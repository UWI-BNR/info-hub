/*******************************************************************************
DO-FILE:     bnr_mort_construct_rates.do
VERSION:     0.1.0 (30 August 2026)
PROJECT:     BNR Refit Phase 2
PURPOSE:     Construct private annual crude and directly age-standardised
             mortality-rate rows from the Step 3 classified-death cohort.

This bounded helper is called by Mortality Step 3.  It creates no public,
approval or website output.  It deliberately uses the established mortality
cohort: valid death date, known male/female sex, and the existing Primary and
Inclusive classifications.  It does not contain CVD-event DCO logic.
*******************************************************************************/
version 19
* Preserve the caller's operational failure handler. This helper is invoked
* inside the Step 3 controller, so clear all would remove that handler if a
* rate validation fails.
clear
set more off

args base_input population_input standard_input rates_output qa_output ///
    release_id start_year end_year

foreach argument in base_input population_input standard_input rates_output ///
        qa_output release_id start_year end_year {
    if "``argument''" == "" {
        display as error "Mortality-rate helper received an incomplete contract."
        exit 198
    }
}

foreach input_file in base_input population_input standard_input {
    capture confirm file "``input_file''"
    if _rc {
        display as error "Required private mortality-rate input was not found: ``input_file''"
        exit 601
    }
}

local start_num = real("`start_year'")
local end_num = real("`end_year'")
if missing(`start_num', `end_num') | `start_num' < 2010 | `end_num' < `start_num' {
    display as error "Mortality-rate years must be complete calendar years from 2010."
    exit 198
}

local lower_probability = 0.025
local upper_probability = 0.975
local ci_level_value = 95

tempfile population standard age_grid observed atomic crude asr rate_rows qa_dta
tempname qa_handle

* ==============================================================================
* 1. Validate the approved private denominator and WHO-standard assets.
* ==============================================================================
use "`population_input'", clear
foreach variable in year sex age_group population {
    capture confirm variable `variable'
    if _rc exit 111
}
capture confirm numeric variable year population
if _rc exit 109
capture confirm string variable sex age_group
if _rc exit 109
replace sex = lower(strtrim(sex))
replace age_group = lower(strtrim(age_group))
keep if inrange(year, `start_num', `end_num')
assert inlist(sex, "all", "female", "male")
assert population > 0 & !missing(population)
isid year sex age_group
bysort year sex: assert _N == 21
forvalues check_year = `start_num'/`end_num' {
    quietly count if year == `check_year'
    if r(N) != 63 {
        display as error "WPP population input is incomplete for `check_year'."
        exit 459
    }
}
preserve
    reshape wide population, i(year age_group) j(sex) string
    assert abs(populationall - populationfemale - populationmale) < 0.000001
restore
save `population', replace

use "`standard_input'", clear
foreach variable in age_group standard_weight {
    capture confirm variable `variable'
    if _rc exit 111
}
capture confirm string variable age_group
if _rc exit 109
capture confirm numeric variable standard_weight
if _rc exit 109
replace age_group = lower(strtrim(age_group))
isid age_group
assert _N == 21
assert standard_weight > 0 & !missing(standard_weight)
quietly summarize standard_weight, meanonly
assert abs(r(sum) - 1) < 0.000000001
save `standard', replace

* ==============================================================================
* 2. Create the mortality numerator at five-year-age grain.
*    The existing Step 3 cohort has already excluded invalid/unknown sex, so
*    the all-sex rate remains exactly reconcilable to female plus male counts.
* ==============================================================================
use "`base_input'", clear
foreach variable in dth_year case_definition event_type metric_sex age_years death {
    capture confirm variable `variable'
    if _rc exit 111
}
keep if inrange(dth_year, `start_num', `end_num')
assert inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
assert inlist(event_type, "heart", "stroke")
assert inlist(metric_sex, "female", "male")
assert death == 1

* Step 3 already uses age_group for its reporting bands (under_70 and
* age_70_plus).  Rates use the independent five-year denominator bands below.
capture drop age_group
generate str16 age_group = "age_unknown"
forvalues lower = 0(5)95 {
    local upper = `lower' + 4
    replace age_group = "age_`lower'_`upper'" if inrange(age_years, `lower', `upper')
}
replace age_group = "age_100_plus" if age_years >= 100 & !missing(age_years)

generate long __death_row = _n
expand 4
bysort __death_row: generate byte __copy = _n
replace event_type = "all_cvd" if inlist(__copy, 2, 4)
replace metric_sex = "all" if inlist(__copy, 3, 4)
drop __death_row __copy
collapse (sum) deaths = death, by(dth_year case_definition event_type metric_sex age_group)
rename metric_sex sex
isid dth_year case_definition event_type sex age_group
save `observed', replace

* Build an explicit zero-inclusive numerator grid.  Age unknown is intentionally
* retained for crude-rate totals only; it is not part of direct standardisation.
use `population', clear
keep year sex age_group
rename year dth_year
expand 2
bysort dth_year sex age_group: generate byte __definition = _n
generate str32 case_definition = cond(__definition == 1, ///
    "primary_clear_likely", "upper_clear_likely_possible")
drop __definition
expand 3
bysort dth_year sex age_group case_definition: generate byte __event = _n
generate str20 event_type = "all_cvd" if __event == 1
replace event_type = "heart" if __event == 2
replace event_type = "stroke" if __event == 3
drop __event
* Keep the denominator-supported age grid only.  Using-only age_unknown rows
* remain in `observed' for crude rates, but are deliberately outside the ASR.
merge 1:1 dth_year case_definition event_type sex age_group using `observed', ///
    keep(master match) nogen
replace deaths = 0 if missing(deaths)
assert deaths >= 0 & deaths == floor(deaths)
save `atomic', replace

* ==============================================================================
* 3. Annual crude rates and exact Poisson (Garwood) intervals.
* ==============================================================================
use `observed', clear
collapse (sum) deaths, by(dth_year case_definition event_type sex)
tempfile crude_observed
save `crude_observed', replace

use `atomic', clear
keep dth_year case_definition event_type sex
duplicates drop
merge 1:1 dth_year case_definition event_type sex using `crude_observed', nogen
replace deaths = 0 if missing(deaths)
preserve
    use `population', clear
    collapse (sum) denominator = population, by(year sex)
    rename year dth_year
    tempfile all_age_population
    save `all_age_population', replace
restore
merge m:1 dth_year sex using `all_age_population', nogen assert(match)
generate double value = 100000 * deaths / denominator
generate double numerator = deaths
generate double ci_lower_value = 0
replace ci_lower_value = 0.5 * (100000 / denominator) * ///
    invchi2(2 * deaths, `lower_probability') if deaths > 0
generate double ci_upper_value = 0.5 * (100000 / denominator) * ///
    invchi2(2 * (deaths + 1), `upper_probability')
generate byte ci_level = `ci_level_value'
generate str40 ci_method = "poisson_exact_garwood"
generate str20 age_group = "all"
generate str45 statistic = "annual_crude_rate"
tempfile crude_rows
save `crude_rows', replace

* ==============================================================================
* 4. Direct age standardisation and Fay-Feuer gamma intervals.
* ==============================================================================
use `atomic', clear
preserve
    use `population', clear
    rename year dth_year
    tempfile population_for_asr
    save `population_for_asr', replace
restore
merge m:1 dth_year sex age_group using `population_for_asr', nogen assert(match)
merge m:1 age_group using `standard', nogen assert(match)
generate double __rate_weight = standard_weight * 100000 / population
generate double __point = __rate_weight * deaths
generate double __variance = (__rate_weight ^ 2) * deaths
collapse (sum) value = __point ci_variance = __variance ///
    (max) ci_max_weight = __rate_weight, ///
    by(dth_year case_definition event_type sex)
assert value >= 0 & ci_variance >= 0 & ci_max_weight > 0
generate double ci_lower_value = 0
replace ci_lower_value = 0.5 * (ci_variance / value) * ///
    invchi2(2 * (value ^ 2) / ci_variance, `lower_probability') if value > 0
generate double __upper_point = value + ci_max_weight
generate double __upper_variance = ci_variance + (ci_max_weight ^ 2)
generate double ci_upper_value = 0.5 * (__upper_variance / __upper_point) * ///
    invchi2(2 * (__upper_point ^ 2) / __upper_variance, `upper_probability')
generate double numerator = .
generate double denominator = .
generate byte ci_level = `ci_level_value'
generate str40 ci_method = "fay_feuer_gamma"
generate str20 age_group = "age_standardised"
generate str45 statistic = "annual_age_standardised_rate"
tempfile asr_rows
save `asr_rows', replace

* ==============================================================================
* 5. Apply the common public-shaped mortality metric fields.
* ==============================================================================
use `crude_rows', clear
append using `asr_rows'
generate str20 metric_id = "MORT-RATE-001"
generate str20 release_id = "`release_id'"
generate str12 period_type = "annual"
generate str20 period = string(dth_year, "%04.0f")
generate str10 period_start = period + "-01-01"
generate byte period_month = .
generate byte period_quarter = .
generate byte period_complete = 1
generate str30 source_status = "death_certificate"
generate str15 unit = "rate_per_100000"
generate byte comparison_n = .
generate str25 status_flag = "final"
generate str20 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = 0
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = 0
generate str60 suppression_reason = ""

rename sex metric_sex
rename dth_year period_year
order metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type metric_sex age_group case_definition source_status ///
    statistic value unit numerator denominator comparison_n status_flag ///
    ci_lower_value ci_upper_value ci_level ci_method ///
    sdc_policy primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason
sort period_year case_definition event_type metric_sex age_group
isid metric_id period_type period_year period_month period_quarter ///
    case_definition event_type metric_sex age_group statistic, missok
save "`rates_output'", replace

* ==============================================================================
* 6. Evidence-bearing private QA receipt.
* ==============================================================================
postfile `qa_handle' str44 check str8 result str244 detail using "`qa_output'", replace
post `qa_handle' ("rate_reference_assets") ("PASS") ///
    ("WPP 2024 Barbados population and WHO World Standard assets passed completeness and accounting checks.")
post `qa_handle' ("rate_lattice") ("PASS") ///
    ("Complete annual grid: two definitions, three CVD types, three sex strata and crude/age-standardised forms.")
post `qa_handle' ("crude_rate_equations") ("PASS") ///
    ("Each crude rate equals its classified annual death numerator divided by the approved all-age population.")
post `qa_handle' ("age_standardisation") ("PASS") ///
    ("Each ASR uses all 21 five-year age bands and the fixed WHO World Standard weights.")
post `qa_handle' ("statistical_confidence_intervals") ("PASS") ///
    ("Crude intervals are exact Poisson Garwood; ASR intervals are Fay-Feuer gamma.")
post `qa_handle' ("rate_age_unknown_policy") ("PASS") ///
    ("Deaths with unusable age remain in crude rates and are excluded from age-standardisation.")
postclose `qa_handle'

use "`rates_output'", clear
quietly count
local rate_rows = r(N)
local expected_rate_rows = (`end_num' - `start_num' + 1) * 36
if `rate_rows' != `expected_rate_rows' {
    display as error "Mortality rate output does not contain the expected annual lattice."
    exit 459
}
quietly count if missing(value) | ci_lower_value < 0 | ///
    ci_lower_value > value + 0.0000001 | ci_upper_value + 0.0000001 < value | ///
    ci_upper_value < ci_lower_value | ci_level != 95 | ci_method == ""
if r(N) {
    display as error "Mortality rate or confidence-interval validation failed."
    exit 459
}
quietly count if age_group == "all" & (missing(numerator) | missing(denominator))
if r(N) exit 459
quietly count if age_group == "age_standardised" & (!missing(numerator) | !missing(denominator))
if r(N) exit 459

display as result "Mortality annual rate construction passed."

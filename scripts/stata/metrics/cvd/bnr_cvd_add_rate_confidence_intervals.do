/*******************************************************************************
DO-FILE:     bnr_cvd_add_rate_confidence_intervals.do
VERSION:     1.0.1 (28 August 2026)
PURPOSE:     Add 95% statistical confidence intervals to the private
             public-shaped annual CVD rate candidate.

METHODS:
  Hospital crude
    Exact Poisson / Garwood interval.

  Hospital age-standardised
    Fay-Feuer gamma interval for a directly standardised rate.

  Hospital + DCO crude
    Conditional gamma interval using the central hospital + DCO pseudo-count.

  Hospital + DCO age-standardised
    Conditional Fay-Feuer gamma interval using central age-specific
    hospital + DCO pseudo-counts.

IMPORTANT:
  - These are statistical confidence intervals around the central estimate.
  - DCO linkage/ascertainment uncertainty remains separate in
    linkage_lower_value and linkage_upper_value.
  - The helper does not change value, numerator, denominator, or linkage limits.
  - Count rows receive blank CI fields.
  - No public output is created here.

NOTES:
  The gamma quantiles are evaluated through the chi-square relationship:
      Gamma(shape, scale) quantile
        = 0.5 * scale * invchi2(2 * shape, probability)

  This avoids adding any Stata package dependency.
*******************************************************************************/

version 19
clear all
set more off

args events_input components_input population_input standard_input ///
    rates_input qa_output cvd_release_year cvd_release_month

foreach argument in events_input components_input population_input ///
        standard_input rates_input qa_output cvd_release_year cvd_release_month {
    if "``argument''" == "" {
        display as error "Rate-CI helper received an incomplete contract."
        exit 198
    }
}

foreach input_file in events_input components_input population_input ///
        standard_input rates_input qa_output {
    capture confirm file "``input_file''"
    if _rc {
        display as error "Required CI input was not found: ``input_file''"
        exit 601
    }
}

local year_num = real("`cvd_release_year'")
local month_num = real("`cvd_release_month'")
if missing(`year_num', `month_num') | ///
        `year_num' != floor(`year_num') | ///
        `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "CVD release year/month must be valid integers."
    exit 198
}

local last_complete_year = `year_num'
if `month_num' < 12 local last_complete_year = `year_num' - 1
if `last_complete_year' < 2010 exit 459

local year4 : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local release_id "cvd_`year4'_`month2'"

local lower_probability = 0.025
local upper_probability = 0.975
local ci_level_value = 95

tempfile rates_original hospital_age population_asr standard_asr ///
    age_ci_source crude_ci hospital_asr_ci dco_asr_ci ci_rows ///
    rates_final ci_qa existing_qa

* ---------------------------------------------------------------------------
* 1. Freeze the existing candidate before adding any CI fields.
* ---------------------------------------------------------------------------
use "`rates_input'", clear

local rate_required schema_version release_id metric_id period_type dth_year ///
    event_type sex age_group ascertainment_scope mortality_definition ///
    estimate_basis unit value numerator denominator linkage_lower_value ///
    linkage_upper_value period_complete status_flag
foreach variable of local rate_required {
    capture confirm variable `variable'
    if _rc {
        display as error "Rate-CI helper input variable is absent: `variable'"
        exit 111
    }
}

assert schema_version == "bnr_cvd_public_metric_v2"
assert release_id == "`release_id'"
assert period_type == "annual"

* Permit a safe re-run of this helper against an already extended private file.
capture drop ci_lower_value
capture drop ci_upper_value
capture drop ci_level
capture drop ci_method

clonevar __value_before = value
clonevar __numerator_before = numerator
clonevar __denominator_before = denominator
clonevar __linkage_lower_before = linkage_lower_value
clonevar __linkage_upper_before = linkage_upper_value

save "`rates_original'", replace

* ---------------------------------------------------------------------------
* 2. Crude-rate intervals.
*
* With one stratum, the Fay-Feuer gamma machinery reduces to the ordinary
* Garwood interval when the numerator is an observed integer count.
* Fractional DCO-enhanced central numerators therefore use the same gamma
* equations but are explicitly labelled conditional_gamma.
* ---------------------------------------------------------------------------
use "`rates_original'", clear
keep if metric_id == "CVD-INCIDENCE-001" & age_group == "all"

assert !missing(numerator, denominator, value)
assert numerator >= 0
assert denominator > 0
assert inlist(ascertainment_scope, "hospital_only", "hospital_plus_dco")
assert mortality_definition == "not_applicable" if ascertainment_scope == "hospital_only"
assert inlist(mortality_definition, "primary", "inclusive") ///
    if ascertainment_scope == "hospital_plus_dco"

generate double __rate_weight = 100000 / denominator
generate double ci_point_check = numerator * __rate_weight
assert abs(ci_point_check - value) < 0.0000001

* Hospital-only crude numerators must remain observed integer counts.
assert abs(numerator - round(numerator)) < 0.0000001 ///
    if ascertainment_scope == "hospital_only"

generate double ci_lower_value = 0
replace ci_lower_value = ///
    0.5 * __rate_weight * invchi2(2 * numerator, `lower_probability') ///
    if numerator > 0

generate double ci_upper_value = ///
    0.5 * __rate_weight * invchi2(2 * (numerator + 1), `upper_probability')

generate byte ci_level = `ci_level_value'
generate str40 ci_method = "poisson_exact_garwood" ///
    if ascertainment_scope == "hospital_only"
replace ci_method = "conditional_gamma" ///
    if ascertainment_scope == "hospital_plus_dco"

keep metric_id dth_year event_type sex age_group ascertainment_scope ///
    mortality_definition ci_point_check ci_lower_value ci_upper_value ///
    ci_level ci_method
save "`crude_ci'", replace

* ---------------------------------------------------------------------------
* 3. Recreate the hospital age-specific numerator used by the ASR calculation.
*    This mirrors the existing rate core, but only for the CI variance.
* ---------------------------------------------------------------------------
use "`events_input'", clear

foreach variable in eid doe etype dco sex agey {
    capture confirm variable `variable'
    if _rc {
        display as error "Hospital-event CI input variable is absent: `variable'"
        exit 111
    }
}
foreach variable in doe etype dco sex agey {
    capture confirm numeric variable `variable'
    if _rc exit 109
}

isid eid
assert inlist(dco, 0, 1)

keep if dco == 0 & inrange(year(doe), 2010, `last_complete_year')
assert inlist(etype, 1, 2)

generate int dth_year = year(doe)
generate str12 event_type = "stroke" if etype == 1
replace event_type = "heart" if etype == 2

generate str10 sex_atomic = "unknown"
replace sex_atomic = "female" if sex == 1
replace sex_atomic = "male" if sex == 2

generate str16 age_group = "age_unknown"
forvalues lower = 0(5)95 {
    local upper = `lower' + 4
    replace age_group = "age_`lower'_`upper'" ///
        if inrange(agey, `lower', `upper')
}
replace age_group = "age_100_plus" if agey >= 100 & !missing(agey)

generate long hospital_n = 1
generate long __event_row = _n
expand 4
bysort __event_row: generate byte __copy = _n
replace event_type = "all_cvd" if inlist(__copy, 2, 4)

generate str10 sex_public = sex_atomic
replace sex_public = "all" if inlist(__copy, 3, 4)

drop __event_row __copy eid doe etype dco sex agey sex_atomic
rename sex_public sex

collapse (sum) hospital_n, by(dth_year event_type sex age_group)
isid dth_year event_type sex age_group
save "`hospital_age'", replace

* Population and standard assets used by the ASR variance.
use "`population_input'", clear
foreach variable in year sex age_group population {
    capture confirm variable `variable'
    if _rc exit 111
}
rename year dth_year
keep if inrange(dth_year, 2010, `last_complete_year') & ///
    inlist(sex, "all", "female", "male")
assert population > 0 & !missing(population)
isid dth_year sex age_group
save "`population_asr'", replace

use "`standard_input'", clear
foreach variable in age_group standard_weight {
    capture confirm variable `variable'
    if _rc exit 111
}
assert standard_weight > 0 & !missing(standard_weight)
isid age_group
quietly summarize standard_weight, meanonly
assert abs(r(sum) - 1) < 0.000000001
keep age_group standard_weight
save "`standard_asr'", replace

* ---------------------------------------------------------------------------
* 4. Build the age-specific central pseudo-count grid for statistical CIs.
* ---------------------------------------------------------------------------
use "`components_input'", clear

local component_required mortality_definition dth_year category sex age_group ///
    dco_central_component_n
foreach variable of local component_required {
    capture confirm variable `variable'
    if _rc {
        display as error "Rate-component CI input variable is absent: `variable'"
        exit 111
    }
}

keep if inrange(dth_year, 2010, `last_complete_year') & ///
    inlist(category, "all_cvd", "heart", "stroke") & ///
    inlist(sex, "all", "female", "male") & ///
    age_group != "age_unknown"

assert inlist(mortality_definition, "primary", "inclusive")
assert dco_central_component_n >= 0 & !missing(dco_central_component_n)

rename category event_type

merge m:1 dth_year event_type sex age_group using "`hospital_age'", ///
    keep(master match)
replace hospital_n = 0 if _merge == 1
drop _merge

merge m:1 dth_year sex age_group using "`population_asr'"
assert _merge == 3
drop _merge

merge m:1 age_group using "`standard_asr'"
assert _merge == 3
drop _merge

generate double __rate_weight = standard_weight * 100000 / population
assert __rate_weight > 0 & !missing(__rate_weight)

generate double __hospital_point = __rate_weight * hospital_n
generate double __hospital_variance = (__rate_weight ^ 2) * hospital_n

generate double __dco_central_n = hospital_n + dco_central_component_n
assert __dco_central_n >= 0 & !missing(__dco_central_n)
generate double __dco_point = __rate_weight * __dco_central_n
generate double __dco_variance = (__rate_weight ^ 2) * __dco_central_n

save "`age_ci_source'", replace

* ---------------------------------------------------------------------------
* 5. Hospital-only ASR: Fay-Feuer gamma interval.
*
* Hospital counts are identical under Primary and Inclusive DCO definitions.
* Retain one definition only to avoid duplicating the observed calculation.
* ---------------------------------------------------------------------------
use "`age_ci_source'", clear
keep if mortality_definition == "primary"

collapse (sum) ci_point_check = __hospital_point ///
    ci_variance = __hospital_variance ///
    (max) ci_max_weight = __rate_weight, ///
    by(dth_year event_type sex)

assert ci_point_check >= 0 & ci_variance >= 0
assert ci_max_weight > 0 & !missing(ci_max_weight)

generate double ci_lower_value = 0
replace ci_lower_value = ///
    0.5 * (ci_variance / ci_point_check) * ///
    invchi2(2 * (ci_point_check ^ 2) / ci_variance, `lower_probability') ///
    if ci_point_check > 0

generate double __upper_point = ci_point_check + ci_max_weight
generate double __upper_variance = ci_variance + (ci_max_weight ^ 2)
generate double ci_upper_value = ///
    0.5 * (__upper_variance / __upper_point) * ///
    invchi2(2 * (__upper_point ^ 2) / __upper_variance, `upper_probability')

generate str24 metric_id = "CVD-INCIDENCE-001"
generate str20 age_group = "age_standardised"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate byte ci_level = `ci_level_value'
generate str40 ci_method = "fay_feuer_gamma"

keep metric_id dth_year event_type sex age_group ascertainment_scope ///
    mortality_definition ci_point_check ci_lower_value ci_upper_value ///
    ci_level ci_method
save "`hospital_asr_ci'", replace

* ---------------------------------------------------------------------------
* 6. Hospital + DCO ASR: conditional Fay-Feuer gamma interval.
* ---------------------------------------------------------------------------
use "`age_ci_source'", clear

collapse (sum) ci_point_check = __dco_point ///
    ci_variance = __dco_variance ///
    (max) ci_max_weight = __rate_weight, ///
    by(mortality_definition dth_year event_type sex)

assert ci_point_check >= 0 & ci_variance >= 0
assert ci_max_weight > 0 & !missing(ci_max_weight)

generate double ci_lower_value = 0
replace ci_lower_value = ///
    0.5 * (ci_variance / ci_point_check) * ///
    invchi2(2 * (ci_point_check ^ 2) / ci_variance, `lower_probability') ///
    if ci_point_check > 0

generate double __upper_point = ci_point_check + ci_max_weight
generate double __upper_variance = ci_variance + (ci_max_weight ^ 2)
generate double ci_upper_value = ///
    0.5 * (__upper_variance / __upper_point) * ///
    invchi2(2 * (__upper_point ^ 2) / __upper_variance, `upper_probability')

generate str24 metric_id = "CVD-INCIDENCE-001"
generate str20 age_group = "age_standardised"
generate str24 ascertainment_scope = "hospital_plus_dco"
generate byte ci_level = `ci_level_value'
generate str40 ci_method = "conditional_fay_feuer_gamma"

keep metric_id dth_year event_type sex age_group ascertainment_scope ///
    mortality_definition ci_point_check ci_lower_value ci_upper_value ///
    ci_level ci_method
save "`dco_asr_ci'", replace

* ---------------------------------------------------------------------------
* 7. Merge statistical CIs onto the existing candidate.
* ---------------------------------------------------------------------------
use "`crude_ci'", clear
append using "`hospital_asr_ci'"
append using "`dco_asr_ci'"

local ci_key metric_id dth_year event_type sex age_group ascertainment_scope ///
    mortality_definition
isid `ci_key'
save "`ci_rows'", replace

use "`rates_original'", clear
merge 1:1 `ci_key' using "`ci_rows'"

quietly count if metric_id == "CVD-INCIDENCE-001" & _merge != 3
local missing_ci_matches = r(N)

quietly count if metric_id != "CVD-INCIDENCE-001" & _merge != 1
local unexpected_ci_matches = r(N)

drop _merge

generate byte __point_changed = ///
    !(value == __value_before | (missing(value) & missing(__value_before))) | ///
    !(numerator == __numerator_before | ///
        (missing(numerator) & missing(__numerator_before))) | ///
    !(denominator == __denominator_before | ///
        (missing(denominator) & missing(__denominator_before)))

generate byte __linkage_changed = ///
    !(linkage_lower_value == __linkage_lower_before | ///
        (missing(linkage_lower_value) & missing(__linkage_lower_before))) | ///
    !(linkage_upper_value == __linkage_upper_before | ///
        (missing(linkage_upper_value) & missing(__linkage_upper_before)))

quietly count if __point_changed
local point_change_failures = r(N)

quietly count if __linkage_changed
local linkage_change_failures = r(N)

quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    abs(value - ci_point_check) >= 0.0000001
local point_reproduction_failures = r(N)

quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    (missing(ci_lower_value) | missing(ci_upper_value) | ///
    missing(ci_level) | ci_method == "")
local missing_ci_fields = r(N)

quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    (ci_lower_value < 0 | ci_lower_value > value + 0.0000001 | ///
    ci_upper_value + 0.0000001 < value | ci_upper_value < ci_lower_value)
local interval_order_failures = r(N)

quietly count if metric_id == "CVD-INCIDENCE-001" & ci_level != 95
local ci_level_failures = r(N)

quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    ((age_group == "all" & ascertainment_scope == "hospital_only" & ///
        ci_method != "poisson_exact_garwood") | ///
     (age_group == "all" & ascertainment_scope == "hospital_plus_dco" & ///
        ci_method != "conditional_gamma") | ///
     (age_group == "age_standardised" & ///
        ascertainment_scope == "hospital_only" & ///
        ci_method != "fay_feuer_gamma") | ///
     (age_group == "age_standardised" & ///
        ascertainment_scope == "hospital_plus_dco" & ///
        ci_method != "conditional_fay_feuer_gamma"))
local ci_method_failures = r(N)

quietly count if metric_id != "CVD-INCIDENCE-001" & ///
    (!missing(ci_lower_value) | !missing(ci_upper_value) | ///
    !missing(ci_level) | ci_method != "")
local nonrate_ci_failures = r(N)

drop __value_before __numerator_before __denominator_before ///
    __linkage_lower_before __linkage_upper_before ///
    __point_changed __linkage_changed ci_point_check

save "`rates_final'", replace

* ---------------------------------------------------------------------------
* 8. Append CI acceptance checks to the existing private rate QA CSV.
* ---------------------------------------------------------------------------
clear
set obs 9
generate str96 check = ""
generate double value = .
generate str220 detail = ""

replace check = "Rate rows without CI match" in 1
replace value = `missing_ci_matches' in 1
replace detail = "Every CVD-INCIDENCE-001 row matched exactly one statistical CI." in 1

replace check = "Unexpected non-rate CI match" in 2
replace value = `unexpected_ci_matches' in 2
replace detail = "No burden/count row matched the rate-CI lattice." in 2

replace check = "Central estimate field changes" in 3
replace value = `point_change_failures' in 3
replace detail = "value, numerator and denominator are unchanged by the CI helper." in 3

replace check = "Linkage uncertainty field changes" in 4
replace value = `linkage_change_failures' in 4
replace detail = "linkage_lower_value and linkage_upper_value are unchanged." in 4

replace check = "Rate point reproduction failures" in 5
replace value = `point_reproduction_failures' in 5
replace detail = "CI source calculations reproduce every published central rate." in 5

replace check = "Missing statistical CI fields" in 6
replace value = `missing_ci_fields' in 6
replace detail = "Every annual rate has CI limits, 95% level and a method identifier." in 6

replace check = "Statistical CI ordering failures" in 7
replace value = `interval_order_failures' + `ci_level_failures' in 7
replace detail = "Every 95% CI is non-negative and contains its central estimate." in 7

replace check = "Statistical CI method failures" in 8
replace value = `ci_method_failures' in 8
replace detail = "Crude and ASR rows use the frozen hospital/DCO CI methods." in 8

replace check = "Non-rate CI field failures" in 9
replace value = `nonrate_ci_failures' in 9
replace detail = "Count rows have blank statistical CI fields." in 9

save "`ci_qa'", replace

import delimited using "`qa_output'", varnames(1) clear
foreach variable in check value detail {
    capture confirm variable `variable'
    if _rc exit 111
}
save "`existing_qa'", replace
append using "`ci_qa'"
order check value detail
export delimited using "`qa_output'", replace

* ---------------------------------------------------------------------------
* 9. Final acceptance gate, then replace the private rate candidate in place.
* ---------------------------------------------------------------------------
assert `missing_ci_matches' == 0
assert `unexpected_ci_matches' == 0
assert `point_change_failures' == 0
assert `linkage_change_failures' == 0
assert `point_reproduction_failures' == 0
assert `missing_ci_fields' == 0
assert `interval_order_failures' == 0
assert `ci_level_failures' == 0
assert `ci_method_failures' == 0
assert `nonrate_ci_failures' == 0

use "`rates_final'", clear
save "`rates_input'", replace

display as result "Statistical confidence intervals added to private CVD rates."
display as result "  CI level: 95%"
display as result "  Crude hospital: exact Poisson / Garwood"
display as result "  ASR hospital: Fay-Feuer gamma"
display as result "  DCO-enhanced intervals: conditional on central DCO pseudo-counts"

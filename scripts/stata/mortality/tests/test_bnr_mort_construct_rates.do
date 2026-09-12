/*******************************************************************************
DO-FILE:     test_bnr_mort_construct_rates.do
PURPOSE:     Synthetic unit test for the bounded annual mortality-rate helper.
             It writes only temporary files and never calls Steps 4--6.
*******************************************************************************/
version 19
clear all
set more off

if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc exit _rc
}

tempfile base population standard rates qa

* Two complete test years, both definitions, two resolved outcomes and both
* sex groups.  The all-CVD/all-sex expansions are created by the helper.
clear
set obs 12
generate int dth_year = cond(_n <= 6, 2010, 2011)
generate str32 case_definition = cond(mod(_n, 2), ///
    "primary_clear_likely", "upper_clear_likely_possible")
generate str20 event_type = cond(inlist(_n, 1, 2, 7, 8), "heart", "stroke")
generate str20 metric_sex = cond(mod(floor((_n - 1) / 2), 2), "female", "male")
generate double age_years = 50 + 5 * mod(_n, 4)
replace age_years = . if _n == 12
generate byte death = 1
save `base', replace

* 21 five-year groups with internally consistent all-sex population.
clear
set obs 2
generate int year = 2009 + _n
expand 21
bysort year: generate int age_index = _n - 1
generate str16 age_group = ""
forvalues lower = 0(5)95 {
    local index = `lower' / 5
    local upper = `lower' + 4
    replace age_group = "age_`lower'_`upper'" if age_index == `index'
}
replace age_group = "age_100_plus" if age_index == 20
expand 3
bysort year age_index: generate byte sex_index = _n
generate str10 sex = cond(sex_index == 1, "all", cond(sex_index == 2, "female", "male"))
generate double population = 1000 + 10 * age_index
replace population = population / 2 if inlist(sex, "female", "male")
drop age_index sex_index
save `population', replace

clear
set obs 21
generate int age_index = _n - 1
generate str16 age_group = ""
forvalues lower = 0(5)95 {
    local index = `lower' / 5
    local upper = `lower' + 4
    replace age_group = "age_`lower'_`upper'" if age_index == `index'
}
replace age_group = "age_100_plus" if age_index == 20
generate double standard_weight = 1 / 21
drop age_index
save `standard', replace

do "$BNR_STATA/mortality/bnr_mort_construct_rates.do" ///
    `"`base'"' `"`population'"' `"`standard'"' ///
    `"`rates'"' `"`qa'"' "mort_2099_01" 2010 2011

use `rates', clear
quietly count
assert r(N) == 72
assert metric_id == "MORT-RATE-001"
assert period_type == "annual"
assert inlist(age_group, "all", "age_standardised")
assert inlist(metric_sex, "all", "female", "male")
assert inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
assert inlist(event_type, "all_cvd", "heart", "stroke")
assert ci_level == 95
assert ci_lower_value >= 0 & ci_lower_value <= value & value <= ci_upper_value
assert !missing(numerator, denominator) if age_group == "all"
assert missing(numerator) & missing(denominator) if age_group == "age_standardised"
assert ci_method == "poisson_exact_garwood" if age_group == "all"
assert ci_method == "fay_feuer_gamma" if age_group == "age_standardised"

quietly count if period_year == 2011 & case_definition == "primary_clear_likely" & ///
    event_type == "stroke" & metric_sex == "male" & age_group == "all" & numerator == 1
assert r(N) == 1

* Freeze one exact Poisson/Garwood result independently of the constructor.
* Male all-age population is half of sum(1000, 1010, ..., 1200) = 11,550.
local expected_lower = 0.5 * (100000 / 11550) * invchi2(2, 0.025)
local expected_upper = 0.5 * (100000 / 11550) * invchi2(4, 0.975)
assert abs(ci_lower_value - `expected_lower') < 0.0000001 if period_year == 2011 & ///
    case_definition == "primary_clear_likely" & event_type == "stroke" & ///
    metric_sex == "male" & age_group == "all"
assert abs(ci_upper_value - `expected_upper') < 0.0000001 if period_year == 2011 & ///
    case_definition == "primary_clear_likely" & event_type == "stroke" & ///
    metric_sex == "male" & age_group == "all"

use `qa', clear
assert _N == 6
assert result == "PASS"

display as result "test_bnr_mort_construct_rates: PASSED"

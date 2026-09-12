/*******************************************************************************
DO-FILE: test_bnr_cvd_annual_dco_count_contract.do
VERSION: 1.1.1 (28 August 2026)
PURPOSE: Verify the Step 4 annual DCO count contract before Step 5 review.

USAGE:
  do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_annual_dco_count_contract.do" ///
      "path/to/cvd_burden_metrics_....dta" ///
      "path/to/stage4_incidence_rates_....dta" "cvd_2024_04"
*******************************************************************************/

version 19
clear all
set more off

args burden_dta rates_dta release_id
if "`burden_dta'" == "" | "`rates_dta'" == "" | "`release_id'" == "" exit 198
capture confirm file "`burden_dta'"
if _rc exit 601
capture confirm file "`rates_dta'"
if _rc exit 601

use "`rates_dta'", clear
foreach variable in metric_id release_id period_type dth_year event_type sex age_group ascertainment_scope mortality_definition estimate_basis unit value numerator denominator linkage_lower_value linkage_upper_value period_complete status_flag {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"
assert period_type == "annual"
assert period_complete == 1
assert status_flag == "final"

* Additional rows are annual/all-age only, in the same released event x sex x
* mortality-definition strata as hospital-plus-DCO rates.
preserve
    keep if metric_id == "CVD-BURDEN-001" & ///
        inlist(ascertainment_scope, "hospital_plus_dco", "additional_dco")
    assert age_group == "all"
    assert unit == "count"
    assert estimate_basis == "estimated"
    assert inlist(mortality_definition, "primary", "inclusive")
    assert inlist(event_type, "all_cvd", "heart", "stroke")
    assert inlist(sex, "all", "female", "male")
    assert !missing(value, numerator, linkage_lower_value, linkage_upper_value)
    assert missing(denominator)
    assert linkage_lower_value <= value & value <= linkage_upper_value
    isid release_id dth_year event_type sex mortality_definition ascertainment_scope
    quietly count
    local count_rows = r(N)
restore

* There are 36 new count rows per complete year: 3 events x 3 sexes x 2
* definitions x 2 DCO count scopes.
quietly levelsof dth_year, local(annual_years)
local annual_year_n : word count `annual_years'
assert `count_rows' == 36 * `annual_year_n'

* Recheck the private arithmetic before Step 5 applies suppression.  The
* hospital term is deliberately sourced from the established burden lattice.
tempfile hospital_counts
use "`burden_dta'", clear
preserve
    keep if metric_id == "CVD-BURDEN-001" & ///
        ascertainment_scope == "hospital_only" & age_group == "all" & ///
        statistic == "annual_count"
    keep period_year event_type sex value
    rename value hospital_value
    isid period_year event_type sex
    save "`hospital_counts'", replace
restore

use "`rates_dta'", clear
keep if metric_id == "CVD-BURDEN-001" & age_group == "all" & ///
    inlist(ascertainment_scope, "hospital_plus_dco", "additional_dco")
keep dth_year event_type sex mortality_definition ascertainment_scope value
rename dth_year period_year
reshape wide value, i(mortality_definition period_year event_type sex) j(ascertainment_scope) string
* The burden lattice can also contain an incomplete current-year hospital row.
* The rate input contains completed annual years only, so retain its rows and
* matching hospital counts; do not assess unrelated burden-only observations.
merge m:1 period_year event_type sex using "`hospital_counts'", keep(master match) nogen
assert !missing(hospital_value)
assert abs(valuehospital_plus_dco - hospital_value - valueadditional_dco) < 0.000001

display as result "Annual DCO count contract test passed."

/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage4_primary_projection.do
VERSION: 0.5.0 (26 August 2026)
PURPOSE: Create a provisional primary-suppressed expanded CVD candidate.

This helper does not apply secondary, temporal or derived suppression.  Its
output is private review material only and must never be promoted or published.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 4 primary-projection helper v0.5.0"

args primary_private_dta primary_candidate_dta qa_dta release_id

foreach argument in primary_private_dta primary_candidate_dta qa_dta release_id {
    if "``argument''" == "" {
        display as error "Stage 4 primary-projection helper received an incomplete contract."
        exit 198
    }
}

capture confirm file "`primary_private_dta'"
assert _rc == 0

use "`primary_private_dta'", clear
local required_variables release_id value numerator denominator linkage_lower_value linkage_upper_value primary_suppression
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"

quietly count
local candidate_rows = r(N)
quietly count if primary_suppression == 1
local primary_rows = r(N)

generate str12 suppression_status = cond(primary_suppression == 1, "primary", "none")
generate str244 disclosure_note = cond(primary_suppression == 1, "Primary suppression: supporting frequency 1-5.", "No disclosure restriction identified.")
generate str20 display_value = cond(primary_suppression == 1, "*", string(value, "%12.3f"))

replace value = . if primary_suppression == 1
replace numerator = . if primary_suppression == 1
replace denominator = . if primary_suppression == 1
replace linkage_lower_value = . if primary_suppression == 1
replace linkage_upper_value = . if primary_suppression == 1

quietly count if suppression_status == "primary" & (!missing(value) | !missing(numerator) | !missing(denominator) | !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0

foreach private_variable in primary_suppression related_primary_cells related_suppression_review suppression_review suppression_reason stage3_original_primary stage3_hospital_primary stage3_dco_primary {
    capture drop `private_variable'
}

save "`primary_candidate_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Primary rows classified" in 1
replace detail = "`primary_rows' of `candidate_rows' rows classified as primary." in 1
replace check = "Primary numeric fields blanked" in 2
replace detail = "value, numerator, denominator and linkage bounds are blank on primary rows." in 2
replace check = "Primary display symbols written" in 3
replace detail = "Primary rows use display_value = *." in 3
replace check = "Private decision fields removed" in 4
replace detail = "The output is still a private provisional candidate awaiting closure." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 4 primary-projection helper passed."

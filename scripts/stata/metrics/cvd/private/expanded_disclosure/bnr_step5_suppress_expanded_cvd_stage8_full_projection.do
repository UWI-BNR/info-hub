/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage8_full_projection.do
VERSION: 0.9.1 (27 August 2026)
PURPOSE: Create a provisional combined candidate after all currently registered
         primary and secondary protection decisions.

The output is still private review material.  It is not approved or public.
Every protected row has its estimate, numerator, denominator and rate bounds
blanked together.  All private decision and support fields are removed.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 8 full-projection helper v0.9.1"

args audited_private_dta candidate_dta qa_dta release_id

foreach argument in audited_private_dta candidate_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}

capture confirm file "`audited_private_dta'"
assert _rc == 0

use "`audited_private_dta'", clear
local required_variables release_id value numerator denominator linkage_lower_value linkage_upper_value stage6_protection_status
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"
assert inlist(stage6_protection_status, "none", "primary", "secondary_structural", "secondary_existing")

quietly count
local candidate_rows = r(N)
quietly count if stage6_protection_status != "none"
local protected_rows = r(N)

generate str12 suppression_status = "none"
replace suppression_status = "primary" if stage6_protection_status == "primary"
replace suppression_status = "secondary" if inlist(stage6_protection_status, "secondary_structural", "secondary_existing")
generate str244 disclosure_note = "No disclosure restriction identified."
replace disclosure_note = "Primary suppression: supporting frequency 1-5." if suppression_status == "primary"
replace disclosure_note = "Secondary suppression: protects a related confidential value." if suppression_status == "secondary"
generate str20 display_value = string(value, "%12.3f")
replace display_value = "*" if suppression_status != "none"

replace value = . if suppression_status != "none"
replace numerator = . if suppression_status != "none"
replace denominator = . if suppression_status != "none"
replace linkage_lower_value = . if suppression_status != "none"
replace linkage_upper_value = . if suppression_status != "none"

quietly count if suppression_status != "none" & (!missing(value) | !missing(numerator) | !missing(denominator) | !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0

foreach private_variable in sdc_policy primary_suppression_threshold primary_suppression related_primary_cells related_suppression_review suppression_review suppression_reason stage3_original_primary stage3_hospital_primary stage3_dco_primary stage5_unknown_support_present stage5_mixed_support_present stage5_structural_secondary stage6_existing_secondary stage6_protection_status stage7_rate_protected {
    capture drop `private_variable'
}

save "`candidate_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Combined protection status projected" in 1
replace detail = "`protected_rows' of `candidate_rows' rows are primary or secondary protected." in 1
replace check = "Protected numeric fields blanked together" in 2
replace detail = "Estimate, numerator, denominator and rate bounds are blank on every protected row." in 2
replace check = "Protected display symbols written" in 3
replace detail = "Protected rows use display_value = *." in 3
replace check = "Private decision fields removed" in 4
replace detail = "The candidate remains private pending the remaining whole-release checks." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 8 full-projection helper passed."

/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage5_structural_secondary.do
VERSION: 0.6.1 (27 August 2026)
PURPOSE: Flag structural secondary suppression for private DCO residuals.

Policy in this limited block:
  * preserve All-sex and female DCO rates; flag male if private unknown-sex
    DCO support is non-zero for the same definition/year/event;
  * preserve All-CVD and Heart DCO rates; flag Stroke if private mixed DCO
    support is non-zero for the same definition/year/sex.

This helper writes a private review lattice only. It does not blank or publish.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 5 structural-secondary helper v0.6.1"

args primary_private_dta support_dta closure_private_dta qa_dta release_id

foreach argument in primary_private_dta support_dta closure_private_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}

capture confirm file "`primary_private_dta'"
assert _rc == 0
capture confirm file "`support_dta'"
assert _rc == 0

tempfile unknown_support mixed_support

use "`support_dta'", clear
local support_required mortality_definition period_year event_type sex dco_lower_component_n dco_central_component_n dco_upper_component_n
foreach variable of local support_required {
    capture confirm variable `variable'
    if _rc exit 111
}

* Unknown-sex residual: any non-zero component requires a male companion.
preserve
keep if sex == "unknown"
quietly count
if r(N) == 0 {
    clear
    generate str20 mortality_definition = ""
    generate int period_year = .
    generate str20 event_type = ""
    generate byte stage5_unknown_support_present = .
}
else {
    generate byte stage5_unknown_support_present = dco_lower_component_n > 0 | dco_central_component_n > 0 | dco_upper_component_n > 0
    collapse (max) stage5_unknown_support_present, by(mortality_definition period_year event_type)
}
save "`unknown_support'", replace
restore

* Mixed subtype residual: any non-zero component requires a Stroke companion.
keep if event_type == "mixed_unallocated"
quietly count
if r(N) == 0 {
    clear
    generate str20 mortality_definition = ""
    generate int period_year = .
    generate str8 sex = ""
    generate byte stage5_mixed_support_present = .
}
else {
    generate byte stage5_mixed_support_present = dco_lower_component_n > 0 | dco_central_component_n > 0 | dco_upper_component_n > 0
    collapse (max) stage5_mixed_support_present, by(mortality_definition period_year sex)
}
save "`mixed_support'", replace

use "`primary_private_dta'", clear
local combined_required metric_id release_id period_year event_type sex ascertainment_scope mortality_definition primary_suppression suppression_review
foreach variable of local combined_required {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"

merge m:1 mortality_definition period_year event_type using "`unknown_support'", nogen keep(master match)
merge m:1 mortality_definition period_year sex using "`mixed_support'", nogen keep(master match)
replace stage5_unknown_support_present = 0 if missing(stage5_unknown_support_present)
replace stage5_mixed_support_present = 0 if missing(stage5_mixed_support_present)

generate byte stage5_structural_secondary = 0
replace stage5_structural_secondary = 1 if metric_id == "CVD-INCIDENCE-001" & ascertainment_scope == "hospital_plus_dco" & sex == "male" & stage5_unknown_support_present == 1 & primary_suppression == 0
replace stage5_structural_secondary = 1 if metric_id == "CVD-INCIDENCE-001" & ascertainment_scope == "hospital_plus_dco" & event_type == "stroke" & stage5_mixed_support_present == 1 & primary_suppression == 0
replace suppression_review = 1 if stage5_structural_secondary == 1

quietly count if stage5_structural_secondary == 1
local secondary_rows = r(N)
quietly count if stage5_unknown_support_present == 1
local unknown_residual_rows = r(N)
quietly count if stage5_mixed_support_present == 1
local mixed_residual_rows = r(N)
save "`closure_private_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Private unknown-sex support identified" in 1
replace detail = "`unknown_residual_rows' candidate rows have non-zero unknown-sex support." in 1
replace check = "Private mixed subtype support identified" in 2
replace detail = "`mixed_residual_rows' candidate rows have non-zero mixed support." in 2
replace check = "Deterministic structural companions flagged" in 3
replace detail = "`secondary_rows' non-primary rate rows flagged for secondary protection." in 3
replace check = "No numeric blanking performed" in 4
replace detail = "This remains a private closure review lattice." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 5 structural-secondary helper passed."

/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage6_existing_closure.do
VERSION: 1.1.4 (28 August 2026)
PURPOSE: Carry established burden related-cell decisions into the combined
         expanded CVD Step 5 private protection register.

Stage 5 added the new deterministic rate companions for private DCO residuals.
This stage retains the existing burden workflow's related-cell decisions.  It
does not calculate a new burden suppression rule: those decisions were made by
the established burden Step 5 pathway and arrive as related_suppression_review.

This helper writes a private review lattice only.  It does not blank, approve,
publish or create a public candidate.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 6 existing-closure helper v1.1.1"

args structural_private_dta closure_private_dta qa_dta release_id

foreach argument in structural_private_dta closure_private_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}

capture confirm file "`structural_private_dta'"
assert _rc == 0

use "`structural_private_dta'", clear

local required_variables metric_id release_id period_year event_type sex age_group ascertainment_scope statistic period_complete primary_suppression related_primary_cells related_suppression_review suppression_review stage5_structural_secondary
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"

assert inlist(primary_suppression, 0, 1)
assert inlist(related_suppression_review, 0, 1)
assert inlist(stage5_structural_secondary, 0, 1)

generate byte stage6_existing_secondary = 0
replace stage6_existing_secondary = 1 if metric_id == "CVD-BURDEN-001" & related_suppression_review == 1 & primary_suppression == 0 & stage5_structural_secondary == 0

* A related hospital count decision also protects its directly linked rate and
* hospital-plus-DCO representations.  Otherwise the newly released DCO count
* could be combined with a total to reconstruct that protected hospital count.
tempfile hospital_existing_support
preserve
    keep if metric_id == "CVD-BURDEN-001" & ///
        ascertainment_scope == "hospital_only" & age_group == "all" & ///
        statistic == "annual_count" & period_complete == 1 & ///
        stage6_existing_secondary == 1
    keep period_year event_type sex
    generate byte stage6_hosp_existing = 1
    isid period_year event_type sex
    save "`hospital_existing_support'", replace
restore
merge m:1 period_year event_type sex using "`hospital_existing_support'", nogen keep(master match)
replace stage6_hosp_existing = 0 if missing(stage6_hosp_existing)
replace stage6_existing_secondary = 1 if ///
    inlist(ascertainment_scope, "hospital_only", "hospital_plus_dco") & ///
    inlist(statistic, "annual_count", "annual_crude_rate", "annual_age_standardised_rate") & ///
    ((metric_id == "CVD-BURDEN-001" & age_group == "all") | ///
    metric_id == "CVD-INCIDENCE-001") & ///
    stage6_hosp_existing == 1 & primary_suppression == 0 & ///
    stage5_structural_secondary == 0

generate str28 stage6_protection_status = "none"
replace stage6_protection_status = "primary" if primary_suppression == 1
replace stage6_protection_status = "secondary_structural" if primary_suppression == 0 & stage5_structural_secondary == 1
replace stage6_protection_status = "secondary_existing" if primary_suppression == 0 & stage5_structural_secondary == 0 & stage6_existing_secondary == 1

replace suppression_review = 1 if stage6_protection_status != "none"

quietly count if stage6_protection_status == "primary"
local primary_rows = r(N)
quietly count if stage6_protection_status == "secondary_structural"
local structural_rows = r(N)
quietly count if stage6_protection_status == "secondary_existing"
local existing_rows = r(N)
quietly count if metric_id == "CVD-BURDEN-001" & related_suppression_review == 1 & stage6_protection_status != "secondary_existing" & primary_suppression == 0
assert r(N) == 0

save "`closure_private_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Established burden related-cell decisions retained" in 1
replace detail = "Existing burden decisions are reused and propagated to linked annual representations." in 1
replace check = "Primary protection takes precedence" in 2
replace detail = "`primary_rows' primary rows remain primary." in 2
replace check = "New and established secondary protection registered" in 3
replace detail = "`structural_rows' structural and `existing_rows' established secondary rows registered." in 3
replace check = "No numeric blanking performed" in 4
replace detail = "This remains a private review lattice awaiting further closure checks." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 6 existing-closure helper passed."

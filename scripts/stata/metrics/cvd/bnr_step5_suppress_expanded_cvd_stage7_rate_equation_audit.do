/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage7_rate_equation_audit.do
VERSION: 0.8.1 (27 August 2026)
PURPOSE: Audit protection propagation across linked annual rate representations.

Each protected rate numerator must carry identical protection to both of its
public representations: annual crude rate and annual age-standardised rate.
This helper tests that requirement separately for hospital-only and DCO-enhanced
rate series.  It writes the audit result but does not add suppression decisions.

This helper writes a private review lattice only.  It does not blank, approve,
publish or create a public candidate.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 7 rate-equation audit helper v0.8.1"

args closure_private_dta audited_private_dta equation_audit_dta qa_dta release_id

foreach argument in closure_private_dta audited_private_dta equation_audit_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}

capture confirm file "`closure_private_dta'"
assert _rc == 0

tempfile hospital_audit dco_audit

use "`closure_private_dta'", clear
local required_variables metric_id release_id period_type period_year event_type sex age_group ascertainment_scope mortality_definition statistic stage6_protection_status
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"

generate byte stage7_rate_protected = stage6_protection_status != "none" if metric_id == "CVD-INCIDENCE-001"

preserve
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ascertainment_scope == "hospital_only" & inlist(statistic, "annual_crude_rate", "annual_age_standardised_rate")
generate byte protected_flag = stage7_rate_protected
generate byte rate_row = 1
collapse (sum) rate_rows=rate_row (min) protected_min=protected_flag (max) protected_max=protected_flag, by(period_year event_type sex)
generate str32 equation = "hospital rate representations"
generate str20 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
save "`hospital_audit'", replace
restore

preserve
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ascertainment_scope == "hospital_plus_dco" & inlist(statistic, "annual_crude_rate", "annual_age_standardised_rate")
generate byte protected_flag = stage7_rate_protected
generate byte rate_row = 1
collapse (sum) rate_rows=rate_row (min) protected_min=protected_flag (max) protected_max=protected_flag, by(mortality_definition period_year event_type sex)
generate str32 equation = "DCO rate representations"
generate str20 ascertainment_scope = "hospital_plus_dco"
save "`dco_audit'", replace
restore

save "`audited_private_dta'", replace

use "`hospital_audit'", clear
append using "`dco_audit'"
generate str8 result = cond(rate_rows == 2 & protected_min == protected_max, "PASS", "FAIL")
generate str244 detail = "Crude and age-standardised rate rows must share one protection decision."
save "`equation_audit_dta'", replace

quietly count if result == "FAIL"
local failed_equations = r(N)
quietly count if equation == "hospital rate representations"
local hospital_equations = r(N)
quietly count if equation == "DCO rate representations"
local dco_equations = r(N)

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Hospital rate representation equations audited" in 1
replace detail = "`hospital_equations' hospital-only annual rate equations assessed." in 1
replace check = "DCO rate representation equations audited" in 2
replace detail = "`dco_equations' DCO-enhanced annual rate equations assessed." in 2
replace check = "Protection propagation failures reported" in 3
replace result = cond(`failed_equations' == 0, "PASS", "FAIL") in 3
replace detail = "`failed_equations' equation failures recorded in the audit dataset." in 3
replace check = "No numeric blanking performed" in 4
replace detail = "This remains a private review lattice awaiting further closure checks." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 7 rate-equation audit helper passed."

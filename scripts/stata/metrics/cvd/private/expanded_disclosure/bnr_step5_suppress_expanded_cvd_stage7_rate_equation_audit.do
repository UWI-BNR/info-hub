/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage7_rate_equation_audit.do
VERSION: 1.1.4 (28 August 2026)
PURPOSE: Audit annual CVD count and rate protection representations.

The annual DCO amendment exposes three count terms:
  hospital-only + additional-DCO = hospital-plus-DCO.
No protected term may be recoverable from the other two. The same protection
decision also has to cover each count, crude-rate and ASR representation that
uses the relevant protected component.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 7 representation audit helper v1.1.2"

args closure_private_dta audited_private_dta equation_audit_dta qa_dta release_id

foreach argument in closure_private_dta audited_private_dta equation_audit_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}
capture confirm file "`closure_private_dta'"
assert _rc == 0

tempfile hospital_audit total_audit count_identity hospital_counts

use "`closure_private_dta'", clear
local required_variables metric_id release_id period_type period_year event_type sex age_group ascertainment_scope mortality_definition statistic value period_complete stage6_protection_status
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"
generate byte stage7_protected = stage6_protection_status != "none"
save "`audited_private_dta'", replace

* Hospital-only: established annual count plus crude and ASR must agree.
preserve
    keep if period_type == "annual" & period_complete == 1 & ///
        ascertainment_scope == "hospital_only" & ///
        ((metric_id == "CVD-BURDEN-001" & age_group == "all" & statistic == "annual_count") | ///
        (metric_id == "CVD-INCIDENCE-001" & inlist(statistic, "annual_crude_rate", "annual_age_standardised_rate")))
    generate byte representation_row = 1
    collapse (sum) representation_rows=representation_row ///
        (min) protected_min=stage7_protected (max) protected_max=stage7_protected, ///
        by(period_year event_type sex)
    generate str40 equation = "hospital annual representations"
    generate str20 mortality_definition = "not_applicable"
    generate str244 detail = "Hospital count, crude rate and ASR share one protection decision."
    generate str8 result = cond(representation_rows == 3 & protected_min == protected_max, "PASS", "FAIL")
    save "`hospital_audit'", replace
restore

* Hospital-plus-DCO: annual count, crude rate and ASR must agree by definition.
preserve
    keep if period_type == "annual" & period_complete == 1 & ///
        ascertainment_scope == "hospital_plus_dco" & ///
        ((metric_id == "CVD-BURDEN-001" & age_group == "all" & statistic == "annual_count") | ///
        (metric_id == "CVD-INCIDENCE-001" & inlist(statistic, "annual_crude_rate", "annual_age_standardised_rate")))
    generate byte representation_row = 1
    collapse (sum) representation_rows=representation_row ///
        (min) protected_min=stage7_protected (max) protected_max=stage7_protected, ///
        by(mortality_definition period_year event_type sex)
    generate str40 equation = "hospital-plus-DCO annual representations"
    generate str244 detail = "Total count, crude rate and ASR share one protection decision."
    generate str8 result = cond(representation_rows == 3 & protected_min == protected_max, "PASS", "FAIL")
    save "`total_audit'", replace
restore

* Count identity: one protected term requires at least one protected companion.
preserve
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        period_complete == 1 & ///
        ascertainment_scope == "hospital_only" & age_group == "all" & ///
        statistic == "annual_count"
    keep period_year event_type sex value stage7_protected
    rename value hospital_value
    rename stage7_protected hospital_protected
    isid period_year event_type sex
    save "`hospital_counts'", replace
restore

keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
    period_complete == 1 & ///
    inlist(ascertainment_scope, "hospital_plus_dco", "additional_dco") & ///
    age_group == "all" & statistic == "annual_count"
keep mortality_definition period_year event_type sex ascertainment_scope value stage7_protected
rename stage7_protected protect
reshape wide value protect, i(mortality_definition period_year event_type sex) j(ascertainment_scope) string
merge m:1 period_year event_type sex using "`hospital_counts'", keep(master match) nogen
assert !missing(hospital_value)
generate byte protected_terms = hospital_protected + ///
    protecthospital_plus_dco + protectadditional_dco
generate byte arithmetic_failure = abs(valuehospital_plus_dco - hospital_value - ///
    valueadditional_dco) > 0.000001
    generate str40 equation = "DCO count identity"
generate str244 detail = "Total equals hospital plus additional DCO; any protected term needs a protected companion."
generate str8 result = cond(protected_terms == 0 | protected_terms >= 2, "PASS", "FAIL")
replace result = "FAIL" if arithmetic_failure == 1
keep mortality_definition period_year event_type sex equation result detail protected_terms arithmetic_failure
save "`count_identity'", replace

use "`hospital_audit'", clear
append using "`total_audit'"
append using "`count_identity'"
save "`equation_audit_dta'", replace

quietly count if result == "FAIL"
local failed_equations = r(N)
quietly count if equation == "hospital annual representations"
local hospital_equations = r(N)
quietly count if equation == "hospital-plus-DCO annual representations"
local total_equations = r(N)
quietly count if equation == "DCO count identity"
local count_equations = r(N)

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Hospital annual representations audited" in 1
replace detail = "`hospital_equations' hospital count/crude/ASR equations assessed." in 1
replace check = "Hospital-plus-DCO annual representations audited" in 2
replace detail = "`total_equations' total count/crude/ASR equations assessed." in 2
replace check = "Three-term DCO count identities audited" in 3
replace detail = "`count_equations' hospital + additional-DCO = total identities assessed." in 3
replace check = "Protection or accounting failures reported" in 4
replace result = cond(`failed_equations' == 0, "PASS", "FAIL") in 4
replace detail = "`failed_equations' representation, complementary or arithmetic failures recorded." in 4
save "`qa_dta'", replace

if `failed_equations' > 0 {
    use "`equation_audit_dta'", clear
    noisily list mortality_definition period_year event_type sex equation detail ///
        protected_terms arithmetic_failure if result == "FAIL", noobs clean
}
assert `failed_equations' == 0
display as result "Expanded CVD Step 5 Stage 7 representation audit helper passed."

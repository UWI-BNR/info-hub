/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage9_candidate_audit.do
VERSION: 1.2.0 (28 August 2026)
PURPOSE: Audit the provisional combined candidate against its private
         protection register before integration into the Step 5 controller.

This helper confirms that every protection decision is reflected in the
candidate, existing burden comparator flags remain protected, protected numeric
fields are blank, the statistical-CI contract is intact, and no private support
or decision fields remain.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 9 candidate-audit helper v1.2.0"

args audited_private_dta candidate_dta row_audit_dta qa_dta release_id

foreach argument in audited_private_dta candidate_dta row_audit_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}

capture confirm file "`audited_private_dta'"
assert _rc == 0
capture confirm file "`candidate_dta'"
assert _rc == 0

local key_variables metric_id period_type period_year period_month event_type ///
    sex age_group ascertainment_scope statistic mortality_definition
tempfile expected_protection

use "`audited_private_dta'", clear
local private_required release_id stage6_protection_status related_suppression_review
local private_input_required `key_variables' `private_required'
foreach variable of local private_input_required {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"
isid `key_variables', missok

keep `key_variables' stage6_protection_status related_suppression_review
generate byte expected_protected = stage6_protection_status != "none"
save "`expected_protection'", replace

use "`candidate_dta'", clear
local candidate_required release_id suppression_status value numerator denominator ///
    linkage_lower_value linkage_upper_value ci_lower_value ci_upper_value ///
    ci_level ci_method
local candidate_input_required `key_variables' `candidate_required'
foreach variable of local candidate_input_required {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"
isid `key_variables', missok

local private_field_count = 0
foreach variable in sdc_policy primary_suppression_threshold primary_suppression ///
        related_primary_cells related_suppression_review suppression_review ///
        suppression_reason stage3_original_primary stage3_hospital_primary ///
        stage3_dco_primary stage5_unknown_support_present ///
        stage5_mixed_support_present stage5_structural_secondary ///
        stage6_existing_secondary stage6_hosp_existing stage6_protection_status ///
        stage7_protected {
    capture confirm variable `variable'
    if !_rc local private_field_count = `private_field_count' + 1
}

merge 1:1 `key_variables' using "`expected_protection'"
assert _merge == 3
drop _merge

generate byte candidate_protected = suppression_status != "none"
generate byte protection_failure = ///
    expected_protected == 1 & candidate_protected == 0
generate byte comparator_failure = ///
    related_suppression_review == 1 & candidate_protected == 0

generate byte numeric_failure = candidate_protected == 1 & ///
    (!missing(value) | !missing(numerator) | !missing(denominator) | ///
    !missing(linkage_lower_value) | !missing(linkage_upper_value) | ///
    !missing(ci_lower_value) | !missing(ci_upper_value))

generate byte ci_contract_failure = 0

* Rate rows always retain method/level metadata.
replace ci_contract_failure = 1 if metric_id == "CVD-INCIDENCE-001" & ///
    (ci_level != 95 | ci_method == "")

* Unprotected rates must retain their numerical CI and the central estimate
* must remain inside that interval.
replace ci_contract_failure = 1 if metric_id == "CVD-INCIDENCE-001" & ///
    candidate_protected == 0 & ///
    (missing(ci_lower_value) | missing(ci_upper_value) | ///
    ci_lower_value < 0 | ci_lower_value > value + 0.0000001 | ///
    ci_upper_value + 0.0000001 < value | ///
    ci_upper_value < ci_lower_value)

* Protected rates must not retain numerical CI limits.
replace ci_contract_failure = 1 if metric_id == "CVD-INCIDENCE-001" & ///
    candidate_protected == 1 & ///
    (!missing(ci_lower_value) | !missing(ci_upper_value))

* Non-rate rows never carry statistical-CI fields.
replace ci_contract_failure = 1 if metric_id != "CVD-INCIDENCE-001" & ///
    (!missing(ci_lower_value) | !missing(ci_upper_value) | ///
    !missing(ci_level) | ci_method != "")

generate str8 result = cond( ///
    protection_failure == 0 & comparator_failure == 0 & ///
    numeric_failure == 0 & ci_contract_failure == 0, "PASS", "FAIL")
generate str244 detail = ///
    "Candidate protection, numeric blanking and CI contract agree with the private register."

quietly count if protection_failure == 1
local protection_failures = r(N)
quietly count if comparator_failure == 1
local comparator_failures = r(N)
quietly count if numeric_failure == 1
local numeric_failures = r(N)
quietly count if ci_contract_failure == 1
local ci_contract_failures = r(N)
quietly count if result == "FAIL"
local failed_rows = r(N)

save "`row_audit_dta'", replace

clear
set obs 5
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""

replace check = "Private protection register propagated" in 1
replace result = cond(`protection_failures' == 0, "PASS", "FAIL") in 1
replace detail = "`protection_failures' protected source rows were not protected in the candidate." in 1

replace check = "Existing burden comparator decisions retained" in 2
replace result = cond(`comparator_failures' == 0, "PASS", "FAIL") in 2
replace detail = "`comparator_failures' existing comparator decisions were not protected in the candidate." in 2

replace check = "Protected numeric fields blank" in 3
replace result = cond(`numeric_failures' == 0, "PASS", "FAIL") in 3
replace detail = "`numeric_failures' protected rows retain a numeric release field, linkage bound or CI bound." in 3

replace check = "Statistical CI contract retained" in 4
replace result = cond(`ci_contract_failures' == 0, "PASS", "FAIL") in 4
replace detail = "`ci_contract_failures' candidate rows violate the statistical-CI contract." in 4

replace check = "Private fields absent from candidate" in 5
replace result = cond(`private_field_count' == 0, "PASS", "FAIL") in 5
replace detail = "`private_field_count' private support or decision fields remain in the candidate." in 5

save "`qa_dta'", replace

assert `failed_rows' == 0
assert `private_field_count' == 0

display as result "Expanded CVD Step 5 Stage 9 candidate-audit helper passed."

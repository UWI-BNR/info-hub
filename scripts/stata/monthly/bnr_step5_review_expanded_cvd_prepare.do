/*******************************************************************************
DO-FILE: bnr_step5_review_expanded_cvd_prepare.do
VERSION: 3.4.1 (29 August 2026)
PURPOSE: Prepare the combined CVD Step 5 disclosure-review candidate.
USAGE:   do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_prepare.do" 2026 1
         do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_prepare.do" 2026 1 replace

This is PREPARE only. It does not approve, create public_ready, or publish.

CHANGE 3.4.1:
  Wrap the operational run-summary display block in quietly { } so Stata
  shows the summary itself without echoing each display command.

CHANGE 3.4.0:
  - Add a concise Row audit summary worksheet rather than exposing the full
    3,300-row audit in Excel. The authoritative row-audit DTA remains
    fingerprinted review evidence.
  - Add a Step 5 PREPARE operational run summary.

CHANGE 3.3.1:
  Allow a release with zero protected candidate rows. The human-review workbook
  now writes an explicit "No protected rows" message instead of asking
  export excel to export a zero-observation dataset.

CHANGE 3.3.0:
  Require and fingerprint the Step 2 source-quarantine summary carried forward
  by Step 4, and include it in the private Step 5 review workbook.

CHANGE 3.2.0:
  Require and fingerprint the non-identifying DCO linkage review summary created
  by Step 4, and include it in the private Step 5 review workbook.
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month option
if "`release_year'" == "" | "`release_month'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")
local year = real("`release_year'")
local month = real("`release_month'")
if missing(`year') | `year' != floor(`year') | `year' < 2024 exit 198
if missing(`month') | `month' != floor(`month') | !inrange(`month', 1, 12) exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}
local year4 : display %04.0f `year'
local month2 : display %02.0f `month'
local release_id "cvd_`year4'_`month2'"
local package_dir "$BNR_STAGING/metrics/cvd/`release_id'"
local burden_dta "`package_dir'/datasets/cvd_burden_metrics_`release_id'.dta"
local rates_dta "`package_dir'/datasets/cvd_incidence_rates_`release_id'.dta"
local components_dta "`package_dir'/review/cvd_incidence_rate_components_`release_id'.dta"
local review_dir "`package_dir'/review"
local dco_summary_csv "`review_dir'/cvd_dco_linkage_review_summary_`release_id'.csv"
local quarantine_summary_csv "`review_dir'/cvd_source_quarantine_summary_`release_id'.csv"
local candidate_dta "`review_dir'/step5_candidate.dta"
local qa_dta "`review_dir'/step5_disclosure_qa.dta"
local qa_csv "`review_dir'/step5_disclosure_qa.csv"
local equation_dta "`review_dir'/step5_equation_audit.dta"
local equation_csv "`review_dir'/step5_equation_audit.csv"
local rows_dta "`review_dir'/step5_row_audit.dta"
local review_basis "`review_dir'/step5_review_basis.csv"
local review_workbook "`review_dir'/step5_review.xlsx"
local log_path "$BNR_PRIVATE_LOGS/bnr_cvd_review_prepare_`year4'`month2'.log"

foreach input_file in burden_dta rates_dta components_dta dco_summary_csv quarantine_summary_csv {
    capture confirm file "``input_file''"
    if _rc {
        display as error "Required Step 4 private calculation/review product not found: ``input_file''"
        exit 601
    }
}
foreach output_file in candidate_dta qa_dta qa_csv equation_dta equation_csv rows_dta review_basis review_workbook {
    capture confirm file "``output_file''"
    if !_rc & !`replace_existing' exit 602
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close step5
log using "`log_path'", text replace name(step5)

do "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd.do" ///
    "`burden_dta'" "`rates_dta'" "`components_dta'" "`candidate_dta'" ///
    "`qa_dta'" "`equation_dta'" "`rows_dta'" "`release_id'"

use "`qa_dta'", clear
quietly count
local qa_total = r(N)
quietly count if result == "PASS"
local qa_pass = r(N)
quietly count if result != "PASS"
assert r(N) == 0
export delimited using "`qa_csv'", replace

use "`equation_dta'", clear
quietly count
local equation_total = r(N)
quietly count if result != "PASS"
local equation_failures = r(N)
export delimited using "`equation_csv'", replace

* Record the exact private candidate and QA evidence supplied for human review.
tempfile basis_dta
tempname basis_handle
postfile `basis_handle' str32 file_role str244 file_path double file_size double checksum using "`basis_dta'", replace
foreach item in candidate_dta qa_csv equation_csv rows_dta dco_summary_csv quarantine_summary_csv {
    quietly checksum "``item''"
    post `basis_handle' ("`item'") ("``item''") (r(filelen)) (r(checksum))
}
postclose `basis_handle'

use "`basis_dta'", clear
format file_size checksum %20.0f
export delimited using "`review_basis'", replace

* This concise workbook is private review evidence, not a public output.
clear
set obs 11
generate str40 review_item = ""
generate str244 detail = ""

replace review_item = "Review status" in 1
replace detail = "READY FOR HUMAN REVIEW" in 1

replace review_item = "Release" in 2
replace detail = "`release_id'" in 2

replace review_item = "Candidate" in 3
replace detail = "step5_candidate.dta" in 3

replace review_item = "Disclosure QA" in 4
replace detail = "All checks must be PASS before approval." in 4

replace review_item = "Equation audit" in 5
replace detail = "Review additive, comparator and rate-equation closure." in 5

replace review_item = "Row audit" in 6
replace detail = "See Row audit summary below. The detailed row audit remains a separate fingerprinted DTA." in 6

replace review_item = "DCO linkage review" in 7
replace detail = "Review the aggregate summary below. The identifiable DCO worklist remains under BNR_PRIVATE linkage/review." in 7

replace review_item = "Source quarantine" in 8
replace detail = "Review the aggregate Step 2 quarantine summary below. The detailed quarantine report remains in the private derived release folder." in 8

replace review_item = "Fingerprint register" in 9
replace detail = "step5_review_basis.csv identifies the exact reviewed files." in 9

replace review_item = "If corrections are needed" in 10
replace detail = "Correct the authoritative source or code and rerun. Do not treat edits to generated review workbooks as source corrections." in 10

replace review_item = "If not approved" in 11
replace detail = "Do not edit generated files; correct the earlier source or code and rerun." in 11

export excel using "`review_workbook'", sheet("Review") firstrow(variables) replace

* Supporting review sheets keep the machine-readable evidence visible in the
* workbook without changing the authoritative DTA and CSV review artefacts.
use "`qa_dta'", clear
export excel using "`review_workbook'", sheet("Disclosure QA") firstrow(variables) sheetreplace

use "`equation_dta'", clear
export excel using "`review_workbook'", sheet("Equation audit") firstrow(variables) sheetreplace

* Keep the workbook concise: summarise the row audit rather than exporting all
* candidate rows. The full row-audit DTA remains authoritative and fingerprinted.
use "`rows_dta'", clear
quietly count
local row_audit_total = r(N)
quietly count if expected_protected == 1
local row_expected_protected = r(N)
quietly count if candidate_protected == 1
local row_final_protected = r(N)
quietly count if protection_failure == 1
local row_protection_failures = r(N)
quietly count if comparator_failure == 1
local row_comparator_failures = r(N)
quietly count if numeric_failure == 1
local row_numeric_failures = r(N)
quietly count if ci_contract_failure == 1
local row_ci_failures = r(N)
quietly count if linkage_contract_failure == 1
local row_linkage_failures = r(N)
quietly count if exception_note_failure == 1
local row_note_failures = r(N)
quietly count if result != "PASS"
local row_failed = r(N)

clear
set obs 10
generate str64 review_check = ""
generate str8 status = ""
generate str244 detail = ""
replace review_check = "Candidate rows audited" in 1
replace status = "INFO" in 1
replace detail = "`row_audit_total' candidate rows were audited against the private protection register." in 1
replace review_check = "Expected protected rows" in 2
replace status = "INFO" in 2
replace detail = "`row_expected_protected' rows were expected to be protected before candidate projection." in 2
replace review_check = "Final protected rows" in 3
replace status = "INFO" in 3
replace detail = "`row_final_protected' candidate rows remain protected after the approved release rules." in 3
replace review_check = "Protection propagation failures" in 4
replace status = cond(`row_protection_failures' == 0, "PASS", "FAIL") in 4
replace detail = "`row_protection_failures' protected source rows were not protected in the candidate." in 4
replace review_check = "Comparator protection failures" in 5
replace status = cond(`row_comparator_failures' == 0, "PASS", "FAIL") in 5
replace detail = "`row_comparator_failures' comparator decisions were not retained." in 5
replace review_check = "Protected numeric-field failures" in 6
replace status = cond(`row_numeric_failures' == 0, "PASS", "FAIL") in 6
replace detail = "`row_numeric_failures' protected rows retained a numeric release field or interval bound." in 6
replace review_check = "Statistical CI contract failures" in 7
replace status = cond(`row_ci_failures' == 0, "PASS", "FAIL") in 7
replace detail = "`row_ci_failures' candidate rows violated the statistical-CI contract." in 7
replace review_check = "DCO linkage-bound failures" in 8
replace status = cond(`row_linkage_failures' == 0, "PASS", "FAIL") in 8
replace detail = "`row_linkage_failures' approved national DCO rows violated the linkage-bound contract." in 8
replace review_check = "National DCO note failures" in 9
replace status = cond(`row_note_failures' == 0, "PASS", "FAIL") in 9
replace detail = "`row_note_failures' approved national DCO rows lacked the generic aggregate-release note." in 9
replace review_check = "Overall row-audit failures" in 10
replace status = cond(`row_failed' == 0, "PASS", "FAIL") in 10
replace detail = "`row_failed' candidate rows failed one or more row-audit checks." in 10
export excel using "`review_workbook'", sheet("Row audit summary") firstrow(variables) sheetreplace

use "`candidate_dta'", clear
quietly count
local candidate_rows = r(N)
quietly count if suppression_status != "none"
local protected_rows = r(N)
keep if suppression_status != "none"
if _N > 0 {
    export excel using "`review_workbook'", sheet("Protected worklist") firstrow(variables) sheetreplace
}
else {
    clear
    set obs 1
    generate str40 review_item = "Protected worklist"
    generate str244 detail = "No protected candidate rows in this release."
    export excel using "`review_workbook'", sheet("Protected worklist") firstrow(variables) sheetreplace
}

import delimited using "`dco_summary_csv'", varnames(1) clear
quietly summarize candidate_n if review_required == 1, meanonly
local dco_review_n = 0
if r(N) > 0 local dco_review_n = r(mean) * r(N)
export excel using "`review_workbook'", sheet("DCO linkage summary") firstrow(variables) sheetreplace

import delimited using "`quarantine_summary_csv'", varnames(1) clear
quietly count
assert r(N) == 1
quietly levelsof quarantine_status, local(quarantine_status) clean
local quarantine_n = quarantined_events[1]
export excel using "`review_workbook'", sheet("Source quarantine") firstrow(variables) sheetreplace

import delimited using "`review_basis'", varnames(1) clear
quietly count
local fingerprint_files = r(N)
export excel using "`review_workbook'", sheet("Fingerprint register") firstrow(variables) sheetreplace

local candidate_display : display %12.0fc `candidate_rows'
local protected_display : display %12.0fc `protected_rows'
local qa_pass_display : display %12.0fc `qa_pass'
local qa_total_display : display %12.0fc `qa_total'
local equation_fail_display : display %12.0fc `equation_failures'
local dco_review_display : display %12.0fc `dco_review_n'
local quarantine_display : display %12.0fc `quarantine_n'
local fingerprint_display : display %12.0fc `fingerprint_files'

display as result "Expanded CVD Step 5 PREPARE passed."

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 5 PREPARE: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:                 Completed successfully"
noisily display as text   "  Script version:             3.4.1"
noisily display as text   "  Selected release:           `year4'-`month2'"
noisily display as text   "  Candidate rows:             `candidate_display'"
noisily display as text   "  Protected candidate rows:   `protected_display'"
noisily display as text   "  Disclosure QA checks:       `qa_pass_display' PASS / `qa_total_display'"
noisily display as text   "  Equation audit failures:    `equation_fail_display'"
noisily display as text   "  DCO records for review:     `dco_review_display'"
noisily display as text   "  Quarantine status:          `quarantine_status'"
noisily display as text   "  Quarantined events:         `quarantine_display'"
noisily display as text   "  Fingerprinted evidence:     `fingerprint_display' files"
noisily display as text  `"  Review workbook:            `review_workbook'"'
noisily display as text  `"  Review basis register:      `review_basis'"'
noisily display as text  `"  Private log:                `log_path'"'
noisily display as text   "  Next step:                  Human review, then Step 5 APPROVE."
noisily display as result "============================================================================="
}

log close step5

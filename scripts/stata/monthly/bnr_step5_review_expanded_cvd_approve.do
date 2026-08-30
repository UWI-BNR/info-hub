/*******************************************************************************
DO-FILE: bnr_step5_review_expanded_cvd_approve.do
VERSION: 3.3.1 (29 August 2026)
PURPOSE: Verify the reviewed combined CVD candidate and create public_ready.
USAGE:   do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_approve.do" 2026 1 "<actual authorised name>" "BNR Analyst"

This controller never promotes files to outputs/public or the website.

CHANGE 3.3.1:
  Wrap the operational run-summary display block in quietly { } so Stata
  shows the summary itself without echoing each display command.

CHANGE 3.3.0:
  - Reject common placeholder approver names before approval can be recorded.
  - Write distinct release-stamped and current metadata identifiers while
    retaining the source release identifier in current metadata.
  - Add a concise operational run summary after successful approval.
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month approver_name approver_role option
if "`release_year'" == "" | "`release_month'" == "" | "`approver_name'" == "" | "`approver_role'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")
local year = real("`release_year'")
local month = real("`release_month'")
if missing(`year') | `year' != floor(`year') | `year' < 2024 exit 198
if missing(`month') | `month' != floor(`month') | !inrange(`month', 1, 12) exit 198

local approver_name_clean = strtrim("`approver_name'")
local approver_name_lower = lower("`approver_name_clean'")
if inlist("`approver_name_lower'", "full name", "actual approver name", "approver name", "your name", "<actual authorised name>") {
    display as error "APPROVE requires the actual authorised approver name, not a placeholder."
    exit 198
}

local approver_role_clean = strtrim("`approver_role'")
local role_lower = lower("`approver_role_clean'")
if !inlist("`role_lower'", "bnr lead", "bnr analyst", "bnr developer") exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}
local year4 : display %04.0f `year'
local month2 : display %02.0f `month'
local release_id "cvd_`year4'_`month2'"
local package_id "cvd_metrics_`release_id'"
local package_dir "$BNR_STAGING/metrics/cvd/`release_id'"
local review_dir "`package_dir'/review"
local candidate_dta "`review_dir'/step5_candidate.dta"
local qa_csv "`review_dir'/step5_disclosure_qa.csv"
local equation_csv "`review_dir'/step5_equation_audit.csv"
local rows_dta "`review_dir'/step5_row_audit.dta"
local basis_csv "`review_dir'/step5_review_basis.csv"
local workbook "`review_dir'/step5_review.xlsx"
local ready_dir "`package_dir'/public_ready"
local ready_data "`ready_dir'/datasets"
local ready_meta "`ready_dir'/metadata"
local public_dta "`ready_data'/cvd_metrics_`release_id'.dta"
local public_csv "`ready_data'/cvd_metrics_`release_id'.csv"
local current_dta "`ready_data'/cvd_metrics_current.dta"
local current_csv "`ready_data'/cvd_metrics_current.csv"
local release_yml "`ready_meta'/cvd_metrics_`release_id'.yml"
local current_yml "`ready_meta'/cvd_metrics_current.yml"
local package_yml "`ready_meta'/metric_package.yml"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"
foreach input_file in candidate_dta qa_csv equation_csv rows_dta basis_csv workbook {
    capture confirm file "``input_file''"
    if _rc exit 601
}

* A prior approved package is immutable. Files without approval.yml are an
* incomplete local attempt and are safely rebuilt from the reviewed candidate.
capture confirm file "`approval'"
local approval_exists = (_rc == 0)
if !`approval_exists' | `replace_existing' {
    capture erase "`public_dta'"
    capture erase "`public_csv'"
    capture erase "`current_dta'"
    capture erase "`current_csv'"
    capture erase "`release_yml'"
    capture erase "`current_yml'"
    capture erase "`package_yml'"
    capture erase "`manifest'"
    capture erase "`approval'"
}
foreach output_file in public_dta public_csv current_dta current_csv release_yml current_yml package_yml manifest approval {
    capture confirm file "``output_file''"
    if !_rc exit 602
}

* Verify every saved review fingerprint before the candidate can be approved.
import delimited using "`basis_csv'", varnames(1) clear
foreach required_variable in file_role file_path file_size checksum {
    capture confirm variable `required_variable'
    if _rc exit 111
}
quietly count
local evidence_rows = r(N)
forvalues row = 1/`evidence_rows' {
    local file_to_check = file_path[`row']
    quietly checksum "`file_to_check'"
    if r(filelen) != file_size[`row'] | r(checksum) != checksum[`row'] exit 459
}

import delimited using "`qa_csv'", varnames(1) clear
capture confirm variable result
if _rc exit 111
quietly count
local qa_checks = r(N)
quietly count if result != "PASS"
assert r(N) == 0

capture mkdir "`ready_dir'"
capture mkdir "`ready_data'"
capture mkdir "`ready_meta'"
use "`candidate_dta'", clear
quietly count
local candidate_rows = r(N)
quietly count if suppression_status != "none"
local protected_rows = r(N)
label data "BNR combined CVD metrics"
export delimited using "`public_csv'", replace
save "`public_dta'", replace
export delimited using "`current_csv'", replace
save "`current_dta'", replace

tempname metadata_handle
file open `metadata_handle' using "`release_yml'", write text replace
file write `metadata_handle' "schema: bnr_cvd_public_metric_v2" _n
file write `metadata_handle' "release_id: `release_id'" _n
file write `metadata_handle' "status: approved" _n
file write `metadata_handle' "dataset: cvd_metrics_`release_id'" _n
file close `metadata_handle'

file open `metadata_handle' using "`current_yml'", write text replace
file write `metadata_handle' "schema: bnr_cvd_public_metric_v2" _n
file write `metadata_handle' "release_id: `release_id'" _n
file write `metadata_handle' "status: approved" _n
file write `metadata_handle' "dataset: cvd_metrics_current" _n
file write `metadata_handle' "source_release_dataset: cvd_metrics_`release_id'" _n
file close `metadata_handle'

file open `metadata_handle' using "`package_yml'", write text replace
file write `metadata_handle' "package_id: `package_id'" _n
file write `metadata_handle' "release_id: `release_id'" _n
file write `metadata_handle' "status: approved" _n
file write `metadata_handle' "metric_family: combined_cvd_metrics" _n
file close `metadata_handle'

tempname manifest_handle
file open `manifest_handle' using "`manifest'", write text replace
file write `manifest_handle' "file_path,file_size,checksum" _n
quietly checksum "`public_dta'"
local dta_size = r(filelen)
local dta_checksum = r(checksum)
file write `manifest_handle' "datasets/cvd_metrics_`release_id'.dta,`dta_size',`dta_checksum'" _n
quietly checksum "`public_csv'"
local csv_size = r(filelen)
local csv_checksum = r(checksum)
file write `manifest_handle' "datasets/cvd_metrics_`release_id'.csv,`csv_size',`csv_checksum'" _n
quietly checksum "`current_dta'"
local current_dta_size = r(filelen)
local current_dta_checksum = r(checksum)
file write `manifest_handle' "datasets/cvd_metrics_current.dta,`current_dta_size',`current_dta_checksum'" _n
quietly checksum "`current_csv'"
local current_csv_size = r(filelen)
local current_csv_checksum = r(checksum)
file write `manifest_handle' "datasets/cvd_metrics_current.csv,`current_csv_size',`current_csv_checksum'" _n
quietly checksum "`release_yml'"
local release_yml_size = r(filelen)
local release_yml_checksum = r(checksum)
file write `manifest_handle' "metadata/cvd_metrics_`release_id'.yml,`release_yml_size',`release_yml_checksum'" _n
quietly checksum "`current_yml'"
local current_yml_size = r(filelen)
local current_yml_checksum = r(checksum)
file write `manifest_handle' "metadata/cvd_metrics_current.yml,`current_yml_size',`current_yml_checksum'" _n
quietly checksum "`package_yml'"
local package_yml_size = r(filelen)
local package_yml_checksum = r(checksum)
file write `manifest_handle' "metadata/metric_package.yml,`package_yml_size',`package_yml_checksum'" _n
file close `manifest_handle'

quietly checksum "`manifest'"
local manifest_size = r(filelen)
local manifest_checksum = r(checksum)
local approved_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
tempname approval_handle
file open `approval_handle' using "`approval'", write text replace
file write `approval_handle' "schema: bnr_approval_v1" _n
file write `approval_handle' "status: approved" _n
file write `approval_handle' "package_id: `package_id'" _n
file write `approval_handle' "release_id: `release_id'" _n
file write `approval_handle' "metric_family: combined_cvd_metrics" _n
file write `approval_handle' "approved_by: `approver_name_clean'" _n
file write `approval_handle' "approved_role: `approver_role_clean'" _n
file write `approval_handle' "approved_date: `approved_date'" _n
file write `approval_handle' "review_standard: bnr_metric_review_v1" _n
file write `approval_handle' "disclosure_policy: bnr_sdc_v1" _n
file write `approval_handle' "disclosure_check: passed" _n
file write `approval_handle' "public_ready_manifest: public_manifest.csv" _n
file write `approval_handle' "manifest_size: `manifest_size'" _n
file write `approval_handle' "manifest_checksum: `manifest_checksum'" _n
file write `approval_handle' "promotion_status: pending_step_6" _n
file close `approval_handle'

local candidate_display : display %12.0fc `candidate_rows'
local protected_display : display %12.0fc `protected_rows'
local qa_display : display %12.0fc `qa_checks'
local manifest_files 7

display as result "Expanded CVD Step 5 APPROVE passed."

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 5 APPROVE: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:                 Approved successfully"
noisily display as text   "  Script version:             3.3.1"
noisily display as text   "  Selected release:           `year4'-`month2'"
noisily display as text  `"  Approved by:                `approver_name_clean'"'
noisily display as text  `"  Approved role:              `approver_role_clean'"'
noisily display as text   "  Candidate rows approved:    `candidate_display'"
noisily display as text   "  Protected rows approved:    `protected_display'"
noisily display as text   "  Disclosure QA checks:       `qa_display' PASS"
noisily display as text   "  Manifest files:             `manifest_files'"
noisily display as text  `"  Public-ready folder:        `ready_dir'"'
noisily display as text  `"  Approval receipt:           `approval'"'
noisily display as text   "  Promotion status:           Pending Step 6"
noisily display as text   "  Next step:                  Publish approved package (Step 6)."
noisily display as result "============================================================================="
}

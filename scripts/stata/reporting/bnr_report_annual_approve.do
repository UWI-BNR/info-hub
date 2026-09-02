/*******************************************************************************
DO-FILE: bnr_report_annual_approve.do
VERSION: 0.3.0 (2 September 2026)
PURPOSE: Approve an annual CVD report candidate through the shared control.
*******************************************************************************/

version 19
clear all
set more off

args report_year report_version approver_name approver_role option
if "`report_year'" == "" | "`report_version'" == "" | ///
        "`approver_name'" == "" | "`approver_role'" == "" exit 198
if "`option'" != "" {
    noisily display as error "Approval receipts cannot be replaced. Delete an incomplete test receipt first, then rerun without replace."
    exit 198
}
local year_num = real("`report_year'")
local version_num = real("`report_version'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 exit 198
if missing(`version_num') | `version_num' != floor(`version_num') | `version_num' < 1 exit 198

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO BNR_STATA {
    if "$`path_name'" == "" exit 198
}

local year4 : display %04.0f `year_num'
local report_id "bnr_cvd_annual_report_`year4'_v`version_num'"
local package_dir "$BNR_REPO/outputs/staging/reports/cvd/annual/`year4'/`report_id'"
local candidate_dir "`package_dir'/candidate"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/`report_id'.qmd"
local ready_dir "`package_dir'/public_ready"
local approval "`ready_dir'/approval.yml"
capture mkdir "`package_dir'"
capture mkdir "`ready_dir'"

do "$BNR_STATA/reporting/bnr_report_approve_candidate.do" ///
    "`candidate_pdf'" "`candidate_qmd'" "`approval'" "`report_id'" ///
    "annual_cvd_report" "report_year" "`year4'" "`version_num'" ///
    "`approver_name'" "`approver_role'"

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT: APPROVAL SUMMARY"
noisily display as text   "  Run status:              Candidate approved"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Approved by:             `approver_name'"'
noisily display as text  `"  Approval receipt:        `approval'"'
noisily display as text   "  Next step:               Publish the approved candidate."
noisily display as result "============================================================================="
}

/*******************************************************************************
DO-FILE: bnr_report_approve_candidate.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Shared staged approval control for a finished report candidate.

This helper owns only approval mechanics. Report-specific wrappers supply the
candidate PDF/QMD paths, report identity and staged approval location.
*******************************************************************************/

version 19
clear all
set more off

args candidate_pdf candidate_qmd approval report_id report_type period_key period_value ///
    report_version approver_name approver_role
if "`candidate_pdf'" == "" | "`candidate_qmd'" == "" | "`approval'" == "" | ///
        "`report_id'" == "" | "`report_type'" == "" | "`period_key'" == "" | ///
        "`period_value'" == "" | "`report_version'" == "" | ///
        "`approver_name'" == "" | "`approver_role'" == "" exit 198

local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | `version_num' < 1 exit 198
local approver_name_clean = strtrim("`approver_name'")
local approver_name_lower = lower("`approver_name_clean'")
if "`approver_name_lower'" == "" | inlist("`approver_name_lower'", "full name", "actual approver name", "approver name", "your name", "<actual authorised name>") exit 198
local approver_role_clean = strtrim("`approver_role'")
local approver_role_lower = lower("`approver_role_clean'")
if !inlist("`approver_role_lower'", "bnr lead", "bnr analyst", "bnr developer") exit 198

foreach candidate_file in candidate_pdf candidate_qmd {
    capture confirm file "``candidate_file''"
    if _rc {
        noisily display as error "Candidate file is missing: ``candidate_file''"
        noisily display as error "Build the report candidate before seeking approval."
        exit 601
    }
}
capture confirm file "`approval'"
if !_rc {
    noisily display as error "An approval receipt already exists: `approval'"
    noisily display as error "Approval receipts are immutable. Use a new report version, or remove only an incomplete test receipt."
    exit 602
}

quietly checksum "`candidate_pdf'"
local pdf_size = r(filelen)
local pdf_checksum = r(checksum)
quietly checksum "`candidate_qmd'"
local qmd_size = r(filelen)
local qmd_checksum = r(checksum)
local approved_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local approved_time "`c(current_time)'"

tempname approval_handle
file open `approval_handle' using "`approval'", write text replace
file write `approval_handle' "schema: bnr_report_approval_v1" _n
file write `approval_handle' "status: approved" _n
file write `approval_handle' "report_id: `report_id'" _n
file write `approval_handle' "report_type: `report_type'" _n
file write `approval_handle' "`period_key': `period_value'" _n
file write `approval_handle' "report_version: v`version_num'" _n
file write `approval_handle' "approved_by: `approver_name_clean'" _n
file write `approval_handle' "approved_role: `approver_role_clean'" _n
file write `approval_handle' "approved_date: `approved_date'" _n
file write `approval_handle' "approved_time: `approved_time'" _n
file write `approval_handle' "pdf_size: `pdf_size'" _n
file write `approval_handle' "pdf_checksum: `pdf_checksum'" _n
file write `approval_handle' "qmd_size: `qmd_size'" _n
file write `approval_handle' "qmd_checksum: `qmd_checksum'" _n
file close `approval_handle'

* The expected missing-file check above can leave _rc == 601.  Explicitly
* return success only after the receipt has been completely written.
exit 0

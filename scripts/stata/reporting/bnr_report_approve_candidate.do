/*******************************************************************************
DO-FILE: bnr_report_approve_candidate.do
VERSION: 1.1.0 (10 September 2026)
PURPOSE: Create an approved, manifested report payload in public_ready.

This is a shared mechanical helper. Report-specific Step 2 wrappers supply the
candidate and public_ready directories, identity, period and review evidence.
The candidate itself is never edited. approval.yml is written last.

CHANGE 1.1.0:
  Optionally approve one companion PDF and its landing QMD in the same fixed
  payload. Existing three-file report workflows remain unchanged when the two
  optional filenames are omitted.
*******************************************************************************/

version 19
clear all
set more off

args candidate_dir ready_dir report_id report_type period_key period_value ///
    report_version approver_name approver_role confirm_candidate ///
    confirm_disclosure confirm_ready companion_pdf_name companion_qmd_name

if "`candidate_dir'" == "" | "`ready_dir'" == "" | "`report_id'" == "" | ///
        "`report_type'" == "" | "`period_key'" == "" | ///
        "`period_value'" == "" | "`report_version'" == "" | ///
        "`approver_name'" == "" | "`approver_role'" == "" {
    display as error "Report approval received incomplete arguments."
    exit 198
}

if ("`companion_pdf_name'" == "") != ("`companion_qmd_name'" == "") {
    display as error "Companion PDF and QMD filenames must be supplied together."
    exit 198
}
local has_companion = ("`companion_pdf_name'" != "")
if `has_companion' {
    foreach companion_name in companion_pdf_name companion_qmd_name {
        if strpos("``companion_name''", "/") | strpos("``companion_name''", "\") | ///
                strpos("``companion_name''", "..") | strpos("``companion_name''", ",") {
            display as error "Companion payload names must be safe filenames: ``companion_name''"
            exit 198
        }
    }
    if lower(substr("`companion_pdf_name'", strlen("`companion_pdf_name'") - 3, 4)) != ".pdf" | ///
            lower(substr("`companion_qmd_name'", strlen("`companion_qmd_name'") - 3, 4)) != ".qmd" {
        display as error "Companion filenames must end in .pdf and .qmd."
        exit 198
    }
    local companion_id = substr("`companion_pdf_name'", 1, strlen("`companion_pdf_name'") - 4)
}
local required_payload_count = 3 + (2 * `has_companion')

local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}

local approver_name_clean = strtrim("`approver_name'")
local approver_name_lower = lower("`approver_name_clean'")
if "`approver_name_lower'" == "" | ///
        inlist("`approver_name_lower'", "full name", "actual approver name", ///
        "approver name", "your name", "<actual authorised name>") {
    display as error "Enter the actual full name of the authorised approver."
    exit 198
}
if strpos("`approver_name_clean'", char(34)) | ///
        strpos("`approver_name_clean'", ":") | ///
        strpos("`approver_name_clean'", "#") {
    display as error "Approver name must not contain a double quote, colon or hash."
    exit 198
}

local approver_role_lower = lower(strtrim("`approver_role'"))
if !inlist("`approver_role_lower'", "bnr lead", "bnr analyst", ///
        "bnr developer") {
    display as error "Approver role must be BNR Lead, BNR Analyst or BNR Developer."
    exit 198
}
if "`approver_role_lower'" == "bnr lead" local approver_role_clean "BNR Lead"
if "`approver_role_lower'" == "bnr analyst" local approver_role_clean "BNR Analyst"
if "`approver_role_lower'" == "bnr developer" local approver_role_clean "BNR Developer"

if lower("`confirm_candidate'") != "candidate" | ///
        lower("`confirm_disclosure'") != "disclosure" | ///
        lower("`confirm_ready'") != "ready" {
    display as error "All three report approval confirmations are required."
    display as error "Use the Step 2 dialog and complete every review action."
    exit 198
}

local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local ready_pdf "`ready_dir'/`report_id'.pdf"
local ready_qmd "`ready_dir'/index.qmd"
local ready_metadata "`ready_dir'/report.yml"
local candidate_companion_pdf "`candidate_dir'/`companion_pdf_name'"
local candidate_companion_qmd "`candidate_dir'/`companion_qmd_name'"
local ready_companion_pdf "`ready_dir'/`companion_pdf_name'"
local ready_companion_qmd "`ready_dir'/`companion_qmd_name'"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"

foreach required_file in candidate_pdf candidate_qmd candidate_metadata {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Required candidate file is missing: ``required_file''"
        display as error "Rebuild the report candidate before approval."
        exit 601
    }
}
if `has_companion' {
    foreach required_file in candidate_companion_pdf candidate_companion_qmd {
        capture confirm file "``required_file''"
        if _rc {
            display as error "Required companion candidate file is missing: ``required_file''"
            display as error "Rebuild the complete report candidate before approval."
            exit 601
        }
    }
}

capture confirm file "`approval'"
if !_rc {
    display as error "This report package is already approved: `approval'"
    display as error "Approved packages are immutable. Build a higher version."
    exit 602
}

local metadata_report_ok 0
local metadata_type_ok 0
local metadata_period_ok 0
local metadata_version_ok 0
local metadata_companion_id_ok = !`has_companion'
local metadata_companion_qmd_ok = !`has_companion'
tempname metadata_handle
file open `metadata_handle' using "`candidate_metadata'", read text
file read `metadata_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "report_id: `report_id'" local metadata_report_ok 1
    if "`line'" == "report_type: `report_type'" local metadata_type_ok 1
    if "`line'" == "`period_key': `period_value'" local metadata_period_ok 1
    if "`line'" == "report_version: v`version_num'" local metadata_version_ok 1
    if "`line'" == "public_health_update_id: `companion_id'" local metadata_companion_id_ok 1
    if "`line'" == "public_health_update_landing_page: `companion_qmd_name'" local metadata_companion_qmd_ok 1
    file read `metadata_handle' line
}
file close `metadata_handle'
if !`metadata_report_ok' | !`metadata_type_ok' | !`metadata_period_ok' | ///
        !`metadata_version_ok' | !`metadata_companion_id_ok' | ///
        !`metadata_companion_qmd_ok' {
    display as error "Candidate report.yml does not match the selected report."
    exit 459
}

if `has_companion' {
    local companion_qmd_id_ok 0
    local companion_qmd_version_ok 0
    tempname companion_qmd_handle
    file open `companion_qmd_handle' using "`candidate_companion_qmd'", read text
    file read `companion_qmd_handle' line
    while r(eof) == 0 {
        local line = strtrim(`"`line'"')
        local line = subinstr(`"`line'"', char(34), "", .)
        if "`line'" == "report-id: `companion_id'" local companion_qmd_id_ok 1
        if "`line'" == "report-version: v`version_num'" local companion_qmd_version_ok 1
        file read `companion_qmd_handle' line
    }
    file close `companion_qmd_handle'
    if !`companion_qmd_id_ok' | !`companion_qmd_version_ok' {
        display as error "Companion landing page does not match the selected report version."
        exit 459
    }
}

* An incomplete prior attempt without approval.yml is safe to rebuild.
foreach incomplete_file in ready_pdf ready_qmd ready_metadata manifest {
    capture erase "``incomplete_file''"
}
if `has_companion' {
    capture erase "`ready_companion_pdf'"
    capture erase "`ready_companion_qmd'"
}

copy "`candidate_pdf'" "`ready_pdf'", replace
copy "`candidate_qmd'" "`ready_qmd'", replace
copy "`candidate_metadata'" "`ready_metadata'", replace
if `has_companion' {
    copy "`candidate_companion_pdf'" "`ready_companion_pdf'", replace
    copy "`candidate_companion_qmd'" "`ready_companion_qmd'", replace
}

foreach payload in ready_pdf ready_qmd ready_metadata {
    quietly checksum "``payload''"
    local `payload'_size = r(filelen)
    local `payload'_checksum = r(checksum)
}
if `has_companion' {
    foreach payload in ready_companion_pdf ready_companion_qmd {
        quietly checksum "``payload''"
        local `payload'_size = r(filelen)
        local `payload'_checksum = r(checksum)
    }
}

tempname manifest_handle
file open `manifest_handle' using "`manifest'", write text replace
file write `manifest_handle' "file_path,file_size,checksum" _n
file write `manifest_handle' "`report_id'.pdf,`ready_pdf_size',`ready_pdf_checksum'" _n
file write `manifest_handle' "index.qmd,`ready_qmd_size',`ready_qmd_checksum'" _n
file write `manifest_handle' "report.yml,`ready_metadata_size',`ready_metadata_checksum'" _n
if `has_companion' {
    file write `manifest_handle' "`companion_pdf_name',`ready_companion_pdf_size',`ready_companion_pdf_checksum'" _n
    file write `manifest_handle' "`companion_qmd_name',`ready_companion_qmd_size',`ready_companion_qmd_checksum'" _n
}
file close `manifest_handle'

quietly checksum "`manifest'"
local manifest_size = r(filelen)
local manifest_checksum = r(checksum)
local approved_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local approved_time "`c(current_time)'"

tempfile approval_temp
tempname approval_handle
file open `approval_handle' using "`approval_temp'", write text replace
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
file write `approval_handle' "review_standard: bnr_report_review_v1" _n
file write `approval_handle' "disclosure_review: completed" _n
file write `approval_handle' "candidate_reviewed: true" _n
file write `approval_handle' "publication_readiness_confirmed: true" _n
file write `approval_handle' "public_ready_manifest: public_manifest.csv" _n
file write `approval_handle' "manifest_scope: payload_files_only" _n
file write `approval_handle' "manifest_required_files: `required_payload_count'" _n
file write `approval_handle' "manifest_size: `manifest_size'" _n
file write `approval_handle' "manifest_checksum: `manifest_checksum'" _n
file write `approval_handle' "approval_scope: public_ready_payload" _n
file close `approval_handle'

copy "`approval_temp'" "`approval'", replace
quietly checksum "`approval_temp'"
local approval_size = r(filelen)
local approval_checksum = r(checksum)
quietly checksum "`approval'"
if r(filelen) != `approval_size' | r(checksum) != `approval_checksum' {
    capture erase "`approval'"
    display as error "The final approval receipt could not be verified."
    exit 459
}

* Clear any return code retained by an earlier expected capture.
capture assert 1

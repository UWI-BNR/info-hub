/*******************************************************************************
Shared publisher for an approved report candidate. Report-specific wrappers
provide the candidate, approval and website paths.
*******************************************************************************/
version 19
clear all
set more off

args candidate_pdf candidate_qmd approval report_id report_type period_key period_value ///
    report_version public_pdf site_pdf site_qmd site_metadata option
if "`candidate_pdf'" == "" | "`candidate_qmd'" == "" | "`approval'" == "" | ///
        "`report_id'" == "" | "`report_type'" == "" | "`period_key'" == "" | ///
        "`period_value'" == "" | "`report_version'" == "" | "`public_pdf'" == "" | ///
        "`site_pdf'" == "" | ///
        "`site_qmd'" == "" | "`site_metadata'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")
local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | `version_num' < 1 exit 198

foreach required_file in candidate_pdf candidate_qmd approval {
    capture confirm file "``required_file''"
    if _rc exit 601
}

local status_ok 0
local report_ok 0
local type_ok 0
local period_ok 0
local version_ok 0
local approved_by ""
local pdf_size .
local pdf_checksum .
local qmd_size .
local qmd_checksum .
tempname approval_handle
file open `approval_handle' using "`approval'", read text
file read `approval_handle' line
while r(eof) == 0 {
    local line = strtrim("`line'")
    if "`line'" == "status: approved" local status_ok 1
    if "`line'" == "report_id: `report_id'" local report_ok 1
    if "`line'" == "report_type: `report_type'" local type_ok 1
    if "`line'" == "`period_key': `period_value'" local period_ok 1
    if "`line'" == "report_version: v`version_num'" local version_ok 1
    if strpos("`line'", "approved_by:") == 1 local approved_by = strtrim(substr("`line'", 13, .))
    if strpos("`line'", "pdf_size:") == 1 local pdf_size = real(strtrim(substr("`line'", 10, .)))
    if strpos("`line'", "pdf_checksum:") == 1 local pdf_checksum = real(strtrim(substr("`line'", 14, .)))
    if strpos("`line'", "qmd_size:") == 1 local qmd_size = real(strtrim(substr("`line'", 10, .)))
    if strpos("`line'", "qmd_checksum:") == 1 local qmd_checksum = real(strtrim(substr("`line'", 14, .)))
    file read `approval_handle' line
}
file close `approval_handle'

quietly checksum "`candidate_pdf'"
if !`status_ok' | !`report_ok' | !`type_ok' | !`period_ok' | !`version_ok' | ///
        "`approved_by'" == "" | r(filelen) != `pdf_size' | r(checksum) != `pdf_checksum' exit 459
quietly checksum "`candidate_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' exit 459

foreach output_file in public_pdf site_pdf site_qmd site_metadata {
    capture confirm file "``output_file''"
    if !_rc & !`replace_existing' exit 602
}
copy "`candidate_pdf'" "`public_pdf'", replace
quietly checksum "`public_pdf'"
if r(filelen) != `pdf_size' | r(checksum) != `pdf_checksum' exit 459
copy "`candidate_pdf'" "`site_pdf'", replace
quietly checksum "`site_pdf'"
if r(filelen) != `pdf_size' | r(checksum) != `pdf_checksum' exit 459
copy "`candidate_qmd'" "`site_qmd'", replace
quietly checksum "`site_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' exit 459

tempname metadata_handle
file open `metadata_handle' using "`site_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: `report_type'" _n
file write `metadata_handle' "`period_key': `period_value'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "approved_by: `approved_by'" _n
file write `metadata_handle' "source_pdf: `report_id'.pdf" _n
file close `metadata_handle'

* The expected missing-output checks above can leave a non-zero _rc.  A
* completed copy and metadata write is an unambiguous successful return.
exit 0

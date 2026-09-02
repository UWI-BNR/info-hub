/*******************************************************************************
DO-FILE: bnr_report_test_annual_lifecycle.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Read-only verification of an annual CVD report lifecycle.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_annual_lifecycle.do" 2025 1

The test checks the exact staged annual-report candidate, its public_ready
approval receipt, public PDF, website PDF, QMD landing page and metadata.
It changes no file and does not render Quarto.
*******************************************************************************/

version 19
clear all
set more off

args report_year report_version
if "`report_year'" == "" | "`report_version'" == "" exit 198
local year_num = real("`report_year'")
local version_num = real("`report_version'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 exit 198
if missing(`version_num') | `version_num' != floor(`version_num') | `version_num' < 1 exit 198

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO {
    if "$`path_name'" == "" exit 198
}

local year4 : display %04.0f `year_num'
local report_id "bnr_cvd_annual_report_`year4'_v`version_num'"
local package_dir "$BNR_REPO/outputs/staging/reports/cvd/annual/`year4'/`report_id'"
local candidate_dir "`package_dir'/candidate"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/`report_id'.qmd"
local approval "`package_dir'/public_ready/approval.yml"
local public_dir "$BNR_REPO/outputs/public/reports/cvd/annual/`year4'"
local public_pdf "`public_dir'/`report_id'.pdf"
local site_dir "$BNR_REPO/site/downloads/files/reports/cvd/annual/`year4'"
local site_pdf "`site_dir'/`report_id'.pdf"
local site_metadata "`site_dir'/`report_id'.yml"
local site_qmd "$BNR_REPO/site/surveillance/cvd/reports/annual/`year4'/index.qmd"

foreach required_file in candidate_pdf candidate_qmd approval public_pdf site_pdf site_metadata site_qmd {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Annual lifecycle test requires: ``required_file''"
        exit 601
    }
}

quietly checksum "`candidate_pdf'"
local candidate_pdf_size = r(filelen)
local candidate_pdf_checksum = r(checksum)
quietly checksum "`public_pdf'"
assert r(filelen) == `candidate_pdf_size'
assert r(checksum) == `candidate_pdf_checksum'
quietly checksum "`site_pdf'"
assert r(filelen) == `candidate_pdf_size'
assert r(checksum) == `candidate_pdf_checksum'

quietly checksum "`candidate_qmd'"
local candidate_qmd_size = r(filelen)
local candidate_qmd_checksum = r(checksum)
quietly checksum "`site_qmd'"
assert r(filelen) == `candidate_qmd_size'
assert r(checksum) == `candidate_qmd_checksum'

* Check the staged public_ready receipt binds this exact candidate version.
local status_ok 0
local report_ok 0
local year_ok 0
local version_ok 0
local approved_by ""
local approved_pdf_size .
local approved_pdf_checksum .
local approved_qmd_size .
local approved_qmd_checksum .
tempname approval_handle
file open `approval_handle' using "`approval'", read text
file read `approval_handle' line
while r(eof) == 0 {
    local line = strtrim("`line'")
    if "`line'" == "status: approved" local status_ok 1
    if "`line'" == "report_id: `report_id'" local report_ok 1
    if "`line'" == "report_year: `year4'" local year_ok 1
    if "`line'" == "report_version: v`version_num'" local version_ok 1
    if strpos("`line'", "approved_by:") == 1 local approved_by = strtrim(substr("`line'", 13, .))
    if strpos("`line'", "pdf_size:") == 1 local approved_pdf_size = real(strtrim(substr("`line'", 10, .)))
    if strpos("`line'", "pdf_checksum:") == 1 local approved_pdf_checksum = real(strtrim(substr("`line'", 14, .)))
    if strpos("`line'", "qmd_size:") == 1 local approved_qmd_size = real(strtrim(substr("`line'", 10, .)))
    if strpos("`line'", "qmd_checksum:") == 1 local approved_qmd_checksum = real(strtrim(substr("`line'", 14, .)))
    file read `approval_handle' line
}
file close `approval_handle'
assert `status_ok' == 1
assert `report_ok' == 1
assert `year_ok' == 1
assert `version_ok' == 1
assert "`approved_by'" != ""
assert `approved_pdf_size' == `candidate_pdf_size'
assert `approved_pdf_checksum' == `candidate_pdf_checksum'
assert `approved_qmd_size' == `candidate_qmd_size'
assert `approved_qmd_checksum' == `candidate_qmd_checksum'

* Check the copied landing page and website metadata identify this report.
local qmd_report_ok 0
local qmd_version_ok 0
local qmd_type_ok 0
tempname qmd_handle
file open `qmd_handle' using "`site_qmd'", read text
file read `qmd_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "report-id: `report_id'" local qmd_report_ok 1
    if "`line'" == "report-version: v`version_num'" local qmd_version_ok 1
    if "`line'" == "report-type: Annual report" local qmd_type_ok 1
    file read `qmd_handle' line
}
file close `qmd_handle'
assert `qmd_report_ok' == 1
assert `qmd_version_ok' == 1
assert `qmd_type_ok' == 1

local metadata_report_ok 0
local metadata_version_ok 0
local metadata_pdf_ok 0
tempname metadata_handle
file open `metadata_handle' using "`site_metadata'", read text
file read `metadata_handle' line
while r(eof) == 0 {
    local line = strtrim("`line'")
    if "`line'" == "report_id: `report_id'" local metadata_report_ok 1
    if "`line'" == "report_version: v`version_num'" local metadata_version_ok 1
    if "`line'" == "source_pdf: `report_id'.pdf" local metadata_pdf_ok 1
    file read `metadata_handle' line
}
file close `metadata_handle'
assert `metadata_report_ok' == 1
assert `metadata_version_ok' == 1
assert `metadata_pdf_ok' == 1

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT: LIFECYCLE TEST SUMMARY"
noisily display as text   "  Run status:              All lifecycle checks passed"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Approved by:             `approved_by'"'
noisily display as text   "  Candidate, public and site: PDF/QMD fingerprints match"
noisily display as text   "  Metadata:                Identifier and version match"
noisily display as result "============================================================================="
}

/*******************************************************************************
DO-FILE: bnr_report_test_oneoff_lifecycle.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Read-only verification of a published one-off CVD report lifecycle.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_oneoff_lifecycle.do" workflow_test 1
*******************************************************************************/

version 19
clear all
set more off

args study_id report_version
if "`study_id'" == "" | "`report_version'" == "" {
    display as error "Enter study ID and report version."
    exit 198
}
if !regexm("`study_id'", "^[a-z][a-z0-9_]*$") {
    display as error "Study ID must use lowercase letters, numbers and underscores."
    exit 198
}
local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach required_global in BNR_REPO BNR_STAGING BNR_PUBLIC {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local report_id "bnr_cvd_oneoff_`study_id'_v`version_num'"
local stable_name "bnr_cvd_oneoff_`study_id'"
local package_dir "$BNR_STAGING/reports/cvd/studies/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local public_dir "$BNR_PUBLIC/reports/cvd/studies/`study_id'"
local site_download_dir "$BNR_REPO/site/downloads/files/reports/cvd/studies/`study_id'"
local site_page_dir "$BNR_REPO/site/surveillance/cvd/reports/studies/`study_id'"

local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local ready_pdf "`ready_dir'/`report_id'.pdf"
local ready_qmd "`ready_dir'/index.qmd"
local ready_metadata "`ready_dir'/report.yml"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"
local public_pdf "`public_dir'/`stable_name'.pdf"
local public_qmd "`public_dir'/index.qmd"
local public_metadata "`public_dir'/report.yml"
local site_pdf "`site_download_dir'/`stable_name'.pdf"
local site_metadata "`site_download_dir'/report.yml"
local site_qmd "`site_page_dir'/index.qmd"

capture confirm file "`candidate_pdf'"
if _rc exit 601
capture confirm file "`candidate_qmd'"
if _rc exit 601
capture confirm file "`candidate_metadata'"
if _rc exit 601
capture confirm file "`ready_pdf'"
if _rc exit 601
capture confirm file "`ready_qmd'"
if _rc exit 601
capture confirm file "`ready_metadata'"
if _rc exit 601
capture confirm file "`manifest'"
if _rc exit 601
capture confirm file "`approval'"
if _rc exit 601
capture confirm file "`public_pdf'"
if _rc exit 601
capture confirm file "`public_qmd'"
if _rc exit 601
capture confirm file "`public_metadata'"
if _rc exit 601
capture confirm file "`site_pdf'"
if _rc exit 601
capture confirm file "`site_metadata'"
if _rc exit 601
capture confirm file "`site_qmd'"
if _rc exit 601

quietly checksum "`candidate_pdf'"
local pdf_size = r(filelen)
local pdf_checksum = r(checksum)
quietly checksum "`ready_pdf'"
assert r(filelen) == `pdf_size'
assert r(checksum) == `pdf_checksum'
quietly checksum "`public_pdf'"
assert r(filelen) == `pdf_size'
assert r(checksum) == `pdf_checksum'
quietly checksum "`site_pdf'"
assert r(filelen) == `pdf_size'
assert r(checksum) == `pdf_checksum'

quietly checksum "`candidate_qmd'"
local qmd_size = r(filelen)
local qmd_checksum = r(checksum)
quietly checksum "`ready_qmd'"
assert r(filelen) == `qmd_size'
assert r(checksum) == `qmd_checksum'
quietly checksum "`public_qmd'"
assert r(filelen) == `qmd_size'
assert r(checksum) == `qmd_checksum'
quietly checksum "`site_qmd'"
assert r(filelen) == `qmd_size'
assert r(checksum) == `qmd_checksum'

quietly checksum "`candidate_metadata'"
local metadata_size = r(filelen)
local metadata_checksum = r(checksum)
quietly checksum "`ready_metadata'"
assert r(filelen) == `metadata_size'
assert r(checksum) == `metadata_checksum'
quietly checksum "`public_metadata'"
assert r(filelen) == `metadata_size'
assert r(checksum) == `metadata_checksum'
quietly checksum "`site_metadata'"
assert r(filelen) == `metadata_size'
assert r(checksum) == `metadata_checksum'

local metadata_report_ok 0
local metadata_study_ok 0
local metadata_version_ok 0
local metadata_pdf_ok 0
tempname metadata_handle
file open `metadata_handle' using "`public_metadata'", read text
file read `metadata_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "report_id: `report_id'" local metadata_report_ok 1
    if "`line'" == "study_id: `study_id'" local metadata_study_ok 1
    if "`line'" == "report_version: v`version_num'" local metadata_version_ok 1
    if "`line'" == "pdf_file: `stable_name'.pdf" local metadata_pdf_ok 1
    file read `metadata_handle' line
}
file close `metadata_handle'
assert `metadata_report_ok' == 1
assert `metadata_study_ok' == 1
assert `metadata_version_ok' == 1
assert `metadata_pdf_ok' == 1

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT: LIFECYCLE TEST SUMMARY"
noisily display as text   "  Run status:              All lifecycle checks passed"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text   "  Candidate/public_ready:  Exact three-file payload verified"
noisily display as text   "  Authoritative/site:      PDF, QMD and metadata fingerprints match"
noisily display as result "============================================================================="
}

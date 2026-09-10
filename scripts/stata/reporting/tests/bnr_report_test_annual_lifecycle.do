/*******************************************************************************
DO-FILE: bnr_report_test_annual_lifecycle.do
VERSION: 1.1.0 (10 September 2026)
PURPOSE: Read-only verification of the canonical annual-report lifecycle.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_annual_lifecycle.do" 2025 1
*******************************************************************************/

version 19
clear all
set more off

args report_year report_version
if "`report_year'" == "" | "`report_version'" == "" {
    display as error "Enter report year and version."
    exit 198
}
local year_num = real("`report_year'")
local version_num = real("`report_version'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Report year must be an integer of 2024 or later."
    exit 198
}
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

local year4 : display %04.0f `year_num'
local report_id "bnr_cvd_annual_report_`year4'_v`version_num'"
local stable_name "bnr_cvd_annual_report_`year4'"
local update_id "bnr_cvd_public_health_update_`year4'_v`version_num'"
local update_stable_name "bnr_cvd_public_health_update_`year4'"
local package_dir "$BNR_STAGING/reports/cvd/annual/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local public_dir "$BNR_PUBLIC/reports/cvd/annual/`year4'"
local site_download_dir "$BNR_REPO/site/downloads/files/reports/cvd/annual/`year4'"
local site_page_dir "$BNR_REPO/site/surveillance/cvd/reports/annual/`year4'"
local site_update_page_dir "$BNR_REPO/site/surveillance/cvd/reports/briefings/`year4'"

local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local candidate_update_pdf "`candidate_dir'/`update_id'.pdf"
local candidate_update_qmd "`candidate_dir'/public_health_update.qmd"
local ready_pdf "`ready_dir'/`report_id'.pdf"
local ready_qmd "`ready_dir'/index.qmd"
local ready_metadata "`ready_dir'/report.yml"
local ready_update_pdf "`ready_dir'/`update_id'.pdf"
local ready_update_qmd "`ready_dir'/public_health_update.qmd"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"
local public_pdf "`public_dir'/`stable_name'.pdf"
local public_qmd "`public_dir'/index.qmd"
local public_metadata "`public_dir'/report.yml"
local public_update_pdf "`public_dir'/`update_stable_name'.pdf"
local public_update_qmd "`public_dir'/public_health_update.qmd"
local site_pdf "`site_download_dir'/`stable_name'.pdf"
local site_metadata "`site_download_dir'/report.yml"
local site_qmd "`site_page_dir'/index.qmd"
local site_update_pdf "`site_download_dir'/`update_stable_name'.pdf"
local site_update_qmd "`site_update_page_dir'/index.qmd"

foreach required_file in candidate_pdf candidate_qmd candidate_metadata ///
        ready_pdf ready_qmd ready_metadata manifest approval public_pdf ///
        public_qmd public_metadata site_pdf site_metadata site_qmd ///
        candidate_update_pdf candidate_update_qmd ready_update_pdf ///
        ready_update_qmd public_update_pdf public_update_qmd ///
        site_update_pdf site_update_qmd {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Annual lifecycle test requires: ``required_file''"
        exit 601
    }
}

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

quietly checksum "`candidate_update_pdf'"
local update_pdf_size = r(filelen)
local update_pdf_checksum = r(checksum)
quietly checksum "`ready_update_pdf'"
assert r(filelen) == `update_pdf_size'
assert r(checksum) == `update_pdf_checksum'
quietly checksum "`public_update_pdf'"
assert r(filelen) == `update_pdf_size'
assert r(checksum) == `update_pdf_checksum'
quietly checksum "`site_update_pdf'"
assert r(filelen) == `update_pdf_size'
assert r(checksum) == `update_pdf_checksum'

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

quietly checksum "`candidate_update_qmd'"
local update_qmd_size = r(filelen)
local update_qmd_checksum = r(checksum)
quietly checksum "`ready_update_qmd'"
assert r(filelen) == `update_qmd_size'
assert r(checksum) == `update_qmd_checksum'
quietly checksum "`public_update_qmd'"
assert r(filelen) == `update_qmd_size'
assert r(checksum) == `update_qmd_checksum'
quietly checksum "`site_update_qmd'"
assert r(filelen) == `update_qmd_size'
assert r(checksum) == `update_qmd_checksum'

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

quietly checksum "`manifest'"
local manifest_size = r(filelen)
local manifest_checksum = r(checksum)
local approval_ok 0
local report_ok 0
local version_ok 0
local manifest_size_ok 0
local manifest_checksum_ok 0
local approved_by ""
tempname approval_handle
file open `approval_handle' using "`approval'", read text
file read `approval_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "status: approved" local approval_ok 1
    if "`line'" == "report_id: `report_id'" local report_ok 1
    if "`line'" == "report_version: v`version_num'" local version_ok 1
    if "`line'" == "manifest_size: `manifest_size'" local manifest_size_ok 1
    if "`line'" == "manifest_checksum: `manifest_checksum'" local manifest_checksum_ok 1
    if strpos("`line'", "approved_by:") == 1 local approved_by = strtrim(substr("`line'", 13, .))
    file read `approval_handle' line
}
file close `approval_handle'
assert `approval_ok' == 1
assert `report_ok' == 1
assert `version_ok' == 1
assert `manifest_size_ok' == 1
assert `manifest_checksum_ok' == 1
assert "`approved_by'" != ""

import delimited using "`manifest'", varnames(1) clear
quietly count
assert r(N) == 5
foreach expected_path in "`report_id'.pdf" "index.qmd" "report.yml" "`update_id'.pdf" "public_health_update.qmd" {
    quietly count if file_path == "`expected_path'"
    assert r(N) == 1
}

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

local update_qmd_report_ok 0
local update_qmd_version_ok 0
local update_qmd_type_ok 0
tempname update_qmd_handle
file open `update_qmd_handle' using "`site_update_qmd'", read text
file read `update_qmd_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "report-id: `update_id'" local update_qmd_report_ok 1
    if "`line'" == "report-version: v`version_num'" local update_qmd_version_ok 1
    if "`line'" == "report-type: Public health update" local update_qmd_type_ok 1
    file read `update_qmd_handle' line
}
file close `update_qmd_handle'
assert `update_qmd_report_ok' == 1
assert `update_qmd_version_ok' == 1
assert `update_qmd_type_ok' == 1

local metadata_report_ok 0
local metadata_version_ok 0
local metadata_pdf_ok 0
local metadata_update_pdf_ok 0
tempname metadata_handle
file open `metadata_handle' using "`site_metadata'", read text
file read `metadata_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "report_id: `report_id'" local metadata_report_ok 1
    if "`line'" == "report_version: v`version_num'" local metadata_version_ok 1
    if "`line'" == "pdf_file: `stable_name'.pdf" local metadata_pdf_ok 1
    if "`line'" == "public_health_update_pdf_file: `update_stable_name'.pdf" local metadata_update_pdf_ok 1
    file read `metadata_handle' line
}
file close `metadata_handle'
assert `metadata_report_ok' == 1
assert `metadata_version_ok' == 1
assert `metadata_pdf_ok' == 1
assert `metadata_update_pdf_ok' == 1

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT: LIFECYCLE TEST SUMMARY"
noisily display as text   "  Run status:              All lifecycle checks passed"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Approved by:             `approved_by'"'
noisily display as text   "  Candidate/public_ready:  Exact five-file payload verified"
noisily display as text   "  Authoritative/site:      Report, update, QMD and metadata fingerprints match"
noisily display as result "============================================================================="
}

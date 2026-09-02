/*******************************************************************************
DO-FILE: bnr_report_test_update_lifecycle.do
VERSION: 1.0.0 (2 September 2026)
PURPOSE: Read-only verification of a published rolling three-month CVD update.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_update_lifecycle.do" 2026 1 1
*******************************************************************************/

version 19
clear all
set more off

args report_year report_month report_version
if "`report_year'" == "" | "`report_month'" == "" | ///
        "`report_version'" == "" {
    display as error "Enter report year, report month and report version."
    exit 198
}
local year_num = real("`report_year'")
local month_num = real("`report_month'")
local version_num = real("`report_version'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Report year must be an integer of 2024 or later."
    exit 198
}
if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Report month must be an integer from 1 to 12."
    exit 198
}
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach required_global in BNR_REPO BNR_PUBLIC {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local year4 : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local report_period "`year4'-`month2'"
local report_id "bnr_cvd_update_`year4'_`month2'_v`version_num'"
local public_dir "$BNR_PUBLIC/reports/cvd/updates/`report_period'"
local public_qmd "`public_dir'/index.qmd"
local public_metadata "`public_dir'/report.yml"
local site_qmd "$BNR_REPO/site/surveillance/cvd/reports/updates/`report_period'/index.qmd"

capture confirm file "`public_qmd'"
if _rc {
    display as error "Update lifecycle test requires: `public_qmd'"
    exit 601
}
capture confirm file "`public_metadata'"
if _rc {
    display as error "Update lifecycle test requires: `public_metadata'"
    exit 601
}
capture confirm file "`site_qmd'"
if _rc {
    display as error "Update lifecycle test requires: `site_qmd'"
    exit 601
}

quietly checksum "`public_qmd'"
local qmd_size = r(filelen)
local qmd_checksum = r(checksum)
quietly checksum "`site_qmd'"
assert r(filelen) == `qmd_size'
assert r(checksum) == `qmd_checksum'

local metadata_report_ok 0
local metadata_version_ok 0
local metadata_period_ok 0
local metadata_event_ok 0
local metadata_mortality_ok 0
tempname metadata_handle
file open `metadata_handle' using "`public_metadata'", read text
file read `metadata_handle' line
while r(eof) == 0 {
    if "`line'" == "report_id: `report_id'" local metadata_report_ok 1
    if "`line'" == "report_version: v`version_num'" local metadata_version_ok 1
    if "`line'" == "report_period: `report_period'" local metadata_period_ok 1
    if strpos("`line'", "event_release_id: cvd_") == 1 local metadata_event_ok 1
    if strpos("`line'", "mortality_release_id: mort_") == 1 local metadata_mortality_ok 1
    file read `metadata_handle' line
}
file close `metadata_handle'
assert `metadata_report_ok' == 1
assert `metadata_version_ok' == 1
assert `metadata_period_ok' == 1
assert `metadata_event_ok' == 1
assert `metadata_mortality_ok' == 1

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ROLLING THREE-MONTH CVD UPDATE: LIFECYCLE TEST SUMMARY"
noisily display as text   "  Run status:              All lifecycle checks passed"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text   "  Authoritative/site:      Landing-page fingerprints match"
noisily display as text   "  Metadata:                Identifier, version and source IDs match"
noisily display as result "============================================================================="
}

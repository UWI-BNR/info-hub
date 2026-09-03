/*******************************************************************************
DO-FILE: bnr_report_test_update_lifecycle.do
VERSION: 1.1.0 (2 September 2026)
PURPOSE: Read-only verification of a published CVD update and frozen sources.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_update_lifecycle.do" 2026 1 3
*******************************************************************************/

version 19
clear all
set more off

args report_year report_month report_version
if "`report_year'" == "" | "`report_month'" == "" | "`report_version'" == "" {
    display as error "Update lifecycle test stopped: enter report year, month and version."
    exit 198
}

local year_num = real("`report_year'")
local month_num = real("`report_month'")
local version_num = real("`report_version'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Update lifecycle test stopped: year must be a whole number of 2024 or later."
    exit 198
}
if missing(`month_num') | `month_num' != floor(`month_num') | !inrange(`month_num', 1, 12) {
    display as error "Update lifecycle test stopped: month must be a whole number from 1 to 12."
    exit 198
}
if missing(`version_num') | `version_num' != floor(`version_num') | `version_num' < 1 {
    display as error "Update lifecycle test stopped: version must be a positive whole number."
    exit 198
}

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach required_global in BNR_REPO BNR_PUBLIC {
    if "$`required_global'" == "" {
        display as error "Update lifecycle test stopped: $`required_global' is not configured."
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
local public_event_snapshot "`public_dir'/data/event_release.csv"
local public_mortality_snapshot "`public_dir'/data/mortality_release.csv"

local site_dir "$BNR_REPO/site/surveillance/cvd/reports/updates/`report_period'"
local site_qmd "`site_dir'/index.qmd"
local site_event_snapshot "`site_dir'/data/event_release.csv"
local site_mortality_snapshot "`site_dir'/data/mortality_release.csv"

foreach required_file in public_qmd public_metadata public_event_snapshot ///
        public_mortality_snapshot site_qmd site_event_snapshot site_mortality_snapshot {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Update lifecycle test stopped: required file is missing."
        display as error "Expected: ``required_file''"
        exit 601
    }
}

quietly checksum "`public_qmd'"
local qmd_size = r(filelen)
local qmd_checksum = r(checksum)
quietly checksum "`site_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' {
    display as error "Update lifecycle test failed: authoritative and website QMD files differ."
    exit 459
}

quietly checksum "`public_event_snapshot'"
local event_snapshot_size = r(filelen)
local event_snapshot_checksum = r(checksum)
quietly checksum "`site_event_snapshot'"
if r(filelen) != `event_snapshot_size' | r(checksum) != `event_snapshot_checksum' {
    display as error "Update lifecycle test failed: CVD-event snapshots differ."
    exit 459
}

quietly checksum "`public_mortality_snapshot'"
local mortality_snapshot_size = r(filelen)
local mortality_snapshot_checksum = r(checksum)
quietly checksum "`site_mortality_snapshot'"
if r(filelen) != `mortality_snapshot_size' | r(checksum) != `mortality_snapshot_checksum' {
    display as error "Update lifecycle test failed: mortality snapshots differ."
    exit 459
}

local metadata_report_ok 0
local metadata_type_ok 0
local metadata_version_ok 0
local metadata_period_ok 0
local metadata_template_file_ok 0
local metadata_template_version_ok 0
local metadata_snapshot_policy_ok 0
local metadata_event_file_ok 0
local metadata_mortality_file_ok 0
local event_release ""
local mortality_release ""
local metadata_event_size .
local metadata_event_checksum .
local metadata_mortality_size .
local metadata_mortality_checksum .
local metadata_qmd_size .
local metadata_qmd_checksum .

tempname metadata_handle
file open `metadata_handle' using "`public_metadata'", read text
file read `metadata_handle' line
while r(eof) == 0 {
    local clean_line = strtrim("`line'")
    local clean_line = subinstr("`clean_line'", char(34), "", .)
    if "`clean_line'" == "report_id: `report_id'" local metadata_report_ok 1
    if "`clean_line'" == "report_type: rolling_three_month_cvd_update" local metadata_type_ok 1
    if "`clean_line'" == "report_version: v`version_num'" local metadata_version_ok 1
    if "`clean_line'" == "report_period: `report_period'" local metadata_period_ok 1
    if "`clean_line'" == "update_template_file: bnr_report_update_template.qmd" local metadata_template_file_ok 1
    if "`clean_line'" == "update_template_version: 1.0.0" local metadata_template_version_ok 1
    if "`clean_line'" == "snapshot_policy: complete_exact_release_copies" local metadata_snapshot_policy_ok 1
    if "`clean_line'" == "event_snapshot_file: data/event_release.csv" local metadata_event_file_ok 1
    if "`clean_line'" == "mortality_snapshot_file: data/mortality_release.csv" local metadata_mortality_file_ok 1
    if strpos("`clean_line'", "event_release_id: cvd_") == 1 local event_release = strtrim(substr("`clean_line'", 19, .))
    if strpos("`clean_line'", "mortality_release_id: mort_") == 1 local mortality_release = strtrim(substr("`clean_line'", 23, .))
    if strpos("`clean_line'", "event_source_size:") == 1 local metadata_event_size = real(strtrim(substr("`clean_line'", 20, .)))
    if strpos("`clean_line'", "event_source_checksum:") == 1 local metadata_event_checksum = real(strtrim(substr("`clean_line'", 24, .)))
    if strpos("`clean_line'", "mortality_source_size:") == 1 local metadata_mortality_size = real(strtrim(substr("`clean_line'", 24, .)))
    if strpos("`clean_line'", "mortality_source_checksum:") == 1 local metadata_mortality_checksum = real(strtrim(substr("`clean_line'", 28, .)))
    if strpos("`clean_line'", "landing_page_size:") == 1 local metadata_qmd_size = real(strtrim(substr("`clean_line'", 20, .)))
    if strpos("`clean_line'", "landing_page_checksum:") == 1 local metadata_qmd_checksum = real(strtrim(substr("`clean_line'", 24, .)))
    file read `metadata_handle' line
}
file close `metadata_handle'

if !`metadata_report_ok' | !`metadata_type_ok' | !`metadata_version_ok' | ///
        !`metadata_period_ok' | !`metadata_template_file_ok' | ///
        !`metadata_template_version_ok' | !`metadata_snapshot_policy_ok' | ///
        !`metadata_event_file_ok' | !`metadata_mortality_file_ok' | ///
        "`event_release'" == "" | "`mortality_release'" == "" {
    display as error "Update lifecycle test failed: report.yml is incomplete or inconsistent."
    exit 459
}
if `event_snapshot_size' != `metadata_event_size' | ///
        `event_snapshot_checksum' != `metadata_event_checksum' {
    display as error "Update lifecycle test failed: CVD-event snapshot does not match report.yml."
    exit 459
}
if `mortality_snapshot_size' != `metadata_mortality_size' | ///
        `mortality_snapshot_checksum' != `metadata_mortality_checksum' {
    display as error "Update lifecycle test failed: mortality snapshot does not match report.yml."
    exit 459
}
if `qmd_size' != `metadata_qmd_size' | `qmd_checksum' != `metadata_qmd_checksum' {
    display as error "Update lifecycle test failed: landing page does not match report.yml."
    exit 459
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ROLLING THREE-MONTH CVD UPDATE: LIFECYCLE TEST SUMMARY"
noisily display as text   "  Run status:              All lifecycle checks passed"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text   "  CVD-event snapshot:      Exact authoritative/site copies verified"
noisily display as text   "  Mortality snapshot:      Exact authoritative/site copies verified"
noisily display as text   "  Metadata:                Identity, template and fingerprints match"
noisily display as result "============================================================================="
}

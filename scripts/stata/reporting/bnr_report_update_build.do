/*******************************************************************************
DO-FILE: bnr_report_update_build.do
VERSION: 1.1.0 (2 September 2026)
PURPOSE: Publish one immutable, dated CVD surveillance-update page.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_update_build.do" 2026 01 2026 01 2026 07 1
  do "$BNR_STATA/reporting/bnr_report_update_build.do" 2026 01 2026 01 2026 07 2 replace

ARGUMENTS:
  1-2  Report year and month. These identify the stable report location.
  3-4  CVD-event release year and month.
  5-6  Mortality release year and month.
  7    Report version (a positive integer).
  8    Optional: replace. Required when a later version supersedes an existing
       report at the same stable website address.

WORKFLOW BOUNDARY:
  The central QMD template owns report design. This builder substitutes report
  metadata, freezes complete exact copies of both declared public-release CSVs,
  and publishes the dated package. It does not calculate or publish surveillance
  metrics, apply disclosure control, render Quarto, commit to Git, or deploy.

VERSION RULE:
  Once any output exists for a report period, the next build must use both an
  explicitly higher version and the replace argument. The existing version is
  never silently reused or downgraded.
*******************************************************************************/

version 19
clear all
set more off

args report_year report_month event_year event_month mortality_year mortality_month ///
    report_version option

if "`report_year'" == "" | "`report_month'" == "" | ///
        "`event_year'" == "" | "`event_month'" == "" | ///
        "`mortality_year'" == "" | "`mortality_month'" == "" | ///
        "`report_version'" == "" {
    display as error "Update build stopped: required arguments are missing."
    display as error "Supply report YYYY MM, event-release YYYY MM, mortality-release YYYY MM and version."
    exit 198
}

if "`option'" != "" & lower("`option'") != "replace" {
    display as error "Update build stopped: the final argument must be replace or omitted."
    exit 198
}
local replace_existing = (lower("`option'") == "replace")

foreach numeric_input in report_year report_month event_year event_month mortality_year ///
        mortality_month report_version {
    local value = real("``numeric_input''")
    if missing(`value') | `value' != floor(`value') {
        display as error "Update build stopped: ``numeric_input'' must be a whole number."
        exit 198
    }
}

local report_year_num = real("`report_year'")
local report_month_num = real("`report_month'")
local event_year_num = real("`event_year'")
local event_month_num = real("`event_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")
local version_num = real("`report_version'")

if `report_year_num' < 2024 | `event_year_num' < 2024 | `mortality_year_num' < 2024 {
    display as error "Update build stopped: all years must be 2024 or later."
    exit 198
}
if !inrange(`report_month_num', 1, 12) {
    display as error "Update build stopped: report month must be 1 to 12."
    exit 198
}
if !inrange(`event_month_num', 1, 12) {
    display as error "Update build stopped: event-release month must be 1 to 12."
    exit 198
}
if !inrange(`mortality_month_num', 1, 12) {
    display as error "Update build stopped: mortality-release month must be 1 to 12."
    exit 198
}
if `version_num' < 1 {
    display as error "Update build stopped: report version must be at least 1."
    exit 198
}

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO BNR_STATA BNR_PUBLIC BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" {
        display as error "Update build stopped: global path $`path_name' is not configured."
        exit 198
    }
}

local report_year4 : display %04.0f `report_year_num'
local report_month2 : display %02.0f `report_month_num'
local event_year4 : display %04.0f `event_year_num'
local event_month2 : display %02.0f `event_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'

local report_period "`report_year4'-`report_month2'"
local event_release "cvd_`event_year4'_`event_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local report_id "bnr_cvd_update_`report_year4'_`report_month2'_v`version_num'"
local template "$BNR_STATA/reporting/templates/bnr_report_update_template.qmd"
local template_version "1.0.0"

local event_csv "$BNR_PUBLIC/metrics/cvd/cvd_metrics_`event_release'.csv"
local mortality_csv "$BNR_PUBLIC/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local site_event_csv "$BNR_REPO/site/downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local site_mortality_csv "$BNR_REPO/site/downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"

local public_dir "$BNR_PUBLIC/reports/cvd/updates/`report_period'"
local public_data_dir "`public_dir'/data"
local public_qmd "`public_dir'/index.qmd"
local public_metadata "`public_dir'/report.yml"
local public_event_snapshot "`public_data_dir'/event_release.csv"
local public_mortality_snapshot "`public_data_dir'/mortality_release.csv"

local site_dir "$BNR_REPO/site/surveillance/cvd/reports/updates/`report_period'"
local site_data_dir "`site_dir'/data"
local site_qmd "`site_dir'/index.qmd"
local site_event_snapshot "`site_data_dir'/event_release.csv"
local site_mortality_snapshot "`site_data_dir'/mortality_release.csv"

local event_href "../../../../../downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local mortality_href "../../../../../downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_update_`report_id'.log"

capture confirm file "`template'"
if _rc {
    display as error "Update build stopped: central QMD template is missing."
    display as error "Expected: `template'"
    exit 601
}
capture confirm file "`event_csv'"
if _rc {
    display as error "Update build stopped: authoritative CVD-event release is missing."
    display as error "Expected: `event_csv'"
    exit 601
}
capture confirm file "`site_event_csv'"
if _rc {
    display as error "Update build stopped: website CVD-event release mirror is missing."
    display as error "Expected: `site_event_csv'"
    display as error "Rerun CVD-event workflow Step 6."
    exit 601
}
capture confirm file "`mortality_csv'"
if _rc {
    display as error "Update build stopped: authoritative mortality release is missing."
    display as error "Expected: `mortality_csv'"
    exit 601
}
capture confirm file "`site_mortality_csv'"
if _rc {
    display as error "Update build stopped: website mortality release mirror is missing."
    display as error "Expected: `site_mortality_csv'"
    display as error "Rerun mortality workflow Step 6."
    exit 601
}

quietly checksum "`event_csv'"
local event_size = r(filelen)
local event_checksum = r(checksum)
quietly checksum "`site_event_csv'"
if r(filelen) != `event_size' | r(checksum) != `event_checksum' {
    display as error "Update build stopped: authoritative and website CVD-event releases differ."
    display as error "Rerun CVD-event workflow Step 6 before creating this update."
    exit 459
}
quietly checksum "`mortality_csv'"
local mortality_size = r(filelen)
local mortality_checksum = r(checksum)
quietly checksum "`site_mortality_csv'"
if r(filelen) != `mortality_size' | r(checksum) != `mortality_checksum' {
    display as error "Update build stopped: authoritative and website mortality releases differ."
    display as error "Rerun mortality workflow Step 6 before creating this update."
    exit 459
}
quietly checksum "`template'"
local template_size = r(filelen)
local template_checksum = r(checksum)

local output_exists 0
foreach output_file in public_qmd public_metadata public_event_snapshot ///
        public_mortality_snapshot site_qmd site_event_snapshot site_mortality_snapshot {
    capture confirm file "``output_file''"
    if !_rc local output_exists 1
}

local existing_version .
local existing_report_ok 0
local existing_period_ok 0
if `output_exists' {
    capture confirm file "`public_metadata'"
    if _rc {
        display as error "Update build stopped: existing outputs have no authoritative report.yml."
        display as error "Do not overwrite an incomplete package manually. Review: `public_dir'"
        exit 459
    }

    tempname existing_metadata_handle
    file open `existing_metadata_handle' using "`public_metadata'", read text
    file read `existing_metadata_handle' line
    while r(eof) == 0 {
        local clean_line = strtrim("`line'")
        local clean_line = subinstr("`clean_line'", char(34), "", .)
        if "`clean_line'" == "report_type: rolling_three_month_cvd_update" local existing_report_ok 1
        if "`clean_line'" == "report_period: `report_period'" local existing_period_ok 1
        if strpos("`clean_line'", "report_version: v") == 1 {
            local existing_version = real(substr("`clean_line'", 18, .))
        }
        file read `existing_metadata_handle' line
    }
    file close `existing_metadata_handle'

    if `existing_report_ok' != 1 | `existing_period_ok' != 1 | missing(`existing_version') {
        display as error "Update build stopped: existing report.yml is missing or inconsistent."
        display as error "Review: `public_metadata'"
        exit 459
    }
    if `version_num' <= `existing_version' {
        display as error "Update build stopped: `report_period' already has version v`existing_version'."
        display as error "Use a strictly higher version; published version numbers are never reused."
        exit 459
    }
    if !`replace_existing' {
        display as error "Update build stopped: `report_period' already exists."
        display as error "Use a strictly higher version and add replace to supersede it."
        exit 602
    }
}

capture mkdir "$BNR_PUBLIC/reports"
capture mkdir "$BNR_PUBLIC/reports/cvd"
capture mkdir "$BNR_PUBLIC/reports/cvd/updates"
capture mkdir "`public_dir'"
capture mkdir "`public_data_dir'"
capture mkdir "$BNR_REPO/site/surveillance/cvd/reports"
capture mkdir "$BNR_REPO/site/surveillance/cvd/reports/updates"
capture mkdir "`site_dir'"
capture mkdir "`site_data_dir'"

local published_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local report_month_name : display %tmMonth ym(`report_year_num', `report_month_num')
local report_month_name = strtrim("`report_month_name'")

tempfile template_1 template_2 template_3 template_4 template_5
tempfile template_6 template_7 template_8 staged_qmd staged_metadata
tempfile staged_event_snapshot staged_mortality_snapshot

capture noisily filefilter "`template'" "`template_1'", from("@@REPORT_MONTH_NAME@@") to("`report_month_name'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: report-month substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_1'" "`template_2'", from("@@REPORT_YEAR@@") to("`report_year4'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: report-year substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_2'" "`template_3'", from("@@REPORT_DATE@@") to("`published_date'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: report-date substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_3'" "`template_4'", from("@@REPORT_ID@@") to("`report_id'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: report-identifier substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_4'" "`template_5'", from("@@REPORT_VERSION@@") to("`version_num'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: report-version substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_5'" "`template_6'", from("@@EVENT_RELEASE_ID@@") to("`event_release'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: event-release substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_6'" "`template_7'", from("@@MORTALITY_RELEASE_ID@@") to("`mortality_release'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: mortality-release substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_7'" "`template_8'", from("@@EVENT_SOURCE_HREF@@") to("`event_href'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: event-source-link substitution failed."
    exit `filter_rc'
}
capture noisily filefilter "`template_8'" "`staged_qmd'", from("@@MORTALITY_SOURCE_HREF@@") to("`mortality_href'") replace
if _rc {
    local filter_rc = _rc
    display as error "Update build stopped: mortality-source-link substitution failed."
    exit `filter_rc'
}

capture noisily copy "`event_csv'" "`staged_event_snapshot'", replace
if _rc {
    local copy_rc = _rc
    display as error "Update build stopped: the CVD-event release could not be staged."
    exit `copy_rc'
}
capture noisily copy "`mortality_csv'" "`staged_mortality_snapshot'", replace
if _rc {
    local copy_rc = _rc
    display as error "Update build stopped: the mortality release could not be staged."
    exit `copy_rc'
}

quietly checksum "`staged_event_snapshot'"
if r(filelen) != `event_size' | r(checksum) != `event_checksum' {
    display as error "Update build stopped: staged CVD-event snapshot verification failed."
    exit 459
}
quietly checksum "`staged_mortality_snapshot'"
if r(filelen) != `mortality_size' | r(checksum) != `mortality_checksum' {
    display as error "Update build stopped: staged mortality snapshot verification failed."
    exit 459
}

quietly checksum "`staged_qmd'"
local qmd_size = r(filelen)
local qmd_checksum = r(checksum)

tempname metadata_handle
file open `metadata_handle' using "`staged_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: rolling_three_month_cvd_update" _n
file write `metadata_handle' "report_period: `report_period'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "update_template_file: bnr_report_update_template.qmd" _n
file write `metadata_handle' "update_template_version: `template_version'" _n
file write `metadata_handle' "update_template_size: `template_size'" _n
file write `metadata_handle' "update_template_checksum: `template_checksum'" _n
file write `metadata_handle' "snapshot_policy: complete_exact_release_copies" _n
file write `metadata_handle' "event_release_id: `event_release'" _n
file write `metadata_handle' "event_source_size: `event_size'" _n
file write `metadata_handle' "event_source_checksum: `event_checksum'" _n
file write `metadata_handle' "event_snapshot_file: data/event_release.csv" _n
file write `metadata_handle' "mortality_release_id: `mortality_release'" _n
file write `metadata_handle' "mortality_source_size: `mortality_size'" _n
file write `metadata_handle' "mortality_source_checksum: `mortality_checksum'" _n
file write `metadata_handle' "mortality_snapshot_file: data/mortality_release.csv" _n
file write `metadata_handle' "landing_page: index.qmd" _n
file write `metadata_handle' "landing_page_size: `qmd_size'" _n
file write `metadata_handle' "landing_page_checksum: `qmd_checksum'" _n
file write `metadata_handle' "built_date: `published_date'" _n
file write `metadata_handle' "built_time: `c(current_time)'" _n
file close `metadata_handle'

capture log close bnr_report_update
log using "`private_log'", text replace name(bnr_report_update)

capture noisily copy "`staged_qmd'" "`public_qmd'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `public_qmd'"
    exit `copy_rc'
}
capture noisily copy "`staged_metadata'" "`public_metadata'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `public_metadata'"
    exit `copy_rc'
}
capture noisily copy "`staged_event_snapshot'" "`public_event_snapshot'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `public_event_snapshot'"
    exit `copy_rc'
}
capture noisily copy "`staged_mortality_snapshot'" "`public_mortality_snapshot'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `public_mortality_snapshot'"
    exit `copy_rc'
}
capture noisily copy "`staged_qmd'" "`site_qmd'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `site_qmd'"
    exit `copy_rc'
}
capture noisily copy "`staged_event_snapshot'" "`site_event_snapshot'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `site_event_snapshot'"
    exit `copy_rc'
}
capture noisily copy "`staged_mortality_snapshot'" "`site_mortality_snapshot'", replace
if _rc {
    local copy_rc = _rc
    capture log close bnr_report_update
    display as error "Update publication failed while writing: `site_mortality_snapshot'"
    exit `copy_rc'
}

quietly checksum "`public_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' {
    capture log close bnr_report_update
    display as error "Update publication failed: authoritative QMD verification failed."
    exit 459
}
quietly checksum "`site_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' {
    capture log close bnr_report_update
    display as error "Update publication failed: website QMD verification failed."
    exit 459
}
quietly checksum "`public_event_snapshot'"
if r(filelen) != `event_size' | r(checksum) != `event_checksum' {
    capture log close bnr_report_update
    display as error "Update publication failed: authoritative CVD-event snapshot verification failed."
    exit 459
}
quietly checksum "`site_event_snapshot'"
if r(filelen) != `event_size' | r(checksum) != `event_checksum' {
    capture log close bnr_report_update
    display as error "Update publication failed: website CVD-event snapshot verification failed."
    exit 459
}
quietly checksum "`public_mortality_snapshot'"
if r(filelen) != `mortality_size' | r(checksum) != `mortality_checksum' {
    capture log close bnr_report_update
    display as error "Update publication failed: authoritative mortality snapshot verification failed."
    exit 459
}
quietly checksum "`site_mortality_snapshot'"
if r(filelen) != `mortality_size' | r(checksum) != `mortality_checksum' {
    capture log close bnr_report_update
    display as error "Update publication failed: website mortality snapshot verification failed."
    exit 459
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ROLLING THREE-MONTH CVD UPDATE: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Published successfully"
noisily display as text   "  Script version:          1.1.0"
noisily display as text   "  Template version:        `template_version'"
noisily display as text   "  Report period:           `report_period'"
noisily display as text   "  Report version:          v`version_num'"
noisily display as text   "  CVD-event release:       `event_release'"
noisily display as text   "  Mortality release:       `mortality_release'"
noisily display as text  `"  Authoritative package:   `public_dir'"'
noisily display as text  `"  Frozen event source:     `public_event_snapshot'"'
noisily display as text  `"  Frozen mortality source: `public_mortality_snapshot'"'
noisily display as text  `"  Website landing page:    `site_qmd'"'
noisily display as text  `"  Private publication log: `private_log'"'
noisily display as text   "  Next step:               Run the lifecycle test, then render and review."
noisily display as result "============================================================================="
}
capture log close bnr_report_update
capture assert 1

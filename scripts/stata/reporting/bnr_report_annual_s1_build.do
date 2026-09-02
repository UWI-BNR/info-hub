/*******************************************************************************
DO-FILE: bnr_report_annual_s1_build.do
VERSION: 1.0.0 (2 September 2026)
PURPOSE: Build a private annual CVD report candidate package.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_annual_s1_build.do" 2025 2026 1 2026 7 1
  do "$BNR_STATA/reporting/bnr_report_annual_s1_build.do" 2025 2026 1 2026 7 1 replace
*******************************************************************************/

version 19
clear all
set more off

args report_year event_year event_month mortality_year mortality_month ///
    report_version option

if "`report_year'" == "" | "`event_year'" == "" | "`event_month'" == "" | ///
        "`mortality_year'" == "" | "`mortality_month'" == "" | ///
        "`report_version'" == "" {
    display as error "Enter report year, both source releases and report version."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional Step 1 argument is replace."
    exit 198
}
local replace_existing = (lower("`option'") == "replace")

foreach numeric_input in report_year event_year event_month mortality_year ///
        mortality_month report_version {
    local value = real("``numeric_input''")
    if missing(`value') | `value' != floor(`value') {
        display as error "All annual report period and version inputs must be integers."
        exit 198
    }
}
local report_year_num = real("`report_year'")
local event_year_num = real("`event_year'")
local event_month_num = real("`event_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")
local version_num = real("`report_version'")
if `report_year_num' < 2024 | `event_year_num' < 2024 | ///
        `mortality_year_num' < 2024 {
    display as error "Report and source-release years must be 2024 or later."
    exit 198
}
if !inrange(`event_month_num', 1, 12) | ///
        !inrange(`mortality_month_num', 1, 12) {
    display as error "Source-release months must be integers from 1 to 12."
    exit 198
}
if `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}

if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}
foreach required_global in BNR_REPO BNR_STATA BNR_STAGING BNR_PUBLIC ///
        BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local report_year4 : display %04.0f `report_year_num'
local event_year4 : display %04.0f `event_year_num'
local event_month2 : display %02.0f `event_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'
local event_release "cvd_`event_year4'_`event_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local report_id "bnr_cvd_annual_report_`report_year4'_v`version_num'"
local public_name "bnr_cvd_annual_report_`report_year4'"

local event_csv "$BNR_PUBLIC/metrics/cvd/cvd_metrics_`event_release'.csv"
local mortality_csv "$BNR_PUBLIC/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local site_event_csv "$BNR_REPO/site/downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local site_mortality_csv "$BNR_REPO/site/downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local interpretation "$BNR_STATA/reporting/annual/`report_year4'/bnr_report_annual_`report_year4'_interpretation.do"
local focus "$BNR_STATA/reporting/annual/`report_year4'/bnr_report_annual_`report_year4'_focus.do"

capture confirm file "`event_csv'"
if _rc {
    display as error "Required annual-report event release not found: `event_csv'"
    exit 601
}
capture confirm file "`site_event_csv'"
if _rc {
    display as error "Required website event-release mirror not found: `site_event_csv'"
    display as error "Rerun the CVD-event workflow Step 6."
    exit 601
}
capture confirm file "`mortality_csv'"
if _rc {
    display as error "Required annual-report mortality release not found: `mortality_csv'"
    exit 601
}
capture confirm file "`site_mortality_csv'"
if _rc {
    display as error "Required website mortality-release mirror not found: `site_mortality_csv'"
    display as error "Rerun the mortality workflow Step 6."
    exit 601
}
capture confirm file "`interpretation'"
if _rc {
    display as error "Annual interpretation file not found: `interpretation'"
    exit 601
}
capture confirm file "`focus'"
if _rc {
    display as error "Annual Focus On file not found: `focus'"
    exit 601
}

quietly checksum "`event_csv'"
local event_size = r(filelen)
local event_checksum = r(checksum)
quietly checksum "`site_event_csv'"
local site_event_size = r(filelen)
local site_event_checksum = r(checksum)
if `site_event_size' != `event_size' | ///
        `site_event_checksum' != `event_checksum' {
    display as error "The authoritative event release and website mirror differ."
    display as error "Rerun the CVD-event workflow Step 6 before building this report."
    exit 459
}

quietly checksum "`mortality_csv'"
local mortality_size = r(filelen)
local mortality_checksum = r(checksum)
quietly checksum "`site_mortality_csv'"
local site_mortality_size = r(filelen)
local site_mortality_checksum = r(checksum)
if `site_mortality_size' != `mortality_size' | ///
        `site_mortality_checksum' != `mortality_checksum' {
    display as error "The authoritative mortality release and website mirror differ."
    display as error "Rerun the mortality workflow Step 6 before building this report."
    exit 459
}

local package_dir "$BNR_STAGING/reports/cvd/annual/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local approval "`ready_dir'/approval.yml"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_annual_s1_`report_id'.log"
local site_pdf_href "../../../../../downloads/files/reports/cvd/annual/`report_year4'/`public_name'.pdf"

local reports_dir "$BNR_STAGING/reports"
local cvd_dir "`reports_dir'/cvd"
local annual_dir "`cvd_dir'/annual"
foreach required_dir in reports_dir cvd_dir annual_dir package_dir ///
        candidate_dir ready_dir {
    quietly mata: st_local("dir_exists", strofreal(direxists("``required_dir''")))
    if "`dir_exists'" != "1" {
        capture mkdir "``required_dir''"
        if _rc {
            display as error "Could not create annual-report directory: ``required_dir''"
            display as error "Check that BNR_STAGING is available and writable."
            exit 603
        }
    }
}

capture confirm file "`approval'"
if !_rc {
    display as error "This candidate version has already been approved: `approval'"
    display as error "Approved packages are immutable. Build a higher version."
    exit 602
}
foreach candidate_file in candidate_pdf candidate_qmd candidate_metadata {
    capture confirm file "``candidate_file''"
    if !_rc & !`replace_existing' {
        display as error "Candidate output already exists: ``candidate_file''"
        display as error "Use replace only to rebuild this unapproved candidate."
        exit 602
    }
}

capture log close bnr_report_annual_s1
log using "`private_log'", text replace name(bnr_report_annual_s1)

putpdf clear
putpdf begin, pagesize(A4) font("Arial", 10)
putpdf paragraph, halign(center)
putpdf text ("Barbados National Registry"), bold font("Arial", 18)
putpdf paragraph, halign(center)
putpdf text ("Annual cardiovascular disease report: `report_year4'"), bold font("Arial", 16)
putpdf paragraph, halign(center)
putpdf text ("Version v`version_num'"), italic
putpdf pagebreak

include "$BNR_STATA/reporting/bnr_report_annual_standard.do"
include "`interpretation'"
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 14)
putpdf paragraph
putpdf text ("`annual_interpretation_text'")

include "`focus'"
putpdf paragraph
putpdf text ("`annual_focus_title'"), bold font("Arial", 14)
putpdf paragraph
putpdf text ("`annual_focus_text'")

putpdf pagebreak
putpdf paragraph
putpdf text ("Report metadata"), bold font("Arial", 14)
putpdf paragraph
putpdf text ("Report identifier: `report_id'")
putpdf paragraph
putpdf text ("CVD-event release: `event_release'")
putpdf paragraph
putpdf text ("Mortality release: `mortality_release'")
capture noisily putpdf save "`candidate_pdf'", replace
if _rc {
    local save_rc = _rc
    capture log close bnr_report_annual_s1
    display as error "ANNUAL REPORT STEP 1 FAILED SAFELY"
    display as error "The candidate PDF could not be saved: `candidate_pdf'"
    display as error "Check the private staging path and ensure the PDF is not open."
    exit `save_rc'
}

local build_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local build_time "`c(current_time)'"
tempname qmd_handle
file open `qmd_handle' using "`candidate_qmd'", write text replace
file write `qmd_handle' "---" _n
file write `qmd_handle' `"title: "Annual CVD report: `report_year4'""' _n
file write `qmd_handle' `"description: "Annual CVD report for Barbados, including the standard surveillance section and annual Focus On chapter.""' _n
file write `qmd_handle' "date: `build_date'" _n
file write `qmd_handle' "date-modified: `build_date'" _n
file write `qmd_handle' "report-id: `report_id'" _n
file write `qmd_handle' "report-type: Annual report" _n
file write `qmd_handle' "report-version: v`version_num'" _n
file write `qmd_handle' "coverage-period: `report_year4'" _n
file write `qmd_handle' "event-release-id: `event_release'" _n
file write `qmd_handle' "mortality-release-id: `mortality_release'" _n
file write `qmd_handle' "image: /assets/images/listings/listing_mountain_coast.webp" _n
file write `qmd_handle' "image-alt: Barbados mountain coast." _n
file write `qmd_handle' "categories:" _n
file write `qmd_handle' "  - CVD" _n
file write `qmd_handle' "  - Annual report" _n
file write `qmd_handle' "format:" _n
file write `qmd_handle' "  html:" _n
file write `qmd_handle' "    toc: false" _n
file write `qmd_handle' "    page-layout: article" _n
file write `qmd_handle' "---" _n _n
file write `qmd_handle' "[Open or download the PDF report](`site_pdf_href'){.btn .btn-primary}" _n _n
file write `qmd_handle' `"<iframe src="`site_pdf_href'" title="Annual CVD report: `report_year4'" width="100%" height="900"></iframe>"' _n
file close `qmd_handle'

tempname metadata_handle
file open `metadata_handle' using "`candidate_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: annual_cvd_report" _n
file write `metadata_handle' "report_year: `report_year4'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "public_name: `public_name'" _n
file write `metadata_handle' "event_release_id: `event_release'" _n
file write `metadata_handle' "event_source_size: `event_size'" _n
file write `metadata_handle' "event_source_checksum: `event_checksum'" _n
file write `metadata_handle' "mortality_release_id: `mortality_release'" _n
file write `metadata_handle' "mortality_source_size: `mortality_size'" _n
file write `metadata_handle' "mortality_source_checksum: `mortality_checksum'" _n
file write `metadata_handle' "pdf_file: `public_name'.pdf" _n
file write `metadata_handle' "landing_page: index.qmd" _n
file write `metadata_handle' "built_date: `build_date'" _n
file write `metadata_handle' "built_time: `build_time'" _n
file close `metadata_handle'

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT STEP 1: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Candidate created"
noisily display as text   "  Script version:          1.0.0"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text   "  CVD-event release:       `event_release'"
noisily display as text   "  Mortality release:       `mortality_release'"
noisily display as text  `"  Candidate package:       `candidate_dir'"'
noisily display as text  `"  Private build log:       `private_log'"'
noisily display as text   "  Publication boundary:    Nothing approved or published"
noisily display as text   "  Next step:               Review the candidate, then run Step 2."
noisily display as result "============================================================================="
}
capture log close bnr_report_annual_s1

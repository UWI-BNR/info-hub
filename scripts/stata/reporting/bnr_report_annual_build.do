/*******************************************************************************
DO-FILE: bnr_report_annual_build.do
VERSION: 0.2.0 (2 September 2026)
PURPOSE: Build an annual CVD report candidate: PDF and Quarto landing source.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_annual_build.do" 2025 2026 1 2026 7 1

The arguments are: report year; event-release year/month; mortality-release
year/month; report version; optional replace.

WORKFLOW BOUNDARY:
  The candidate is written below outputs/staging/reports/. It is not copied to
  outputs/public/, site/downloads/ or site/surveillance/, and is therefore not
  published or rendered by this build step. A later controlled publication step
  requires approval evidence from the candidate package's public_ready area.
*******************************************************************************/

version 19
clear all
set more off

args report_year event_year event_month mortality_year mortality_month report_version option

if "`report_year'" == "" | "`event_year'" == "" | "`event_month'" == "" | ///
        "`mortality_year'" == "" | "`mortality_month'" == "" | ///
        "`report_version'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")

foreach numeric_input in report_year event_year event_month mortality_year ///
        mortality_month report_version {
    local value = real("``numeric_input''")
    if missing(`value') | `value' != floor(`value') exit 198
}

local report_year_num = real("`report_year'")
local event_year_num = real("`event_year'")
local event_month_num = real("`event_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")
local version_num = real("`report_version'")
if `report_year_num' < 2024 | `event_year_num' < 2024 | `mortality_year_num' < 2024 exit 198
if !inrange(`event_month_num', 1, 12) | !inrange(`mortality_month_num', 1, 12) exit 198
if `version_num' < 1 exit 198

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO BNR_STATA {
    if "$`path_name'" == "" exit 198
}

local report_year4 : display %04.0f `report_year_num'
local event_year4 : display %04.0f `event_year_num'
local event_month2 : display %02.0f `event_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'
local event_release "cvd_`event_year4'_`event_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local report_id "bnr_cvd_annual_report_`report_year4'_v`version_num'"

local event_csv "$BNR_REPO/site/downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local mortality_csv "$BNR_REPO/site/downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local interpretation "$BNR_STATA/reporting/annual/`report_year4'/bnr_report_annual_`report_year4'_interpretation.do"
local focus "$BNR_STATA/reporting/annual/`report_year4'/bnr_report_annual_`report_year4'_focus.do"

foreach required_file in event_csv mortality_csv interpretation focus {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Required annual-report input not found: ``required_file''"
        exit 601
    }
}

local package_dir "$BNR_REPO/outputs/staging/reports/cvd/annual/`report_year4'/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local pdf_candidate "`candidate_dir'/`report_id'.pdf"
local qmd_candidate "`candidate_dir'/`report_id'.qmd"
local approval "`ready_dir'/approval.yml"
local site_pdf_href "../../../../../downloads/files/reports/cvd/annual/`report_year4'/`report_id'.pdf"

capture mkdir "$BNR_REPO/outputs/staging/reports"
capture mkdir "$BNR_REPO/outputs/staging/reports/cvd"
capture mkdir "$BNR_REPO/outputs/staging/reports/cvd/annual"
capture mkdir "$BNR_REPO/outputs/staging/reports/cvd/annual/`report_year4'"
capture mkdir "`package_dir'"
capture mkdir "`candidate_dir'"
capture mkdir "`ready_dir'"
capture confirm file "`approval'"
if !_rc {
    display as error "This candidate version has already been approved: `approval'"
    display as error "Approved candidates are immutable. Build a new report version instead."
    exit 602
}
foreach candidate_file in pdf_candidate qmd_candidate {
    capture confirm file "``candidate_file''"
    if !_rc & !`replace_existing' {
        display as error "Candidate already exists: ``candidate_file''"
        exit 602
    }
}

* The standard section is intentionally minimal for the walking skeleton.
* It names immutable public sources but does not calculate a new metric here.
putpdf clear
putpdf begin, pagesize(A4) font("Arial", 10)
putpdf paragraph, halign(center)
putpdf text ("Barbados National Registry"), bold font("Arial", 18)
putpdf paragraph, halign(center)
putpdf text ("Annual cardiovascular disease report: `report_year4'"), bold font("Arial", 16)
putpdf paragraph, halign(center)
putpdf text ("Candidate version v`version_num'"), italic
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
putpdf save "`pdf_candidate'", replace

local published_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
tempname qmd_handle
file open `qmd_handle' using "`qmd_candidate'", write text replace
file write `qmd_handle' "---" _n
file write `qmd_handle' `"title: "Annual CVD report: `report_year4'""' _n
file write `qmd_handle' `"description: "Annual CVD report for Barbados, including the standard surveillance section and annual Focus On chapter.""' _n
file write `qmd_handle' "date: `published_date'" _n
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

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT: CANDIDATE BUILD SUMMARY"
noisily display as text   "  Run status:              Candidate created"
noisily display as text   "  Script version:          0.2.0"
noisily display as text   "  Report year:             `report_year4'"
noisily display as text   "  Candidate version:       v`version_num'"
noisily display as text   "  CVD-event release:       `event_release'"
noisily display as text   "  Mortality release:       `mortality_release'"
noisily display as text  `"  Candidate PDF:           `pdf_candidate'"'
noisily display as text  `"  Landing-page source:     `qmd_candidate'"'
noisily display as text   "  Next step:               Review candidate; do not publish it yet."
noisily display as result "============================================================================="
}

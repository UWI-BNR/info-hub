/*******************************************************************************
Publish an approved annual CVD report through the shared report publisher.
Usage: do "$BNR_STATA/reporting/bnr_report_annual_publish.do" 2025 1 [replace]
*******************************************************************************/
version 19
clear all
set more off

args report_year report_version option
if "`report_year'" == "" | "`report_version'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local year_num = real("`report_year'")
local version_num = real("`report_version'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 exit 198
if missing(`version_num') | `version_num' != floor(`version_num') | `version_num' < 1 exit 198

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO BNR_STATA {
    if "$`path_name'" == "" exit 198
}
local year4 : display %04.0f `year_num'
local report_id "bnr_cvd_annual_report_`year4'_v`version_num'"
local package_dir "$BNR_REPO/outputs/staging/reports/cvd/annual/`year4'/`report_id'"
local candidate_dir "`package_dir'/candidate"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/`report_id'.qmd"
local approval "`package_dir'/public_ready/approval.yml"
local public_pdf_dir "$BNR_REPO/outputs/public/reports/cvd/annual/`year4'"
local public_pdf "`public_pdf_dir'/`report_id'.pdf"
local site_pdf_dir "$BNR_REPO/site/downloads/files/reports/cvd/annual/`year4'"
local site_pdf "`site_pdf_dir'/`report_id'.pdf"
local site_metadata "`site_pdf_dir'/`report_id'.yml"
local site_report_dir "$BNR_REPO/site/surveillance/cvd/reports/annual/`year4'"
local site_qmd "`site_report_dir'/index.qmd"
capture mkdir "$BNR_REPO/outputs/public/reports"
capture mkdir "$BNR_REPO/outputs/public/reports/cvd"
capture mkdir "$BNR_REPO/outputs/public/reports/cvd/annual"
capture mkdir "`public_pdf_dir'"
capture mkdir "$BNR_REPO/site/downloads/files/reports"
capture mkdir "$BNR_REPO/site/downloads/files/reports/cvd"
capture mkdir "$BNR_REPO/site/downloads/files/reports/cvd/annual"
capture mkdir "`site_pdf_dir'"
capture mkdir "$BNR_REPO/site/surveillance/cvd/reports/annual"
capture mkdir "`site_report_dir'"

do "$BNR_STATA/reporting/bnr_report_publish_candidate.do" ///
    "`candidate_pdf'" "`candidate_qmd'" "`approval'" "`report_id'" ///
    "annual_cvd_report" "report_year" "`year4'" "`version_num'" ///
    "`public_pdf'" "`site_pdf'" "`site_qmd'" "`site_metadata'" "`option'"

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT: PUBLICATION SUMMARY"
noisily display as text   "  Run status:              Published successfully"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Public PDF:              `public_pdf'"'
noisily display as text  `"  Website PDF:             `site_pdf'"'
noisily display as text  `"  Website landing page:    `site_qmd'"'
noisily display as text   "  Next step:               Render, review, commit and deploy separately."
noisily display as result "============================================================================="
}

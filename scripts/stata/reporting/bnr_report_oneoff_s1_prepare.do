/*******************************************************************************
DO-FILE: bnr_report_oneoff_s1_prepare.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Prepare a private one-off CVD report candidate from a finished PDF.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_oneoff_s1_prepare.do" ///
      workflow_test 1 "$BNR_STAGING/report_inputs/report.pdf" ///
      "One-off CVD report workflow test" ///
      "Engineering placeholder used to test the publication workflow." ///
      2026-09-02

The bespoke analysis and PDF creation happen before this step. This step only
validates, packages and describes the finished PDF. It publishes nothing.
*******************************************************************************/

version 19
clear all
set more off

args study_id report_version source_pdf report_title report_description ///
    report_date option

if "`study_id'" == "" | "`report_version'" == "" | ///
        "`source_pdf'" == "" | "`report_title'" == "" | ///
        "`report_description'" == "" | "`report_date'" == "" {
    display as error "Enter study ID, version, PDF, title, description and report date."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional Step 1 argument is replace."
    exit 198
}
local replace_existing = (lower("`option'") == "replace")

if !regexm("`study_id'", "^[a-z][a-z0-9_]*$") {
    display as error "Study ID must use lowercase letters, numbers and underscores."
    display as error "It must begin with a letter; example: case_fatality_2025"
    exit 198
}
local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}
if substr(lower("`source_pdf'"), -4, 4) != ".pdf" {
    display as error "The supplied report must have a .pdf extension."
    exit 198
}
if strpos("`report_title'", char(34)) | ///
        strpos("`report_description'", char(34)) {
    display as error "Title and description must not contain double quotation marks."
    exit 198
}
local report_date_num = daily("`report_date'", "YMD")
if missing(`report_date_num') {
    display as error "Report date must use YYYY-MM-DD."
    exit 198
}
local canonical_date : display %tdCCYY-NN-DD `report_date_num'
if "`canonical_date'" != "`report_date'" {
    display as error "Report date must use YYYY-MM-DD."
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
foreach required_global in BNR_REPO BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

capture confirm file "`source_pdf'"
if _rc {
    display as error "Finished one-off report PDF not found: `source_pdf'"
    exit 601
}
quietly checksum "`source_pdf'"
local source_pdf_size = r(filelen)
local source_pdf_checksum = r(checksum)
if `source_pdf_size' < 1 {
    display as error "The supplied PDF is empty."
    exit 459
}

local report_id "bnr_cvd_oneoff_`study_id'_v`version_num'"
local public_name "bnr_cvd_oneoff_`study_id'"
local reports_dir "$BNR_STAGING/reports"
local cvd_dir "`reports_dir'/cvd"
local studies_dir "`cvd_dir'/studies"
local package_dir "`studies_dir'/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local approval "`ready_dir'/approval.yml"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_oneoff_s1_`report_id'.log"
local site_pdf_href "../../../../../downloads/files/reports/cvd/studies/`study_id'/`public_name'.pdf"

capture mkdir "`reports_dir'"
capture mkdir "`cvd_dir'"
capture mkdir "`studies_dir'"
capture mkdir "`package_dir'"
capture mkdir "`candidate_dir'"
capture mkdir "`ready_dir'"
quietly mata: st_local("candidate_dir_exists", strofreal(direxists("`candidate_dir'")))
if "`candidate_dir_exists'" != "1" {
    display as error "Could not create private candidate directory: `candidate_dir'"
    exit 603
}
quietly mata: st_local("ready_dir_exists", strofreal(direxists("`ready_dir'")))
if "`ready_dir_exists'" != "1" {
    display as error "Could not create private public_ready directory: `ready_dir'"
    exit 603
}

capture confirm file "`approval'"
if !_rc {
    display as error "This one-off report version is already approved: `approval'"
    display as error "Approved packages are immutable. Prepare a higher version."
    exit 602
}

local candidate_exists 0
capture confirm file "`candidate_pdf'"
if !_rc local candidate_exists 1
capture confirm file "`candidate_qmd'"
if !_rc local candidate_exists 1
capture confirm file "`candidate_metadata'"
if !_rc local candidate_exists 1
if `candidate_exists' & !`replace_existing' {
    display as error "This unapproved candidate version already exists."
    display as error "Use replace only to rebuild the unapproved candidate."
    exit 602
}

capture log close bnr_report_oneoff_s1
log using "`private_log'", text replace name(bnr_report_oneoff_s1)

copy "`source_pdf'" "`candidate_pdf'", replace
quietly checksum "`candidate_pdf'"
if r(filelen) != `source_pdf_size' | r(checksum) != `source_pdf_checksum' {
    capture log close bnr_report_oneoff_s1
    display as error "The private candidate PDF does not match the supplied PDF."
    exit 459
}

tempname qmd_handle
file open `qmd_handle' using "`candidate_qmd'", write text replace
file write `qmd_handle' "---" _n
file write `qmd_handle' `"title: "`report_title'""' _n
file write `qmd_handle' `"description: "`report_description'""' _n
file write `qmd_handle' "date: `report_date'" _n
file write `qmd_handle' "date-modified: `report_date'" _n
file write `qmd_handle' "report-id: `report_id'" _n
file write `qmd_handle' "report-type: One-off report" _n
file write `qmd_handle' "report-version: v`version_num'" _n
file write `qmd_handle' "study-id: `study_id'" _n
file write `qmd_handle' "image: /assets/images/listings/listing_mountain_coast.webp" _n
file write `qmd_handle' "image-alt: Barbados mountain coast." _n
file write `qmd_handle' "categories:" _n
file write `qmd_handle' "  - CVD" _n
file write `qmd_handle' "  - One-off report" _n
file write `qmd_handle' "format:" _n
file write `qmd_handle' "  html:" _n
file write `qmd_handle' "    toc: false" _n
file write `qmd_handle' "    page-layout: article" _n
file write `qmd_handle' "---" _n _n
file write `qmd_handle' "`report_description'" _n _n
file write `qmd_handle' "[Open or download the PDF report](`site_pdf_href'){.btn .btn-primary}" _n _n
file write `qmd_handle' `"<iframe src="`site_pdf_href'" title="`report_title'" width="100%" height="900"></iframe>"' _n
file close `qmd_handle'

local built_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local built_time "`c(current_time)'"
tempname metadata_handle
file open `metadata_handle' using "`candidate_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: one_off_cvd_report" _n
file write `metadata_handle' "study_id: `study_id'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "public_name: `public_name'" _n
file write `metadata_handle' `"report_title: "`report_title'""' _n
file write `metadata_handle' `"report_description: "`report_description'""' _n
file write `metadata_handle' "report_date: `report_date'" _n
file write `metadata_handle' "source_pdf_size: `source_pdf_size'" _n
file write `metadata_handle' "source_pdf_checksum: `source_pdf_checksum'" _n
file write `metadata_handle' "pdf_file: `public_name'.pdf" _n
file write `metadata_handle' "landing_page: index.qmd" _n
file write `metadata_handle' "built_date: `built_date'" _n
file write `metadata_handle' "built_time: `built_time'" _n
file close `metadata_handle'

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT STEP 1: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Candidate prepared"
noisily display as text   "  Script version:          0.1.0"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Source PDF:              `source_pdf'"'
noisily display as text  `"  Candidate package:       `candidate_dir'"'
noisily display as text  `"  Private build log:       `private_log'"'
noisily display as text   "  Publication boundary:    Nothing approved or published"
noisily display as text   "  Next step:               Review the candidate, then run Step 2."
noisily display as result "============================================================================="
}
capture log close bnr_report_oneoff_s1

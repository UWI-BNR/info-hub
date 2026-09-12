/*******************************************************************************
DO-FILE: bnr_report_oneoff_s3_publish.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Publish an approved one-off CVD report payload.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_oneoff_s3_publish.do" workflow_test 1
  do "$BNR_STATA/reporting/bnr_report_oneoff_s3_publish.do" workflow_test 2 replace
*******************************************************************************/

version 19
clear all
set more off

args study_id report_version option
if "`study_id'" == "" | "`report_version'" == "" {
    display as error "Enter study ID and approved report version."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional Step 3 argument is replace."
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

local report_id "bnr_cvd_oneoff_`study_id'_v`version_num'"
local public_name "bnr_cvd_oneoff_`study_id'"
local ready_dir "$BNR_STAGING/reports/cvd/studies/`report_id'/public_ready"

local public_reports "$BNR_PUBLIC/reports"
local public_cvd "`public_reports'/cvd"
local public_studies "`public_cvd'/studies"
local public_dir "`public_studies'/`study_id'"
local public_pdf "`public_dir'/`public_name'.pdf"
local public_qmd "`public_dir'/index.qmd"
local public_metadata "`public_dir'/report.yml"

local site_files "$BNR_REPO/site/downloads/files/reports"
local site_cvd "`site_files'/cvd"
local site_studies "`site_cvd'/studies"
local site_pdf_dir "`site_studies'/`study_id'"
local site_pdf "`site_pdf_dir'/`public_name'.pdf"
local site_metadata "`site_pdf_dir'/report.yml"
local site_reports "$BNR_REPO/site/surveillance/cvd/reports/studies"
local site_report_dir "`site_reports'/`study_id'"
local site_qmd "`site_report_dir'/index.qmd"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_oneoff_s3_`report_id'.log"

capture mkdir "`public_reports'"
capture mkdir "`public_cvd'"
capture mkdir "`public_studies'"
capture mkdir "`public_dir'"
capture mkdir "`site_files'"
capture mkdir "`site_cvd'"
capture mkdir "`site_studies'"
capture mkdir "`site_pdf_dir'"
capture mkdir "`site_reports'"
capture mkdir "`site_report_dir'"
quietly mata: st_local("public_dir_exists", strofreal(direxists("`public_dir'")))
if "`public_dir_exists'" != "1" {
    display as error "Could not create authoritative report directory: `public_dir'"
    exit 603
}
quietly mata: st_local("site_pdf_dir_exists", strofreal(direxists("`site_pdf_dir'")))
if "`site_pdf_dir_exists'" != "1" {
    display as error "Could not create website PDF directory: `site_pdf_dir'"
    exit 603
}
quietly mata: st_local("site_report_dir_exists", strofreal(direxists("`site_report_dir'")))
if "`site_report_dir_exists'" != "1" {
    display as error "Could not create website report directory: `site_report_dir'"
    exit 603
}

capture log close bnr_report_oneoff_s3
log using "`private_log'", text replace name(bnr_report_oneoff_s3)
capture noisily do "$BNR_STATA/reporting/bnr_report_publish_candidate.do" ///
    "`ready_dir'" "`report_id'" "one_off_cvd_report" ///
    "study_id" "`study_id'" "`version_num'" ///
    "`public_pdf'" "`public_qmd'" "`public_metadata'" ///
    "`site_pdf'" "`site_qmd'" "`site_metadata'" "`option'"
local publication_rc = _rc
if `publication_rc' {
    capture log close bnr_report_oneoff_s3
    quietly {
    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "ONE-OFF CVD REPORT STEP 3: FAILURE SUMMARY"
    noisily display as error "  Run status:              Failed safely"
    noisily display as error "  Report identifier:       `report_id'"
    noisily display as error "  Return code:             `publication_rc'"
    noisily display as error "  Recovery:                Resolve the error; public_ready is unchanged."
    noisily display as error "============================================================================="
    }
    exit `publication_rc'
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT STEP 3: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Published successfully"
noisily display as text   "  Script version:          0.1.0"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Public report package:   `public_dir'"'
noisily display as text  `"  Website PDF:             `site_pdf'"'
noisily display as text  `"  Website landing page:    `site_qmd'"'
noisily display as text  `"  Private publication log: `private_log'"'
noisily display as text   "  Next step:               Render and review the Quarto site."
noisily display as result "============================================================================="
}
capture log close bnr_report_oneoff_s3

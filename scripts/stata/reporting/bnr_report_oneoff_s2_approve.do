/*******************************************************************************
DO-FILE: bnr_report_oneoff_s2_approve.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Approve a prepared one-off CVD report candidate.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_oneoff_s2_approve.do" workflow_test 1 ///
      "Full Name" "BNR Role" candidate disclosure ready
*******************************************************************************/

version 19
clear all
set more off

args study_id report_version approver_name approver_role confirm_candidate ///
    confirm_disclosure confirm_ready option

if "`study_id'" == "" | "`report_version'" == "" | ///
        "`approver_name'" == "" | "`approver_role'" == "" {
    display as error "Enter study ID, version, approver name and role."
    exit 198
}
if "`option'" != "" {
    display as error "Step 2 approval has no replace option."
    display as error "Approved packages are immutable; prepare a higher version."
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
foreach required_global in BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local report_id "bnr_cvd_oneoff_`study_id'_v`version_num'"
local package_dir "$BNR_STAGING/reports/cvd/studies/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local approval "`ready_dir'/approval.yml"
local manifest "`ready_dir'/public_manifest.csv"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_oneoff_s2_`report_id'.log"

quietly mata: st_local("package_exists", strofreal(direxists("`package_dir'")))
if "`package_exists'" != "1" {
    display as error "One-off report candidate package not found: `package_dir'"
    display as error "Run one-off report Step 1 first."
    exit 601
}
quietly mata: st_local("ready_exists", strofreal(direxists("`ready_dir'")))
if "`ready_exists'" != "1" {
    capture mkdir "`ready_dir'"
    if _rc {
        display as error "Could not create public_ready: `ready_dir'"
        exit 603
    }
}

capture log close bnr_report_oneoff_s2
log using "`private_log'", text replace name(bnr_report_oneoff_s2)
capture noisily do "$BNR_STATA/reporting/bnr_report_approve_candidate.do" ///
    "`candidate_dir'" "`ready_dir'" "`report_id'" ///
    "one_off_cvd_report" "study_id" "`study_id'" "`version_num'" ///
    "`approver_name'" "`approver_role'" "`confirm_candidate'" ///
    "`confirm_disclosure'" "`confirm_ready'"
local approval_rc = _rc
if `approval_rc' {
    capture log close bnr_report_oneoff_s2
    quietly {
    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "ONE-OFF CVD REPORT STEP 2: FAILURE SUMMARY"
    noisily display as error "  Run status:              Failed safely"
    noisily display as error "  Report identifier:       `report_id'"
    noisily display as error "  Return code:             `approval_rc'"
    noisily display as error "  Public output created:   No"
    noisily display as error "  Recovery:                Resolve the error; candidate is unchanged."
    noisily display as error "============================================================================="
    }
    exit `approval_rc'
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT STEP 2: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Candidate approved"
noisily display as text   "  Script version:          0.1.0"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Approved by:             `approver_name'"'
noisily display as text  `"  Public-ready manifest:   `manifest'"'
noisily display as text  `"  Approval receipt:        `approval'"'
noisily display as text  `"  Private approval log:    `private_log'"'
noisily display as text   "  Publication boundary:    Nothing published"
noisily display as text   "  Next step:               Run one-off report Step 3."
noisily display as result "============================================================================="
}
capture log close bnr_report_oneoff_s2

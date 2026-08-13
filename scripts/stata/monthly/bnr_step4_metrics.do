/*
===============================================================================
 DO-FILE:     bnr_step4_metrics.do
 VERSION:     2.2.1 (30 July 2026)
 PROJECT:     BNR Refit Phase 2
 PURPOSE:     Calculate the CVD burden metrics and create a private staging package

 ROUTINE USE:
   do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 burden
   do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 burden replace

 ANALYST INPUTS:
   1. Completed release year
   2. Completed release month
   3. Metric family: burden
   4. Optional final word: replace

 WORKFLOW BOUNDARY:
   This file calculates and stages metrics. It does not approve, publish, or
   copy anything to the website.
===============================================================================
*/

version 19
clear all
set more off

* A small failure routine keeps expected errors in the same final-summary form
* used by the other workflow steps.
capture program drop _bnr_step4_fail
program define _bnr_step4_fail
    version 19
    args return_code selected_release private_log reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 4: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error "  Script version:         2.2.1"
    noisily display as error "  Selected release:       `selected_release'"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `private_log'"'
    noisily display as text  "  Action:                 Do not use outputs from this incomplete run."
    noisily display as error "============================================================================="
    capture log close step4
    exit `return_code'
end

*===============================================================================
* 1. ANALYST INPUTS
*===============================================================================

args release_year release_month metric_family replace_word

if "`release_year'" == "" | "`release_month'" == "" | "`metric_family'" == "" {
    display as error "Enter release year, release month and metric family."
    display as error "The implemented family is: burden"
    exit 198
}

local metric_family = lower("`metric_family'")
if "`metric_family'" != "burden" {
    display as error "The implemented metric family is burden."
    exit 198
}

local replace_existing = 0
if "`replace_word'" != "" {
    if lower("`replace_word'") != "replace" {
        display as error "The only optional final word is replace."
        exit 198
    }
    local replace_existing = 1
}

*===============================================================================
* 2. PROJECT PATHS AND RELEASE NAMES
*===============================================================================

if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error ///
            "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do through profile.do."
        exit `config_rc'
    }
}

foreach path_name in BNR_STATA BNR_PRIVATE BNR_STAGING BNR_DATA_DERIVED BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" {
        display as error "Required path is not configured: `path_name'"
        exit 198
    }
}

local year = real("`release_year'")
local month = real("`release_month'")

if missing(`year') | `year' != floor(`year') | `year' < 2024 {
    display as error "Release year must be an integer of 2024 or later."
    exit 198
}
if missing(`month') | `month' != floor(`month') | !inrange(`month', 1, 12) {
    display as error "Release month must be an integer from 1 to 12."
    exit 198
}

local release_month_end = dofm(ym(`year', `month') + 1) - 1
if `release_month_end' >= daily("`c(current_date)'", "DMY") {
    display as error "Select a completed release month."
    exit 198
}

local year4 : display %04.0f `year'
local month2 : display %02.0f `month'
local yyyymm "`year4'`month2'"
local selected_release "`year4'-`month2'"
local release_id "cvd_`year4'_`month2'"

* Step 3 input. These names are written in full so analysts do not need to
* reconstruct them from several intermediate locals.
local source_dataset ///
    "$BNR_DATA_DERIVED/cvd/y`year4'/m`month2'/metric_inputs/bnr_cvd_input_count_`yyyymm'_v01.dta"
local source_metadata ///
    "$BNR_DATA_DERIVED/cvd/y`year4'/m`month2'/metric_inputs/bnr_cvd_input_count_`yyyymm'_v01.yml"

* Step 4 private staging package.
local package_folder ///
    "$BNR_STAGING/metrics/cvd/burden/`release_id'"
local private_log ///
    "$BNR_PRIVATE_LOGS/bnr_cvd_metric_controller_`yyyymm'.log"

capture mkdir "$BNR_PRIVATE/outputs"
capture mkdir "$BNR_STAGING"
capture mkdir "$BNR_STAGING/metrics"
capture mkdir "$BNR_STAGING/metrics/cvd"
capture mkdir "$BNR_STAGING/metrics/cvd/burden"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close step4
log using `"`private_log'"', text replace name(step4)

* Routine commands remain quiet. Headers, controlled failures and the final
* summary remain visible to the analyst.
quietly {

noisily display as text "BNR CVD STEP 4: METRIC CALCULATION AND STAGING"
noisily display as result "  Script version:       2.2.1"
noisily display as result "  Selected release:     `selected_release'"
noisily display as result "  Metric family:        burden"
noisily display as result "  Replace authorised:    " cond(`replace_existing', "yes", "no")

*===============================================================================
* 3. CHECK THE STANDARD STEP 3 INPUT
*===============================================================================

capture confirm file `"`source_dataset'"'
if _rc {
    _bnr_step4_fail 601 "`selected_release'" `"`private_log'"' ///
        `"Step 3 count dataset not found: `source_dataset'"'
}

capture confirm file `"`source_metadata'"'
if _rc {
    _bnr_step4_fail 601 "`selected_release'" `"`private_log'"' ///
        `"Step 3 count metadata not found: `source_metadata'"'
}

quietly mata: st_local("package_already_exists", strofreal(direxists("`package_folder'")))
if "`package_already_exists'" == "1" & !`replace_existing' {
    _bnr_step4_fail 602 "`selected_release'" `"`private_log'"' ///
        `"Staging package already exists: `package_folder'. Rerun with replace only after review."'
}

*===============================================================================
* 4. CALCULATE THE BURDEN METRICS
*===============================================================================

* These temporary files pass one calculation dataset and one QA dataset to the
* staging helper. They disappear automatically when this run ends.
tempfile calculated_metrics calculation_qa

capture quietly do "$BNR_STATA/metrics/cvd/bnr_step4_cvd_burden.do" ///
    `"`source_dataset'"' `"`source_metadata'"' "`release_id'" ///
    `"`calculated_metrics'"' `"`calculation_qa'"' "`year4'" "`month'"
if _rc {
    local return_code = _rc
    _bnr_step4_fail `return_code' "`selected_release'" `"`private_log'"' ///
        "The burden metric calculation did not complete."
}

*===============================================================================
* 5. CREATE THE PRIVATE STAGING PACKAGE
*===============================================================================

capture quietly do "$BNR_STATA/common/bnr_step4_stage_metric.do" ///
    `"`calculated_metrics'"' `"`calculation_qa'"' ///
    "cvd" "burden" "`release_id'" ///
    `"`source_dataset'"' `"`source_metadata'"' `"`package_folder'"' ///
    "`replace_existing'" "CVD-BURDEN-001 CVD-BURDEN-002"
if _rc {
    local return_code = _rc
    _bnr_step4_fail `return_code' "`selected_release'" `"`private_log'"' ///
        "The private staging package was not completed."
}

*===============================================================================
* 6. READ THE FINISHED PACKAGE FOR THE OPERATIONAL SUMMARY
*===============================================================================

local release_dataset ///
    "`package_folder'/datasets/cvd_burden_metrics_`release_id'.dta"
local release_csv ///
    "`package_folder'/datasets/cvd_burden_metrics_`release_id'.csv"
local current_dataset ///
    "`package_folder'/datasets/cvd_burden_metrics_current.dta"
local current_csv ///
    "`package_folder'/datasets/cvd_burden_metrics_current.csv"
local package_metadata "`package_folder'/metadata/metric_package.yml"
local qa_review ///
    "`package_folder'/review/cvd_burden_qa_`release_id'.csv"
local suppression_review ///
    "`package_folder'/review/cvd_burden_suppression_review_`release_id'.xlsx"

capture use `"`release_dataset'"', clear
if _rc {
    _bnr_step4_fail 603 "`selected_release'" `"`private_log'"' ///
        "The staged metric dataset could not be opened."
}

count
local metric_rows = r(N)
count if metric_id == "CVD-BURDEN-001"
local burden_001_rows = r(N)
count if metric_id == "CVD-BURDEN-002"
local burden_002_rows = r(N)
count if primary_suppression == 1
local primary_suppressions = r(N)
count if related_suppression_review == 1
local related_review_rows = r(N)
count if suppression_review == 1
local suppression_worklist = r(N)
count if age_group != "all"
local age_specific_rows = r(N)

local metric_rows_display : display %12.0fc `metric_rows'
local burden_001_display : display %12.0fc `burden_001_rows'
local burden_002_display : display %12.0fc `burden_002_rows'
local primary_display : display %12.0fc `primary_suppressions'
local related_display : display %12.0fc `related_review_rows'
local worklist_display : display %12.0fc `suppression_worklist'
local age_specific_display : display %12.0fc `age_specific_rows'

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 4: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             Completed successfully"
noisily display as text   "  Script version:         2.2.1"
noisily display as text   "  Selected release:       `selected_release'"
noisily display as text   "  Metric family:          burden"
noisily display as text   "  Metric rows:            `metric_rows_display'"
noisily display as text   "  CVD-BURDEN-001 rows:    `burden_001_display'"
noisily display as text   "  CVD-BURDEN-002 rows:    `burden_002_display'"
noisily display as text   "  Age-stratified rows:      `age_specific_display'"
noisily display as text   "  Primary suppressions:   `primary_display'"
noisily display as text   "  Related review rows:    `related_display'"
noisily display as text   "  Suppression worklist:   `worklist_display'"
noisily display as text   "  Staging package:        `package_folder'"
noisily display as text   "  QA review file:         `qa_review'"
noisily display as text   "  Suppression workbook:   `suppression_review'"
noisily display as text   "  Private log:            `private_log'"
noisily display as text   "  Next step:              Complete Step 5 review and approval."
noisily display as result "============================================================================="

}

quietly log close step4
capture program drop _bnr_step4_fail

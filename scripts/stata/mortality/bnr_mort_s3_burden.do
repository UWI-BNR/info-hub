/*
===============================================================================
 DO-FILE:     bnr_mort_s3_burden.do
 VERSION:     Pass 4 monthly-public-scope and fixed-reference candidate
              (21 August 2026)
 PROJECT:     BNR Refit Phase 2
 PURPOSE:     Step 3: build a private mortality burden staging package

 ROUTINE USE:
   do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 7
   do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 7 replace

 DIAGNOSTIC USE:
   do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 7 replace debug

 WORKFLOW BOUNDARY:
   This file creates a private Step 3 staging package. It does not approve,
   promote, publish, copy files to the site, calculate rates, or link DCOs.
===============================================================================
*/

version 19
clear all
set more off

capture program drop _bnr_mort_s3_fail
program define _bnr_mort_s3_fail
    version 19
    args return_code private_log reason
    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "MORTALITY STEP 3: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `private_log'"'
    noisily display as error "  Action:                 Do not use outputs from this incomplete run."
    noisily display as error "============================================================================="
    capture log close mort_s3
    exit `return_code'
end

* ==============================================================================
* 1. ANALYST INPUTS -- EDITED BY THE DIALOG OR COMMAND LINE
* ==============================================================================
* Select the Step 2 DATASET RELEASE, not a hand-entered file path.
* The standard BNR path is constructed below. This mirrors the CVD workflow and
* prevents the selected release and the recorded source path from disagreeing.
args release_year release_month option_3 option_4

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Enter the Step 2 release year and month. Example: 2026 7"
    exit 198
}

capture confirm integer number `release_year'
if _rc | real("`release_year'") < 2000 | real("`release_year'") > 2100 {
    display as error "Release year must be a four-digit year from 2000 to 2100."
    exit 198
}

capture confirm integer number `release_month'
if _rc | !inrange(real("`release_month'"), 1, 12) {
    display as error "Release month must be an integer from 1 to 12."
    exit 198
}

local replace_existing = 0
local debug_mode = 0

foreach selected_option in "`option_3'" "`option_4'" {
    if "`selected_option'" != "" {
        if lower("`selected_option'") == "replace" {
            local replace_existing = 1
        }
        else if lower("`selected_option'") == "debug" {
            local debug_mode = 1
        }
        else {
            display as error "Optional words are replace and debug."
            display as error "Example: 2026 7 replace debug"
            exit 198
        }
    }
}

if lower("`option_3'") == lower("`option_4'") & "`option_3'" != "" {
    if inlist(lower("`option_3'"), "replace", "debug") {
        display as error "Do not enter the same optional word twice."
        exit 198
    }
}

local release_year_4 = string(real("`release_year'"), "%04.0f")
local release_month_2 = string(real("`release_month'"), "%02.0f")
local release_id "mort_`release_year_4'_`release_month_2'"

* ==============================================================================
* 2. STANDARD PATHS -- DO NOT EDIT
* ==============================================================================
if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do."
        exit `config_rc'
    }
}

foreach path_name in BNR_STATA BNR_DATA_DERIVED BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" {
        display as error "Required path is not configured: `path_name'"
        exit 198
    }
}

local source_dataset "$BNR_DATA_DERIVED/mortality/y`release_year_4'/m`release_month_2'/bnr_mort_s2_`release_year_4'`release_month_2'.dta"
local package_folder "$BNR_STAGING/mortality/burden/`release_id'"
local private_log "$BNR_PRIVATE_LOGS/bnr_mort_s3_burden_`release_id'.log"

capture confirm file `"`source_dataset'"'
if _rc {
    display as error "Step 2 classification dataset not found:"
    display as error `"`source_dataset'"'
    exit 601
}

* Confirm that this is a completed Step 2 dataset and derive its final year.
* The release ID describes the selected DATA FREEZE. The analysis years are
* recorded separately and must not be confused with the release identifier.
* Step 2 retains its full historical range. The dashboard series is deliberately
* restricted here, from Step 3 onward, to January 2010 and later.
use `"`source_dataset'"', clear
foreach required_date_variable in dth_date dth_year dth_month dth_qtr {
    capture confirm variable `required_date_variable'
    if _rc {
        display as error ///
            "The selected file is not a completed Step 2 dataset: `required_date_variable' is absent."
        exit 111
    }
}

quietly summarize dth_year if !missing(dth_year), meanonly
if missing(r(min)) | missing(r(max)) {
    display as error "The Step 2 dataset contains no valid death year."
    exit 459
}

local source_start_year = floor(r(min))
local analysis_end_year = floor(r(max))
local analysis_start_year = 2010

if `source_start_year' > `analysis_start_year' {
    display as error "The Step 2 dataset does not extend back to the required 2010 dashboard start."
    exit 459
}

if `analysis_end_year' >= real("`release_year'") {
    display as error "Step 3 contains completed calendar years only."
    display as error "The selected release contains death year `analysis_end_year', which is not earlier than release year `release_year'."
    exit 459
}

capture mkdir "$BNR_STAGING"
capture mkdir "$BNR_STAGING/mortality"
capture mkdir "$BNR_STAGING/mortality/burden"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close mort_s3
log using `"`private_log'"', text replace name(mort_s3)

* Routine commands are kept quiet now that the live-data calculation contract
* has completed successfully. The explicit noisily displays below preserve the
* short operator-facing start information and final run summary.
quietly {

noisily display as text "BNR MORTALITY STEP 3: BUILD BURDEN DATA"
noisily display as result "  Script version:       Pass 4 monthly-public-scope and fixed-reference candidate"
noisily display as result "  Step 2 release:       `release_year_4'-`release_month_2'"
noisily display as result "  Source dataset:       `source_dataset'"
noisily display as result "  Package release:      `release_id'"
noisily display as result "  Analysis years:       `analysis_start_year'-`analysis_end_year'"
noisily display as result "  Replace authorised:   " cond(`replace_existing', "yes", "no")
noisily display as result "  Diagnostic detail:    " cond(`debug_mode', "yes", "no")

* Stop if either a completed or partial copy of this release already exists.
* This avoids silently mixing files from two attempts.
local release_dataset "`package_folder'/datasets/mort_burden_metrics_`release_id'.dta"
local metadata_file "`package_folder'/metadata/mort_burden_package.yml"
capture confirm file `"`release_dataset'"'
local release_dataset_exists = !_rc
capture confirm file `"`metadata_file'"'
local metadata_exists = !_rc

if (`release_dataset_exists' | `metadata_exists') & !`replace_existing' {
    _bnr_mort_s3_fail 602 `"`private_log'"' ///
        "A completed or partial staging package already exists. Review it, then rerun with replace if authorised."
}

* ==============================================================================
* 3. CALCULATE PRIVATE BURDEN DATA -- DO NOT EDIT
* ==============================================================================
* Routine execution is quiet. Developers can add the optional word debug to
* expose the full child calculation in the Results window and private log.
tempfile calculated_metrics calculation_qa
if `debug_mode' {
    capture noisily do "$BNR_STATA/mortality/bnr_mort_s3_calc.do" ///
        `"`source_dataset'"' "`release_id'" "`analysis_start_year'" ///
        "`analysis_end_year'" `"`calculated_metrics'"' `"`calculation_qa'"'
}
else {
    capture quietly do "$BNR_STATA/mortality/bnr_mort_s3_calc.do" ///
        `"`source_dataset'"' "`release_id'" "`analysis_start_year'" ///
        "`analysis_end_year'" `"`calculated_metrics'"' `"`calculation_qa'"'
}
if _rc {
    local return_code = _rc
    _bnr_mort_s3_fail `return_code' `"`private_log'"' ///
        "The mortality burden calculation stopped with Stata return code `return_code'."
}

* ==============================================================================
* 4. CREATE PRIVATE STAGING PACKAGE -- DO NOT EDIT
* ==============================================================================
if `debug_mode' {
    capture noisily do "$BNR_STATA/mortality/bnr_mort_s3_stage.do" ///
        `"`calculated_metrics'"' `"`calculation_qa'"' "`release_id'" ///
        `"`source_dataset'"' `"`package_folder'"' "`replace_existing'" ///
        "`release_year_4'" "`release_month_2'" ///
        "`analysis_start_year'" "`analysis_end_year'"
}
else {
    capture quietly do "$BNR_STATA/mortality/bnr_mort_s3_stage.do" ///
        `"`calculated_metrics'"' `"`calculation_qa'"' "`release_id'" ///
        `"`source_dataset'"' `"`package_folder'"' "`replace_existing'" ///
        "`release_year_4'" "`release_month_2'" ///
        "`analysis_start_year'" "`analysis_end_year'"
}
if _rc {
    local return_code = _rc
    _bnr_mort_s3_fail `return_code' `"`private_log'"' ///
        "Private staging stopped with Stata return code `return_code'."
}

* ==============================================================================
* 5. OPERATIONAL SUMMARY -- DO NOT EDIT
* ==============================================================================
use `"`release_dataset'"', clear
quietly count
local metric_rows = r(N)
quietly count if metric_id == "MORT-BURDEN-001"
local count_rows = r(N)
quietly count if metric_id == "MORT-BURDEN-002"
local distribution_rows = r(N)
quietly count if period_type == "annual"
local annual_rows = r(N)
quietly count if period_type == "quarterly"
local quarterly_rows = r(N)
quietly count if period_type == "monthly"
local monthly_rows = r(N)
quietly count if suppression_review == 1
local review_rows = r(N)
quietly count if case_definition == "primary_clear_likely"
local primary_definition_rows = r(N)
quietly count if case_definition == "upper_clear_likely_possible"
local upper_definition_rows = r(N)

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "MORTALITY STEP 3: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             Completed successfully"
noisily display as text   "  Step 2 release:         `release_year_4'-`release_month_2'"
noisily display as text   "  Package release:        `release_id'"
noisily display as text   "  Analysis years:         `analysis_start_year'-`analysis_end_year'"
noisily display as text   "  Metric rows:            `metric_rows'"
noisily display as text   "  Primary lattice rows:   `primary_definition_rows'"
noisily display as text   "  Upper lattice rows:     `upper_definition_rows'"
noisily display as text   "  Count rows:             `count_rows'"
noisily display as text   "  Distribution rows:      `distribution_rows'"
noisily display as text   "  Annual rows:            `annual_rows'"
noisily display as text   "  Quarterly rows:         `quarterly_rows'"
noisily display as text   "  Monthly rows:           `monthly_rows'"
noisily display as text   "  Suppression worklist:   `review_rows'"
noisily display as text   "  Staging package:        `package_folder'"
noisily display as text   "  Private log:            `private_log'"
noisily display as text   "  Next step:              Complete Step 4 mortality-release review."
noisily display as result "============================================================================="

}

quietly log close mort_s3
capture program drop _bnr_mort_s3_fail

/*******************************************************************************
DO-FILE:     bnr_cvd_metric_controller.do
VERSION:     1.4.0 (23 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 4 - calculate metrics and create staging review packages

PURPOSE:     Select a completed Step 3 release, run explicitly named metric
             families, and create staging-only packages for human review.

USAGE:       do "$BNR_STATA/monthly/bnr_cvd_metric_controller.do" ///
                 2024 3 burden

             do "$BNR_STATA/monthly/bnr_cvd_metric_controller.do" ///
                 2024 3 burden replace

ARGUMENTS:   year month metric_family [metric_family ...] [replace]

IMPLEMENTED: burden

BOUNDARY:    This controller creates no public files, website files, approval
             record or publication package.
*******************************************************************************/

version 19
clear all
set more off

capture program drop _bnr_step4_fail
program define _bnr_step4_fail
    version 19
    args return_code release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 4 DID NOT COMPLETE"
    noisily display as error "  Release: `release_id'"
    noisily display as error `"  Reason:  `reason'"'
    noisily display as error `"  Log:     `log_path'"'
    noisily display as text  "No approval or public file was created. Do not use an incomplete staging package."
    noisily display as error "============================================================================="
    capture log close step4
    exit `return_code'
end

* -----------------------------------------------------------------------------
* 0. Read the complete command line
* -----------------------------------------------------------------------------

local command_line `"`0'"'
gettoken release_year remainder : command_line
gettoken release_month options : remainder
local options : list retokenize options

if `"`release_year'"' == "" | `"`release_month'"' == "" | `"`options'"' == "" {
    display as error "Release year, month and at least one metric family are required."
    display as error "Implemented metric families: burden"
    exit 198
}

local run_burden 0
local replace_existing 0
local option_count : word count `options'
local option_position 0

foreach raw_option of local options {
    local ++option_position
    local option = lower("`raw_option'")

    if "`option'" == "replace" {
        if `option_position' != `option_count' {
            display as error "replace must be the final option."
            exit 198
        }
        local replace_existing 1
    }
    else if "`option'" == "burden" {
        if `run_burden' {
            display as error "Metric family specified more than once: burden"
            exit 198
        }
        local run_burden 1
    }
    else {
        display as error "Metric family is not implemented: `raw_option'"
        display as error "Currently implemented: burden"
        exit 198
    }
}

if !`run_burden' {
    display as error "Specify at least one implemented metric family."
    exit 198
}

* -----------------------------------------------------------------------------
* 1. Load and validate project paths
* -----------------------------------------------------------------------------

if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

foreach required_global in BNR_STATA BNR_PRIVATE BNR_STAGING BNR_DATA_DERIVED BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

do "$BNR_STATA/common/bnrcvd_globals.do"

local year_num = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Release year must be an integer of 2024 or later."
    exit 198
}
if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Release month must be an integer from 1 to 12."
    exit 198
}

local release_end = dofm(ym(`year_num', `month_num') + 1) - 1
if `release_end' >= daily("`c(current_date)'", "DMY") {
    display as error "Select a completed release month."
    exit 198
}

local year4 : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"
local release_id "cvd_`year4'_`month2'"
local replace_mode = cond(`replace_existing', 1, 0)

local input_dir "$BNR_DATA_DERIVED/cvd/y`year4'/m`month2'/metric_inputs"
local source_id "bnr_cvd_input_count_`period'_v01"
local source_dta "`input_dir'/`source_id'.dta"
local source_yml "`input_dir'/`source_id'.yml"

local staging_root "$BNR_STAGING"
local family_root "`staging_root'/metrics/cvd/burden"
local package_dir "`family_root'/`release_id'"
local release_dataset "cvd_burden_metrics_`release_id'"
local current_dataset "cvd_burden_metrics_current"
local qa_dataset "cvd_burden_qa_`release_id'"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_metric_controller_`period'.log"

capture mkdir "$BNR_PRIVATE/outputs"
capture mkdir "$BNR_STAGING"
capture mkdir "`staging_root'/metrics"
capture mkdir "`staging_root'/metrics/cvd"
capture mkdir "`family_root'"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close step4
log using `"`output_log'"', text replace name(step4)

* Keep the Results window and log operational rather than developer-facing.
quietly {

noisily display as text "BNR CVD STEP 4: METRIC CALCULATION AND STAGING"
noisily display as result "  Script version:       1.4.0"
noisily display as result "  Selected release:     `year4'-`month2'"
noisily display as result "  Metric families:      burden"
if `replace_existing' {
    noisily display as result "  Replacement allowed: yes"
}
else {
    noisily display as result "  Replacement allowed: no"
}

foreach required_file in `"`source_dta'"' `"`source_yml'"' {
    capture confirm file `"`required_file'"'
    if _rc {
        _bnr_step4_fail 601 "`release_id'" `"`output_log'"' ///
            `"Required Step 3 burden input not found: `required_file'"'
        exit _rc
    }
}

quietly mata: st_local("package_exists", strofreal(direxists("`package_dir'")))
if "`package_exists'" == "1" & !`replace_existing' {
    _bnr_step4_fail 602 "`release_id'" `"`output_log'"' ///
        `"The burden staging package already exists: `package_dir'. Rerun only with explicit replace authorisation."'
    exit _rc
}

* -----------------------------------------------------------------------------
* 2. Run the burden calculation
* -----------------------------------------------------------------------------

tempfile burden_calculation burden_qa

capture quietly do "$BNR_STATA/metrics/cvd/metric_cvd_burden.do" ///
    `"`source_dta'"' `"`source_yml'"' "`release_id'" ///
    `"`burden_calculation'"' `"`burden_qa'"' "`year4'" "`month_num'"
if _rc {
    local calculation_rc = _rc
    _bnr_step4_fail `calculation_rc' "`release_id'" `"`output_log'"' ///
        "The burden calculation did not complete."
    exit _rc
}

* -----------------------------------------------------------------------------
* 3. Create the standard staging-only review package
* -----------------------------------------------------------------------------

capture quietly do "$BNR_STATA/common/bnr_stage_metric.do" ///
    `"`burden_calculation'"' `"`burden_qa'"' ///
    "cvd" "burden" "`release_id'" ///
    `"`source_dta'"' `"`source_yml'"' `"`package_dir'"' ///
    "`replace_mode'" "CVD-BURDEN-001 CVD-BURDEN-002"
if _rc {
    local staging_rc = _rc
    _bnr_step4_fail `staging_rc' "`release_id'" `"`output_log'"' ///
        "The burden staging package was not completed."
    exit _rc
}

local release_dta "`package_dir'/datasets/`release_dataset'.dta"
local release_csv "`package_dir'/datasets/`release_dataset'.csv"
local current_dta "`package_dir'/datasets/`current_dataset'.dta"
local current_csv "`package_dir'/datasets/`current_dataset'.csv"
local release_yml "`package_dir'/metadata/`release_dataset'.yml"
local current_yml "`package_dir'/metadata/`current_dataset'.yml"
local package_yml "`package_dir'/metadata/metric_package.yml"
local qa_csv "`package_dir'/review/`qa_dataset'.csv"
local suppression_csv ///
    "`package_dir'/review/cvd_burden_suppression_review_`release_id'.csv"
local suppression_xlsx ///
    "`package_dir'/review/cvd_burden_suppression_review_`release_id'.xlsx"
local readme "`package_dir'/readme.txt"

capture use `"`release_dta'"', clear
if _rc {
    local use_rc = _rc
    _bnr_step4_fail `use_rc' "`release_id'" `"`output_log'"' ///
        "The staged burden metric dataset could not be opened for final QA."
    exit _rc
}
quietly count
local metric_rows = r(N)
quietly count if metric_id == "CVD-BURDEN-001"
local burden_001_rows = r(N)
quietly count if metric_id == "CVD-BURDEN-002"
local burden_002_rows = r(N)
quietly count if primary_suppression
local primary_suppression_rows = r(N)
quietly count if related_suppression_review
local related_suppression_rows = r(N)
quietly count if suppression_review
local suppression_review_rows = r(N)

* -----------------------------------------------------------------------------
* 4. Single operational run summary
* -----------------------------------------------------------------------------

local metric_rows_display : display %12.0fc `metric_rows'
tempname summary_frame
frame create `summary_frame'
frame `summary_frame': quietly set obs 27
frame `summary_frame': generate str28 operational_item = ""
frame `summary_frame': generate strL result = ""

frame `summary_frame': replace operational_item = "Run status" in 1
frame `summary_frame': replace result = "Completed successfully" in 1
frame `summary_frame': replace operational_item = "Script version" in 2
frame `summary_frame': replace result = "1.4.0" in 2
frame `summary_frame': replace operational_item = "Selected release" in 3
frame `summary_frame': replace result = "`year4'-`month2'" in 3
frame `summary_frame': replace operational_item = "Metric family" in 4
frame `summary_frame': replace result = "burden" in 4
frame `summary_frame': replace operational_item = "Source dataset" in 5
frame `summary_frame': replace result = `"`source_dta'"' in 5
frame `summary_frame': replace operational_item = "Metric rows" in 6
frame `summary_frame': replace result = "`metric_rows_display'" in 6
frame `summary_frame': replace operational_item = "CVD-BURDEN-001 rows" in 7
frame `summary_frame': replace result = "`burden_001_rows'" in 7
frame `summary_frame': replace operational_item = "CVD-BURDEN-002 rows" in 8
frame `summary_frame': replace result = "`burden_002_rows'" in 8
frame `summary_frame': replace operational_item = "SDC policy" in 9
frame `summary_frame': replace result = "bnr_sdc_v1: suppress frequencies 1 to 5" in 9
frame `summary_frame': replace operational_item = "Primary suppressions" in 10
frame `summary_frame': replace result = "`primary_suppression_rows'" in 10
frame `summary_frame': replace operational_item = "Related review rows" in 11
frame `summary_frame': replace result = "`related_suppression_rows'" in 11
frame `summary_frame': replace operational_item = "Total suppression worklist" in 12
frame `summary_frame': replace result = "`suppression_review_rows'" in 12
frame `summary_frame': replace operational_item = "Replacement authorised" in 13
frame `summary_frame': replace result = cond(`replace_existing', "Yes", "No") in 13
frame `summary_frame': replace operational_item = "Release DTA" in 14
frame `summary_frame': replace result = `"`release_dta'"' in 14
frame `summary_frame': replace operational_item = "Release CSV" in 15
frame `summary_frame': replace result = `"`release_csv'"' in 15
frame `summary_frame': replace operational_item = "Current DTA" in 16
frame `summary_frame': replace result = `"`current_dta'"' in 16
frame `summary_frame': replace operational_item = "Current CSV" in 17
frame `summary_frame': replace result = `"`current_csv'"' in 17
frame `summary_frame': replace operational_item = "Package metadata" in 18
frame `summary_frame': replace result = `"`package_yml'"' in 18
frame `summary_frame': replace operational_item = "Release metadata" in 19
frame `summary_frame': replace result = `"`release_yml'"' in 19
frame `summary_frame': replace operational_item = "Current metadata" in 20
frame `summary_frame': replace result = `"`current_yml'"' in 20
frame `summary_frame': replace operational_item = "QA review file" in 21
frame `summary_frame': replace result = `"`qa_csv'"' in 21
frame `summary_frame': replace operational_item = "Suppression review CSV" in 22
frame `summary_frame': replace result = `"`suppression_csv'"' in 22
frame `summary_frame': replace operational_item = "Suppression review workbook" in 23
frame `summary_frame': replace result = `"`suppression_xlsx'"' in 23
frame `summary_frame': replace operational_item = "Package readme" in 24
frame `summary_frame': replace result = `"`readme'"' in 24
frame `summary_frame': replace operational_item = "Private staging folder" in 25
frame `summary_frame': replace result = `"`package_dir'"' in 25
frame `summary_frame': replace operational_item = "Private log" in 26
frame `summary_frame': replace result = `"`output_log'"' in 26
frame `summary_frame': replace operational_item = "Next step" in 27
frame `summary_frame': replace result = ///
    "Complete Step 5 analytical and suppression review before publication." in 27

frame `summary_frame': label variable operational_item "Operational item"
frame `summary_frame': label variable result "Result"
frame `summary_frame': format operational_item %-28s
frame `summary_frame': format result %-180s

local original_linesize = c(linesize)
set linesize 220
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 4: OPERATIONAL RUN SUMMARY"
frame `summary_frame': noisily list operational_item result, noobs clean abbreviate(28)
noisily display as result "============================================================================="
set linesize `original_linesize'
frame drop `summary_frame'

}

quietly log close step4
capture program drop _bnr_step4_fail

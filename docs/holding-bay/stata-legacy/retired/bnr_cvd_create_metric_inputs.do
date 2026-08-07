/*******************************************************************************
DO-FILE:     bnr_cvd_create_metric_inputs.do
VERSION:     1.3.0 (23 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 3 - create deidentified metric-input datasets

PURPOSE:     Create explicitly authorised, private, deidentified CVD
             event-level input datasets from one Step 2 confidential release.

USAGE:       do "$BNR_STATA/monthly/bnr_cvd_create_metric_inputs.do" ///
                 2024 3 count case_fatality length_of_stay performance ///
                 all_variables

ARGUMENTS:   year month dataset [dataset ...] [replace]
             Specify every dataset to create in words: count, case_fatality,
             length_of_stay, performance and/or all_variables. The optional
             final word replace permits replacement of selected existing
             outputs.

INPUT:       $BNR_DATA_DERIVED/cvd/yYYYY/mMM/
                 bnr_cvd_confidential_YYYYMM_v01.dta
                 bnr_cvd_confidential_YYYYMM_v01.yml

OUTPUTS:     $BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/
                 bnr_cvd_input_count_YYYYMM_v01.dta/.yml
                 bnr_cvd_input_case_fatality_YYYYMM_v01.dta/.yml
                 bnr_cvd_input_length_of_stay_YYYYMM_v01.dta/.yml
                 bnr_cvd_input_performance_YYYYMM_v01.dta/.yml
                 bnr_cvd_input_all_variables_YYYYMM_v01.dta/.yml

SECURITY:    All inputs, outputs and logs are confidential and remain outside
             Git. This file creates no metrics, staging, public or web files.
*******************************************************************************/

version 19
clear all
set more off

capture program drop _bnr_step3_fail
program define _bnr_step3_fail
    version 19
    args return_code release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 3 DID NOT COMPLETE"
    noisily display as error "  Release: `release_id'"
    noisily display as error `"  Reason:  `reason'"'
    noisily display as error `"  Log:     `log_path'"'
    noisily display as text  "Do not use any Step 3 output from this incomplete run."
    noisily display as error "============================================================================="
    capture log close step3
    exit `return_code'
end

* -----------------------------------------------------------------------------
* 0. Arguments and private paths
* -----------------------------------------------------------------------------

* Read the complete argument string. Stata's args command would place only
* the third word in an "options" local, silently losing all later dataset
* names and a trailing replace authorisation.
local command_line `"`0'"'
gettoken release_year remainder : command_line
gettoken release_month options : remainder
local options : list retokenize options

if `"`release_year'"' == "" | `"`release_month'"' == "" | `"`options'"' == "" {
    display as error "Release year, month and at least one dataset name are required."
    display as error ///
        "Allowed datasets: count case_fatality length_of_stay performance all_variables"
    exit 198
}

local make_count 0
local make_case_fatality 0
local make_length_of_stay 0
local make_performance 0
local make_all_variables 0
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
    else if !inlist("`option'", "count", "case_fatality", ///
            "length_of_stay", "performance", "all_variables") {
        display as error "Unrecognised dataset option: `raw_option'"
        display as error ///
            "Allowed datasets: count case_fatality length_of_stay performance all_variables"
        exit 198
    }
    else {
        local option_flag "make_`option'"
        if ``option_flag'' {
            display as error "Dataset option specified more than once: `option'"
            exit 198
        }
        local `option_flag' 1
    }
}

if `make_count' + `make_case_fatality' + `make_length_of_stay' + ///
        `make_performance' + `make_all_variables' == 0 {
    display as error "Specify at least one dataset to create."
    exit 198
}

if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

if `"$BNR_STATA"' == "" {
    display as error "Required private path is not configured: BNR_STATA"
    exit 198
}
if `"$BNR_DATA_DERIVED"' == "" {
    display as error "Required private path is not configured: BNR_DATA_DERIVED"
    exit 198
}
if `"$BNR_PRIVATE_LOGS"' == "" {
    display as error "Required private path is not configured: BNR_PRIVATE_LOGS"
    exit 198
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

local year4 : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"

local source_dir "$BNR_DATA_DERIVED/cvd/y`year4'/m`month2'"
local source_id "bnr_cvd_confidential_`period'_v01"
local source_dta "`source_dir'/`source_id'.dta"
local source_yml "`source_dir'/`source_id'.yml"
local output_dir "`source_dir'/metric_inputs"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_create_metric_inputs_`period'.log"

capture mkdir "$BNR_PRIVATE_LOGS"
capture mkdir "`output_dir'"

local selected ""
if `make_count' local selected "`selected' count"
if `make_case_fatality' local selected "`selected' case_fatality"
if `make_length_of_stay' local selected "`selected' length_of_stay"
if `make_performance' local selected "`selected' performance"
if `make_all_variables' local selected "`selected' all_variables"
local selected : list retokenize selected
local output_rows 0

capture log close step3
log using "`output_log'", text replace name(step3)

* Keep the Results window and log operational rather than developer-facing.
quietly {

noisily display as text "BNR CVD STEP 3: DEIDENTIFIED METRIC-INPUT DATASETS"
noisily display as result "  Script version: 1.3.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Source dataset:   `source_dta'"
noisily display as result "  Authorised files: `selected'"
if `replace_existing' {
    noisily display as result "  Replace authorised: yes"
}
else {
    noisily display as result "  Replace authorised: no"
}

foreach required_file in "`source_dta'" "`source_yml'" {
    capture confirm file "`required_file'"
    if _rc {
        _bnr_step3_fail 601 "`year4'-`month2'" `"`output_log'"' ///
            `"Required Step 2 input not found: `required_file'"'
        exit _rc
    }
}

foreach dataset of local selected {
    local output_id "bnr_cvd_input_`dataset'_`period'_v01"
    foreach extension in dta yml {
        local existing_file "`output_dir'/`output_id'.`extension'"
        capture confirm file "`existing_file'"
        if !_rc & !`replace_existing' {
            _bnr_step3_fail 602 "`year4'-`month2'" `"`output_log'"' ///
                `"Selected output already exists: `existing_file'. Rerun only with explicit replace authorisation."'
            exit _rc
        }
    }
}

* -----------------------------------------------------------------------------
* 1. Validate the authoritative confidential input
* -----------------------------------------------------------------------------

capture use "`source_dta'", clear
if _rc {
    local use_rc = _rc
    _bnr_step3_fail `use_rc' "`year4'-`month2'" `"`output_log'"' ///
        "The selected Step 2 confidential dataset could not be opened."
    exit _rc
}

local common_variables eid dco dco_alt etype doe yoe moe agey age5 age70 sex
local cf_variables parish dodi sadi dod
local los_variables doa htoa mtoa
local performance_variables htoe mtoe htecg mtecg doasp htoasp mtoasp ///
    asp_ampm dore htore mtore asp1 asp2 asp3 aspdose htype reperf ///
    repertype ecg doecg dmed1 dmed5
local all_variables "`common_variables' `cf_variables' `los_variables' `performance_variables'"
local all_variables : list uniq all_variables

local required_variables "`common_variables' source_era"
if `make_case_fatality' | `make_length_of_stay' | `make_all_variables' {
    local required_variables "`required_variables' `cf_variables'"
}
if `make_length_of_stay' | `make_performance' | `make_all_variables' {
    local required_variables "`required_variables' `los_variables'"
}
if `make_performance' | `make_all_variables' {
    local required_variables "`required_variables' `performance_variables'"
}
local required_variables : list uniq required_variables

foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        _bnr_step3_fail 111 "`year4'-`month2'" `"`output_log'"' ///
            "Required Step 2 variable is absent: `variable'."
        exit _rc
    }
}

quietly count
local input_records = r(N)
if `input_records' == 0 {
    _bnr_step3_fail 2000 "`year4'-`month2'" `"`output_log'"' ///
        "The Step 2 input contains no event records."
    exit _rc
}
capture quietly isid eid
if _rc {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "The Step 2 input must contain one unique eid per event."
    exit _rc
}

quietly count if !inlist(etype, 1, 2) | missing(etype)
local invalid_etype = r(N)
quietly count if missing(doe) | yoe != year(doe) | moe != month(doe)
local invalid_event_date = r(N)
if `invalid_etype' | `invalid_event_date' {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        `"Step 2 input is unsafe: `invalid_etype' invalid event type(s); `invalid_event_date' invalid event date(s)."'
    exit _rc
}

quietly summarize doe, meanonly
local event_date_min : display %tdCCYY-NN-DD r(min)
local event_date_max : display %tdCCYY-NN-DD r(max)
quietly count if missing(agey)
local missing_age = r(N)
quietly count if source_era == 1 & dco != 0
local post2023_dco_nonzero = r(N)
if `post2023_dco_nonzero' {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Post-2023 dco must be explicitly zero in the Step 2 input."
    exit _rc
}

quietly count if !inlist(source_era, 0, 1) | missing(source_era)
local invalid_source_era = r(N)
quietly count if !inlist(dco, 0, 1) | missing(dco)
local invalid_dco = r(N)
if `invalid_source_era' | `invalid_dco' {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        `"Step 2 source status is unsafe: `invalid_source_era' invalid source_era value(s); `invalid_dco' invalid dco value(s)."'
    exit _rc
}

quietly count if etype == 1
local records_stroke = r(N)
quietly count if etype == 2
local records_ami = r(N)

preserve
keep eid etype doe dco
sort eid
capture quietly datasignature, nonames
if _rc local data_signature "not_available"
else local data_signature "`r(datasignature)'"
restore

* -----------------------------------------------------------------------------
* 2. Create only the analyst-authorised datasets
* -----------------------------------------------------------------------------

foreach dataset of local selected {
    local variables ""
    local description ""
    if "`dataset'" == "count" {
        local variables "`common_variables'"
        local description "Deidentified event dataset for CVD counts and incidence"
    }
    if "`dataset'" == "case_fatality" {
        local variables "`common_variables' `cf_variables'"
        local description "Deidentified event dataset for in-hospital case-fatality analysis"
    }
    if "`dataset'" == "length_of_stay" {
        local variables "`common_variables' `los_variables' `cf_variables'"
        local description "Deidentified event dataset for in-hospital length-of-stay analysis"
    }
    if "`dataset'" == "performance" {
        local variables "`common_variables' `performance_variables' `los_variables'"
        local description "Deidentified event dataset for care-performance analysis"
    }
    if "`dataset'" == "all_variables" {
        local variables "`all_variables'"
        local description "Deidentified event dataset containing all fields authorised across the metric-input subsets"
    }

    local output_id "bnr_cvd_input_`dataset'_`period'_v01"
    local output_dta "`output_dir'/`output_id'.dta"
    local output_yml "`output_dir'/`output_id'.yml"

    preserve
    keep `variables'
    sort doe etype eid

    quietly count
    if r(N) != `input_records' {
        _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
            "Record-count QA failed while creating the `dataset' input."
        exit _rc
    }
    capture quietly isid eid
    if _rc {
        _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
            "Event identifier is not unique in `dataset'."
        exit _rc
    }

    quietly ds
    local actual_variables "`r(varlist)'"
    local actual_count : word count `actual_variables'
    local expected_count : word count `variables'
    if `actual_count' != `expected_count' {
        _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
            "Variable contract failed for `dataset'."
        exit _rc
    }
    foreach variable of local variables {
        capture confirm variable `variable'
        if _rc {
            _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
                "Variable contract failed for `dataset': `variable' is absent."
            exit _rc
        }
    }

    label data "BNR CVD deidentified `dataset' metric-input dataset through `event_date_max'"
    notes _dta: title: BNR CVD deidentified `dataset' metric-input dataset
    notes _dta: dataset_id: `output_id'
    notes _dta: created: $todayiso
    notes _dta: release: `year4'-`month2'
    notes _dta: tier: Confidential deidentified individual-level data
    notes _dta: unit_of_analysis: One row per CVD event
    notes _dta: parent_dataset: `source_id'
    notes _dta: deidentification: Direct identifiers and operational fields removed by explicit variable contract
    notes _dta: coverage_limitation: Post-2023 DCO surveillance is not yet included; dco is set to zero
    notes _dta: rights: Restricted to authorised BNR use; not for public release
    notes _dta: description: `description'

    if `replace_existing' {
        save "`output_dta'", replace
    }
    else {
        save "`output_dta'"
    }

    tempname yaml
    if `replace_existing' {
        file open `yaml' using "`output_yml'", write text replace
    }
    else {
        file open `yaml' using "`output_yml'", write text
    }
    file write `yaml' "dataset_id: `output_id'" _n
    file write `yaml' "status: confidential_deidentified" _n
    file write `yaml' "created: $todayiso" _n
    file write `yaml' `"created_by: "`analyst'""' _n
    file write `yaml' "release: `year4'-`month2'" _n
    file write `yaml' "coverage_start: 2009" _n
    file write `yaml' "coverage_end: `event_date_max'" _n
    file write `yaml' "unit_of_analysis: one_cvd_event" _n
    file write `yaml' "records_total: `input_records'" _n
    file write `yaml' "records_stroke: `records_stroke'" _n
    file write `yaml' "records_ami: `records_ami'" _n
    file write `yaml' "event_date_min: `event_date_min'" _n
    file write `yaml' "event_date_max: `event_date_max'" _n
    file write `yaml' "missing_age: `missing_age'" _n
    file write `yaml' "post_2023_dco_nonzero: `post2023_dco_nonzero'" _n
    file write `yaml' `"parent_dataset: "`source_id'""' _n
    file write `yaml' `"source_dataset: "`source_dta'""' _n
    file write `yaml' `"data_signature_core: "`data_signature'""' _n
    file write `yaml' "direct_identifiers_removed: true" _n
    file write `yaml' "variables:" _n
    foreach variable of local variables {
        file write `yaml' "  - `variable'" _n
    }
    file close `yaml'

    capture confirm file "`output_dta'"
    if _rc {
        _bnr_step3_fail 603 "`year4'-`month2'" `"`output_log'"' ///
            "Output dataset was not created: `output_dta'."
        exit _rc
    }
    capture confirm file "`output_yml'"
    if _rc {
        _bnr_step3_fail 603 "`year4'-`month2'" `"`output_log'"' ///
            "Output receipt was not created: `output_yml'."
        exit _rc
    }

    local ++output_rows
    local output_label`output_rows' "`dataset' dataset"
    local output_result`output_rows' `"`output_dta'"'
    local ++output_rows
    local output_label`output_rows' "`dataset' receipt"
    local output_result`output_rows' `"`output_yml'"'
    restore
}

* -----------------------------------------------------------------------------
* 3. Single operational run summary
* -----------------------------------------------------------------------------
* Keep the end-of-run result tidy in both the Results window and private log.
* A temporary frame is used so the analyst's active data remain untouched.
local input_records_display : display %12.0fc `input_records'
local summary_rows = 11 + `output_rows'

tempname summary_frame
frame create `summary_frame'

frame `summary_frame': quietly set obs `summary_rows'
frame `summary_frame': generate str24 operational_item = ""
frame `summary_frame': generate strL result = ""

frame `summary_frame': replace operational_item = "Run status" in 1
frame `summary_frame': replace result = "Completed successfully" in 1
frame `summary_frame': replace operational_item = "Script version" in 2
frame `summary_frame': replace result = "1.3.0" in 2
frame `summary_frame': replace operational_item = "Selected release" in 3
frame `summary_frame': replace result = "`year4'-`month2'" in 3
frame `summary_frame': replace operational_item = "Source dataset" in 4
frame `summary_frame': replace result = `"`source_dta'"' in 4
frame `summary_frame': replace operational_item = "Records retained" in 5
frame `summary_frame': replace result = "`input_records_display' in each selected dataset" in 5
frame `summary_frame': replace operational_item = "Missing age retained" in 6
frame `summary_frame': replace result = "`missing_age'" in 6
frame `summary_frame': replace operational_item = "Selected datasets" in 7
frame `summary_frame': replace result = "`selected'" in 7
frame `summary_frame': replace operational_item = "Replacement authorised" in 8
if `replace_existing' {
    frame `summary_frame': replace result = "Yes" in 8
}
else {
    frame `summary_frame': replace result = "No" in 8
}

local summary_row 8
forvalues output_row = 1/`output_rows' {
    local ++summary_row
    frame `summary_frame': replace operational_item = ///
        "`output_label`output_row''" in `summary_row'
    frame `summary_frame': replace result = ///
        `"`output_result`output_row''"' in `summary_row'
}

local ++summary_row
frame `summary_frame': replace operational_item = "Private output folder" in `summary_row'
frame `summary_frame': replace result = `"`output_dir'"' in `summary_row'
local ++summary_row
frame `summary_frame': replace operational_item = "Private log" in `summary_row'
frame `summary_frame': replace result = `"`output_log'"' in `summary_row'
local ++summary_row
frame `summary_frame': replace operational_item = "Next step" in `summary_row'
frame `summary_frame': replace result = ///
    "Use the selected input dataset(s) in the relevant Step 4 metric workflow." in `summary_row'

frame `summary_frame': label variable operational_item "Operational item"
frame `summary_frame': label variable result "Result"
frame `summary_frame': format operational_item %-24s
frame `summary_frame': format result %-180s

local original_linesize = c(linesize)
set linesize 220
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 3: OPERATIONAL RUN SUMMARY"
frame `summary_frame': noisily list operational_item result, noobs clean abbreviate(24)
noisily display as result "============================================================================="
set linesize `original_linesize'

frame drop `summary_frame'

}

quietly log close step3
capture program drop _bnr_step3_fail

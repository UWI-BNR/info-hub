/*******************************************************************************
DO-FILE:     bnr_step3_metric_inputs.do
VERSION:     2.1.0 (27 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 3 - create deidentified metric-input datasets

PURPOSE
    Create one or more private, deidentified event-level datasets from the
    confidential Step 2 release. Each output contains only the variables
    authorised for its later analytical purpose.

ROUTINE USE
    Analysts normally change only the command arguments: release year, release
    month, requested datasets, and optional final word replace.

    do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" ///
        2024 3 count case_fatality length_of_stay performance all_variables

AVAILABLE DATASETS
    count           Counts and incidence
    case_fatality   In-hospital case fatality
    length_of_stay  In-hospital length of stay
    performance     Care-performance measures
    all_variables   Union of all approved deidentified fields

IMPORTANT
    - Inputs and outputs remain confidential and outside Git.
    - This step does not calculate metrics or create staging/public files.
    - Generated outputs must not be edited manually.
*******************************************************************************/

version 19
clear all
set more off

* =============================================================================
* INTERNAL SUPPORT: STANDARD FAILURE MESSAGE
* =============================================================================
* Controlled failures use the same concise operational ending as Steps 1 and 2.

capture program drop _bnr_step3_fail
program define _bnr_step3_fail
    version 19
    args return_code release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 3: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:          Did not complete"
    noisily display as error "  Script version:      2.1.0"
    noisily display as error "  Selected release:    `release_id'"
    noisily display as error `"  Reason:              `reason'"'
    noisily display as error `"  Private log:         `log_path'"'
    noisily display as text  "  Action:               Do not use outputs from this incomplete run."
    noisily display as error "============================================================================="

    capture log close step3
    exit `return_code'
end

*===============================================================================
* 1. ANALYST INPUTS
*===============================================================================

* Read the full command line because the analyst may request several datasets.
local command_line `"`0'"'
gettoken release_year remainder : command_line
gettoken release_month options : remainder
local options : list retokenize options

if `"`release_year'"' == "" | `"`release_month'"' == "" | `"`options'"' == "" {
    display as error "Supply a release year, month and at least one dataset name."
    display as error "Allowed: count case_fatality length_of_stay performance all_variables"
    exit 198
}

* Convert the supplied options into simple yes/no flags.
local make_count          0
local make_case_fatality  0
local make_length_of_stay 0
local make_performance    0
local make_all_variables  0
local replace_existing    0

local number_options : word count `options'
local option_number 0
foreach option of local options {
    local ++option_number
    local option = lower("`option'")

    if "`option'" == "replace" {
        if `option_number' != `number_options' {
            display as error "replace must be the final word."
            exit 198
        }
        local replace_existing 1
    }
    else if inlist("`option'", "count", "case_fatality", ///
            "length_of_stay", "performance", "all_variables") {
        local make_`option' 1
    }
    else {
        display as error "Unrecognised dataset option: `option'"
        exit 198
    }
}

if `make_count' + `make_case_fatality' + `make_length_of_stay' + ///
        `make_performance' + `make_all_variables' == 0 {
    display as error "Select at least one dataset to create."
    exit 198
}


*===============================================================================
* 2. PROJECT PATHS AND RELEASE NAMES
*===============================================================================

* Load the local path file only when the current Stata session has not already
* loaded it. The path itself remains machine-specific and outside Git.
if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc exit _rc
}

foreach path in BNR_STATA BNR_DATA_DERIVED BNR_PRIVATE_LOGS {
    if `"$`path'"' == "" {
        display as error "Required project path is not configured: `path'"
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

local year4  : display %04.0f `year'
local month2 : display %02.0f `month'
local period "`year4'`month2'"

local source_dir "$BNR_DATA_DERIVED/cvd/y`year4'/m`month2'"
local source_id  "bnr_cvd_confidential_`period'_v01"
local source_dta "`source_dir'/`source_id'.dta"
local source_yml "`source_dir'/`source_id'.yml"
local output_dir "`source_dir'/metric_inputs"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_create_metric_inputs_`period'.log"

capture mkdir "$BNR_PRIVATE_LOGS"
capture mkdir "`output_dir'"

* Record the selected outputs in one readable list.
local selected ""
if `make_count'          local selected "`selected' count"
if `make_case_fatality'  local selected "`selected' case_fatality"
if `make_length_of_stay' local selected "`selected' length_of_stay"
if `make_performance'    local selected "`selected' performance"
if `make_all_variables'  local selected "`selected' all_variables"
local selected : list retokenize selected

* Run metadata required by the dataset notes and YAML receipts.
local today_iso : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local analyst "`c(username)'"

capture log close step3
log using "`output_log'", text replace name(step3)

quietly {

noisily display as text "BNR CVD STEP 3: DEIDENTIFIED METRIC-INPUT DATASETS"
noisily display as result "  Script version:     2.1.0"
noisily display as result "  Selected release:   `year4'-`month2'"
noisily display as result "  Source dataset:     `source_dta'"
noisily display as result "  Selected outputs:   `selected'"
noisily display as result "  Replace authorised: `replace_existing'"

* Routine commands are kept quiet so the Results window and log remain operational.
* Controlled failures and the final summary are displayed with noisily.


*===============================================================================
* 3. CHECK THE STEP 2 INPUT AND OUTPUT NAMES
*===============================================================================

capture confirm file "`source_dta'"
if _rc {
    _bnr_step3_fail 601 "`year4'-`month2'" `"`output_log'"' ///
        `"Step 2 dataset not found: `source_dta'"'
}

capture confirm file "`source_yml'"
if _rc {
    _bnr_step3_fail 601 "`year4'-`month2'" `"`output_log'"' ///
        `"Step 2 YAML receipt not found: `source_yml'"'
}

* Stop before reading the data if a selected output already exists and the
* analyst has not deliberately authorised replacement.
if !`replace_existing' {
    foreach dataset of local selected {
        local output_id "bnr_cvd_input_`dataset'_`period'_v01"
        capture confirm file "`output_dir'/`output_id'.dta"
        if !_rc {
            _bnr_step3_fail 602 "`year4'-`month2'" `"`output_log'"' ///
                `"Output already exists; rerun with replace only if intended: `output_dir'/`output_id'.dta"' 
        }
        capture confirm file "`output_dir'/`output_id'.yml"
        if !_rc {
            _bnr_step3_fail 602 "`year4'-`month2'" `"`output_log'"' ///
                `"YAML receipt already exists; rerun with replace only if intended: `output_dir'/`output_id'.yml"' 
        }
    }
}


*===============================================================================
* 4. OPEN AND CHECK THE CONFIDENTIAL SOURCE DATASET
*===============================================================================

use "`source_dta'", clear

* These positive lists define the complete deidentification contract. Analysts
* should change them only after an agreed metric or governance change.
local common_variables eid dco dco_alt etype doe yoe moe agey age5 age70 sex
local cf_variables parish dodi sadi dod
local los_variables doa htoa mtoa
local performance_variables htoe mtoe htecg mtecg doasp htoasp mtoasp ///
    asp_ampm dore htore mtore asp1 asp2 asp3 aspdose htype reperf ///
    repertype ecg doecg dmed1 dmed5
local all_variables "`common_variables' `cf_variables' `los_variables' `performance_variables'"
local all_variables : list uniq all_variables

* Build one required-variable list based on the outputs selected for this run.
local required_variables "`common_variables'"
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
            `"Required variable is missing from the Step 2 dataset: `variable'"'
    }
}

count
local input_records = r(N)
if `input_records' == 0 {
    _bnr_step3_fail 2000 "`year4'-`month2'" `"`output_log'"' ///
        "The Step 2 input contains no records."
}

capture isid eid
if _rc {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "eid does not uniquely identify the Step 2 records."
}

capture assert inlist(etype, 1, 2)
if _rc {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "etype contains values other than 1 (stroke) or 2 (AMI)."
}

capture assert !missing(doe) & yoe == year(doe) & moe == month(doe)
if _rc {
    _bnr_step3_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Event dates are missing or disagree with yoe/moe."
}

summarize doe, meanonly
local event_date_min : display %tdCCYY-NN-DD r(min)
local event_date_max : display %tdCCYY-NN-DD r(max)

count if missing(agey)
local missing_age = r(N)
count if etype == 1
local records_stroke = r(N)
count if etype == 2
local records_ami = r(N)

* A compact signature provides a stable receipt for the core event structure.
preserve
keep eid etype doe dco
sort eid
capture datasignature, nonames
if _rc local data_signature "not_available"
else local data_signature "`r(datasignature)'"
restore


*===============================================================================
* 5. CREATE EACH AUTHORISED DATASET AND YAML RECEIPT
*===============================================================================

foreach dataset of local selected {

    * Assign the approved variable list and plain-language description.
    if "`dataset'" == "count" {
        local variables "`common_variables'"
        local description "Deidentified event dataset for CVD counts and incidence"
    }
    else if "`dataset'" == "case_fatality" {
        local variables "`common_variables' `cf_variables'"
        local description "Deidentified event dataset for in-hospital case-fatality analysis"
    }
    else if "`dataset'" == "length_of_stay" {
        local variables "`common_variables' `los_variables' `cf_variables'"
        local description "Deidentified event dataset for in-hospital length-of-stay analysis"
    }
    else if "`dataset'" == "performance" {
        local variables "`common_variables' `performance_variables' `los_variables'"
        local description "Deidentified event dataset for care-performance analysis"
    }
    else if "`dataset'" == "all_variables" {
        local variables "`all_variables'"
        local description "Deidentified event dataset containing all approved metric-input fields"
    }

    local output_id  "bnr_cvd_input_`dataset'_`period'_v01"
    local output_dta "`output_dir'/`output_id'.dta"
    local output_yml "`output_dir'/`output_id'.yml"

    preserve
    keep `variables'
    sort doe etype eid

    * The keep command cannot change record count, but these two checks make the
    * essential one-row-per-event contract explicit for future analysts.
    assert _N == `input_records'
    isid eid

    label data "BNR CVD deidentified `dataset' metric-input dataset through `event_date_max'"
    notes _dta: title: BNR CVD deidentified `dataset' metric-input dataset
    notes _dta: dataset_id: `output_id'
    notes _dta: created: `today_iso'
    notes _dta: release: `year4'-`month2'
    notes _dta: tier: Confidential deidentified individual-level data
    notes _dta: unit_of_analysis: One row per CVD event
    notes _dta: parent_dataset: `source_id'
    notes _dta: deidentification: Direct identifiers removed by explicit variable list
    notes _dta: coverage_limitation: Post-2023 DCO surveillance is not yet included
    notes _dta: rights: Restricted to authorised BNR use; not for public release
    notes _dta: description: `description'

    if `replace_existing' {
        capture save "`output_dta'", replace
    }
    else {
        capture save "`output_dta'"
    }
    if _rc {
        local save_rc = _rc
        restore
        _bnr_step3_fail `save_rc' "`year4'-`month2'" `"`output_log'"' ///
            `"Could not save dataset: `output_dta'"'
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
    file write `yaml' "created: `today_iso'" _n
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
    file write `yaml' `"parent_dataset: "`source_id'""' _n
    file write `yaml' `"source_dataset: "`source_dta'""' _n
    file write `yaml' `"data_signature_core: "`data_signature'""' _n
    file write `yaml' "direct_identifiers_removed: true" _n
    file write `yaml' "variables:" _n
    foreach variable of local variables {
        file write `yaml' "  - `variable'" _n
    }
    file close `yaml'

    restore

    local created_datasets "`created_datasets' `dataset'"
    local created_files `"`created_files'|`output_dta'|`output_yml'"'
}



*===============================================================================
* 6. OPERATIONAL SUMMARY
*===============================================================================

local input_records_display : display %12.0fc `input_records'
local missing_age_display   : display %12.0fc `missing_age'

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 3: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             Completed successfully"
noisily display as text   "  Script version:         2.1.0"
noisily display as text   "  Selected release:       `year4'-`month2'"
noisily display as text   "  Records in each output: `input_records_display'"
noisily display as text   "  Missing age retained:   `missing_age_display'"
noisily display as text   "  Datasets created:       `selected'"
noisily display as text   "  Output folder:          `output_dir'"
noisily display as text   "  Private log:            `output_log'"
noisily display as text   "  Next step:              Calculate metric datasets and stage them (Step 4)."
noisily display as result "============================================================================="

}

quietly log close step3

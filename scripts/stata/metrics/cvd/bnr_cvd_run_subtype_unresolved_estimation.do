/*******************************************************************************

DO-FILE:     bnr_cvd_run_subtype_unresolved_estimation.do

VERSION:     1.0.3 (27 August 2026)

PURPOSE:     Stage 4E-b controller for private Heart and Stroke aggregate
             unresolved-linkage estimation. It reads the completed Stage 4E-a
             aggregate concordance profile and writes private DCO components.

             It does not calculate public metrics or rates, approve, promote
             or publish anything.

USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_unresolved_estimation.do" 2024 04 2026 07

              To deliberately replace existing Stage 4E-b outputs:

              do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_unresolved_estimation.do" 2024 04 2026 07 replace

*******************************************************************************/

version 19

clear all

set more off

args cvd_year cvd_month mortality_year mortality_month option

if `"`cvd_year'"' == "" | `"`cvd_month'"' == "" | ///
        `"`mortality_year'"' == "" | `"`mortality_month'"' == "" {
    display as error "CVD year/month and mortality year/month are required."
    exit 198
}

if `"`option'"' != "" & lower(`"`option'"') != "replace" {
    display as error "The only optional argument is replace."
    exit 198
}

local replace_existing = (lower(`"`option'"') == "replace")
local cvd_year_num = real("`cvd_year'")
local cvd_month_num = real("`cvd_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")

foreach numeric_argument in cvd_year_num cvd_month_num mortality_year_num mortality_month_num {
    if missing(``numeric_argument'') | ``numeric_argument'' != floor(``numeric_argument'') {
        display as error "Release arguments must be whole numbers."
        exit 198
    }
}

if !inrange(`cvd_month_num', 1, 12) | !inrange(`mortality_month_num', 1, 12) {
    display as error "Release months must be from 1 to 12."
    exit 198
}

if `"$BNR_PRIVATE"' == "" | `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

foreach required_global in BNR_PRIVATE BNR_STATA BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local cvd_year4 : display %04.0f `cvd_year_num'
local cvd_month2 : display %02.0f `cvd_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'
local cvd_release "cvd_`cvd_year4'_`cvd_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local linkage_release "`cvd_release'_`mortality_release'"

local input_dir "$BNR_PRIVATE/data/derived/cvd/y`cvd_year4'/m`cvd_month2'/linkage/mort_y`mortality_year4'_m`mortality_month2'"
local concordance_input "`input_dir'/stage4_subtype_concordance_`linkage_release'.dta"
local results_output "`input_dir'/stage4_subtype_unresolved_estimation_`linkage_release'.dta"
local qa_output "`input_dir'/stage4_subtype_unresolved_estimation_qa_`linkage_release'.csv"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_subtype_unresolved_estimation_`cvd_year4'`cvd_month2'_mort_`mortality_year4'`mortality_month2'.log"

capture confirm file `"`concordance_input'"'
if _rc {
    display as error "Required Stage 4E-a concordance profile was not found: `concordance_input'"
    exit 601
}

foreach output_file in results_output qa_output {
    capture confirm file ``output_file''
    if !_rc & !`replace_existing' {
        display as error "A Stage 4E-b private output already exists: ``output_file''"
        display as error "Review it or rerun with the explicit replace argument."
        exit 602
    }
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4e2
log using `"`output_log'"', text replace name(stage4e2)

display as text "BNR CVD STAGE 4E-B: PRIVATE SUBTYPE UNRESOLVED-LINKAGE ESTIMATION"
display as text "  CVD release:       `cvd_release'"
display as text "  Mortality release: `mortality_release'"
display as text "  Subtypes:          Heart and Stroke; concordant evidence only"
display as text "  Annual fallback:   annual, year +/-1, then all years; n >= 20"

capture noisily do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_subtype_unresolved_core.do" `"`concordance_input'"' `"`results_output'"' `"`qa_output'"'
if _rc {
    local core_rc = _rc
    display as error "Stage 4E-b did not complete; no public output was created."
    log close stage4e2
    exit `core_rc'
}

display as result ""
display as result "============================================================================="
display as result "STAGE 4E-B: PRIVATE SUBTYPE UNRESOLVED-LINKAGE ESTIMATION"
display as result "  Run status:             COMPLETE"
display as result "  Aggregate estimate:     `results_output'"
display as result "  Aggregate QA:           `qa_output'"
display as result "  Private log:            `output_log'"
display as result "  Next action:            Review subtype components before metric construction"
display as result "============================================================================="

log close stage4e2

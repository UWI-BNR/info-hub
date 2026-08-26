/*******************************************************************************

DO-FILE:     bnr_cvd_run_l01_episode_diagnostic.do

VERSION:     1.0.6 (25 August 2026)

PURPOSE:     Stage 4B controller for the private L01 exact-NRN and 28-day
              episode-linkage diagnostic.

              This controller calls only the controlled L01 pass. It does not
              run L02/L03, estimate unresolved records, create DCO metrics,
              prepare a review package, approve, promote or publish.

USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_run_l01_episode_diagnostic.do" 2024 04 2026 07

              To deliberately replace the two private Stage 4B outputs:

              do "$BNR_STATA/metrics/cvd/bnr_cvd_run_l01_episode_diagnostic.do" 2024 04 2026 07 replace

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

local input_dir ///
    "$BNR_PRIVATE/data/derived/cvd_linkage/y`cvd_year4'/m`cvd_month2'/mort_y`mortality_year4'_m`mortality_month2'"
local deaths_input ///
    "`input_dir'/bnr_cvd_linkage_deaths_`linkage_release'.dta"
local events_input ///
    "`input_dir'/bnr_cvd_linkage_events_`linkage_release'.dta"
local results_output ///
    "`input_dir'/stage4_l01_episode_diagnostic_`linkage_release'.dta"
local qa_output ///
    "`input_dir'/stage4_l01_episode_qa_`linkage_release'.csv"
local output_log ///
    "$BNR_PRIVATE_LOGS/bnr_cvd_l01_episode_`cvd_year4'`cvd_month2'_mort_`mortality_year4'`mortality_month2'.log"

foreach required_file in deaths_input events_input {
    capture confirm file ``required_file''
    if _rc {
        display as error "Required Stage 3 private input was not found: ``required_file''"
        exit 601
    }
}

foreach output_file in results_output qa_output {
    capture confirm file ``output_file''
    if !_rc & !`replace_existing' {
        display as error "A Stage 4B private output already exists: ``output_file''"
        display as error "Review it or rerun with the explicit replace argument."
        exit 602
    }
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4b
log using `"`output_log'"', text replace name(stage4b)

display as text "BNR CVD STAGE 4B: PRIVATE L01 AND EPISODE DIAGNOSTIC"
display as text "  CVD release:       `cvd_release'"
display as text "  Mortality release: `mortality_release'"
display as text "  Rule scope:         L01 exact NRN only"

capture noisily do "$BNR_STATA/metrics/cvd/bnr_cvd_l01_episode_core.do" `"`deaths_input'"' `"`events_input'"' `"`results_output'"' `"`qa_output'"'
if _rc {
    local core_rc = _rc
    display as error "Stage 4B did not complete; no public output was created."
    log close stage4b
    exit `core_rc'
}

display as result ""
display as result "============================================================================="
display as result "STAGE 4B: PRIVATE L01 AND EPISODE DIAGNOSTIC"
display as result "  Run status:             COMPLETE"
display as result "  Candidate diagnostic:   `results_output'"
display as result "  Aggregate QA:           `qa_output'"
display as result "  Private log:            `output_log'"
display as result "  Next action:            Review aggregate QA before L02/L03 implementation"
display as result "============================================================================="

log close stage4b

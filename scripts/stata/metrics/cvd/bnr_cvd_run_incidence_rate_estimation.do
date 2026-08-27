/*******************************************************************************
DO-FILE:     bnr_cvd_run_incidence_rate_estimation.do
VERSION:     1.0.8 (27 August 2026)
RELEASE:     Stage 3 rate-construction integrated release 1.0.7
PURPOSE:     Private controller for annual CVD crude and age-standardised rates.

USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_run_incidence_rate_estimation.do" 2024 04 2026 07 replace

NOTE:        Before this pass, prepare the two private reference assets using
             bnr_cvd_prepare_rate_reference.do. This controller never creates
             public output or invokes disclosure-control promotion.
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
if `"$BNR_STATA"' == "" | `"$BNR_PRIVATE"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc exit _rc
}
foreach g in BNR_STATA BNR_PRIVATE BNR_PRIVATE_LOGS {
    if `"$`g'"' == "" exit 198
}

local cy_num = real("`cvd_year'")
local cm_num = real("`cvd_month'")
local my_num = real("`mortality_year'")
local mm_num = real("`mortality_month'")
if missing(`cy_num', `cm_num', `my_num', `mm_num') | ///
        !inrange(`cm_num', 1, 12) | !inrange(`mm_num', 1, 12) | ///
        !inrange(`cy_num', 2010, 2100) | !inrange(`my_num', 2010, 2100) | ///
        `cy_num' != floor(`cy_num') | `cm_num' != floor(`cm_num') | ///
        `my_num' != floor(`my_num') | `mm_num' != floor(`mm_num') {
    display as error "Release years and months must be valid integers."
    exit 198
}
if (`my_num' * 12 + `mm_num') < (`cy_num' * 12 + `cm_num') {
    display as error "The mortality release cannot precede the CVD source release."
    exit 198
}
local cy : display %04.0f `cy_num'
local cm : display %02.0f `cm_num'
local my : display %04.0f `my_num'
local mm : display %02.0f `mm_num'
local release "`cy'_`cm'_mort_`my'_`mm'"
local linkage_release "cvd_`release'"
local linkage_dir "$BNR_PRIVATE/data/derived/cvd/y`cy'/m`cm'/linkage/mort_y`my'_m`mm'"
local reference_dir "$BNR_PRIVATE/data/reference/population"

local events_input "$BNR_PRIVATE/data/derived/cvd/y`cy'/m`cm'/bnr_cvd_confidential_`cy'`cm'_v01.dta"
local linkage_input "`linkage_dir'/stage4_l01_l03_episode_diagnostic_`linkage_release'.dta"
local joint_input "`linkage_dir'/stage4_joint_subtype_estimation_cvd_`release'.dta"
local population_input "`reference_dir'/wpp2024_brb_population_2010_2035_5y.dta"
local standard_input "`reference_dir'/who_world_standard_2000_2025.dta"
local rates_output "`linkage_dir'/stage4_incidence_rates_cvd_`release'.dta"
local components_output "`linkage_dir'/stage4_incidence_rate_components_cvd_`release'.dta"
local qa_output "`linkage_dir'/stage4_incidence_rates_qa_cvd_`release'.csv"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_incidence_rates_`cy'`cm'_mort_`my'`mm'.log"

display as text "Hospital-event input: `events_input'"
display as text "Final linkage input: `linkage_input'"
display as text "Joint DCO input: `joint_input'"
display as text "Population reference: `population_input'"
display as text "WHO standard reference: `standard_input'"

foreach f in events_input linkage_input joint_input population_input standard_input {
    capture confirm file ``f''
    if _rc {
        local dependency = "`f'"
        if "`f'" == "events_input" local dependency "hospital-event input"
        if "`f'" == "linkage_input" local dependency "final linkage input"
        if "`f'" == "joint_input" local dependency "joint DCO input"
        if "`f'" == "population_input" local dependency "WPP 2024 population reference"
        if "`f'" == "standard_input" local dependency "WHO standard-population reference"
        display as error "Missing `dependency': ``f''"
        if "`f'" == "standard_input" {
            display as error "Create or install who_world_standard_2000_2025.dta before running rates."
        }
        exit 601
    }
}
foreach f in rates_output components_output qa_output {
    capture confirm file ``f''
    if !_rc & lower(`"`option'"') != "replace" {
        display as error "Private rate output already exists: ``f''"
        exit 602
    }
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4rates
log using `"`output_log'"', text replace name(stage4rates)
display as text "BNR CVD PRIVATE ANNUAL INCIDENCE RATE CONSTRUCTION"
display as text "Implementation release: 1.0.7"
local complete_year = `cy_num'
if `cm_num' < 12 local complete_year = `cy_num' - 1
display as text "Complete annual rate range: 2010--`complete_year'"
capture noisily do "$BNR_STATA/metrics/cvd/bnr_cvd_construct_incidence_rates_core.do" `"`events_input'"' `"`linkage_input'"' `"`joint_input'"' `"`population_input'"' `"`standard_input'"' `"`rates_output'"' `"`components_output'"' `"`qa_output'"' `cy' `cm'
if _rc {
    local rc = _rc
    display as error "Rate construction did not complete; no public output was created."
    log close stage4rates
    exit `rc'
}
display as result "Private annual CVD rate construction completed."
display as result "  Candidate rates: `rates_output'"
display as result "  Components:      `components_output'"
display as result "  QA:              `qa_output'"
display as result "  Log:             `output_log'"
log close stage4rates

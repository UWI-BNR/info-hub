/*******************************************************************************
DO-FILE:     bnr_cvd_run_joint_subtype_estimation.do
VERSION:     1.0.6 (25 August 2026)
PURPOSE:     Stage 4E-c controller for joint Heart/Stroke/mixed DCO allocation.
USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_run_joint_subtype_estimation.do" 2024 04 2026 07 replace
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
if `"`option'"' != "" & lower(`"`option'"') != "replace" exit 198
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
local cy : display %04.0f `cy_num'
local cm : display %02.0f `cm_num'
local my : display %04.0f `my_num'
local mm : display %02.0f `mm_num'
local release "`cy'_`cm'_mort_`my'_`mm'"
local linkage_release "cvd_`release'"
local dir "$BNR_PRIVATE/data/derived/cvd_linkage/y`cy'/m`cm'/mort_y`my'_m`mm'"
local all_input "`dir'/stage4_unresolved_estimation_cvd_`release'.dta"
local concordance_input "`dir'/stage4_subtype_concordance_`linkage_release'.dta"
local results_output "`dir'/stage4_joint_subtype_estimation_cvd_`release'.dta"
local qa_output "`dir'/stage4_joint_subtype_estimation_qa_cvd_`release'.csv"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_joint_subtype_estimation_`cy'`cm'_mort_`my'`mm'.log"
foreach f in all_input concordance_input {
    capture confirm file ``f''
    if _rc {
        display as error "Required input not found: ``f''"
        exit 601
    }
}
foreach f in results_output qa_output {
    capture confirm file ``f''
    if !_rc & lower(`"`option'"') != "replace" exit 602
}
capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4e3joint
log using `"`output_log'"', text replace name(stage4e3joint)
display as text "BNR CVD STAGE 4E-C: JOINT SUBTYPE DCO ESTIMATION"
capture noisily do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_joint_subtype_core.do" ///
    `"`all_input'"' `"`concordance_input'"' `"`results_output'"' `"`qa_output'"'
if _rc {
    local rc = _rc
    display as error "Stage 4E-c joint estimator did not complete; no public output was created."
    log close stage4e3joint
    exit `rc'
}
display as result "Stage 4E-c joint subtype DCO estimation completed."
display as result "  Results: `results_output'"
display as result "  QA:      `qa_output'"
display as result "  Log:     `output_log'"
log close stage4e3joint

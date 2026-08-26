/*******************************************************************************
DO-FILE:     bnr_cvd_run_subtype_reconciliation.do
VERSION:     1.0.3 (25 August 2026)
PURPOSE:     Stage 4E-c controller for constrained Heart/Stroke/mixed DCO
             reconciliation. Private outputs only.
USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_reconciliation.do" 2024 04 2026 07 replace
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
local cvd_year_num = real("`cvd_year'")
local cvd_month_num = real("`cvd_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")
local cy : display %04.0f `cvd_year_num'
local cm : display %02.0f `cvd_month_num'
local my : display %04.0f `mortality_year_num'
local mm : display %02.0f `mortality_month_num'
local release "`cy'_`cm'_mort_`my'_`mm'"
local dir "$BNR_PRIVATE/data/derived/cvd_linkage/y`cy'/m`cm'/mort_y`my'_m`mm'"
local all_input "`dir'/stage4_unresolved_estimation_cvd_`release'.dta"
local subtype_input "`dir'/stage4_subtype_unresolved_estimation_cvd_`release'.dta"
local results_output "`dir'/stage4_subtype_reconciliation_`release'.dta"
local qa_output "`dir'/stage4_subtype_reconciliation_qa_`release'.csv"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_subtype_reconciliation_`cy'`cm'_mort_`my'`mm'.log"
capture confirm file `"`all_input'"'
if _rc {
    display as error "Stage 4D output not found: `all_input'"
    exit 601
}
capture confirm file `"`subtype_input'"'
if _rc {
    display as error "Stage 4E-b output not found: `subtype_input'"
    exit 601
}
foreach f in results_output qa_output {
    capture confirm file ``f''
    if !_rc & lower(`"`option'"') != "replace" {
        display as error "Output exists; rerun with replace: ``f''"
        exit 602
    }
}
capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4e3
log using `"`output_log'"', text replace name(stage4e3)
display as text "BNR CVD STAGE 4E-C: CONSTRAINED SUBTYPE RECONCILIATION"
capture noisily do "$BNR_STATA/metrics/cvd/bnr_cvd_reconcile_subtype_core.do" ///
    `"`all_input'"' `"`subtype_input'"' `"`results_output'"' `"`qa_output'"'
if _rc {
    local rc = _rc
    display as error "Stage 4E-c did not complete; no public output was created."
    log close stage4e3
    exit `rc'
}
display as result "Stage 4E-c constrained reconciliation completed."
display as result "  Reconciled output: `results_output'"
display as result "  QA output:         `qa_output'"
display as result "  Private log:       `output_log'"
log close stage4e3

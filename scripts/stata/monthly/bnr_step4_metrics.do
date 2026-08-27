/*******************************************************************************
DO-FILE: bnr_step4_metrics.do
VERSION: 3.0.1 (27 August 2026)
PURPOSE: Calculate and privately stage the combined CVD burden and annual-rate
         package. This step does not review, approve or publish.

ROUTINE USE:
  do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 4 2026 7
  do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 4 2026 7 replace
*******************************************************************************/
version 19
clear all
set more off

args cvd_year cvd_month mortality_year mortality_month option
foreach argument in cvd_year cvd_month mortality_year mortality_month {
    if "``argument''" == "" exit 198
}
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_mode = (lower("`option'") == "replace")
foreach argument in cvd_year cvd_month mortality_year mortality_month {
    local `argument'_number = real("``argument''")
    if missing(``argument'_number') | ``argument'_number' != floor(``argument'_number') exit 198
}
if !inrange(`cvd_month_number', 1, 12) | !inrange(`mortality_month_number', 1, 12) exit 198
if (`mortality_year_number' * 12 + `mortality_month_number') < (`cvd_year_number' * 12 + `cvd_month_number') exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_STATA BNR_PRIVATE BNR_STAGING BNR_DATA_DERIVED BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}
local cy : display %04.0f `cvd_year_number'
local cm : display %02.0f `cvd_month_number'
local my : display %04.0f `mortality_year_number'
local mm : display %02.0f `mortality_month_number'
local release_id "cvd_`cy'_`cm'"
local linkage_release "cvd_`cy'_`cm'_mort_`my'_`mm'"
local input_counts "$BNR_DATA_DERIVED/cvd/y`cy'/m`cm'/metric_inputs/bnr_cvd_input_count_`cy'`cm'_v01.dta"
local input_metadata "$BNR_DATA_DERIVED/cvd/y`cy'/m`cm'/metric_inputs/bnr_cvd_input_count_`cy'`cm'_v01.yml"
local linkage_dir "$BNR_PRIVATE/data/derived/cvd/y`cy'/m`cm'/linkage/mort_y`my'_m`mm'"
local rates_dta "`linkage_dir'/stage4_incidence_rates_cvd_`cy'_`cm'_mort_`my'_`mm'.dta"
local components_dta "`linkage_dir'/stage4_incidence_rate_components_cvd_`cy'_`cm'_mort_`my'_`mm'.dta"
local package_dir "$BNR_STAGING/metrics/cvd/`release_id'"
capture confirm file "`input_counts'"
if _rc exit 601
capture confirm file "`input_metadata'"
if _rc exit 601

* Linkage and rate construction remain explicit, ordered private calculations.
foreach program in bnr_cvd_prepare_linkage_inputs bnr_cvd_profile_linkage_inputs bnr_cvd_run_l01_episode_diagnostic bnr_cvd_run_l02_l03_episode_diagnostic bnr_cvd_run_unresolved_estimation bnr_cvd_run_subtype_concordance_profile bnr_cvd_run_subtype_unresolved_estimation bnr_cvd_run_joint_subtype_estimation bnr_cvd_run_incidence_rate_estimation {
    do "$BNR_STATA/metrics/cvd/`program'.do" `cy' `cm' `my' `mm' `option'
}
tempfile burden_dta burden_qa
do "$BNR_STATA/metrics/cvd/bnr_step4_cvd_burden.do" "`input_counts'" "`input_metadata'" "`release_id'" "`burden_dta'" "`burden_qa'" "`cy'" "`cm'"
do "$BNR_STATA/metrics/cvd/bnr_step4_stage_expanded_cvd.do" "`burden_dta'" "`rates_dta'" "`components_dta'" "`package_dir'" "`release_id'" "`replace_mode'"
display as result "CVD Step 4 combined calculation and staging passed."

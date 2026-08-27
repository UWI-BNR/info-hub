/*******************************************************************************
DO-FILE: bnr_step4_stage_expanded_cvd.do
VERSION: 1.1.0 (27 August 2026)
PURPOSE: Stage separate private CVD burden and rate calculation products.
*******************************************************************************/
version 19
clear all
set more off

args burden_dta rates_dta components_dta package_dir release_id replace_mode
foreach argument in burden_dta rates_dta components_dta package_dir release_id replace_mode {
    if "``argument''" == "" exit 198
}
if !inlist("`replace_mode'", "0", "1") exit 198
foreach input_file in burden_dta rates_dta components_dta {
    capture confirm file "``input_file''"
    if _rc exit 601
}

local datasets_dir "`package_dir'/datasets"
local review_dir "`package_dir'/review"
local burden_out "`datasets_dir'/cvd_burden_metrics_`release_id'.dta"
local rates_out "`datasets_dir'/cvd_incidence_rates_`release_id'.dta"
local components_out "`review_dir'/cvd_incidence_rate_components_`release_id'.dta"
foreach output_file in burden_out rates_out components_out {
    capture confirm file "``output_file''"
    if !_rc & "`replace_mode'" == "0" exit 602
}
capture mkdir "`package_dir'"
capture mkdir "`datasets_dir'"
capture mkdir "`review_dir'"

* The two inputs have different private calculation grains.  Do not append
* them here: Step 5 Stage 1 is the tested and sole normalisation boundary.
use "`burden_dta'", clear
save "`burden_out'", replace
use "`rates_dta'", clear
save "`rates_out'", replace
use "`components_dta'", clear
save "`components_out'", replace
display as result "Expanded CVD Step 4 private calculation products staged."

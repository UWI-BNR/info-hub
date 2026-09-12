/*******************************************************************************
PURPOSE: Synthetic I/O test for the expanded CVD Step 4 staging helper.
VERSION: 1.0.0 (27 August 2026)
*******************************************************************************/
version 19
clear all
set more off
display as result "Running expanded CVD Step 4 staging test v1.0.0"
if "$BNR_STATA" == "" exit 198
tempfile burden rates components
tempname package_root
local package_root "`c(tmpdir)'/bnr_cvd_step4_stage_test"

clear
set obs 1
generate str20 metric_id = "CVD-BURDEN-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate str12 period = "2099"
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str12 age_group = "all"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str30 statistic = "annual_count"
save "`burden'", replace

clear
set obs 1
generate str20 metric_id = "CVD-INCIDENCE-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate str12 period = "2099"
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str12 age_group = "all"
generate str24 ascertainment_scope = "hospital_plus_dco"
generate str20 mortality_definition = "primary"
generate str12 estimate_basis = "estimated"
generate str30 statistic = "annual_crude_rate"
save "`rates'", replace

clear
set obs 1
generate str20 mortality_definition = "primary"
generate int dth_year = 2099
generate str20 category = "all_cvd"
generate str8 sex = "all"
generate str18 age_group = "all"
generate double dco_lower_component_n = 1
generate double dco_central_component_n = 1
generate double dco_upper_component_n = 1
save "`components'", replace

do "$BNR_STATA/metrics/cvd/bnr_step4_stage_expanded_cvd.do" "`burden'" "`rates'" "`components'" "`package_root'" "cvd_2099_01" "1"
use "`package_root'/datasets/cvd_burden_metrics_cvd_2099_01.dta", clear
assert _N == 1
use "`package_root'/datasets/cvd_incidence_rates_cvd_2099_01.dta", clear
assert _N == 1
use "`package_root'/review/cvd_incidence_rate_components_cvd_2099_01.dta", clear
assert _N == 1
display as result "Expanded CVD Step 4 staging test passed."

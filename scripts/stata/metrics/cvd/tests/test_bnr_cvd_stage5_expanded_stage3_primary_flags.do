/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage3_primary_flags.do
VERSION: 0.4.0 (26 August 2026)
PURPOSE: Synthetic test for expanded CVD Step 5 Stage 3 primary flags.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 3 primary-flag test v0.4.0"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage3_primary_flags.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile combined_input support_input primary_output qa_output

clear
set obs 5
generate str20 metric_id = "CVD-INCIDENCE-001"
replace metric_id = "CVD-BURDEN-001" in 5
generate str12 release_id = "cvd_2099_01"
generate int period_year = 2099
generate str20 event_type = "heart"
replace event_type = "all_cvd" in 5
generate str8 sex = "female"
replace sex = "all" in 5
generate str18 age_group = "all"
replace age_group = "age_standardised" in 2
generate str24 ascertainment_scope = "hospital_only"
replace ascertainment_scope = "hospital_plus_dco" in 3/4
generate str20 mortality_definition = "not_applicable"
replace mortality_definition = "primary" in 3/4
generate str45 statistic = "annual_crude_rate"
replace statistic = "annual_age_standardised_rate" in 2/4
replace statistic = "annual_count" in 5
generate double numerator = 3
replace numerator = . in 2/4
replace numerator = 20 in 3/5
generate byte primary_suppression = 0
replace primary_suppression = 1 in 5
generate byte suppression_review = primary_suppression
save "`combined_input'", replace

clear
set obs 2
generate str20 mortality_definition = "primary"
generate int period_year = 2099
generate str20 event_type = "heart"
replace event_type = "stroke" in 2
generate str8 sex = "female"
generate byte component_primary_suppression = 1
replace component_primary_suppression = 0 in 2
save "`support_input'", replace

do "`helper_path'" "`combined_input'" "`support_input'" "`primary_output'" "`qa_output'" "cvd_2099_01"

use "`primary_output'", clear
quietly count if metric_id == "CVD-INCIDENCE-001" & ascertainment_scope == "hospital_only" & primary_suppression == 1
assert r(N) == 2
quietly count if metric_id == "CVD-INCIDENCE-001" & ascertainment_scope == "hospital_plus_dco" & primary_suppression == 1
assert r(N) == 2
quietly count if metric_id == "CVD-BURDEN-001" & primary_suppression == 1
assert r(N) == 1

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 3 primary-flag test passed."

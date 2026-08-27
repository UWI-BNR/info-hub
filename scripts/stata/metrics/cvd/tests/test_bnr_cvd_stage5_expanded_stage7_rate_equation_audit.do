/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage7_rate_equation_audit.do
VERSION: 0.8.1 (27 August 2026)
PURPOSE: Synthetic test for annual rate protection-propagation audit.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 7 rate-equation audit test v0.8.1"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage7_rate_equation_audit.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile closure_input audited_output equation_output qa_output

clear
set obs 5
generate str20 metric_id = "CVD-INCIDENCE-001"
replace metric_id = "CVD-BURDEN-001" in 5
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int period_year = 2099
generate str20 event_type = "heart"
generate str8 sex = "female"
generate str18 age_group = "all"
replace age_group = "age_standardised" in 2/4
generate str24 ascertainment_scope = "hospital_only"
replace ascertainment_scope = "hospital_plus_dco" in 3/4
generate str20 mortality_definition = "not_applicable"
replace mortality_definition = "primary" in 3/4
generate str45 statistic = "annual_crude_rate"
replace statistic = "annual_age_standardised_rate" in 2/4
generate str28 stage6_protection_status = "none"
replace stage6_protection_status = "primary" in 3/4
save "`closure_input'", replace

do "`helper_path'" "`closure_input'" "`audited_output'" "`equation_output'" "`qa_output'" "cvd_2099_01"

use "`audited_output'", clear
quietly count if metric_id == "CVD-INCIDENCE-001" & stage7_rate_protected == 1
assert r(N) == 2
quietly count if metric_id == "CVD-BURDEN-001" & !missing(stage7_rate_protected)
assert r(N) == 0

use "`equation_output'", clear
assert _N == 2
assert rate_rows == 2
assert protected_min == protected_max
assert result == "PASS"

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 7 rate-equation audit test passed."

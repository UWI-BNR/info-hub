/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage2_dco_support.do
VERSION: 0.3.0 (26 August 2026)
PURPOSE: Synthetic test for expanded CVD Step 5 Stage 2 DCO support.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 2 DCO-support test v0.3.0"

if "$BNR_STATA" == "" {
    display as error "Load bnr_paths_LOCAL.do before running this test."
    exit 198
}

local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage2_dco_support.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile components_input support_output qa_output

clear
set obs 4
generate str20 mortality_definition = "primary"
generate int dth_year = 2099
generate str20 category = ""
replace category = "heart" in 1/2
replace category = "stroke" in 3
replace category = "all_cvd" in 4
generate str8 sex = "female"
generate str18 age_group = ""
replace age_group = "age_0_4" in 1
replace age_group = "age_5_9" in 2
replace age_group = "age_0_4" in 3/4
generate double dco_lower_component_n = 0
replace dco_lower_component_n = 1 in 1
replace dco_lower_component_n = 2 in 2
replace dco_lower_component_n = 10 in 3
replace dco_lower_component_n = 13 in 4
generate double dco_central_component_n = dco_lower_component_n
generate double dco_upper_component_n = dco_lower_component_n
save "`components_input'", replace

do "`helper_path'" "`components_input'" "`support_output'" "`qa_output'" "cvd_2099_01"

use "`support_output'", clear
assert _N == 3
quietly count if event_type == "heart" & dco_central_component_n == 3 & component_primary_suppression == 1
assert r(N) == 1
quietly count if event_type == "stroke" & dco_central_component_n == 10 & component_primary_suppression == 0
assert r(N) == 1
quietly count if event_type == "all_cvd" & dco_central_component_n == 13 & component_primary_suppression == 0
assert r(N) == 1

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 2 DCO-support test passed."

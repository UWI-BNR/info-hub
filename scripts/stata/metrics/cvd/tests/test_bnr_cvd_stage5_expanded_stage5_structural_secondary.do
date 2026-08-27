/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage5_structural_secondary.do
VERSION: 0.6.1 (27 August 2026)
PURPOSE: Synthetic test for structural secondary flags.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 5 structural-secondary test v0.6.1"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage5_structural_secondary.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile primary_input support_input closure_output qa_output empty_support_input empty_closure_output empty_qa_output

clear
set obs 4
generate str20 metric_id = "CVD-INCIDENCE-001"
generate str12 release_id = "cvd_2099_01"
generate int period_year = 2099
generate str20 event_type = "heart"
replace event_type = "stroke" in 3/4
generate str8 sex = "female"
replace sex = "male" in 1
generate str24 ascertainment_scope = "hospital_plus_dco"
replace ascertainment_scope = "hospital_only" in 4
generate str20 mortality_definition = "primary"
generate byte primary_suppression = 0
generate byte suppression_review = 0
save "`primary_input'", replace

clear
set obs 3
generate str20 mortality_definition = "primary"
generate int period_year = 2099
generate str20 event_type = "heart"
replace event_type = "mixed_unallocated" in 2
replace event_type = "stroke" in 3
generate str8 sex = "unknown"
replace sex = "female" in 2/3
generate double dco_lower_component_n = 0
replace dco_lower_component_n = 2 in 1/2
generate double dco_central_component_n = dco_lower_component_n
generate double dco_upper_component_n = dco_lower_component_n
save "`support_input'", replace

do "`helper_path'" "`primary_input'" "`support_input'" "`closure_output'" "`qa_output'" "cvd_2099_01"

use "`closure_output'", clear
quietly count if event_type == "heart" & sex == "male" & stage5_structural_secondary == 1
assert r(N) == 1
quietly count if event_type == "stroke" & sex == "female" & ascertainment_scope == "hospital_plus_dco" & stage5_structural_secondary == 1
assert r(N) == 1
quietly count if event_type == "stroke" & ascertainment_scope == "hospital_only" & stage5_structural_secondary == 0
assert r(N) == 1

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

clear
set obs 1
generate str20 mortality_definition = "primary"
generate int period_year = 2099
generate str20 event_type = "heart"
generate str8 sex = "female"
generate double dco_lower_component_n = 0
generate double dco_central_component_n = 0
generate double dco_upper_component_n = 0
save "`empty_support_input'", replace

do "`helper_path'" "`primary_input'" "`empty_support_input'" "`empty_closure_output'" "`empty_qa_output'" "cvd_2099_01"

use "`empty_closure_output'", clear
quietly count if stage5_structural_secondary == 1
assert r(N) == 0

use "`empty_qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 5 structural-secondary test passed."

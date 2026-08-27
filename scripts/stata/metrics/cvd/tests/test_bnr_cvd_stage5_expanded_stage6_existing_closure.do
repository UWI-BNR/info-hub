/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage6_existing_closure.do
VERSION: 0.7.0 (27 August 2026)
PURPOSE: Synthetic test for established burden related-cell closure.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 6 existing-closure test v0.7.0"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage6_existing_closure.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile structural_input closure_output qa_output

clear
set obs 4
generate str20 metric_id = "CVD-BURDEN-001"
replace metric_id = "CVD-INCIDENCE-001" in 4
generate str12 release_id = "cvd_2099_01"
generate byte primary_suppression = 0
replace primary_suppression = 1 in 1
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
replace related_suppression_review = 1 in 2
generate byte suppression_review = primary_suppression
generate byte stage5_structural_secondary = 0
replace stage5_structural_secondary = 1 in 4
save "`structural_input'", replace

do "`helper_path'" "`structural_input'" "`closure_output'" "`qa_output'" "cvd_2099_01"

use "`closure_output'", clear
quietly count if stage6_protection_status == "primary"
assert r(N) == 1
quietly count if _n == 2 & stage6_protection_status == "secondary_existing"
assert r(N) == 1
quietly count if _n == 3 & stage6_protection_status == "none"
assert r(N) == 1
quietly count if _n == 4 & stage6_protection_status == "secondary_structural"
assert r(N) == 1
quietly count if stage6_existing_secondary == 1
assert r(N) == 1
quietly count if suppression_review == 1
assert r(N) == 3

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 6 existing-closure test passed."

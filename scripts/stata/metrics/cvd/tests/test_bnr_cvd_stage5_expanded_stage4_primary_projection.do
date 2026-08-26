/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage4_primary_projection.do
VERSION: 0.5.0 (26 August 2026)
PURPOSE: Synthetic test for expanded CVD Step 5 Stage 4 primary projection.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 4 primary-projection test v0.5.0"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage4_primary_projection.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile primary_input candidate_output qa_output

clear
set obs 2
generate str12 release_id = "cvd_2099_01"
generate str20 metric_id = "CVD-INCIDENCE-001"
generate double value = 100
generate double numerator = 3
generate double denominator = 20000
generate double linkage_lower_value = 90
generate double linkage_upper_value = 110
generate byte primary_suppression = 0
replace primary_suppression = 1 in 1
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = primary_suppression
generate str80 suppression_reason = ""
generate byte stage3_original_primary = primary_suppression
generate byte stage3_hospital_primary = primary_suppression
generate byte stage3_dco_primary = 0
save "`primary_input'", replace

do "`helper_path'" "`primary_input'" "`candidate_output'" "`qa_output'" "cvd_2099_01"

use "`candidate_output'", clear
assert _N == 2
assert suppression_status == "primary" in 1
assert display_value == "*" in 1
assert missing(value) & missing(numerator) & missing(denominator) & missing(linkage_lower_value) & missing(linkage_upper_value) in 1
assert suppression_status == "none" in 2
assert value == 100 & numerator == 3 & denominator == 20000 in 2
capture confirm variable primary_suppression
assert _rc != 0
capture confirm variable stage3_hospital_primary
assert _rc != 0

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 4 primary-projection test passed."

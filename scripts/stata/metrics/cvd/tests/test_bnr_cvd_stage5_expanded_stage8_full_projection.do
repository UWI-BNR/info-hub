/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage8_full_projection.do
VERSION: 0.9.1 (27 August 2026)
PURPOSE: Synthetic test for combined primary and secondary projection.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 8 full-projection test v0.9.1"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage8_full_projection.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile audited_input candidate_output qa_output

clear
set obs 4
generate str12 release_id = "cvd_2099_01"
generate double value = 101
generate double numerator = 11
generate double denominator = 10000
generate double linkage_lower_value = 90
generate double linkage_upper_value = 110
generate str28 stage6_protection_status = "primary"
replace stage6_protection_status = "secondary_structural" in 2
replace stage6_protection_status = "secondary_existing" in 3
replace stage6_protection_status = "none" in 4
generate byte primary_suppression = stage6_protection_status == "primary"
generate byte stage5_structural_secondary = stage6_protection_status == "secondary_structural"
generate byte stage6_existing_secondary = stage6_protection_status == "secondary_existing"
generate byte stage7_rate_protected = stage6_protection_status != "none"
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
save "`audited_input'", replace

do "`helper_path'" "`audited_input'" "`candidate_output'" "`qa_output'" "cvd_2099_01"

use "`candidate_output'", clear
quietly count if suppression_status != "none" & (!missing(value) | !missing(numerator) | !missing(denominator) | !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0
quietly count if suppression_status == "none" & value == 101 & numerator == 11 & denominator == 10000
assert r(N) == 1
quietly count if suppression_status == "primary" & display_value == "*"
assert r(N) == 1
quietly count if suppression_status == "secondary"
assert r(N) == 2
capture confirm variable stage6_protection_status
assert _rc != 0
capture confirm variable stage7_rate_protected
assert _rc != 0
capture confirm variable sdc_policy
assert _rc != 0
capture confirm variable primary_suppression_threshold
assert _rc != 0

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 8 full-projection test passed."

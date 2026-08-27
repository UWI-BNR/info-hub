/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage9_candidate_audit.do
VERSION: 1.0.1 (27 August 2026)
PURPOSE: Synthetic test for final private-to-candidate row audit.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 9 candidate-audit test v1.0.1"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage9_candidate_audit.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile audited_input candidate_input row_output qa_output

clear
set obs 4
generate str20 metric_id = "CVD-BURDEN-001"
replace metric_id = "CVD-INCIDENCE-001" in 3/4
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int period_year = 2099
generate byte period_month = .
generate str20 event_type = "all_cvd"
replace event_type = "heart" in 2/3
replace event_type = "stroke" in 4
generate str8 sex = "all"
generate str18 age_group = "all"
replace age_group = "age_standardised" in 4
generate str45 statistic = "annual_count"
replace statistic = "annual_crude_rate" in 3
replace statistic = "annual_age_standardised_rate" in 4
generate str20 mortality_definition = "not_applicable"
replace mortality_definition = "primary" in 3/4
generate str28 stage6_protection_status = "primary"
replace stage6_protection_status = "secondary_existing" in 2
replace stage6_protection_status = "secondary_structural" in 3
replace stage6_protection_status = "none" in 4
generate byte related_suppression_review = stage6_protection_status == "secondary_existing"
save "`audited_input'", replace

use "`audited_input'", clear
generate str12 suppression_status = "none"
replace suppression_status = "primary" if stage6_protection_status == "primary"
replace suppression_status = "secondary" if inlist(stage6_protection_status, "secondary_existing", "secondary_structural")
generate double value = 100
generate double numerator = 10
generate double denominator = 10000
generate double linkage_lower_value = 90
generate double linkage_upper_value = 110
replace value = . if suppression_status != "none"
replace numerator = . if suppression_status != "none"
replace denominator = . if suppression_status != "none"
replace linkage_lower_value = . if suppression_status != "none"
replace linkage_upper_value = . if suppression_status != "none"
drop stage6_protection_status related_suppression_review
save "`candidate_input'", replace

do "`helper_path'" "`audited_input'" "`candidate_input'" "`row_output'" "`qa_output'" "cvd_2099_01"

use "`row_output'", clear
assert _N == 4
assert result == "PASS"
assert protection_failure == 0
assert comparator_failure == 0
assert numeric_failure == 0

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 9 candidate-audit test passed."

/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_end_to_end.do
VERSION: 1.0.1 (27 August 2026)
PURPOSE: End-to-end synthetic test for the expanded CVD Step 5 helper.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 end-to-end test v1.0.1"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile burden_input rates_input components_input candidate_output qa_output equation_output row_output

clear
set obs 1
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-BURDEN-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate str20 period = "2099"
generate str10 period_start = "2099-01-01"
generate int period_year = 2099
generate byte period_month = .
generate byte period_quarter = .
generate byte period_complete = 1
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str12 age_group = "all"
generate str30 source_status = "hospital_registered"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str45 statistic = "annual_count"
generate double value = 20
generate str15 unit = "count"
generate double numerator = 20
generate double denominator = .
generate double linkage_lower_value = .
generate double linkage_upper_value = .
generate int comparison_n = .
generate str25 status_flag = "final"
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = 0
generate int related_primary_cells = 1
generate byte related_suppression_review = 1
generate byte suppression_review = 1
generate str80 suppression_reason = "related count"
save "`burden_input'", replace

clear
set obs 6
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-INCIDENCE-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int dth_year = 2099
generate byte period_month = .
generate str20 event_type = "heart"
replace event_type = "stroke" in 5/6
generate str8 sex = "female"
generate str18 age_group = "all"
replace age_group = "age_standardised" if inlist(_n, 2, 4, 6)
generate str24 ascertainment_scope = "hospital_only"
replace ascertainment_scope = "hospital_plus_dco" in 3/6
generate str20 mortality_definition = "not_applicable"
replace mortality_definition = "primary" in 3/6
generate str12 estimate_basis = "observed"
replace estimate_basis = "estimated" in 3/6
generate str15 unit = "rate_per_100000"
generate double value = 100
generate double numerator = 3
replace numerator = . if age_group == "age_standardised"
replace numerator = 10 if event_type == "stroke" & age_group == "all"
generate double denominator = 20000
replace denominator = . if age_group == "age_standardised"
generate double linkage_lower_value = .
generate double linkage_upper_value = .
replace linkage_lower_value = 90 if ascertainment_scope == "hospital_plus_dco"
replace linkage_upper_value = 110 if ascertainment_scope == "hospital_plus_dco"
generate byte period_complete = 1
generate str25 status_flag = "final"
save "`rates_input'", replace

clear
set obs 3
generate str20 mortality_definition = "primary"
generate int dth_year = 2099
generate str20 category = "heart"
replace category = "stroke" in 2
replace category = "mixed_unallocated" in 3
generate str8 sex = "female"
generate str18 age_group = "age_0_4"
generate double dco_lower_component_n = 3
replace dco_lower_component_n = 10 in 2
replace dco_lower_component_n = 2 in 3
generate double dco_central_component_n = dco_lower_component_n
generate double dco_upper_component_n = dco_lower_component_n
save "`components_input'", replace

do "`helper_path'" "`burden_input'" "`rates_input'" "`components_input'" "`candidate_output'" "`qa_output'" "`equation_output'" "`row_output'" "cvd_2099_01"

use "`candidate_output'", clear
quietly count if suppression_status != "none" & (!missing(value) | !missing(numerator) | !missing(denominator) | !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0
quietly count if suppression_status == "primary"
assert r(N) == 4
quietly count if suppression_status == "secondary"
assert r(N) == 3

use "`equation_output'", clear
assert result == "PASS"

use "`row_output'", clear
assert result == "PASS"

use "`qa_output'", clear
assert _N == 32
assert result == "PASS"

display as result "Expanded CVD Step 5 end-to-end test passed."

/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_stage1_combine.do
VERSION: 0.2.0 (26 August 2026)
PURPOSE: Synthetic test for expanded CVD Step 5 Stage 1 lattice construction.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 1 combine test v0.2.0"

if "$BNR_STATA" == "" {
    display as error "Load bnr_paths_LOCAL.do before running this test."
    exit 198
}

local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_stage1_combine.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile burden_input rates_input combined_private qa_output

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
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = 0
generate str80 suppression_reason = ""
save "`burden_input'", replace

clear
set obs 2
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-INCIDENCE-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int dth_year = 2099
generate byte period_month = .
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str18 age_group = cond(_n == 1, "all", "age_standardised")
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str15 unit = "rate_per_100000"
generate double value = 100
generate double numerator = cond(_n == 1, 20, .)
generate double denominator = cond(_n == 1, 20000, .)
generate double linkage_lower_value = .
generate double linkage_upper_value = .
generate byte period_complete = 1
generate str25 status_flag = "final"
save "`rates_input'", replace

do "`helper_path'" "`burden_input'" "`rates_input'" "`combined_private'" "`qa_output'" "cvd_2099_01"

use "`combined_private'", clear
assert _N == 3
quietly count if statistic == "annual_crude_rate" & age_group == "all"
assert r(N) == 1
quietly count if statistic == "annual_age_standardised_rate" & age_group == "age_standardised"
assert r(N) == 1
assert source_status == "hospital_registered" if metric_id == "CVD-INCIDENCE-001"
assert primary_suppression == 0 if metric_id == "CVD-INCIDENCE-001"

use "`qa_output'", clear
assert _N == 4
assert result == "PASS"

display as result "Expanded CVD Step 5 Stage 1 combine test passed."

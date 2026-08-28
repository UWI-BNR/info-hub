/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_end_to_end.do
VERSION: 2.1.1 (27 August 2026)
PURPOSE: End-to-end synthetic test for annual DCO count and rate disclosure.

Tests one annual/all-age Heart/Female equation:
  hospital (20) + additional DCO (3) = hospital plus DCO (23).
The DCO component is primary-suppressed.  Its count, total count, crude rate
and ASR must be suppressed, while the hospital count and representations remain
available.  This proves the count identity cannot reconstruct the small DCO.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 end-to-end test v2.1.1"

if "$BNR_STATA" == "" exit 198
local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd.do"
capture confirm file "`helper_path'"
assert _rc == 0

tempfile burden_input rates_input components_input candidate_output qa_output equation_output row_output

* Established hospital-only annual count.
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
generate str20 event_type = "heart"
generate str8 sex = "female"
generate str18 age_group = "all"
generate str30 source_status = "hospital_registered"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str45 statistic = "annual_count"
generate double value = 20
generate str18 unit = "count"
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

* Rate core output: hospital rate pair, total count/rate triplet, and DCO count.
clear
set obs 6
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str24 metric_id = "CVD-INCIDENCE-001"
replace metric_id = "CVD-BURDEN-001" in 5/6
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int dth_year = 2099
generate byte period_month = .
generate str20 event_type = "heart"
generate str8 sex = "female"
generate str18 age_group = "all"
replace age_group = "age_standardised" in 2
replace age_group = "age_standardised" in 4
generate str24 ascertainment_scope = "hospital_only"
replace ascertainment_scope = "hospital_plus_dco" in 3/5
replace ascertainment_scope = "additional_dco" in 6
generate str20 mortality_definition = "not_applicable"
replace mortality_definition = "primary" in 3/6
replace mortality_definition = "primary" in 5
generate str12 estimate_basis = "observed"
replace estimate_basis = "estimated" in 3/6
generate str18 unit = "rate_per_100000"
replace unit = "count" in 5/6
generate double value = 100
replace value = 23 in 5
replace value = 3 in 6
generate double numerator = 20
replace numerator = . in 2
replace numerator = . in 4
replace numerator = 23 in 3
replace numerator = 23 in 5
replace numerator = 3 in 6
generate double denominator = 20000
replace denominator = . in 2
replace denominator = . in 4
replace denominator = . in 5/6
generate double linkage_lower_value = .
generate double linkage_upper_value = .
replace linkage_lower_value = 90 in 3/4
replace linkage_upper_value = 110 in 3/4
replace linkage_lower_value = 23 in 5
replace linkage_upper_value = 23 in 5
replace linkage_lower_value = 3 in 6
replace linkage_upper_value = 3 in 6
generate byte period_complete = 1
generate str25 status_flag = "final"
save "`rates_input'", replace

* The private DCO support establishes the single primary decision.
clear
set obs 1
generate str20 mortality_definition = "primary"
generate int dth_year = 2099
generate str20 category = "heart"
generate str8 sex = "female"
generate str18 age_group = "age_0_4"
generate double dco_lower_component_n = 3
generate double dco_central_component_n = 3
generate double dco_upper_component_n = 3
save "`components_input'", replace

do "`helper_path'" "`burden_input'" "`rates_input'" "`components_input'" "`candidate_output'" "`qa_output'" "`equation_output'" "`row_output'" "cvd_2099_01"

use "`candidate_output'", clear
quietly count if suppression_status != "none" & (!missing(value) | !missing(numerator) | !missing(denominator) | !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0
quietly count if ascertainment_scope == "additional_dco" & suppression_status == "primary"
assert r(N) == 1
quietly count if ascertainment_scope == "hospital_plus_dco" & suppression_status == "primary"
assert r(N) == 3
quietly count if ascertainment_scope == "hospital_only" & suppression_status == "none"
assert r(N) == 3
quietly count if ascertainment_scope == "hospital_only" & missing(value)
assert r(N) == 0

use "`equation_output'", clear
assert result == "PASS"
quietly count if equation == "DCO count identity"
assert r(N) == 1

use "`row_output'", clear
assert result == "PASS"

use "`qa_output'", clear
assert _N == 32
assert result == "PASS"

display as result "Expanded CVD Step 5 end-to-end test passed."

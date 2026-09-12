/*******************************************************************************
DO-FILE:     test_bnr_cvd_stage2_disclosure.do
VERSION:     1.0.7 (24 August 2026)
PURPOSE:     Synthetic tests for Stage 2 CVD disclosure closure.

SAFETY:      Uses only generated aggregate rows, an impossible release ID and
             tempfile outputs.  It never calls Step 5 approval or Step 6.
*******************************************************************************/

version 19
clear all
set more off

if `"$BNR_STATA"' == "" | `"$BNR_PRIVATE_LOGS"' == "" {
    display as error "Load bnr_paths_LOCAL.do before running this synthetic test."
    display as error "The test also requires BNR_PRIVATE_LOGS for its persistent log."
    exit 198
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage2test
local test_log "$BNR_PRIVATE_LOGS/bnr_cvd_stage2_disclosure_test.log"
log using `"`test_log'"', text replace name(stage2test)
display as text "Stage 2 synthetic test log: `test_log'"

* ---------------------------------------------------------------------------
* Scenario 1: one protected quarter must close the quarter-month and annual
* routes.  The expected deterministic protectors include two months and Q2:
* one month for the Q1 equation, one for the annual-monthly equation, and one
* for the newly protected Q2 equation.  Three monthly protectors are therefore
* expected when all three cross-frequency equation families are enforced.
* ---------------------------------------------------------------------------
tempfile time_private time_candidate time_qa time_audit time_row_audit
clear
set obs 17

generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-BURDEN-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = ""
replace period_type = "monthly" in 1/12
replace period_type = "quarterly" in 13/16
replace period_type = "annual" in 17
generate str20 period = "synthetic"
generate str10 period_start = "2099-01-01"
generate int period_year = 2020
generate byte period_month = .
replace period_month = _n in 1/12
generate byte period_quarter = .
replace period_quarter = ceil(period_month / 3) in 1/12
replace period_quarter = _n - 12 in 13/16
replace period = "2020_m" + string(period_month, "%02.0f") in 1/12
replace period = "2020_q" + string(period_quarter, "%01.0f") in 13/16
replace period = "2020" in 17
generate byte period_complete = 1
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str12 age_group = "all"
generate str30 source_status = "hospital_registered"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str45 statistic = ""
replace statistic = "monthly_count" in 1/12
replace statistic = "quarterly_count" in 13/16
replace statistic = "annual_count" in 17
generate double value = 20
replace value = 60 in 13/16
replace value = 240 in 17
replace value = 3 in 13
generate str15 unit = "count"
generate double numerator = value
generate double denominator = .
generate double linkage_lower_value = .
generate double linkage_upper_value = .
generate int comparison_n = .
generate str25 status_flag = "final"
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = inrange(value, 1, 5)
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = primary_suppression
generate str80 suppression_reason = "synthetic"
save `"`time_private'"', replace

do "$BNR_STATA/common/bnr_step5_suppress.do" ///
    `"`time_private'"' `"`time_candidate'"' `"`time_qa'"' ///
    `"`time_audit'"' `"`time_row_audit'"' "cvd_2099_01" ///
    "synthetic_previous_public.dta" "synthetic_previous_private.dta" ///
    "cvd_2098_12"

use `"`time_candidate'"', clear
display as text "Scenario 1 suppression table:"
table (period_type statistic) (suppression_status), statistic(frequency) missing
display as text "Scenario 1 all-CVD time rows:"
list period_type period_year period_month period_quarter period statistic ///
    suppression_status if event_type == "all_cvd" & sex == "all" & ///
    age_group == "all", sepby(period_type) noobs
quietly count if period_type == "quarterly" & period_quarter == 1 & ///
    suppression_status == "primary"
assert r(N) == 1
quietly count if period_type == "quarterly" & period_quarter == 2 & ///
    suppression_status == "secondary"
assert r(N) == 1
quietly count if period_type == "monthly" & suppression_status == "secondary"
assert r(N) == 3
quietly count if suppression_status != "none" & ///
    (!missing(value) | !missing(numerator) | !missing(denominator) | ///
    !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0

local nonpublic_candidate_fields step4_primary_flag step4_related_flag ///
    previous_release_id previous_release_found previous_value ///
    temporal_increment temporal_check step5_temporal_flag ///
    step5_complementary_flag step5_derived_flag __source_row ///
    __comparator_offset __private_row_id
foreach variable of local nonpublic_candidate_fields {
    capture confirm variable `variable'
    assert _rc != 0
}

use `"`time_qa'"', clear
quietly count if check == "Cross-frequency equation closure" & result == "PASS"
assert r(N) == 1
use `"`time_audit'"', clear
assert _N >= 3
use `"`time_row_audit'"', clear
assert _N == 17
isid __private_row_id
confirm variable step5_complementary_flag

* ---------------------------------------------------------------------------
* Scenario 2: a protected annual count must withhold a later five-year mean.
* ---------------------------------------------------------------------------
tempfile comparator_private comparator_candidate comparator_qa comparator_audit ///
    comparator_row_audit
clear
set obs 3
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-BURDEN-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate str20 period = "synthetic"
generate str10 period_start = "2099-01-01"
generate int period_year = 2015
replace period_year = 2016 in 2/3
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
replace statistic = "annual_previous_5yr_mean" in 3
generate double value = 3
replace value = 100 in 2/3
generate str15 unit = "count"
generate double numerator = value
generate double denominator = .
generate double linkage_lower_value = .
generate double linkage_upper_value = .
generate int comparison_n = .
replace comparison_n = 5 in 3
generate str25 status_flag = "final"
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = inrange(value, 1, 5) & statistic == "annual_count"
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = primary_suppression
generate str80 suppression_reason = "synthetic"
save `"`comparator_private'"', replace

do "$BNR_STATA/common/bnr_step5_suppress.do" ///
    `"`comparator_private'"' `"`comparator_candidate'"' `"`comparator_qa'"' ///
    `"`comparator_audit'"' `"`comparator_row_audit'"' "cvd_2099_01" ///
    "synthetic_previous_public.dta" "synthetic_previous_private.dta" ///
    "cvd_2098_12"

use `"`comparator_candidate'"', clear
quietly count if statistic == "annual_previous_5yr_mean" & ///
    period_year == 2016 & suppression_status == "derived"
assert r(N) == 1
use `"`comparator_qa'"', clear
quietly count if result != "PASS"
assert r(N) == 0

* ---------------------------------------------------------------------------
* Scenario 3: historic public/private AMI rows are the direct predecessor of
* Stage 2 Heart rows for temporal comparison.  A 10-event increment is public
* under the n<6 temporal rule; without the label bridge it would be treated as
* a missing predecessor and withheld conservatively.
* ---------------------------------------------------------------------------
tempfile bridge_private bridge_candidate bridge_qa bridge_audit ///
    bridge_row_audit bridge_previous_public bridge_previous_private

clear
set obs 1
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-BURDEN-001"
generate str12 release_id = "cvd_2099_04"
generate str12 period_type = "annual"
generate str20 period = "2099"
generate str10 period_start = "2099-01-01"
generate int period_year = 2099
generate byte period_month = .
generate byte period_quarter = .
generate byte period_complete = 0
generate str20 event_type = "heart"
generate str8 sex = "female"
generate str12 age_group = "all"
generate str30 source_status = "hospital_registered"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str45 statistic = "annual_count"
generate double value = 110
generate str15 unit = "count"
generate double numerator = value
generate double denominator = .
generate double linkage_lower_value = .
generate double linkage_upper_value = .
generate int comparison_n = .
generate str25 status_flag = "incomplete"
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = 0
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = 0
generate str80 suppression_reason = "synthetic"
save `"`bridge_private'"', replace

keep metric_id period_type period_year period_quarter event_type sex age_group statistic
replace event_type = "ami"
generate str12 suppression_status = "none"
save `"`bridge_previous_public'"', replace

drop suppression_status
generate double value = 100
save `"`bridge_previous_private'"', replace

do "$BNR_STATA/common/bnr_step5_suppress.do" ///
    `"`bridge_private'"' `"`bridge_candidate'"' `"`bridge_qa'"' ///
    `"`bridge_audit'"' `"`bridge_row_audit'"' "cvd_2099_04" ///
    `"`bridge_previous_public'"' `"`bridge_previous_private'"' ///
    "cvd_2099_03"

use `"`bridge_candidate'"', clear
quietly count if suppression_status == "none"
assert r(N) == 1
use `"`bridge_row_audit'"', clear
assert temporal_check == "previous_public_value"
assert temporal_increment == 10

noisily display as result "PASS: CVD Stage 2 synthetic disclosure tests completed."
log close stage2test

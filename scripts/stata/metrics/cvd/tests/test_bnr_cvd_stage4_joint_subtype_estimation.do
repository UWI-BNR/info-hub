/*******************************************************************************
DO-FILE:     test_bnr_cvd_stage4_joint_subtype_estimation.do
VERSION:     1.0.6 (25 August 2026)
PURPOSE:     Synthetic tests for the joint Heart/Stroke/mixed DCO estimator.
*******************************************************************************/
version 19
clear all
set more off
tempfile all_input concordance_input results_output qa_output
tempname ah ch
postfile `ah' str10 mortality_definition int dth_year ///
    double dco_lower_component_n dco_central_component_n dco_upper_component_n ///
    using `"`all_input'"', replace
post `ah' ("primary") (2020) (4) (7) (10)
post `ah' ("primary") (2021) (10) (13) (15)
postclose `ah'
postfile `ch' str10 mortality_definition int dth_year ///
    str32 final_episode_outcome str40 attribution_route long candidate_n ///
    using `"`concordance_input'"', replace
* 2020: resolved A composition Heart=2, Stroke=1, Mixed=1; U=6.
post `ch' ("primary") (2020) ("recorded_event_0_27_days") ///
    ("heart_recorded_concordant") (8)
post `ch' ("primary") (2020) ("provisional_additional_dco") ///
    ("heart_dco_eligible") (2)
post `ch' ("primary") (2020) ("recorded_event_0_27_days") ///
    ("stroke_recorded_concordant") (9)
post `ch' ("primary") (2020) ("provisional_additional_dco") ///
    ("stroke_dco_eligible") (1)
post `ch' ("primary") (2020) ("provisional_additional_dco") ///
    ("mixed_dco_all_cvd_only") (1)
post `ch' ("primary") (2020) ("pending_no_deterministic_match") ///
    ("pending_identity") (6)
* 2021 has enough resolved evidence and a different composition.
post `ch' ("primary") (2021) ("recorded_event_0_27_days") ///
    ("heart_recorded_concordant") (10)
post `ch' ("primary") (2021) ("provisional_additional_dco") ///
    ("heart_dco_eligible") (4)
post `ch' ("primary") (2021) ("recorded_event_0_27_days") ///
    ("stroke_recorded_concordant") (10)
post `ch' ("primary") (2021) ("provisional_additional_dco") ///
    ("stroke_dco_eligible") (3)
post `ch' ("primary") (2021) ("provisional_additional_dco") ///
    ("mixed_dco_all_cvd_only") (3)
post `ch' ("primary") (2021) ("pending_no_deterministic_match") ///
    ("pending_identity") (5)
postclose `ch'
do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_joint_subtype_core.do" ///
    `"`all_input'"' `"`concordance_input'"' `"`results_output'"' `"`qa_output'"'
use `"`results_output'"', clear
assert _N == 6
quietly summarize joint_central_component_n if dth_year == 2020, meanonly
assert abs(r(sum) - 7) < 0.000001
quietly summarize joint_central_component_n if dth_year == 2021, meanonly
assert abs(r(sum) - 13) < 0.000001
quietly summarize joint_lower_component_n if dth_year == 2020, meanonly
assert abs(r(sum) - 4) < 0.000001
quietly summarize joint_lower_component_n if dth_year == 2021, meanonly
assert abs(r(sum) - 10) < 0.000001
assert allocation_probability >= 0 & allocation_probability <= 1
import delimited using `"`qa_output'"', varnames(1) clear
quietly count if value != 0
assert r(N) == 0
noisily display as result "PASS: Stage 4E-c joint subtype-estimation synthetic tests completed."

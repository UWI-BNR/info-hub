/*******************************************************************************

DO-FILE:     test_bnr_cvd_stage4_unresolved_estimation.do

VERSION:     1.0.1 (25 August 2026)

PURPOSE:     Synthetic tests for Stage 4D aggregate unresolved-linkage
              estimation and its annual / three-year / all-years hierarchy.

SAFETY:      Generates only synthetic aggregate linkage candidates and uses
             tempfile outputs. It does not read BNR data, call Step 5/6 or
             create public output.

*******************************************************************************/

version 19

clear all

set more off

if `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        display as error "The BNR local path configuration could not be loaded."
        exit _rc
    }
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4dtest
log using "$BNR_PRIVATE_LOGS/bnr_cvd_stage4_unresolved_estimation_test.log", text replace name(stage4dtest)

tempfile linkage_input results_output qa_output low_input low_results low_qa

clear
set obs 48
generate str5 record_id = "D" + string(_n, "%04.0f")
generate int dth_year = 2020
replace dth_year = 2021 in 26/39
replace dth_year = 2022 in 40/48
generate double dth_date = mdy(6, 30, dth_year)
format dth_date %td
generate byte cvd_prim = 1
generate byte cvd_incl = 1
generate byte final_person_match = 0
generate str36 final_episode_outcome = "pending_no_deterministic_match"

replace final_person_match = 1 in 1/20
replace final_episode_outcome = "recorded_event_0_27_days" in 1/10
replace final_episode_outcome = "provisional_additional_dco" in 11/20

replace final_person_match = 1 in 26/35
replace final_episode_outcome = "recorded_event_0_27_days" in 26/33
replace final_episode_outcome = "provisional_additional_dco" in 34/35

replace final_person_match = 1 in 40/44
replace final_episode_outcome = "recorded_event_0_27_days" in 40/41
replace final_episode_outcome = "provisional_additional_dco" in 42/44

save `"`linkage_input'"', replace

do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_unresolved_core.do" `"`linkage_input'"' `"`results_output'"' `"`qa_output'"'

use `"`results_output'"', clear

assert _N == 6
assert estimation_level == "annual" if mortality_definition == "primary" & dth_year == 2020
assert selected_resolved_n == 20 if mortality_definition == "primary" & dth_year == 2020
assert abs(selected_additional_fraction - 0.5) < 0.000001 if ///
    mortality_definition == "primary" & dth_year == 2020
assert abs(estimated_unresolved_dco_n - 2.5) < 0.000001 if ///
    mortality_definition == "primary" & dth_year == 2020

assert estimation_level == "three_year" if mortality_definition == "primary" & dth_year == 2021
assert selected_resolved_n == 35 if mortality_definition == "primary" & dth_year == 2021
assert selected_additional_dco_n == 15 if mortality_definition == "primary" & dth_year == 2021
assert abs(selected_additional_fraction - (15 / 35)) < 0.000001 if ///
    mortality_definition == "primary" & dth_year == 2021

assert estimation_level == "all_years" if mortality_definition == "primary" & dth_year == 2022
assert selected_resolved_n == 35 if mortality_definition == "primary" & dth_year == 2022
assert selected_additional_dco_n == 15 if mortality_definition == "primary" & dth_year == 2022
assert abs(selected_additional_fraction - (15 / 35)) < 0.000001 if ///
    mortality_definition == "primary" & dth_year == 2022

assert dco_lower_component_n <= dco_central_component_n
assert dco_central_component_n <= dco_upper_component_n

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if check == "Annual cells using annual" & value == 2
assert r(N) == 1
quietly count if check == "Annual cells using three_year" & value == 2
assert r(N) == 1
quietly count if check == "Annual cells using all_years" & value == 2
assert r(N) == 1
quietly count if check == "Primary/Inclusive central-component invariant failures" & value == 0
assert r(N) == 1

* The hierarchy must leave a genuinely under-resolved series unestimated rather
* than silently borrowing a fraction below the approved minimum denominator.
clear
set obs 5
generate str5 record_id = "U" + string(_n, "%04.0f")
generate int dth_year = 2023
generate double dth_date = mdy(6, 30, dth_year)
format dth_date %td
generate byte cvd_prim = 1
generate byte cvd_incl = 1
generate byte final_person_match = 0
generate str36 final_episode_outcome = "pending_no_deterministic_match"
save `"`low_input'"', replace

do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_unresolved_core.do" `"`low_input'"' `"`low_results'"' `"`low_qa'"'

use `"`low_results'"', clear
assert _N == 2
assert estimation_level == "insufficient_resolved"
assert missing(estimated_unresolved_dco_n) & missing(dco_central_component_n)
assert dco_lower_component_n == 0
assert dco_upper_component_n == 5

noisily display as result "PASS: Stage 4D aggregate unresolved-estimation synthetic tests completed."

log close stage4dtest

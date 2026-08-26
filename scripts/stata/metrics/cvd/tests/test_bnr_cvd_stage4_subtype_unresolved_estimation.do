/*******************************************************************************

DO-FILE:     test_bnr_cvd_stage4_subtype_unresolved_estimation.do

VERSION:     1.0.2 (25 August 2026)

PURPOSE:     Synthetic tests for Stage 4E-b Heart/Stroke aggregate unresolved-
             linkage estimation and its annual / three-year / all-years
             fallback hierarchy.

SAFETY:      Uses only fabricated aggregate concordance cells and tempfile
             outputs. It does not read BNR data, relink people, calculate
             public metrics, call Steps 5/6 or create public output.

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
capture log close stage4e2test
log using "$BNR_PRIVATE_LOGS/bnr_cvd_stage4_subtype_unresolved_estimation_test.log", text replace name(stage4e2test)

tempfile concordance_input results_output qa_output low_input low_results low_qa
tempname cells_handle low_cells_handle

* Build aggregate rows corresponding to the Stage 4E-a concordance profile.
* Each of the four definition/subtype series has 20, 10 and 5 resolved
* candidates in 2020, 2021 and 2022 respectively. Thus 2020 uses annual,
* 2021 uses the three-year pool, and 2022 uses the all-years fallback.
postfile `cells_handle' str10 mortality_definition int dth_year ///
    str24 certificate_family str24 episode_family ///
    str36 final_episode_outcome str40 attribution_route ///
    long candidate_n using `"`concordance_input'"', replace

foreach definition in primary inclusive {
    foreach subtype in heart stroke {
        if "`subtype'" == "heart" {
            local certificate_family "heart_only"
            local concordant_route "heart_recorded_concordant"
            local additional_route "heart_dco_eligible"
        }
        else {
            local certificate_family "stroke_only"
            local concordant_route "stroke_recorded_concordant"
            local additional_route "stroke_dco_eligible"
        }

        forvalues test_year = 2020/2022 {
            local recorded_n 10
            local additional_n 10
            local unresolved_n 5

            if `test_year' == 2021 {
                local recorded_n 8
                local additional_n 2
                local unresolved_n 3
            }
            if `test_year' == 2022 {
                local recorded_n 2
                local additional_n 3
                local unresolved_n 4
            }

            * Definitions are alternative estimands. This valid synthetic
            * example deliberately gives Inclusive Heart 2020 a lower central
            * estimate than Primary Heart 2020, while retaining ordered lower
            * and upper components. It must not fail a false central-ordering
            * assertion.
            if "`definition'" == "inclusive" & "`subtype'" == "heart" & ///
                    `test_year' == 2020 {
                local recorded_n 40
                local additional_n 10
                local unresolved_n 5
            }

            post `cells_handle' ("`definition'") (`test_year') ///
                ("`certificate_family'") ("`subtype'_only") ///
                ("recorded_event_0_27_days") ("`concordant_route'") ///
                (`recorded_n')
            post `cells_handle' ("`definition'") (`test_year') ///
                ("`certificate_family'") ("no_window_event") ///
                ("provisional_additional_dco") ("`additional_route'") ///
                (`additional_n')
            post `cells_handle' ("`definition'") (`test_year') ///
                ("`certificate_family'") ("pending_identity") ///
                ("pending_no_deterministic_match") ("pending_identity") ///
                (`unresolved_n')
        }
    }
}

* These two rows must remain visible as exclusions and must not change the
* Heart calibration fraction or the Stroke deterministic-DCO component.
post `cells_handle' ("primary") (2020) ("heart_only") ("stroke_only") ///
    ("recorded_event_0_27_days") ("linked_subtype_discordant") (2)
post `cells_handle' ("inclusive") (2020) ("stroke_only") ///
    ("unclassified_matched") ("recorded_event_0_27_days") ///
    ("matched_episode_unclassified") (1)

postclose `cells_handle'

do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_subtype_unresolved_core.do" `"`concordance_input'"' `"`results_output'"' `"`qa_output'"'

use `"`results_output'"', clear

assert _N == 12
assert estimation_level == "annual" if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2020
assert selected_resolved_n == 20 if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2020
assert abs(selected_additional_fraction - 0.5) < 0.000001 if ///
    mortality_definition == "primary" & event_type == "heart" & dth_year == 2020
assert abs(estimated_unresolved_dco_n - 2.5) < 0.000001 if ///
    mortality_definition == "primary" & event_type == "heart" & dth_year == 2020
assert linked_subtype_discordant_n == 2 if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2020

assert estimation_level == "three_year" if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2021
assert selected_resolved_n == 35 if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2021
assert selected_additional_dco_n == 15 if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2021
assert abs(selected_additional_fraction - (15 / 35)) < 0.000001 if ///
    mortality_definition == "primary" & event_type == "heart" & dth_year == 2021

assert estimation_level == "all_years" if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2022
assert selected_resolved_n == 35 if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2022
assert selected_additional_dco_n == 15 if mortality_definition == "primary" & ///
    event_type == "heart" & dth_year == 2022
assert abs(selected_additional_fraction - (15 / 35)) < 0.000001 if ///
    mortality_definition == "primary" & event_type == "heart" & dth_year == 2022

assert matched_episode_unclassified_n == 1 if ///
    mortality_definition == "inclusive" & event_type == "stroke" & dth_year == 2020
assert dco_lower_component_n <= dco_central_component_n
assert dco_central_component_n <= dco_upper_component_n

preserve
    keep if event_type == "heart" & dth_year == 2020
    keep mortality_definition event_type dth_year ///
        dco_lower_component_n dco_central_component_n dco_upper_component_n
    rename dco_lower_component_n low
    rename dco_central_component_n central
    rename dco_upper_component_n upper
    reshape wide low central upper, i(event_type dth_year) ///
        j(mortality_definition) string
    assert centralinclusive < centralprimary
    assert lowinclusive >= lowprimary
    assert upperinclusive >= upperprimary
restore

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if check == "primary heart: cells using annual" & value == 1
assert r(N) == 1
quietly count if check == "primary heart: cells using three_year" & value == 1
assert r(N) == 1
quietly count if check == "primary heart: cells using all_years" & value == 1
assert r(N) == 1
quietly count if check == "Primary/Inclusive subtype lower-component invariant failures" & value == 0
assert r(N) == 1
quietly count if check == "Primary/Inclusive subtype upper-component invariant failures" & value == 0
assert r(N) == 1

* A genuinely under-resolved subtype must remain without a central estimate;
* it must not borrow a fraction below the approved resolved-count threshold.
postfile `low_cells_handle' str10 mortality_definition int dth_year ///
    str24 certificate_family str24 episode_family ///
    str36 final_episode_outcome str40 attribution_route ///
    long candidate_n using `"`low_input'"', replace
foreach definition in primary inclusive {
    post `low_cells_handle' ("`definition'") (2023) ("heart_only") ///
        ("pending_identity") ("pending_no_deterministic_match") ///
        ("pending_identity") (5)
}
postclose `low_cells_handle'

do "$BNR_STATA/metrics/cvd/bnr_cvd_estimate_subtype_unresolved_core.do" `"`low_input'"' `"`low_results'"' `"`low_qa'"'

use `"`low_results'"', clear
assert _N == 2
assert estimation_level == "insufficient_resolved"
assert missing(estimated_unresolved_dco_n) & missing(dco_central_component_n)
assert dco_lower_component_n == 0
assert dco_upper_component_n == 5

noisily display as result "PASS: Stage 4E-b subtype unresolved-estimation synthetic tests completed."

log close stage4e2test

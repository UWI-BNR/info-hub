/*******************************************************************************

DO-FILE:     test_bnr_cvd_stage4_subtype_concordance.do

VERSION:     1.0.1 (25 August 2026)

PURPOSE:     Synthetic tests for the Stage 4E-a Heart/Stroke family-
             concordance profile.

SAFETY:      Uses only fabricated mortality/linkage rows and tempfile outputs.
             It does not read BNR data, estimate DCOs, call Steps 5/6 or
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
capture log close stage4e1test
log using "$BNR_PRIVATE_LOGS/bnr_cvd_stage4_subtype_concordance_test.log", text replace name(stage4e1test)

tempfile linkage_input cells_output qa_output resolution_output

clear
set obs 6
generate str5 record_id = "D" + string(_n, "%04.0f")
generate int dth_year = 2020
replace dth_year = 2021 in 6
generate byte cvd_prim = 1
replace cvd_prim = 0 in 6
generate byte cvd_incl = 1
generate byte hrt_prim = 1
replace hrt_prim = 0 in 2
replace hrt_prim = 0 in 5/6
generate byte str_prim = 0
replace str_prim = 1 in 2/3
replace str_prim = 1 in 5
generate byte hrt_incl = hrt_prim
replace hrt_incl = 1 in 6
generate byte str_incl = str_prim
generate byte cvd_sub_p = 1
replace cvd_sub_p = 2 in 2
replace cvd_sub_p = 3 in 3
replace cvd_sub_p = 2 in 5
replace cvd_sub_p = . in 6
generate byte cvd_sub_i = cvd_sub_p
replace cvd_sub_i = 1 in 6
label define cvdsub 1 "Heart" 2 "Stroke" 3 "Mixed"
label values cvd_sub_p cvdsub
label values cvd_sub_i cvdsub
generate byte final_person_match = 1
replace final_person_match = 0 in 5
generate str36 final_episode_outcome = "provisional_additional_dco"
replace final_episode_outcome = "recorded_event_0_27_days" in 1
replace final_episode_outcome = "recorded_event_0_27_days" in 4
replace final_episode_outcome = "pending_no_deterministic_match" in 5
generate long episode_heart_count_0_27 = 0
replace episode_heart_count_0_27 = 1 in 1
generate long episode_stroke_count_0_27 = 0
replace episode_stroke_count_0_27 = 1 in 4

save `"`linkage_input'"', replace

do "$BNR_STATA/metrics/cvd/bnr_cvd_profile_subtype_concordance_core.do" `"`linkage_input'"' `"`cells_output'"' `"`qa_output'"' `"`resolution_output'"'

use `"`cells_output'"', clear
quietly summarize candidate_n if mortality_definition == "primary", meanonly
assert r(sum) == 5
quietly summarize candidate_n if mortality_definition == "inclusive", meanonly
assert r(sum) == 6
quietly summarize candidate_n if mortality_definition == "primary" & attribution_route == "stroke_dco_eligible", meanonly
assert r(sum) == 1
quietly summarize candidate_n if mortality_definition == "primary" & attribution_route == "mixed_dco_all_cvd_only", meanonly
assert r(sum) == 1
quietly summarize candidate_n if mortality_definition == "primary" & attribution_route == "linked_subtype_discordant", meanonly
assert r(sum) == 1
quietly summarize candidate_n if mortality_definition == "inclusive" & attribution_route == "heart_dco_eligible", meanonly
assert r(sum) == 1

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if check == "primary: certificate both" & value == 1
assert r(N) == 1
quietly count if check == "inclusive: linked_subtype_discordant" & value == 1
assert r(N) == 1

import delimited using `"`resolution_output'"', varnames(1) clear
quietly summarize candidate_n if mortality_definition == "primary" & subtype_source_label == "Heart", meanonly
assert r(sum) == 2
quietly summarize candidate_n if mortality_definition == "inclusive" & subtype_source_label == "Heart", meanonly
assert r(sum) == 3

noisily display as result "PASS: Stage 4E-a subtype concordance synthetic tests completed."

log close stage4e1test

/*******************************************************************************

DO-FILE:     test_bnr_cvd_stage4_l01_episode.do

VERSION:     1.0.6 (25 August 2026)

PURPOSE:     Synthetic tests for Stage 4B exact-NRN person and episode linkage.

SAFETY:      Generates only impossible identifiers and uses tempfile outputs.
             It does not read BNR data, create DCO metrics, call Step 5/6 or
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
capture log close stage4btest
log using "$BNR_PRIVATE_LOGS/bnr_cvd_stage4_l01_episode_test.log", text replace name(stage4btest)

tempfile deaths_input events_input results_output qa_output

clear
input str5 record_id double dth_date str11 nrn str2 mortality_sex
"D0001" 21955 "600101-0001" "1"
"D0002" 21965 "550101-0002" "1"
"D0003" 21975 "700101-0003" "1"
"D0004" 21985 "700101-0004" "1"
"D0005" 21995 "700231-0005" "1"
"D0006" 22005 "650101-0006" "1"
end
format dth_date %td
save `"`deaths_input'"', replace

clear
input str5 eid double doe byte etype double dob byte cvd_sex str11 natregno
"E0001" 21946 2 . 2 "600101-0001"
"E0002" 21884 1 . 2 "550101-0002"
"E0003" 21970 1 . 1 "700101-0003"
"E0004" 21978 1 . 1 "700101-0004"
"E0005" 21979 2 . 2 "700101-0004"
"E0006" 21980 1 . 2 "700231-0005"
"E0007" 21900 2 . 2 "650101-0007"
end
format doe dob %td
save `"`events_input'"', replace

do "$BNR_STATA/metrics/cvd/bnr_cvd_l01_episode_core.do" `"`deaths_input'"' `"`events_input'"' `"`results_output'"' `"`qa_output'"'

use `"`results_output'"', clear

assert _N == 6
assert l01_person_match == 1 if record_id == "D0001"
assert l01_episode_outcome == "recorded_event_0_27_days" if record_id == "D0001"
assert episode_event_count_0_27 == 1 if record_id == "D0001"
assert episode_heart_count_0_27 == 1 if record_id == "D0001"

assert l01_person_match == 1 if record_id == "D0002"
assert l01_episode_outcome == "provisional_additional_dco" if record_id == "D0002"
assert remote_prior_event == 1 if record_id == "D0002"
assert nearest_prior_event_days > 27 if record_id == "D0002"

assert l01_person_match == 0 if record_id == "D0003"
assert linkage_status == "pending_sex_contradiction" if record_id == "D0003"

assert l01_person_match == 0 if record_id == "D0004"
assert linkage_status == "pending_cvd_sex_conflict" if record_id == "D0004"

assert l01_person_match == 0 if record_id == "D0005"
assert linkage_status == "pending_invalid_mortality_nrn" if record_id == "D0005"

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if check == "L01 exact-NRN person matches" & count == 2
assert r(N) == 1
quietly count if check == "L01 recorded event episodes" & count == 1
assert r(N) == 1
quietly count if check == "L01 provisional additional DCOs" & count == 1
assert r(N) == 1
quietly count if check == "Pending: no valid CVD NRN counterpart" & count == 1
assert r(N) == 1

noisily display as result "PASS: Stage 4B L01 and episode synthetic tests completed."

log close stage4btest

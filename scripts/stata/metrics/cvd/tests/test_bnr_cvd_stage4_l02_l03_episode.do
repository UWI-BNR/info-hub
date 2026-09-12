/*******************************************************************************

DO-FILE:     test_bnr_cvd_stage4_l02_l03_episode.do

VERSION:     1.0.4 (25 August 2026)

PURPOSE:     Synthetic tests for Stage 4C deterministic L02/L03 person and
              episode linkage.

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
capture log close stage4ctest
log using "$BNR_PRIVATE_LOGS/bnr_cvd_stage4_l02_l03_episode_test.log", text replace name(stage4ctest)

tempfile l01_input events_input results_output qa_output

clear
input str5 record_id double dth_date str30 pname str11 nrn str2 mortality_sex str3 mortality_age str2 mortality_agetxt byte l01_person_match str3 linkage_rule_id str48 linkage_status
"D0001" 21955 "L01 PERSON" "600101-0001" "1" "60" "6" 1 "L01" "L01_exact_nrn"
"D0002" 21955 "ALICE B JONES" "700101-0002" "1" "50" "6" 0 "" "pending_no_valid_cvd_nrn"
"D0003" 21975 "CLARA SMITH" "650101-0003" "2" "55" "6" 0 "" "pending_no_valid_cvd_nrn"
"D0004" 21985 "DAVID BROWN" "" "1" "60" "6" 0 "" "pending_invalid_mortality_nrn"
"D0005" 22000 "ERIN WHITE" "" "2" "50" "6" 0 "" "pending_invalid_mortality_nrn"
"D0006" 22010 "FRANK BLACK" "720101-0006" "1" "48" "6" 0 "" "pending_sex_contradiction"
end
format dth_date %td
generate str32 nrn_clean = subinstr(strtrim(nrn), "-", "", .)
save `"`l01_input'"', replace

clear
input str5 eid double doe byte etype double dob byte cvd_sex str11 natregno int agey str12 fname str12 mname str12 lname
"E0001" 21950 2 . 2 "600101-0001" 60 "L01" "" "PERSON"
"E0002" 21946 1 3653 2 "" 50 "ALICE" "B" "JONES"
"E0003" 21915 1 1827 1 "" 55 "SMITH" "" "CLARA"
"E0004" 21685 2 . 2 "" 59 "BROWN" "" "DAVID"
"E0005" 21800 1 . 1 "" 50 "WHITE" "" "ERIN"
"E0006" 21700 2 . 1 "" 50 "WHITE" "" "ERIN"
"E0007" 22000 1 . 1 "720101-0006" 48 "FRANK" "" "BLACK"
end
format doe dob %td
save `"`events_input'"', replace

do "$BNR_STATA/metrics/cvd/bnr_cvd_l02_l03_episode_core.do" `"`l01_input'"' `"`events_input'"' `"`results_output'"' `"`qa_output'"'

use `"`results_output'"', clear

assert _N == 6
assert final_person_match == 1 if record_id == "D0001"
assert final_linkage_rule_id == "L01" if record_id == "D0001"
assert final_episode_outcome == "recorded_event_0_27_days" if record_id == "D0001"

assert final_person_match == 1 if record_id == "D0002"
assert final_linkage_rule_id == "L02" if record_id == "D0002"
assert final_episode_outcome == "recorded_event_0_27_days" if record_id == "D0002"

assert final_person_match == 1 if record_id == "D0003"
assert final_linkage_rule_id == "L03" if record_id == "D0003"
assert l03_match_basis == "exact_dob" if record_id == "D0003"
assert final_episode_outcome == "provisional_additional_dco" if record_id == "D0003"
assert remote_prior_event == 1 if record_id == "D0003"

assert final_person_match == 1 if record_id == "D0004"
assert final_linkage_rule_id == "L03" if record_id == "D0004"
assert l03_match_basis == "age_fallback" if record_id == "D0004"
assert final_episode_outcome == "provisional_additional_dco" if record_id == "D0004"

assert final_person_match == 0 if record_id == "D0005"
assert final_linkage_status == "pending_l02_l03_no_unique_candidate" if record_id == "D0005"
assert l03_candidate_n == 2 if record_id == "D0005"

assert final_person_match == 0 if record_id == "D0006"
assert final_linkage_status == "pending_sex_contradiction" if record_id == "D0006"

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if check == "L02 unique person matches" & count == 1
assert r(N) == 1
quietly count if check == "L02 ambiguous candidate sets" & count == 0
assert r(N) == 1
quietly count if check == "L03 unique person matches" & count == 2
assert r(N) == 1
quietly count if check == "L03 ambiguous candidate sets" & count == 1
assert r(N) == 1
quietly count if check == "L03 exact-DOB unique matches" & count == 1
assert r(N) == 1
quietly count if check == "L03 age-fallback unique matches" & count == 1
assert r(N) == 1
quietly count if check == "Final deterministic person matches" & count == 4
assert r(N) == 1
quietly count if check == "Final pending or unresolved candidates" & count == 2
assert r(N) == 1

noisily display as result "PASS: Stage 4C L02/L03 and episode synthetic tests completed."

log close stage4ctest

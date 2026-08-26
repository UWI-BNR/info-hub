/*******************************************************************************

DO-FILE:     bnr_cvd_l02_l03_episode_core.do

VERSION:     1.0.4 (25 August 2026)

PURPOSE:     Stage 4C private deterministic L02/L03 and episode-linkage core.

              This controlled pass preserves the Stage 4B L01 diagnostic and
              applies only the remaining approved deterministic identity rules:

              L02: exact normalized full name, canonical sex and exact
                   explicit/NRN-derived date of birth, with one candidate.
              L03: exact first/surname boundary tokens in either order,
                   canonical sex and exact DOB or a years-only age fallback,
                   with one candidate.

              Every final person match is then assessed against the same
              0--27-day Heart/Stroke episode rule used in Stage 4B.

              It does not estimate unresolved deaths, create final DCO metric
              rows, call Step 5/6, or create public output.

INPUTS:       Private Stage 4B diagnostic and Stage 3 hospital-event input.

OUTPUTS:      Private candidate-level L01--L03 diagnostic DTA and aggregate
              QA CSV. The DTA contains confidential linkage provenance and
              must never leave the private analysis environment.

*******************************************************************************/

version 19

clear

set more off

args l01_input events_input results_output qa_output

if `"`l01_input'"' == "" | `"`events_input'"' == "" | ///
        `"`results_output'"' == "" | `"`qa_output'"' == "" {
    display as error "L02/L03 episode core received an incomplete file contract."
    exit 198
}

foreach required_file in l01_input events_input {
    capture confirm file ``required_file''
    if _rc {
        display as error "Required private linkage input was not found: ``required_file''"
        exit 601
    }
}

tempfile deaths_base events_prepared l02_candidates l03_candidates ///
    l02_summary l03_summary matched_deaths episode_summary qa_dta

* ---------------------------------------------------------------------------
* 1. Prepare a private person proxy for hospital events. Names are normalized
*    only for deterministic comparison: punctuation becomes a token boundary;
*    there is no fuzzy matching. A valid NRN is handled as text throughout.
* ---------------------------------------------------------------------------
use `"`events_input'"', clear

isid eid

foreach required_variable in eid doe etype dob cvd_sex natregno agey ///
        fname mname lname {
    capture confirm variable `required_variable'
    if _rc {
        display as error "CVD linkage input is missing required variable: `required_variable'"
        exit 111
    }
}

capture confirm string variable natregno
if _rc {
    display as error "CVD NRN must be stored as source text."
    exit 109
}

generate str32 nrn_clean = subinstr(strtrim(natregno), "-", "", .)
replace nrn_clean = subinstr(nrn_clean, " ", "", .)
generate byte __cvd_nrn_format_valid = strlen(nrn_clean) == 10 & ///
    regexm(nrn_clean, "^[0-9]+$")
generate int __cvd_nrn_year = real(substr(nrn_clean, 1, 2))
generate int __cvd_nrn_month = real(substr(nrn_clean, 3, 2))
generate int __cvd_nrn_day = real(substr(nrn_clean, 5, 2))
generate double __cvd_nrn_date_2000 = ///
    mdy(__cvd_nrn_month, __cvd_nrn_day, 2000 + __cvd_nrn_year)
generate double __cvd_nrn_date_1900 = ///
    mdy(__cvd_nrn_month, __cvd_nrn_day, 1900 + __cvd_nrn_year)
generate byte __cvd_nrn_date_valid = __cvd_nrn_format_valid == 1 & ///
    !missing(__cvd_nrn_date_2000) & ///
    month(__cvd_nrn_date_2000) == __cvd_nrn_month & ///
    day(__cvd_nrn_date_2000) == __cvd_nrn_day
generate byte __cvd_nrn_valid = __cvd_nrn_format_valid == 1 & ///
    __cvd_nrn_date_valid == 1

generate byte cvd_sex_canonical = .
replace cvd_sex_canonical = 1 if cvd_sex == 1
replace cvd_sex_canonical = 2 if cvd_sex == 2

generate byte __cvd_has_female = __cvd_nrn_valid == 1 & ///
    cvd_sex_canonical == 1
generate byte __cvd_has_male = __cvd_nrn_valid == 1 & ///
    cvd_sex_canonical == 2
bysort nrn_clean: egen byte __cvd_group_has_female = max(__cvd_has_female)
bysort nrn_clean: egen byte __cvd_group_has_male = max(__cvd_has_male)
generate byte __cvd_sex_conflict = __cvd_nrn_valid == 1 & ///
    __cvd_group_has_female == 1 & __cvd_group_has_male == 1

generate double __cvd_explicit_dob = dob if __cvd_nrn_valid == 1 & ///
    !missing(dob)
bysort nrn_clean: egen double __cvd_explicit_dob_min = min(__cvd_explicit_dob)
bysort nrn_clean: egen double __cvd_explicit_dob_max = max(__cvd_explicit_dob)
generate byte __cvd_dob_conflict = __cvd_nrn_valid == 1 & ///
    !missing(__cvd_explicit_dob_min, __cvd_explicit_dob_max) & ///
    __cvd_explicit_dob_min != __cvd_explicit_dob_max

generate byte __cvd_age_2000_compatible = __cvd_nrn_valid == 1 & ///
    !missing(agey, doe, __cvd_nrn_date_2000) & ///
    abs(agey - floor((doe - __cvd_nrn_date_2000) / 365.25)) <= 1
generate byte __cvd_age_1900_compatible = __cvd_nrn_valid == 1 & ///
    !missing(agey, doe, __cvd_nrn_date_1900) & ///
    abs(agey - floor((doe - __cvd_nrn_date_1900) / 365.25)) <= 1
generate double cvd_dob_nrn = .
replace cvd_dob_nrn = __cvd_nrn_date_2000 if ///
    __cvd_age_2000_compatible == 1 & __cvd_age_1900_compatible == 0
replace cvd_dob_nrn = __cvd_nrn_date_1900 if ///
    __cvd_age_1900_compatible == 1 & __cvd_age_2000_compatible == 0
generate double cvd_dob_resolved = dob
replace cvd_dob_resolved = cvd_dob_nrn if missing(cvd_dob_resolved)
format cvd_dob_resolved %td

generate str244 cvd_full_name_norm = upper(strtrim(fname + " " + mname + " " + lname))
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, ".", " ", .)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, ",", " ", .)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, "-", " ", .)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, "/", " ", .)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, "(", " ", .)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, ")", " ", .)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm, char(39), " ", .)
replace cvd_full_name_norm = strtrim(itrim(cvd_full_name_norm))
generate str80 cvd_name_first = word(cvd_full_name_norm, 1)
generate str80 cvd_name_last = word(cvd_full_name_norm, wordcount(cvd_full_name_norm))

* A valid NRN group with contradictory non-missing sex or explicit DOB is not
* silently rescued by a name match. Events with no valid NRN remain eligible.
generate byte cvd_identity_conflict = __cvd_nrn_valid == 1 & ///
    (__cvd_sex_conflict == 1 | __cvd_dob_conflict == 1)
generate str244 event_person_key = "E:" + eid
replace event_person_key = "N:" + nrn_clean if __cvd_nrn_valid == 1 & ///
    cvd_identity_conflict == 0
replace event_person_key = "F:" + cvd_full_name_norm + "|" + ///
    string(cvd_sex_canonical, "%01.0f") + "|" + ///
    string(cvd_dob_resolved, "%12.0f") if __cvd_nrn_valid == 0 & ///
    cvd_full_name_norm != "" & !missing(cvd_sex_canonical, cvd_dob_resolved)

keep eid doe etype agey cvd_sex_canonical cvd_dob_resolved ///
    cvd_full_name_norm cvd_name_first cvd_name_last event_person_key ///
    cvd_identity_conflict
generate str10 episode_event_family = ""
replace episode_event_family = "stroke" if etype == 1
replace episode_event_family = "heart" if etype == 2
save `"`events_prepared'"', replace

* ---------------------------------------------------------------------------
* 2. Prepare L01 results and resolve a mortality DOB only when the NRN century
*    is unambiguous from a years-valued age at death. L02/L03 may enter only
*    the two pending statuses without a material identifier contradiction.
* ---------------------------------------------------------------------------
use `"`l01_input'"', clear

isid record_id
generate long __death_row_id = _n

foreach required_variable in record_id dth_date pname nrn mortality_sex ///
        mortality_age mortality_agetxt l01_person_match linkage_rule_id ///
        linkage_status {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Stage 4B diagnostic is missing required variable: `required_variable'"
        exit 111
    }
}

capture confirm string variable nrn
if _rc {
    display as error "Mortality NRN must be stored as source text."
    exit 109
}

capture confirm variable nrn_clean
if _rc {
    generate str32 nrn_clean = subinstr(strtrim(nrn), "-", "", .)
    replace nrn_clean = subinstr(nrn_clean, " ", "", .)
}

* Stage 4B already retains this derived field. Recalculate it from the
* immutable source code so this pass is self-contained and does not fail on
* the expected inherited variable name.
capture drop mortality_sex_canonical
generate byte mortality_sex_canonical = .
replace mortality_sex_canonical = 2 if strtrim(mortality_sex) == "1"
replace mortality_sex_canonical = 1 if strtrim(mortality_sex) == "2"
generate double mortality_age_numeric = real(strtrim(mortality_age))

generate byte __death_nrn_format_valid = strlen(nrn_clean) == 10 & ///
    regexm(nrn_clean, "^[0-9]+$")
generate int __death_nrn_year = real(substr(nrn_clean, 1, 2))
generate int __death_nrn_month = real(substr(nrn_clean, 3, 2))
generate int __death_nrn_day = real(substr(nrn_clean, 5, 2))
generate double __death_nrn_date_2000 = ///
    mdy(__death_nrn_month, __death_nrn_day, 2000 + __death_nrn_year)
generate double __death_nrn_date_1900 = ///
    mdy(__death_nrn_month, __death_nrn_day, 1900 + __death_nrn_year)
generate byte __death_nrn_date_valid = __death_nrn_format_valid == 1 & ///
    !missing(__death_nrn_date_2000) & ///
    month(__death_nrn_date_2000) == __death_nrn_month & ///
    day(__death_nrn_date_2000) == __death_nrn_day
generate byte __death_nrn_valid = __death_nrn_format_valid == 1 & ///
    __death_nrn_date_valid == 1
generate byte __death_age_2000_compatible = __death_nrn_valid == 1 & ///
    strtrim(mortality_agetxt) == "6" & ///
    !missing(mortality_age_numeric, dth_date, __death_nrn_date_2000) & ///
    abs(mortality_age_numeric - ///
    floor((dth_date - __death_nrn_date_2000) / 365.25)) <= 1
generate byte __death_age_1900_compatible = __death_nrn_valid == 1 & ///
    strtrim(mortality_agetxt) == "6" & ///
    !missing(mortality_age_numeric, dth_date, __death_nrn_date_1900) & ///
    abs(mortality_age_numeric - ///
    floor((dth_date - __death_nrn_date_1900) / 365.25)) <= 1
generate double mortality_dob_resolved = .
replace mortality_dob_resolved = __death_nrn_date_2000 if ///
    __death_age_2000_compatible == 1 & __death_age_1900_compatible == 0
replace mortality_dob_resolved = __death_nrn_date_1900 if ///
    __death_age_1900_compatible == 1 & __death_age_2000_compatible == 0
format mortality_dob_resolved %td

generate str244 mortality_full_name_norm = upper(strtrim(pname))
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, ".", " ", .)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, ",", " ", .)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, "-", " ", .)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, "/", " ", .)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, "(", " ", .)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, ")", " ", .)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm, char(39), " ", .)
replace mortality_full_name_norm = strtrim(itrim(mortality_full_name_norm))
generate str80 mortality_name_first = word(mortality_full_name_norm, 1)
generate str80 mortality_name_last = ///
    word(mortality_full_name_norm, wordcount(mortality_full_name_norm))
generate byte l02_l03_permitted = l01_person_match == 0 & ///
    inlist(linkage_status, "pending_invalid_mortality_nrn", ///
    "pending_no_valid_cvd_nrn")
save `"`deaths_base'"', replace

* ---------------------------------------------------------------------------
* 3. L02: exact normalized full name, canonical sex, exact DOB and a unique
*    CVD person proxy. Repeated hospital events for one proxy count once.
* ---------------------------------------------------------------------------
use `"`events_prepared'"', clear
keep if cvd_identity_conflict == 0 & cvd_full_name_norm != "" & ///
    !missing(cvd_sex_canonical, cvd_dob_resolved)
keep event_person_key cvd_full_name_norm cvd_sex_canonical cvd_dob_resolved
duplicates drop
* joinby requires identically named key variables in both datasets. These
* temporary names make the L02 comparison explicit while leaving the CVD event
* preparation and the later provenance variables unchanged.
rename cvd_full_name_norm mortality_full_name_norm
rename cvd_sex_canonical mortality_sex_canonical
rename cvd_dob_resolved mortality_dob_resolved
save `"`l02_candidates'"', replace

use `"`deaths_base'"', clear
keep if l02_l03_permitted == 1 & mortality_full_name_norm != "" & ///
    !missing(mortality_sex_canonical, mortality_dob_resolved)
keep __death_row_id mortality_full_name_norm mortality_sex_canonical ///
    mortality_dob_resolved
joinby mortality_full_name_norm mortality_sex_canonical mortality_dob_resolved ///
    using `"`l02_candidates'"'
bysort __death_row_id event_person_key: keep if _n == 1
bysort __death_row_id: generate long l02_candidate_n = _N
bysort __death_row_id: keep if _n == 1
keep __death_row_id l02_candidate_n event_person_key
rename event_person_key l02_event_person_key
isid __death_row_id
save `"`l02_summary'"', replace

* ---------------------------------------------------------------------------
* 4. L03: exact first/surname boundary tokens in either order. A DOB mismatch
*    cannot be rescued by age. The age fallback is allowed only when a DOB is
*    absent and the mortality source explicitly records age in years.
* ---------------------------------------------------------------------------
use `"`events_prepared'"', clear
keep if cvd_identity_conflict == 0 & cvd_name_first != "" & ///
    cvd_name_last != "" & !missing(cvd_sex_canonical)
keep event_person_key cvd_name_first cvd_name_last cvd_sex_canonical ///
    cvd_dob_resolved doe agey
preserve
    rename cvd_name_first l03_name_first
    rename cvd_name_last l03_name_last
    save `"`l03_candidates'"', replace
restore
rename cvd_name_first l03_name_last
rename cvd_name_last l03_name_first
append using `"`l03_candidates'"'
save `"`l03_candidates'"', replace

use `"`deaths_base'"', clear
keep if l02_l03_permitted == 1 & mortality_name_first != "" & ///
    mortality_name_last != "" & !missing(mortality_sex_canonical)
merge 1:1 __death_row_id using `"`l02_summary'"', keep(master match) ///
    gen(__l02_summary_merge)
keep if missing(l02_candidate_n) | l02_candidate_n != 1
drop __l02_summary_merge l02_candidate_n l02_event_person_key
keep __death_row_id dth_date mortality_name_first mortality_name_last ///
    mortality_sex_canonical mortality_dob_resolved mortality_age_numeric ///
    mortality_agetxt
rename mortality_name_first l03_name_first
rename mortality_name_last l03_name_last
rename mortality_sex_canonical cvd_sex_canonical
joinby l03_name_first l03_name_last cvd_sex_canonical using `"`l03_candidates'"'
generate byte __l03_exact_dob = !missing(mortality_dob_resolved, ///
    cvd_dob_resolved) & mortality_dob_resolved == cvd_dob_resolved
generate double __cvd_age_at_death = agey + ///
    floor((dth_date - doe) / 365.25) if !missing(agey, doe, dth_date) & ///
    doe <= dth_date
generate byte __l03_age_fallback = ///
    (missing(mortality_dob_resolved) | missing(cvd_dob_resolved)) & ///
    strtrim(mortality_agetxt) == "6" & ///
    !missing(mortality_age_numeric, __cvd_age_at_death) & ///
    abs(mortality_age_numeric - __cvd_age_at_death) <= 1
keep if __l03_exact_dob == 1 | __l03_age_fallback == 1
bysort __death_row_id event_person_key: egen byte __pair_exact_dob = ///
    max(__l03_exact_dob)
bysort __death_row_id event_person_key: egen byte __pair_age_fallback = ///
    max(__l03_age_fallback)
bysort __death_row_id event_person_key: keep if _n == 1
bysort __death_row_id: generate long l03_candidate_n = _N
bysort __death_row_id: keep if _n == 1
generate str12 l03_match_basis = "age_fallback"
replace l03_match_basis = "exact_dob" if __pair_exact_dob == 1
keep __death_row_id l03_candidate_n event_person_key l03_match_basis
rename event_person_key l03_event_person_key
isid __death_row_id
save `"`l03_summary'"', replace

* ---------------------------------------------------------------------------
* 5. Combine the immutable L01 result with L02/L03. An L02 or L03 result is
*    accepted only when there is exactly one person proxy. All other cases stay
*    pending; this is not yet an unresolved-estimator classification.
* ---------------------------------------------------------------------------
use `"`deaths_base'"', clear
merge 1:1 __death_row_id using `"`l02_summary'"', keep(master match) ///
    gen(__l02_merge)
drop __l02_merge
merge 1:1 __death_row_id using `"`l03_summary'"', keep(master match) ///
    gen(__l03_merge)
drop __l03_merge

generate byte l02_person_match = l02_candidate_n == 1
generate byte l03_person_match = l03_candidate_n == 1
generate byte final_person_match = l01_person_match == 1 | ///
    l02_person_match == 1 | l03_person_match == 1
generate str244 final_event_person_key = ""
replace final_event_person_key = "N:" + nrn_clean if l01_person_match == 1
replace final_event_person_key = l02_event_person_key if l02_person_match == 1
replace final_event_person_key = l03_event_person_key if l03_person_match == 1
generate str3 final_linkage_rule_id = ""
replace final_linkage_rule_id = "L01" if l01_person_match == 1
replace final_linkage_rule_id = "L02" if l02_person_match == 1
replace final_linkage_rule_id = "L03" if l03_person_match == 1
generate str60 final_linkage_status = linkage_status
replace final_linkage_status = "L02_full_name_dob_sex" if l02_person_match == 1
replace final_linkage_status = "L03_boundary_name_dob" if ///
    l03_person_match == 1 & l03_match_basis == "exact_dob"
replace final_linkage_status = "L03_boundary_name_age" if ///
    l03_person_match == 1 & l03_match_basis == "age_fallback"
replace final_linkage_status = "pending_l02_l03_no_unique_candidate" if ///
    l02_l03_permitted == 1 & final_person_match == 0

save `"`matched_deaths'"', replace

* ---------------------------------------------------------------------------
* 6. Episode linkage is repeated for all final L01/L02/L03 person proxies.
*    Only an event 0--27 days before death is already recorded. A remote prior
*    event remains a private diagnostic and never blocks an additional DCO.
* ---------------------------------------------------------------------------
use `"`matched_deaths'"', clear
keep if final_person_match == 1
keep __death_row_id final_event_person_key dth_date
rename final_event_person_key event_person_key

if _N == 0 {
    clear
    set obs 0
    generate long __death_row_id = .
    generate long episode_event_count_0_27 = .
    generate long episode_heart_count_0_27 = .
    generate long episode_stroke_count_0_27 = .
    generate double nearest_prior_event_date = .
    format nearest_prior_event_date %td
    generate double nearest_prior_event_days = .
    generate byte remote_prior_event = .
    save `"`episode_summary'"', replace
}
else {
    * More than one mortality candidate can validly resolve to one CVD person
    * proxy. joinby therefore preserves every death-event pair without falsely
    * requiring the mortality-side person key to be unique.
    joinby event_person_key using `"`events_prepared'"'
    keep if inlist(episode_event_family, "heart", "stroke")

    generate double __prior_event_days = dth_date - doe if doe <= dth_date
    generate byte __episode_event = inrange(__prior_event_days, 0, 27)
    generate byte __episode_heart = __episode_event == 1 & ///
        episode_event_family == "heart"
    generate byte __episode_stroke = __episode_event == 1 & ///
        episode_event_family == "stroke"
    bysort __death_row_id: egen long episode_event_count_0_27 = ///
        total(__episode_event)
    bysort __death_row_id: egen long episode_heart_count_0_27 = ///
        total(__episode_heart)
    bysort __death_row_id: egen long episode_stroke_count_0_27 = ///
        total(__episode_stroke)
    bysort __death_row_id: egen double nearest_prior_event_date = ///
        max(cond(__prior_event_days >= 0, doe, .))
    generate double nearest_prior_event_days = dth_date - ///
        nearest_prior_event_date if !missing(nearest_prior_event_date)
    generate byte remote_prior_event = nearest_prior_event_days > 27 if ///
        !missing(nearest_prior_event_days)
    bysort __death_row_id: generate byte __first_episode_row = _n == 1
    keep if __first_episode_row == 1
    keep __death_row_id episode_event_count_0_27 episode_heart_count_0_27 ///
        episode_stroke_count_0_27 nearest_prior_event_date ///
        nearest_prior_event_days remote_prior_event
    format nearest_prior_event_date %td
    isid __death_row_id
    save `"`episode_summary'"', replace
}

use `"`matched_deaths'"', clear
merge 1:1 __death_row_id using `"`episode_summary'"', keep(master match) ///
    gen(__episode_summary_merge)
drop __episode_summary_merge __death_row_id
generate str36 final_episode_outcome = "pending_no_deterministic_match"
replace final_episode_outcome = "recorded_event_0_27_days" if ///
    final_person_match == 1 & episode_event_count_0_27 > 0
replace final_episode_outcome = "provisional_additional_dco" if ///
    final_person_match == 1 & episode_event_count_0_27 == 0

label data "BNR private CVD L01-L03 linkage and episode diagnostic"
label variable l02_person_match "Matched by unique L02 full-name/DOB/sex rule"
label variable l03_person_match "Matched by unique L03 boundary-name rule"
label variable final_person_match "Matched by one approved deterministic rule"
label variable final_linkage_rule_id "Final deterministic linkage rule ID"
label variable final_linkage_status "Final linkage result or pending reason"
label variable final_episode_outcome "Episode result; not a final DCO decision"
label variable l03_match_basis "L03 used exact DOB or years-only age fallback"

* ---------------------------------------------------------------------------
* 7. Aggregate QA only. The result DTA remains strictly private.
* ---------------------------------------------------------------------------
tempname qa_handle
postfile `qa_handle' str72 check long count str190 detail using `qa_dta', replace

quietly count
local mortality_candidates = r(N)
post `qa_handle' ("Mortality candidates") (`mortality_candidates') ///
    ("Inclusive mortality candidates within the CVD coverage window")

quietly count if l01_person_match == 1
local l01_retained = r(N)
post `qa_handle' ("L01 retained person matches") (`l01_retained') ///
    ("Previously validated Stage 4B exact-NRN matches")

quietly count if l02_l03_permitted == 1 & mortality_full_name_norm != "" & ///
    !missing(mortality_sex_canonical, mortality_dob_resolved)
local l02_eligible = r(N)
post `qa_handle' ("L02 eligible mortality candidates") (`l02_eligible') ///
    ("Pending L01 cases with normalized full name, sex and resolved DOB")

quietly count if l02_person_match == 1
local l02_matched = r(N)
post `qa_handle' ("L02 unique person matches") (`l02_matched') ///
    ("One exact normalized full-name/DOB/sex CVD person proxy")

quietly count if !missing(l02_candidate_n) & l02_candidate_n > 1
local l02_ambiguous = r(N)
post `qa_handle' ("L02 ambiguous candidate sets") (`l02_ambiguous') ///
    ("More than one L02 person proxy; retained as pending")

quietly count if l02_l03_permitted == 1 & l02_person_match == 0 & ///
    mortality_name_first != "" & mortality_name_last != "" & ///
    !missing(mortality_sex_canonical)
local l03_eligible = r(N)
post `qa_handle' ("L03 eligible mortality candidates") (`l03_eligible') ///
    ("After L02, with boundary names and known canonical sex")

quietly count if l03_person_match == 1
local l03_matched = r(N)
post `qa_handle' ("L03 unique person matches") (`l03_matched') ///
    ("One boundary-name/sex/DOB-or-age CVD person proxy")

quietly count if !missing(l03_candidate_n) & l03_candidate_n > 1
local l03_ambiguous = r(N)
post `qa_handle' ("L03 ambiguous candidate sets") (`l03_ambiguous') ///
    ("More than one L03 person proxy; retained as pending")

quietly count if l03_person_match == 1 & l03_match_basis == "exact_dob"
local l03_exact_dob = r(N)
post `qa_handle' ("L03 exact-DOB unique matches") (`l03_exact_dob') ///
    ("Boundary names and sex; exact resolved DOB")

quietly count if l03_person_match == 1 & l03_match_basis == "age_fallback"
local l03_age_fallback = r(N)
post `qa_handle' ("L03 age-fallback unique matches") (`l03_age_fallback') ///
    ("Boundary names and sex; mortality age unit explicitly Years")

quietly count if l01_person_match == 0 & l02_l03_permitted == 0
local blocked_pending = r(N)
post `qa_handle' ("L01 contradiction-blocked pending candidates") (`blocked_pending') ///
    ("Identifier conflicts or duplicate mortality NRNs are not overridden")

quietly count if final_person_match == 1
local final_matched = r(N)
post `qa_handle' ("Final deterministic person matches") (`final_matched') ///
    ("L01, L02 or L03 only")

quietly count if final_episode_outcome == "recorded_event_0_27_days"
local recorded_episode = r(N)
post `qa_handle' ("Final recorded event episodes") (`recorded_episode') ///
    ("One or more same-person Heart/Stroke events 0--27 days before death")

quietly count if final_episode_outcome == "provisional_additional_dco"
local provisional_additional = r(N)
post `qa_handle' ("Final provisional additional DCOs") (`provisional_additional') ///
    ("No same-person Heart/Stroke event in the 0--27-day window")

quietly count if final_person_match == 1 & remote_prior_event == 1
local remote_event = r(N)
post `qa_handle' ("Final links with remote prior event") (`remote_event') ///
    ("Nearest same-person event was retained but was more than 27 days before death")

quietly count if final_person_match == 0
local final_pending = r(N)
post `qa_handle' ("Final pending or unresolved candidates") (`final_pending') ///
    ("Not yet an unresolved-estimator classification")

assert `final_matched' + `final_pending' == `mortality_candidates'

postclose `qa_handle'

save `"`results_output'"', replace

use `"`qa_dta'"', clear
order check count detail
export delimited using `"`qa_output'"', replace

display as result "L02/L03 and episode diagnostic created."
display as result "  L01 retained matches:            `l01_retained'"
display as result "  L02 unique matches:              `l02_matched'"
display as result "  L03 unique matches:              `l03_matched'"
display as result "  Final deterministic matches:     `final_matched'"
display as result "  Final pending or unresolved:     `final_pending'"

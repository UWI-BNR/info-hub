/*******************************************************************************

DO-FILE:     bnr_cvd_l01_episode_core.do

VERSION:     1.0.6 (25 August 2026)

PURPOSE:     Stage 4B private deterministic L01 and episode-linkage core.

              Applies only L01: a unique, valid exact National Registration
              Number (NRN) with no material source contradiction.  It then
              separates person linkage from episode linkage, applying the
              agreed 0--27-day pre-death window to Heart and Stroke events.

              This is deliberately a controlled first pass.  It does not
              apply L02/L03 name rules, estimate unresolved deaths, construct
              final DCO records, calculate metrics, or create public output.

INPUTS:       Private Stage 3 mortality and hospital-event linkage inputs.

OUTPUTS:      Private candidate-level L01/episode diagnostic DTA and aggregate
              QA CSV.  The DTA contains confidential linkage provenance and
              must never leave the private analysis environment.

*******************************************************************************/

version 19

clear

set more off

args deaths_input events_input results_output qa_output

if `"`deaths_input'"' == "" | `"`events_input'"' == "" | ///
        `"`results_output'"' == "" | `"`qa_output'"' == "" {
    display as error "L01 episode core received an incomplete file contract."
    exit 198
}

foreach required_file in deaths_input events_input {
    capture confirm file ``required_file''
    if _rc {
        display as error "Required Stage 3 linkage input was not found: ``required_file''"
        exit 601
    }
}

tempfile cvd_person events_l01 deaths_l01 episode_summary qa_dta

* ---------------------------------------------------------------------------
* 1. Make one deterministic person-level CVD NRN map, while retaining all
*    hospital events separately for the later episode test.
* ---------------------------------------------------------------------------
use `"`events_input'"', clear

isid eid

foreach required_variable in eid doe etype dob cvd_sex natregno {
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
generate byte l01_cvd_nrn_format_valid = strlen(nrn_clean) == 10 & ///
    regexm(nrn_clean, "^[0-9]+$")
generate int __cvd_nrn_year = real(substr(nrn_clean, 1, 2))
generate int __cvd_nrn_month = real(substr(nrn_clean, 3, 2))
generate int __cvd_nrn_day = real(substr(nrn_clean, 5, 2))
generate double __cvd_nrn_calendar_date = ///
    mdy(__cvd_nrn_month, __cvd_nrn_day, 2000 + __cvd_nrn_year)
generate byte l01_cvd_nrn_date_valid = l01_cvd_nrn_format_valid == 1 & ///
    !missing(__cvd_nrn_calendar_date) & ///
    month(__cvd_nrn_calendar_date) == __cvd_nrn_month & ///
    day(__cvd_nrn_calendar_date) == __cvd_nrn_day
generate byte l01_cvd_nrn_valid = l01_cvd_nrn_format_valid == 1 & ///
    l01_cvd_nrn_date_valid == 1
drop __cvd_nrn_year __cvd_nrn_month __cvd_nrn_day ///
    __cvd_nrn_calendar_date

generate byte __cvd_has_female = l01_cvd_nrn_valid == 1 & cvd_sex == 1
generate byte __cvd_has_male = l01_cvd_nrn_valid == 1 & cvd_sex == 2
bysort nrn_clean: egen byte __cvd_group_has_female = max(__cvd_has_female)
bysort nrn_clean: egen byte __cvd_group_has_male = max(__cvd_has_male)
generate byte l01_cvd_sex_conflict = l01_cvd_nrn_valid == 1 & ///
    __cvd_group_has_female == 1 & __cvd_group_has_male == 1

generate double __cvd_dob_for_group = dob if l01_cvd_nrn_valid == 1 & ///
    !missing(dob)
bysort nrn_clean: egen double __cvd_dob_min = min(__cvd_dob_for_group)
bysort nrn_clean: egen double __cvd_dob_max = max(__cvd_dob_for_group)
generate byte l01_cvd_dob_conflict = l01_cvd_nrn_valid == 1 & ///
    !missing(__cvd_dob_min, __cvd_dob_max) & ///
    __cvd_dob_min != __cvd_dob_max
generate double l01_cvd_dob = __cvd_dob_min

generate byte l01_cvd_person_sex = .
replace l01_cvd_person_sex = 1 if l01_cvd_nrn_valid == 1 & ///
    __cvd_group_has_female == 1 & __cvd_group_has_male == 0
replace l01_cvd_person_sex = 2 if l01_cvd_nrn_valid == 1 & ///
    __cvd_group_has_male == 1 & __cvd_group_has_female == 0

bysort nrn_clean: generate byte __first_cvd_nrn = _n == 1

preserve
    keep if l01_cvd_nrn_valid == 1 & __first_cvd_nrn == 1
    keep nrn_clean l01_cvd_person_sex l01_cvd_sex_conflict ///
        l01_cvd_dob l01_cvd_dob_conflict
    isid nrn_clean
    save `"`cvd_person'"', replace
restore

keep if l01_cvd_nrn_valid == 1 & l01_cvd_sex_conflict == 0 & ///
    l01_cvd_dob_conflict == 0
keep nrn_clean eid doe etype
generate str10 episode_event_family = ""
replace episode_event_family = "stroke" if etype == 1
replace episode_event_family = "heart" if etype == 2
keep if inlist(episode_event_family, "heart", "stroke")
save `"`events_l01'"', replace

* ---------------------------------------------------------------------------
* 2. Apply the L01 identity rule to mortality candidates.  NRN format and the
*    yymmdd prefix are both checked without numeric conversion. A known sex
*    mismatch, internally contradictory CVD demographic group, or incompatible
*    explicit CVD DOB prevents a deterministic L01 match.
* ---------------------------------------------------------------------------
use `"`deaths_input'"', clear

isid record_id

* Keep an internal immutable row key for episode aggregation and rejoining.
* record_id remains source provenance, but it is not relied upon after the
* person-to-many-events expansion.
generate long __death_row_id = _n

foreach required_variable in record_id dth_date nrn mortality_sex {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Mortality linkage input is missing required variable: `required_variable'"
        exit 111
    }
}

capture confirm string variable nrn
if _rc {
    display as error "Mortality NRN must be stored as source text."
    exit 109
}

generate str32 nrn_clean = subinstr(strtrim(nrn), "-", "", .)
replace nrn_clean = subinstr(nrn_clean, " ", "", .)
generate byte l01_death_nrn_format_valid = strlen(nrn_clean) == 10 & ///
    regexm(nrn_clean, "^[0-9]+$")
generate int __death_nrn_year = real(substr(nrn_clean, 1, 2))
generate int __death_nrn_month = real(substr(nrn_clean, 3, 2))
generate int __death_nrn_day = real(substr(nrn_clean, 5, 2))
generate double __death_nrn_calendar_date = ///
    mdy(__death_nrn_month, __death_nrn_day, 2000 + __death_nrn_year)
generate byte l01_death_nrn_date_valid = l01_death_nrn_format_valid == 1 & ///
    !missing(__death_nrn_calendar_date) & ///
    month(__death_nrn_calendar_date) == __death_nrn_month & ///
    day(__death_nrn_calendar_date) == __death_nrn_day
generate byte l01_death_nrn_valid = l01_death_nrn_format_valid == 1 & ///
    l01_death_nrn_date_valid == 1
drop __death_nrn_year __death_nrn_month __death_nrn_day ///
    __death_nrn_calendar_date

bysort nrn_clean: generate long l01_death_nrn_n = _N if ///
    l01_death_nrn_valid == 1
generate byte l01_death_nrn_unique = l01_death_nrn_valid == 1 & ///
    l01_death_nrn_n == 1

generate byte mortality_sex_canonical = .
replace mortality_sex_canonical = 2 if strtrim(mortality_sex) == "1"
replace mortality_sex_canonical = 1 if strtrim(mortality_sex) == "2"

* Keep mortality candidates only.  Without keep(master match), merge appends
* CVD-only NRN groups as extra observations with no death-row key.
merge m:1 nrn_clean using `"`cvd_person'"', keep(master match) gen(__l01_merge)

generate byte l01_cvd_counterpart_found = __l01_merge == 3
generate byte l01_sex_contradiction = l01_cvd_counterpart_found == 1 & ///
    !missing(mortality_sex_canonical, l01_cvd_person_sex) & ///
    mortality_sex_canonical != l01_cvd_person_sex

generate str6 l01_nrn_yymmdd = substr(nrn_clean, 1, 6) if ///
    l01_death_nrn_valid == 1
generate str6 __cvd_dob_yymmdd = ""
replace __cvd_dob_yymmdd = string(mod(year(l01_cvd_dob), 100), "%02.0f") + ///
    string(month(l01_cvd_dob), "%02.0f") + ///
    string(day(l01_cvd_dob), "%02.0f") if !missing(l01_cvd_dob)
generate byte l01_nrn_dob_contradiction = l01_cvd_counterpart_found == 1 & ///
    !missing(l01_cvd_dob) & l01_nrn_yymmdd != __cvd_dob_yymmdd

generate byte l01_person_match = l01_death_nrn_unique == 1 & ///
    l01_cvd_counterpart_found == 1 & l01_cvd_sex_conflict == 0 & ///
    l01_cvd_dob_conflict == 0 & l01_sex_contradiction == 0 & ///
    l01_nrn_dob_contradiction == 0

generate str3 linkage_rule_id = ""
replace linkage_rule_id = "L01" if l01_person_match == 1

generate str48 linkage_status = "pending_l02_l03"
replace linkage_status = "L01_exact_nrn" if l01_person_match == 1
replace linkage_status = "pending_invalid_mortality_nrn" if ///
    l01_death_nrn_valid == 0
replace linkage_status = "pending_duplicate_mortality_nrn" if ///
    l01_death_nrn_valid == 1 & l01_death_nrn_unique == 0
replace linkage_status = "pending_no_valid_cvd_nrn" if ///
    l01_death_nrn_unique == 1 & l01_cvd_counterpart_found == 0
replace linkage_status = "pending_cvd_sex_conflict" if ///
    l01_death_nrn_unique == 1 & l01_cvd_counterpart_found == 1 & ///
    l01_cvd_sex_conflict == 1
replace linkage_status = "pending_cvd_dob_conflict" if ///
    l01_death_nrn_unique == 1 & l01_cvd_counterpart_found == 1 & ///
    l01_cvd_dob_conflict == 1
replace linkage_status = "pending_sex_contradiction" if ///
    l01_death_nrn_unique == 1 & l01_cvd_counterpart_found == 1 & ///
    l01_cvd_sex_conflict == 0 & l01_cvd_dob_conflict == 0 & ///
    l01_sex_contradiction == 1
replace linkage_status = "pending_nrn_dob_contradiction" if ///
    l01_death_nrn_unique == 1 & l01_cvd_counterpart_found == 1 & ///
    l01_cvd_sex_conflict == 0 & l01_cvd_dob_conflict == 0 & ///
    l01_sex_contradiction == 0 & l01_nrn_dob_contradiction == 1

drop __l01_merge __cvd_dob_yymmdd
save `"`deaths_l01'"', replace

* ---------------------------------------------------------------------------
* 3. Episode linkage is a separate operation.  A linked person can have many
*    historical hospital events; only a Heart/Stroke event in the 0--27 days
*    before death is an already-recorded episode. A remote prior event is kept
*    for private QA but does not prevent provisional additional-DCO status.
* ---------------------------------------------------------------------------
use `"`deaths_l01'"', clear
keep if l01_person_match == 1
keep __death_row_id nrn_clean dth_date

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
    merge 1:m nrn_clean using `"`events_l01'"'
    keep if _merge == 3
    drop _merge

    generate double __prior_event_days = dth_date - doe if doe <= dth_date
    generate byte __episode_event = inrange(__prior_event_days, 0, 27)
    generate byte __episode_heart = __episode_event == 1 & ///
        episode_event_family == "heart"
    generate byte __episode_stroke = __episode_event == 1 & ///
        episode_event_family == "stroke"

    bysort __death_row_id: egen long episode_event_count_0_27 = total(__episode_event)
    bysort __death_row_id: egen long episode_heart_count_0_27 = total(__episode_heart)
    bysort __death_row_id: egen long episode_stroke_count_0_27 = total(__episode_stroke)
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

use `"`deaths_l01'"', clear
merge 1:1 __death_row_id using `"`episode_summary'"'
drop _merge __death_row_id

generate str36 l01_episode_outcome = "pending_l02_l03"
replace l01_episode_outcome = "recorded_event_0_27_days" if ///
    l01_person_match == 1 & episode_event_count_0_27 > 0
replace l01_episode_outcome = "provisional_additional_dco" if ///
    l01_person_match == 1 & episode_event_count_0_27 == 0

label data "BNR private CVD L01 linkage and episode diagnostic"
label variable linkage_rule_id "Deterministic person-linkage rule ID"
label variable linkage_status "L01 result or reason pending L02/L03"
label variable l01_person_match "Matched by unique valid exact NRN"
label variable l01_episode_outcome "L01 episode result; not a final DCO decision"
label variable remote_prior_event "Nearest same-person event was more than 27 days before death"
label variable nearest_prior_event_date "Nearest same-person event date on or before death"
label variable nearest_prior_event_days "Elapsed days from nearest prior event to death"

* ---------------------------------------------------------------------------
* 4. Aggregate QA. These values are safe to review; the candidate-level DTA
*    remains private and is not an upload or public-release artifact.
* ---------------------------------------------------------------------------
tempname qa_handle
postfile `qa_handle' str64 check long count str180 detail using `qa_dta', replace

quietly count
local mortality_candidates = r(N)
post `qa_handle' ("Mortality candidates") (`mortality_candidates') ///
    ("Inclusive mortality candidates within the CVD coverage window")

quietly count if l01_person_match == 1
local l01_matched = r(N)
post `qa_handle' ("L01 exact-NRN person matches") (`l01_matched') ///
    ("Unique valid NRN; no material demographic contradiction")

quietly count if l01_death_nrn_valid == 0
local invalid_death_nrn = r(N)
post `qa_handle' ("Pending: invalid mortality NRN") (`invalid_death_nrn') ///
    ("Can be considered only by later L02/L03 name rules")

quietly count if l01_death_nrn_valid == 1 & l01_death_nrn_unique == 0
local duplicate_death_nrn = r(N)
post `qa_handle' ("Pending: duplicate mortality NRN") (`duplicate_death_nrn') ///
    ("Exact NRN is not person-unique in mortality candidates")

quietly count if linkage_status == "pending_no_valid_cvd_nrn"
local no_valid_cvd_nrn = r(N)
post `qa_handle' ("Pending: no valid CVD NRN counterpart") (`no_valid_cvd_nrn') ///
    ("Can be considered only by later L02/L03 name rules")

quietly count if linkage_status == "pending_cvd_sex_conflict"
local cvd_sex_conflict = r(N)
post `qa_handle' ("Pending: CVD NRN sex conflict") (`cvd_sex_conflict') ///
    ("One CVD NRN has contradictory non-missing source sex values")

quietly count if linkage_status == "pending_cvd_dob_conflict"
local cvd_dob_conflict = r(N)
post `qa_handle' ("Pending: CVD NRN DOB conflict") (`cvd_dob_conflict') ///
    ("One CVD NRN has contradictory explicit dates of birth")

quietly count if linkage_status == "pending_sex_contradiction"
local sex_contradiction = r(N)
post `qa_handle' ("Pending: mortality/CVD sex contradiction") (`sex_contradiction') ///
    ("Known source sex values disagree for an otherwise exact NRN")

quietly count if linkage_status == "pending_nrn_dob_contradiction"
local dob_contradiction = r(N)
post `qa_handle' ("Pending: NRN/CVD DOB contradiction") (`dob_contradiction') ///
    ("Explicit CVD DOB disagrees with the NRN yymmdd prefix")

quietly count if l01_episode_outcome == "recorded_event_0_27_days"
local recorded_episode = r(N)
post `qa_handle' ("L01 recorded event episodes") (`recorded_episode') ///
    ("One or more same-person Heart/Stroke events 0--27 days before death")

quietly count if l01_episode_outcome == "provisional_additional_dco"
local provisional_additional = r(N)
post `qa_handle' ("L01 provisional additional DCOs") (`provisional_additional') ///
    ("No same-person Heart/Stroke event in the 0--27-day window")

quietly count if l01_person_match == 1 & remote_prior_event == 1
local remote_event = r(N)
post `qa_handle' ("L01 links with remote prior event") (`remote_event') ///
    ("Nearest same-person event was retained but was more than 27 days before death")

quietly count if l01_person_match == 0
local pending_l02_l03 = r(N)
post `qa_handle' ("Pending L02/L03 or unresolved") (`pending_l02_l03') ///
    ("Not a final unresolved classification; later deterministic rules remain")

postclose `qa_handle'

save `"`results_output'"', replace

use `"`qa_dta'"', clear
order check count detail
export delimited using `"`qa_output'"', replace

display as result "L01 exact-NRN and episode diagnostic created."
display as result "  L01 person matches:             `l01_matched'"
display as result "  Recorded event episodes:        `recorded_episode'"
display as result "  Provisional additional DCOs:    `provisional_additional'"
display as result "  Pending L02/L03 or unresolved:  `pending_l02_l03'"

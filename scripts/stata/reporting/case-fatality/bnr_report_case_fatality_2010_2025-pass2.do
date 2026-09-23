/*******************************************************************************
BNR CASE FATALITY, 2010-2025 — PRIVATE STUDY FILE
Version: 0.2.0 (23 September 2026)

CURRENT STAGE: input, outcome-source and deterministic linkage audit. This file
intentionally stops before the case-fatality definition is approved, final
metrics are calculated, disclosure decisions are made, or a PDF is built.
Extend this same file after private review; do not create a separate workflow.

Run from an authorised Stata 19 session with bnr_paths_LOCAL.do loaded:
    do "$BNR_STATA/reporting/case-fatality/bnr_report_case_fatality_2010_2025.do"

All inputs, outputs and logs are confidential and remain under $BNR_PRIVATE.
This script never modifies source files or publishes anything.
*******************************************************************************/

version 19
clear all
set more off

/*******************************************************************************
EDITABLE SECTION 1 — FROZEN INPUTS AND PRIVATE OUTPUT
Change only for a deliberately selected pair of releases and study version.
*******************************************************************************/
local study_id "cvd_case_fatality_2010_2025_v01"
local event_input "$BNR_PRIVATE/data/derived/cvd/y2026/m01/bnr_cvd_confidential_202601_v01.dta"
local death_input "$BNR_PRIVATE/data/raw/redcap/mortality/y2026/m07/bnr_mort_s1_202607.dta"
local first_year 2010
local last_year 2025
local death_cutoff = mdy(1, 31, 2026)

local stage_root "$BNR_PRIVATE/outputs/staging/reports/cvd"
local report_type_root "`stage_root'/case-fatality"
local study_root "`report_type_root'/`study_id'"
local review_root "`study_root'/review"

/*******************************************************************************
CONTROLLED SECTION 1 — INPUT CONTRACT AND PRIVATE FOLDERS
DO NOT EDIT for a routine study update.
*******************************************************************************/
foreach path_name in BNR_PRIVATE BNR_STATA {
    if `"$`path_name'"' == "" {
        display as error "Required path is not configured: `path_name'"
        exit 198
    }
}
foreach input_path in event_input death_input {
    capture confirm file `"``input_path''"'
    if _rc {
        display as error "Required private input missing: ``input_path''"
        exit 601
    }
}
if `last_year' < `first_year' | `death_cutoff' < mdy(12,31,`last_year') + 30 {
    display as error "Invalid year range or death cut-off for full 30-day follow-up."
    exit 198
}
capture mkdir "$BNR_PRIVATE/outputs/staging/reports"
capture mkdir "$BNR_PRIVATE/outputs/staging/reports/cvd"
capture mkdir "`report_type_root'"
capture mkdir "`study_root'"
capture mkdir "`review_root'"
capture log close case_fatality
log using "`review_root'/case_fatality_input_audit.log", text replace name(case_fatality)
display as text "Private case-fatality input audit: `study_id'"
display as text "CVD input: `event_input'"
display as text "Death input: `death_input'"
display as text "Death extract cut-off: " %tdCCYY-NN-DD `death_cutoff'

tempfile events_source events_prepared cvd_nrn_map index_events ///
    deaths_source deaths_l01 deaths_base l02_candidates l02_summary ///
    l03_candidates l03_summary matched_deaths event_deaths

/*******************************************************************************
CONTROLLED SECTION 2 — CVD EVENT AND HOSPITAL-OUTCOME AUDIT
DO NOT EDIT. No outcome is imputed from discharge status. DCO=1 is excluded.
*******************************************************************************/
use "`event_input'", clear
foreach field in eid dco etype doe dod dodi sadi sex agey ///
    natregno fname mname lname dob {
    capture confirm variable `field'
    if _rc {
        display as error "CVD Step 2 input lacks required field: `field'"
        log close case_fatality
        exit 111
    }
}
capture isid eid
if _rc {
    display as error "CVD eid is not unique."
    log close case_fatality
    exit 459
}
capture assert inlist(dco,0,1)
if _rc {
    display as error "CVD dco has an unexpected or missing value."
    log close case_fatality
    exit 459
}
quietly count if dco == 1
display as result "Legacy DCO rows excluded: " r(N)
keep if dco == 0
keep if inrange(doe,mdy(1,1,`first_year'),mdy(12,31,`last_year'))
* Retain every year unchanged. In particular, 2024 is not corrected or
* excluded; annual volumes provide evidence for the planned completeness review.
generate int event_year = year(doe)
generate byte one = 1
generate byte bad_event_type = !inlist(etype,1,2)
* Preserve dod unchanged. The historical file sometimes fills dod with dodi
* for people discharged alive. An analytical copy removes only unmistakably
* impossible magnitudes; alive-record dod values never establish a death.
clonevar dod_clean = dod
generate byte dod_extreme = !missing(dod_clean) & abs(dod_clean) > 1000000
replace dod_clean = . if dod_extreme == 1
format dod_clean %tdCCYY-NN-DD
generate byte dod_matches_dodi = !missing(dod_clean,dodi) & dod_clean == dodi
generate byte alive_dod_matches_dodi = sadi == 1 & dod_matches_dodi == 1
generate byte bad_recorded_dod = !missing(dod_clean) & dod_clean < doe
generate byte recorded_dod_30 = !missing(dod_clean) & ///
    inrange(dod_clean-doe,0,30)
generate byte recorded_dod_later = !missing(dod_clean) & dod_clean-doe > 30
generate byte missing_recorded_dod = missing(dod_clean)
generate byte hospital_death_30 = sadi == 2 & ///
    inrange(dod_clean-doe,0,30)
generate byte missing_discharge_status = missing(sadi)
generate byte missing_age = missing(agey)
generate byte missing_sex = !inlist(sex,1,2)

* Placeholder is distinct from blank and from other invalid identifiers.
capture confirm string variable natregno
if _rc {
    display as error "CVD natregno must be source text."
    log close case_fatality
    exit 109
}
generate str32 nrn_clean = subinstr(strtrim(natregno),"-","",.)
replace nrn_clean = subinstr(nrn_clean," ","",.)
generate byte nrn_blank = nrn_clean == ""
generate byte nrn_placeholder = nrn_clean == "9999999999"
generate byte nrn_format = strlen(nrn_clean)==10 & regexm(nrn_clean,"^[0-9]+$")
generate int nrn_month = real(substr(nrn_clean,3,2))
generate int nrn_day = real(substr(nrn_clean,5,2))
generate int nrn_year = real(substr(nrn_clean,1,2))
generate double nrn_date = mdy(nrn_month,nrn_day,2000+nrn_year)
generate byte nrn_valid = nrn_format & !missing(nrn_date) & ///
    month(nrn_date)==nrn_month & day(nrn_date)==nrn_day
generate byte nrn_other_invalid = !nrn_blank & !nrn_placeholder & !nrn_valid

save `"`events_source'"', replace

* Never write direct identity fields or source values into these review files.
preserve
    keep if bad_recorded_dod | bad_event_type | dod_extreme
    keep eid event_year etype doe dod dod_clean dodi sadi dod_extreme ///
        bad_recorded_dod bad_event_type
    save "`review_root'/recorded_dod_exceptions.dta", replace
restore
preserve
    keep if !missing(dod) | !missing(sadi)
    keep eid event_year etype doe dod dod_clean dodi sadi recorded_dod_30 ///
        recorded_dod_later hospital_death_30 dod_matches_dodi ///
        alive_dod_matches_dodi dod_extreme bad_recorded_dod
    save "`review_root'/hospital_outcome_review.dta", replace
restore
preserve
    collapse (sum) events=one recorded_dod_30 recorded_dod_later ///
        bad_recorded_dod bad_event_type missing_recorded_dod ///
        missing_discharge_status missing_age missing_sex nrn_blank ///
        nrn_placeholder nrn_other_invalid nrn_valid dod_extreme ///
        dod_matches_dodi alive_dod_matches_dodi hospital_death_30, ///
        by(event_year etype sex)
    sort event_year etype sex
    save "`review_root'/cvd_event_audit_by_year_type_sex.dta", replace
restore
preserve
    collapse (sum) events=one recorded_dod_30 hospital_death_30 ///
        missing_recorded_dod dod_matches_dodi alive_dod_matches_dodi ///
        dod_extreme, by(event_year etype sadi)
    sort event_year etype sadi
    save "`review_root'/discharge_status_by_year_type.dta", replace
restore

display as text "Hospital discharge-status codes and labels (verify before defining deceased):"
tabulate sadi, missing
display as text "Hospital discharge status by valid death-date category:"
tabulate sadi recorded_dod_30, missing
display as text "Recorded dod exceptions by year:"
quietly count if bad_recorded_dod
if r(N) > 0 tabulate event_year if bad_recorded_dod
else display as result "None found."

/*******************************************************************************
CONTROLLED SECTION 3 — ALL-DEATHS EXTRACT AUDIT
DO NOT EDIT. Mortality Step 2 cause classification is deliberately unused.
*******************************************************************************/
use "`death_input'", clear
foreach field in record_id dth_date reg_date qa_dod qa_dup nrn pname sex age agetxt {
    capture confirm variable `field'
    if _rc {
        display as error "Mortality Step 1 input lacks required field: `field'"
        log close case_fatality
        exit 111
    }
}
capture isid record_id
if _rc {
    display as error "Mortality record_id is not unique."
    log close case_fatality
    exit 459
}
generate int death_year = year(dth_date)
generate byte one = 1
generate byte invalid_death_date = qa_dod != 0 | missing(dth_date)
generate byte bad_registration_date = missing(reg_date)
generate byte registration_before_death = !missing(reg_date,dth_date) & reg_date<dth_date
generate int registration_lag = reg_date-dth_date if !missing(reg_date,dth_date)
generate byte registration_over_30 = registration_lag>30 if !missing(registration_lag)
generate byte registration_over_90 = registration_lag>90 if !missing(registration_lag)
generate byte flagged_duplicate = qa_dup==1
generate byte missing_death_nrn = strtrim(nrn)==""
generate str32 __death_nrn_audit = subinstr(strtrim(nrn),"-","",.)
replace __death_nrn_audit = subinstr(__death_nrn_audit," ","",.)
generate byte placeholder_death_nrn = __death_nrn_audit=="9999999999"
generate byte unavailable_death_nrn = ///
    missing_death_nrn==1 | placeholder_death_nrn==1
quietly count if invalid_death_date
display as result "Mortality records with missing or invalid death date: " r(N)
quietly count if qa_dod == 0 & !missing(dth_date) & dth_date>`death_cutoff'
if r(N) {
    display as error "Deaths extend past the selected mortality release cut-off."
    log close case_fatality
    exit 459
}
save `"`deaths_source'"', replace
preserve
    keep if invalid_death_date | registration_before_death | flagged_duplicate
    keep record_id dth_date reg_date qa_dod invalid_death_date ///
        registration_before_death flagged_duplicate
    save "`review_root'/mortality_date_exceptions.dta", replace
restore
preserve
    keep if inrange(death_year,`first_year',`last_year'+1)
    collapse (sum) deaths=one invalid_death_date bad_registration_date ///
        registration_before_death registration_over_30 ///
        registration_over_90 flagged_duplicate missing_death_nrn ///
        placeholder_death_nrn unavailable_death_nrn, by(death_year)
    sort death_year
    save "`review_root'/mortality_audit_by_death_year.dta", replace
restore

/*******************************************************************************
CONTROLLED SECTION 4 — EVENT PERSON PROXIES AND ANNUAL INDEX EVENTS
DO NOT EDIT. The index is the first event for each deterministic person proxy,
event type and calendar year. An unidentifiable event remains its own proxy.
*******************************************************************************/
use `"`events_source'"', clear

generate byte cvd_sex_canonical = .
replace cvd_sex_canonical = 1 if sex == 1
replace cvd_sex_canonical = 2 if sex == 2

generate double __cvd_nrn_date_2000 = nrn_date
generate double __cvd_nrn_date_1900 = ///
    mdy(nrn_month,nrn_day,1900+nrn_year) if nrn_valid == 1
generate byte __cvd_age_2000_compatible = nrn_valid == 1 & ///
    !missing(agey,doe,__cvd_nrn_date_2000) & ///
    abs(agey-floor((doe-__cvd_nrn_date_2000)/365.25)) <= 1
generate byte __cvd_age_1900_compatible = nrn_valid == 1 & ///
    !missing(agey,doe,__cvd_nrn_date_1900) & ///
    abs(agey-floor((doe-__cvd_nrn_date_1900)/365.25)) <= 1
generate double cvd_dob_nrn = .
replace cvd_dob_nrn = __cvd_nrn_date_2000 if ///
    __cvd_age_2000_compatible == 1 & __cvd_age_1900_compatible == 0
replace cvd_dob_nrn = __cvd_nrn_date_1900 if ///
    __cvd_age_1900_compatible == 1 & __cvd_age_2000_compatible == 0
generate double cvd_dob_resolved = dob
replace cvd_dob_resolved = cvd_dob_nrn if missing(cvd_dob_resolved)
format cvd_dob_resolved %tdCCYY-NN-DD

generate byte __cvd_has_female = nrn_valid == 1 & cvd_sex_canonical == 1
generate byte __cvd_has_male = nrn_valid == 1 & cvd_sex_canonical == 2
bysort nrn_clean: egen byte __cvd_group_has_female = max(__cvd_has_female)
bysort nrn_clean: egen byte __cvd_group_has_male = max(__cvd_has_male)
generate byte __cvd_explicit_dob_marker = nrn_valid == 1 & !missing(dob)
generate double __cvd_explicit_dob = dob if __cvd_explicit_dob_marker == 1
bysort nrn_clean: egen double __cvd_explicit_dob_min = min(__cvd_explicit_dob)
bysort nrn_clean: egen double __cvd_explicit_dob_max = max(__cvd_explicit_dob)
generate byte cvd_identity_conflict = nrn_valid == 1 & ///
    ((__cvd_group_has_female == 1 & __cvd_group_has_male == 1) | ///
    (!missing(__cvd_explicit_dob_min,__cvd_explicit_dob_max) & ///
    __cvd_explicit_dob_min != __cvd_explicit_dob_max))

generate str244 cvd_full_name_norm = ///
    upper(strtrim(fname + " " + mname + " " + lname))
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,"."," ",.)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,","," ",.)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,"-"," ",.)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,"/"," ",.)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,"("," ",.)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,")"," ",.)
replace cvd_full_name_norm = subinstr(cvd_full_name_norm,char(39)," ",.)
replace cvd_full_name_norm = strtrim(itrim(cvd_full_name_norm))
generate str80 cvd_name_first = word(cvd_full_name_norm,1)
generate str80 cvd_name_last = ///
    word(cvd_full_name_norm,wordcount(cvd_full_name_norm))

generate str244 event_person_key = "E:" + eid
replace event_person_key = "N:" + nrn_clean if ///
    nrn_valid == 1 & cvd_identity_conflict == 0
replace event_person_key = "F:" + cvd_full_name_norm + "|" + ///
    string(cvd_sex_canonical,"%01.0f") + "|" + ///
    string(cvd_dob_resolved,"%12.0f") if nrn_valid == 0 & ///
    cvd_full_name_norm != "" & !missing(cvd_sex_canonical,cvd_dob_resolved)
generate str1 event_person_key_source = substr(event_person_key,1,1)

sort event_person_key etype event_year doe eid
by event_person_key etype event_year: generate byte annual_index_event = _n == 1
save `"`events_prepared'"', replace
preserve
    keep if annual_index_event == 1
    isid event_person_key etype event_year
    save `"`index_events'"', replace
restore

preserve
    keep if nrn_valid == 1
    generate byte cvd_nrn_sex_conflict = ///
        __cvd_group_has_female == 1 & __cvd_group_has_male == 1
    generate byte cvd_nrn_dob_conflict = ///
        !missing(__cvd_explicit_dob_min,__cvd_explicit_dob_max) & ///
        __cvd_explicit_dob_min != __cvd_explicit_dob_max
    generate double cvd_person_dob = __cvd_explicit_dob_min
    generate byte cvd_person_sex = .
    replace cvd_person_sex = 1 if ///
        __cvd_group_has_female == 1 & __cvd_group_has_male == 0
    replace cvd_person_sex = 2 if ///
        __cvd_group_has_male == 1 & __cvd_group_has_female == 0
    keep nrn_clean cvd_person_dob cvd_person_sex ///
        cvd_nrn_sex_conflict cvd_nrn_dob_conflict
    bysort nrn_clean: keep if _n == 1
    isid nrn_clean
    save `"`cvd_nrn_map'"', replace
restore

preserve
    collapse (sum) events=one index_events=annual_index_event, ///
        by(event_year etype sex event_person_key_source)
    generate long repeat_events_excluded = events-index_events
    sort event_year etype sex event_person_key_source
    save "`review_root'/index_event_audit_by_year_type_sex.dta", replace
restore

/*******************************************************************************
CONTROLLED SECTION 5 — DETERMINISTIC ALL-CAUSE DEATH LINKAGE (L01-L03)
DO NOT EDIT. Rules reproduce the approved CVD identity principles. L02/L03 do
not override duplicate NRNs or contradictions. There is no fuzzy matching.
*******************************************************************************/
use `"`deaths_source'"', clear
keep if qa_dod == 0 & !missing(dth_date) & ///
    inrange(dth_date,mdy(1,1,`first_year'),`death_cutoff')
generate long __death_row_id = _n

capture confirm string variable nrn
if _rc {
    display as error "Mortality NRN must be stored as source text."
    log close case_fatality
    exit 109
}
generate str32 nrn_clean = subinstr(strtrim(nrn),"-","",.)
replace nrn_clean = subinstr(nrn_clean," ","",.)
generate byte __death_nrn_format_valid = strlen(nrn_clean)==10 & ///
    regexm(nrn_clean,"^[0-9]+$")
generate int __death_nrn_year = real(substr(nrn_clean,1,2))
generate int __death_nrn_month = real(substr(nrn_clean,3,2))
generate int __death_nrn_day = real(substr(nrn_clean,5,2))
generate double __death_nrn_date_2000 = ///
    mdy(__death_nrn_month,__death_nrn_day,2000+__death_nrn_year)
generate double __death_nrn_date_1900 = ///
    mdy(__death_nrn_month,__death_nrn_day,1900+__death_nrn_year)
generate byte __death_nrn_valid = __death_nrn_format_valid == 1 & ///
    nrn_clean != "9999999999" & !missing(__death_nrn_date_2000) & ///
    month(__death_nrn_date_2000)==__death_nrn_month & ///
    day(__death_nrn_date_2000)==__death_nrn_day
bysort nrn_clean: generate long __death_nrn_count = _N if __death_nrn_valid == 1

generate byte mortality_sex_canonical = .
replace mortality_sex_canonical = 2 if strtrim(sex) == "1"
replace mortality_sex_canonical = 1 if strtrim(sex) == "2"
generate double mortality_age_numeric = real(strtrim(age))
generate byte __death_age_2000_compatible = __death_nrn_valid == 1 & ///
    strtrim(agetxt) == "6" & ///
    !missing(mortality_age_numeric,dth_date,__death_nrn_date_2000) & ///
    abs(mortality_age_numeric-floor((dth_date-__death_nrn_date_2000)/365.25)) <= 1
generate byte __death_age_1900_compatible = __death_nrn_valid == 1 & ///
    strtrim(agetxt) == "6" & ///
    !missing(mortality_age_numeric,dth_date,__death_nrn_date_1900) & ///
    abs(mortality_age_numeric-floor((dth_date-__death_nrn_date_1900)/365.25)) <= 1
generate double mortality_dob_resolved = .
replace mortality_dob_resolved = __death_nrn_date_2000 if ///
    __death_age_2000_compatible == 1 & __death_age_1900_compatible == 0
replace mortality_dob_resolved = __death_nrn_date_1900 if ///
    __death_age_1900_compatible == 1 & __death_age_2000_compatible == 0
format mortality_dob_resolved %tdCCYY-NN-DD

generate str244 mortality_full_name_norm = upper(strtrim(pname))
replace mortality_full_name_norm = subinstr(mortality_full_name_norm,"."," ",.)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm,","," ",.)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm,"-"," ",.)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm,"/"," ",.)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm,"("," ",.)
replace mortality_full_name_norm = subinstr(mortality_full_name_norm,")"," ",.)
replace mortality_full_name_norm = ///
    subinstr(mortality_full_name_norm,char(39)," ",.)
replace mortality_full_name_norm = strtrim(itrim(mortality_full_name_norm))
generate str80 mortality_name_first = word(mortality_full_name_norm,1)
generate str80 mortality_name_last = ///
    word(mortality_full_name_norm,wordcount(mortality_full_name_norm))

merge m:1 nrn_clean using `"`cvd_nrn_map'"', keep(master match) ///
    gen(__l01_merge)
generate byte __l01_sex_contradiction = __l01_merge == 3 & ///
    !missing(mortality_sex_canonical,cvd_person_sex) & ///
    mortality_sex_canonical != cvd_person_sex
generate str6 __l01_nrn_yymmdd = substr(nrn_clean,1,6) if ///
    __death_nrn_valid == 1
generate str6 __cvd_dob_yymmdd = ""
replace __cvd_dob_yymmdd = string(mod(year(cvd_person_dob),100),"%02.0f") + ///
    string(month(cvd_person_dob),"%02.0f") + ///
    string(day(cvd_person_dob),"%02.0f") if !missing(cvd_person_dob)
generate byte __l01_dob_contradiction = __l01_merge == 3 & ///
    !missing(cvd_person_dob) & __l01_nrn_yymmdd != __cvd_dob_yymmdd
generate byte l01_person_match = __death_nrn_valid == 1 & ///
    __death_nrn_count == 1 & __l01_merge == 3 & ///
    cvd_nrn_sex_conflict == 0 & cvd_nrn_dob_conflict == 0 & ///
    __l01_sex_contradiction == 0 & __l01_dob_contradiction == 0
generate str60 linkage_status = "pending_invalid_mortality_nrn"
replace linkage_status = "pending_duplicate_mortality_nrn" if ///
    __death_nrn_valid == 1 & __death_nrn_count > 1
replace linkage_status = "pending_no_valid_cvd_nrn" if ///
    __death_nrn_valid == 1 & __death_nrn_count == 1 & __l01_merge == 1
replace linkage_status = "blocked_identifier_contradiction" if ///
    __death_nrn_valid == 1 & __death_nrn_count == 1 & __l01_merge == 3 & ///
    (cvd_nrn_sex_conflict == 1 | cvd_nrn_dob_conflict == 1 | ///
    __l01_sex_contradiction == 1 | __l01_dob_contradiction == 1)
replace linkage_status = "L01_unique_nrn" if l01_person_match == 1
generate byte l02_l03_permitted = l01_person_match == 0 & ///
    inlist(linkage_status,"pending_invalid_mortality_nrn", ///
    "pending_no_valid_cvd_nrn")
save `"`deaths_base'"', replace

* L02: one exact full-name, sex and DOB person proxy.
use `"`events_prepared'"', clear
keep if cvd_identity_conflict == 0 & cvd_full_name_norm != "" & ///
    !missing(cvd_sex_canonical,cvd_dob_resolved)
keep event_person_key cvd_full_name_norm cvd_sex_canonical cvd_dob_resolved
duplicates drop
rename cvd_full_name_norm mortality_full_name_norm
rename cvd_sex_canonical mortality_sex_canonical
rename cvd_dob_resolved mortality_dob_resolved
save `"`l02_candidates'"', replace

use `"`deaths_base'"', clear
keep if l02_l03_permitted == 1 & mortality_full_name_norm != "" & ///
    !missing(mortality_sex_canonical,mortality_dob_resolved)
keep __death_row_id mortality_full_name_norm mortality_sex_canonical ///
    mortality_dob_resolved
joinby mortality_full_name_norm mortality_sex_canonical ///
    mortality_dob_resolved using `"`l02_candidates'"'
bysort __death_row_id event_person_key: keep if _n == 1
bysort __death_row_id: generate long l02_candidate_n = _N
bysort __death_row_id: keep if _n == 1
rename event_person_key l02_event_person_key
keep __death_row_id l02_candidate_n l02_event_person_key
save `"`l02_summary'"', replace

* L03: exact boundary names in either order, sex, and exact DOB or age fallback.
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
    gen(__l02_premerge)
keep if missing(l02_candidate_n) | l02_candidate_n != 1
drop __l02_premerge l02_candidate_n l02_event_person_key
keep __death_row_id dth_date mortality_name_first mortality_name_last ///
    mortality_sex_canonical mortality_dob_resolved mortality_age_numeric agetxt
rename mortality_name_first l03_name_first
rename mortality_name_last l03_name_last
rename mortality_sex_canonical cvd_sex_canonical
joinby l03_name_first l03_name_last cvd_sex_canonical ///
    using `"`l03_candidates'"'
generate byte __l03_exact_dob = ///
    !missing(mortality_dob_resolved,cvd_dob_resolved) & ///
    mortality_dob_resolved == cvd_dob_resolved
generate double __cvd_age_at_death = agey + ///
    floor((dth_date-doe)/365.25) if !missing(agey,doe,dth_date) & doe<=dth_date
generate byte __l03_age_fallback = ///
    (missing(mortality_dob_resolved) | missing(cvd_dob_resolved)) & ///
    strtrim(agetxt) == "6" & ///
    !missing(mortality_age_numeric,__cvd_age_at_death) & ///
    abs(mortality_age_numeric-__cvd_age_at_death) <= 1
keep if __l03_exact_dob == 1 | __l03_age_fallback == 1
bysort __death_row_id event_person_key: egen byte __pair_exact_dob = ///
    max(__l03_exact_dob)
bysort __death_row_id event_person_key: keep if _n == 1
bysort __death_row_id: generate long l03_candidate_n = _N
bysort __death_row_id: keep if _n == 1
generate str12 l03_match_basis = "age_fallback"
replace l03_match_basis = "exact_dob" if __pair_exact_dob == 1
rename event_person_key l03_event_person_key
keep __death_row_id l03_candidate_n l03_event_person_key l03_match_basis
save `"`l03_summary'"', replace

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
replace linkage_status = "L02_full_name_dob_sex" if l02_person_match == 1
replace linkage_status = "L03_boundary_name_dob" if ///
    l03_person_match == 1 & l03_match_basis == "exact_dob"
replace linkage_status = "L03_boundary_name_age" if ///
    l03_person_match == 1 & l03_match_basis == "age_fallback"
replace linkage_status = "pending_l02_l03_no_unique_candidate" if ///
    l02_l03_permitted == 1 & final_person_match == 0
save `"`matched_deaths'"', replace

/*******************************************************************************
CONTROLLED SECTION 6 — 30-DAY LINKAGE AND SOURCE RECONCILIATION
DO NOT EDIT. These are private provisional audits, not approved publication
metrics. The earliest linked all-cause death 0--30 days after each index event
is retained. A source dod on an alive discharge never supplies death evidence.
*******************************************************************************/
use `"`matched_deaths'"', clear
keep if final_person_match == 1
keep record_id dth_date final_event_person_key final_linkage_rule_id
rename final_event_person_key event_person_key
quietly count
if r(N) == 0 {
    use `"`index_events'"', clear
    keep if _n == 0
    keep eid
    save `"`event_deaths'"', replace
}
else {
    joinby event_person_key using `"`index_events'"'
    generate int days_to_death = dth_date-doe
    keep if inrange(days_to_death,0,30)
    sort eid days_to_death dth_date record_id
    by eid: keep if _n == 1
    keep eid record_id dth_date days_to_death final_linkage_rule_id
    isid eid
    save `"`event_deaths'"', replace
}

use `"`index_events'"', clear
merge 1:1 eid using `"`event_deaths'"', keep(master match) gen(__death_merge)
generate byte linked_death_30 = __death_merge == 3
generate byte both_death_sources = linked_death_30 == 1 & hospital_death_30 == 1
generate byte linked_only_death = linked_death_30 == 1 & hospital_death_30 == 0
generate byte hospital_only_death = linked_death_30 == 0 & hospital_death_30 == 1
generate byte neither_death_source = linked_death_30 == 0 & hospital_death_30 == 0
generate byte inclusive_death_30 = linked_death_30 == 1 | hospital_death_30 == 1

label data "BNR private provisional annual index-event case-fatality linkage audit"
save "`review_root'/linked_index_events_private.dta", replace
preserve
    keep if hospital_only_death == 1
    keep eid event_year etype doe sadi dod dod_clean dodi ///
        hospital_death_30 linked_death_30 dod_extreme bad_recorded_dod
    save "`review_root'/hospital_only_deaths_private_review.dta", replace
restore
preserve
    collapse (sum) index_events=one linked_death_30 hospital_death_30 ///
        both_death_sources ///
        linked_only_death hospital_only_death neither_death_source ///
        inclusive_death_30 ///
        missing_discharge_status dod_extreme alive_dod_matches_dodi, ///
        by(event_year etype sex)
    generate double linked_case_fatality_pct = 100*linked_death_30/index_events
    generate double hospital_case_fatality_pct = 100*hospital_death_30/index_events
    generate double inclusive_case_fatality_pct = 100*inclusive_death_30/index_events
    format linked_case_fatality_pct hospital_case_fatality_pct ///
        inclusive_case_fatality_pct %6.2f
    sort event_year etype sex
    save "`review_root'/case_fatality_linkage_audit_by_year_type_sex.dta", replace
restore

* Linkage-rule counts contain no direct identifiers but remain private QA.
use `"`matched_deaths'"', clear
generate byte one_match = 1
collapse (sum) deaths=one_match, by(final_linkage_rule_id linkage_status)
gsort final_linkage_rule_id linkage_status
save "`review_root'/mortality_linkage_rule_audit.dta", replace

display as result "Input and deterministic linkage audit complete."
display as text "Review private files in `review_root'."
display as text "The linked rates are provisional QA only: no final numerator, disclosure-controlled aggregate dataset or PDF was created."
log close case_fatality

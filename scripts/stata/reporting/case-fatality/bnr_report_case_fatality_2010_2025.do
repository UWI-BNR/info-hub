/*******************************************************************************
BNR CASE FATALITY, 2010-2025 — PRIVATE STUDY FILE
Version: 0.4.1 (23 September 2026)

CURRENT STAGE: candidate metrics and disclosure-controlled public-data review.
The primary outcome is death within 30 days identified by either deterministic
mortality linkage or a valid hospital death record. Linked-only and in-hospital
measures are condition-specific secondary measures. This version calculates
crude estimates with Wilson 95% confidence intervals and age-standardised
predictive margins. It creates private review files and a suppressed candidate
public dataset, but deliberately stops before the final report PDF.

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
local study_id "cvd_case_fatality_2010_2025_v03"
local event_input "$BNR_PRIVATE/data/derived/cvd/y2026/m01/bnr_cvd_confidential_202601_v01.dta"
local death_input "$BNR_PRIVATE/data/raw/redcap/mortality/y2026/m07/bnr_mort_s1_202607.dta"
local mortality_release "2026-07"
local first_year 2010
local last_year 2025
local followup_end = mdy(12,31,`last_year') + 30

local stage_root "$BNR_PRIVATE/outputs/staging/reports/cvd"
local report_type_root "`stage_root'/case-fatality"
local study_root "`report_type_root'/`study_id'"
local review_root "`study_root'/review"
local candidate_root "`study_root'/candidate"

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
if `last_year' < `first_year' | `followup_end' < mdy(12,31,`last_year') + 30 {
    display as error "Invalid year range or follow-up end."
    exit 198
}
capture mkdir "$BNR_PRIVATE/outputs/staging/reports"
capture mkdir "$BNR_PRIVATE/outputs/staging/reports/cvd"
capture mkdir "`report_type_root'"
capture mkdir "`study_root'"
capture mkdir "`review_root'"
capture mkdir "`candidate_root'"
capture log close case_fatality
log using "`review_root'/case_fatality_input_audit.log", text replace name(case_fatality)
display as text "Private case-fatality input audit: `study_id'"
display as text "CVD input: `event_input'"
display as text "Death input: `death_input'"
display as text "Mortality release: `mortality_release'"
display as text "Eligible death follow-up ends: " %tdCCYY-NN-DD `followup_end'

tempfile events_source events_prepared cvd_nrn_map index_events ///
    deaths_source deaths_l01 deaths_base l02_candidates l02_summary ///
    l03_candidates l03_summary matched_deaths matched_death_keys ///
    eligible_pairs event_deaths hospital_only_events primary_annual ///
    primary_unknown_sex secondary_linked secondary_hospital ///
    crude_rows primary_adj secondary_adj candidate_base ///
    pri_sex_marg pri_all_marg pri_sex_part sec_marg model_results

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
quietly count if qa_dod == 0 & !missing(dth_date) & dth_date>`followup_end'
display as result "Valid deaths after the eligible follow-up window (audited but excluded from linkage): " r(N)
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
quietly count if bad_event_type == 1
display as result "Events outside the Heart/Stroke analysis types (excluded): " r(N)
keep if bad_event_type == 0

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
    inrange(dth_date,mdy(1,1,`first_year'),`followup_end')
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
DO NOT EDIT. The earliest linked all-cause death 0--30 days after each index
event is retained. The frozen primary outcome is positive evidence from either
the mortality linkage or a valid hospital death; missing evidence is not death.
*******************************************************************************/
use `"`matched_deaths'"', clear
keep if final_person_match == 1
keep record_id dth_date final_event_person_key final_linkage_rule_id ///
    linkage_status
rename final_event_person_key event_person_key
rename record_id death_record_id
rename dth_date cand_dod
rename final_linkage_rule_id link_rule
rename linkage_status link_basis
save `"`matched_death_keys'"', replace

quietly count
if r(N) == 0 {
    use `"`index_events'"', clear
    keep if _n == 0
    keep eid
    generate int dtd = .
    generate str3 link_rule = ""
    generate str60 link_basis = ""
    save `"`event_deaths'"', replace
}
else {
    joinby event_person_key using `"`index_events'"'
    generate int dtd = cand_dod-doe
    keep if inrange(dtd,0,30)

    * One certificate may legitimately sit within 30 days of more than one
    * annual Heart/Stroke index event. Audit that before selecting one death
    * record per event.
    bysort death_record_id eid: keep if _n == 1
    save `"`eligible_pairs'"', replace
    preserve
        bysort death_record_id: generate long linked_index_event_n = _N
        bysort death_record_id: egen byte linked_to_heart = max(etype==2)
        bysort death_record_id: egen byte linked_to_stroke = max(etype==1)
        bysort death_record_id: keep if _n == 1
        generate byte one_death = 1
        generate byte multiple_index_events = linked_index_event_n > 1
        generate byte both_event_types = linked_to_heart==1 & linked_to_stroke==1
        generate int death_year = year(cand_dod)
        collapse (sum) deaths=one_death linked_event_pairs=linked_index_event_n ///
            multiple_index_events both_event_types, by(death_year)
        sort death_year
        save "`review_root'/multiple_index_event_death_audit.dta", replace
    restore

    sort eid dtd cand_dod death_record_id
    by eid: keep if _n == 1
    keep eid death_record_id cand_dod dtd link_rule link_basis
    rename death_record_id record_id
    rename cand_dod dth_date
    isid eid
    save `"`event_deaths'"', replace
}

use `"`index_events'"', clear
merge 1:1 eid using `"`event_deaths'"', keep(master match) gen(__death_merge)
generate byte d_lnk30 = __death_merge == 3
generate byte d_hsp30 = hospital_death_30
generate byte d_both = d_lnk30 == 1 & d_hsp30 == 1
generate byte d_lnkonly = d_lnk30 == 1 & d_hsp30 == 0
generate byte d_hsponly = d_lnk30 == 0 & d_hsp30 == 1
generate byte d_neither = d_lnk30 == 0 & d_hsp30 == 0
generate byte d_pri30 = d_lnk30 == 1 | d_hsp30 == 1

assert d_pri30 == d_both + d_lnkonly + d_hsponly
assert one == d_pri30 + d_neither

label data "BNR private annual index-event case-fatality diagnostic"
save "`review_root'/linked_index_events_private.dta", replace
preserve
    keep if d_hsponly == 1
    save `"`hospital_only_events'"', replace
    keep eid event_year etype sex doe sadi dod dod_clean dodi ///
        event_person_key_source nrn_valid nrn_blank nrn_placeholder ///
        d_hsp30 d_lnk30 dod_extreme bad_recorded_dod
    save "`review_root'/hospital_only_deaths_private_review.dta", replace
restore

* Among actual linked 30-day outcomes, show reliance on L01/L02/L03.
preserve
    keep if d_lnk30 == 1
    generate byte one_linked_outcome = 1
    collapse (sum) linked_deaths=one_linked_outcome, ///
        by(event_year etype sex link_rule link_basis)
    sort event_year etype sex link_rule link_basis
    save "`review_root'/linked_outcome_rule_by_year_type_sex.dta", replace
restore

* Preserve the exact 0--30-day shape; the file is aggregate but remains private.
preserve
    keep if d_lnk30 == 1
    generate byte one_linked_outcome = 1
    collapse (sum) linked_deaths=one_linked_outcome, ///
        by(event_year etype sex dtd link_rule link_basis)
    sort event_year etype sex dtd link_rule link_basis
    save "`review_root'/linked_time_to_death_audit.dta", replace
restore

* Private annual source-reconciliation table. Diagnostic components must not
* enter the public payload because their differences expose small counts.
preserve
    collapse (sum) index_events=one linked_death_30=d_lnk30 ///
        hospital_death_30=d_hsp30 both_death_sources=d_both ///
        linked_only_death=d_lnkonly hospital_only_death=d_hsponly ///
        neither_death_source=d_neither primary_death_30=d_pri30 ///
        missing_discharge_status dod_extreme alive_dod_matches_dodi, ///
        by(event_year etype sex)
    generate double primary_case_fatality_pct = 100*primary_death_30/index_events
    generate double linked_case_fatality_pct = 100*linked_death_30/index_events
    generate double hospital_case_fatality_pct = 100*hospital_death_30/index_events
    format primary_case_fatality_pct linked_case_fatality_pct ///
        hospital_case_fatality_pct %6.2f
    sort event_year etype sex
    save "`review_root'/case_fatality_linkage_audit_by_year_type_sex.dta", replace
restore

* Explain hospital-only cases without releasing direct identifiers. A matched
* death outside the 30-day window is distinguished from no deterministic
* mortality-person match; neither category is silently treated as a death link.
use `"`hospital_only_events'"', clear
joinby event_person_key using `"`matched_death_keys'"', ///
    unmatched(master) _merge(__hospital_only_merge)
generate byte any_deterministic_death_match = __hospital_only_merge == 3
generate int candidate_days_to_death = cand_dod-doe if ///
    any_deterministic_death_match == 1
assert !inrange(candidate_days_to_death,0,30) if ///
    any_deterministic_death_match == 1
bysort eid: egen byte __any_person_match = max(any_deterministic_death_match)
bysort eid: egen int nearest_later_death_days = ///
    min(cond(candidate_days_to_death>30,candidate_days_to_death,.))
bysort eid: egen int nearest_prior_death_days = ///
    max(cond(candidate_days_to_death<0,candidate_days_to_death,.))
bysort eid: keep if _n == 1
generate str44 hospital_only_reason = "no_deterministic_death_match"
replace hospital_only_reason = "insufficient_or_conflicting_event_identity" if ///
    __any_person_match == 0 & event_person_key_source == "E"
replace hospital_only_reason = "matched_death_after_30_days" if ///
    __any_person_match == 1 & !missing(nearest_later_death_days)
replace hospital_only_reason = "matched_death_before_event_only" if ///
    __any_person_match == 1 & missing(nearest_later_death_days) & ///
    !missing(nearest_prior_death_days)
generate byte one_hospital_only = 1
collapse (sum) hospital_only_deaths=one_hospital_only, ///
    by(event_year etype sex event_person_key_source hospital_only_reason)
sort event_year etype sex event_person_key_source hospital_only_reason
save "`review_root'/hospital_only_linkage_audit_by_year_type_sex.dta", replace

/*******************************************************************************
CONTROLLED SECTION 7 — CRUDE CONDITION-SPECIFIC MEASURES
DO NOT EDIT. This section builds the complete table that a public user could
compare. The primary series remains annual by Heart/Stroke and sex. Each
secondary series is now also Heart/Stroke-specific, but uses the agreed broad
periods and both sexes combined. Keeping the two conditions separate avoids
the ambiguous pooled denominator discussed during methodological review.
*******************************************************************************/
use "`review_root'/linked_index_events_private.dta", clear

* Step 7.1: audit unknown sex before constructing the displayed sex strata.
* The combined-sex result can reveal an unknown-sex count when compared with
* the women and men rows. These private counts therefore participate in the
* disclosure decision even though they never enter the candidate public file.
preserve
    generate byte sex_unk = !inlist(sex,1,2)
    generate byte sex_unk_d = sex_unk*d_pri30
    generate byte sex_unk_n = sex_unk*(1-d_pri30)
    collapse (sum) unk_den=sex_unk unk_num=sex_unk_d ///
        unk_noncase=sex_unk_n, by(event_year etype)
    save `"`primary_unknown_sex'"', replace
restore

* Step 7.2: calculate annual primary counts for women and men. These rows use
* only valid sex codes. The both-sex row below uses every eligible index event.
preserve
    keep if inlist(sex,1,2)
    collapse (sum) denominator=one numerator=d_pri30, ///
        by(event_year etype sex)
    generate int period_start = event_year
    generate int period_end = event_year
    generate str9 period_label = string(event_year,"%04.0f")
    generate str12 time_basis = "annual"
    generate str24 measure_id = "primary_30d"
    generate double comp_n = .
    generate double shared_n = .
    generate str40 quality_flag = ""
    replace quality_flag = "2024_abstraction_completeness" if ///
        event_year == 2024
    save `"`primary_annual'"', replace
restore
preserve
    collapse (sum) denominator=one numerator=d_pri30, ///
        by(event_year etype)
    generate byte sex = 0
    generate int period_start = event_year
    generate int period_end = event_year
    generate str9 period_label = string(event_year,"%04.0f")
    generate str12 time_basis = "annual"
    generate str24 measure_id = "primary_30d"
    generate double comp_n = .
    generate double shared_n = .
    generate str40 quality_flag = ""
    replace quality_flag = "2024_abstraction_completeness" if ///
        event_year == 2024
    append using `"`primary_annual'"'
    merge m:1 event_year etype using `"`primary_unknown_sex'"', nogen
    save `"`primary_annual'"', replace
restore

* Step 7.3: assign the agreed broad periods once at record level. Secondary
* measures retain etype in the collapse, so Heart and Stroke remain distinct.
generate byte per_id = .
replace per_id = 1 if inrange(event_year,2010,2015)
replace per_id = 2 if inrange(event_year,2016,2020)
replace per_id = 3 if inrange(event_year,2021,2023)
replace per_id = 4 if inrange(event_year,2024,2025)
generate int period_start = .
generate int period_end = .
replace period_start = 2010 if per_id == 1
replace period_end   = 2015 if per_id == 1
replace period_start = 2016 if per_id == 2
replace period_end   = 2020 if per_id == 2
replace period_start = 2021 if per_id == 3
replace period_end   = 2023 if per_id == 3
replace period_start = 2024 if per_id == 4
replace period_end   = 2025 if per_id == 4
generate byte sex_unk = !inlist(sex,1,2)

* Step 7.4: calculate linked-death secondary counts separately for Heart and
* Stroke. comp_n is the hospital-only component. Publishing a linked count when
* comp_n is 1--5 would disclose that small component after subtraction from the
* primary count, so comp_n is part of the later suppression test.
preserve
    collapse (sum) denominator=one numerator=d_lnk30 ///
        comp_n=d_hsponly shared_n=d_both unk_den=sex_unk, ///
        by(per_id period_start period_end etype)
    generate int event_year = .
    generate byte sex = 0
    generate str9 period_label = string(period_start,"%04.0f") + "-" + ///
        string(period_end,"%04.0f")
    generate str12 time_basis = "period"
    generate str24 measure_id = "linked_30d"
    generate str40 quality_flag = ""
    replace quality_flag = "2024_abstraction_completeness" if per_id == 4
    save `"`secondary_linked'"', replace
restore

* Step 7.5: calculate in-hospital secondary counts at the same condition and
* period grain. comp_n is now the linked-only component. Historical source
* defects make 2010--15 and 2021--23 unsuitable for public release, although
* their crude counts remain in the private audit for diagnosis.
preserve
    collapse (sum) denominator=one numerator=d_hsp30 ///
        comp_n=d_lnkonly shared_n=d_both unk_den=sex_unk, ///
        by(per_id period_start period_end etype)
    generate int event_year = .
    generate byte sex = 0
    generate str9 period_label = string(period_start,"%04.0f") + "-" + ///
        string(period_end,"%04.0f")
    generate str12 time_basis = "period"
    generate str24 measure_id = "in_hospital_30d"
    generate str40 quality_flag = ""
    replace quality_flag = "extreme_dod_values" if per_id == 1
    replace quality_flag = "2023_missing_discharge_status" if per_id == 3
    replace quality_flag = "2024_abstraction_completeness" if per_id == 4
    save `"`secondary_hospital'"', replace
restore

* Step 7.6: join the three crude count layouts. Wilson intervals are calculated
* directly from each binomial numerator and denominator; no normal approximation
* is used. The unrounded values are retained in private review data.
use `"`primary_annual'"', clear
append using `"`secondary_linked'"' `"`secondary_hospital'"'
generate double noncase_n = denominator-numerator
local z95 = invnormal(.975)
generate double __p = numerator/denominator
generate double __w = 1 + (`z95'^2)/denominator
generate double estimate = 100*__p
generate double ci_lower = 100*max(0, ///
    (__p + (`z95'^2)/(2*denominator) - ///
    `z95'*sqrt((__p*(1-__p)/denominator) + ///
    (`z95'^2)/(4*denominator^2)))/__w)
generate double ci_upper = 100*min(1, ///
    (__p + (`z95'^2)/(2*denominator) + ///
    `z95'*sqrt((__p*(1-__p)/denominator) + ///
    (`z95'^2)/(4*denominator^2)))/__w)
drop __p __w
generate str20 standardisation = "crude"

/*******************************************************************************
CONTROLLED SECTION 8 — COMPLETE-PAYLOAD DISCLOSURE CONTROL
DO NOT EDIT. Suppression is decided before crude and adjusted rows are split.
The checks include direct cells, complements, overlaps and unknown-sex cells.
This prevents a safe-looking row from revealing a count of 1--5 when combined
with another released row. The private audit retains all diagnostic counts;
the candidate public dataset blanks every protected value.
*******************************************************************************/
generate byte small_den = inrange(denominator,1,5)
generate byte small_num = inrange(numerator,1,5)
generate byte small_comp = inrange(comp_n,1,5)
generate byte small_shared = inrange(shared_n,1,5)
generate byte small_noncase = inrange(noncase_n,1,5)
generate byte small_unk = inrange(unk_den,1,5) | ///
    inrange(unk_num,1,5) | inrange(unk_noncase,1,5)

generate str32 release_status = "release"
replace release_status = "not_release_source_quality" if ///
    measure_id == "in_hospital_30d" & inlist(per_id,1,3)
replace release_status = "suppress_small_count" if ///
    release_status == "release" & ///
    (small_den | small_num | small_comp | small_shared | small_noncase)
replace release_status = "suppress_small_count" if ///
    release_status == "release" & measure_id == "primary_30d" & ///
    sex == 0 & small_unk
replace release_status = "suppress_small_count" if ///
    release_status == "release" & time_basis == "period" & ///
    sex == 0 & small_unk
generate byte cand_release = release_status == "release"

* The assertions make accidental release of any directly or indirectly small
* cell a hard error rather than a warning hidden in the log.
quietly count if cand_release & ///
    (small_den | small_num | small_comp | small_shared | small_noncase)
assert r(N) == 0
quietly count if cand_release & measure_id == "primary_30d" & ///
    sex == 0 & small_unk
assert r(N) == 0
quietly count if cand_release & time_basis == "period" & ///
    sex == 0 & small_unk
assert r(N) == 0

order measure_id standardisation time_basis period_label period_start ///
    period_end event_year etype sex denominator numerator estimate ///
    ci_lower ci_upper comp_n shared_n noncase_n unk_den unk_num ///
    unk_noncase release_status quality_flag cand_release
sort measure_id period_start event_year etype sex
save "`review_root'/candidate_public_layout_disclosure_audit.dta", replace
save `"`candidate_base'"', replace
save `"`crude_rows'"', replace

/*******************************************************************************
CONTROLLED SECTION 9 — AGE COMPLETENESS AND AGE-STANDARDISED ESTIMATES
DO NOT EDIT. Ages from 0 through 110 years are accepted. Valid ages are grouped
as <55, 55--64, 65--74, 75--84 and 85+. Separate Heart and Stroke logistic
models estimate predictive margins over each condition's pooled valid-age
distribution. Primary models include year, sex, year-by-sex and age group.
Secondary models use broad period and age group. Clustered standard errors allow
the same deterministic person proxy to contribute an index event in more than
one year. These are model-based marginal estimates with delta-method 95% CIs.
*******************************************************************************/
use "`review_root'/linked_index_events_private.dta", clear
generate byte age_miss = missing(agey)
generate byte age_bad = !missing(agey) & !inrange(agey,0,110)
generate byte age_ok = inrange(agey,0,110)
generate byte age_grp = .
replace age_grp = 1 if age_ok & agey < 55
replace age_grp = 2 if age_ok & inrange(agey,55,64)
replace age_grp = 3 if age_ok & inrange(agey,65,74)
replace age_grp = 4 if age_ok & inrange(agey,75,84)
replace age_grp = 5 if age_ok & agey >= 85

* Step 9.1: preserve compact private QA tables. They show exactly which records
* enter the models and whether missing or impossible age values cluster in a
* particular year, condition or sex stratum.
preserve
    collapse (sum) events=one age_missing=age_miss age_invalid=age_bad ///
        age_complete=age_ok primary_deaths=d_pri30, ///
        by(event_year etype sex)
    sort event_year etype sex
    save "`review_root'/age_model_audit_by_year_type_sex.dta", replace
restore
preserve
    keep if age_ok
    collapse (sum) events=one primary_deaths=d_pri30, ///
        by(etype age_grp)
    sort etype age_grp
    save "`review_root'/age_group_reference_audit.dta", replace
restore

* Step 9.2: fit primary models separately within each condition. The sex-specific
* model contains year, sex, their interaction and age group; margins fix year and
* sex while averaging over one common age distribution. A second combined-sex
* model contains year and age group only, so its margins standardise age without
* also imposing a common sex distribution. A missing margin later stops release.
foreach t in 1 2 {
    use "`review_root'/linked_index_events_private.dta", clear
    generate byte age_ok = inrange(agey,0,110)
    generate byte age_grp = .
    replace age_grp = 1 if age_ok & agey < 55
    replace age_grp = 2 if age_ok & inrange(agey,55,64)
    replace age_grp = 3 if age_ok & inrange(agey,65,74)
    replace age_grp = 4 if age_ok & inrange(agey,75,84)
    replace age_grp = 5 if age_ok & agey >= 85
    keep if etype == `t'
    capture drop __cf_pid
    egen long __cf_pid = group(event_person_key)
    quietly logit d_pri30 i.event_year##i.sex i.age_grp if ///
        age_ok & inlist(sex,1,2), vce(cluster __cf_pid)
    if e(converged) != 1 {
        display as error "Primary sex-specific model did not converge: etype `t'."
        exit 430
    }
    quietly margins, at(event_year=(2010(1)2025) sex=(1 2)) ///
        level(95) saving(`"`pri_sex_marg'"', replace)
    quietly logit d_pri30 i.event_year i.age_grp if age_ok, ///
        vce(cluster __cf_pid)
    if e(converged) != 1 {
        display as error "Primary combined-sex model did not converge: etype `t'."
        exit 430
    }
    quietly margins, at(event_year=(2010(1)2025)) ///
        level(95) saving(`"`pri_all_marg'"', replace)

    use `"`pri_sex_marg'"', clear
    keep _at1 _at2 _margin _ci_lb _ci_ub
    rename _at1 event_year
    rename _at2 sex
    generate byte etype = `t'
    generate int period_start = event_year
    generate int period_end = event_year
    generate str24 measure_id = "primary_30d"
    rename _margin estimate
    rename _ci_lb ci_lower
    rename _ci_ub ci_upper
    replace estimate = 100*estimate
    replace ci_lower = 100*ci_lower
    replace ci_upper = 100*ci_upper
    save `"`pri_sex_part'"', replace

    use `"`pri_all_marg'"', clear
    keep _at1 _margin _ci_lb _ci_ub
    rename _at1 event_year
    generate byte sex = 0
    generate byte etype = `t'
    generate int period_start = event_year
    generate int period_end = event_year
    generate str24 measure_id = "primary_30d"
    rename _margin estimate
    rename _ci_lb ci_lower
    rename _ci_ub ci_upper
    replace estimate = 100*estimate
    replace ci_lower = 100*ci_lower
    replace ci_upper = 100*ci_upper
    append using `"`pri_sex_part'"'
    if `t' == 1 save `"`primary_adj'"', replace
    else {
        append using `"`primary_adj'"'
        save `"`primary_adj'"', replace
    }
}

* Step 9.3: fit the two condition-specific secondary models. Linked mortality
* uses all four periods. In-hospital modelling uses only 2016--20 and 2024--25;
* excluded source-quality periods cannot influence estimates that may be shown.
local first_secondary = 1
foreach t in 1 2 {
    foreach out in d_lnk30 d_hsp30 {
        if "`out'" == "d_lnk30" {
            local mid "linked_30d"
            local mif "inrange(per_id,1,4)"
            local ats "1 2 3 4"
        }
        else {
            local mid "in_hospital_30d"
            local mif "inlist(per_id,2,4)"
            local ats "2 4"
        }

        use "`review_root'/linked_index_events_private.dta", clear
        generate byte age_ok = inrange(agey,0,110)
        generate byte age_grp = .
        replace age_grp = 1 if age_ok & agey < 55
        replace age_grp = 2 if age_ok & inrange(agey,55,64)
        replace age_grp = 3 if age_ok & inrange(agey,65,74)
        replace age_grp = 4 if age_ok & inrange(agey,75,84)
        replace age_grp = 5 if age_ok & agey >= 85
        generate byte per_id = .
        replace per_id = 1 if inrange(event_year,2010,2015)
        replace per_id = 2 if inrange(event_year,2016,2020)
        replace per_id = 3 if inrange(event_year,2021,2023)
        replace per_id = 4 if inrange(event_year,2024,2025)
        keep if etype == `t'
        capture drop __cf_pid
        egen long __cf_pid = group(event_person_key)
        quietly logit `out' i.per_id i.age_grp if age_ok & `mif', ///
            vce(cluster __cf_pid)
        if e(converged) != 1 {
            display as error "Secondary model did not converge: `mid', etype `t'."
            exit 430
        }
        quietly margins, at(per_id=(`ats')) ///
            level(95) saving(`"`sec_marg'"', replace)

        use `"`sec_marg'"', clear
        keep _at1 _margin _ci_lb _ci_ub
        rename _at1 per_id
        generate byte etype = `t'
        generate byte sex = 0
        generate int event_year = .
        generate int period_start = .
        generate int period_end = .
        replace period_start = 2010 if per_id == 1
        replace period_end   = 2015 if per_id == 1
        replace period_start = 2016 if per_id == 2
        replace period_end   = 2020 if per_id == 2
        replace period_start = 2021 if per_id == 3
        replace period_end   = 2023 if per_id == 3
        replace period_start = 2024 if per_id == 4
        replace period_end   = 2025 if per_id == 4
        generate str24 measure_id = "`mid'"
        rename _margin estimate
        rename _ci_lb ci_lower
        rename _ci_ub ci_upper
        replace estimate = 100*estimate
        replace ci_lower = 100*ci_lower
        replace ci_upper = 100*ci_upper
        if `first_secondary' == 1 {
            save `"`secondary_adj'"', replace
            local first_secondary = 0
        }
        else {
            append using `"`secondary_adj'"'
            save `"`secondary_adj'"', replace
        }
    }
}

use `"`primary_adj'"', clear
append using `"`secondary_adj'"'
keep measure_id period_start period_end event_year etype sex ///
    estimate ci_lower ci_upper
isid measure_id period_start period_end etype sex
sort measure_id period_start etype sex
save `"`model_results'"', replace
save "`review_root'/age_standardised_model_results.dta", replace

/*******************************************************************************
CONTROLLED SECTION 10 — CANDIDATE PUBLIC DATASET AND METADATA
DO NOT EDIT. Adjusted rows inherit the disclosure and source-quality decision
from the matching crude row. Counts describe the observed cohort; an adjusted
estimate is a model-based margin and is not obtained by dividing those counts.
Protected rows remain present so users can distinguish suppression from absence,
but all counts, estimates and confidence limits are blanked before export.
*******************************************************************************/
use `"`candidate_base'"', clear
drop estimate ci_lower ci_upper standardisation
generate str20 standardisation = "age_standardised"
merge 1:1 measure_id period_start period_end event_year etype sex ///
    using `"`model_results'"', keep(master match) nogen
quietly count if release_status == "release" & missing(estimate)
assert r(N) == 0
save `"`model_results'"', replace

use `"`crude_rows'"', clear
append using `"`model_results'"'
generate str6 event_type = ""
replace event_type = "Stroke" if etype == 1
replace event_type = "Heart" if etype == 2
generate str10 sex_group = "Both"
replace sex_group = "Women" if sex == 1
replace sex_group = "Men" if sex == 2

* Retain only fields intended for external interpretation, then blank every
* protected numeric result. Private complement and linkage diagnostics are not
* copied to the candidate public payload.
keep measure_id standardisation time_basis period_label period_start ///
    period_end event_type sex_group denominator numerator estimate ///
    ci_lower ci_upper release_status quality_flag
rename denominator events
rename numerator deaths
rename estimate estimate_pct
rename ci_lower ci_lower_pct
rename ci_upper ci_upper_pct
replace events = . if release_status != "release"
replace deaths = . if release_status != "release"
replace estimate_pct = . if release_status != "release"
replace ci_lower_pct = . if release_status != "release"
replace ci_upper_pct = . if release_status != "release"
quietly count if release_status != "release" & ///
    (!missing(events) | !missing(deaths) | !missing(estimate_pct) | ///
    !missing(ci_lower_pct) | !missing(ci_upper_pct))
assert r(N) == 0
quietly count if release_status == "release" & ///
    missing(events,deaths,estimate_pct,ci_lower_pct,ci_upper_pct)
assert r(N) == 0
assert event_type != "" & inlist(sex_group,"Both","Women","Men")
replace estimate_pct = round(estimate_pct,.01)
replace ci_lower_pct = round(ci_lower_pct,.01)
replace ci_upper_pct = round(ci_upper_pct,.01)
format events deaths %12.0f
format estimate_pct ci_lower_pct ci_upper_pct %6.2f
sort measure_id standardisation period_start event_type sex_group
label data "BNR candidate public case-fatality metrics; not approved for release"
save "`candidate_root'/case_fatality_metrics_candidate.dta", replace
export delimited using ///
    "`candidate_root'/case_fatality_metrics_candidate.csv", replace

* The candidate metadata travels with the dataset during review. It records the
* cohort overlap explicitly: one person can contribute once to each separate
* Heart and Stroke series, and the same later all-cause death can therefore be
* an outcome in both series. It must not be interpreted as two deaths nationally.
file open meta using "`candidate_root'/case_fatality_metadata_candidate.txt", ///
    write text replace
file write meta "BNR case-fatality candidate public dataset" _n
file write meta "Status: private review candidate; not approved for publication." _n _n
file write meta ///
    "Primary measure: all-cause death within 30 days of the first annual " ///
    "index event, identified by deterministic mortality linkage or a valid " ///
    "hospital death record." _n
file write meta ///
    "Secondary measures: deterministic linked all-cause death within 30 " ///
    "days; and death recorded in hospital within 30 days. Secondary rows " ///
    "are condition-specific and use broad periods." _n
file write meta ///
    "Cohorts: Heart and Stroke are separate disease-specific cohorts. A " ///
    "person can contribute one index event per year to each cohort. A " ///
    "subsequent all-cause death can therefore be an outcome in both series; " ///
    "this is not a count of distinct national deaths." _n
file write meta "Crude uncertainty: Wilson 95% binomial confidence intervals." _n
file write meta ///
    "Age-standardisation: logistic predictive margins using age groups <55, " ///
    "55-64, 65-74, 75-84 and 85+. Primary sex-specific models are separate " ///
    "by condition and include year, sex, year-by-sex and age group; combined-" ///
    "sex models include year and age group. Secondary models are separate by " ///
    "condition and include period and age group. Records with missing or " ///
    "invalid age are excluded. Delta-method 95% confidence intervals are " ///
    "reported." _n
file write meta ///
    "Suppression: all numeric outputs are blank when a direct cell, " ///
    "complementary source-only cell, shared-source cell, noncase cell or " ///
    "derivable unknown-sex cell is 1-5. Adjusted rows inherit the crude-row " ///
    "decision." _n
file write meta ///
    "Quality flags: 2024 is flagged for abstraction completeness. In-hospital " ///
    "estimates for 2010-15 and 2021-23 are not released because of historical " ///
    "source-quality limitations." _n
file write meta ///
    "Counts on age-standardised rows describe the observed cohort; the " ///
    "percentage is model-based and is not deaths divided by events." _n
file close meta

* Linkage-rule counts contain no direct identifiers but remain private QA.
use `"`matched_deaths'"', clear
generate byte one_match = 1
collapse (sum) deaths=one_match, by(final_linkage_rule_id linkage_status)
gsort final_linkage_rule_id linkage_status
save "`review_root'/mortality_linkage_rule_audit.dta", replace

display as result "Candidate metrics and disclosure-controlled dataset complete."
display as text "Private review files: `review_root'"
display as text "Candidate public-data files: `candidate_root'"
display as text "No final report PDF was created; numerical and disclosure review remains required."
log close case_fatality

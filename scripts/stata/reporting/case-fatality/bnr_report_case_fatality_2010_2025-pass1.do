/*******************************************************************************
BNR CASE FATALITY, 2010-2025 — PRIVATE STUDY FILE
Version: 0.1.0 (23 September 2026)

CURRENT STAGE: input and hospital-death audit only. This file intentionally
stops before person linkage, case-fatality calculation, disclosure decisions,
PDF construction, approval, and publication. Extend this same file after the
private review; do not create a separate operational workflow.

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
local death_input "$BNR_PRIVATE/data/raw/redcap/mortality/y2026/m01/bnr_mort_s1_202601.dta"
local first_year 2010
local last_year 2025
local death_cutoff = mdy(1, 31, 2026)

local stage_root "$BNR_PRIVATE/outputs/staging"
local brief_root "`stage_root'/briefings"
local study_root "`brief_root'/`study_id'"
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
capture mkdir "`stage_root'"
capture mkdir "`brief_root'"
capture mkdir "`study_root'"
capture mkdir "`review_root'"
capture log close case_fatality
log using "`review_root'/case_fatality_input_audit.log", text replace name(case_fatality)
display as text "Private case-fatality input audit: `study_id'"
display as text "CVD input: `event_input'"
display as text "Death input: `death_input'"
display as text "Death extract cut-off: " %tdCCYY-NN-DD `death_cutoff'

/*******************************************************************************
CONTROLLED SECTION 2 — CVD EVENT AND HOSPITAL-DEATH AUDIT
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
generate int event_year = year(doe)
generate byte one = 1
generate byte bad_event_type = !inlist(etype,1,2)
generate byte bad_hospital_date = !missing(dod) & dod < doe
generate byte hospital_death_30 = !missing(dod) & inrange(dod-doe,0,30)
generate byte hospital_death_later = !missing(dod) & dod-doe > 30
generate byte missing_hospital_date = missing(dod)
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

* Never write direct identity fields or source values into these review files.
preserve
    keep if bad_hospital_date | bad_event_type
    keep eid event_year etype doe dod dodi sadi bad_hospital_date bad_event_type
    save "`review_root'/hospital_date_exceptions.dta", replace
restore
preserve
    keep if !missing(dod) | !missing(sadi)
    keep eid event_year etype doe dod dodi sadi hospital_death_30 ///
        hospital_death_later bad_hospital_date
    save "`review_root'/hospital_outcome_review.dta", replace
restore
preserve
    collapse (sum) events=one hospital_death_30 hospital_death_later ///
        bad_hospital_date bad_event_type missing_hospital_date ///
        missing_discharge_status missing_age missing_sex nrn_blank ///
        nrn_placeholder nrn_other_invalid nrn_valid, by(event_year etype sex)
    sort event_year etype sex
    save "`review_root'/cvd_event_audit_by_year_type_sex.dta", replace
restore
preserve
    collapse (sum) events=one hospital_death_30 ///
        missing_hospital_date, by(event_year etype sadi)
    sort event_year etype sadi
    save "`review_root'/discharge_status_by_year_type.dta", replace
restore

display as text "Hospital discharge-status codes and labels (verify before defining deceased):"
tabulate sadi, missing
display as text "Hospital discharge status by valid death-date category:"
tabulate sadi hospital_death_30, missing
display as text "Hospital date exceptions by year:"
quietly count if bad_hospital_date
if r(N) > 0 tabulate event_year if bad_hospital_date
else display as result "None found."

/*******************************************************************************
CONTROLLED SECTION 3 — ALL-DEATHS EXTRACT AUDIT
DO NOT EDIT. Mortality Step 2 cause classification is deliberately unused.
*******************************************************************************/
use "`death_input'", clear
foreach field in record_id dth_date reg_date qa_dod qa_dup nrn pname sex {
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
generate byte invalid_death_date = missing(dth_date)
generate byte bad_registration_date = missing(reg_date)
generate byte registration_before_death = !missing(reg_date,dth_date) & reg_date<dth_date
generate int registration_lag = reg_date-dth_date if !missing(reg_date,dth_date)
generate byte registration_over_30 = registration_lag>30 if !missing(registration_lag)
generate byte registration_over_90 = registration_lag>90 if !missing(registration_lag)
generate byte flagged_duplicate = qa_dup==1
generate byte missing_death_nrn = strtrim(nrn)==""
quietly count if invalid_death_date
display as result "Mortality records with missing or invalid death date: " r(N)
quietly count if !missing(dth_date) & dth_date>`death_cutoff'
if r(N) {
    display as error "Deaths extend past the selected mortality release cut-off."
    log close case_fatality
    exit 459
}
preserve
    keep if invalid_death_date | registration_before_death | flagged_duplicate
    keep record_id dth_date reg_date invalid_death_date ///
        registration_before_death flagged_duplicate
    save "`review_root'/mortality_date_exceptions.dta", replace
restore
preserve
    keep if inrange(death_year,`first_year',`last_year'+1)
    collapse (sum) deaths=one invalid_death_date bad_registration_date ///
        registration_before_death registration_over_30 ///
        registration_over_90 flagged_duplicate missing_death_nrn, by(death_year)
    sort death_year
    save "`review_root'/mortality_audit_by_death_year.dta", replace
restore

display as result "Input audit complete. Review private files in `review_root'."
display as text "No person matching, final numerator, aggregate public dataset or PDF was created."
log close case_fatality

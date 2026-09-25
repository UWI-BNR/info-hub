/*******************************************************************************
BNR CASE FATALITY, 2010-2025 — PRIVATE STUDY FILE
Version: 0.6.2 (24 September 2026)

CURRENT STAGE: candidate metrics and disclosure-controlled public-data review.
The primary outcome is death within 30 days identified by either deterministic
mortality linkage or a valid hospital death record. Linked-only and in-hospital
measures are condition-specific secondary measures. This version calculates
crude estimates with Wilson 95% confidence intervals and age-standardised
predictive margins. It creates private review files, a disclosure-controlled
candidate public dataset and the finished one-off report PDF. The PDF presents
annual primary All-CVD, Heart and Stroke results; secondary measures remain
available in the candidate public dataset for possible later use. A controlled
presentation-only helper adds the same running page furniture used by the BNR
annual report. It does not access data or calculate report measures.

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
local mortality_release "2026-07"
local first_year 2010
local last_year 2025
local followup_end = mdy(12,31,`last_year') + 30

local stage_root "$BNR_PRIVATE/outputs/staging/reports/cvd"
local report_type_root "`stage_root'/case-fatality"
local study_root "`report_type_root'/`study_id'"
local review_root "`study_root'/review"
local candidate_root "`study_root'/candidate"
local figure_root "`candidate_root'/figures"
local report_pdf "`candidate_root'/bnr_cvd_case_fatality_2010_2025.pdf"
local report_body_pdf "`candidate_root'/bnr_cvd_case_fatality_2010_2025_body.pdf"
local pdf_helper "$BNR_REPO/scripts/python/stamp_annual_report_pdf.py"
local pdf_python "$BNR_REPO/venv-info-hub/Scripts/python.exe"
local pdf_logo "$BNR_REPO/site/assets/images/uwi-crestonly-20p.png"
local cf_equation "$BNR_REPO/scripts/stata/reporting/assets/case_fatality_equation.png"
local info_hub_web "uwi-bnr.github.io/info-hub/"

/*******************************************************************************
EDITABLE SECTION 2 - YEAR-SPECIFIC REPORT INTERPRETATION
Review and rewrite these four passages for every new report year. They interpret
the current results for decision-makers and health professionals; they must not
be carried forward automatically. Keep methods and data-quality explanations on
the final Methods page rather than in these passages.
*******************************************************************************/
local note_brief = "In 2025, about three in ten CVD events were followed by death within 30 days. " + ///
    "The heart estimate was higher than the stroke estimate, although the uncertainty ranges overlap. " + ///
    "Women and men had similar overall crude results. Age adjustment made little difference to the combined-sex estimates, so age mix did not materially change the overall 2025 result."

local note_cvd = "The 2025 crude result was similar for women and men. After age adjustment, the estimate was slightly higher for men, suggesting that differences in age mix affect the sex comparison somewhat; the uncertainty ranges still overlap. " + ///
    "The overall 2025 estimate returned to the range seen in 2021-2023. The apparent drop in 2024 should be interpreted cautiously; decisions should consider the multi-year pattern rather than one annual point."

local note_heart = "Heart case fatality in 2025 was higher than Stroke case fatality and remained roughly one in three events. " + ///
    "The crude estimate was higher for women than men, but this gap narrowed after age adjustment and the uncertainty ranges overlap. " + ///
    "Heart estimates vary more from year to year than Stroke estimates, partly reflecting smaller event numbers; decisions should therefore consider the multi-year pattern rather than one annual point."

local note_stroke = "In 2025, crude stroke case fatality was almost the same for women and men. Age adjustment produced a somewhat higher estimate for men, but the uncertainty ranges overlap. " + ///
    "The combined estimate was below 2023 and within the broad range seen across the series. The annual pattern does not show a consistent year-on-year improvement. Continued monitoring remains important."

/*******************************************************************************
CONTROLLED SECTION 1 — INPUT CONTRACT AND PRIVATE FOLDERS
DO NOT EDIT for a routine study update.
*******************************************************************************/
foreach path_name in BNR_PRIVATE BNR_STATA BNR_REPO {
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
capture mkdir "`figure_root'"
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
    eligible_pairs event_deaths hospital_only_events cvd_index_events ///
    primary_events primary_annual ///
    primary_unknown_sex secondary_linked secondary_hospital ///
    crude_rows primary_adj secondary_adj candidate_base ///
    pri_sex_marg pri_all_marg pri_sex_part sec_marg model_results ///
    model_sample_counts ref_totals report_rows

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

* Build the additional All-CVD primary cohort by pooling the already-frozen
* Heart and Stroke condition-specific index events. This retains the approved
* first-event-of-each-condition rule: a person with both conditions can
* contribute two index events, and the same later death can be an outcome for
* both. The private overlap audit quantifies those person-years; the report and
* metadata explain that All CVD is an event aggregate, not a distinct-person or
* distinct-death count.
use "`review_root'/linked_index_events_private.dta", clear
preserve
    bysort event_person_key event_year: generate long condition_index_n = _N
    bysort event_person_key event_year: egen byte has_heart = max(etype==2)
    bysort event_person_key event_year: egen byte has_stroke = max(etype==1)
    bysort event_person_key event_year: keep if _n == 1
    generate byte one_person_year = 1
    generate byte both_conditions = has_heart==1 & has_stroke==1
    collapse (sum) cvd_person_years=one_person_year ///
        condition_index_rows=condition_index_n both_conditions, by(event_year)
    sort event_year
    save "`review_root'/cvd_index_event_overlap_audit.dta", replace
restore
replace etype = 0
label data "BNR private pooled All-CVD condition-index-event cohort"
save `"`cvd_index_events'"', replace

* The primary analytical file contains that pooled reporting series plus the
* two condition-specific series. Heart and Stroke retain their frozen records.
use "`review_root'/linked_index_events_private.dta", clear
append using `"`cvd_index_events'"'
save `"`primary_events'"', replace

use "`review_root'/linked_index_events_private.dta", clear
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
CONTROLLED SECTION 7 — CRUDE PRIMARY AND CONDITION-SPECIFIC SECONDARY MEASURES
DO NOT EDIT. This section builds the complete table that a public user could
compare. The primary series is annual by All CVD, Heart and Stroke and by sex.
Each secondary series remains Heart/Stroke-specific, uses the agreed broad
reporting eras and combines women and men. The eras are intentionally unequal:
their boundaries describe known changes in data provenance and quality rather
than equal calendar blocks. Keeping the two conditions separate avoids the
ambiguous pooled denominator discussed during methodological review.
*******************************************************************************/
use `"`primary_events'"', clear

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
* etype 0 is the pooled All-CVD condition-index-event cohort; etypes 1 and 2
* are the separate Stroke and Heart condition cohorts.
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

* Step 7.3: return to condition-specific records and assign the four agreed
* reporting eras once at record level.
* 2021--23 already uses REDCap, but predates the Info-Hub analytical process.
* 2024--25 is called the transition and process-improvement era: it spans the
* late-2024 process change and therefore must not imply uniform quality within
* the two years. Secondary measures retain etype in the collapse, so Heart and
* Stroke remain distinct.
use "`review_root'/linked_index_events_private.dta", clear
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
    replace quality_flag = "contains_2024_completeness_caution" if per_id == 4
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
    replace quality_flag = "contains_2024_completeness_caution" if per_id == 4
    save `"`secondary_hospital'"', replace
restore

* Step 7.6: join the three crude count layouts. Wilson intervals are calculated
* directly from each binomial numerator and denominator; no normal approximation
* is used. The unrounded values are retained in private review data.
use `"`primary_annual'"', clear
append using `"`secondary_linked'"' `"`secondary_hospital'"'

* Step 7.7: attach reader-facing era names and explanations only to the pooled
* secondary rows. Annual primary rows already state "calendar year" and leave
* era_name and era_note blank. This prevents an individual year—especially
* 2025—from being described as though it spans a multi-year process change.
* The secondary fields explain why their unequal periods are pre-specified.
generate str40 era_name = ""
replace era_name = "Early legacy era" if time_basis=="period" & ///
    inrange(period_start,2010,2015)
replace era_name = "Later legacy era" if time_basis=="period" & ///
    inrange(period_start,2016,2020)
replace era_name = "Third legacy / pre-Info-Hub era" if ///
    time_basis=="period" & inrange(period_start,2021,2023)
replace era_name = "Transition and process-improvement era" if ///
    time_basis=="period" & inrange(period_start,2024,2025)
generate str48 era_note = ""
replace era_note = "Early legacy records" if time_basis=="period" & ///
    inrange(period_start,2010,2015)
replace era_note = "Later legacy records" if time_basis=="period" & ///
    inrange(period_start,2016,2020)
replace era_note = "REDCap records before the Info-Hub process" if ///
    time_basis=="period" & inrange(period_start,2021,2023)
replace era_note = "Straddles the late-2024 process change" if ///
    time_basis=="period" & inrange(period_start,2024,2025)
generate str32 period_basis = "calendar year"
replace period_basis = "pre-specified reporting era" if ///
    time_basis == "period"

* Step 7.8: calculate the crude point estimates and Wilson intervals.
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

order measure_id standardisation time_basis period_basis era_name era_note ///
    period_label period_start ///
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
as <55, 55--64, 65--74, 75--84 and 85+. Separate All-CVD, Heart and Stroke
logistic models estimate predictive margins over each cohort's pooled valid-age
distribution. Primary models include year, sex, year-by-sex and age group.
Secondary models use reporting era and age group. Every margin is averaged over
the same fixed 2010--2025 valid-age reference population for that cohort.
This makes the adjusted series a within-cohort comparison over time; All CVD,
Heart and Stroke use different internal standards and their adjusted values
should not be compared directly. Clustered standard errors allow the same deterministic
person proxy to contribute an index event in more than one year. These are
model-based marginal estimates with delta-method 95% confidence intervals.
*******************************************************************************/
use `"`primary_events'"', clear
generate byte age_miss = missing(agey)
generate byte age_bad = !missing(agey) & !inrange(agey,0,110)
generate byte age_ok = inrange(agey,0,110)
generate byte age_grp = .
replace age_grp = 1 if age_ok & agey < 55
replace age_grp = 2 if age_ok & inrange(agey,55,64)
replace age_grp = 3 if age_ok & inrange(agey,65,74)
replace age_grp = 4 if age_ok & inrange(agey,75,84)
replace age_grp = 5 if age_ok & agey >= 85
generate byte age_excl = !age_ok
generate byte pri_ageok_d = d_pri30*age_ok
generate byte pri_ageex_d = d_pri30*age_excl
generate byte lnk_ageok_d = d_lnk30*age_ok
generate byte lnk_ageex_d = d_lnk30*age_excl
generate byte hsp_ageok_d = d_hsp30*age_ok
generate byte hsp_ageex_d = d_hsp30*age_excl

* Step 9.1: preserve compact private QA tables. They show exactly which records
* enter the models and whether missing or impossible age values cluster in a
* particular year, condition or sex stratum.
preserve
    collapse (sum) events=one age_missing=age_miss age_invalid=age_bad ///
        age_complete=age_ok primary_deaths=d_pri30 ///
        primary_deaths_age_complete=pri_ageok_d ///
        primary_deaths_age_excluded=pri_ageex_d, ///
        by(event_year etype sex)
    sort event_year etype sex
    save "`review_root'/age_model_audit_by_year_type_sex.dta", replace
restore
preserve
    keep if age_ok
    collapse (sum) ref_events=one ref_deaths=d_pri30, ///
        by(etype age_grp)
    bysort etype: egen long ref_total = total(ref_events)
    generate double ref_weight = ref_events/ref_total
    generate str24 ref_pop = cond(etype==0,"cvd_cases_2010_2025", ///
        cond(etype==1,"stroke_cases_2010_2025","heart_cases_2010_2025"))
    order ref_pop etype age_grp ref_events ref_total ref_weight ref_deaths
    sort etype age_grp
    save "`review_root'/age_group_reference_audit.dta", replace
restore
preserve
    use "`review_root'/age_group_reference_audit.dta", clear
    collapse (firstnm) ref_total, by(etype)
    save `"`ref_totals'"', replace
restore

* Step 9.2: construct one exact model-sample audit row for every crude layout
* before fitting models. The audit distinguishes the eligible cohort from the
* valid-age model cohort and records deaths excluded because age was missing or
* invalid. In-hospital rows from source-quality-excluded eras remain in this
* audit and are later labelled as not modelled.
preserve
    keep if inlist(sex,1,2)
    collapse (sum) eligible_events=one eligible_deaths=d_pri30 ///
        model_events=age_ok model_deaths=pri_ageok_d ///
        age_excluded_events=age_excl age_excluded_deaths=pri_ageex_d, ///
        by(event_year etype sex)
    generate int period_start = event_year
    generate int period_end = event_year
    generate str24 measure_id = "primary_30d"
    save `"`model_sample_counts'"', replace
restore
preserve
    collapse (sum) eligible_events=one eligible_deaths=d_pri30 ///
        model_events=age_ok model_deaths=pri_ageok_d ///
        age_excluded_events=age_excl age_excluded_deaths=pri_ageex_d, ///
        by(event_year etype)
    generate byte sex = 0
    generate int period_start = event_year
    generate int period_end = event_year
    generate str24 measure_id = "primary_30d"
    append using `"`model_sample_counts'"'
    save `"`model_sample_counts'"', replace
restore

* Secondary measures remain condition-specific. Remove the additional All-CVD
* primary rows before creating their pooled reporting-era samples.
keep if inlist(etype,1,2)
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
preserve
    collapse (sum) eligible_events=one eligible_deaths=d_lnk30 ///
        model_events=age_ok model_deaths=lnk_ageok_d ///
        age_excluded_events=age_excl age_excluded_deaths=lnk_ageex_d, ///
        by(per_id period_start period_end etype)
    generate int event_year = .
    generate byte sex = 0
    generate str24 measure_id = "linked_30d"
    append using `"`model_sample_counts'"'
    save `"`model_sample_counts'"', replace
restore
preserve
    collapse (sum) eligible_events=one eligible_deaths=d_hsp30 ///
        model_events=age_ok model_deaths=hsp_ageok_d ///
        age_excluded_events=age_excl age_excluded_deaths=hsp_ageex_d, ///
        by(per_id period_start period_end etype)
    generate int event_year = .
    generate byte sex = 0
    generate str24 measure_id = "in_hospital_30d"
    append using `"`model_sample_counts'"'
    save `"`model_sample_counts'"', replace
restore

* Step 9.3: fit primary models separately within each cohort. The sex-specific
* model contains year, sex, their interaction and age group; margins fix year and
* sex while averaging over the full cohort-specific 2010--25 valid-age
* reference population. A second combined-sex model contains year and age group
* only. Its margins use the same fixed cohort-specific age standard without
* additionally standardising sex. The noesample option is deliberate: it keeps
* the reference population fixed rather than allowing each fitted model's sample
* to redefine the standard. A missing margin later stops release.
local first_primary = 1
foreach t in 0 1 2 {
    use `"`primary_events'"', clear
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
    quietly margins if age_ok, ///
        at(event_year=(2010(1)2025) sex=(1 2)) noesample ///
        level(95) saving(`"`pri_sex_marg'"', replace)
    quietly logit d_pri30 i.event_year i.age_grp if age_ok, ///
        vce(cluster __cf_pid)
    if e(converged) != 1 {
        display as error "Primary combined-sex model did not converge: etype `t'."
        exit 430
    }
    quietly margins if age_ok, at(event_year=(2010(1)2025)) noesample ///
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
    if `first_primary' == 1 {
        save `"`primary_adj'"', replace
        local first_primary = 0
    }
    else {
        append using `"`primary_adj'"'
        save `"`primary_adj'"', replace
    }
}

* Step 9.4: fit the two condition-specific secondary models. Linked mortality
* uses all four reporting eras. In-hospital modelling uses only 2016--20 and
* 2024--25; excluded source-quality eras cannot influence model coefficients.
* Regardless of the fitting sample, margins are averaged over the full fixed
* 2010--25 valid-age reference population for that condition.
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
        quietly margins if age_ok, at(per_id=(`ats')) noesample ///
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

* Step 9.5: bind each proposed adjusted row to its exact model-sample counts
* and fixed reference-population identifier. Successful model rows can exist
* only when the fitted model converged and margins were estimable; the script
* has already stopped on non-convergence. The two source-quality-excluded
* in-hospital eras are retained with an explicit not-modelled status.
use `"`model_sample_counts'"', clear
merge 1:1 measure_id period_start period_end event_year etype sex ///
    using `"`model_results'"', keep(master match) assert(master match) ///
    generate(model_merge)
merge m:1 etype using `"`ref_totals'"', assert(match) nogen
generate str24 ref_pop = cond(etype==0,"cvd_cases_2010_2025", ///
    cond(etype==1,"stroke_cases_2010_2025","heart_cases_2010_2025"))
generate byte estimable = model_merge == 3 & ///
    !missing(estimate,ci_lower,ci_upper)
generate str32 model_status = "converged_estimable"
replace model_status = "not_modelled_source_quality" if ///
    measure_id == "in_hospital_30d" & inlist(per_id,1,3)
quietly count if model_status == "converged_estimable" & !estimable
assert r(N) == 0
quietly count if model_status == "not_modelled_source_quality" & ///
    model_merge != 1
assert r(N) == 0
drop model_merge estimate ci_lower ci_upper
order measure_id period_start period_end event_year etype sex ///
    eligible_events eligible_deaths model_events model_deaths ///
    age_excluded_events age_excluded_deaths ref_pop ref_total ///
    estimable model_status
isid measure_id period_start period_end etype sex
sort measure_id period_start etype sex
save "`review_root'/age_model_sample_audit.dta", replace

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
    using `"`model_results'"', keep(master match) assert(master match) nogen
quietly count if release_status == "release" & missing(estimate)
assert r(N) == 0
save `"`model_results'"', replace

use `"`crude_rows'"', clear
append using `"`model_results'"'
generate str6 event_type = ""
replace event_type = "CVD" if etype == 0
replace event_type = "Stroke" if etype == 1
replace event_type = "Heart" if etype == 2
generate str10 sex_group = "Both"
replace sex_group = "Women" if sex == 1
replace sex_group = "Men" if sex == 2

* Retain only fields intended for external interpretation, then blank every
* protected numeric result. Private complement and linkage diagnostics are not
* copied to the candidate public payload.
keep measure_id standardisation time_basis period_basis era_name era_note ///
    period_label period_start period_end event_type sex_group denominator ///
    numerator estimate ci_lower ci_upper release_status quality_flag
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
    "Inputs: joined identifiable CVD event release 2026-01 and all-deaths " ///
    "mortality release `mortality_release'. Death follow-up ends 30 January " ///
    "2026, providing 30 complete days for events through 31 December 2025." _n
file write meta ///
    "Primary measure: all-cause death within 30 days of the first event of " ///
    "each condition in each calendar year. All CVD pools the Heart and Stroke " ///
    "condition-specific index events. Deaths are identified by deterministic " ///
    "mortality linkage or death recorded on the index hospital event record " ///
    "within 30 days." _n
file write meta ///
    "Secondary measures: deterministic linked all-cause death within 30 " ///
    "days; and death recorded on the index hospital event record within 30 " ///
    "days. Secondary rows are condition-specific and use four pre-specified " ///
    "reporting eras. They are calculated for the candidate dataset but are " ///
    "not presented in the initial report PDF." _n
file write meta ///
    "Reporting eras: 2010-15 Early legacy; 2016-20 Later legacy; 2021-23 " ///
    "Third legacy / pre-Info-Hub; and 2024-25 Transition and process-" ///
    "improvement. The eras " ///
    "describe changes in data provenance and quality, not equal calendar " ///
    "blocks. The 2024-25 era straddles a late-2024 process change and should " ///
    "not be interpreted as having uniform data quality." _n
file write meta ///
    "Cohorts: All CVD pools the separate Heart and Stroke disease-specific " ///
    "cohorts. A person can contribute one index event per year to each " ///
    "condition-specific cohort. A " ///
    "subsequent all-cause death can therefore be an outcome in both series; " ///
    "this is not a count of distinct national deaths." _n
file write meta "Crude uncertainty: Wilson 95% binomial confidence intervals." _n
file write meta ///
    "Age-standardisation: logistic predictive margins using age groups <55, " ///
    "55-64, 65-74, 75-84 and 85+. Every margin for a cohort is averaged " ///
    "over that cohort's fixed pooled 2010-25 valid-age index-event " ///
    "population. Primary sex-specific models include year, sex, year-by-sex " ///
    "and age group; combined-sex models include year and age group. Secondary " ///
    "models include reporting era and age group. Records with missing or " ///
    "invalid age are excluded. All CVD, Heart and Stroke use different internal " ///
    "standards: adjusted results support comparisons over time within a " ///
    "cohort and should not be compared directly between cohorts. " ///
    "Delta-method 95% confidence intervals are reported." _n
file write meta ///
    "Suppression: all numeric outputs are blank when a direct cell, " ///
    "complementary source-only cell, shared-source cell, noncase cell or " ///
    "derivable unknown-sex cell is 1-5. Adjusted rows inherit the crude-row " ///
    "decision." _n
file write meta ///
    "Quality flags: the 2024 annual primary rows are flagged for possible " ///
    "abstraction incompleteness. The 2024-25 secondary era is flagged because " ///
    "it contains 2024 and straddles a process change. In-hospital estimates " ///
    "for 2010-15 and 2021-23 are not released because of historical source-" ///
    "quality limitations." _n
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

/*******************************************************************************
CONTROLLED SECTION 11 — FINISHED ONE-OFF REPORT PDF
DO NOT EDIT for a routine rerun. All result tables and figures read only the
disclosure-controlled candidate dataset created above. The report presents
annual primary All-CVD, Heart and Stroke results and never loads secondary
measures into a report table or figure. Crude estimates are the main measure;
age-standardised estimates provide supporting within-cohort context. The body
PDF is composed in Stata and the existing presentation-only annual-report
helper adds page furniture. The completed PDF remains private until it passes
the separate one-off prepare, approve and publish workflow.
*******************************************************************************/
local crest "$BNR_REPO/site/assets/images/uwi-crestonly-20p.png"
foreach required_report_file in crest pdf_helper pdf_python pdf_logo cf_equation {
    capture confirm file "``required_report_file''"
    if _rc {
        display as error "Required report file not found: ``required_report_file''"
        log close case_fatality
        exit 601
    }
}

* Step 11.1: create the exact aggregate report source. The assertion protects
* the agreed first-report design: every annual primary result must be released.
* If a later rerun introduces suppression, the PDF stops rather than silently
* omitting or reconstructing a protected value.
use "`candidate_root'/case_fatality_metrics_candidate.dta", clear
keep if measure_id == "primary_30d"
quietly count if release_status != "release"
if r(N) > 0 {
    display as error "Annual primary rows now include protected values."
    display as error "Review disclosure control before rebuilding the PDF."
    log close case_fatality
    exit 459
}
assert !missing(events,deaths,estimate_pct,ci_lower_pct,ci_upper_pct)
save `"`report_rows'"', replace

* Step 11.2: collect the six sex-specific 2025 headline values plus the crude
* and age-adjusted combined-sex values used on each detailed results page.
* These locals feed cards directly, so no report number is typed by hand.
foreach c in CVD Heart Stroke {
    local cstem = lower("`c'")
    foreach s in Women Men {
        local sstem = lower("`s'")
        quietly count if event_type == "`c'" & sex_group == "`s'" & ///
            standardisation == "crude" & period_start == `last_year'
        assert r(N) == 1
        quietly summarize estimate_pct if event_type == "`c'" & ///
            sex_group == "`s'" & standardisation == "crude" & ///
            period_start == `last_year', meanonly
        local `cstem'_`sstem'_pct : display %4.1f r(mean)
        quietly summarize ci_lower_pct if event_type == "`c'" & ///
            sex_group == "`s'" & standardisation == "crude" & ///
            period_start == `last_year', meanonly
        local `cstem'_`sstem'_lo : display %4.1f r(mean)
        quietly summarize ci_upper_pct if event_type == "`c'" & ///
            sex_group == "`s'" & standardisation == "crude" & ///
            period_start == `last_year', meanonly
        local `cstem'_`sstem'_hi : display %4.1f r(mean)
    }
    foreach a in crude age_standardised {
        local astem "crude"
        if "`a'" == "age_standardised" local astem "adjusted"
        quietly count if event_type == "`c'" & sex_group == "Both" & ///
            standardisation == "`a'" & period_start == `last_year'
        assert r(N) == 1
        quietly summarize estimate_pct if event_type == "`c'" & ///
            sex_group == "Both" & standardisation == "`a'" & ///
            period_start == `last_year', meanonly
        local `cstem'_`astem'_pct : display %4.1f r(mean)
        quietly summarize ci_lower_pct if event_type == "`c'" & ///
            sex_group == "Both" & standardisation == "`a'" & ///
            period_start == `last_year', meanonly
        local `cstem'_`astem'_lo : display %4.1f r(mean)
        quietly summarize ci_upper_pct if event_type == "`c'" & ///
            sex_group == "Both" & standardisation == "`a'" & ///
            period_start == `last_year', meanonly
        local `cstem'_`astem'_hi : display %4.1f r(mean)
    }
}

* Step 11.3: draw four restrained report figures. One combined Heart-and-Stroke
* chart appears on the 2025 brief page. The three larger charts show women and
* men separately for All CVD, Heart and Stroke. Every legend explains both the
* confidence-interval whiskers and the lightly shaded 2024 completeness-caution
* band. Axis labels use whole percentages throughout.
local ink       "44 62 80"
local teal      "4 81 116"
local heart_col "178 95 82"
local stroke_col "47 126 96"
local cvd_women "4 116 161"
local cvd_men   "4 46 71"
local heart_women "233 130 112"
local heart_men   "123 60 52"
local stroke_women "72 171 131"
local stroke_men   "22 81 61"
local muted     "102 102 102"
local pale      "240 246 248"
local pale2     "248 249 250"
local white     "255 255 255"
local rule      "222 226 230"
local amber     "181 103 0"
local font_title "Montserrat Medium"
local font_body  "Montserrat"

use `"`report_rows'"', clear
keep if standardisation == "crude" & sex_group == "Both"
sort event_type period_start
quietly count
local shade_n = r(N)
local shade_a = `shade_n' + 1
local shade_b = `shade_n' + 2
set obs `shade_b'
generate double shade_x = .
generate double shade_lo = .
generate double shade_hi = .
replace shade_x = 2023.5 in `shade_a'
replace shade_x = 2024.5 in `shade_b'
replace shade_lo = 0 in `shade_a'/`shade_b'
replace shade_hi = 60 in `shade_a'/`shade_b'
replace period_start = period_start+0.1 if event_type=="Heart"
#delimit ;
twoway
    (rspike ci_lower_pct ci_upper_pct period_start if event_type=="Heart",
        lcolor("`muted'%60"))
    (connected estimate_pct period_start if event_type=="Heart",
        lwidth(0.75) lcolor("`heart_col'%90") mcolor("`heart_col'") msymbol(O) msize(4))
    (rspike ci_lower_pct ci_upper_pct period_start if event_type=="Stroke",
        lcolor("`muted'%60"))
    (connected estimate_pct period_start if event_type=="Stroke",
        lwidth(0.75) lcolor("`stroke_col'%90") mcolor("`stroke_col'") msymbol(O) msize(4))
    , 

      graphregion(color("`white'"))
      plotregion(color("`white'") margin(small))
      xsize(7.2) ysize(2.35) name(cf_trend_hs, replace)

      ytitle("%", size(6)) xtitle("")
      xlabel(2010(2)2024 2025, labsize(5) noticks nogrid)
      xscale(noline range(2009.5 2025))

      ylabel(0(10)60, format(%2.0f) labsize(5) angle(horizontal) noticks nogrid)
      yscale(noline range(0 60))

      legend(order(2 "Heart" 4 "Stroke" 1 "95% CI") rows(1) position(12)
          region(lcolor(none)) size(5))
        ;
graph export "`figure_root'/heart_stroke_overall.png", replace width(2400);
#delimit cr

foreach c in CVD Heart Stroke {
    use `"`report_rows'"', clear
    keep if standardisation == "crude" & event_type == "`c'" & ///
        inlist(sex_group,"Women","Men")
    local stem = lower("`c'")
    local wcol "``stem'_women'"
    local mcol "``stem'_men'"
    quietly count
    local shade_n = r(N)
    local shade_a = `shade_n' + 1
    local shade_b = `shade_n' + 2
    set obs `shade_b'
    generate double shade_x = .
    generate double shade_lo = .
    generate double shade_hi = .
    replace shade_x = 2023.5 in `shade_a'
    replace shade_x = 2024.5 in `shade_b'
    replace shade_lo = 0 in `shade_a'/`shade_b'
    replace shade_hi = 60 in `shade_a'/`shade_b'
    replace period_start = period_start+0.2 if sex_group=="Men"
    #delimit ;
    twoway
        (rspike ci_lower_pct ci_upper_pct period_start if sex_group=="Women",
            lcolor("`muted'%48"))
        (connected estimate_pct period_start if sex_group=="Women",
            lwidth(0.75) lcolor("`wcol'%90") mcolor("`wcol'") msymbol(O) msize(4))
        (rspike ci_lower_pct ci_upper_pct period_start if sex_group=="Men",
            lcolor("`muted'%48"))
        (connected estimate_pct period_start if sex_group=="Men",
            lwidth(0.75) lcolor("`mcol'%90") mcolor("`mcol'") msymbol(O) msize(4))
        , 

        graphregion(color("`white'"))
        plotregion(color("`white'") margin(small))
        xsize(7.2) ysize(2.35) name(cf_sex_`stem', replace)

        xlabel(2010(2)2024 2025, labsize(5) noticks nogrid)
        xscale(noline range(2009.5 2025))

        ytitle("%", size(6)) xtitle("")
        ylabel(0(10)60, format(%2.0f) labsize(5) angle(horizontal) noticks nogrid)
        yscale(noline range(0 60))
        
        legend(order(2 "Women" 4 "Men" 1 "95% CI") rows(1) position(12)
              region(lcolor(none)) size(5))
        ;
    #delimit cr
    graph export "`figure_root'/`stem'_crude_by_sex.png", ///
        replace width(2600)
}

* Step 11.4: compose the finished A4 report. Every figure and table below is
* derived from report_rows, which contains only released annual primary values.
capture putpdf clear
putpdf begin, pagesize(A4) ///
    margin(top,0.55) margin(bottom,0.55) ///
    margin(left,0.65) margin(right,0.65) font("Arial",10)



* COVER PAGE
putpdf table cf_cover_logo = (5,1), width(15%) border(all,nil) halign(center)
forvalues r = 1/4 {
    putpdf table cf_cover_logo(`r',1) = (" ")
}
putpdf table cf_cover_logo(5,1) = image("`crest'"), halign(center)
putpdf table cf_cover = (8,1), width(88%) border(all,nil) halign(center)
putpdf table cf_cover(1,1) = (" ")
putpdf table cf_cover(2,1) = (" ")
putpdf table cf_cover(3,1) = ("BARBADOS NATIONAL REGISTRY"), ///
    halign(center) font("`font_title'",10,"`teal'")
putpdf table cf_cover(4,1) = ("Thirty-day case fatality"), ///
    halign(center) bold font("`font_title'",24,"`ink'")
putpdf table cf_cover(5,1) = ("after cardiovascular events"), ///
    halign(center) bold font("`font_title'",20,"`ink'")
putpdf table cf_cover(6,1) = ("Barbados, 2010-2025"), ///
    halign(center) font("`font_body'",12,"`muted'")
putpdf table cf_cover(7,1) = ("Published `c(current_date)'"), ///
    halign(center) font("`font_body'",8.5,"`muted'")
putpdf table cf_cover(8,1) = ///
    ("The University of the West Indies | Cave Hill Campus"), ///
    halign(center) font("`font_body'",8,"`muted'")



* PAGE 2: 2025 in brief. Six cards provide the sex-specific headline values.
* Narrow empty columns create deliberate white space between the three card
* columns. One combined chart retains the long Heart and Stroke context.
* The exact 2025 table then reports all three cohorts and all three sex groups.
putpdf pagebreak
putpdf paragraph, font("`font_body'",1)
putpdf text ("2025 IN BRIEF"), ///
    bold font("`font_title'",7.5,"`teal'") linebreak
putpdf text ("Thirty-day case fatality at a glance"), ///
    bold font("`font_title'",18,"`ink'")
putpdf paragraph, font("`font_body'",1)
matrix cf_card_w = (30,5,30,5,30)
putpdf table cf_cards = (6,5), width(100%) width(cf_card_w) border(all,nil)
putpdf table cf_cards(1,1) = ("CVD | WOMEN"), bold ///
    font("`font_title'",7.0,"`cvd_women'") border(top,single,"`cvd_women'")
putpdf table cf_cards(1,3) = ("HEART | WOMEN"), bold ///
    font("`font_title'",7.0,"`heart_women'") border(top,single,"`heart_women'")
putpdf table cf_cards(1,5) = ("STROKE | WOMEN"), bold ///
    font("`font_title'",7.0,"`stroke_women'") border(top,single,"`stroke_women'")
putpdf table cf_cards(2,1) = ("`cvd_women_pct'%"), bold font("`font_title'",15,"`ink'")
putpdf table cf_cards(2,3) = ("`heart_women_pct'%"), bold font("`font_title'",15,"`ink'")
putpdf table cf_cards(2,5) = ("`stroke_women_pct'%"), bold font("`font_title'",15,"`ink'")
putpdf table cf_cards(3,1) = ("95% CI `cvd_women_lo'-`cvd_women_hi'"), font("`font_body'",8.2,"`muted'")
putpdf table cf_cards(3,3) = ("95% CI `heart_women_lo'-`heart_women_hi'"), font("`font_body'",8.2,"`muted'")
putpdf table cf_cards(3,5) = ("95% CI `stroke_women_lo'-`stroke_women_hi'"), font("`font_body'",8.2,"`muted'")
putpdf table cf_cards(4,1) = ("CVD | MEN"), bold ///
    font("`font_title'",7.0,"`cvd_men'") border(top,single,"`cvd_men'")
putpdf table cf_cards(4,3) = ("HEART | MEN"), bold ///
    font("`font_title'",7.0,"`heart_men'") border(top,single,"`heart_men'")
putpdf table cf_cards(4,5) = ("STROKE | MEN"), bold ///
    font("`font_title'",7.0,"`stroke_men'") border(top,single,"`stroke_men'")
putpdf table cf_cards(5,1) = ("`cvd_men_pct'%"), bold font("`font_title'",15,"`ink'")
putpdf table cf_cards(5,3) = ("`heart_men_pct'%"), bold font("`font_title'",15,"`ink'")
putpdf table cf_cards(5,5) = ("`stroke_men_pct'%"), bold font("`font_title'",15,"`ink'")
putpdf table cf_cards(6,1) = ("95% CI `cvd_men_lo'-`cvd_men_hi'"), font("`font_body'",8.2,"`muted'")
putpdf table cf_cards(6,3) = ("95% CI `heart_men_lo'-`heart_men_hi'"), font("`font_body'",8.2,"`muted'")
putpdf table cf_cards(6,5) = ("95% CI `stroke_men_lo'-`stroke_men_hi'"), font("`font_body'",8.2,"`muted'")

putpdf paragraph, font("`font_body'",.5)
putpdf table cf_brief_chart = (1,1), width(100%) border(all,nil) halign(center)
putpdf table cf_brief_chart(1,1) = image("`figure_root'/heart_stroke_overall.png")


putpdf paragraph, font("`font_body'",1)
putpdf text ("2025 results by sex"), ///
    bold font("`font_title'",10.5,"`ink'")
* Format the nine exact 2025 rows once: three cohorts by three sex groups.
use `"`report_rows'"', clear
keep if period_start == `last_year'
keep event_type sex_group standardisation events deaths estimate_pct ///
    ci_lower_pct ci_upper_pct
rename estimate_pct pct
rename ci_lower_pct lo
rename ci_upper_pct hi
reshape wide events deaths pct lo hi, i(event_type sex_group) ///
    j(standardisation) string
generate str32 crude_txt = strtrim(string(pctcrude,"%4.1f")) + ///
    " (" + strtrim(string(locrude,"%4.1f")) + "-" + ///
    strtrim(string(hicrude,"%4.1f")) + ")"
generate str32 adj_txt = strtrim(string(pctage_standardised,"%4.1f")) + ///
    " (" + strtrim(string(loage_standardised,"%4.1f")) + "-" + ///
    strtrim(string(hiage_standardised,"%4.1f")) + ")"
generate byte cond_order = cond(event_type=="CVD",1,cond(event_type=="Heart",2,3))
generate byte sex_order = cond(sex_group=="Both",1,cond(sex_group=="Women",2,3))
sort cond_order sex_order
assert _N == 9

putpdf paragraph, font("`font_body'",.5)
matrix cf_brief_w = (12,11,10,10,28,29)
putpdf table cf_brief_tab = (10,6), width(100%) width(cf_brief_w) border(all,nil)
putpdf table cf_brief_tab(1,1) = ("Event")
putpdf table cf_brief_tab(1,2) = ("Sex")
putpdf table cf_brief_tab(1,3) = ("Events")
putpdf table cf_brief_tab(1,4) = ("Deaths")
putpdf table cf_brief_tab(1,5) = ("Crude % (95% CI)")
putpdf table cf_brief_tab(1,6) = ("Adjusted % (95% CI)")
putpdf table cf_brief_tab(1,.), bold font("`font_title'",7.2,"`ink'") ///
    border(bottom,single,"`rule'")
forvalues i = 1/9 {
    local rr = `i' + 1
    local ev = event_type[`i']
    local sx = sex_group[`i']
    local nn = strtrim(string(eventscrude[`i'],"%8.0fc"))
    local dd = strtrim(string(deathscrude[`i'],"%8.0fc"))
    local ct = crude_txt[`i']
    local at = adj_txt[`i']
    putpdf table cf_brief_tab(`rr',1) = ("`ev'"), font("`font_body'",7.2,"`ink'")
    putpdf table cf_brief_tab(`rr',2) = ("`sx'"), font("`font_body'",7.2,"`ink'")
    putpdf table cf_brief_tab(`rr',3) = ("`nn'"), font("`font_body'",7.2,"`ink'")
    putpdf table cf_brief_tab(`rr',4) = ("`dd'"), font("`font_body'",7.2,"`ink'")
    putpdf table cf_brief_tab(`rr',5) = ("`ct'"), font("`font_body'",7.2,"`ink'")
    putpdf table cf_brief_tab(`rr',6) = ("`at'"), font("`font_body'",7.2,"`ink'")
}
putpdf paragraph, font("`font_body'",.5)
putpdf table cf_brief_note = (2,1), width(100%) border(all,nil)
putpdf table cf_brief_note(1,1) = ("WHAT THIS MEANS"), bold ///
    font("`font_title'",8.6,"`teal'") border(top,single,"`teal'")
putpdf table cf_brief_note(2,1) = ("`note_brief'"), ///
    font("`font_body'",8.6,"`ink'")




* PAGES 3 TO 5: one consistent sex-stratified page for each primary cohort.
* The compact table uses the five most recent complete years. A tidy row layout
* keeps women and men visible without forcing nine very narrow table columns.
foreach c in CVD Heart Stroke {
    local stem = lower("`c'")
    local c_upper = upper("`c'")
    local ccol "`teal'"
    if "`c'" == "Stroke" local ccol "`stroke_col'"
    if "`c'" == "Heart" local ccol "`heart_col'"
    putpdf pagebreak
    putpdf paragraph, font("`font_body'",1)
    putpdf text ("`c_upper' EVENTS"), ///
        bold font("`font_title'",7.5,"`ccol'") linebreak
    local page_title "Thirty-day case fatality after `c' events"
    if "`c'" == "CVD" local page_title "Thirty-day case fatality after CVD events"
    putpdf text ("`page_title'"), ///
        bold font("`font_title'",18,"`ink'") linebreak
    putpdf text ("Annual results by sex."), ///
        font("`font_body'",8,"`muted'")

    * Two condition-coloured cards place the latest combined-sex crude and
    * age-adjusted estimates together without crowding them into one cell.
    local crude_pct "``stem'_crude_pct'"
    local crude_lo "``stem'_crude_lo'"
    local crude_hi "``stem'_crude_hi'"
    local adjusted_pct "``stem'_adjusted_pct'"
    local adjusted_lo "``stem'_adjusted_lo'"
    local adjusted_hi "``stem'_adjusted_hi'"
    putpdf paragraph, font("`font_body'",.6)
    matrix cf_detail_card_w = (47,6,47)
    putpdf table cf_`stem'_cards = (3,3), width(100%) ///
        width(cf_detail_card_w) border(all,nil)
    putpdf table cf_`stem'_cards(1,1) = ("CRUDE | WOMEN + MEN | 2025"), ///
        bold font("`font_title'",7.0,"`ccol'") border(top,single,"`ccol'")
    putpdf table cf_`stem'_cards(1,3) = ("AGE-ADJUSTED | WOMEN + MEN | 2025"), ///
        bold font("`font_title'",7.0,"`ccol'") border(top,single,"`ccol'")
    putpdf table cf_`stem'_cards(2,1) = ("`crude_pct'%"), ///
        bold font("`font_title'",15,"`ink'")
    putpdf table cf_`stem'_cards(2,3) = ("`adjusted_pct'%"), ///
        bold font("`font_title'",15,"`ink'")
    putpdf table cf_`stem'_cards(3,1) = ///
        ("95% CI `crude_lo'-`crude_hi'"), font("`font_body'",8.2,"`muted'")
    putpdf table cf_`stem'_cards(3,3) = ///
        ("95% CI `adjusted_lo'-`adjusted_hi'"), font("`font_body'",8.2,"`muted'")

    putpdf paragraph, font("`font_body'",.5)
    putpdf table cf_`stem'_img = (1,1), width(100%) ///
        border(all,nil) halign(center)
    putpdf table cf_`stem'_img(1,1) = ///
        image("`figure_root'/`stem'_crude_by_sex.png")
    putpdf paragraph, font("`font_body'",1)
    putpdf text ("Recent results by sex"), ///
        bold font("`font_title'",10.5,"`ink'")

    use `"`report_rows'"', clear
    keep if event_type == "`c'" & inlist(sex_group,"Women","Men") & ///
        inrange(period_start,2021,2025)
    keep period_start sex_group standardisation events deaths estimate_pct ///
        ci_lower_pct ci_upper_pct
    rename period_start yr
    rename estimate_pct pct
    rename ci_lower_pct lo
    rename ci_upper_pct hi
    reshape wide events deaths pct lo hi, i(yr sex_group) ///
        j(standardisation) string
    generate str36 crude_txt = strtrim(string(pctcrude,"%4.1f")) + ///
        " (" + strtrim(string(locrude,"%4.1f")) + "-" + ///
        strtrim(string(hicrude,"%4.1f")) + ")"
    generate str36 adj_txt = ///
        strtrim(string(pctage_standardised,"%4.1f")) + ///
        " (" + strtrim(string(loage_standardised,"%4.1f")) + "-" + ///
        strtrim(string(hiage_standardised,"%4.1f")) + ")"
    generate byte sex_order = cond(sex_group=="Women",1,2)
    sort yr sex_order
    assert _N == 10

    matrix cf_result_w = (8,11,11,10,29,31)
    putpdf table cf_`stem'_tab = (11,6), width(100%) ///
        width(cf_result_w) border(all,nil)
    putpdf table cf_`stem'_tab(1,1) = ("Year")
    putpdf table cf_`stem'_tab(1,2) = ("Sex")
    putpdf table cf_`stem'_tab(1,3) = ("Events")
    putpdf table cf_`stem'_tab(1,4) = ("Deaths")
    putpdf table cf_`stem'_tab(1,5) = ("Crude % (95% CI)")
    putpdf table cf_`stem'_tab(1,6) = ("Adjusted % (95% CI)")
    putpdf table cf_`stem'_tab(1,.), ///
        bold font("`font_title'",7.2,"`ink'") border(bottom,single,"`rule'")
    forvalues i = 1/10 {
        local rr = `i' + 1
        local yy : display %4.0f yr[`i']
        local sx = sex_group[`i']
        local nn = strtrim(string(eventscrude[`i'],"%8.0fc"))
        local dd = strtrim(string(deathscrude[`i'],"%8.0fc"))
        local ct = crude_txt[`i']
        local at = adj_txt[`i']
        putpdf table cf_`stem'_tab(`rr',1) = ("`yy'"), ///
            font("`font_body'",7.2,"`ink'")
        putpdf table cf_`stem'_tab(`rr',2) = ("`sx'"), ///
            font("`font_body'",7.2,"`ink'")
        putpdf table cf_`stem'_tab(`rr',3) = ("`nn'"), ///
            font("`font_body'",7.2,"`ink'")
        putpdf table cf_`stem'_tab(`rr',4) = ("`dd'"), ///
            font("`font_body'",7.2,"`ink'")
        putpdf table cf_`stem'_tab(`rr',5) = ("`ct'"), ///
            font("`font_body'",7.2,"`ink'")
        putpdf table cf_`stem'_tab(`rr',6) = ("`at'"), ///
            font("`font_body'",7.2,"`ink'")
    }
    local meaning "`note_stroke'"
    if "`c'" == "CVD" local meaning "`note_cvd'"
    if "`c'" == "Heart" local meaning "`note_heart'"
    putpdf paragraph, font("`font_body'",.6)
    putpdf table cf_`stem'_note = (2,1), width(100%) border(all,nil)
    putpdf table cf_`stem'_note(1,1) = ("WHAT THIS MEANS"), bold ///
        font("`font_title'",8.6,"`ccol'") border(top,single,"`ccol'")
    putpdf table cf_`stem'_note(2,1) = ("`meaning'"), ///
        font("`font_body'",8.6,"`ink'")
}

* Page 6: concise public methods. Internal cleaning and diagnostic operations
* remain in the commented analytical sections above and private review files;
* only information needed to understand or reproduce the public measures is
* printed here.
putpdf pagebreak
putpdf paragraph, font("`font_body'",1)
putpdf text ("METHODS"), ///
    bold font("`font_title'",7.5,"`teal'") linebreak
putpdf text ("How this report was produced"), ///
    bold font("`font_title'",18,"`ink'")
putpdf paragraph, font("`font_body'",.5)
putpdf text ("The same steps were used for every year and for women, men and both sexes combined."), ///
    font("`font_body'",8,"`muted'")
putpdf paragraph, font("`font_body'",.5)
putpdf text ("How case fatality is calculated"), ///
    bold font("`font_title'",10,"`ink'")
putpdf table cf_equation_box = (1,1), width(55%) border(all,nil) halign(center)
putpdf table cf_equation_box(1,1) = image("`cf_equation'"), halign(center)
putpdf paragraph, font("`font_body'",.5)
matrix cf_method_w = (26,74)
putpdf table cf_methods = (8,2), width(100%) ///
    width(cf_method_w) border(all,nil)
putpdf table cf_methods(1,1) = ("What was counted?")
putpdf table cf_methods(1,2) = ("BNR hospital records of Heart and Stroke events from 2010 to 2025. All CVD combines the Heart and Stroke event groups.")

putpdf table cf_methods(2,1) = ("Which event was used?")
putpdf table cf_methods(2,2) = ("Within each calendar year, we used each person's first Heart event and first Stroke event. Later events of the same type during that year were not counted. A person who experienced both types could contribute once to the Heart series and once to the Stroke series, and therefore twice to All CVD. All CVD is consequently an event total, not a count of distinct people or deaths.")

putpdf table cf_methods(3,1) = ("What counted as a death?")
putpdf table cf_methods(3,2) = ("We counted a death from any cause occurring on the event date or during the following 30 days. The recorded cause of death did not have to be cardiovascular. A death was counted when it was reported in the hospital record or when the event record linked to a death in the all-deaths register.")

putpdf table cf_methods(4,1) = ("How were records linked?")
putpdf table cf_methods(4,2) = ("Hospital and death records were linked using predefined exact matching rules. We first used a valid national registration number when it identified one person and there was no conflicting information. When this was not possible, we required exact agreement on specified combinations of name, sex and date of birth, with a limited age-in-years fallback. A possible match was accepted only when it identified one unique person; ambiguous matches remained unlinked.")

putpdf table cf_methods(5,1) = ("What does crude mean?")
putpdf table cf_methods(5,2) = ("The crude result is the percentage actually observed in that year's event group: eligible index events followed by death within 30 days, divided by all eligible index events, multiplied by 100. It makes no allowance for differences in patients' ages. It describes the experience recorded by BNR in that year and is the main result in this report. It is a percentage among recorded events, not a population mortality rate.")

putpdf table cf_methods(6,1) = ("Why adjust for age?")
putpdf table cf_methods(6,2) = ("The chance of dying within 30 days generally increases with age. A year with older event patients can therefore have a higher crude percentage even if outcomes at the same ages have not worsened. The age-adjusted result estimates what each year's percentage would be if its age mix matched a fixed Barbados reference group. The All-CVD, Heart and Stroke series each use their own pooled 2010-2025 reference group. Adjusted results can therefore be compared over time within the same series, but not directly between the three series. We calculate them using logistic regression and predictive margins.")

putpdf table cf_methods(7,1) = ("What does the 95% CI show?")
putpdf table cf_methods(7,2) = ("The 95% confidence interval shows the statistical precision of the estimated percentage. Wider intervals indicate greater uncertainty, usually because fewer events were available. Crude intervals use the Wilson method; age-adjusted intervals are calculated from the statistical model and allow for repeat records from the same person. These intervals describe uncertainty arising from the observed numbers; they do not account for missed events, incomplete records or deaths that were not successfully linked.")

putpdf table cf_methods(8,1) = ("How was privacy protected?")
putpdf table cf_methods(8,2) = ("Counts from 1 to 5 were suppressed. We also suppressed additional values when necessary to prevent a protected count from being calculated by subtracting other published values. Zero counts were not automatically suppressed. Disclosure checks were applied to the complete proposed public dataset, and every result displayed in this report passed those checks.")

putpdf table cf_methods(.,.), font("`font_body'",7.2,"`ink'")
putpdf table cf_methods(.,1), bold font("`font_title'",7.2,"`teal'")
putpdf table cf_methods(1,.), border(top,single,"`teal'")
putpdf table cf_methods(8,.), border(bottom,single,"`teal'")
putpdf paragraph, font("`font_body'",.8)
putpdf text ("Data used"), bold font("`font_title'",8,"`ink'") linebreak
putpdf text ("CVD event release: January 2026. All-deaths release: `mortality_release'. Death follow-up runs through 30 January 2026, giving every event through 31 December 2025 a complete 30-day follow-up period."), ///
    font("`font_body'",7.2,"`muted'")

* Step 11.5: save the Stata-composed body, then add the same presentation-only
* running furniture used by the annual report. The helper leaves the cover
* undecorated; visible numbering begins on the 2025-in-brief page. The new
* optional centre-footer argument prints the Info-Hub address without changing
* the annual report unless that argument is deliberately supplied there.
capture noisily putpdf save "`report_body_pdf'", replace
if _rc {
    local pdf_rc = _rc
    capture log close case_fatality
    display as error "CASE-FATALITY REPORT BODY PDF COULD NOT BE SAVED"
    display as error "Check that the destination PDF is not open: `report_body_pdf'"
    exit `pdf_rc'
}

local furniture_command `""`pdf_python'" "`pdf_helper'" --input "`report_body_pdf'" --output "`report_pdf'" --report-title "BNR Case-Fatality Report 2010-2025" --report-year "2025" --logo "`pdf_logo'" --skip-first-pages 1 --footer-center "`info_hub_web'""'
capture noisily shell `furniture_command'
if _rc {
    local furniture_rc = _rc
    capture log close case_fatality
    display as error "CASE-FATALITY REPORT PAGE FURNITURE FAILED"
    display as error "Run: python scripts/python/check-python-environment.py"
    display as error "The unstamped body remains private: `report_body_pdf'"
    exit `furniture_rc'
}
capture confirm file "`report_pdf'"
if _rc {
    capture log close case_fatality
    display as error "The page-furniture helper did not write: `report_pdf'"
    exit 603
}
capture erase "`report_body_pdf'"

display as result "Candidate metrics, public dataset and report PDF complete."
display as text "Private review files: `review_root'"
display as text "Candidate public-data files: `candidate_root'"
display as text "Finished one-off report PDF: `report_pdf'"
display as text "The files remain private and require the one-off prepare/approve/publish workflow."
log close case_fatality

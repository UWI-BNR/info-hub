/*******************************************************************************
DO-FILE:     bnr_step2_cvd_confidential.do
VERSION:     1.3.0 (29 August 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 2 - build the confidential cumulative CVD dataset

PURPOSE
    Combine the frozen 2009-2023 CVD dataset with one selected cumulative
    post-2023 REDCap release, harmonise the two eras, create common analytical
    variables, and save one confidential cumulative dataset.

QUARANTINE POLICY
    Step 2 does not silently discard unsafe source information. Record-level
    source problems are handled using the smallest safe temporary action:

      * full quarantine: the event cannot safely enter the analytical dataset;
      * partial quarantine: the event remains, but unsafe field values are made
        unavailable for analyses that require them.

    Every full or partial quarantine is written to a private review report.
    Structural failures such as missing files, incompatible schemas or broken
    historical invariants remain fatal. Source corrections must be made in the
    authoritative source and the workflow rerun.

ROUTINE USE
    do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 1
*******************************************************************************/
version 19
clear all
set more off

capture program drop _bnr_step2_fail
program define _bnr_step2_fail
    version 19
    args return_code release_id log_path reason
    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 2 DID NOT COMPLETE"
    noisily display as error "  Release: `release_id'"
    noisily display as error `"  Reason:  `reason'"'
    noisily display as error `"  Log:     `log_path'"'
    noisily display as text  "Do not use any Step 2 output from this incomplete run."
    noisily display as error "============================================================================="
    capture log close step2
    exit `return_code'
end

args release_year release_month
if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Release year and month are required."
    display as error "Example: do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2026 1"
    exit 198
}

if `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

foreach path_name in BNR_STATA BNR_DATA_FROZEN BNR_DATA_RAW BNR_DATA_DERIVED BNR_PRIVATE_LOGS {
    if `"$`path_name'"' == "" {
        display as error "Required project path is not configured: `path_name'"
        exit 198
    }
}

local year_num  = real("`release_year'")
local month_num = real("`release_month'")
if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 exit 198
if missing(`month_num') | `month_num' != floor(`month_num') | !inrange(`month_num', 1, 12) exit 198

local year4  : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"
if `month_num' == 12 local end_td = mdy(12, 31, `year_num')
else local end_td = mdy(`month_num' + 1, 1, `year_num') - 1
local start_td = mdy(1, 1, 2024)
local end_date : display %tdCCYY-NN-DD `end_td'
local today_iso : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local analyst "`c(username)'"

local historical_file "$BNR_DATA_FROZEN/releases/y2023/m12/bnr-cvd-indiv-full-202312-v01.dta"
local release_file "$BNR_DATA_RAW/redcap/cvd/y`year4'/m`month2'/bnr_cvd_step1_`period'.dta"
local output_root "$BNR_DATA_DERIVED/cvd"
local output_year "`output_root'/y`year4'"
local output_dir "`output_year'/m`month2'"
local output_id "bnr_cvd_confidential_`period'_v01"
local output_dta "`output_dir'/`output_id'.dta"
local output_yml "`output_dir'/`output_id'.yml"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_step2_`period'.log"
local review_dir "`output_dir'/review"
local quarantine_dta "`review_dir'/bnr_cvd_step2_quarantine_`period'.dta"
local quarantine_xlsx "`review_dir'/bnr_cvd_step2_quarantine_`period'.xlsx"
local quarantine_summary "`review_dir'/bnr_cvd_step2_quarantine_summary_`period'.csv"

capture mkdir "$BNR_DATA_DERIVED"
capture mkdir "`output_root'"
capture mkdir "`output_year'"
capture mkdir "`output_dir'"
capture mkdir "`review_dir'"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close step2
log using "`output_log'", text replace name(step2)

quietly {
noisily display as text "BNR CVD STEP 2: CONFIDENTIAL CUMULATIVE DATASET"
noisily display as result "  Script version:   1.3.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Historical input: `historical_file'"
noisily display as result "  Post-2023 input:  `release_file'"
noisily display as result "  Private output:   `output_dta'"

capture confirm file "`historical_file'"
if _rc {
    _bnr_step2_fail 601 "`year4'-`month2'" `"`output_log'"' `"Required historical input not found: `historical_file'"'
}
capture confirm file "`release_file'"
if _rc {
    _bnr_step2_fail 601 "`year4'-`month2'" `"`output_log'"' `"Required Step 1 dataset not found: `release_file'"'
}

* -----------------------------------------------------------------------------
* 3. VALIDATE, QUARANTINE AND HARMONISE THE POST-2023 RELEASE
* -----------------------------------------------------------------------------
tempfile post2023 quarantine_worklist
capture use "`release_file'", clear
if _rc {
    local use_rc = _rc
    _bnr_step2_fail `use_rc' "`year4'-`month2'" `"`output_log'"' "The selected Step 1 Stata dataset could not be opened."
}

quietly count
local n_post_source = r(N)
quietly ds
local k_post : word count `r(varlist)'
local core_fields recid redcap_event_name edate dob cfage natregno recnum
foreach variable of local core_fields {
    capture confirm string variable `variable'
    if _rc {
        _bnr_step2_fail 109 "`year4'-`month2'" `"`output_log'"' "Post-2023 schema failure: `variable' is absent or is not a string."
    }
}

* Quarantine tracking stays in the private Step 2 preparation only.
generate long __q_source_row = _n
generate byte __q_full = 0
generate byte __q_partial = 0
generate str244 __q_reason = ""
generate str244 __q_fields = ""
generate str244 __q_source_detail = ""
generate str40 __q_dob_source = strtrim(dob)
generate str40 __q_edate_source = strtrim(edate)
generate str40 __q_cfage_source = strtrim(cfage)

* Core event-identity problems require full quarantine.
replace __q_full = 1 if inlist(strtrim(recid), "", ".")
replace __q_reason = "missing_record_id" if inlist(strtrim(recid), "", ".")
replace __q_fields = "recid" if inlist(strtrim(recid), "", ".")

replace __q_full = 1 if inlist(strtrim(redcap_event_name), "", ".")
replace __q_reason = cond(__q_reason == "", "missing_event_type", substr(__q_reason + "; missing_event_type", 1, 244)) if inlist(strtrim(redcap_event_name), "", ".")
replace __q_fields = cond(__q_fields == "", "redcap_event_name", substr(__q_fields + "; redcap_event_name", 1, 244)) if inlist(strtrim(redcap_event_name), "", ".")

replace __q_full = 1 if !inlist(strtrim(redcap_event_name), "", ".", "stroke_arm_1", "heart_arm_2")
replace __q_reason = cond(__q_reason == "", "unrecognised_event_type", substr(__q_reason + "; unrecognised_event_type", 1, 244)) if !inlist(strtrim(redcap_event_name), "", ".", "stroke_arm_1", "heart_arm_2")
replace __q_fields = cond(__q_fields == "", "redcap_event_name", substr(__q_fields + "; redcap_event_name", 1, 244)) if !inlist(strtrim(redcap_event_name), "", ".", "stroke_arm_1", "heart_arm_2")

replace __q_full = 1 if inlist(strtrim(edate), "", ".", "99")
replace __q_reason = cond(__q_reason == "", "missing_event_date", substr(__q_reason + "; missing_event_date", 1, 244)) if inlist(strtrim(edate), "", ".", "99")
replace __q_fields = cond(__q_fields == "", "edate", substr(__q_fields + "; edate", 1, 244)) if inlist(strtrim(edate), "", ".", "99")

tempvar duplicate_id
quietly duplicates tag recid redcap_event_name, generate(`duplicate_id')
replace __q_full = 1 if `duplicate_id' > 0
replace __q_reason = cond(__q_reason == "", "duplicate_event_identity", substr(__q_reason + "; duplicate_event_identity", 1, 244)) if `duplicate_id' > 0
replace __q_fields = cond(__q_fields == "", "recid+redcap_event_name", substr(__q_fields + "; recid+redcap_event_name", 1, 244)) if `duplicate_id' > 0
drop `duplicate_id'

* Expected numeric fields are structural requirements. A malformed value within
* an otherwise valid field is partially quarantined and set missing.
local numeric_fields cfsource___1 cfsource___2 cfsource___3 cfsource___4 cfsource___5 cfsource___6 cfsource___7 cfsource___8 cfsource___9 cfsource___10 cfsource___11 cfsource___12 cfsource___13 cfsource___14 cfsource___15 cfsource___16 cfsource___17 cfsource___18 cfsource___19 cfsource___20 cfsource___21 cfsource___22 cfsource___23 cfsource___24 cfsource___25 cfsource___26 cfsource___27 sex cfage cfage_da hstatus slc cstatus eligible ineligible duplicate duprec dupcheck toabs mstatus resident citizen parish ward___1 ward___2 ward___3 ward___4 ward___5 htype stype dxtype dstroke inhosp etimeampm pstroke pstrokeyr pami pamiyr rfany htn diab sysbp diasbp bgunit bgmg bgmmol dieany_2 decg ecg ecgtampm tropdone troptype tropres trop1res trop2res assess assess1 assess2 assess3 assess4 dieany dct ct reperf repertype asp___1 asp___2 asp___3 aspdose asptimeampm_2 vstatus dismeds___1 dismeds___2 dismeds___3 dismeds___4 dismeds___5 dismeds___6 dismeds___7 dismeds___8 dismeds___9 dismeds___10 aspdosedis dissysbp disdiasbp disbgmmol carunit strunit sunitadmsame sunitdissame ward___88 ward___99 ward___999 ward___9999 casefinding_demographics_complet edateyr edatemon edatemondash event_complete tests_complete asp___88 asp___99 asp___999 asp___9999 dismeds___88 dismeds___99 dismeds___999 dismeds___9999 treatment_discharge_complete

foreach variable of local numeric_fields {
    capture confirm string variable `variable'
    if _rc {
        _bnr_step2_fail 109 "`year4'-`month2'" `"`output_log'"' "Post-2023 schema failure: expected numeric field `variable' is absent or not a string."
    }
    tempvar bad_numeric
    generate byte `bad_numeric' = !inlist(strtrim(`variable'), "", ".") & missing(real(strtrim(`variable')))
    replace __q_partial = 1 if `bad_numeric' == 1 & __q_full == 0
    replace __q_reason = cond(__q_reason == "", "invalid_numeric_value", substr(__q_reason + "; invalid_numeric_value", 1, 244)) if `bad_numeric' == 1
    replace __q_fields = cond(__q_fields == "", "`variable'", substr(__q_fields + "; `variable'", 1, 244)) if `bad_numeric' == 1
    replace __q_source_detail = substr(cond(__q_source_detail == "", "`variable'=" + strtrim(`variable'), __q_source_detail + "; `variable'=" + strtrim(`variable')), 1, 244) if `bad_numeric' == 1
    replace `variable' = "" if `bad_numeric' == 1 | strtrim(`variable') == "."
    destring `variable', replace
    drop `bad_numeric'
}

* Date fields are parsed individually. Invalid event dates fully quarantine the
* event; invalid non-event dates partially quarantine only that field.
local date_fields cfdoa dob cfadmdate dlc cfdod edate ecgd doct reperfd aspd astrunitd dstrunitd
foreach variable of local date_fields {
    capture confirm string variable `variable'
    if _rc {
        _bnr_step2_fail 109 "`year4'-`month2'" `"`output_log'"' "Post-2023 schema failure: expected date field `variable' is absent or not a string."
    }
    tempvar parsed_date bad_date
    generate double `parsed_date' = daily(strtrim(`variable'), "YMD")
    replace `parsed_date' = daily(strtrim(`variable'), "DMY") if missing(`parsed_date') & !inlist(strtrim(`variable'), "", ".", "99")
    generate byte `bad_date' = !inlist(strtrim(`variable'), "", ".", "99") & missing(`parsed_date')
    if "`variable'" == "edate" {
        replace __q_full = 1 if `bad_date' == 1
    }
    else {
        replace __q_partial = 1 if `bad_date' == 1 & __q_full == 0
    }
    replace __q_reason = cond(__q_reason == "", "invalid_date_value", substr(__q_reason + "; invalid_date_value", 1, 244)) if `bad_date' == 1
    replace __q_fields = cond(__q_fields == "", "`variable'", substr(__q_fields + "; `variable'", 1, 244)) if `bad_date' == 1
    replace __q_source_detail = substr(cond(__q_source_detail == "", "`variable'=" + strtrim(`variable'), __q_source_detail + "; `variable'=" + strtrim(`variable')), 1, 244) if `bad_date' == 1
    drop `variable'
    rename `parsed_date' `variable'
    format `variable' %tdCCYY-NN-DD
    drop `bad_date'
}

replace __q_full = 1 if !missing(edate) & !inrange(edate, `start_td', `end_td')
replace __q_reason = cond(__q_reason == "", "event_date_outside_release", substr(__q_reason + "; event_date_outside_release", 1, 244)) if !missing(edate) & !inrange(edate, `start_td', `end_td')
replace __q_fields = cond(__q_fields == "", "edate", substr(__q_fields + "; edate", 1, 244)) if !missing(edate) & !inrange(edate, `start_td', `end_td')

* Age is checked before the post-2023 rows join the frozen history. An unsafe
* DOB/age partially quarantines those fields, not the whole event.
tempvar calculated_age
quietly generate int `calculated_age' = age(dob, edate) if __q_full == 0 & !missing(dob, edate)
replace __q_partial = 1 if __q_full == 0 & missing(`calculated_age')
replace __q_reason = cond(__q_reason == "", "age_unavailable", substr(__q_reason + "; age_unavailable", 1, 244)) if __q_full == 0 & missing(`calculated_age')
replace __q_fields = cond(__q_fields == "", "dob+age", substr(__q_fields + "; dob+age", 1, 244)) if __q_full == 0 & missing(`calculated_age')

replace __q_partial = 1 if __q_full == 0 & !missing(`calculated_age') & !inrange(`calculated_age', 0, 120)
replace __q_reason = cond(__q_reason == "", "implausible_calculated_age", substr(__q_reason + "; implausible_calculated_age", 1, 244)) if __q_full == 0 & !missing(`calculated_age') & !inrange(`calculated_age', 0, 120)
replace __q_fields = cond(__q_fields == "", "dob+age", substr(__q_fields + "; dob+age", 1, 244)) if __q_full == 0 & !missing(`calculated_age') & !inrange(`calculated_age', 0, 120)
replace __q_source_detail = substr(cond(__q_source_detail == "", "calculated_age=" + string(`calculated_age', "%12.0f"), __q_source_detail + "; calculated_age=" + string(`calculated_age', "%12.0f")), 1, 244) if __q_full == 0 & !missing(`calculated_age') & !inrange(`calculated_age', 0, 120)
replace dob = . if __q_full == 0 & !missing(`calculated_age') & !inrange(`calculated_age', 0, 120)
drop `calculated_age'

* Build one row per fully or partially quarantined source event.
preserve
keep if __q_full == 1 | __q_partial == 1
generate str8 quarantine_level = cond(__q_full == 1, "full", "partial")
generate long source_row = __q_source_row
generate str244 review_reason = __q_reason
generate str244 affected_fields = __q_fields
generate str40 source_dob = __q_dob_source
generate str40 source_edate = __q_edate_source
generate str40 source_cfage = __q_cfage_source
generate str244 source_detail = __q_source_detail
generate str244 temporary_action = "Event retained; affected field(s) made unavailable pending source review."
replace temporary_action = "Event excluded from analytical Step 2 output pending source review." if __q_full == 1
generate str244 analytical_impact = "Event remains available for analyses that do not require quarantined field(s)."
replace analytical_impact = "Event does not contribute to downstream analytical datasets until corrected and rerun." if __q_full == 1
replace analytical_impact = "Event retained for safe all-age analyses but unavailable for age-dependent analyses until corrected." if __q_full == 0 & strpos(__q_fields, "age") > 0
generate str20 review_status = "pending"
generate str244 review_note = ""
keep source_row recid redcap_event_name quarantine_level review_reason affected_fields source_dob source_edate source_cfage source_detail temporary_action analytical_impact review_status review_note
sort source_row
save "`quarantine_worklist'", replace
restore

quietly count if __q_full == 1
local full_quarantine_n = r(N)
quietly count if __q_partial == 1 & __q_full == 0
local partial_quarantine_n = r(N)
local quarantined_n = `full_quarantine_n' + `partial_quarantine_n'

drop if __q_full == 1
quietly count
local n_post = r(N)
if `n_post' == 0 & `n_post_source' > 0 {
    do "$BNR_STATA/metrics/cvd/bnr_step2_write_quarantine_report.do" "`quarantine_worklist'" "`quarantine_dta'" "`quarantine_xlsx'" "`quarantine_summary'" "cvd_`year4'_`month2'" "`n_post_source'" "`n_post'"
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' "All post-2023 source events were fully quarantined. Review the quarantine report before rerunning."
}

generate byte qa_quarantine_partial = __q_partial == 1
label variable qa_quarantine_partial "Step 2 partial source quarantine applied"
drop __q_source_row __q_full __q_partial __q_reason __q_fields __q_source_detail __q_dob_source __q_edate_source __q_cfage_source

quietly count if redcap_event_name == "stroke_arm_1"
local n_stroke = r(N)
quietly count if redcap_event_name == "heart_arm_2"
local n_ami = r(N)
quietly summarize edate
local min_event : display %tdCCYY-NN-DD r(min)
local max_event : display %tdCCYY-NN-DD r(max)

generate byte source_era = 1
generate long source_release = `period'
label define source_era_ 0 "Frozen 2009-2023" 1 "Post-2023 REDCap", replace
label values source_era source_era_
label variable source_release "Selected source release (YYYYMM)"
save "`post2023'", replace

* The quarantine report is written before the historical append. Its detailed
* rows remain private while its one-row summary can travel with the release.
do "$BNR_STATA/metrics/cvd/bnr_step2_write_quarantine_report.do" "`quarantine_worklist'" "`quarantine_dta'" "`quarantine_xlsx'" "`quarantine_summary'" "cvd_`year4'_`month2'" "`n_post_source'" "`n_post'"

* -----------------------------------------------------------------------------
* 4. LOAD THE FROZEN HISTORY AND APPEND THE RETAINED POST-2023 RELEASE
* -----------------------------------------------------------------------------
capture use "`historical_file'", clear
if _rc {
    local use_rc = _rc
    _bnr_step2_fail `use_rc' "`year4'-`month2'" `"`output_log'"' "The frozen 2009-2023 dataset could not be opened."
}
quietly count
local n_historical = r(N)
quietly ds
local k_historical : word count `r(varlist)'
if `n_historical' != 16306 | `k_historical' != 145 {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' `"Historical source contract failed: expected 16,306 records and 145 fields; found `n_historical' records and `k_historical' fields."'
}

generate byte source_era = 0
generate long source_release = 202312
label define source_era_ 0 "Frozen 2009-2023" 1 "Post-2023 REDCap", replace
label values source_era source_era_
label variable source_release "Selected source release (YYYYMM)"

capture append using "`post2023'"
if _rc {
    local append_rc = _rc
    _bnr_step2_fail `append_rc' "`year4'-`month2'" `"`output_log'"' "The selected post-2023 release could not be appended safely."
}
replace qa_quarantine_partial = 0 if missing(qa_quarantine_partial)

quietly count
local n_total = r(N)
local expected_total = `n_historical' + `n_post'
if `n_total' != `expected_total' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' "Record-count failure after appending the retained post-2023 release."
}

* -----------------------------------------------------------------------------
* 5. CREATE THE COMMON ANALYTICAL VARIABLES
* -----------------------------------------------------------------------------
generate str32 eid = "H" + strofreal(pid, "%09.0f") if source_era == 0
replace eid = "R" + strtrim(recid) + "_" + redcap_event_name if source_era == 1
label variable eid "CVD event unique identifier"
capture quietly isid eid
if _rc {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' "The combined dataset does not contain one unique eid per retained event."
}

clonevar rid = recid
label variable rid "REDCap record ID"
generate byte dco_alt = 0
replace dco_alt = 2 if source_era == 0 & sd_absstatus == 2
replace dco_alt = 1 if source_era == 0 & sd_absstatus == 3
generate byte dco = 0
replace dco = 1 if source_era == 0 & sd_absstatus == 3
label define dco_alt_ 0 "Abstracted" 1 "DCO" 2 "Partial abstraction", replace
label define dco_ 0 "Abstracted" 1 "DCO", replace
label values dco_alt dco_alt_
label values dco dco_
label variable dco_alt "Abstraction status"
label variable dco "Death-certificate-only case"
note dco: Post-2023 releases currently contain abstracted cases only; DCO surveillance is not yet included.

generate byte etype = 1 if redcap_event_name == "stroke_arm_1"
replace etype = 2 if redcap_event_name == "heart_arm_2"
label define etype_ 1 "Stroke" 2 "AMI", replace
label values etype etype_
label variable etype "CVD event type"
capture assert inlist(etype, 1, 2)
if _rc {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' "A retained record has an unrecognised event type."
}

clonevar docf = cfdoa
clonevar doe = edate
clonevar doa = cfadmdate
clonevar dodi = dlc
clonevar dod = cfdod
clonevar doecg = ecgd
clonevar dore = reperfd
clonevar doasp = aspd
clonevar doasu = astrunitd
clonevar dodisu = dstrunitd
format docf doe doa dodi dod doecg dore doasp doasu dodisu %tdCCYY-NN-DD

generate int yoe = year(doe)
generate byte moe = month(doe)
label variable yoe "CVD event year"
label variable moe "CVD event month"

generate byte htoe = real(substr(etime, 1, 2))
generate byte mtoe = real(substr(etime, 4, 2))
generate byte htoa = real(substr(admtime, 1, 2))
generate byte mtoa = real(substr(admtime, 4, 2))
generate byte htecg = real(substr(ecgt, 1, 2))
generate byte mtecg = real(substr(ecgt, 4, 2))
generate byte htore = real(substr(reperft, 1, 2))
generate byte mtore = real(substr(reperft, 4, 2))
generate byte htoasp = real(substr(aspt, 1, 2))
generate byte mtoasp = real(substr(aspt, 4, 2))

generate int agey = floor(cfage) if source_era == 0
replace agey = age(dob, doe) if source_era == 1 & !missing(dob, doe)
label variable agey "Age at event in completed years"
note agey: Through 2023, floor(cfage); from 2024, calculated from dob and event date. Unsafe post-2023 age/DOB values are partially quarantined and remain missing until source correction.
quietly count if source_era == 1 & missing(agey)
local missing_age_post = r(N)
quietly count if source_era == 1 & !missing(agey) & !inrange(agey, 0, 120)
assert r(N) == 0

recode agey (0/4=1) (5/9=2) (10/14=3) (15/19=4) (20/24=5) (25/29=6) (30/34=7) (35/39=8) (40/44=9) (45/49=10) (50/54=11) (55/59=12) (60/64=13) (65/69=14) (70/74=15) (75/79=16) (80/84=17) (85/120=18), generate(age5)
label define age5_ 1 "0-4" 2 "5-9" 3 "10-14" 4 "15-19" 5 "20-24" 6 "25-29" 7 "30-34" 8 "35-39" 9 "40-44" 10 "45-49" 11 "50-54" 12 "55-59" 13 "60-64" 14 "65-69" 15 "70-74" 16 "75-79" 17 "80-84" 18 "85+", replace
label values age5 age5_
label variable age5 "Age at event in 5-year groups"
generate byte age70 = agey >= 70 if !missing(agey)
label define age70_ 0 "Under 70 years" 1 "70 years and older", replace
label values age70 age70_
label variable age70 "Age at event: under 70 or 70+"

clonevar sadi = vstatus
clonevar sbp = sysbp
clonevar dbp = diasbp
clonevar asp1 = asp___1
clonevar asp2 = asp___2
clonevar asp3 = asp___3
clonevar asp_ampm = asptimeampm_2
clonevar aspdose_dis = aspdosedis
clonevar sunit = strunit
clonevar doasu_same = sunitadmsame
clonevar dodisu_same = sunitdissame
forvalues medication = 1/10 {
    clonevar dmed`medication' = dismeds___`medication'
}

mvdecode sadi, mv(99=.a)
mvdecode pstroke pami htn diab ecg repertype sunit doasu_same dodisu_same, mv(99=.a)
mvdecode pstrokeyr, mv(99=.a \ 9999=.b \ 1=.c \ 1908=.c)
mvdecode pamiyr, mv(99=.a \ 9999=.b)
mvdecode sbp dbp, mv(999=.a \ 99999=.b)
mvdecode trop1res trop2res, mv(0=.a)
foreach variable in trop1res trop2res {
    replace `variable' = .b if !missing(`variable') & round(`variable', .01) == 9999.99
}
mvdecode assess assess1 assess2 assess3 assess4 ct reperf, mv(99=.a \ 99999=.b)
mvdecode aspdose, mv(999=.a)
mvdecode aspdose_dis, mv(99=.a \ 999=.b)
recode parish (99=.)

clonevar id_fname = fname
clonevar id_mname = mname
clonevar id_lname = lname
clonevar id_nid = natregno
clonevar id_hid = recnum
order eid rid source_era source_release qa_quarantine_partial dco dco_alt etype docf dob doe yoe moe htoe mtoe doa htoa mtoa dodi sadi dod sex agey age5 age70
order id_fname id_mname id_lname id_nid id_hid, last
compress
sort doe etype eid

* -----------------------------------------------------------------------------
* 6. FINAL PRIVATE QA, DATASET AND RECEIPT
* -----------------------------------------------------------------------------
quietly count if source_era == 0
local final_historical = r(N)
quietly count if source_era == 1
local final_post = r(N)
quietly count
local final_total = r(N)
if `final_historical' != `n_historical' | `final_post' != `n_post' | `final_total' != `expected_total' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' "Final record-count QA failed before saving the confidential dataset."
}
capture quietly isid eid
if _rc {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' "Final identifier QA failed before saving the confidential dataset."
}

preserve
keep eid etype doe source_release
sort eid
capture quietly datasignature, nonames
if _rc local data_signature "not_available"
else local data_signature "`r(datasignature)'"
restore

local quarantine_status "clear"
if `quarantined_n' > 0 local quarantine_status "review_pending"

label data "BNR CVD confidential cumulative analytical dataset through `end_date'"
notes _dta: title: BNR CVD confidential cumulative analytical dataset
notes _dta: dataset_id: `output_id'
notes _dta: created: `today_iso'
notes _dta: temporal: 2009 through `end_date'
notes _dta: tier: Confidential identifiable individual-level data
notes _dta: unit_of_analysis: One row per retained CVD event
notes _dta: source_historical: `historical_file'
notes _dta: source_post_2023: `release_file'
notes _dta: source_quarantine_status: `quarantine_status'
notes _dta: source_quarantined_events: `quarantined_n'
notes _dta: source_quarantine_report: `quarantine_xlsx'
notes _dta: coverage_limitation: Post-2023 DCO cases are not yet included
notes _dta: rights: Restricted to authorised BNR use; not for public release

capture save "`output_dta'", replace
if _rc {
    local save_rc = _rc
    _bnr_step2_fail `save_rc' "`year4'-`month2'" `"`output_log'"' "The confidential cumulative Stata dataset could not be saved."
}

tempname yaml
file open `yaml' using "`output_yml'", write text replace
file write `yaml' "dataset_id: `output_id'" _n
file write `yaml' "status: confidential" _n
file write `yaml' "created: `today_iso'" _n
file write `yaml' `"created_by: "`analyst'""' _n
file write `yaml' "release: `year4'-`month2'" _n
file write `yaml' "coverage_end: `end_date'" _n
file write `yaml' "records_historical: `n_historical'" _n
file write `yaml' "records_post_2023_source: `n_post_source'" _n
file write `yaml' "records_post_2023_retained: `n_post'" _n
file write `yaml' "records_total: `n_total'" _n
file write `yaml' "records_stroke_post_2023: `n_stroke'" _n
file write `yaml' "records_ami_post_2023: `n_ami'" _n
file write `yaml' "fields_post_2023_source: `k_post'" _n
file write `yaml' "event_date_min_post_2023: `min_event'" _n
file write `yaml' "event_date_max_post_2023: `max_event'" _n
file write `yaml' "missing_age_post_2023: `missing_age_post'" _n
file write `yaml' "quarantine_status: `quarantine_status'" _n
file write `yaml' "quarantined_events: `quarantined_n'" _n
file write `yaml' "fully_quarantined_events: `full_quarantine_n'" _n
file write `yaml' "partially_quarantined_events: `partial_quarantine_n'" _n
file write `yaml' `"quarantine_report_dta: "`quarantine_dta'""' _n
file write `yaml' `"quarantine_report_xlsx: "`quarantine_xlsx'""' _n
file write `yaml' `"quarantine_summary: "`quarantine_summary'""' _n
file write `yaml' `"data_signature_core: "`data_signature'""' _n
file write `yaml' "dco_post_2023_included: false" _n
file write `yaml' `"source_historical: "`historical_file'""' _n
file write `yaml' `"source_post_2023: "`release_file'""' _n
file close `yaml'

capture confirm file "`output_yml'"
if _rc {
    _bnr_step2_fail 603 "`year4'-`month2'" `"`output_log'"' "The confidential dataset YAML receipt was not created."
}
capture confirm file "`quarantine_xlsx'"
if _rc {
    _bnr_step2_fail 603 "`year4'-`month2'" `"`output_log'"' "The Step 2 quarantine report was not created."
}
capture confirm file "`quarantine_summary'"
if _rc {
    _bnr_step2_fail 603 "`year4'-`month2'" `"`output_log'"' "The Step 2 quarantine summary was not created."
}

* -----------------------------------------------------------------------------
* 7. OPERATIONAL SUMMARY
* -----------------------------------------------------------------------------
local n_historical_display : display %12.0fc `n_historical'
local n_post_source_display : display %12.0fc `n_post_source'
local n_post_display : display %12.0fc `n_post'
local n_total_display : display %12.0fc `n_total'
local quarantined_display : display %12.0fc `quarantined_n'
local full_display : display %12.0fc `full_quarantine_n'
local partial_display : display %12.0fc `partial_quarantine_n'
local run_status "Completed successfully"
if `quarantined_n' > 0 local run_status "Completed with quarantine review"

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 2: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             `run_status'"
noisily display as text   "  Script version:         1.3.0"
noisily display as text   "  Selected release:       `year4'-`month2'"
noisily display as text   "  Historical records:     `n_historical_display'"
noisily display as text   "  Post-2023 source:       `n_post_source_display'"
noisily display as text   "  Post-2023 retained:     `n_post_display'"
noisily display as text   "  Total retained records: `n_total_display'"
noisily display as text   "  Quarantined events:     `quarantined_display'"
noisily display as text   "    Fully quarantined:    `full_display'"
noisily display as text   "    Partially quarantined:`partial_display'"
noisily display as text   "  Missing post-2023 age:  `missing_age_post'"
noisily display as text   "  Quarantine status:      `quarantine_status'"
noisily display as text  `"  Quarantine report:      `quarantine_xlsx'"'
noisily display as text   "  DCO limitation:         Post-2023 DCO records are not yet included."
noisily display as text  `"  Private dataset:        `output_dta'"'
noisily display as text  `"  YAML receipt:           `output_yml'"'
noisily display as text  `"  Private log:            `output_log'"'
noisily display as text   "  Next step:              Create de-identified metric-input datasets (Step 3)."
noisily display as result "============================================================================="
}

quietly log close step2
capture program drop _bnr_step2_fail

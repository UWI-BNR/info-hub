/*******************************************************************************
DO-FILE:     bnr_step2_cvd_confidential.do
VERSION:     1.2.0 (27 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 2 - build the confidential cumulative CVD dataset

PURPOSE
    Combine the frozen 2009-2023 CVD dataset with one selected cumulative
    post-2023 REDCap release from Step 1. Harmonise the two eras, create the
    shared analytical variables, and save one confidential cumulative dataset.

ROUTINE ANALYST INPUTS
    Analysts normally provide only:

        1. release year; and
        2. release month.

    Example:

        do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 3

    The dialog supplies the same two values. Analysts should not normally edit
    the internal sections of this DO-file.

INPUTS
    Frozen historical source:
        $BNR_DATA_FROZEN/releases/y2023/m12/
            bnr-cvd-indiv-full-202312-v01.dta

    Selected cumulative Step 1 source:
        $BNR_DATA_RAW/redcap/cvd/yYYYY/mMM/
            bnr_cvd_redcap_raw_YYYYMM.dta

OUTPUTS
    $BNR_DATA_DERIVED/cvd/yYYYY/mMM/
        bnr_cvd_confidential_YYYYMM_v01.dta
        bnr_cvd_confidential_YYYYMM_v01.yml

    $BNR_PRIVATE_LOGS/
        bnr_cvd_prepare_confidential_YYYYMM.log

SECURITY
    Every input and output is confidential and remains outside Git. Step 2 does
    not de-identify data, calculate metrics, create a staging package, approve
    publication, or copy files to the website.

IMPORTANT METHOD RULES
    - No records are deliberately excluded in Step 2.
    - Through 2023, age at event follows the approved floor(cfage) rule.
    - From 2024, age is calculated from date of birth and event date.
    - Post-2023 extracts currently contain abstracted cases only. DCO cases are
      not yet included. A future DCO source will require an agreed code update.

STRUCTURE OF THIS FILE
    Sections 0-2 prepare and check the analyst's requested release.
    Sections 3-7 are internal workflow code and should rarely need changing.
*******************************************************************************/

version 19
clear all
set more off


* =============================================================================
* INTERNAL SUPPORT: STANDARD FAILURE MESSAGE
* =============================================================================
* This small program gives every controlled failure the same visible ending.
* Analysts should not normally need to alter it.

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


* =============================================================================
* 0. ANALYST INPUTS
* =============================================================================
* The year and month arrive from either the command line or the Step 2 dialog.
* No paths, filenames, variable lists or methods should need routine editing.

args release_year release_month

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Release year and month are required."
    display as error ///
        "Example: do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 3"
    exit 198
}


* =============================================================================
* 1. LOAD THE LOCAL BNR PATH CONFIGURATION
* =============================================================================
* Most workstations load this file automatically at Stata startup. The fallback
* below allows the controller to run in a new session where paths are not yet set.
* All established info-hub-private locations remain unchanged.

if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"

    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}


* =============================================================================
* 2. CHECK THE SELECTED RELEASE AND BUILD FILE LOCATIONS
* =============================================================================

local year_num  = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Release year must be an integer of 2024 or later."
    exit 198
}

if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Release month must be an integer from 1 to 12."
    exit 198
}

local year4  : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"

* Find the final calendar day covered by the selected cumulative release.
if `month_num' == 12 {
    local end_td = mdy(12, 31, `year_num')
}
else {
    local end_td = mdy(`month_num' + 1, 1, `year_num') - 1
}

local start_td = mdy(1, 1, 2024)
local end_date : display %tdCCYY-NN-DD `end_td'

* Run metadata is defined locally. Step 2 no longer loads the much broader
* briefing globals file merely to obtain a date and username.
local today_iso : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local analyst "`c(username)'"

* Input paths are fixed by the approved workflow.
local historical_file ///
    "$BNR_DATA_FROZEN/releases/y2023/m12/bnr-cvd-indiv-full-202312-v01.dta"
local release_file ///
    "$BNR_DATA_RAW/redcap/cvd/y`year4'/m`month2'/bnr_cvd_redcap_raw_`period'.dta"

* Output names remain stable because they are data-product names, not DO-file names.
local output_root  "$BNR_DATA_DERIVED/cvd"
local output_year  "`output_root'/y`year4'"
local output_dir   "`output_year'/m`month2'"
local output_id    "bnr_cvd_confidential_`period'_v01"
local output_dta   "`output_dir'/`output_id'.dta"
local output_yml   "`output_dir'/`output_id'.yml"
local output_log   "$BNR_PRIVATE_LOGS/bnr_cvd_step2_`period'.log"

* mkdir is harmless when a folder already exists.
capture mkdir "$BNR_DATA_DERIVED"
capture mkdir "`output_root'"
capture mkdir "`output_year'"
capture mkdir "`output_dir'"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close step2
log using "`output_log'", text replace name(step2)

* Routine commands are kept quiet so analysts receive a concise operational log.
* Important progress, failures and the final summary remain visible.
quietly {

noisily display as text "BNR CVD STEP 2: CONFIDENTIAL CUMULATIVE DATASET"
noisily display as result "  Script version:   1.2.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Historical input: `historical_file'"
noisily display as result "  Post-2023 input:  `release_file'"
noisily display as result "  Private output:   `output_dta'"

* Stop immediately if either approved input is absent.
foreach required_file in "`historical_file'" "`release_file'" {
    capture confirm file "`required_file'"

    if _rc {
        _bnr_step2_fail 601 "`year4'-`month2'" `"`output_log'"' ///
            `"Required input not found: `required_file'"'
        exit _rc
    }
}

* -----------------------------------------------------------------------------
* 3. VALIDATE AND HARMONISE the selected post-2023 release
* -----------------------------------------------------------------------------

tempfile post2023
capture use "`release_file'", clear
if _rc {
    local use_rc = _rc
    _bnr_step2_fail `use_rc' "`year4'-`month2'" `"`output_log'"' ///
        "The selected Step 1 Stata dataset could not be opened."
    exit _rc
}

quietly count
local n_post = r(N)
quietly ds
local k_post : word count `r(varlist)'

local core_fields recid redcap_event_name edate dob cfage natregno recnum
foreach variable of local core_fields {
    capture confirm string variable `variable'
    if _rc {
        _bnr_step2_fail 109 "`year4'-`month2'" `"`output_log'"' ///
            "Post-2023 schema failure: `variable' is absent or is not a string."
        exit _rc
    }
}

quietly count if inlist(strtrim(recid), "", ".")
local missing_recid = r(N)
quietly count if inlist(strtrim(redcap_event_name), "", ".")
local missing_event = r(N)
quietly count if inlist(strtrim(edate), "", ".", "99")
local missing_edate = r(N)
quietly count if redcap_event_name == "stroke_arm_1"
local n_stroke = r(N)
quietly count if redcap_event_name == "heart_arm_2"
local n_ami = r(N)

tempvar duplicate_id
quietly duplicates tag recid redcap_event_name, generate(`duplicate_id')
quietly count if `duplicate_id' > 0
local duplicate_rows = r(N)
drop `duplicate_id'

if `missing_recid' | `missing_event' | `missing_edate' | `duplicate_rows' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        `"Release is unsafe: `missing_recid' missing recid; `missing_event' missing event; `missing_edate' missing event date; `duplicate_rows' duplicate row(s)."'
    exit _rc
}

* REDCap fields imported by Step 1 as strings but analytically numeric.
local numeric_fields ///
    cfsource___1 cfsource___2 cfsource___3 cfsource___4 cfsource___5 ///
    cfsource___6 cfsource___7 cfsource___8 cfsource___9 cfsource___10 ///
    cfsource___11 cfsource___12 cfsource___13 cfsource___14 ///
    cfsource___15 cfsource___16 cfsource___17 cfsource___18 ///
    cfsource___19 cfsource___20 cfsource___21 cfsource___22 ///
    cfsource___23 cfsource___24 cfsource___25 cfsource___26 ///
    cfsource___27 sex cfage cfage_da hstatus slc cstatus eligible ///
    ineligible duplicate duprec dupcheck toabs mstatus resident citizen ///
    parish ward___1 ward___2 ward___3 ward___4 ward___5 htype stype ///
    dxtype dstroke inhosp etimeampm pstroke pstrokeyr pami pamiyr ///
    rfany htn diab sysbp diasbp bgunit bgmg bgmmol dieany_2 decg ecg ///
    ecgtampm tropdone troptype tropres trop1res trop2res assess assess1 ///
    assess2 assess3 assess4 dieany dct ct reperf repertype asp___1 ///
    asp___2 asp___3 aspdose asptimeampm_2 vstatus dismeds___1 ///
    dismeds___2 dismeds___3 dismeds___4 dismeds___5 dismeds___6 ///
    dismeds___7 dismeds___8 dismeds___9 dismeds___10 aspdosedis ///
    dissysbp disdiasbp disbgmmol carunit strunit sunitadmsame ///
    sunitdissame ward___88 ward___99 ward___999 ward___9999 ///
    casefinding_demographics_complet edateyr edatemon edatemondash ///
    event_complete tests_complete asp___88 asp___99 asp___999 ///
    asp___9999 dismeds___88 dismeds___99 dismeds___999 ///
    dismeds___9999 treatment_discharge_complete

local conversion_failures 0
foreach variable of local numeric_fields {
    capture confirm string variable `variable'
    if _rc {
        display as error "Expected post-2023 numeric field is absent: `variable'"
        local ++conversion_failures
    }
    else {
        quietly count if !inlist(strtrim(`variable'), "", ".") & ///
            missing(real(strtrim(`variable')))
        if r(N) {
            display as error ///
                "`variable': " r(N) " value(s) cannot be converted to numeric."
            local conversion_failures = `conversion_failures' + r(N)
        }
    }
}

if `conversion_failures' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Post-2023 numeric conversion failed for `conversion_failures' value(s)."
    exit _rc
}

foreach variable of local numeric_fields {
    quietly replace `variable' = "" if strtrim(`variable') == "."
    quietly destring `variable', replace
}

* Blank, string ".", and string "99" are ordinary missing dates in the
* post-2023 extract. Any other unparseable value is a conversion failure.
local date_fields ///
    cfdoa dob cfadmdate dlc cfdod edate ecgd doct reperfd aspd ///
    astrunitd dstrunitd

local date_failures 0
foreach variable of local date_fields {
    capture confirm string variable `variable'
    if _rc {
        display as error "Expected post-2023 date field is absent: `variable'"
        local ++date_failures
    }
    else {
        tempvar parsed_date
        quietly generate double `parsed_date' = daily(strtrim(`variable'), "YMD")
        quietly replace `parsed_date' = daily(strtrim(`variable'), "DMY") ///
            if missing(`parsed_date') & ///
            !inlist(strtrim(`variable'), "", ".", "99")
        quietly count if !inlist(strtrim(`variable'), "", ".", "99") & ///
            missing(`parsed_date')
        if r(N) {
            display as error ///
                "`variable': " r(N) " value(s) cannot be converted to a date."
            local date_failures = `date_failures' + r(N)
        }
        drop `variable'
        rename `parsed_date' `variable'
        format `variable' %tdCCYY-NN-DD
    }
}

if `date_failures' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Post-2023 date conversion failed for `date_failures' value(s)."
    exit _rc
}

quietly count if !inrange(edate, `start_td', `end_td')
local event_dates_outside = r(N)
if `event_dates_outside' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "`event_dates_outside' event date(s) fall outside the selected cumulative period."
    exit _rc
}

quietly summarize edate
local min_event : display %tdCCYY-NN-DD r(min)
local max_event : display %tdCCYY-NN-DD r(max)

generate byte source_era = 1
generate long source_release = `period'
label define source_era_ 0 "Frozen 2009-2023" 1 "Post-2023 REDCap", replace
label values source_era source_era_
label variable source_release "Selected source release (YYYYMM)"

save `post2023', replace

* -----------------------------------------------------------------------------
* 4. LOAD THE FROZEN HISTORY AND APPEND THE SELECTED RELEASE
* -----------------------------------------------------------------------------

capture use "`historical_file'", clear
if _rc {
    local use_rc = _rc
    _bnr_step2_fail `use_rc' "`year4'-`month2'" `"`output_log'"' ///
        "The frozen 2009-2023 dataset could not be opened."
    exit _rc
}
quietly count
local n_historical = r(N)
quietly ds
local k_historical : word count `r(varlist)'

if `n_historical' != 16306 | `k_historical' != 145 {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        `"Historical source contract failed: expected 16,306 records and 145 fields; found `n_historical' records and `k_historical' fields."'
    exit _rc
}

generate byte source_era = 0
generate long source_release = 202312
label define source_era_ 0 "Frozen 2009-2023" 1 "Post-2023 REDCap", replace
label values source_era source_era_
label variable source_release "Selected source release (YYYYMM)"

capture append using `post2023'
if _rc {
    local append_rc = _rc
    _bnr_step2_fail `append_rc' "`year4'-`month2'" `"`output_log'"' ///
        "The selected post-2023 release could not be appended safely."
    exit _rc
}

quietly count
local n_total = r(N)
local expected_total = `n_historical' + `n_post'
if `n_total' != `expected_total' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Record-count failure after appending the selected release."
    exit _rc
}

* -----------------------------------------------------------------------------
* 5. CREATE THE COMMON ANALYTICAL VARIABLES - NO RECORDS ARE EXCLUDED
* -----------------------------------------------------------------------------

* Stable event identifier. Historical IDs retain the approved pid; later IDs
* use the REDCap record and event. Prefixes prevent cross-era collisions.
generate str32 eid = "H" + strofreal(pid, "%09.0f") if source_era == 0
replace eid = "R" + strtrim(recid) + "_" + redcap_event_name ///
    if source_era == 1
label variable eid "CVD event unique identifier"

capture quietly isid eid
if _rc {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "The combined dataset does not contain one unique eid per event."
    exit _rc
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

quietly count if missing(etype)
if r(N) {
    local invalid_event_names = r(N)
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "`invalid_event_names' record(s) have an unrecognised REDCap event name."
    exit _rc
}

* Canonical analytical dates retain the original source fields alongside them.
clonevar docf  = cfdoa
clonevar doe   = edate
clonevar doa   = cfadmdate
clonevar dodi  = dlc
clonevar dod   = cfdod
clonevar doecg = ecgd
clonevar dore  = reperfd
clonevar doasp = aspd
clonevar doasu = astrunitd
clonevar dodisu = dstrunitd

format docf doe doa dodi dod doecg dore doasp doasu dodisu %tdCCYY-NN-DD

generate int yoe = year(doe)
generate byte moe = month(doe)
label variable yoe "CVD event year"
label variable moe "CVD event month"

* Time components. The original source strings remain available for QA.
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

* Period-specific approved age rules.
generate int agey = floor(cfage) if source_era == 0
replace agey = age(dob, doe) if source_era == 1 & !missing(dob, doe)
label variable agey "Age at event in completed years"
note agey: Through 2023, floor(cfage); from 2024, calculated from dob and event date.

quietly count if source_era == 1 & missing(agey)
local missing_age_post = r(N)
quietly count if !missing(agey) & !inrange(agey, 0, 120)
if r(N) {
    local implausible_ages = r(N)
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "`implausible_ages' implausible calculated age(s) detected."
    exit _rc
}

recode agey ///
    (0/4=1) (5/9=2) (10/14=3) (15/19=4) (20/24=5) ///
    (25/29=6) (30/34=7) (35/39=8) (40/44=9) (45/49=10) ///
    (50/54=11) (55/59=12) (60/64=13) (65/69=14) ///
    (70/74=15) (75/79=16) (80/84=17) (85/120=18), generate(age5)

label define age5_ ///
    1 "0-4" 2 "5-9" 3 "10-14" 4 "15-19" 5 "20-24" ///
    6 "25-29" 7 "30-34" 8 "35-39" 9 "40-44" 10 "45-49" ///
    11 "50-54" 12 "55-59" 13 "60-64" 14 "65-69" ///
    15 "70-74" 16 "75-79" 17 "80-84" 18 "85+", replace
label values age5 age5_
label variable age5 "Age at event in 5-year groups"

generate byte age70 = agey >= 70 if !missing(agey)
label define age70_ 0 "Under 70 years" 1 "70 years and older", replace
label values age70 age70_
label variable age70 "Age at event: under 70 or 70+"

* Frequently used canonical aliases. Source fields are retained to keep Step 2
* lossless and to support future metric-input definitions in Step 3.
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

* Keep sentinel handling consistent with the established 2023 preparation.
mvdecode sadi, mv(99=.a)
mvdecode pstroke pami htn diab ecg repertype sunit doasu_same dodisu_same, ///
    mv(99=.a)
* Retain the established historical treatment of legacy sentinel codes.
* The two .c codes are historical non-years, not valid years of a stroke.
mvdecode pstrokeyr, mv(99=.a \ 9999=.b \ 1=.c \ 1908=.c)
mvdecode pamiyr, mv(99=.a \ 9999=.b)
mvdecode sbp dbp, mv(999=.a \ 99999=.b)
* Troponin sentinel 9999.99 can arrive from the frozen historical file as a
* float, where binary rounding prevents an exact literal comparison. Decode
* it after rounding to two decimal places; clinical values are otherwise
* unchanged. Zero remains the established .a sentinel.
mvdecode trop1res trop2res, mv(0=.a)
foreach variable in trop1res trop2res {
    replace `variable' = .b if !missing(`variable') & ///
        round(`variable', .01) == 9999.99
}
mvdecode assess assess1 assess2 assess3 assess4 ct reperf, ///
    mv(99=.a \ 99999=.b)
mvdecode aspdose, mv(999=.a)
mvdecode aspdose_dis, mv(99=.a \ 999=.b)

* Parish code 99 is an explicit historical missing-value code.
recode parish (99=.)

* Identifiers remain only in this confidential Step 2 output.
clonevar id_fname = fname
clonevar id_mname = mname
clonevar id_lname = lname
clonevar id_nid = natregno
clonevar id_hid = recnum

order eid rid source_era source_release dco dco_alt etype ///
    docf dob doe yoe moe htoe mtoe doa htoa mtoa dodi sadi dod ///
    sex agey age5 age70
order id_fname id_mname id_lname id_nid id_hid, last

compress
sort doe etype eid

* -----------------------------------------------------------------------------
* 6. RUN FINAL PRIVATE QA, SAVE THE DATASET AND WRITE ITS RECEIPT
* -----------------------------------------------------------------------------

quietly count if source_era == 0
local final_historical = r(N)
quietly count if source_era == 1
local final_post = r(N)
quietly count
local final_total = r(N)
if `final_historical' != `n_historical' | `final_post' != `n_post' | ///
        `final_total' != `expected_total' {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Final record-count QA failed before saving the confidential dataset."
    exit _rc
}
capture quietly isid eid
if _rc {
    _bnr_step2_fail 459 "`year4'-`month2'" `"`output_log'"' ///
        "Final identifier QA failed before saving the confidential dataset."
    exit _rc
}

preserve
keep eid etype doe source_release
sort eid
capture quietly datasignature, nonames
if _rc local data_signature "not_available"
else local data_signature "`r(datasignature)'"
restore

label data "BNR CVD confidential cumulative analytical dataset through `end_date'"
notes _dta: title: BNR CVD confidential cumulative analytical dataset
notes _dta: dataset_id: `output_id'
notes _dta: created: `today_iso'
notes _dta: temporal: 2009 through `end_date'
notes _dta: tier: Confidential identifiable individual-level data
notes _dta: unit_of_analysis: One row per CVD event
notes _dta: source_historical: `historical_file'
notes _dta: source_post_2023: `release_file'
notes _dta: coverage_limitation: Post-2023 DCO cases are not yet included
notes _dta: rights: Restricted to authorised BNR use; not for public release

capture save "`output_dta'", replace
if _rc {
    local save_rc = _rc
    _bnr_step2_fail `save_rc' "`year4'-`month2'" `"`output_log'"' ///
        "The confidential cumulative Stata dataset could not be saved."
    exit _rc
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
file write `yaml' "records_post_2023: `n_post'" _n
file write `yaml' "records_total: `n_total'" _n
file write `yaml' "records_stroke_post_2023: `n_stroke'" _n
file write `yaml' "records_ami_post_2023: `n_ami'" _n
file write `yaml' "fields_post_2023_source: `k_post'" _n
file write `yaml' "event_date_min_post_2023: `min_event'" _n
file write `yaml' "event_date_max_post_2023: `max_event'" _n
file write `yaml' "missing_age_post_2023: `missing_age_post'" _n
file write `yaml' `"data_signature_core: "`data_signature'""' _n
file write `yaml' "dco_post_2023_included: false" _n
file write `yaml' `"source_historical: "`historical_file'""' _n
file write `yaml' `"source_post_2023: "`release_file'""' _n
file close `yaml'

capture confirm file "`output_yml'"
if _rc {
    _bnr_step2_fail 603 "`year4'-`month2'" `"`output_log'"' ///
        "The confidential dataset YAML receipt was not created."
    exit _rc
}


* =============================================================================
* 7. DISPLAY ONE CLEAR OPERATIONAL SUMMARY
* =============================================================================
* Direct display statements are deliberately used instead of constructing a
* temporary summary dataset. This is longer on the page but easier to maintain.

local n_historical_display : display %12.0fc `n_historical'
local n_post_display       : display %12.0fc `n_post'
local n_stroke_display     : display %12.0fc `n_stroke'
local n_ami_display        : display %12.0fc `n_ami'
local n_total_display      : display %12.0fc `n_total'

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 2: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             Completed successfully"
noisily display as text   "  Script version:         1.2.0"
noisily display as text   "  Selected release:       `year4'-`month2'"
noisily display as text   "  Historical records:     `n_historical_display'"
noisily display as text   "  Post-2023 records:      `n_post_display'"
noisily display as text   "  Post-2023 stroke:       `n_stroke_display'"
noisily display as text   "  Post-2023 AMI:          `n_ami_display'"
noisily display as text   "  Total records:          `n_total_display'"
noisily display as text   "  Post-2023 dates:        `min_event' through `max_event'"
noisily display as text   "  Missing post-2023 age:  `missing_age_post'"
noisily display as text   "  DCO limitation:         Post-2023 DCO records are not yet included."
noisily display as text  `"  Private dataset:        `output_dta'"'
noisily display as text  `"  YAML receipt:           `output_yml'"'
noisily display as text  `"  Private log:            `output_log'"'
noisily display as text   "  Next step:              Create de-identified metric-input datasets (Step 3)."
noisily display as result "============================================================================="

}

quietly log close step2
capture program drop _bnr_step2_fail

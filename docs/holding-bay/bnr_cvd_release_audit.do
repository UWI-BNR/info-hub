/*******************************************************************************
DO-FILE:     bnr_cvd_release_audit.do
PROJECT:     BNR Refit Phase 2
PURPOSE:     Development audit for a selected post-2023 cumulative CVD release.
             Produces a non-disclosive, aggregate-only QA log to inform Step 1.

USAGE:       Run from the info-hub repository root:

                 do "scripts/stata/monthly/bnr_cvd_release_audit.do" 2024 1

             Repeat for each candidate cumulative release (for example months
             1, 2 and 3). The selected source is never altered.

INPUT:       $BNR_DATA_RAW/redcap/cvd/yYYYY/mMM/
             bnr_cvd_redcap_raw_YYYYMM.dta

OUTPUT:      $BNR_PRIVATE_LOGS/bnr_cvd_release_audit_YYYYMM.log

SECURITY:    The log contains structure and aggregate QA only. It must not list
             names, patient identifiers, addresses, free text or record-level
             values. The log remains a private operational file.

STATUS:      Temporary development utility. Its accepted checks will later be
             incorporated into the production Step 1 preparation DO file.
*******************************************************************************/

version 19
set more off

* -----------------------------------------------------------------------------
* 0. Read arguments and load local paths
* -----------------------------------------------------------------------------

args release_year release_month

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Year and month are required."
    display as error ///
        "Example: do scripts/stata/monthly/bnr_cvd_release_audit.do 2024 1"
    exit 198
}

if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    local config_rc = _rc
    if `config_rc' {
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

if `"$BNR_DATA_RAW"' == "" | `"$BNR_PRIVATE_LOGS"' == "" {
    display as error "The BNR local path configuration is incomplete."
    exit 198
}

* -----------------------------------------------------------------------------
* 1. Validate and standardise the requested release
* -----------------------------------------------------------------------------

local year_num  = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Year must be an integer greater than or equal to 2024."
    exit 198
}

if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Month must be an integer from 1 to 12."
    exit 198
}

local year4  : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"

if `month_num' == 12 {
    local end_td = mdy(12, 31, `year_num')
}
else {
    local end_td = mdy(`month_num' + 1, 1, `year_num') - 1
}

local start_td = mdy(1, 1, 2024)
local start_date : display %tdCCYY-NN-DD `start_td'
local end_date   : display %tdCCYY-NN-DD `end_td'

local release_dir ///
    "$BNR_DATA_RAW/redcap/cvd/y`year4'/m`month2'"
local source_file ///
    "`release_dir'/bnr_cvd_redcap_raw_`period'.dta"
local audit_log ///
    "$BNR_PRIVATE_LOGS/bnr_cvd_release_audit_`period'.log"

capture confirm file "`source_file'"
if _rc {
    display as error "The selected Step 0 release was not found:"
    display as error "  `source_file'"
    exit 601
}

capture mkdir "$BNR_PRIVATE"
capture mkdir "$BNR_PRIVATE/logs"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close release_audit
log using "`audit_log'", text replace name(release_audit)

display as text "BNR CVD POST-2023 RELEASE AUDIT"
display as text "Private aggregate QA: no record-level values are shown"
display as result "  Selected release: `year4'-`month2'"
display as result "  Intended period:  `start_date' through `end_date'"
display as result "  Source:           `source_file'"

* Work in a temporary frame so the analyst's open dataset remains unchanged.
tempname audit_frame
frame create `audit_frame'
frame `audit_frame': use "`source_file'", clear

frame `audit_frame': quietly count
local n_records = r(N)
frame `audit_frame': quietly ds
local n_fields : word count `r(varlist)'

display as text ""
display as text "A. RELEASE SIZE"
display as result "  Records: `n_records'"
display as result "  Fields:  `n_fields'"

* -----------------------------------------------------------------------------
* 2. Confirm fields required to identify and date every event
* -----------------------------------------------------------------------------

local core_fields ///
    recid redcap_event_name edate dob cfage natregno recnum

local missing_core 0
foreach variable of local core_fields {
    frame `audit_frame': capture confirm variable `variable'
    if _rc {
        display as error "  Missing required field: `variable'"
        local ++missing_core
    }
}

if `missing_core' {
    display as error ""
    display as error ///
        "AUDIT STOPPED: `missing_core' required field(s) are absent."
    frame drop `audit_frame'
    log close release_audit
    exit 111
}

* The current Step 0 contract imports all REDCap fields as strings. A storage
* type change is not necessarily wrong, but must be reviewed before Step 1.
local nonstring_core 0
foreach variable of local core_fields {
    frame `audit_frame': capture confirm string variable `variable'
    if _rc {
        display as error "  Unexpected non-string field: `variable'"
        local ++nonstring_core
    }
}

if `nonstring_core' {
    display as error ""
    display as error ///
        "AUDIT STOPPED: `nonstring_core' core field(s) changed storage type."
    frame drop `audit_frame'
    log close release_audit
    exit 109
}

display as text ""
display as text "B. CORE FIELD COMPLETENESS"

foreach variable in recid redcap_event_name edate natregno recnum {
    frame `audit_frame': quietly count if trim(`variable') == ""
    display as result ///
        "  Missing `variable': " %9.0fc r(N)
}

* -----------------------------------------------------------------------------
* 3. Event-date coverage and release composition
* -----------------------------------------------------------------------------

tempvar event_date event_year
frame `audit_frame': generate double `event_date' = daily(trim(edate), "YMD")
frame `audit_frame': replace `event_date' = daily(trim(edate), "DMY") ///
    if missing(`event_date') & trim(edate) != ""
frame `audit_frame': format `event_date' %tdCCYY-NN-DD

frame `audit_frame': quietly count if trim(edate) != "" & missing(`event_date')
local invalid_event_dates = r(N)

frame `audit_frame': quietly count if !missing(`event_date') & ///
    !inrange(`event_date', `start_td', `end_td')
local event_dates_outside = r(N)

frame `audit_frame': quietly summarize `event_date'
local dated_records = r(N)
if `dated_records' > 0 {
    local min_event_date : display %tdCCYY-NN-DD r(min)
    local max_event_date : display %tdCCYY-NN-DD r(max)
}
else {
    local min_event_date "not available"
    local max_event_date "not available"
}

display as text ""
display as text "C. EVENT-DATE COVERAGE"
display as result "  Earliest valid event date: `min_event_date'"
display as result "  Latest valid event date:   `max_event_date'"
display as result ///
    "  Non-empty event dates that cannot be parsed: " ///
    %9.0fc `invalid_event_dates'
display as result ///
    "  Event dates outside intended cumulative period: " ///
    %9.0fc `event_dates_outside'

frame `audit_frame': generate int `event_year' = year(`event_date')

display as text ""
display as text "  Records by event year"
frame `audit_frame': tabulate `event_year', missing

display as text ""
display as text "  Records by REDCap event"
frame `audit_frame': tabulate redcap_event_name, missing

* -----------------------------------------------------------------------------
* 4. Duplicate identifiers
* -----------------------------------------------------------------------------

tempvar duplicate_event duplicate_recid
frame `audit_frame': quietly duplicates tag recid redcap_event_name, ///
    generate(`duplicate_event')
frame `audit_frame': quietly count if `duplicate_event' > 0
local duplicate_event_rows = r(N)

frame `audit_frame': quietly duplicates tag recid, generate(`duplicate_recid')
frame `audit_frame': quietly count if `duplicate_recid' > 0
local duplicate_recid_rows = r(N)

display as text ""
display as text "D. DUPLICATE IDENTIFIERS"
display as result ///
    "  Rows sharing recid + REDCap event: " %9.0fc `duplicate_event_rows'
display as result ///
    "  Rows sharing recid (any event):     " %9.0fc `duplicate_recid_rows'

* -----------------------------------------------------------------------------
* 5. Non-empty strings that cannot be converted to numbers
* -----------------------------------------------------------------------------

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

local numeric_fields_present 0
local numeric_fields_missing 0
local numeric_failure_total 0

display as text ""
display as text "E. NUMERIC-CONVERSION CHECK"

foreach variable of local numeric_fields {
    frame `audit_frame': capture confirm variable `variable'
    if _rc {
        local ++numeric_fields_missing
        display as error "  Expected numeric field absent: `variable'"
    }
    else {
        local ++numeric_fields_present
        frame `audit_frame': capture confirm string variable `variable'
        if _rc {
            display as error ///
                "  Expected string field is already numeric: `variable'"
        }
        else {
            frame `audit_frame': quietly count if trim(`variable') != "" & ///
                missing(real(trim(`variable')))
            local failures = r(N)
            if `failures' > 0 {
                display as error ///
                    "  `variable': " %9.0fc `failures' " failed conversion(s)"
                local numeric_failure_total = ///
                    `numeric_failure_total' + `failures'
            }
        }
    }
}

display as result ///
    "  Numeric fields checked: " %9.0fc `numeric_fields_present'
display as result ///
    "  Expected numeric fields absent: " %9.0fc `numeric_fields_missing'
display as result ///
    "  Total non-empty values failing numeric conversion: " ///
    %9.0fc `numeric_failure_total'

* -----------------------------------------------------------------------------
* 6. Date-conversion checks
* -----------------------------------------------------------------------------

local date_fields ///
    cfdoa dob cfadmdate dlc cfdod edate ecgd doct reperfd aspd ///
    astrunitd dstrunitd

local date_fields_present 0
local date_fields_missing 0
local date_failure_total 0

display as text ""
display as text "F. DATE-CONVERSION CHECK"

foreach variable of local date_fields {
    frame `audit_frame': capture confirm variable `variable'
    if _rc {
        local ++date_fields_missing
        display as error "  Expected date field absent: `variable'"
    }
    else {
        local ++date_fields_present
        frame `audit_frame': capture confirm string variable `variable'
        if _rc {
            display as error ///
                "  Expected string date is already numeric: `variable'"
        }
        else {
            tempvar parsed_date
            frame `audit_frame': generate double `parsed_date' = ///
                daily(trim(`variable'), "YMD")
            frame `audit_frame': replace `parsed_date' = ///
                daily(trim(`variable'), "DMY") ///
                if missing(`parsed_date') & trim(`variable') != ""
            frame `audit_frame': quietly count if trim(`variable') != "" & ///
                missing(`parsed_date')
            local failures = r(N)
            if `failures' > 0 {
                display as error ///
                    "  `variable': " %9.0fc `failures' " failed conversion(s)"
                local date_failure_total = `date_failure_total' + `failures'
            }
            frame `audit_frame': drop `parsed_date'
        }
    }
}

display as result ///
    "  Date fields checked: " %9.0fc `date_fields_present'
display as result ///
    "  Expected date fields absent: " %9.0fc `date_fields_missing'
display as result ///
    "  Total non-empty values failing date conversion: " ///
    %9.0fc `date_failure_total'

* -----------------------------------------------------------------------------
* 7. Post-2023 age-at-event QA
* -----------------------------------------------------------------------------

tempvar birth_date age_event cfage_numeric
frame `audit_frame': generate double `birth_date' = daily(trim(dob), "YMD")
frame `audit_frame': replace `birth_date' = daily(trim(dob), "DMY") ///
    if missing(`birth_date') & trim(dob) != ""
frame `audit_frame': generate int `age_event' = ///
    age(`birth_date', `event_date') if !missing(`birth_date', `event_date')
frame `audit_frame': generate double `cfage_numeric' = real(trim(cfage))

frame `audit_frame': quietly count if missing(`age_event')
local age_not_calculated = r(N)
frame `audit_frame': quietly count if !missing(`age_event') & ///
    !inrange(`age_event', 0, 120)
local age_implausible = r(N)
frame `audit_frame': quietly count if !missing(`age_event', `cfage_numeric') & ///
    `age_event' != floor(`cfage_numeric')
local age_disagreements = r(N)

display as text ""
display as text "G. AGE AT EVENT"
display as result ///
    "  Age cannot be calculated from DOB + event date: " ///
    %9.0fc `age_not_calculated'
display as result ///
    "  Calculated age outside 0-120 years: " %9.0fc `age_implausible'
display as result ///
    "  Calculated age differs from floor(cfage): " ///
    %9.0fc `age_disagreements'

* -----------------------------------------------------------------------------
* 8. Data signature and compact verdict
* -----------------------------------------------------------------------------

frame `audit_frame': capture quietly datasignature, nonames
if _rc {
    local data_signature "not available"
}
else {
    local data_signature "`r(datasignature)'"
}

local critical_issues = `invalid_event_dates' + `event_dates_outside' + ///
    `duplicate_event_rows'
local review_issues = `numeric_fields_missing' + `numeric_failure_total' + ///
    `date_fields_missing' + `date_failure_total' + `age_implausible'

display as text ""
display as text "H. AUDIT VERDICT"
display as result "  Data signature: `data_signature'"
display as result ///
    "  Critical issue count: " %9.0fc `critical_issues'
display as result ///
    "  Additional items requiring review: " %9.0fc `review_issues'

if `critical_issues' == 0 & `review_issues' == 0 {
    display as result ///
        "  RESULT: No structural or conversion problems detected."
}
else if `critical_issues' > 0 {
    display as error ///
        "  RESULT: Critical problems detected; do not use this release in Step 1."
}
else {
    display as error ///
        "  RESULT: Review the flagged conversion or schema items before Step 1."
}

display as text ""
display as text "KNOWN COVERAGE LIMITATION"
display as text ///
    "  Current post-2023 REDCap releases contain abstracted records only."
display as text ///
    "  DCO records are not yet included and will require a later extension."
display as text ""
display as result "Audit log: `audit_log'"

frame drop `audit_frame'
log close release_audit

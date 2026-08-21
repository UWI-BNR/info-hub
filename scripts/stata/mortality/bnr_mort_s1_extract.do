/*******************************************************************************
DO-FILE:     bnr_mort_s1_extract.do
VERSION:     0.9.0 (17 August 2026)
PROJECT:     BNR Refit Phase 2
PURPOSE:     Step 1 of the mortality workflow. Extract the REDCap
             death-certificate form only and create a private all-deaths
             analytical dataset through a selected month-end.

USAGE:       Run from the info-hub repository root:

                 do "scripts/stata/mortality/bnr_mort_s1_extract.do" 2026 7

             If outputs for that month already exist, add replace:

                 do "scripts/stata/mortality/bnr_mort_s1_extract.do" 2026 7 replace

             The optional dialog constructs exactly the same command.

IMPORTANT:   The REDCap API extraction deliberately takes the simple route:
             it retrieves the full project export, including both REDCap arms
             and all project fields.

             Stata then:
                 1. retains death_data_collect_arm_1 only; and
                 2. keeps the 48 approved death-certificate fields.

             tracking_arm_2 is therefore present only in the private raw CSV.
             It is removed before the analytical DTA is created.


CONFIDENTIAL:
             The raw CSV and analytical DTA contain identifiable mortality
             information, including NRN and other linkage fields. They must
             remain in the private data area and must never be committed to Git.

TOKEN:       The mortality REDCap token is read directly by Python from the
             private local text file identified by:

                 $BNR_MORT_REDCAP_TOKEN_FILE

             The token itself is never stored in this DO file or in a Stata
             macro, and must never be committed to Git.

OUTPUT:      Private mortality source CSV, analytical Stata dataset,
             YAML receipt and log:
             $BNR_DATA_RAW/redcap/mortality/yYYYY/mMM/

             The API initially writes the full project to the CSV during the
             run. After Stata applies the mortality-arm, variable and date
             restrictions, the CSV is overwritten with the restricted
             mortality source extract.

DESIGN:      The API initially exports the complete REDCap project.

             Stata removes tracking_arm_2, non-death-certificate fields and
             valid deaths after the selected month-end.

             The final CSV contains the restricted mortality source variables.
             The final DTA contains those source variables plus Step 1 derived
             dates, cleaned cause text and QA flags.

             The analytical DTA excludes records with a valid death date after
             the selected month-end, but retains records with a missing or
             invalid death date so that data problems are visible.

             Step 1 does not classify AMI, stroke or underlying cause of death.
             It preserves original cause text and creates cleaned text copies
             for Step 2.

ANALYST-EDITABLE INPUTS:
             Routine analysts normally change only:
             - release year;
             - release month; and
             - optional replace argument.

             The mortality API token is a one-time local workstation setting
             in Section 1 and must not be committed after population.

             DEVELOPMENT_LIMIT is an implementation setting, not a routine
             analyst input. Leave it at 1000 during development.

INTERNAL CODE:
             Sections 2 to 9 implement the approved extraction, validation,
             preparation and output process. Keep changes simple and explicit.
*******************************************************************************/

version 19
set more off


* =============================================================================
* SECTION 0 - DO NOT TOUCH THIS SECTION
* Standard failure message used by the workflow
* =============================================================================

capture program drop _bnr_mort_s1_fail
program define _bnr_mort_s1_fail
    version 19
    args return_code release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "MORTALITY STEP 1 DID NOT COMPLETE"
    noisily display as error "  Release: `release_id'"
    noisily display as error `"  Reason:  `reason'"'
    noisily display as error `"  Log:     `log_path'"'
    noisily display as text  "Do not use files from this incomplete run."
    noisily display as error "============================================================================="
    capture log close mort_extract
    exit `return_code'
end


* =============================================================================
* SECTION 1 - EDIT THIS SECTION
* Routine analyst inputs
*
* The analyst supplies the release year/month through the dialog or command
* line. No API token is stored in this DO file.
* =============================================================================

args release_year release_month replace_existing

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Year and month are required."
    display as error ///
        "Example: do scripts/stata/mortality/bnr_mort_s1_extract.do 2026 7"
    exit 198
}

* Load the existing BNR workstation paths if they are not already available.
if `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    local config_rc = _rc
    if `config_rc' {
        display as error "The BNR local path configuration could not be loaded."
        display as error ///
            "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do through profile.do."
        exit `config_rc'
    }
}

if `"$BNR_STATA"' == "" | `"$BNR_DATA_RAW"' == "" | ///
        `"$BNR_PRIVATE_LOGS"' == "" {
    display as error "The BNR local path configuration is incomplete."
    exit 198
}

if `"$BNR_MORT_REDCAP_TOKEN_FILE"' == "" {
    display as error "The mortality REDCap token-file path is not configured."
    display as error ///
        "Add BNR_MORT_REDCAP_TOKEN_FILE to bnr_paths_LOCAL.do."
    exit 198
}

local redcap_url "https://caribdata.org/redcap/api/"


* =============================================================================
* SECTION 2 - DO NOT TOUCH THIS SECTION
* Validate the requested reporting year and month
* =============================================================================

local year_num  = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2008 {
    display as error "Year must be an integer greater than or equal to 2008."
    exit 198
}

if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Month must be an integer from 1 to 12."
    exit 198
}

if "`replace_existing'" != "" & lower("`replace_existing'") != "replace" {
    display as error "The optional third argument must be replace."
    exit 198
}

if `month_num' == 12 {
    local end_td = mdy(12, 31, `year_num')
}
else {
    local end_td = mdy(`month_num' + 1, 1, `year_num') - 1
}

local end_date : display %tdCCYY-NN-DD `end_td'
local year4    : display %04.0f `year_num'
local month2   : display %02.0f `month_num'
local period   "`year4'`month2'"

* A release month must have finished before it can be extracted.
local today_td = daily("`c(current_date)'", "DMY")
if `end_td' > `today_td' {
    display as error ///
        "The selected month has not ended. Choose the latest completed month."
    exit 198
}


* =============================================================================
* SECTION 3 - DO NOT TOUCH THIS SECTION
* Define private output locations and filenames
* =============================================================================

local release_dir ///
    "$BNR_DATA_RAW/redcap/mortality/y`year4'/m`month2'"

local raw_stub ///
    "bnr_mort_s1_`period'_raw"

local data_stub ///
    "bnr_mort_s1_`period'"

local outcsv      "`release_dir'/`raw_stub'.csv"
local outdta      "`release_dir'/`data_stub'.dta"
local outmanifest "`release_dir'/`data_stub'_manifest.yml"
local outlog      "$BNR_PRIVATE_LOGS/`data_stub'.log"

capture mkdir "$BNR_PRIVATE"
capture mkdir "$BNR_PRIVATE/logs"
capture mkdir "$BNR_PRIVATE_LOGS"
capture log close mort_extract
log using "`outlog'", text replace name(mort_extract)


quietly {

noisily display as text "BNR MORTALITY STEP 1: REDCAP EXTRACTION"
noisily display as result "  Script version:   0.9.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Release cut-off:  `end_date'"
noisily display as result "  Raw API extract:  full REDCap project"
noisily display as result "  Analytical DTA:   mortality arm + death-certificate fields only"
noisily display as result "  Private output:   `release_dir'"


* =============================================================================
* SECTION 4 - DO NOT TOUCH THIS SECTION
* Protect existing Step 1 outputs from accidental replacement
* =============================================================================

local existing_output 0

foreach file in "`outcsv'" "`outdta'" "`outmanifest'" {
    capture confirm file `"`file'"'
    if !_rc {
        local existing_output 1
    }
}

if `existing_output' {
    if lower("`replace_existing'") != "replace" {
        _bnr_mort_s1_fail 602 "`year4'-`month2'" `"`outlog'"' ///
            "A mortality Step 1 extract already exists. Rerun only with explicit replace authorisation."
        exit _rc
    }

    foreach file in "`outcsv'" "`outdta'" "`outmanifest'" {
        capture confirm file `"`file'"'
        if !_rc {
            erase `"`file'"'
        }
    }
}


* =============================================================================
* SECTION 5 - DO NOT TOUCH THIS SECTION
* Extract the complete REDCap project
*
* This deliberately mirrors the proven CVD extraction pattern:
*   - no selective field list;
*   - no selective form list;
*   - no selective event list;
*   - no selected-record list.
*
* The CSV temporarily contains the full REDCap project during the run.
* Stata makes the mortality selection in Sections 6 and 7, then overwrites
* the CSV with the restricted mortality source extract.
* =============================================================================

python:
from sfi import Macro
from redcap import Project

import csv
import hashlib
import io
import os


api_url = Macro.getLocal("redcap_url")
token_file = Macro.getGlobal("BNR_MORT_REDCAP_TOKEN_FILE")
outcsv = Macro.getLocal("outcsv")


def stop(message):
    """Raise a short error that cannot reveal the API token."""
    raise RuntimeError(message) from None


if not token_file:
    stop("BNR_MORT_REDCAP_TOKEN_FILE is not defined in bnr_paths_LOCAL.do.")

if not os.path.isfile(token_file):
    stop("The local mortality REDCap token file was not found.")

with open(token_file, "r", encoding="utf-8-sig") as handle:
    api_token = handle.read().strip()

if not api_token or api_token == "PASTE_REDCAP_API_TOKEN_HERE":
    stop("The local mortality REDCap token file does not yet contain a token.")

if any(character.isspace() for character in api_token):
    stop("The mortality REDCap token file must contain only the token on one line.")


try:
    project = Project(api_url, api_token)

    csv_text = project.export_records(
        "csv",
        raw_or_label="raw",
        raw_or_label_headers="raw",
        export_checkbox_labels=False,
    )

except Exception as error:
    stop(
        "Mortality REDCap extraction failed "
        f"({type(error).__name__}). Check the API URL, token permissions "
        "and network connection."
    )


if isinstance(csv_text, bytes):
    csv_text = csv_text.decode("utf-8-sig")

reader = csv.DictReader(io.StringIO(csv_text))
headers = reader.fieldnames or []
rows = list(reader)

if not rows:
    stop("The REDCap project returned no records.")

os.makedirs(os.path.dirname(outcsv), exist_ok=True)

with open(outcsv, "w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=headers,
        extrasaction="raise",
        quoting=csv.QUOTE_ALL,
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(rows)

with open(outcsv, "rb") as handle:
    csv_sha256 = hashlib.sha256(handle.read()).hexdigest()

Macro.setLocal("raw_rows_py", str(len(rows)))
Macro.setLocal("field_count_py", str(len(headers)))
Macro.setLocal("csv_sha256_py", csv_sha256)

print(
    f"REDCap returned {len(rows):,} rows and {len(headers):,} fields "
    "before Stata mortality filtering."
)
print("The mortality token was read locally and was not written to the Stata session.")
end


* SECTION 6 - DO NOT TOUCH THIS SECTION
* Import the raw project extract, retain the mortality arm and keep only the
* approved death-certificate fields
* =============================================================================

* Fixed REDCap mortality event. Routine analysts do not edit this value.
local mort_event "death_data_collect_arm_1"

capture confirm file "`outcsv'"
if _rc {
    _bnr_mort_s1_fail 603 "`year4'-`month2'" `"`outlog'"' ///
        "The raw mortality REDCap CSV was not created."
    exit _rc
}


tempname extract_frame
frame create `extract_frame'


capture frame `extract_frame': import delimited using "`outcsv'", clear ///
    stringcols(_all) varnames(1) bindquote(strict)

if _rc {
    local import_rc = _rc
    _bnr_mort_s1_fail `import_rc' "`year4'-`month2'" `"`outlog'"' ///
        "Stata could not import the REDCap CSV."
    exit _rc
}


* ---- Check the two-arm REDCap structure -------------------------------------

capture frame `extract_frame': confirm variable record_id redcap_event_name

if _rc {
    _bnr_mort_s1_fail 111 "`year4'-`month2'" `"`outlog'"' ///
        "The raw REDCap extract is missing record_id or redcap_event_name."
    exit _rc
}


frame `extract_frame': count if redcap_event_name == "`mort_event'"
local mortality_arm_rows = r(N)

if `mortality_arm_rows' == 0 {
    _bnr_mort_s1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "No death_data_collect_arm_1 rows were found in the raw extract."
    exit _rc
}


frame `extract_frame': count if redcap_event_name == "tracking_arm_2"
local tracking_arm_rows = r(N)


frame `extract_frame': count if ///
    !inlist(redcap_event_name, "`mort_event'", "tracking_arm_2")
local unexpected_arm_rows = r(N)

if `unexpected_arm_rows' > 0 {
    _bnr_mort_s1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "The raw REDCap extract contains an unexpected event/arm."
    exit _rc
}


* ---- Retain mortality rows only ---------------------------------------------

frame `extract_frame': keep if redcap_event_name == "`mort_event'"


frame `extract_frame': count if trim(record_id) == ""
local missing_record_id = r(N)

if `missing_record_id' > 0 {
    _bnr_mort_s1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "The mortality arm contains `missing_record_id' row(s) without a record ID."
    exit _rc
}


capture frame `extract_frame': isid record_id

if _rc {
    _bnr_mort_s1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "record_id is not unique within the mortality arm."
    exit _rc
}


* ---- Check required death-certificate variables -----------------------------
* Keep this list explicit. It mirrors the supplied REDCap data dictionary and
* makes schema changes visible to future BNR staff.

capture frame `extract_frame': confirm variable ///
    record_id ///
    dddoa ddda odda certtype regnum district pname address parish ///
    sex age agetxt nrnnd nrn mstatus occu durationnum durationtxt ///
    dod dodyear ///
    cod1a onsetnumcod1a onsettxtcod1a ///
    cod1b onsetnumcod1b onsettxtcod1b ///
    cod1c onsetnumcod1c onsettxtcod1c ///
    cod1d onsetnumcod1d onsettxtcod1d ///
    cod2a onsetnumcod2a onsettxtcod2a ///
    cod2b onsetnumcod2b onsettxtcod2b ///
    pod deathparish regdate certifier certifieraddr ///
    namematch duprec cleaned elecmatch redcap_event_name

if _rc {
    _bnr_mort_s1_fail 111 "`year4'-`month2'" `"`outlog'"' ///
        "One or more required death-certificate variables are missing from the REDCap extract."
    exit _rc
}


* ---- Drop tracking/administrative fields by keeping only approved fields -----

frame `extract_frame': keep ///
    record_id ///
    dddoa ddda odda certtype regnum district pname address parish ///
    sex age agetxt nrnnd nrn mstatus occu durationnum durationtxt ///
    dod dodyear ///
    cod1a onsetnumcod1a onsettxtcod1a ///
    cod1b onsetnumcod1b onsettxtcod1b ///
    cod1c onsetnumcod1c onsettxtcod1c ///
    cod1d onsetnumcod1d onsettxtcod1d ///
    cod2a onsetnumcod2a onsettxtcod2a ///
    cod2b onsetnumcod2b onsettxtcod2b ///
    pod deathparish regdate certifier certifieraddr ///
    namematch duprec cleaned elecmatch redcap_event_name


* =============================================================================
* SECTION 7 - DO NOT TOUCH THIS SECTION
* Basic mortality preparation and retain-and-report QA
*
* Preserve all original source variables. Derived variables use short, clear
* names and do not contain cause-classification logic.
* =============================================================================

* ---- Death date and reporting period -----------------------------------------

frame `extract_frame': generate double dth_date = daily(dod, "YMD") ///
    if trim(dod) != ""
frame `extract_frame': format dth_date %tdCCYY-NN-DD
frame `extract_frame': label variable dth_date "Date of death - Stata date"

frame `extract_frame': generate int dth_year = year(dth_date) ///
    if !missing(dth_date)
frame `extract_frame': generate byte dth_month = month(dth_date) ///
    if !missing(dth_date)
frame `extract_frame': generate byte dth_qtr = ceil(month(dth_date) / 3) ///
    if !missing(dth_date)

frame `extract_frame': label variable dth_year "Reporting year"
frame `extract_frame': label variable dth_month "Reporting month"
frame `extract_frame': label variable dth_qtr "Reporting quarter"

frame `extract_frame': generate byte qa_dod = ///
    (trim(dod) == "" | missing(dth_date))
frame `extract_frame': label variable qa_dod ///
    "QA: death date missing or invalid"

frame `extract_frame': generate byte qa_pre08 = ///
    (!missing(dth_date) & dth_date < td(01jan2008))
frame `extract_frame': label variable qa_pre08 ///
    "QA: death date before expected 2008 start"

frame `extract_frame': generate byte qa_year = 0
frame `extract_frame': replace qa_year = 1 if ///
    !missing(dth_date) & ///
    (trim(dodyear) == "" | real(dodyear) != year(dth_date))
frame `extract_frame': label variable qa_year ///
    "QA: source death year disagrees with death date"

* Valid death dates after the selected release cut-off are not part of this
* analytical release. They remain preserved in the raw CSV.
frame `extract_frame': generate byte after_cut = ///
    (!missing(dth_date) & dth_date > `end_td')

frame `extract_frame': count if after_cut == 1
local after_cutoff = r(N)

frame `extract_frame': drop if after_cut == 1
frame `extract_frame': drop after_cut

* ---- Registration date ------------------------------------------------------

frame `extract_frame': generate double reg_date = daily(regdate, "YMD") ///
    if trim(regdate) != ""
frame `extract_frame': format reg_date %tdCCYY-NN-DD
frame `extract_frame': label variable reg_date ///
    "Date of registration - Stata date"

frame `extract_frame': generate byte qa_reg = ///
    (trim(regdate) == "" | missing(reg_date))
frame `extract_frame': label variable qa_reg ///
    "QA: registration date missing or invalid"

* ---- Other simple source checks ---------------------------------------------

frame `extract_frame': generate byte qa_dup = ///
    (trim(namematch) == "3" | trim(duprec) != "")
frame `extract_frame': label variable qa_dup ///
    "QA: source marks record as a possible duplicate"

frame `extract_frame': generate byte qa_cert = ///
    (trim(cod1a) == "" & trim(cod1b) == "" & trim(cod1c) == "" & ///
     trim(cod1d) == "" & trim(cod2a) == "" & trim(cod2b) == "")
frame `extract_frame': label variable qa_cert ///
    "QA: all six cause-of-death text fields are blank"

frame `extract_frame': generate byte qa_sex = ///
    !inlist(trim(sex), "1", "2", "99")
frame `extract_frame': label variable qa_sex ///
    "QA: sex code outside expected values"

frame `extract_frame': generate byte qa_age = ///
    (trim(age) == "" | missing(real(age)) | ///
     !inlist(trim(agetxt), "1", "2", "3", "4", "5", "6", "99"))
frame `extract_frame': label variable qa_age ///
    "QA: age or age-unit value missing or invalid"

frame `extract_frame': generate byte qa_any = ///
    qa_dod | qa_pre08 | qa_year | qa_reg | qa_dup | ///
    qa_cert | qa_sex | qa_age
frame `extract_frame': label variable qa_any ///
    "QA: one or more Step 1 review flags"


* ---- Clean analytical copies of certificate text ---------------------------
* Original cod1a-cod2b values are never changed.

frame `extract_frame': generate strL c1a_cln = lower(trim(itrim(cod1a)))
frame `extract_frame': replace c1a_cln = subinstr(c1a_cln, char(13), " ", .)
frame `extract_frame': replace c1a_cln = subinstr(c1a_cln, char(10), " ", .)
frame `extract_frame': replace c1a_cln = itrim(c1a_cln)

frame `extract_frame': generate strL c1b_cln = lower(trim(itrim(cod1b)))
frame `extract_frame': replace c1b_cln = subinstr(c1b_cln, char(13), " ", .)
frame `extract_frame': replace c1b_cln = subinstr(c1b_cln, char(10), " ", .)
frame `extract_frame': replace c1b_cln = itrim(c1b_cln)

frame `extract_frame': generate strL c1c_cln = lower(trim(itrim(cod1c)))
frame `extract_frame': replace c1c_cln = subinstr(c1c_cln, char(13), " ", .)
frame `extract_frame': replace c1c_cln = subinstr(c1c_cln, char(10), " ", .)
frame `extract_frame': replace c1c_cln = itrim(c1c_cln)

frame `extract_frame': generate strL c1d_cln = lower(trim(itrim(cod1d)))
frame `extract_frame': replace c1d_cln = subinstr(c1d_cln, char(13), " ", .)
frame `extract_frame': replace c1d_cln = subinstr(c1d_cln, char(10), " ", .)
frame `extract_frame': replace c1d_cln = itrim(c1d_cln)

frame `extract_frame': generate strL c2a_cln = lower(trim(itrim(cod2a)))
frame `extract_frame': replace c2a_cln = subinstr(c2a_cln, char(13), " ", .)
frame `extract_frame': replace c2a_cln = subinstr(c2a_cln, char(10), " ", .)
frame `extract_frame': replace c2a_cln = itrim(c2a_cln)

frame `extract_frame': generate strL c2b_cln = lower(trim(itrim(cod2b)))
frame `extract_frame': replace c2b_cln = subinstr(c2b_cln, char(13), " ", .)
frame `extract_frame': replace c2b_cln = subinstr(c2b_cln, char(10), " ", .)
frame `extract_frame': replace c2b_cln = itrim(c2b_cln)


* =============================================================================
* SECTION 8 - DO NOT TOUCH THIS SECTION
* Save the confidential analytical dataset and small YAML receipt
* =============================================================================

frame `extract_frame': count
local analytical_rows = r(N)

frame `extract_frame': count if qa_dod == 1
local bad_dod_rows = r(N)

frame `extract_frame': count if qa_pre08 == 1
local pre08_rows = r(N)

frame `extract_frame': count if qa_year == 1
local year_mismatch_rows = r(N)

frame `extract_frame': count if qa_dup == 1
local duplicate_flag_rows = r(N)

frame `extract_frame': count if qa_cert == 1
local blank_cert_rows = r(N)

frame `extract_frame': count if qa_any == 1
local qa_any_rows = r(N)

frame `extract_frame': count if trim(nrnnd) == "1"
local nrn_documented_rows = r(N)

frame `extract_frame': count if trim(cleaned) != "1"
local not_cleaned_rows = r(N)


* ---- Final mortality source CSV ---------------------------------------------
* The API used a broad full-project export because that pathway is robust.
* By this point Stata has already:
*   - kept death_data_collect_arm_1 only;
*   - removed tracking variables;
*   - kept the approved death-certificate variables; and
*   - removed valid death dates after the selected release cut-off.
*
* Rewrite the CSV now so the retained CSV and DTA refer to the same mortality
* release. Keep only source variables in the CSV; derived variables remain in
* the analytical DTA.

capture frame `extract_frame': export delimited ///
    record_id ///
    redcap_event_name ///
    dddoa ddda odda certtype regnum district pname address parish ///
    sex age agetxt nrnnd nrn mstatus occu durationnum durationtxt ///
    dod dodyear ///
    cod1a onsetnumcod1a onsettxtcod1a ///
    cod1b onsetnumcod1b onsettxtcod1b ///
    cod1c onsetnumcod1c onsettxtcod1c ///
    cod1d onsetnumcod1d onsettxtcod1d ///
    cod2a onsetnumcod2a onsettxtcod2a ///
    cod2b onsetnumcod2b onsettxtcod2b ///
    pod deathparish regdate certifier certifieraddr ///
    namematch duprec cleaned elecmatch ///
    using "`outcsv'", replace quote

if _rc {
    local csv_save_rc = _rc
    _bnr_mort_s1_fail `csv_save_rc' "`year4'-`month2'" `"`outlog'"' ///
        "The restricted mortality source CSV could not be saved."
    exit _rc
}


frame `extract_frame': compress
frame `extract_frame': label data ///
    "BNR private all-deaths mortality data through `end_date'"

frame `extract_frame': notes _dta: confidential: Contains identifiable mortality records
frame `extract_frame': notes _dta: source: full BNR mortality REDCap project export; analytical DTA retains death_data_collect_arm_1
frame `extract_frame': notes _dta: tracking_arm_2 present only during initial API export; removed from retained CSV and DTA
frame `extract_frame': notes _dta: selected release cut-off: `end_date'
frame `extract_frame': notes _dta: records with missing or invalid death dates are retained and flagged
frame `extract_frame': notes _dta: valid death dates after the selected cut-off are retained in the raw CSV but excluded from this DTA
frame `extract_frame': notes _dta: original cod1a-cod2b values are preserved unchanged
frame `extract_frame': notes _dta: NRN is retained confidentially for possible future linkage
frame `extract_frame': notes _dta: do not place this dataset in the Git repository

capture frame `extract_frame': save "`outdta'"

if _rc {
    local save_rc = _rc
    _bnr_mort_s1_fail `save_rc' "`year4'-`month2'" `"`outlog'"' ///
        "The private mortality analytical dataset could not be saved."
    exit _rc
}

frame drop `extract_frame'

* Write a deliberately small YAML operational receipt.
tempname manifest
file open `manifest' using "`outmanifest'", write text replace

file write `manifest' "# Private operational receipt: do not publish." _n
file write `manifest' "package_type: private_mortality_step1" _n
file write `manifest' `"source_system: "BNR mortality REDCap""' _n
file write `manifest' `"api_extract_scope: "full REDCap project export""' _n
file write `manifest' `"retained_csv_scope: "mortality arm, approved source fields, selected date cut-off""' _n
file write `manifest' `"analytical_event: "`mort_event'""' _n
file write `manifest' "tracking_arm_in_raw_extract: true" _n
file write `manifest' "tracking_arm_rows_removed: `tracking_arm_rows'" _n
file write `manifest' `"release_cutoff: "`end_date'""' _n
file write `manifest' "release_year: `year_num'" _n
file write `manifest' "release_month: `month_num'" _n
file write `manifest' "raw_rows: `raw_rows_py'" _n
file write `manifest' "raw_field_count: `field_count_py'" _n
file write `manifest' "analytical_rows: `analytical_rows'" _n
file write `manifest' "retained_csv_rows: `analytical_rows'" _n
file write `manifest' "valid_rows_after_cutoff_excluded: `after_cutoff'" _n
file write `manifest' "missing_or_invalid_death_date_rows: `bad_dod_rows'" _n
file write `manifest' "pre_2008_death_date_rows: `pre08_rows'" _n
file write `manifest' "death_year_mismatch_rows: `year_mismatch_rows'" _n
file write `manifest' "source_duplicate_flag_rows: `duplicate_flag_rows'" _n
file write `manifest' "blank_certificate_rows: `blank_cert_rows'" _n
file write `manifest' "rows_with_any_step1_qa_flag: `qa_any_rows'" _n
file write `manifest' "nrn_documented_rows: `nrn_documented_rows'" _n
file write `manifest' "records_not_marked_cleaned: `not_cleaned_rows'" _n
file write `manifest' `"raw_csv: "`raw_stub'.csv""' _n
file write `manifest' `"raw_csv_sha256: "`csv_sha256_py'""' _n
file write `manifest' `"analytical_dta: "`data_stub'.dta""' _n
file write `manifest' "confidential: true" _n

file close `manifest'


* =============================================================================
* SECTION 9 - DO NOT TOUCH THIS SECTION
* Display the operational run summary
* =============================================================================

local raw_rows_display : display %12.0fc real("`raw_rows_py'")
local analytical_rows_display : display %12.0fc `analytical_rows'

local original_linesize = c(linesize)
set linesize 220

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "MORTALITY STEP 1: OPERATIONAL RUN SUMMARY"
noisily display as result ""
noisily display as text   "  Run status:              Completed successfully"
noisily display as text   "  Release:                 `year4'-`month2'"
noisily display as text   "  Release cut-off:         `end_date'"
noisily display as text   "  Analytical event:        `mort_event'"
noisily display as text   "  Raw tracking rows:       `tracking_arm_rows'"
noisily display as text   "  Tracking rows in DTA:    0"
noisily display as text   "  Raw REDCap rows:         `raw_rows_display'"
noisily display as text   "  Analytical rows:         `analytical_rows_display'"
noisily display as text   "  After cut-off excluded:  `after_cutoff'"
noisily display as text   "  Bad/missing death date:  `bad_dod_rows'"
noisily display as text   "  Source duplicate flags:  `duplicate_flag_rows'"
noisily display as text   "  Blank cause certificates:`blank_cert_rows'"
noisily display as text   "  Rows with any QA flag:   `qa_any_rows'"
noisily display as text   "  NRN documented:          `nrn_documented_rows'"
noisily display as text   ""
noisily display as text   `"  Mortality source CSV:    `outcsv'"'
noisily display as text   `"  Analytical DTA:          `outdta'"'
noisily display as text   `"  YAML receipt:            `outmanifest'"'
noisily display as text   `"  Private log:             `outlog'"'
noisily display as text   ""
noisily display as text   "  Next step: Review this summary and harden Step 1 before starting cause classification."
noisily display as result "============================================================================="

set linesize `original_linesize'

}

quietly log close mort_extract
capture program drop _bnr_mort_s1_fail

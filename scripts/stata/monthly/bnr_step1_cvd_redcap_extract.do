/*******************************************************************************
DO-FILE:     bnr_step1_cvd_redcap_extract.do
VERSION:     1.2.0 (27 July 2026)
PROJECT:     BNR Refit Phase 2
PURPOSE:     Step 1 of the monthly CVD workflow. Extract a private cumulative
             REDCap snapshot from 1 January 2024 through a selected month-end.

USAGE:       Run from the info-hub repository root:

                 do "scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do" 2024 1

             If an extract for that month already exists, add replace:

                 do "scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do" 2024 1 replace

             The optional dialog constructs exactly the same command. It does
             not use a separate extraction pathway.

SECURITY:    The REDCap API token is read directly by Python from the local
             text file identified by $BNR_REDCAP_TOKEN_FILE. The token must
             never be written in this DO file, stored in a Stata macro, printed
             to a log, or committed to Git.

INPUT:       REDCap API: https://caribdata.org/redcap/api/
FILTER:      2024-01-01 <= edate <= final day of selected month
OUTPUT:      Private raw CSV, Stata dataset, YAML manifest and Stata log under:
             $BNR_DATA_RAW/redcap/cvd/yYYYY/mMM/

NOTES:       This is a private source-data extract. It deliberately retains
             identifiers and operational fields. De-identification belongs in
             Step 2 of the monthly workflow.

ANALYST-EDITABLE INPUTS:
             Routine analysts normally change only the year, month and optional
             replace argument supplied when this file is run. These inputs are
             checked in Sections 1 and 2 below.

INTERNAL CODE:
             Sections 3 to 8 implement the approved extraction, validation and
             output process. They should not normally be edited during a routine
             monthly run. Any change to fields, dates, events, paths or outputs
             should be reviewed as a workflow change and documented.
*******************************************************************************/

version 19
set more off

* -----------------------------------------------------------------------------
* INTERNAL FAILURE MESSAGE
* -----------------------------------------------------------------------------
* This small helper gives every controlled failure the same clear final message,
* closes the named log and returns the original Stata error code. Routine
* analysts should not need to alter this program.
capture program drop _bnr_step1_fail
program define _bnr_step1_fail
    version 19
    args return_code release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 1 DID NOT COMPLETE"
    noisily display as error "  Release: `release_id'"
    noisily display as error `"  Reason:  `reason'"'
    noisily display as error `"  Log:     `log_path'"'
    noisily display as text  "Do not use any extract file from this incomplete run."
    noisily display as error "============================================================================="
    capture log close redcap_extract
    exit `return_code'
end

* -----------------------------------------------------------------------------
* 1. ANALYST INPUTS: read the requested release year and month
* -----------------------------------------------------------------------------

* The dialog and direct command line both pass the same three arguments.
* Only the first two are required. The third must be blank or the word replace.
args release_year release_month replace_existing

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Year and month are required."
    display as error ///
        "Example: do scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do 2024 1"
    exit 198
}

* If the BNR configuration has already been loaded, retain it. Otherwise load
* the untracked local file relative to the repository root.
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
        `"$BNR_PRIVATE_LOGS"' == "" | `"$BNR_REDCAP_TOKEN_FILE"' == "" {
    display as error "The BNR local path configuration is incomplete."
    exit 198
}

* The API URL is public configuration; the token is not.
local redcap_url "https://caribdata.org/redcap/api/"

* -----------------------------------------------------------------------------
* 2. ANALYST INPUT CHECKS: validate the requested release month
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

if "`replace_existing'" != "" & lower("`replace_existing'") != "replace" {
    display as error "The optional third argument must be replace."
    display as error ///
        "Example: do scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do 2024 1 replace"
    exit 198
}

local start_date "2024-01-01"

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

* Do not create a nominal month-end snapshot before that month has ended.
local today_td = daily("`c(current_date)'", "DMY")
if `end_td' > `today_td' {
    display as error ///
        "The selected month has not ended. Choose the latest completed month."
    exit 198
}

* -----------------------------------------------------------------------------
* 3. INTERNAL SETUP: define unchanged private output files
* -----------------------------------------------------------------------------

local release_dir ///
    "$BNR_DATA_RAW/redcap/cvd/y`year4'/m`month2'"
local file_stub ///
    "bnr_cvd_step1_`period'"

local outcsv      "`release_dir'/`file_stub'.csv"
local outdta      "`release_dir'/`file_stub'.dta"
local outmanifest "`release_dir'/`file_stub'_manifest.yml"
local outlog      "$BNR_PRIVATE_LOGS/`file_stub'.log"

capture mkdir "$BNR_PRIVATE"
capture mkdir "$BNR_PRIVATE/logs"
capture mkdir "$BNR_PRIVATE_LOGS"
capture log close redcap_extract
log using "`outlog'", text replace name(redcap_extract)

* Keep the Results window and log operational rather than developer-facing.
quietly {

noisily display as text "BNR CVD STEP 1: REDCAP EXTRACTION"
noisily display as result "  Script version:   1.2.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Coverage:         2024-01-01 through `end_date'"
noisily display as result "  Private output:   `release_dir'"

* -----------------------------------------------------------------------------
* 4. INTERNAL OUTPUT PROTECTION: prevent accidental replacement
* -----------------------------------------------------------------------------

* A retained raw extract must never be replaced accidentally. The optional
* third argument must explicitly be the word replace before any existing CSV,
* DTA or YAML file is removed.
local existing_output 0
foreach file in "`outcsv'" "`outdta'" "`outmanifest'" {
    capture confirm file `"`file'"'
    if !_rc {
        local existing_output 1
    }
}

if `existing_output' {
    if lower("`replace_existing'") != "replace" {
        _bnr_step1_fail 602 "`year4'-`month2'" `"`outlog'"' ///
            "A REDCap extract already exists. Rerun only with explicit replace authorisation."
        exit _rc
    }

    foreach file in "`outcsv'" "`outdta'" "`outmanifest'" {
        capture confirm file `"`file'"'
        if !_rc {
            erase `"`file'"'
        }
    }
}

* -----------------------------------------------------------------------------
* 5. INTERNAL EXTRACTION: retrieve and validate REDCap records
* -----------------------------------------------------------------------------

python:
from sfi import Macro
from redcap import Project

import csv
import hashlib
import io
import os
from datetime import datetime, timezone


api_url = Macro.getLocal("redcap_url")
token_file = Macro.getGlobal("BNR_REDCAP_TOKEN_FILE")
start_date = Macro.getLocal("start_date")
end_date = Macro.getLocal("end_date")
release_year = Macro.getLocal("year4")
release_month = Macro.getLocal("month2")
outcsv = Macro.getLocal("outcsv")
outmanifest = Macro.getLocal("outmanifest")

expected_events = {"stroke_arm_1", "heart_arm_2"}

# These are the fields used by the earlier post-2023 workflow. The export is
# intentionally broader, but checking this list detects an incompatible schema
# before an apparently successful raw snapshot is accepted.
required_fields = {
    "recid", "cfdoa", "fname", "mname", "lname", "sex", "dob",
    "cfage", "cfage_da", "natregno", "recnum", "cfadmdate", "admtime",
    "dlc", "cfdod", "parish", "ward___1", "ward___2", "ward___3",
    "ward___4", "ward___5", "htype", "stype", "edate", "etime",
    "pstroke", "pstrokeyr", "pami", "pamiyr", "htn", "diab", "sysbp",
    "diasbp", "bgmmol", "ecg", "ecgd", "ecgt", "tropres", "trop1res",
    "trop2res", "assess", "assess1", "assess2", "assess3", "assess4",
    "ct", "doct", "reperf", "repertype", "reperfd", "reperft",
    "asp___1", "asp___2", "asp___3", "aspdose", "aspd", "aspt",
    "asptimeampm_2", "vstatus", "dismeds___1", "dismeds___2",
    "dismeds___3", "dismeds___4", "dismeds___5", "dismeds___6",
    "dismeds___7", "dismeds___8", "dismeds___9", "dismeds___10",
    "aspdosedis", "strunit", "sunitadmsame", "astrunitd",
    "sunitdissame", "dstrunitd", "redcap_event_name"
}


def stop(message):
    """Raise a short error that cannot reveal the API token."""
    raise RuntimeError(message) from None


if not token_file:
    stop("BNR_REDCAP_TOKEN_FILE is not defined in bnr_paths_LOCAL.do.")

if not os.path.isfile(token_file):
    stop("The local REDCap token file was not found.")

with open(token_file, "r", encoding="utf-8-sig") as handle:
    api_token = handle.read().strip()

if not api_token or api_token == "PASTE_REDCAP_API_TOKEN_HERE":
    stop("The local REDCap token file does not yet contain a token.")

if any(character.isspace() for character in api_token):
    stop("The REDCap token file must contain only the token on one line.")

filter_logic = (
    f"[edate] >= '{start_date}' and [edate] <= '{end_date}'"
)

try:
    project = Project(api_url, api_token)
    csv_text = project.export_records(
        "csv",
        raw_or_label="raw",
        raw_or_label_headers="raw",
        export_checkbox_labels=False,
        filter_logic=filter_logic,
    )
except Exception as error:
    stop(
        "REDCap extraction failed "
        f"({type(error).__name__}). Check the API URL, token permissions, "
        "network connection and selected date period."
    )

if isinstance(csv_text, bytes):
    csv_text = csv_text.decode("utf-8-sig")

reader = csv.DictReader(io.StringIO(csv_text))
headers = reader.fieldnames or []
rows = list(reader)

missing_fields = sorted(required_fields.difference(headers))
if missing_fields:
    stop(
        "REDCap schema validation failed. Missing expected fields: "
        + ", ".join(missing_fields)
    )

if not rows:
    stop("The requested cumulative period returned no REDCap records.")

observed_events = {
    row.get("redcap_event_name", "").strip()
    for row in rows
    if row.get("redcap_event_name", "").strip()
}

unexpected_events = sorted(observed_events.difference(expected_events))
if unexpected_events:
    stop(
        "Unexpected REDCap event names were returned: "
        + ", ".join(unexpected_events)
    )

missing_events = sorted(expected_events.difference(observed_events))
if missing_events:
    print(
        "Warning: no rows were returned for expected event name(s): "
        + ", ".join(missing_events)
    )

os.makedirs(os.path.dirname(outcsv), exist_ok=True)

# REDCap free-text fields can contain quotation marks.  Although Python reads
# the API response correctly, Stata's CSV importer can interpret a small
# number of those rows differently and shift the remaining columns.  Write a
# normalised RFC-style CSV from the parsed rows so the file handed to Stata has
# one consistently quoted record per row.  This remains a complete private
# source extract; no fields or values are changed.
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

# Write a deliberately simple YAML receipt.  No YAML package is needed: all
# values are controlled by this DO file or REDCap validation above, and text
# values are double-quoted so staff can read the file safely in any editor.
def yaml_text(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


with open(outmanifest, "w", encoding="utf-8", newline="\n") as handle:
    handle.write("# Private operational receipt: do not publish with patient-level data.\n")
    handle.write("package_type: private_redcap_raw_extract\n")
    handle.write('source_system: "BNR CVD REDCap"\n')
    handle.write(f'api_url: "{yaml_text(api_url)}"\n')
    handle.write(f'event_date_start: "{start_date}"\n')
    handle.write(f'event_date_end: "{end_date}"\n')
    handle.write(f"release_year: {int(release_year)}\n")
    handle.write(f"release_month: {int(release_month)}\n")
    handle.write("filter_field: edate\n")
    handle.write(f'filter_logic: "{yaml_text(filter_logic)}"\n')
    handle.write(f"record_rows: {len(rows)}\n")
    handle.write(f"field_count: {len(headers)}\n")
    handle.write("event_names:\n")
    for event_name in sorted(observed_events):
        handle.write(f'  - "{yaml_text(event_name)}"\n')
    if missing_events:
        handle.write("expected_event_names_without_rows:\n")
        for event_name in missing_events:
            handle.write(f'  - "{yaml_text(event_name)}"\n')
    else:
        handle.write("expected_event_names_without_rows: []\n")
    handle.write(f'csv_file: "{yaml_text(os.path.basename(outcsv))}"\n')
    handle.write(f'csv_sha256: "{csv_sha256}"\n')
    handle.write(f'extracted_at_utc: "{datetime.now(timezone.utc).isoformat()}"\n')
    handle.write("confidential: true\n")

print(f"REDCap returned {len(rows):,} rows and {len(headers):,} fields.")
print("The token was read locally and was not written to the Stata session.")
end

* -----------------------------------------------------------------------------
* 6. INTERNAL STATA CHECKS: import, validate and save the DTA file
* -----------------------------------------------------------------------------

capture confirm file "`outcsv'"
if _rc {
    _bnr_step1_fail 603 "`year4'-`month2'" `"`outlog'"' ///
        "The raw REDCap CSV was not created."
    exit _rc
}
capture confirm file "`outmanifest'"
if _rc {
    _bnr_step1_fail 603 "`year4'-`month2'" `"`outlog'"' ///
        "The REDCap extraction receipt was not created."
    exit _rc
}

* The analyst's current data remain untouched. The temporary frame is removed
* automatically when this DO file finishes.
tempname extract_frame
frame create `extract_frame'

capture frame `extract_frame': import delimited using "`outcsv'", clear ///
    stringcols(_all) varnames(1) bindquote(strict)
if _rc {
    local import_rc = _rc
    _bnr_step1_fail `import_rc' "`year4'-`month2'" `"`outlog'"' ///
        "Stata could not import the extracted REDCap CSV."
    exit _rc
}

capture frame `extract_frame': confirm variable recid edate redcap_event_name
if _rc {
    _bnr_step1_fail 111 "`year4'-`month2'" `"`outlog'"' ///
        "The extracted CSV is missing a required identity, date or event field."
    exit _rc
}
capture frame `extract_frame': assert inlist(redcap_event_name, ///
    "stroke_arm_1", "heart_arm_2")
if _rc {
    _bnr_step1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "The extracted CSV contains an unexpected REDCap event name."
    exit _rc
}

frame `extract_frame': generate double __event_date = daily(edate, "YMD")
frame `extract_frame': replace __event_date = daily(edate, "DMY") ///
    if missing(__event_date) & edate != ""
frame `extract_frame': format __event_date %tdCCYY-NN-DD

frame `extract_frame': count if missing(__event_date)
local invalid_event_dates = r(N)
if `invalid_event_dates' > 0 {
    _bnr_step1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "The extract contains `invalid_event_dates' row(s) without a valid event date."
    exit _rc
}

capture frame `extract_frame': assert inrange(__event_date, ///
    daily("`start_date'", "YMD"), ///
    daily("`end_date'", "YMD"))
if _rc {
    _bnr_step1_fail 459 "`year4'-`month2'" `"`outlog'"' ///
        "The extract contains an event date outside the selected cumulative period."
    exit _rc
}
frame `extract_frame': drop __event_date

frame `extract_frame': compress
frame `extract_frame': label data ///
    "BNR CVD private raw REDCap extract through `end_date'"
frame `extract_frame': notes _dta: confidential: Contains identifiable patient-level information
frame `extract_frame': notes _dta: source: BNR CVD REDCap API
frame `extract_frame': notes _dta: event date range: `start_date' through `end_date'
frame `extract_frame': notes _dta: do not place this dataset in the Git repository

capture frame `extract_frame': save "`outdta'"
if _rc {
    local save_rc = _rc
    _bnr_step1_fail `save_rc' "`year4'-`month2'" `"`outlog'"' ///
        "The private Stata extract could not be saved."
    exit _rc
}
frame `extract_frame': count
local extract_rows = r(N)
frame drop `extract_frame'

* -----------------------------------------------------------------------------
* 7. OPERATIONAL SUMMARY: report the completed run
* -----------------------------------------------------------------------------

* Display the final result directly. This is deliberately repetitive and plain:
* analysts can see every important output without having to understand a
* temporary summary dataset or additional reporting program.
local extract_rows_display : display %12.0fc `extract_rows'
local original_linesize = c(linesize)
set linesize 220

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 1: OPERATIONAL RUN SUMMARY"
noisily display as result ""
noisily display as text   "  Run status:       Completed successfully"
noisily display as text   "  Release:          `year4'-`month2'"
noisily display as text   "  Coverage:         `start_date' through `end_date'"
noisily display as text   "  Records extracted:`extract_rows_display'"
noisily display as text   `"  CSV extract:      `outcsv'"'
noisily display as text   `"  Stata dataset:    `outdta'"'
noisily display as text   `"  YAML receipt:     `outmanifest'"'
noisily display as text   `"  Private log:      `outlog'"'
noisily display as text   "  Next step:        Join this snapshot to the frozen 2009-2023 dataset (Step 2)."
noisily display as result "============================================================================="

set linesize `original_linesize'

}

quietly log close redcap_extract
capture program drop _bnr_step1_fail

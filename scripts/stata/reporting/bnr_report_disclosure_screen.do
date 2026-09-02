/*******************************************************************************
DO-FILE: bnr_report_disclosure_screen.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Screen a structured count dataset for obvious disclosure-review issues.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_disclosure_screen.do" ///
      "C:/path/report_counts.dta" case_fatality_2025

REQUIRED VARIABLES:
  output_id   Table, figure or output identifier
  cell_id     Cell identifier unique within output_id
  cell_count  Numeric count underlying the displayed cell

This utility does not suppress values, alter the source dataset, establish
secondary suppression, approve a report or publish anything.
*******************************************************************************/

version 19
clear all
set more off

args input_dta review_id option
if "`input_dta'" == "" | "`review_id'" == "" {
    display as error "Enter the count dataset path and disclosure review ID."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional argument is replace."
    exit 198
}
local replace_existing = (lower("`option'") == "replace")
if !regexm("`review_id'", "^[a-z][a-z0-9_]*$") {
    display as error "Review ID must use lowercase letters, numbers and underscores."
    exit 198
}

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach required_global in BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

capture confirm file "`input_dta'"
if _rc {
    display as error "Disclosure-screen input dataset not found: `input_dta'"
    exit 601
}
quietly checksum "`input_dta'"
local input_size = r(filelen)
local input_checksum = r(checksum)

local review_root "$BNR_STAGING/report_reviews"
local disclosure_root "`review_root'/disclosure"
local review_dir "`disclosure_root'/`review_id'"
local screen_csv "`review_dir'/disclosure_screen.csv"
local summary_yml "`review_dir'/screen_summary.yml"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_disclosure_screen_`review_id'.log"

capture mkdir "`review_root'"
capture mkdir "`disclosure_root'"
capture mkdir "`review_dir'"
quietly mata: st_local("review_dir_exists", strofreal(direxists("`review_dir'")))
if "`review_dir_exists'" != "1" {
    display as error "Could not create disclosure-review directory: `review_dir'"
    exit 603
}

local output_exists 0
capture confirm file "`screen_csv'"
if !_rc local output_exists 1
capture confirm file "`summary_yml'"
if !_rc local output_exists 1
if `output_exists' & !`replace_existing' {
    display as error "Disclosure-screen output already exists for `review_id'."
    display as error "Use replace only after reviewing the existing output."
    exit 602
}

capture log close bnr_report_disclosure_screen
log using "`private_log'", text replace name(bnr_report_disclosure_screen)

use "`input_dta'", clear
capture confirm variable output_id
if _rc {
    capture log close bnr_report_disclosure_screen
    display as error "Required variable is missing: output_id"
    exit 111
}
capture confirm variable cell_id
if _rc {
    capture log close bnr_report_disclosure_screen
    display as error "Required variable is missing: cell_id"
    exit 111
}
capture confirm numeric variable cell_count
if _rc {
    capture log close bnr_report_disclosure_screen
    display as error "Required numeric variable is missing or nonnumeric: cell_count"
    exit 111
}
quietly count
if r(N) == 0 {
    capture log close bnr_report_disclosure_screen
    display as error "The disclosure-screen input dataset contains no rows."
    exit 2000
}
local input_rows = r(N)

duplicates tag output_id cell_id, generate(flag_duplicate_cell)
replace flag_duplicate_cell = flag_duplicate_cell > 0
generate byte flag_missing_count = missing(cell_count)
generate byte flag_negative_count = !missing(cell_count) & cell_count < 0
generate byte flag_noninteger_count = !missing(cell_count) & ///
    cell_count != floor(cell_count)
generate byte flag_small_count = !missing(cell_count) & ///
    cell_count == floor(cell_count) & inrange(cell_count, 0, 5)
egen screen_issue_count = rowtotal(flag_duplicate_cell flag_missing_count ///
    flag_negative_count flag_noninteger_count flag_small_count)
generate str6 screen_status = "CLEAR"
replace screen_status = "REVIEW" if screen_issue_count > 0

quietly count if flag_duplicate_cell == 1
local duplicate_rows = r(N)
quietly count if flag_missing_count == 1
local missing_rows = r(N)
quietly count if flag_negative_count == 1
local negative_rows = r(N)
quietly count if flag_noninteger_count == 1
local noninteger_rows = r(N)
quietly count if flag_small_count == 1
local small_rows = r(N)
quietly count if screen_status == "REVIEW"
local review_rows = r(N)

order output_id cell_id cell_count screen_status screen_issue_count ///
    flag_small_count flag_missing_count flag_negative_count ///
    flag_noninteger_count flag_duplicate_cell
sort output_id cell_id
export delimited using "`screen_csv'", replace

local screened_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local screened_time "`c(current_time)'"
tempname summary_handle
file open `summary_handle' using "`summary_yml'", write text replace
file write `summary_handle' "schema: bnr_report_disclosure_screen_v1" _n
file write `summary_handle' "review_id: `review_id'" _n
file write `summary_handle' "status: screening_completed" _n
file write `summary_handle' "threshold_rule: integer counts from 0 to 5" _n
file write `summary_handle' "input_size: `input_size'" _n
file write `summary_handle' "input_checksum: `input_checksum'" _n
file write `summary_handle' "input_rows: `input_rows'" _n
file write `summary_handle' "review_rows: `review_rows'" _n
file write `summary_handle' "small_count_rows: `small_rows'" _n
file write `summary_handle' "missing_count_rows: `missing_rows'" _n
file write `summary_handle' "negative_count_rows: `negative_rows'" _n
file write `summary_handle' "noninteger_count_rows: `noninteger_rows'" _n
file write `summary_handle' "duplicate_cell_rows: `duplicate_rows'" _n
file write `summary_handle' "human_disclosure_review_required: true" _n
file write `summary_handle' "secondary_suppression_assessed: false" _n
file write `summary_handle' "screened_date: `screened_date'" _n
file write `summary_handle' "screened_time: `screened_time'" _n
file close `summary_handle'

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "REPORT DISCLOSURE SCREEN: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Screening completed"
noisily display as text   "  Script version:          0.1.0"
noisily display as text   "  Review identifier:       `review_id'"
noisily display as text   "  Input rows:              `input_rows'"
noisily display as text   "  Rows requiring review:   `review_rows'"
noisily display as text   "  Small-count rows:        `small_rows'"
noisily display as text   "  Missing-count rows:      `missing_rows'"
noisily display as text   "  Negative-count rows:     `negative_rows'"
noisily display as text   "  Non-integer rows:        `noninteger_rows'"
noisily display as text   "  Duplicate-cell rows:     `duplicate_rows'"
noisily display as text  `"  Detailed screen:         `screen_csv'"'
noisily display as text  `"  Screening summary:       `summary_yml'"'
noisily display as text   "  Important:               Human disclosure review is still required"
noisily display as result "============================================================================="
}
capture log close bnr_report_disclosure_screen

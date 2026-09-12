/*******************************************************************************
DO-FILE: bnr_report_test_disclosure_screen.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Verify the synthetic disclosure-screen output.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_disclosure_screen.do"
*******************************************************************************/

version 19
clear all
set more off

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STAGING" == "" exit 198

local screen_csv "$BNR_STAGING/report_reviews/disclosure/workflow_test/disclosure_screen.csv"
local summary_yml "$BNR_STAGING/report_reviews/disclosure/workflow_test/screen_summary.yml"
capture confirm file "`screen_csv'"
if _rc {
    display as error "Synthetic disclosure-screen CSV not found: `screen_csv'"
    exit 601
}
capture confirm file "`summary_yml'"
if _rc {
    display as error "Synthetic disclosure-screen summary not found: `summary_yml'"
    exit 601
}

import delimited using "`screen_csv'", clear varnames(1)
quietly count
assert r(N) == 8

quietly count if flag_missing_count == 1
assert r(N) == 1
quietly count if flag_negative_count == 1
assert r(N) == 1
quietly count if flag_noninteger_count == 1
assert r(N) == 1
quietly count if flag_small_count == 1
assert r(N) == 2
quietly count if flag_duplicate_cell == 1
assert r(N) == 2
quietly count if screen_status == "REVIEW"
assert r(N) == 7
quietly count if screen_status == "CLEAR"
assert r(N) == 1

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "REPORT DISCLOSURE SCREEN: TEST SUMMARY"
noisily display as text   "  Run status:              All screening checks passed"
noisily display as text   "  Input rows:              8"
noisily display as text   "  Rows requiring review:   7"
noisily display as text   "  Clear rows:              1"
noisily display as text   "  Source dataset changed:  No"
noisily display as result "============================================================================="
}

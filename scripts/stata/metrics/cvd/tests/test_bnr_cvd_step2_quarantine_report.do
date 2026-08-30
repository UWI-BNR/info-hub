/*******************************************************************************
TEST: test_bnr_cvd_step2_quarantine_report.do
VERSION: 1.0.0 (29 August 2026)
PURPOSE: Synthetic acceptance test for the Step 2 quarantine report helper.
*******************************************************************************/
version 19
clear all
set more off

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STATA" == "" exit 198

tempfile worklist report_dta summary_csv
local report_xlsx "`c(tmpdir)'/bnr_step2_quarantine_test.xlsx"
capture erase "`report_xlsx'"

clear
set obs 2
generate long source_row = _n
generate str20 recid = cond(_n == 1, "100", "101")
generate str20 redcap_event_name = cond(_n == 1, "stroke_arm_1", "heart_arm_2")
generate str8 quarantine_level = cond(_n == 1, "full", "partial")
generate str80 review_reason = cond(_n == 1, "missing_event_date", "implausible_calculated_age")
generate str80 affected_fields = cond(_n == 1, "edate", "dob+age")
generate str40 source_dob = cond(_n == 1, "1970-01-01", "1073-07-18")
generate str40 source_edate = cond(_n == 1, "", "2026-01-31")
generate str40 source_cfage = cond(_n == 1, "", "952")
generate str80 source_detail = cond(_n == 1, "", "calculated_age=952")
generate str120 temporary_action = cond(_n == 1, "Event excluded from analytical Step 2 output pending source review.", "Event retained; affected field(s) made unavailable pending source review.")
generate str160 analytical_impact = cond(_n == 1, "Event does not contribute downstream until corrected and rerun.", "Event retained for safe all-age analyses but unavailable for age-dependent analyses until corrected.")
generate str20 review_status = "pending"
generate str120 review_note = ""
save "`worklist'", replace

do "$BNR_STATA/metrics/cvd/bnr_step2_write_quarantine_report.do" "`worklist'" "`report_dta'" "`report_xlsx'" "`summary_csv'" "cvd_2026_01" "10" "9"

use "`report_dta'", clear
assert _N == 2
quietly count if quarantine_level == "full"
assert r(N) == 1
quietly count if quarantine_level == "partial"
assert r(N) == 1

import delimited using "`summary_csv'", varnames(1) clear
assert _N == 1
assert quarantine_status == "review_pending"
assert source_events == 10
assert retained_events == 9
assert quarantined_events == 2
assert fully_quarantined_events == 1
assert partially_quarantined_events == 1

capture confirm file "`report_xlsx'"
assert _rc == 0
capture erase "`report_xlsx'"

display as result "PASS: Step 2 quarantine-report synthetic test completed."

/*******************************************************************************
DO-FILE: bnr_step2_write_quarantine_report.do
VERSION: 1.0.0 (29 August 2026)
PURPOSE: Write the private Step 2 quarantine report and one-row release summary.

The input worklist contains only post-2023 source rows that were fully or
partially quarantined by Step 2. The detailed DTA/XLSX remain private. The
summary CSV contains aggregate counts and paths only and can travel with the
release into later review steps.
*******************************************************************************/
version 19
clear
set more off

args worklist_dta report_dta report_xlsx summary_csv release_id source_events retained_events

foreach argument in worklist_dta report_dta report_xlsx summary_csv release_id source_events retained_events {
    if "``argument''" == "" exit 198
}

capture confirm file "`worklist_dta'"
if _rc exit 601

local source_n = real("`source_events'")
local retained_n = real("`retained_events'")
if missing(`source_n') | missing(`retained_n') exit 198

use "`worklist_dta'", clear
local required source_row recid redcap_event_name quarantine_level review_reason affected_fields source_dob source_edate source_cfage source_detail temporary_action analytical_impact review_status review_note
foreach variable of local required {
    capture confirm variable `variable'
    if _rc exit 111
}

quietly count
local quarantined_n = r(N)
quietly count if quarantine_level == "full"
local full_n = r(N)
quietly count if quarantine_level == "partial"
local partial_n = r(N)
assert `quarantined_n' == `full_n' + `partial_n'
assert `retained_n' == `source_n' - `full_n'

sort source_row quarantine_level
label data "BNR CVD Step 2 private quarantine review worklist"
save "`report_dta'", replace

local quarantine_status "clear"
if `quarantined_n' > 0 local quarantine_status "review_pending"

* The workbook always has a Summary sheet. The detailed sheet is added only
* when there are records to review, avoiding awkward zero-observation exports.
clear
set obs 9
generate str40 review_item = ""
generate str244 detail = ""
replace review_item = "Release" in 1
replace detail = "`release_id'" in 1
replace review_item = "Quarantine status" in 2
replace detail = "`quarantine_status'" in 2
replace review_item = "Source events" in 3
replace detail = string(`source_n', "%12.0f") in 3
replace review_item = "Retained events" in 4
replace detail = string(`retained_n', "%12.0f") in 4
replace review_item = "Quarantined events" in 5
replace detail = string(`quarantined_n', "%12.0f") in 5
replace review_item = "Fully quarantined" in 6
replace detail = string(`full_n', "%12.0f") in 6
replace review_item = "Partially quarantined" in 7
replace detail = string(`partial_n', "%12.0f") in 7
replace review_item = "Correction rule" in 8
replace detail = "Correct the authoritative source and rerun. Do not edit generated analytical outputs as a source correction." in 8
replace review_item = "Detailed worklist" in 9
replace detail = "Quarantine sheet and companion DTA. Identifiers remain private." in 9
export excel using "`report_xlsx'", sheet("Summary") firstrow(variables) replace

if `quarantined_n' > 0 {
    use "`report_dta'", clear
    export excel using "`report_xlsx'", sheet("Quarantine") firstrow(variables) sheetreplace
}

clear
set obs 1
generate str20 release_id = "`release_id'"
generate str20 quarantine_status = "`quarantine_status'"
generate long source_events = `source_n'
generate long retained_events = `retained_n'
generate long quarantined_events = `quarantined_n'
generate long fully_quarantined_events = `full_n'
generate long partially_quarantined_events = `partial_n'
generate str244 quarantine_report_dta = "`report_dta'"
generate str244 quarantine_report_xlsx = "`report_xlsx'"
export delimited using "`summary_csv'", replace

display as result "Step 2 quarantine report written."
display as result "  Status:              `quarantine_status'"
display as result "  Quarantined events:  `quarantined_n'"
display as result "  Fully quarantined:   `full_n'"
display as result "  Partially quarantined: `partial_n'"

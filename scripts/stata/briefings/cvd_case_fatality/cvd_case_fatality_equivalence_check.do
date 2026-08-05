/*
=============================================================================
DO-FILE:     cvd_case_fatality_equivalence_check.do
PROJECT:     BNR Info-Hub
PURPOSE:     Confirm that the Step 3 case-fatality input reproduces the
             2010-2023 aggregate source used by the legacy briefing.

WHY THIS EXISTS
---------------
The legacy briefing used a private prepared dataset.  The new workflow uses
the deidentified Step 3 case-fatality library.  Identifiers are expected to
differ, so this check compares only the aggregates used by the briefing.

WHAT IT CHECKS
--------------
* Hospital-ascertained events only (DCO excluded)
* Years 2010-2023 (the 2009 set-up year is excluded)
* The five legacy case-fatality categories
* Event counts by event type, sex and calendar year

It deliberately does NOT amend either source dataset or create a public file.
Review the exported CSV before converting or publishing the new briefing.

USAGE
-----
do cvd_case_fatality_equivalence_check.do ///
    "legacy_prepared_dataset.dta" ///
    "step3_case_fatality_input.dta" ///
    "case_fatality_equivalence_2010_2023.csv"

The third argument is optional.  If omitted, the report is saved in the
current Stata working directory.
=============================================================================
*/

clear all
set more off

args legacy_input step3_input report_file

if `"`legacy_input'"' == "" | `"`step3_input'"' == "" {
    display as error "Equivalence check stopped: two input datasets are required."
    display as error "Usage: do cvd_case_fatality_equivalence_check.do legacy.dta step3.dta [report.csv]"
    exit 198
}

if `"`report_file'"' == "" {
    local report_file "cvd_case_fatality_equivalence_2010_2023.csv"
}

foreach input_file in `"`legacy_input'"' `"`step3_input'"' {
    capture confirm file `"`input_file'"'
    if _rc {
        display as error "Equivalence check stopped: input file not found."
        display as error "  `input_file'"
        exit 601
    }
}

tempfile legacy_summary step3_summary comparison

* ---------------------------------------------------------------------------
* Create the exact aggregate input required by the legacy briefing.
* The same code is applied independently to both sources.
* ---------------------------------------------------------------------------
foreach source in legacy step3 {

    if "`source'" == "legacy" {
        use `"`legacy_input'"', clear
        local source_name "Legacy prepared dataset"
        local summary_file `legacy_summary'
    }
    else {
        use `"`step3_input'"', clear
        local source_name "Step 3 case-fatality input"
        local summary_file `step3_summary'
    }

    foreach required_variable in dco etype doe yoe dodi sadi dod sex agey {
        capture confirm variable `required_variable'
        if _rc {
            display as error "Equivalence check stopped: `source_name' lacks `required_variable'."
            exit 111
        }
    }

    keep if inrange(yoe, 2010, 2023)
    drop if dco == 1

    * This is the legacy five-category case-fatality derivation, unchanged.
    replace dod = . if dod > 1000000
    generate double doe_dod_diff = dod - doe

    generate byte cf = sadi
    recode cf (2 = 3)
    replace cf = 2 if missing(sadi) & !missing(dod) & doe_dod_diff > 28
    replace cf = 4 if missing(sadi) & !missing(dod) & doe_dod_diff <= 7
    replace cf = 5 if missing(sadi) & !missing(dod) & ///
        doe_dod_diff > 7 & doe_dod_diff <= 28
    replace cf = 6 if missing(cf)

    label define cf_check 1 "Confirmed alive" 2 "Possible alive" ///
        3 "Confirmed fatality" 4 "Probable fatality" ///
        5 "Possible fatality" 6 "No dates", replace
    label values cf cf_check

    generate long events = 1
    collapse (sum) events, by(yoe etype sex cf)
    sort yoe etype sex cf
    save `summary_file', replace
}

* ---------------------------------------------------------------------------
* Compare sources.  A matched row with difference zero is an exact agreement.
* ---------------------------------------------------------------------------
use `legacy_summary', clear
rename events legacy_events
merge 1:1 yoe etype sex cf using `step3_summary'
rename events step3_events

replace legacy_events = 0 if missing(legacy_events)
replace step3_events = 0 if missing(step3_events)
generate long difference = step3_events - legacy_events
generate str20 comparison_status = "AGREES"
replace comparison_status = "DIFFERS" if difference != 0
replace comparison_status = "LEGACY ONLY" if _merge == 1
replace comparison_status = "STEP 3 ONLY" if _merge == 2

label variable legacy_events "Events in legacy prepared dataset"
label variable step3_events "Events in Step 3 input"
label variable difference "Step 3 minus legacy events"
label variable comparison_status "Aggregate comparison result"

order comparison_status yoe etype sex cf legacy_events step3_events difference
sort comparison_status yoe etype sex cf
save `comparison', replace
export delimited using `"`report_file'"', replace

count if comparison_status != "AGREES"
local differing_rows = r(N)
count
local comparison_rows = r(N)

display as text _n "============================================================"
display as text "CASE-FATALITY SOURCE EQUIVALENCE CHECK"
display as text "============================================================"
display as result "  Comparison rows: `comparison_rows'"
display as result "  Differing rows:  `differing_rows'"
display as result "  Report:          `report_file'"

if `differing_rows' == 0 {
    display as result _n "RESULT: PASS"
    display as result "The 2010-2023 aggregate case-fatality inputs agree exactly."
}
else {
    display as error _n "RESULT: REVIEW REQUIRED"
    display as error "Do not convert or publish the new briefing until differences are explained."
    list comparison_status yoe etype sex cf legacy_events step3_events difference ///
        if comparison_status != "AGREES", noobs abbreviate(20)
}

exit

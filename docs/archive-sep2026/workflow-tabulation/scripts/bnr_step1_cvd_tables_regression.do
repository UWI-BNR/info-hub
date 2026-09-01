/*
===============================================================================
DO-FILE:     bnr_step1_cvd_tables_regression.do
PROJECT:     BNR Info-Hub
PURPOSE:     One-time regression comparison for CVD Table Step 1
STATUS:      Implementation-validation helper; not a routine production step

OVERVIEW
  This file compares a completed Table Step 1 staging package with the legacy
  2023 public workbook. It writes a cell-level comparison, a readable summary
  and an overall status into the staging package's review folder.

  It deliberately remains separate from bnr_step1_cvd_tables.do. The routine
  production pathway therefore carries no permanent dependency on the legacy
  workbook.

INPUTS
  1. Full path to a completed Table Step 1 staging package.
  2. Full path to workbook_cvd_annual_tabulations.xlsx.
  3. Optional word replace, required when comparison outputs already exist.

OUTPUTS
  review/regression_comparison.csv
  review/regression_summary.txt
  review/regression_status.txt

COMMAND-LINE USE
  do bnr_step1_cvd_tables_regression.do ///
      "FULL/PATH/TO/cvd_tables_2024_01" ///
      "FULL/PATH/TO/workbook_cvd_annual_tabulations.xlsx" ///
      [replace]

IMPORTANT INTERPRETATION NOTES
  - Legacy Table 1 workbook counts are exactly four times the true counts.
    The old workbook export counted four expanded display copies. Both the raw
    workbook value and the corrected comparison value are retained below.
  - Legacy weekly Table 2 has been replaced by monthly Table 2. Only completed-
    year totals are regression-tested across the two time aggregations.
  - New Table 3 deliberately uses release-matched months and known-age
    denominators. It is recorded as a documented design change, not forced into
    an invalid numerical comparison with the legacy whole-year table.
  - Legacy Table 6 reverses the Stroke and AMI labels for its two-year period
    blocks. The regression aligns those rows by analytical order and records
    the legacy label issue explicitly.
  - Incidence differences larger than the published-precision tolerance are
    listed for human review. They are expected where the new workflow excludes
    missing-age events that cannot be assigned a population denominator.

HELPERS / DEPENDENCIES
  - No user-written Stata commands.
  - No analytical helper files.
  - Stata's built-in import excel command is required.
  - No Mata is used.
===============================================================================
*/


* =============================================================================
* A. INITIALISE AND READ INPUTS
* =============================================================================

clear all
set more off

args staging_package legacy_workbook replace_option

if `"`staging_package'"' == "" | `"`legacy_workbook'"' == "" {
    display as error "Regression comparison stopped: two file paths are required."
    display as text  "Supply the staging package and the legacy workbook."
    exit 198
}

if "`replace_option'" != "" & lower("`replace_option'") != "replace" {
    display as error "Regression comparison stopped: optional third argument must be replace."
    exit 198
}

local replace_outputs = lower("`replace_option'") == "replace"
local review_folder "`staging_package'/review"
local comparison_csv "`review_folder'/regression_comparison.csv"
local summary_txt    "`review_folder'/regression_summary.txt"
local status_txt     "`review_folder'/regression_status.txt"


* =============================================================================
* B. VALIDATE THE STAGING PACKAGE AND WORKBOOK
* =============================================================================

capture confirm file "`legacy_workbook'"
if _rc {
    display as error "Regression comparison stopped: legacy workbook not found."
    display as result "`legacy_workbook'"
    exit 601
}

forvalues table_number = 1/7 {
    local table2 : display %02.0f `table_number'

    if `table_number' == 1 local stem "annual_event_counts"
    if `table_number' == 2 local stem "monthly_event_counts"
    if `table_number' == 3 local stem "age70_event_percent"
    if `table_number' == 4 local stem "incidence_rates"
    if `table_number' == 5 local stem "incidence_rate_ratios"
    if `table_number' == 6 local stem "case_fatality"
    if `table_number' == 7 local stem "length_of_stay"

    local staged_file "`staging_package'/datasets/table_`table2'_`stem'.dta"
    capture confirm file "`staged_file'"
    if _rc {
        display as error "Regression comparison stopped: staged dataset not found."
        display as result "`staged_file'"
        exit 601
    }
}

capture confirm file "`comparison_csv'"
if !_rc & `replace_outputs' == 0 {
    display as error "Regression comparison stopped: comparison output already exists."
    display as result "`comparison_csv'"
    display as text "Supply replace only after confirming that the earlier review can be overwritten."
    exit 602
}


* =============================================================================
* C. STANDARD COMPARISON STRUCTURE
* =============================================================================
* Each table block creates the same review variables:
*   table_id       new workflow table number
*   check_id       short name of the check
*   comparison_key human-readable cell or group identifier
*   metric         quantity being compared
*   legacy_raw     value read directly from the legacy workbook
*   legacy_value   legacy value after any documented correction
*   new_value      value produced by Table Step 1
*   difference     new minus comparison legacy value
*   tolerance      acceptable absolute difference
*   status         PASS, REVIEW or DOCUMENTED_CHANGE
*   note           explanation required for interpretation

tempfile compare_t1 compare_t2 compare_t3 compare_t4
tempfile compare_t5 compare_t6 compare_t7


* =============================================================================
* D. TABLE 1 -- ANNUAL EVENT COUNTS
* =============================================================================
* KNOWN LEGACY EXPORT DEFECT
* The old Table 1 workbook was exported after each event record had been
* expanded into four display copies. Its workbook counts are therefore exactly
* four times the event counts. This block retains legacy_raw, divides it by four
* into legacy_value, and verifies that the corrected values equal Step 1.

import excel using "`legacy_workbook'", ///
    sheet("Table1") cellrange(A7:J20) clear

rename A year_text
rename B legacy_1
rename C legacy_2
rename D legacy_3
rename E legacy_4
rename F legacy_5
rename G legacy_6
rename H legacy_7
rename I legacy_8
rename J legacy_9

destring year_text, generate(year) ignore(" ")
drop year_text
reshape long legacy_, i(year) j(display_cell)
rename legacy_ legacy_raw

gen byte etype = .
gen byte sex   = .
replace etype = 1 if inrange(display_cell, 1, 3)
replace etype = 2 if inrange(display_cell, 4, 6)
replace etype = 3 if inrange(display_cell, 7, 9)
replace sex = mod(display_cell - 1, 3) + 1

gen double legacy_value = legacy_raw / 4
keep year etype sex legacy_raw legacy_value
tempfile legacy_t1
save `legacy_t1', replace

use "`staging_package'/datasets/table_01_annual_event_counts.dta", clear
keep if inrange(year, 2010, 2023)
keep year etype sex event_count
merge 1:1 year etype sex using `legacy_t1'
quietly count if _merge != 3
if r(N) > 0 {
    display as error "Regression comparison stopped: Table 1 keys do not align."
    tabulate _merge
    exit 459
}
drop _merge

rename event_count new_value
gen double difference = new_value - legacy_value
gen double tolerance = 0
gen str20 status = cond(difference == 0, "PASS", "REVIEW")
gen str8  table_id = "Table 1"
gen str32 check_id = "annual_counts"
gen str40 metric = "event_count"
gen str120 comparison_key = ///
    "year=" + string(year) + "; etype=" + string(etype) + ///
    "; sex=" + string(sex)
gen str244 note = ///
    "Legacy workbook count divided by four: old export counted four expanded display copies."

keep table_id check_id comparison_key metric legacy_raw legacy_value ///
     new_value difference tolerance status note
save `compare_t1', replace


* =============================================================================
* E. TABLE 2 -- MONTHLY COUNTS: COMPLETED-YEAR TOTAL CHECK
* =============================================================================
* The weekly public table is deliberately retired. A valid cross-version check
* is still possible: monthly and weekly counts must sum to identical annual
* Stroke and AMI totals for each completed year.

tempname legacy2_post
tempfile legacy_t2
postfile `legacy2_post' int year byte etype double legacy_raw ///
    using `legacy_t2', replace

forvalues yr = 2010/2023 {
    import excel using "`legacy_workbook'", ///
        sheet("Table2_`yr'") cellrange(A57:D57) clear

    post `legacy2_post' (`yr') (1) (B[1])
    post `legacy2_post' (`yr') (2) (C[1])
}
postclose `legacy2_post'

use "`staging_package'/datasets/table_02_monthly_event_counts.dta", clear
keep if inrange(year, 2010, 2023) & inlist(etype, 1, 2)
collapse (sum) event_count, by(year etype)
merge 1:1 year etype using `legacy_t2'
quietly count if _merge != 3
if r(N) > 0 {
    display as error "Regression comparison stopped: Table 2 annual keys do not align."
    tabulate _merge
    exit 459
}
drop _merge

gen double legacy_value = legacy_raw
rename event_count new_value
gen double difference = new_value - legacy_value
gen double tolerance = 0
gen str20 status = cond(difference == 0, "PASS", "REVIEW")
gen str8  table_id = "Table 2"
gen str32 check_id = "monthly_vs_weekly_total"
gen str40 metric = "annual_event_total"
gen str120 comparison_key = ///
    "year=" + string(year) + "; etype=" + string(etype)
gen str244 note = ///
    "Completed-year total only: new monthly aggregation compared with legacy weekly aggregation."

keep table_id check_id comparison_key metric legacy_raw legacy_value ///
     new_value difference tolerance status note
save `compare_t2', replace


* =============================================================================
* F. TABLE 3 -- DOCUMENTED DESIGN CHANGE
* =============================================================================
* The new table compares the release year to date with the same calendar months
* in the preceding five years and uses the known-age denominator. The legacy
* workbook instead compares complete 2023 with complete 2018-2022. A cell-by-
* cell comparison would therefore compare different estimands and is not used.

clear
set obs 1
gen str8  table_id = "Table 3"
gen str32 check_id = "age70_design_change"
gen str120 comparison_key = "all cells"
gen str40 metric = "percentage"
gen double legacy_raw   = .
gen double legacy_value = .
gen double new_value    = .
gen double difference   = .
gen double tolerance    = .
gen str20 status = "DOCUMENTED_CHANGE"
gen str244 note = ///
    "Not directly comparable: release-matched months and known-age denominator replace legacy complete-period percentages."
save `compare_t3', replace


* =============================================================================
* G. TABLE 4 -- ANNUAL INCIDENCE RATES
* =============================================================================
* The comparison tolerance is 0.005 per 100,000, corresponding to agreement at
* two decimal places. Larger differences are retained as REVIEW. They are
* expected where Step 1 now excludes missing-age events explicitly instead of
* carrying unmatched records into the incidence calculation.

tempname legacy4_post
tempfile legacy_t4
postfile `legacy4_post' int year byte etype sex dco ///
    str12 metric double legacy_raw using `legacy_t4', replace

local excel_columns "B C D E F G"
local column_etypes  "1 1 1 2 2 2"
local column_sexes   "1 2 3 1 2 3"
local rate_metrics   "crude rateadj lb_gam ub_gam"

forvalues yr = 2010/2023 {
    import excel using "`legacy_workbook'", ///
        sheet("Table5_`yr'") cellrange(A10:G18) clear

    forvalues column_number = 1/6 {
        local excel_column : word `column_number' of `excel_columns'
        local this_etype   : word `column_number' of `column_etypes'
        local this_sex     : word `column_number' of `column_sexes'

        forvalues metric_number = 1/4 {
            local metric_name : word `metric_number' of `rate_metrics'
            local row_no = `metric_number'
            post `legacy4_post' (`yr') (`this_etype') (`this_sex') (0) ///
                ("`metric_name'") (`excel_column'[`row_no'])

            local row_no = `metric_number' + 5
            post `legacy4_post' (`yr') (`this_etype') (`this_sex') (1) ///
                ("`metric_name'") (`excel_column'[`row_no'])
        }
    }
}
postclose `legacy4_post'

use "`staging_package'/datasets/table_04_incidence_rates.dta", clear
keep if inrange(year, 2010, 2023)
keep year etype sex dco crude rateadj lb_gam ub_gam
rename crude   new_crude
rename rateadj new_rateadj
rename lb_gam  new_lb_gam
rename ub_gam  new_ub_gam
reshape long new_, i(year etype sex dco) j(metric) string
rename new_ new_value

merge 1:1 year etype sex dco metric using `legacy_t4'
quietly count if _merge != 3
if r(N) > 0 {
    display as error "Regression comparison stopped: Table 4 keys do not align."
    tabulate _merge
    exit 459
}
drop _merge

gen double legacy_value = legacy_raw
gen double difference = new_value - legacy_value
gen double tolerance = 0.005
gen str20 status = cond(abs(difference) <= tolerance, "PASS", "REVIEW")
gen str8  table_id = "Table 4"
gen str32 check_id = "incidence_rates"
gen str120 comparison_key = ///
    "year=" + string(year) + "; etype=" + string(etype) + ///
    "; sex=" + string(sex) + "; dco=" + string(dco)
gen str244 note = ///
    "Review differences beyond two-decimal tolerance; missing-age events are explicitly excluded in Step 1."

keep table_id check_id comparison_key metric legacy_raw legacy_value ///
     new_value difference tolerance status note
save `compare_t4', replace


* =============================================================================
* H. TABLE 5 -- INCIDENCE RATE RATIOS
* =============================================================================
* The workbook's two period blocks are labelled in reverse: rows labelled
* Stroke contain the AMI comparisons and rows labelled AMI contain the Stroke
* comparisons. The numerical comparison therefore follows the established
* analytical row order. The new Step 1 labels are not reversed.

tempname legacy5_post
tempfile legacy_t5
postfile `legacy5_post' int comparison_order str80 legacy_label ///
    double legacy_rr legacy_lower legacy_upper using `legacy_t5', replace

import excel using "`legacy_workbook'", ///
    sheet("Table6") cellrange(A5:D18) clear

local comparison_orders "1 2 12 13 14 15 16 17 32 33 34 35 36 37"
forvalues row_no = 1/14 {
    local this_order : word `row_no' of `comparison_orders'
    post `legacy5_post' (`this_order') (A[`row_no']) ///
        (B[`row_no']) (C[`row_no']) (D[`row_no'])
}
postclose `legacy5_post'

use "`staging_package'/datasets/table_05_incidence_rate_ratios.dta", clear
keep comparison_order comparison_label rate_ratio lower_95 upper_95
merge 1:1 comparison_order using `legacy_t5'
quietly count if _merge != 3
if r(N) > 0 {
    display as error "Regression comparison stopped: Table 5 keys do not align."
    tabulate _merge
    exit 459
}
drop _merge

* Keep the workbook's descriptive row label for audit, but do not leave it
* beginning with legacy_.  The reshape below uses legacy_ as a numeric stub;
* including the string label in that stub would cause a type-mismatch error.
rename legacy_label workbook_label

rename rate_ratio new_rate_ratio
rename lower_95   new_lower_95
rename upper_95   new_upper_95
rename legacy_rr  legacy_rate_ratio
rename legacy_lower legacy_lower_95
rename legacy_upper legacy_upper_95
reshape long new_ legacy_, i(comparison_order) j(metric) string
rename new_ new_value
rename legacy_ legacy_raw

gen double legacy_value = legacy_raw
gen double difference = new_value - legacy_value
gen double tolerance = 0.005
gen str20 status = cond(abs(difference) <= tolerance, "PASS", "REVIEW")
gen str8  table_id = "Table 5"
gen str32 check_id = "incidence_rate_ratios"
gen str120 comparison_key = comparison_label
gen str244 note = "Compared at legacy two-decimal published precision."
replace note = ///
    "Legacy Stroke/AMI period-block labels are reversed; values aligned by analytical row order." ///
    if comparison_order >= 10

keep table_id check_id comparison_key metric legacy_raw legacy_value ///
     new_value difference tolerance status note
save `compare_t5', replace


* =============================================================================
* I. TABLE 6 -- IN-HOSPITAL CASE FATALITY
* =============================================================================
* The new staged dataset retains the four event-type-by-sex detail cells. The
* legacy workbook additionally calculates totals. This comparison uses the
* detail cells, from which any future totals are constructed. Tolerance 0.05
* corresponds to the legacy one-decimal published presentation.

tempname legacy6_post
tempfile legacy_t6
postfile `legacy6_post' byte period_number etype sex ///
    double legacy_raw using `legacy_t6', replace

import excel using "`legacy_workbook'", ///
    sheet("Table7") cellrange(A7:J13) clear

forvalues row_no = 1/7 {
    local period_number = 8 - `row_no'
    post `legacy6_post' (`period_number') (1) (1) (B[`row_no'])
    post `legacy6_post' (`period_number') (1) (2) (C[`row_no'])
    post `legacy6_post' (`period_number') (2) (1) (E[`row_no'])
    post `legacy6_post' (`period_number') (2) (2) (F[`row_no'])
}
postclose `legacy6_post'

use "`staging_package'/datasets/table_06_case_fatality.dta", clear
keep period_number etype sex confirmed_cf_percent
merge 1:1 period_number etype sex using `legacy_t6'
quietly count if _merge != 3
if r(N) > 0 {
    display as error "Regression comparison stopped: Table 6 keys do not align."
    tabulate _merge
    exit 459
}
drop _merge

gen double legacy_value = legacy_raw
rename confirmed_cf_percent new_value
gen double difference = new_value - legacy_value
gen double tolerance = 0.05
gen str20 status = cond(abs(difference) <= tolerance, "PASS", "REVIEW")
gen str8  table_id = "Table 6"
gen str32 check_id = "case_fatality"
gen str40 metric = "confirmed_cf_percent"
gen str120 comparison_key = ///
    "period=" + string(period_number) + "; etype=" + string(etype) + ///
    "; sex=" + string(sex)
gen str244 note = "Detail cells compared at legacy one-decimal published precision."

keep table_id check_id comparison_key metric legacy_raw legacy_value ///
     new_value difference tolerance status note
save `compare_t6', replace


* =============================================================================
* J. TABLE 7 -- LENGTH OF HOSPITAL STAY
* =============================================================================

tempname legacy7_post
tempfile legacy_t7
postfile `legacy7_post' int year byte etype sex str24 metric ///
    double legacy_raw using `legacy_t7', replace

import excel using "`legacy_workbook'", ///
    sheet("Table8") cellrange(A7:E62) clear

local los_columns "B C D E"
local los_etypes  "1 1 2 2"
local los_sexes   "1 2 1 2"
local los_metrics "median_days lower_quartile_days upper_quartile_days"

forvalues year_block = 0/13 {
    local yr = 2023 - `year_block'
    local first_row = 1 + (`year_block' * 4)

    forvalues column_number = 1/4 {
        local excel_column : word `column_number' of `los_columns'
        local this_etype   : word `column_number' of `los_etypes'
        local this_sex     : word `column_number' of `los_sexes'

        forvalues metric_number = 1/3 {
            local metric_name : word `metric_number' of `los_metrics'
            local row_no = `first_row' + `metric_number'
            post `legacy7_post' (`yr') (`this_etype') (`this_sex') ///
                ("`metric_name'") (`excel_column'[`row_no'])
        }
    }
}
postclose `legacy7_post'

use "`staging_package'/datasets/table_07_length_of_stay.dta", clear
keep if inrange(year, 2010, 2023)
keep year etype sex median_days lower_quartile_days upper_quartile_days
rename median_days         new_median_days
rename lower_quartile_days new_lower_quartile_days
rename upper_quartile_days new_upper_quartile_days
reshape long new_, i(year etype sex) j(metric) string
rename new_ new_value

merge 1:1 year etype sex metric using `legacy_t7'
quietly count if _merge != 3
if r(N) > 0 {
    display as error "Regression comparison stopped: Table 7 keys do not align."
    tabulate _merge
    exit 459
}
drop _merge

gen double legacy_value = legacy_raw
gen double difference = new_value - legacy_value
gen double tolerance = 0.000001
gen str20 status = cond(abs(difference) <= tolerance, "PASS", "REVIEW")
gen str8  table_id = "Table 7"
gen str32 check_id = "length_of_stay"
gen str120 comparison_key = ///
    "year=" + string(year) + "; etype=" + string(etype) + ///
    "; sex=" + string(sex)
gen str244 note = "Median and quartiles compared directly with the legacy workbook."

keep table_id check_id comparison_key metric legacy_raw legacy_value ///
     new_value difference tolerance status note
save `compare_t7', replace


* =============================================================================
* K. COMBINE AND EXPORT CELL-LEVEL COMPARISONS
* =============================================================================

use `compare_t1', clear
append using `compare_t2' `compare_t3' `compare_t4' ///
             `compare_t5' `compare_t6' `compare_t7'

order table_id check_id comparison_key metric status ///
      legacy_raw legacy_value new_value difference tolerance note
sort table_id check_id comparison_key metric

label variable legacy_raw   "Value read directly from legacy workbook"
label variable legacy_value "Legacy value used in comparison"
label variable new_value    "Value produced by Table Step 1"
label variable difference   "New value minus comparison legacy value"
label variable tolerance    "Maximum acceptable absolute difference"
label variable status       "Comparison outcome"

export delimited using "`comparison_csv'", replace

quietly count
local number_checks = r(N)
quietly count if status == "PASS"
local number_pass = r(N)
quietly count if status == "REVIEW"
local number_review = r(N)
quietly count if status == "DOCUMENTED_CHANGE"
local number_documented = r(N)

local overall_status "PASS WITH DOCUMENTED CHANGES"
if `number_review' > 0 {
    local overall_status "REVIEW REQUIRED"
}


* =============================================================================
* L. WRITE READABLE SUMMARY AND STATUS FILES
* =============================================================================

tempname summary
file open `summary' using "`summary_txt'", write text replace
file write `summary' "BNR CVD Table Step 1 regression summary" _n
file write `summary' "Overall status: `overall_status'" _n _n
file write `summary' "Cell-level checks: `number_checks'" _n
file write `summary' "Passed: `number_pass'" _n
file write `summary' "Require review: `number_review'" _n
file write `summary' "Documented design changes: `number_documented'" _n _n
file write `summary' "Table 1: legacy workbook values are four times the true counts because the old workbook export counted four expanded display copies. Corrected values are compared." _n
file write `summary' "Table 2: completed-year totals are compared across legacy weekly and new monthly aggregation." _n
file write `summary' "Table 3: no direct numerical comparison; release-matched months and known-age denominators are documented design changes." _n
file write `summary' "Table 4: differences beyond 0.005 per 100,000 require review; the new method explicitly excludes missing-age events." _n
file write `summary' "Table 5: compared at two-decimal published precision; legacy Stroke/AMI period labels are reversed." _n
file write `summary' "Table 6: detail cells compared at one-decimal published precision." _n
file write `summary' "Table 7: medians and quartiles compared directly." _n _n
file write `summary' "See regression_comparison.csv for every cell and review flag." _n
file close `summary'

tempname status_file
file open `status_file' using "`status_txt'", write text replace
file write `status_file' "Regression test status: `overall_status'" _n
file write `status_file' "Checks requiring review: `number_review'" _n
file write `status_file' "Documented design changes: `number_documented'" _n
file write `status_file' "Review regression_summary.txt and regression_comparison.csv before Table Step 2." _n
file close `status_file'


* =============================================================================
* M. OPERATIONAL RUN SUMMARY
* =============================================================================

qui {
    noi display as text _n "============================================================"
    noi display as text    "TABLE STEP 1: REGRESSION COMPARISON SUMMARY"
    noi display as text    "============================================================"
    noi display as result  "Status:             `overall_status'"
    noi display as result  "Cell-level checks:  `number_checks'"
    noi display as result  "Passed:             `number_pass'"
    noi display as result  "Require review:     `number_review'"
    noi display as result  "Documented changes: `number_documented'"
    noi display as result  "Comparison file:    `comparison_csv'"
    noi display as result  "Summary file:       `summary_txt'"
    noi display as text    "Suppression:        NOT APPLIED"
    noi display as text    "Publication:        NOT PERFORMED"
    noi display as text    "Next: review flagged differences before Table Step 2."
    noi display as text    "============================================================"
}

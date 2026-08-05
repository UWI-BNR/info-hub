/*
===============================================================================
DO-FILE:     bnr_step1_cvd_tables.do
PROJECT:     BNR Info-Hub
PURPOSE:     Table workflow Step 1: calculate and stage CVD table datasets
STATUS:      Operational production file

OVERVIEW
  This file creates the seven unsuppressed analytical datasets used by the
  routine CVD tables publication workflow.

  It deliberately stops at PRIVATE STAGING. It does not:
    - suppress cells;
    - create public Markdown or a public workbook;
    - approve a package;
    - copy files to outputs/public/; or
    - copy files into the Quarto website.

INPUTS
  1. One deidentified Step 3 all-variables dataset and companion YML.
  2. The existing Barbados population reference dataset used by the
     incidence briefing.
  3. The existing WHO standard-population dataset used by the incidence
     briefing.

OUTPUTS
  outputs/staging/tables/cvd/cvd_tables_YYYY_MM/
    datasets/
      table_01_annual_event_counts.dta/.csv
      table_02_monthly_event_counts.dta/.csv
      table_03_age70_event_percent.dta/.csv
      table_04_incidence_rates.dta/.csv
      table_05_incidence_rate_ratios.dta/.csv
      table_06_case_fatality.dta/.csv
      table_07_length_of_stay.dta/.csv
    metadata/
      package.yml
      input_manifest.csv
      table_catalogue.csv
    review/
      qa_summary.txt
    readme.txt

HELPERS / DEPENDENCIES
  - scripts/stata/config/bnr_paths_LOCAL.do
  - user-written Stata command: distrate
  - dialog: scripts/stata/dialogs/bnr_step1_cvd_tables.dlg
  - help: scripts/stata/help/bnr_step1_cvd_tables.sthlp

  No analytical calculations are hidden in a helper file.

COMMAND-LINE USE
  do bnr_step1_cvd_tables.do release_year release_month input_version [replace]

EXAMPLE
  do bnr_step1_cvd_tables.do 2024 1 1 replace

VALIDATION NOTE
  The analytical implementation has been regression-tested separately against
  the established 2010-2023 tables. The optional comparison file is:
  bnr_step1_cvd_tables_regression.do. It is not part of a routine monthly run.
===============================================================================
*/


* =============================================================================
* A. INITIALISE AND LOAD SHARED PATHS
* =============================================================================

clear all
set more off

* This is the only machine-specific path in this file.
local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"


* =============================================================================
* B. READ AND VALIDATE COMMAND-LINE INPUTS
* =============================================================================

args release_year release_month input_version replace_option

if "`release_year'" == "" | "`release_month'" == "" | ///
   "`input_version'" == "" {
    display as error "Table Step 1 stopped: required inputs were not supplied."
    display as text  "Usage: do bnr_step1_cvd_tables.do release_year release_month input_version [replace]"
    exit 198
}

foreach item in release_year release_month input_version {
    capture confirm integer number ``item''
    if _rc {
        display as error "Table Step 1 stopped: `item' must be an integer."
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    display as error "Table Step 1 stopped: release_month must be 1 to 12."
    exit 198
}

if "`replace_option'" != "" & lower("`replace_option'") != "replace" {
    display as error "Table Step 1 stopped: optional fourth argument must be replace."
    exit 198
}

local replace_staging = lower("`replace_option'") == "replace"

local month2  : display %02.0f `release_month'
local version2: display %02.0f `input_version'
local yyyymm  "`release_year'`month2'"
local release "`release_year'-`month2'"
local package_id "cvd_tables_`release_year'_`month2'"

local coverage_date = dofm(ym(`release_year', `release_month') + 1) - 1
local coverage : display %tdCCYY-NN-DD `coverage_date'

* Completed annual incidence results end on 31 December of the preceding year.
local incidence_end_year = `release_year' - 1

* Case-fatality uses completed two-year periods: 2010-11, 2012-13, etc.
local case_fatality_end_year = `incidence_end_year'
if mod(`case_fatality_end_year', 2) == 0 {
    local case_fatality_end_year = `case_fatality_end_year' - 1
}


* =============================================================================
* C. DECLARE INPUTS AND PRIVATE STAGING FOLDERS
* =============================================================================

local input_dataset_id "bnr_cvd_input_all_variables_`yyyymm'_v`version2'"
local input_file "$BNR_DATA_DERIVED/cvd/y`release_year'/m`month2'/metric_inputs/`input_dataset_id'.dta"
local input_yml  "$BNR_DATA_DERIVED/cvd/y`release_year'/m`month2'/metric_inputs/`input_dataset_id'.yml"

* These are the controlled reference files used by the established incidence
* analysis and the completed historical regression comparison. Do not replace
* either file without documenting the change and rerunning that comparison.
local population_file "$BNR_PRIVATE_WORK/brb_pop.dta"
local who_file        "$BNR_PRIVATE_WORK/who_std.dta"

local staging_root     "$BNR_STAGING/tables/cvd"
local staging_package  "`staging_root'/`package_id'"
local staging_data     "`staging_package'/datasets"
local staging_metadata "`staging_package'/metadata"
local staging_review   "`staging_package'/review"

cap mkdir "$BNR_STAGING/tables"
cap mkdir "$BNR_STAGING/tables/cvd"

capture mkdir "`staging_package'"
if _rc & `replace_staging' == 0 {
    display as error "Table Step 1 stopped: the staging package already exists."
    display as result "`staging_package'"
    display as text "Use a new release or explicitly supply replace."
    exit 602
}

cap mkdir "`staging_data'"
cap mkdir "`staging_metadata'"
cap mkdir "`staging_review'"

* Earlier development packages contained this one-time regression marker.
* Remove it during an authorised replacement so it cannot be mistaken for a
* routine Step 1 requirement. The historical comparison evidence is retained
* separately from monthly staging packages.
if `replace_staging' == 1 {
    capture erase "`staging_review'/regression_status.txt"
}

cap log close
log using "$BNR_PRIVATE_LOGS/`package_id'_step1.log", text replace

display as text _n "------------------------------------------------------------"
display as text    "BNR CVD TABLE WORKFLOW: STEP 1"
display as text    "------------------------------------------------------------"
display as result  "Package:          `package_id'"
display as result  "Step 3 release:   `release' (version `version2')"
display as result  "Coverage through: `coverage'"
display as result  "Private staging:  `staging_package'"
display as text    "------------------------------------------------------------"


* =============================================================================
* D. VALIDATE INPUT FILES AND SOFTWARE DEPENDENCIES
* =============================================================================

foreach required_file in input_file input_yml population_file who_file {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Table Step 1 stopped: required file not found."
        display as result "``required_file''"
        exit 601
    }
}

capture which distrate
if _rc {
    display as error "Table Step 1 stopped: the user-written command distrate is not installed."
    display as text  "Install and validate distrate before running production tables."
    exit 199
}

use "`input_file'", clear

foreach required_variable in ///
    eid dco etype doe yoe moe doa dodi sadi dod sex agey age5 age70 {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Table Step 1 stopped: required variable `required_variable' is missing."
        exit 111
    }
}

capture isid eid
if _rc {
    display as error "Table Step 1 stopped: eid is not unique."
    duplicates report eid
    exit 459
}

count if !inlist(etype, 1, 2) & !missing(etype)
if r(N) > 0 {
    display as error "Table Step 1 stopped: unexpected etype values were found."
    tabulate etype, missing
    exit 459
}

count if !inlist(sex, 1, 2) & !missing(sex)
if r(N) > 0 {
    display as error "Table Step 1 stopped: unexpected sex values were found."
    tabulate sex, missing
    exit 459
}

count if yoe > `release_year' | ///
    (yoe == `release_year' & moe > `release_month' & !missing(moe))
if r(N) > 0 {
    display as error "Table Step 1 stopped: events occur after the selected release coverage."
    exit 459
}


* =============================================================================
* E. LEGACY DATA CLEANING -- WORKING COPY ONLY
* =============================================================================
* These corrections reproduce the established BNR briefing treatment.
* They change only the in-memory working copy; the Step 3 source is untouched.
*
* Once the refitted upstream workflow guarantees clean dates, this whole block
* may be commented out after a documented regression test.

replace dod  = . if dod  > 1000000
replace dodi = . if dodi > 1000000

tempfile analysis_input
save `analysis_input', replace


* =============================================================================
* F. TABLE 1 -- ANNUAL EVENT COUNTS
* =============================================================================
* Scope follows the legacy table generator: registered Stroke and AMI events,
* including DCO events, with event-type, sex and all-CVD totals.

use `analysis_input', clear
keep if inrange(yoe, 2010, `release_year')
keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)
gen long event_count = 1

collapse (sum) event_count, by(yoe etype sex)

tempfile t1_detail t1_etype_total t1_cvd_sex t1_cvd_total
save `t1_detail', replace

collapse (sum) event_count, by(yoe etype)
gen byte sex = 3
save `t1_etype_total', replace

use `t1_detail', clear
collapse (sum) event_count, by(yoe sex)
gen byte etype = 3
save `t1_cvd_sex', replace

collapse (sum) event_count, by(yoe)
gen byte etype = 3
gen byte sex = 3
save `t1_cvd_total', replace

use `t1_detail', clear
append using `t1_etype_total' `t1_cvd_sex' `t1_cvd_total'
rename yoe year

gen str14 period_status = "complete"
replace period_status = "year_to_date" if year == `release_year' & `release_month' < 12
gen str10 coverage_end = "`coverage'"

label define etype_table 1 "Stroke" 2 "AMI" 3 "All CVD", replace
label define sex_table   1 "Female" 2 "Male" 3 "Total", replace
label values etype etype_table
label values sex sex_table
label variable year          "Event year"
label variable etype         "CVD event group"
label variable sex           "Sex group"
label variable event_count   "Registered event count before suppression"
label variable period_status "Completeness of reporting period"
label variable coverage_end  "Dataset coverage end date"

sort year etype sex
isid year etype sex
label data "BNR CVD Table 1: annual event counts, unsuppressed staging data"
save "`staging_data'/table_01_annual_event_counts.dta", replace
export delimited using "`staging_data'/table_01_annual_event_counts.csv", replace


* =============================================================================
* G. TABLE 2 -- MONTHLY EVENT COUNTS
* =============================================================================
* Weekly values are deliberately retired. Future months in the release year
* are retained in the private dataset as unavailable and are never coded zero.

use `analysis_input', clear
keep if inrange(yoe, 2010, `release_year')
keep if inlist(etype, 1, 2)
keep if inrange(moe, 1, 12)
gen long event_count = 1
collapse (sum) event_count, by(yoe moe etype)

tempfile t2_detail t2_all t2_observed
save `t2_detail', replace
collapse (sum) event_count, by(yoe moe)
gen byte etype = 3
save `t2_all', replace
use `t2_detail', clear
append using `t2_all'
rename yoe year
rename moe month
save `t2_observed', replace

clear
local number_years = `release_year' - 2010 + 1
set obs `=`number_years' * 36'
gen int  year  = 2010 + floor((_n - 1) / 36)
gen byte month = mod(floor((_n - 1) / 3), 12) + 1
gen byte etype = mod(_n - 1, 3) + 1

merge 1:1 year month etype using `t2_observed', nogen

gen byte cell_available = year < `release_year' | ///
    (year == `release_year' & month <= `release_month')
replace event_count = 0 if missing(event_count) & cell_available == 1
replace event_count = . if cell_available == 0

gen str14 period_status = "complete"
replace period_status = "current_month" if ///
    year == `release_year' & month == `release_month'
replace period_status = "not_yet_observed" if cell_available == 0
gen str10 coverage_end = "`coverage'"

label define etype_table 1 "Stroke" 2 "AMI" 3 "All CVD", replace
label values etype etype_table
label variable year           "Event year"
label variable month          "Calendar month"
label variable etype          "CVD event group"
label variable event_count    "Registered event count before suppression"
label variable cell_available "Month is covered by this release"
label variable period_status  "Completeness of reporting period"
label variable coverage_end   "Dataset coverage end date"

sort year month etype
isid year month etype
label data "BNR CVD Table 2: monthly event counts, unsuppressed staging data"
save "`staging_data'/table_02_monthly_event_counts.dta", replace
export delimited using "`staging_data'/table_02_monthly_event_counts.csv", replace


* =============================================================================
* H. TABLE 3 -- EVENT PERCENTAGE BY BROAD AGE GROUP
* =============================================================================
* The current release year is compared with the same available calendar months
* in the preceding five years. Percentages use the known-age denominator.
* Missing-age counts are retained explicitly for QA and disclosure review.

use `analysis_input', clear
keep if inrange(yoe, `release_year' - 5, `release_year')
keep if moe <= `release_month'
keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)

gen byte period = 1 if yoe == `release_year'
replace period = 2 if inrange(yoe, `release_year' - 5, `release_year' - 1)
keep if inlist(period, 1, 2)

gen long event_count = 1

preserve
    keep if missing(age70)
    collapse (sum) missing_age_count=event_count, by(period etype sex)
    tempfile t3_missing
    save `t3_missing', replace
restore

keep if inlist(age70, 0, 1)
collapse (sum) numerator_count=event_count, by(period etype sex age70)
fillin period etype sex age70
replace numerator_count = 0 if missing(numerator_count)
drop _fillin
bysort period etype sex: egen denominator_count = total(numerator_count)
merge m:1 period etype sex using `t3_missing', nogen
replace missing_age_count = 0 if missing(missing_age_count)

gen double percentage = 100 * numerator_count / denominator_count ///
    if denominator_count > 0
gen byte years_in_period = cond(period == 1, 1, 5)
gen double annual_average_numerator = numerator_count / years_in_period
gen double annual_average_denominator = denominator_count / years_in_period

gen int period_start_year = `release_year'
gen int period_end_year   = `release_year'
replace period_start_year = `release_year' - 5 if period == 2
replace period_end_year   = `release_year' - 1 if period == 2
gen byte months_covered = `release_month'
gen str10 coverage_end = "`coverage'"

label define period_age 1 "Current year to date" 2 "Preceding five-year comparison", replace
label define etype_table 1 "Stroke" 2 "AMI" 3 "All CVD", replace
label define sex_table   1 "Female" 2 "Male" 3 "Total", replace
label values period period_age
label values etype etype_table
label values sex sex_table
label variable period                     "Comparison period"
label variable period_start_year          "First year in period"
label variable period_end_year            "Last year in period"
label variable months_covered             "Calendar months included in each year"
label variable etype                      "CVD event type"
label variable sex                        "Sex"
label variable age70                      "Age group: under 70 or 70+"
label variable numerator_count            "Events in age group before suppression"
label variable denominator_count          "Events with known age group before suppression"
label variable missing_age_count          "Events with missing age group"
label variable annual_average_numerator   "Annual average age-group count"
label variable annual_average_denominator "Annual average known-age denominator"
label variable percentage                 "Percentage of known-age events"
label variable coverage_end               "Dataset coverage end date"

sort period etype sex age70
isid period etype sex age70
label data "BNR CVD Table 3: broad age-group percentages, unsuppressed staging data"
save "`staging_data'/table_03_age70_event_percent.dta", replace
export delimited using "`staging_data'/table_03_age70_event_percent.csv", replace


* =============================================================================
* I. PREPARE INCIDENCE ANALYSIS DATA
* =============================================================================
* This reproduces the established incidence preparation without downloading
* reference data during a production run.

use "`population_file'", clear
foreach required_variable in year sex age18 bpop {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Table Step 1 stopped: population reference lacks `required_variable'."
        exit 111
    }
}
keep if inrange(year, 2010, `incidence_end_year')
keep year sex age18 bpop
isid year sex age18
tempfile population_reference
save `population_reference', replace

use "`who_file'", clear
foreach required_variable in age18 rpop {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Table Step 1 stopped: WHO reference lacks `required_variable'."
        exit 111
    }
}
keep age18 rpop
isid age18
tempfile who_reference
save `who_reference', replace

tempfile incidence_no_dco incidence_with_dco incidence_analysis

* Hospital events only: dco=0 in the resulting sensitivity dimension.
use `analysis_input', clear
keep if inrange(yoe, 2010, `incidence_end_year')
drop if dco == 1
keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)

* Incidence rates require a known five-year age group because every event must
* be linked to an age-specific population denominator. Missing-age events
* cannot be assigned a denominator. Count them for QA, then exclude them from
* the incidence numerator before zero-filled age cells are created.
quietly count if missing(age5)
local incidence_missing_age_no_dco = r(N)
display as text "Incidence QA: `incidence_missing_age_no_dco' non-DCO events have missing age5 and are excluded from rate calculations."
drop if missing(age5)

rename yoe year
rename age5 age18
gen long event = 1
collapse (sum) event, by(etype year sex age18)
fillin etype year sex age18
replace event = 0 if missing(event)
drop _fillin
tempfile incidence_no_dco_sex
save `incidence_no_dco_sex', replace
collapse (sum) event, by(etype year age18)
gen byte sex = 3
append using `incidence_no_dco_sex'
merge m:1 year sex age18 using `population_reference', assert(match) nogen
merge m:1 age18 using `who_reference', assert(match) nogen
gen byte dco = 0
save `incidence_no_dco', replace

* Hospital plus DCO events: dco=1 in the resulting sensitivity dimension.
use `analysis_input', clear
keep if inrange(yoe, 2010, `incidence_end_year')
keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)

* Repeat the same explicit treatment for the sensitivity analysis that adds
* DCO events. This second count includes any missing-age DCO events.
quietly count if missing(age5)
local incidence_missing_age_with_dco = r(N)
display as text "Incidence QA: `incidence_missing_age_with_dco' events including DCO have missing age5 and are excluded from rate calculations."
drop if missing(age5)

rename yoe year
rename age5 age18
gen long event = 1
collapse (sum) event, by(etype year sex age18)
fillin etype year sex age18
replace event = 0 if missing(event)
drop _fillin
tempfile incidence_with_dco_sex
save `incidence_with_dco_sex', replace
collapse (sum) event, by(etype year age18)
gen byte sex = 3
append using `incidence_with_dco_sex'
merge m:1 year sex age18 using `population_reference', assert(match) nogen
merge m:1 age18 using `who_reference', assert(match) nogen
gen byte dco = 1
save `incidence_with_dco', replace

use `incidence_no_dco', clear
append using `incidence_with_dco'
sort dco etype year sex age18
save `incidence_analysis', replace


* =============================================================================
* J. TABLE 4 -- ANNUAL INCIDENCE RATES
* =============================================================================

tempfile table4_distrate
distrate event bpop using "`who_reference'", ///
    stand(age18) popstand(rpop) ///
    by(etype year sex dco) ///
    mult(100000) format(%8.2f) saving(`table4_distrate')

use `table4_distrate', clear
keep etype year sex dco event N crude rateadj lb_gam ub_gam
rename event numerator_count
rename N population_denominator
gen str14 period_status = "complete"
gen str10 coverage_end = "`coverage'"

label define etype_table 1 "Stroke" 2 "AMI" 3 "All CVD", replace
label define sex_table   1 "Female" 2 "Male" 3 "Total", replace
label values etype etype_table
label values sex sex_table
label define dco_table 0 "Without DCO" 1 "DCO added", replace
label values dco dco_table
label variable numerator_count       "Event numerator before suppression"
label variable population_denominator "Population denominator"
label variable crude                 "Crude incidence rate per 100,000"
label variable rateadj               "WHO age-standardised rate per 100,000"
label variable lb_gam                "Lower 95% confidence limit"
label variable ub_gam                "Upper 95% confidence limit"
label variable dco                   "DCO sensitivity definition"
label variable coverage_end          "Dataset coverage end date"

sort year dco etype sex
isid year dco etype sex
label data "BNR CVD Table 4: annual incidence rates, unsuppressed staging data"
save "`staging_data'/table_04_incidence_rates.dta", replace
export delimited using "`staging_data'/table_04_incidence_rates.csv", replace


* =============================================================================
* K. TABLE 5 -- INCIDENCE RATE RATIOS
* =============================================================================
* Hospital events only. This retains the three comparisons in the established
* briefing/table: Stroke vs AMI, men vs women, and each completed two-year
* period vs 2010-2011 within event type.

use `incidence_no_dco', clear
gen byte etype_reverse = etype
recode etype_reverse (1=2) (2=1)

gen byte year2 = .
replace year2 = floor((year - 2010) / 2) + 1 if ///
    inrange(year, 2010, `case_fatality_end_year')
drop if missing(year2)

tempfile irr_by_etype irr_by_sex irr_by_year

distrate event bpop using "`who_reference'", ///
    stand(age18) popstand(rpop) ///
    by(etype_reverse) ///
    mult(100000) format(%8.2f) saving(`irr_by_etype')

distrate event bpop using "`who_reference'", ///
    stand(age18) popstand(rpop) ///
    by(sex) ///
    mult(100000) format(%8.2f) saving(`irr_by_sex')

distrate event bpop using "`who_reference'", ///
    stand(age18) popstand(rpop) ///
    by(etype_reverse year2) ///
    mult(100000) format(%8.2f) saving(`irr_by_year')

* Supporting event counts for disclosure review.
use `incidence_no_dco', clear
gen byte etype_reverse = etype
recode etype_reverse (1=2) (2=1)
collapse (sum) comparison_count=event, by(etype_reverse)
quietly summarize comparison_count if etype_reverse == 1, meanonly
local ami_reference_count = r(sum)
tempfile irr_support_etype
save `irr_support_etype', replace

use `irr_by_etype', clear
drop if srr == 1 & missing(lb_srr) & missing(ub_srr)
merge 1:1 etype_reverse using `irr_support_etype', keep(match) nogen
gen double reference_count = `ami_reference_count'
gen byte comparison_type = 1
gen int comparison_order = 1
gen str80 comparison_label = "Stroke vs AMI"
keep comparison_type comparison_order comparison_label ///
     srr lb_srr ub_srr comparison_count reference_count
tempfile irr_final_etype
save `irr_final_etype', replace

use `incidence_no_dco', clear
collapse (sum) comparison_count=event, by(sex)
quietly summarize comparison_count if sex == 1, meanonly
local female_reference_count = r(sum)
tempfile irr_support_sex
save `irr_support_sex', replace

use `irr_by_sex', clear
drop if srr == 1 & missing(lb_srr) & missing(ub_srr)
drop if sex == 3
merge 1:1 sex using `irr_support_sex', keep(match) nogen
gen double reference_count = `female_reference_count'
gen byte comparison_type = 2
gen int comparison_order = 2
gen str80 comparison_label = "CVD in men vs women"
keep comparison_type comparison_order comparison_label ///
     srr lb_srr ub_srr comparison_count reference_count
tempfile irr_final_sex
save `irr_final_sex', replace

use `incidence_no_dco', clear
gen byte etype_reverse = etype
recode etype_reverse (1=2) (2=1)
gen byte year2 = floor((year - 2010) / 2) + 1 if ///
    inrange(year, 2010, `case_fatality_end_year')
drop if missing(year2)
collapse (sum) comparison_count=event, by(etype_reverse year2)
bysort etype_reverse: egen reference_count = ///
    max(cond(year2 == 1, comparison_count, .))
tempfile irr_support_year
save `irr_support_year', replace

use `irr_by_year', clear
drop if srr == 1 & missing(lb_srr) & missing(ub_srr)
drop if year2 == 1
merge 1:1 etype_reverse year2 using `irr_support_year', keep(match) nogen
gen byte comparison_type = 3
gen int period_start_year = 2010 + (year2 - 1) * 2
gen int period_end_year = period_start_year + 1
gen int comparison_order = 10 + (etype_reverse - 1) * 20 + year2
gen str80 comparison_label = ///
    cond(etype_reverse == 2, "Stroke ", "AMI ") + ///
    string(period_start_year) + "-" + string(period_end_year) + ///
    " vs 2010-2011"
keep comparison_type comparison_order comparison_label ///
     period_start_year period_end_year ///
     srr lb_srr ub_srr comparison_count reference_count
tempfile irr_final_year
save `irr_final_year', replace

use `irr_final_etype', clear
append using `irr_final_sex' `irr_final_year'
rename srr rate_ratio
rename lb_srr lower_95
rename ub_srr upper_95
gen double support_count_min = min(comparison_count, reference_count)
gen str10 coverage_end = "`coverage'"

label define comparison_type_table ///
    1 "Event type" 2 "Sex" 3 "Two-year period", replace
label values comparison_type comparison_type_table
label variable comparison_label "Incidence-rate comparison"
label variable rate_ratio       "WHO age-standardised incidence rate ratio"
label variable lower_95         "Lower 95% confidence limit"
label variable upper_95         "Upper 95% confidence limit"
label variable comparison_count "Event count in comparison group"
label variable reference_count  "Event count in reference group"
label variable support_count_min "Smaller supporting event count"
label variable coverage_end     "Dataset coverage end date"

sort comparison_order
isid comparison_order
label data "BNR CVD Table 5: incidence rate ratios, unsuppressed staging data"
save "`staging_data'/table_05_incidence_rate_ratios.dta", replace
export delimited using "`staging_data'/table_05_incidence_rate_ratios.csv", replace


* =============================================================================
* L. TABLE 6 -- IN-HOSPITAL CASE FATALITY
* =============================================================================
* Definition follows the established table: confirmed in-hospital deaths as a
* percentage of non-DCO hospital events, reported in completed two-year periods.

use `analysis_input', clear
drop if dco == 1
keep if inrange(yoe, 2010, `case_fatality_end_year')
keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)

gen double event_to_death_days = dod - doe
gen byte cf = sadi
recode cf (2=3)
replace cf = 2 if missing(sadi) & !missing(dod) & event_to_death_days > 28
replace cf = 4 if missing(sadi) & !missing(dod) & event_to_death_days <= 7
replace cf = 5 if missing(sadi) & !missing(dod) & ///
    inrange(event_to_death_days, 8, 28)
replace cf = .a if missing(cf)

gen long denominator_count = 1
gen long confirmed_deaths = cf == 3
gen long probable_deaths  = cf == 4
gen byte period_number = floor((yoe - 2010) / 2) + 1

collapse (sum) denominator_count confirmed_deaths probable_deaths, ///
    by(period_number etype sex)

gen int period_start_year = 2010 + (period_number - 1) * 2
gen int period_end_year   = period_start_year + 1
gen double confirmed_cf_percent = 100 * confirmed_deaths / denominator_count
gen double confirmed_probable_cf_percent = ///
    100 * (confirmed_deaths + probable_deaths) / denominator_count
gen str10 coverage_end = "`coverage'"

label define etype_table 1 "Stroke" 2 "AMI" 3 "All CVD", replace
label define sex_table   1 "Female" 2 "Male" 3 "Total", replace
label values etype etype_table
label values sex sex_table
label variable denominator_count             "Non-DCO hospital events before suppression"
label variable confirmed_deaths              "Confirmed in-hospital deaths before suppression"
label variable probable_deaths               "Probable in-hospital deaths before suppression"
label variable confirmed_cf_percent          "Confirmed in-hospital case-fatality percentage"
label variable confirmed_probable_cf_percent "Confirmed plus probable case-fatality percentage"
label variable coverage_end                  "Dataset coverage end date"

sort period_number etype sex
isid period_number etype sex
label data "BNR CVD Table 6: in-hospital case fatality, unsuppressed staging data"
save "`staging_data'/table_06_case_fatality.dta", replace
export delimited using "`staging_data'/table_06_case_fatality.csv", replace


* =============================================================================
* M. TABLE 7 -- MEDIAN LENGTH OF HOSPITAL STAY
* =============================================================================
* Definition follows the established public table:
*   - non-DCO hospital events;
*   - patients confirmed alive at discharge (cf==1);
*   - length of stay = discharge date minus admission date;
*   - grouped by event year, event type and sex.
*
* Negative or unusually long stays are not silently changed. They are counted
* in the QA section so analysts can review upstream data quality.

use `analysis_input', clear
drop if dco == 1
keep if inrange(yoe, 2010, `release_year')
keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)

gen double event_to_death_days = dod - doe
gen byte cf = sadi
recode cf (2=3)
replace cf = 2 if missing(sadi) & !missing(dod) & event_to_death_days > 28
replace cf = 4 if missing(sadi) & !missing(dod) & event_to_death_days <= 7
replace cf = 5 if missing(sadi) & !missing(dod) & ///
    inrange(event_to_death_days, 8, 28)
replace cf = .a if missing(cf)

gen double length_of_stay = dodi - doa
keep if cf == 1

collapse (count) support_count=length_of_stay ///
         (p50) median_days=length_of_stay ///
         (p25) lower_quartile_days=length_of_stay ///
         (p75) upper_quartile_days=length_of_stay, ///
         by(yoe etype sex)

rename yoe year
gen str14 period_status = "complete"
replace period_status = "year_to_date" if year == `release_year' & `release_month' < 12
gen str10 coverage_end = "`coverage'"

label define etype_table 1 "Stroke" 2 "AMI" 3 "All CVD", replace
label define sex_table   1 "Female" 2 "Male" 3 "Total", replace
label values etype etype_table
label values sex sex_table
label variable support_count        "Stays contributing to summary before suppression"
label variable median_days          "Median length of stay in days"
label variable lower_quartile_days  "Lower quartile length of stay in days"
label variable upper_quartile_days  "Upper quartile length of stay in days"
label variable period_status        "Completeness of reporting period"
label variable coverage_end         "Dataset coverage end date"

sort year etype sex
isid year etype sex
label data "BNR CVD Table 7: length of stay, unsuppressed staging data"
save "`staging_data'/table_07_length_of_stay.dta", replace
export delimited using "`staging_data'/table_07_length_of_stay.csv", replace


* =============================================================================
* N. STRUCTURAL QA SUMMARY
* =============================================================================

use `analysis_input', clear
quietly count
local qa_observations = r(N)
quietly count if missing(age70)
local qa_missing_age70 = r(N)
quietly count if inrange(yoe, 2010, `incidence_end_year') & ///
    inlist(etype, 1, 2) & inlist(sex, 1, 2) & missing(age5)
local qa_inc_age5_with_dco = r(N)
quietly count if inrange(yoe, 2010, `incidence_end_year') & ///
    inlist(etype, 1, 2) & inlist(sex, 1, 2) & dco != 1 & missing(age5)
local qa_inc_age5_no_dco = r(N)
quietly count if dodi - doa < 0 & !missing(dodi, doa)
local qa_negative_stay = r(N)
quietly count if dodi - doa >= 60 & !missing(dodi, doa)
local qa_long_stay = r(N)
quietly count if dod < doe & !missing(dod, doe)
local qa_death_before_event = r(N)

tempname qa
file open `qa' using "`staging_review'/qa_summary.txt", write text replace
file write `qa' "BNR CVD tables Step 1 QA summary" _n
file write `qa' "Package: `package_id'" _n
file write `qa' "Input: `input_dataset_id'" _n
file write `qa' "Coverage end: `coverage'" _n _n
file write `qa' "Input observations: `qa_observations'" _n
file write `qa' "Missing age70: `qa_missing_age70'" _n
file write `qa' "Missing age5 among incidence events excluding DCO: `qa_inc_age5_no_dco'" _n
file write `qa' "Missing age5 among incidence events including DCO: `qa_inc_age5_with_dco'" _n
file write `qa' "Missing-age events are excluded from incidence rates because no age-specific population denominator can be assigned." _n
file write `qa' "Negative discharge-minus-admission stays: `qa_negative_stay'" _n
file write `qa' "Stays of 60 days or longer: `qa_long_stay'" _n
file write `qa' "Deaths dated before event: `qa_death_before_event'" _n _n
file write `qa' "These counts are review flags. No additional cleaning was applied." _n
file close `qa'

* =============================================================================
* O. PACKAGE METADATA AND CATALOGUE
* =============================================================================

local created_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")

tempname package
file open `package' using "`staging_metadata'/package.yml", write text replace
file write `package' "package_id: `package_id'" _n
file write `package' "product_type: tables" _n
file write `package' "domain: cvd" _n
file write `package' "workflow_step: 1" _n
file write `package' "status: unsuppressed_staging" _n
file write `package' "release: `release'" _n
file write `package' "coverage_end: `coverage'" _n
file write `package' "input_dataset_id: `input_dataset_id'" _n
file write `package' "created: `created_date'" _n
file write `package' "disclosure_control: not_yet_applied" _n
file close `package'

tempname manifest
file open `manifest' using "`staging_metadata'/input_manifest.csv", ///
    write text replace
file write `manifest' "input_type,input_id,path" _n
file write `manifest' "step3_dataset,`input_dataset_id',`input_file'" _n
file write `manifest' "step3_metadata,`input_dataset_id',`input_yml'" _n
file write `manifest' "population_reference,brb_pop,`population_file'" _n
file write `manifest' "standard_population,who_std,`who_file'" _n
file close `manifest'

tempname catalogue
file open `catalogue' using "`staging_metadata'/table_catalogue.csv", ///
    write text replace
file write `catalogue' "display_order,table_id,title,dataset_stem" _n
file write `catalogue' "1,annual_event_counts,Annual event counts,table_01_annual_event_counts" _n
file write `catalogue' "2,monthly_event_counts,Monthly event counts,table_02_monthly_event_counts" _n
file write `catalogue' "3,age70_event_percent,Event percentage by broad age group,table_03_age70_event_percent" _n
file write `catalogue' "4,incidence_rates,Annual incidence rates,table_04_incidence_rates" _n
file write `catalogue' "5,incidence_rate_ratios,Incidence rate ratios,table_05_incidence_rate_ratios" _n
file write `catalogue' "6,case_fatality,In-hospital case fatality,table_06_case_fatality" _n
file write `catalogue' "7,length_of_stay,Median length of hospital stay,table_07_length_of_stay" _n
file close `catalogue'

tempname readme
file open `readme' using "`staging_package'/readme.txt", write text replace
file write `readme' "BNR CVD routine tables: private Step 1 staging package" _n _n
file write `readme' "Package: `package_id'" _n
file write `readme' "Release: `release'" _n
file write `readme' "Coverage end: `coverage'" _n _n
file write `readme' "The datasets folder contains unsuppressed analytical tables." _n
file write `readme' "Current-year outputs are retained as permanent year-to-date rows or periods." _n
file write `readme' "Do not copy this package to a public location." _n
file write `readme' "Table Step 2 disclosure review and approval are still required." _n
file close `readme'


* =============================================================================
* P. OPERATIONAL RUN SUMMARY
* =============================================================================

qui {
    noi display as text _n "============================================================"
    noi display as text    "TABLE STEP 1: OPERATIONAL RUN SUMMARY"
    noi display as text    "============================================================"
    noi display as result  "Status:           COMPLETED - PRIVATE UNSUPPRESSED STAGING"
    noi display as result  "Package:          `package_id'"
    noi display as result  "Input release:    `release' version `version2'"
    noi display as result  "Coverage through: `coverage'"
    noi display as result  "Table datasets:   7 DTA files and 7 CSV files"
    noi display as result  "Staging package:  `staging_package'"
    noi display as text    "Suppression:      NOT APPLIED"
    noi display as text    "Publication:      NOT PERFORMED"
    noi display as text    "Next: review the staging package, then run Table Step 2."
    noi display as text    "============================================================"
}

log close

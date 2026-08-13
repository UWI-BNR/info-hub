/*
===============================================================================
DO-FILE:     bnr_step2a_cvd_tables.do
PROJECT:     BNR Info-Hub
PURPOSE:     Table workflow Step 2A: suppress and prepare CVD tables for review
STATUS:      Operational production file

OVERVIEW
  This file reads the seven UNSUPPRESSED datasets created by Table Step 1,
  applies the approved BNR disclosure-control rules, and creates one complete
  PUBLIC-READY BUT UNAPPROVED package inside private staging.

  Step 2A creates:
    - seven suppressed public-safe DTA/CSV datasets;
    - the exact workbook proposed for publication;
    - the exact Markdown fragments proposed for the website;
    - package and disclosure metadata;
    - a private suppression worklist and review workbook; and
    - a proposed public manifest for Table Step 3.

  It deliberately does NOT:
    - approve the package;
    - create approval.yml;
    - copy files to outputs/public/;
    - copy files into the Quarto website; or
    - render or deploy the website.

INPUT
  outputs/staging/tables/cvd/cvd_tables_YYYY_MM/
    datasets/      seven unsuppressed Step 1 datasets
    metadata/      completed Step 1 metadata
    review/        completed Step 1 QA summary

OUTPUT
  The same private staging package gains:
    review/
      suppression_worklist.csv
      cross_table_disclosure_check.csv
      suppression_review.xlsx
      suppression_summary.txt
    public_ready/
      datasets/    seven suppressed DTA/CSV pairs
      workbook/    workbook_cvd_annual_tabulations.xlsx
      tables/      seven generated Markdown fragments
      metadata/    package.yml, table_catalogue.csv, disclosure_control.yml
      public_manifest.csv
      readme.txt

DISCLOSURE RULE
  Primary threshold: a contributing frequency from 1 to 5. A true zero is not
  automatically primary-suppressed.
  Complementary suppression is applied where a published total, paired
  percentage, DCO sensitivity result, or another table could reveal a
  primary-suppressed cell.

COMMAND-LINE USE
  do bnr_step2a_cvd_tables.do release_year release_month [replace]

EXAMPLE
  do bnr_step2a_cvd_tables.do 2024 1 replace
===============================================================================
*/


* =============================================================================
* A. INITIALISE AND LOAD SHARED PATHS
* =============================================================================

clear all
set more off

do "scripts/stata/config/bnr_paths_LOCAL.do"


* =============================================================================
* B. READ AND VALIDATE COMMAND-LINE INPUTS
* =============================================================================

args release_year release_month replace_option

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Table Step 2A stopped: required inputs were not supplied."
    display as text  "Usage: do bnr_step2a_cvd_tables.do release_year release_month [replace]"
    exit 198
}

foreach item in release_year release_month {
    capture confirm integer number ``item''
    if _rc {
        display as error "Table Step 2A stopped: `item' must be an integer."
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    display as error "Table Step 2A stopped: release_month must be 1 to 12."
    exit 198
}

if "`replace_option'" != "" & lower("`replace_option'") != "replace" {
    display as error "Table Step 2A stopped: optional third argument must be replace."
    exit 198
}

local replace_review = lower("`replace_option'") == "replace"
local month2  : display %02.0f `release_month'
local package_id "cvd_tables_`release_year'_`month2'"

local coverage_date = dofm(ym(`release_year', `release_month') + 1) - 1
local coverage : display %tdCCYY-NN-DD `coverage_date'


* =============================================================================
* C. DECLARE PRIVATE INPUT AND OUTPUT FOLDERS
* =============================================================================

local staging_package "$BNR_STAGING/tables/cvd/`package_id'"
local step1_data       "`staging_package'/datasets"
local step1_metadata   "`staging_package'/metadata"
local review_dir       "`staging_package'/review"

* public_ready is intentionally inside PRIVATE staging. It contains the exact
* products proposed for release, but nothing is public until Steps 2B and 3.
local public_ready     "`staging_package'/public_ready"
local public_data      "`public_ready'/datasets"
local public_workbook  "`public_ready'/workbook"
local public_tables    "`public_ready'/tables"
local public_metadata  "`public_ready'/metadata"

local download_xlsx    "`public_workbook'/workbook_cvd_annual_tabulations.xlsx"
local review_xlsx      "`review_dir'/suppression_review.xlsx"
local worklist_csv     "`review_dir'/suppression_worklist.csv"
local cross_table_csv  "`review_dir'/cross_table_disclosure_check.csv"

* Step 2A must never create a new package in place of Step 1.
capture confirm file "`step1_metadata'/package.yml"
if _rc {
    display as error "Table Step 2A stopped: the Step 1 package was not found."
    display as result "`staging_package'"
    exit 601
}

capture mkdir "`public_ready'"
if _rc & `replace_review' == 0 {
    display as error "Table Step 2A stopped: public_ready already exists."
    display as result "`public_ready'"
    display as text "Review the existing products or explicitly authorise replace."
    exit 602
}

capture mkdir "`public_data'"
capture mkdir "`public_workbook'"
capture mkdir "`public_tables'"
capture mkdir "`public_metadata'"

* Rebuilding Step 2A invalidates any earlier approval. Step 2B will create a
* fresh approval only after the rebuilt products have been reviewed.
if `replace_review' == 1 {
    capture erase "`public_ready'/approval.yml"
}

cap log close
log using "$BNR_PRIVATE_LOGS/`package_id'_step2a.log", text replace

display as text _n "------------------------------------------------------------"
display as text    "BNR CVD TABLE WORKFLOW: STEP 2A"
display as text    "------------------------------------------------------------"
display as result  "Package:          `package_id'"
display as result  "Coverage through: `coverage'"
display as result  "Step 1 input:     `step1_data'"
display as result  "Public-ready:     `public_ready'"
display as text    "Status:           PRIVATE AND UNAPPROVED"
display as text    "------------------------------------------------------------"


* =============================================================================
* D. VALIDATE THE COMPLETE STEP 1 INPUT CONTRACT
* =============================================================================

local table1 "table_01_annual_event_counts"
local table2 "table_02_monthly_event_counts"
local table3 "table_03_age70_event_percent"
local table4 "table_04_incidence_rates"
local table5 "table_05_incidence_rate_ratios"
local table6 "table_06_case_fatality"
local table7 "table_07_length_of_stay"

foreach table_name in table1 table2 table3 table4 table5 table6 table7 {
    capture confirm file "`step1_data'/``table_name''.dta"
    if _rc {
        display as error "Table Step 2A stopped: a required Step 1 dataset is missing."
        display as result "`step1_data'/``table_name''.dta"
        exit 601
    }
}

foreach required_file in ///
    "`step1_metadata'/input_manifest.csv" ///
    "`step1_metadata'/table_catalogue.csv" ///
    "`review_dir'/qa_summary.txt" {
    capture confirm file "`required_file'"
    if _rc {
        display as error "Table Step 2A stopped: Step 1 is incomplete."
        display as result "`required_file'"
        exit 601
    }
}

* Every input dataset must identify the same selected coverage end date.
foreach table_name in table1 table2 table3 table4 table5 table6 table7 {
    quietly use "`step1_data'/``table_name''.dta", clear
    capture confirm variable coverage_end
    if _rc {
        display as error "Table Step 2A stopped: coverage_end is missing from ``table_name''."
        exit 111
    }
    quietly count if coverage_end != "`coverage'"
    if r(N) > 0 {
        display as error "Table Step 2A stopped: the selected release does not match ``table_name''."
        display as text  "Expected coverage_end: `coverage'"
        exit 459
    }
}


* =============================================================================
* D2. BUILD AND AUDIT THE JOINT COUNT-TABLE DISCLOSURE PLAN
* =============================================================================
* Tables 1 and 2 publish different views of the same event counts. They must
* therefore be controlled as one release, not as two independent tables.
*
* The plan deliberately preserves disease totals where possible:
*   - if a sex-specific disease count is primary-suppressed, the other sex for
*     that disease is complementary-suppressed and the disease total remains;
*   - affected female/male All-CVD margins are also suppressed, because those
*     margins could otherwise recreate the protected disease-by-sex cells;
*   - if an annual total and its monthly components would leave exactly one
*     hidden term, another monthly component is hidden deterministically; and
*   - if no second covered month exists, the annual total is hidden instead.
*
* The final audit represents every published additive equation and stops the
* run if any equation contains exactly one hidden term. In that situation the
* hidden value could be recovered by subtraction.

tempfile t1_event_totals t1_sex_totals t1_grand ///
         t2_annual_totals t1_sdc_initial t1_sdc_plan ///
         t2_sdc_initial t2_sdc_plan annual_initial annual_cross_flags ///
         audit_t1 audit_t2 audit_cross combined_disclosure_audit

* ---- D2.1 Reconcile the unsuppressed values before planning suppression ----

use "`step1_data'/`table1'.dta", clear

preserve
    keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)
    collapse (sum) calculated_total=event_count, by(year etype)
    save `t1_event_totals', replace
restore

preserve
    keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)
    collapse (sum) calculated_total=event_count, by(year sex)
    save `t1_sex_totals', replace
restore

preserve
    keep if inlist(etype, 1, 2) & inlist(sex, 1, 2)
    collapse (sum) calculated_total=event_count, by(year)
    save `t1_grand', replace
restore

preserve
    keep if inlist(etype, 1, 2) & sex == 3
    keep year etype event_count
    rename event_count published_total
    merge 1:1 year etype using `t1_event_totals', assert(match) nogen
    count if published_total != calculated_total
    if r(N) {
        display as error "Table Step 2A stopped: Table 1 event totals do not equal the sex-specific cells."
        exit 459
    }
restore

preserve
    keep if etype == 3 & inlist(sex, 1, 2)
    keep year sex event_count
    rename event_count published_total
    merge 1:1 year sex using `t1_sex_totals', assert(match) nogen
    count if published_total != calculated_total
    if r(N) {
        display as error "Table Step 2A stopped: Table 1 sex totals do not equal the disease-specific cells."
        exit 459
    }
restore

preserve
    keep if etype == 3 & sex == 3
    keep year event_count
    rename event_count published_total
    merge 1:1 year using `t1_grand', assert(match) nogen
    count if published_total != calculated_total
    if r(N) {
        display as error "Table Step 2A stopped: Table 1 grand totals do not equal the four detail cells."
        exit 459
    }
restore

use "`step1_data'/`table2'.dta", clear

preserve
    keep if inlist(etype, 1, 2)
    reshape wide event_count, i(year month cell_available) j(etype)
    rename event_count1 stroke_count
    rename event_count2 ami_count
    tempfile t2_disease_components
    save `t2_disease_components', replace
restore

keep if etype == 3
keep year month cell_available event_count
rename event_count all_cvd_count
merge 1:1 year month cell_available using `t2_disease_components', assert(match) nogen
count if cell_available == 1 & all_cvd_count != stroke_count + ami_count
if r(N) {
    display as error "Table Step 2A stopped: Table 2 All-CVD counts do not equal Stroke plus AMI."
    exit 459
}

use "`step1_data'/`table2'.dta", clear
keep if cell_available == 1
collapse (sum) monthly_total=event_count, by(year etype)
save `t2_annual_totals', replace

use "`step1_data'/`table1'.dta", clear
keep if sex == 3
keep year etype event_count
rename event_count annual_total
merge 1:1 year etype using `t2_annual_totals', assert(match) nogen
count if annual_total != monthly_total
if r(N) {
    display as error "Table Step 2A stopped: annual counts in Table 1 do not equal the covered monthly counts in Table 2."
    exit 459
}

* ---- D2.2 Initial Table 1 plan: protect the complete 3 x 3 margins ----

use "`step1_data'/`table1'.dta", clear
gen byte suppress_primary = inrange(event_count, 1, 5)
gen byte suppress_secondary = 0
gen str200 suppression_reason = ""
replace suppression_reason = "Event count is between 1 and 5." if suppress_primary

* Preserve disease totals by hiding both sex-specific disease cells whenever
* either one is primary-suppressed.
gen byte primary_detail = suppress_primary & inlist(etype, 1, 2) & inlist(sex, 1, 2)
bysort year etype: egen byte affected_event = max(primary_detail)
replace suppress_secondary = 1 if affected_event & inlist(etype, 1, 2) & ///
    inlist(sex, 1, 2) & !suppress_primary
replace suppression_reason = "Companion sex-specific count is hidden so the disease total can remain public." if ///
    suppress_secondary & suppression_reason == ""

* A sex-specific All-CVD margin would recreate a hidden disease-by-sex cell
* when the other disease count is public. Hide both affected sex margins.
gen byte hidden_detail = (suppress_primary | suppress_secondary) & ///
    inlist(etype, 1, 2) & inlist(sex, 1, 2)
bysort year sex: egen byte hidden_in_sex = max(hidden_detail)
replace suppress_secondary = 1 if etype == 3 & inlist(sex, 1, 2) & ///
    hidden_in_sex & !suppress_primary
replace suppression_reason = "Sex-specific All-CVD margin is hidden to protect a disease-by-sex count." if ///
    suppress_secondary & suppression_reason == ""

* If a disease total, sex total or grand total is itself primary-suppressed,
* hide its companion margin as well. This closes all six equations in the
* Table 1 3 x 3 layout.
gen byte hidden_event_total = (suppress_primary | suppress_secondary) & ///
    inlist(etype, 1, 2) & sex == 3
bysort year: egen byte any_hidden_event_total = max(hidden_event_total)
replace suppress_secondary = 1 if any_hidden_event_total & ///
    inlist(etype, 1, 2) & sex == 3 & !suppress_primary
replace suppression_reason = "Companion disease total is hidden to protect an annual margin." if ///
    suppress_secondary & suppression_reason == ""

gen byte hidden_sex_total = (suppress_primary | suppress_secondary) & ///
    etype == 3 & inlist(sex, 1, 2)
bysort year: egen byte any_hidden_sex_total = max(hidden_sex_total)
replace suppress_secondary = 1 if any_hidden_sex_total & etype == 3 & ///
    inlist(sex, 1, 2) & !suppress_primary
replace suppression_reason = "Companion sex total is hidden to protect an annual margin." if ///
    suppress_secondary & suppression_reason == ""

gen byte hidden_grand = suppress_primary & etype == 3 & sex == 3
bysort year: egen byte any_hidden_grand = max(hidden_grand)
replace suppress_secondary = 1 if any_hidden_grand & ///
    ((inlist(etype, 1, 2) & sex == 3) | ///
     (etype == 3 & inlist(sex, 1, 2))) & !suppress_primary
replace suppression_reason = "Annual margin is hidden because the grand total is protected." if ///
    suppress_secondary & suppression_reason == ""

keep year etype sex suppress_primary suppress_secondary suppression_reason
save `t1_sdc_initial', replace

preserve
    keep if sex == 3
    keep year etype suppress_primary suppress_secondary
    rename suppress_primary annual_primary
    rename suppress_secondary annual_secondary
    save `annual_initial', replace
restore

* ---- D2.3 Initial Table 2 plan: protect each monthly component equation ----

use "`step1_data'/`table2'.dta", clear
gen byte suppress_primary = inrange(event_count, 1, 5) & cell_available == 1
gen byte suppress_secondary = 0
gen str200 suppression_reason = ""
replace suppression_reason = "Monthly event count is between 1 and 5." if suppress_primary

gen byte hidden_disease = suppress_primary & inlist(etype, 1, 2)
bysort year month: egen byte hidden_disease_in_month = max(hidden_disease)
replace suppress_secondary = 1 if etype == 3 & hidden_disease_in_month & ///
    !suppress_primary
replace suppression_reason = "Monthly All-CVD total is hidden because it contains a protected disease count." if ///
    suppress_secondary & suppression_reason == ""

merge m:1 year etype using `annual_initial', assert(match) nogen
gen byte monthly_hidden = (suppress_primary | suppress_secondary) & cell_available
bysort year etype: egen int hidden_months = total(monthly_hidden)
bysort year etype: egen int covered_months = total(cell_available)

* Where the annual total is public and only one month is hidden, select the
* smallest remaining covered month (earliest month breaks ties) as the second
* hidden term. If there is no second covered month, flag the annual total.
gen byte companion_candidate = cell_available & !monthly_hidden
bysort year etype: egen double companion_value = ///
    min(cond(companion_candidate, event_count, .))
bysort year etype: egen byte companion_month = ///
    min(cond(companion_candidate & event_count == companion_value, month, .))

gen byte annual_needs_secondary = hidden_months == 1 & ///
    annual_primary == 0 & annual_secondary == 0 & covered_months == 1

replace suppress_secondary = 1 if hidden_months == 1 & ///
    annual_primary == 0 & annual_secondary == 0 & covered_months > 1 & ///
    month == companion_month & !suppress_primary
replace suppression_reason = "Additional month is hidden so the annual total cannot reveal the protected month." if ///
    suppress_secondary & suppression_reason == ""

preserve
    keep if annual_needs_secondary
    keep year etype
    quietly count
    if r(N) > 0 {
        duplicates drop
    }
    gen byte annual_cross_secondary = 1
    save `annual_cross_flags', replace
restore

drop annual_primary annual_secondary monthly_hidden hidden_months covered_months ///
     companion_candidate companion_value companion_month annual_needs_secondary ///
     hidden_disease hidden_disease_in_month
save `t2_sdc_initial', replace

* ---- D2.4 Apply cross-table annual flags, then close Table 1 margins again ----

use `t1_sdc_initial', clear
merge m:1 year etype using `annual_cross_flags', nogen
replace annual_cross_secondary = 0 if missing(annual_cross_secondary)
replace suppress_secondary = 1 if sex == 3 & annual_cross_secondary & ///
    !suppress_primary
replace suppression_reason = "Annual total is hidden because only one covered monthly component exists and is protected." if ///
    sex == 3 & annual_cross_secondary & !suppress_primary

gen byte hidden_event_total = (suppress_primary | suppress_secondary) & ///
    inlist(etype, 1, 2) & sex == 3
bysort year: egen byte any_hidden_event_total = max(hidden_event_total)
replace suppress_secondary = 1 if any_hidden_event_total & ///
    inlist(etype, 1, 2) & sex == 3 & !suppress_primary
replace suppression_reason = "Companion disease total is hidden to protect an annual margin." if ///
    suppress_secondary & suppression_reason == ""

gen byte hidden_sex_total = (suppress_primary | suppress_secondary) & ///
    etype == 3 & inlist(sex, 1, 2)
bysort year: egen byte any_hidden_sex_total = max(hidden_sex_total)
replace suppress_secondary = 1 if any_hidden_sex_total & etype == 3 & ///
    inlist(sex, 1, 2) & !suppress_primary
replace suppression_reason = "Companion sex total is hidden to protect an annual margin." if ///
    suppress_secondary & suppression_reason == ""

gen byte hidden_grand = (suppress_primary | suppress_secondary) & ///
    etype == 3 & sex == 3
bysort year: egen byte any_hidden_grand = max(hidden_grand)
replace suppress_secondary = 1 if any_hidden_grand & ///
    ((inlist(etype, 1, 2) & sex == 3) | ///
     (etype == 3 & inlist(sex, 1, 2))) & !suppress_primary
replace suppression_reason = "Annual margin is hidden because the grand total is protected." if ///
    suppress_secondary & suppression_reason == ""

drop annual_cross_secondary hidden_event_total any_hidden_event_total ///
     hidden_sex_total any_hidden_sex_total hidden_grand any_hidden_grand
save `t1_sdc_plan', replace

* ---- D2.5 Ensure a hidden annual total is not recreated by public months ----

preserve
    keep if sex == 3
    keep year etype suppress_primary suppress_secondary
    rename suppress_primary annual_primary
    rename suppress_secondary annual_secondary
    tempfile annual_final
    save `annual_final', replace
restore

use `t2_sdc_initial', clear
merge m:1 year etype using `annual_final', assert(match) nogen
gen byte monthly_hidden = (suppress_primary | suppress_secondary) & cell_available
bysort year etype: egen int hidden_months = total(monthly_hidden)
gen byte annual_hidden = annual_primary | annual_secondary
gen byte equation_has_one_hidden = annual_hidden + hidden_months == 1

gen byte companion_candidate = equation_has_one_hidden & cell_available & !monthly_hidden
bysort year etype: egen double companion_value = ///
    min(cond(companion_candidate, event_count, .))
bysort year etype: egen byte companion_month = ///
    min(cond(companion_candidate & event_count == companion_value, month, .))

replace suppress_secondary = 1 if companion_candidate & ///
    month == companion_month & !suppress_primary
replace suppression_reason = "Additional month is hidden to prevent reconstruction from the annual total." if ///
    suppress_secondary & suppression_reason == ""

drop annual_primary annual_secondary monthly_hidden hidden_months annual_hidden ///
     equation_has_one_hidden companion_candidate companion_value companion_month
save `t2_sdc_plan', replace

* ---- D2.6 Fail-closed audit of every additive publication equation ----

use `t1_sdc_plan', clear
gen byte hidden = suppress_primary | suppress_secondary
gen byte cell = (etype - 1) * 3 + sex
keep year cell hidden
reshape wide hidden, i(year) j(cell)
expand 6
bysort year: gen byte relation = _n
gen str24 check_type = "table_01_margin"
gen str120 cell_key = ""
gen int terms_in_equation = 3
gen int suppressed_terms = .
replace cell_key = "year=" + string(year) + "; Stroke female + male = total" if relation == 1
replace suppressed_terms = hidden1 + hidden2 + hidden3 if relation == 1
replace cell_key = "year=" + string(year) + "; AMI female + male = total" if relation == 2
replace suppressed_terms = hidden4 + hidden5 + hidden6 if relation == 2
replace cell_key = "year=" + string(year) + "; female Stroke + AMI = All CVD" if relation == 3
replace suppressed_terms = hidden1 + hidden4 + hidden7 if relation == 3
replace cell_key = "year=" + string(year) + "; male Stroke + AMI = All CVD" if relation == 4
replace suppressed_terms = hidden2 + hidden5 + hidden8 if relation == 4
replace cell_key = "year=" + string(year) + "; Stroke + AMI totals = All CVD" if relation == 5
replace suppressed_terms = hidden3 + hidden6 + hidden9 if relation == 5
replace cell_key = "year=" + string(year) + "; female + male totals = All CVD" if relation == 6
replace suppressed_terms = hidden7 + hidden8 + hidden9 if relation == 6
keep check_type cell_key terms_in_equation suppressed_terms
save `audit_t1', replace

use `t2_sdc_plan', clear
gen byte hidden = suppress_primary | suppress_secondary
keep year month etype hidden
reshape wide hidden, i(year month) j(etype)
gen str24 check_type = "table_02_margin"
gen str120 cell_key = "year=" + string(year) + "; month=" + string(month) + ///
    "; Stroke + AMI = All CVD"
gen int terms_in_equation = 3
gen int suppressed_terms = hidden1 + hidden2 + hidden3
keep check_type cell_key terms_in_equation suppressed_terms
save `audit_t2', replace

use `t2_sdc_plan', clear
gen byte monthly_hidden = (suppress_primary | suppress_secondary) & cell_available
collapse (sum) covered_months=cell_available suppressed_months=monthly_hidden, by(year etype)
merge 1:1 year etype using `annual_final', assert(match) nogen
gen byte annual_hidden = annual_primary | annual_secondary
gen str24 check_type = "table_01_vs_table_02"
gen str120 cell_key = "year=" + string(year) + "; event=" + string(etype) + ///
    "; annual total = sum of covered months"
gen int terms_in_equation = covered_months + 1
gen int suppressed_terms = suppressed_months + annual_hidden
keep check_type cell_key terms_in_equation suppressed_terms
save `audit_cross', replace

use `audit_t1', clear
append using `audit_t2' `audit_cross'
gen byte exact_reconstruction_risk = suppressed_terms == 1
gen str6 check_status = cond(exact_reconstruction_risk, "FAIL", "PASS")
order check_type cell_key terms_in_equation suppressed_terms ///
      exact_reconstruction_risk check_status
sort check_type cell_key
save `combined_disclosure_audit', replace

quietly count
local cross_table_checks = r(N)
quietly count if exact_reconstruction_risk
local cross_table_failures = r(N)
export delimited using "`cross_table_csv'", replace

if `cross_table_failures' {
    display as error "Table Step 2A stopped: the disclosure audit found a reconstructable hidden count."
    display as result "Review: `cross_table_csv'"
    exit 459
}


* =============================================================================
* E. TABLE 1 -- ANNUAL EVENT COUNTS
* =============================================================================
* Suppression flags come from the joint Table 1/Table 2 plan above. The plan
* protects all annual margins while retaining disease totals where possible.

use "`step1_data'/`table1'.dta", clear
isid year etype sex

foreach required_variable in year etype sex event_count period_status coverage_end {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Table Step 2A stopped: Table 1 lacks `required_variable'."
        exit 111
    }
}

gen double review_value = event_count
merge 1:1 year etype sex using `t1_sdc_plan', assert(match) nogen

gen str12 suppression_status = "none"
replace suppression_status = "primary"   if suppress_primary == 1
replace suppression_status = "secondary" if suppress_secondary == 1 & suppress_primary == 0

decode etype, gen(event_group)
decode sex,   gen(sex_group)

quietly count if suppression_status == "primary"
local t1_primary = r(N)
quietly count if suppression_status == "secondary"
local t1_secondary = r(N)

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_01"
    gen str120 cell_key = "year=" + string(year) + "; event=" + event_group + "; sex=" + sex_group
    gen str50 measure = "event_count"
    gen double unsuppressed_value = review_value
    gen double support_count = review_value
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work1
    save `work1', replace
restore







replace event_count = . if suppression_status != "none"
gen str14 display_count = cond(missing(event_count), "—", trim(string(event_count, "%12.0fc")))

drop review_value suppress_primary suppress_secondary suppression_reason
order year etype event_group sex sex_group event_count display_count ///
      suppression_status period_status coverage_end

label variable event_count        "Registered event count; missing when suppressed"
label variable display_count      "Public display value"
label variable suppression_status "Disclosure-control status"
label data "BNR CVD Table 1: annual event counts, public-ready and unapproved"

save "`public_data'/`table1'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    replace display_count = "Suppressed" if suppression_status != "none"
    export delimited using "`public_data'/`table1'.csv", replace
restore

preserve
    gen byte column = (etype - 1) * 3 + sex
    keep year period_status column display_count
    reshape wide display_count, i(year period_status) j(column)
    rename display_count1 stroke_female
    rename display_count2 stroke_male
    rename display_count3 stroke_total
    rename display_count4 ami_female
    rename display_count5 ami_male
    rename display_count6 ami_total
    rename display_count7 cvd_female
    rename display_count8 cvd_male
    rename display_count9 cvd_total
    gen str20 year_display = string(year)
    replace year_display = string(year) + " (YTD)" if period_status == "year_to_date"
    order year_display stroke_female stroke_male stroke_total ///
          ami_female ami_male ami_total cvd_female cvd_male cvd_total
    drop year period_status
    label variable year_display  "Year"
    label variable stroke_female "Stroke: female"
    label variable stroke_male   "Stroke: male"
    label variable stroke_total  "Stroke: total"
    label variable ami_female    "AMI: female"
    label variable ami_male      "AMI: male"
    label variable ami_total     "AMI: total"
    label variable cvd_female    "All CVD: female"
    label variable cvd_male      "All CVD: male"
    label variable cvd_total     "All CVD: total"
    tempfile present1
    save `present1', replace
restore


* =============================================================================
* F. TABLE 2 -- MONTHLY EVENT COUNTS
* =============================================================================
* Suppression flags come from the joint plan. It protects both the within-month
* Stroke + AMI equation and the annual-total = sum-of-months equation.

use "`step1_data'/`table2'.dta", clear
isid year month etype

gen double review_value = event_count
merge 1:1 year month etype using `t2_sdc_plan', assert(match) nogen

gen str12 suppression_status = "none"
replace suppression_status = "primary"   if suppress_primary == 1
replace suppression_status = "secondary" if suppress_secondary == 1

decode etype, gen(event_group)
quietly count if suppression_status == "primary"
local t2_primary = r(N)
quietly count if suppression_status == "secondary"
local t2_secondary = r(N)

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_02"
    gen str120 cell_key = "year=" + string(year) + "; month=" + string(month) + "; event=" + event_group
    gen str50 measure = "event_count"
    gen double unsuppressed_value = review_value
    gen double support_count = review_value
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work2
    save `work2', replace
restore

replace event_count = . if suppression_status != "none"
gen str14 display_count = ""
replace display_count = "—" if suppression_status != "none"
replace display_count = trim(string(event_count, "%12.0fc")) if ///
    suppression_status == "none" & cell_available == 1
replace display_count = "Not available" if cell_available == 0

drop review_value suppress_primary suppress_secondary suppression_reason
order year month etype event_group event_count display_count ///
      suppression_status cell_available period_status coverage_end

label variable event_count        "Registered event count; missing when suppressed or unavailable"
label variable display_count      "Public display value"
label variable suppression_status "Disclosure-control status"
label data "BNR CVD Table 2: monthly event counts, public-ready and unapproved"

save "`public_data'/`table2'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    replace display_count = "Suppressed" if suppression_status != "none"
    export delimited using "`public_data'/`table2'.csv", replace
restore

preserve
    keep year month etype display_count
    reshape wide display_count, i(year month) j(etype)
    rename display_count1 stroke
    rename display_count2 ami
    rename display_count3 all_cvd
    gen str12 month_name = word("January February March April May June July August September October November December", month)
    order year month month_name stroke ami all_cvd
    label variable year       "Year"
    label variable month      "Month number"
    label variable month_name "Month"
    label variable stroke     "Stroke"
    label variable ami        "AMI"
    label variable all_cvd    "All CVD"
    tempfile present2
    save `present2', replace
restore


* =============================================================================
* G. TABLE 3 -- EVENT PERCENTAGE BY BROAD AGE GROUP
* =============================================================================
* The two percentages within each event/sex/period group are complementary.
* If either age-group numerator is between 1 and 5, both percentages are hidden.

use "`step1_data'/`table3'.dta", clear
isid period etype sex age70

gen double review_value = percentage
gen byte suppress_primary = inrange(numerator_count, 1, 5)
bysort period etype sex: egen byte primary_in_pair = max(suppress_primary)
gen byte suppress_secondary = primary_in_pair == 1 & suppress_primary == 0

gen str12 suppression_status = "none"
replace suppression_status = "primary"   if suppress_primary == 1
replace suppression_status = "secondary" if suppress_secondary == 1

decode period, gen(period_group)
decode etype,  gen(event_group)
decode sex,    gen(sex_group)
gen str12 age_group = cond(age70 == 0, "Under 70", "70 and over")

gen str200 suppression_reason = ""
replace suppression_reason = "Age-group numerator is between 1 and 5." if suppression_status == "primary"
replace suppression_reason = "Paired percentage is hidden to protect its primary-suppressed complement." if suppression_status == "secondary"

quietly count if suppression_status == "primary"
local t3_primary = r(N)
quietly count if suppression_status == "secondary"
local t3_secondary = r(N)

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_03"
    gen str120 cell_key = "period=" + period_group + "; event=" + event_group + ///
        "; sex=" + sex_group + "; age=" + age_group
    gen str50 measure = "percentage"
    gen double unsuppressed_value = review_value
    gen double support_count = numerator_count
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work3
    save `work3', replace
restore

replace percentage = . if suppression_status != "none"
gen str12 display_percent = cond(missing(percentage), "—", trim(string(percentage, "%9.1f")))

* Public files retain the percentage and period definitions, not private
* numerators, denominators, missing-age counts, or annual-average counts.
drop review_value suppress_primary suppress_secondary primary_in_pair ///
     suppression_reason numerator_count denominator_count missing_age_count ///
     years_in_period annual_average_numerator annual_average_denominator
order period period_group period_start_year period_end_year months_covered ///
      etype event_group sex sex_group age70 age_group percentage ///
      display_percent suppression_status coverage_end

label variable percentage         "Percentage; missing when suppressed"
label variable display_percent    "Public display value"
label variable suppression_status "Disclosure-control status"
label data "BNR CVD Table 3: broad age-group percentages, public-ready and unapproved"

save "`public_data'/`table3'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    replace display_percent = "Suppressed" if suppression_status != "none"
    export delimited using "`public_data'/`table3'.csv", replace
restore

preserve
    keep period period_group period_start_year period_end_year months_covered ///
         event_group sex_group age70 display_percent
    reshape wide display_percent, ///
        i(period period_group period_start_year period_end_year months_covered event_group sex_group) ///
        j(age70)
    rename display_percent0 under_70
    rename display_percent1 age_70_plus
    gen str50 period_display = period_group + " (" + ///
        string(period_start_year) + "-" + string(period_end_year) + ///
        ", months 1-" + string(months_covered) + ")"
    order period period_display event_group sex_group under_70 age_70_plus
    sort period event_group sex_group
    drop period_start_year period_end_year months_covered period_group
    label variable period_display "Period"
    label variable event_group    "Event"
    label variable sex_group      "Sex"
    label variable under_70       "Under 70 (%)"
    label variable age_70_plus    "70 and over (%)"
    tempfile present3
    save `present3', replace
restore
* =============================================================================
* H. TABLE 4 -- ANNUAL INCIDENCE RATES
* =============================================================================
* A complete rate row is hidden when its numerator is between 1 and 5.
*
* Two additional protections are applied:
*   1. If adding DCO events produces a positive increment below 6, both the
*      without-DCO and DCO-added rows are hidden to prevent differencing.
*   2. A both-sex total is hidden when either contributing sex-specific rate
*      has already been suppressed.

use "`step1_data'/`table4'.dta", clear
isid year dco etype sex

gen double review_value = rateadj
gen byte suppress_primary = inrange(numerator_count, 1, 5)

bysort year etype sex: egen double no_dco_count = ///
    max(cond(dco == 0, numerator_count, .))
gen double dco_increment = numerator_count - no_dco_count if dco == 1
bysort year etype sex: egen byte small_dco_increment = ///
    max(inrange(dco_increment, 1, 5))

gen byte suppress_secondary = small_dco_increment == 1 & suppress_primary == 0

* Propagate suppression from female/male rows to the both-sex total.
gen byte detail_suppressed = (suppress_primary == 1 | suppress_secondary == 1) & inlist(sex, 1, 2)
bysort year etype dco: egen byte sex_detail_suppressed = max(detail_suppressed)
replace suppress_secondary = 1 if sex == 3 & sex_detail_suppressed == 1 & suppress_primary == 0

gen str12 suppression_status = "none"
replace suppression_status = "primary"   if suppress_primary == 1
replace suppression_status = "secondary" if suppress_secondary == 1 & suppress_primary == 0

decode etype, gen(event_group)
decode sex,   gen(sex_group)
decode dco,   gen(dco_group)

gen str200 suppression_reason = ""
replace suppression_reason = "Incidence numerator is between 1 and 5." if suppression_status == "primary"
replace suppression_reason = "Without-DCO and DCO-added results are both hidden because their positive increment is fewer than 6." if ///
    suppression_status == "secondary" & small_dco_increment == 1
replace suppression_reason = "Both-sex rate contains a suppressed sex-specific result." if ///
    suppression_status == "secondary" & sex == 3 & small_dco_increment == 0

quietly count if suppression_status == "primary"
local t4_primary = r(N)
quietly count if suppression_status == "secondary"
local t4_secondary = r(N)

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_04"
    gen str120 cell_key = "year=" + string(year) + "; event=" + event_group + ///
        "; sex=" + sex_group + "; DCO=" + dco_group
    gen str50 measure = "incidence rate row"
    gen double unsuppressed_value = review_value
    gen double support_count = numerator_count
    replace support_count = dco_increment if ///
        suppression_status == "secondary" & small_dco_increment == 1 & dco == 1
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work4
    save `work4', replace
restore

foreach rate_variable in crude rateadj lb_gam ub_gam {
    replace `rate_variable' = . if suppression_status != "none"
}

gen str12 display_crude = cond(missing(crude), "—", trim(string(crude, "%9.1f")))
gen str12 display_adjusted = cond(missing(rateadj), "—", trim(string(rateadj, "%9.1f")))
gen str12 display_lower = cond(missing(lb_gam), "—", trim(string(lb_gam, "%9.1f")))
gen str12 display_upper = cond(missing(ub_gam), "—", trim(string(ub_gam, "%9.1f")))

* Numerators and population denominators remain in the private worklist only.
drop review_value suppress_primary suppress_secondary no_dco_count ///
     dco_increment small_dco_increment detail_suppressed sex_detail_suppressed ///
     suppression_reason numerator_count population_denominator
order year etype event_group sex sex_group dco dco_group crude rateadj ///
      lb_gam ub_gam display_crude display_adjusted display_lower display_upper ///
      suppression_status period_status coverage_end

label variable crude              "Crude rate per 100,000; missing when suppressed"
label variable rateadj            "WHO age-standardised rate per 100,000; missing when suppressed"
label variable lb_gam             "Lower 95% confidence limit; missing when suppressed"
label variable ub_gam             "Upper 95% confidence limit; missing when suppressed"
label variable suppression_status "Disclosure-control status"
label data "BNR CVD Table 4: incidence rates, public-ready and unapproved"

save "`public_data'/`table4'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    foreach display_variable in display_crude display_adjusted display_lower display_upper {
        replace `display_variable' = "Suppressed" if suppression_status != "none"
    }
    export delimited using "`public_data'/`table4'.csv", replace
restore

preserve
    keep year event_group sex_group dco_group display_crude ///
         display_adjusted display_lower display_upper
    label variable year             "Year"
    label variable event_group      "Event"
    label variable sex_group        "Sex"
    label variable dco_group        "DCO definition"
    label variable display_crude    "Crude rate"
    label variable display_adjusted "Adjusted rate"
    label variable display_lower    "Lower 95% limit"
    label variable display_upper    "Upper 95% limit"
    tempfile present4
    save `present4', replace
restore


* =============================================================================
* I. TABLE 5 -- INCIDENCE RATE RATIOS
* =============================================================================
* The rate ratio and both confidence limits are hidden if either contributing
* comparison count is fewer than 6.

use "`step1_data'/`table5'.dta", clear
isid comparison_order

gen double review_value = rate_ratio
gen byte suppress_primary = inrange(comparison_count, 1, 5) | ///
    inrange(reference_count, 1, 5)
replace suppress_primary = 0 if missing(comparison_count) | missing(reference_count)
gen byte suppress_secondary = 0

gen str12 suppression_status = "none"
replace suppression_status = "primary" if suppress_primary == 1

gen str200 suppression_reason = ""
replace suppression_reason = "At least one comparison count is between 1 and 5." if suppression_status == "primary"

quietly count if suppression_status == "primary"
local t5_primary = r(N)
local t5_secondary = 0

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_05"
    gen str120 cell_key = comparison_label
    gen str50 measure = "incidence rate ratio"
    gen double unsuppressed_value = review_value
    gen double support_count = min(comparison_count, reference_count)
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work5
    save `work5', replace
restore

foreach ratio_variable in rate_ratio lower_95 upper_95 {
    replace `ratio_variable' = . if suppression_status != "none"
}

gen str12 display_ratio = cond(missing(rate_ratio), "—", trim(string(rate_ratio, "%9.2f")))
gen str12 display_lower = cond(missing(lower_95), "—", trim(string(lower_95, "%9.2f")))
gen str12 display_upper = cond(missing(upper_95), "—", trim(string(upper_95, "%9.2f")))

drop review_value suppress_primary suppress_secondary suppression_reason ///
     comparison_count reference_count support_count_min
order comparison_order comparison_type comparison_label period_start_year ///
      period_end_year rate_ratio lower_95 upper_95 display_ratio ///
      display_lower display_upper suppression_status coverage_end

label variable rate_ratio         "Incidence rate ratio; missing when suppressed"
label variable lower_95           "Lower 95% confidence limit; missing when suppressed"
label variable upper_95           "Upper 95% confidence limit; missing when suppressed"
label variable suppression_status "Disclosure-control status"
label data "BNR CVD Table 5: incidence rate ratios, public-ready and unapproved"

save "`public_data'/`table5'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    foreach display_variable in display_ratio display_lower display_upper {
        replace `display_variable' = "Suppressed" if suppression_status != "none"
    }
    export delimited using "`public_data'/`table5'.csv", replace
restore

preserve
    keep comparison_order comparison_label display_ratio display_lower display_upper
    sort comparison_order
    drop comparison_order
    label variable comparison_label "Comparison"
    label variable display_ratio    "IRR"
    label variable display_lower    "Lower 95% limit"
    label variable display_upper    "Upper 95% limit"
    tempfile present5
    save `present5', replace
restore


* =============================================================================
* J. TABLE 6 -- IN-HOSPITAL CASE FATALITY
* =============================================================================
* The published definition is confirmed in-hospital deaths among non-DCO
* hospital events. A percentage is hidden if either confirmed deaths or the
* complementary survivor count is fewer than 6.

use "`step1_data'/`table6'.dta", clear
isid period_number etype sex

gen double review_value = confirmed_cf_percent
gen double survivor_count = denominator_count - confirmed_deaths
gen byte suppress_primary = inrange(confirmed_deaths, 1, 5) | ///
    inrange(survivor_count, 1, 5)
replace suppress_primary = 0 if missing(confirmed_deaths) | missing(survivor_count)
gen byte suppress_secondary = 0

gen str12 suppression_status = "none"
replace suppression_status = "primary" if suppress_primary == 1

decode etype, gen(event_group)
decode sex,   gen(sex_group)

gen str200 suppression_reason = ""
replace suppression_reason = "Confirmed deaths or complementary survivors are between 1 and 5." if suppression_status == "primary"

quietly count if suppression_status == "primary"
local t6_primary = r(N)
local t6_secondary = 0

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_06"
    gen str120 cell_key = "period=" + string(period_start_year) + "-" + ///
        string(period_end_year) + "; event=" + event_group + "; sex=" + sex_group
    gen str50 measure = "confirmed case-fatality percentage"
    gen double unsuppressed_value = review_value
    gen double support_count = min(confirmed_deaths, survivor_count)
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work6
    save `work6', replace
restore

replace confirmed_cf_percent = . if suppression_status != "none"
gen str12 display_percent = cond(missing(confirmed_cf_percent), "—", ///
    trim(string(confirmed_cf_percent, "%9.1f")))

* Probable-death sensitivity fields and all supporting counts remain private.
drop review_value suppress_primary suppress_secondary suppression_reason ///
     denominator_count confirmed_deaths probable_deaths survivor_count ///
     confirmed_probable_cf_percent
order period_number period_start_year period_end_year etype event_group sex ///
      sex_group confirmed_cf_percent display_percent suppression_status coverage_end

label variable confirmed_cf_percent "Confirmed case-fatality percentage; missing when suppressed"
label variable display_percent      "Public display value"
label variable suppression_status   "Disclosure-control status"
label data "BNR CVD Table 6: confirmed case fatality, public-ready and unapproved"

save "`public_data'/`table6'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    replace display_percent = "Suppressed" if suppression_status != "none"
    export delimited using "`public_data'/`table6'.csv", replace
restore

preserve
    gen byte column = (etype - 1) * 2 + sex
    keep period_number period_start_year period_end_year column display_percent
    reshape wide display_percent, ///
        i(period_number period_start_year period_end_year) j(column)
    rename display_percent1 stroke_female
    rename display_percent2 stroke_male
    rename display_percent3 ami_female
    rename display_percent4 ami_male
    gen str12 period_display = string(period_start_year) + "-" + string(period_end_year)
    order period_number period_display stroke_female stroke_male ami_female ami_male
    sort period_number
    drop period_start_year period_end_year period_number
    label variable period_display "Period"
    label variable stroke_female  "Stroke: female (%)"
    label variable stroke_male    "Stroke: male (%)"
    label variable ami_female     "AMI: female (%)"
    label variable ami_male       "AMI: male (%)"
    tempfile present6
    save `present6', replace
restore


* =============================================================================
* K. TABLE 7 -- IN-HOSPITAL LENGTH OF STAY
* =============================================================================
* The median and both quartiles are hidden together when fewer than 6 eligible
* hospital stays contribute to the row.

use "`step1_data'/`table7'.dta", clear
isid year etype sex

gen double review_value = median_days
gen byte suppress_primary = inrange(support_count, 1, 5)
gen byte suppress_secondary = 0

gen str12 suppression_status = "none"
replace suppression_status = "primary" if suppress_primary == 1

decode etype, gen(event_group)
decode sex,   gen(sex_group)

gen str200 suppression_reason = ""
replace suppression_reason = "Between 1 and 5 eligible stays contribute to the summary." if suppression_status == "primary"

quietly count if suppression_status == "primary"
local t7_primary = r(N)
local t7_secondary = 0

preserve
    keep if suppression_status != "none"
    gen str10 table_id = "table_07"
    gen str120 cell_key = "year=" + string(year) + "; event=" + event_group + "; sex=" + sex_group
    gen str50 measure = "median and quartiles"
    gen double unsuppressed_value = review_value
    gen double review_support_count = support_count
    drop support_count
    rename review_support_count support_count
    keep table_id cell_key measure unsuppressed_value support_count ///
         suppression_status suppression_reason
    tempfile work7
    save `work7', replace
restore

foreach stay_variable in median_days lower_quartile_days upper_quartile_days {
    replace `stay_variable' = . if suppression_status != "none"
}

gen str12 display_median = cond(missing(median_days), "—", trim(string(median_days, "%9.1f")))
gen str12 display_lower  = cond(missing(lower_quartile_days), "—", trim(string(lower_quartile_days, "%9.1f")))
gen str12 display_upper  = cond(missing(upper_quartile_days), "—", trim(string(upper_quartile_days, "%9.1f")))

drop review_value suppress_primary suppress_secondary suppression_reason support_count
order year etype event_group sex sex_group median_days lower_quartile_days ///
      upper_quartile_days display_median display_lower display_upper ///
      suppression_status period_status coverage_end

label variable median_days          "Median stay in days; missing when suppressed"
label variable lower_quartile_days  "Lower quartile in days; missing when suppressed"
label variable upper_quartile_days  "Upper quartile in days; missing when suppressed"
label variable suppression_status   "Disclosure-control status"
label data "BNR CVD Table 7: length of stay, public-ready and unapproved"

save "`public_data'/`table7'.dta", replace
preserve
    * ASCII-safe wording prevents Excel misreading the UTF-8 em dash in CSV.
    foreach display_variable in display_median display_lower display_upper {
        replace `display_variable' = "Suppressed" if suppression_status != "none"
    }
    export delimited using "`public_data'/`table7'.csv", replace
restore

preserve
    gen str20 year_display = string(year)
    replace year_display = string(year) + " (YTD)" if period_status == "year_to_date"
    keep year year_display event_group sex_group display_median display_lower display_upper
    sort year event_group sex_group
    label variable year_display   "Year"
    label variable event_group    "Event"
    label variable sex_group      "Sex"
    label variable display_median "Median days"
    label variable display_lower  "Lower quartile"
    label variable display_upper  "Upper quartile"
    tempfile present7
    save `present7', replace
restore
* =============================================================================
* L. COMBINE THE PRIVATE SUPPRESSION WORKLIST
* =============================================================================

use `work1', clear
append using `work2' `work3' `work4' `work5' `work6' `work7'
sort table_id suppression_status cell_key
gen long review_item = _n
order review_item table_id cell_key measure unsuppressed_value support_count ///
      suppression_status suppression_reason

label variable review_item          "Review item"
label variable table_id             "Table"
label variable cell_key             "Cell or row"
label variable measure              "Suppressed measure"
label variable unsuppressed_value   "Exact value for private review"
label variable support_count        "Relevant supporting count"
label variable suppression_status   "Primary or complementary suppression"
label variable suppression_reason   "Reason"

quietly count
local review_items = r(N)
quietly count if suppression_status == "primary"
local total_primary = r(N)
quietly count if suppression_status == "secondary"
local total_secondary = r(N)

tempfile combined_worklist
save `combined_worklist', replace

if `review_items' > 0 {
    export delimited using "`worklist_csv'", replace
}
else {
    * Keep the CSV structurally valid without inventing a review item.
    file open empty_worklist using "`worklist_csv'", write replace text
    file write empty_worklist "review_item,table_id,cell_key,measure,unsuppressed_value,support_count,suppression_status,suppression_reason" _n
    file close empty_worklist
}


* =============================================================================
* M. CREATE THE PRIVATE SUPPRESSION REVIEW WORKBOOK
* =============================================================================
* This workbook is private. It contains exact values and supporting counts.
* It must never be placed in public_ready, outputs/public, or the website.

clear
set obs 7
gen str10 table_id = ""
gen str55 table_title = ""
gen long primary_suppressions = .
gen long secondary_suppressions = .
gen long total_review_items = .

replace table_id = "table_01" in 1
replace table_title = "Annual event counts" in 1
replace primary_suppressions = `t1_primary' in 1
replace secondary_suppressions = `t1_secondary' in 1

replace table_id = "table_02" in 2
replace table_title = "Monthly event counts" in 2
replace primary_suppressions = `t2_primary' in 2
replace secondary_suppressions = `t2_secondary' in 2

replace table_id = "table_03" in 3
replace table_title = "Broad age-group percentages" in 3
replace primary_suppressions = `t3_primary' in 3
replace secondary_suppressions = `t3_secondary' in 3

replace table_id = "table_04" in 4
replace table_title = "Annual incidence rates" in 4
replace primary_suppressions = `t4_primary' in 4
replace secondary_suppressions = `t4_secondary' in 4

replace table_id = "table_05" in 5
replace table_title = "Incidence rate ratios" in 5
replace primary_suppressions = `t5_primary' in 5
replace secondary_suppressions = `t5_secondary' in 5

replace table_id = "table_06" in 6
replace table_title = "Confirmed in-hospital case fatality" in 6
replace primary_suppressions = `t6_primary' in 6
replace secondary_suppressions = `t6_secondary' in 6

replace table_id = "table_07" in 7
replace table_title = "In-hospital length of stay" in 7
replace primary_suppressions = `t7_primary' in 7
replace secondary_suppressions = `t7_secondary' in 7

replace total_review_items = primary_suppressions + secondary_suppressions
label variable table_id                "Table"
label variable table_title             "Title"
label variable primary_suppressions    "Primary"
label variable secondary_suppressions  "Complementary"
label variable total_review_items      "Total review items"

export excel using "`review_xlsx'", replace sheet("Summary") firstrow(varlabels)

use `combined_worklist', clear
if `review_items' == 0 {
    set obs 1
    replace table_id = "none" in 1
    replace cell_key = "No suppressed or otherwise flagged cells." in 1
    replace measure = "not applicable" in 1
    replace suppression_status = "none" in 1
    replace suppression_reason = "No worklist items were generated for this release." in 1
}
export excel using "`review_xlsx'", sheet("Worklist", replace) firstrow(varlabels)

use `combined_disclosure_audit', clear
label variable check_type                "Check type"
label variable cell_key                  "Published additive relationship"
label variable terms_in_equation         "Terms"
label variable suppressed_terms          "Hidden terms"
label variable exact_reconstruction_risk "Exactly one hidden term"
label variable check_status              "Status"
export excel using "`review_xlsx'", sheet("Cross-table checks", replace) firstrow(varlabels)

clear
set obs 7
gen str10 table_id = ""
gen str220 disclosure_rule = ""
replace table_id = "table_01" in 1
replace disclosure_rule = "Jointly protect annual sex-by-disease cells and margins; retain disease totals where possible; audit against monthly counts." in 1
replace table_id = "table_02" in 2
replace disclosure_rule = "Protect monthly component totals and add a second hidden term where an annual total could reveal one protected month." in 2
replace table_id = "table_03" in 3
replace disclosure_rule = "If either age-group numerator is 1 to 5, suppress both complementary percentages." in 3
replace table_id = "table_04" in 4
replace disclosure_rule = "Suppress a rate row supported by 1 to 5 events; protect small DCO increments and affected both-sex totals." in 4
replace table_id = "table_05" in 5
replace disclosure_rule = "Suppress the ratio and confidence limits when either comparison count is 1 to 5." in 5
replace table_id = "table_06" in 6
replace disclosure_rule = "Suppress case fatality when confirmed deaths or complementary survivors are 1 to 5." in 6
replace table_id = "table_07" in 7
replace disclosure_rule = "Suppress median and quartiles together when 1 to 5 eligible stays contribute." in 7
label variable table_id        "Table"
label variable disclosure_rule "Disclosure-control rule"
export excel using "`review_xlsx'", sheet("Disclosure rules", replace) firstrow(varlabels)

clear
set obs 8
gen str28 field = ""
gen str180 meaning = ""
replace field = "review_item" in 1
replace meaning = "Sequential private review number." in 1
replace field = "table_id" in 2
replace meaning = "Public table containing the affected cell or row." in 2
replace field = "cell_key" in 3
replace meaning = "Plain-language dimensions identifying the affected cell or row." in 3
replace field = "measure" in 4
replace meaning = "Count, percentage, rate, ratio, or summary hidden from public output." in 4
replace field = "unsuppressed_value" in 5
replace meaning = "Exact private value before disclosure control; never public." in 5
replace field = "support_count" in 6
replace meaning = "Relevant count used to make or explain the suppression decision." in 6
replace field = "suppression_status" in 7
replace meaning = "Primary means below threshold; secondary means hidden to prevent recovery." in 7
replace field = "suppression_reason" in 8
replace meaning = "Readable explanation of the rule applied." in 8
label variable field   "Field"
label variable meaning "Meaning"
export excel using "`review_xlsx'", sheet("Data dictionary", replace) firstrow(varlabels)

* Apply deliberately light, durable formatting. Detailed visual design is not
* allowed to obscure the review information.
putexcel set "`review_xlsx'", sheet("Summary") modify
putexcel A1:E1, bold hcenter border(bottom) overwritefmt
putexcel set "`review_xlsx'", sheet("Worklist") modify
putexcel A1:H1, bold hcenter border(bottom) overwritefmt
putexcel set "`review_xlsx'", sheet("Cross-table checks") modify
putexcel A1:F1, bold hcenter border(bottom) overwritefmt
putexcel set "`review_xlsx'", sheet("Disclosure rules") modify
putexcel A1:B1, bold hcenter border(bottom) overwritefmt
putexcel set "`review_xlsx'", sheet("Data dictionary") modify
putexcel A1:B1, bold hcenter border(bottom) overwritefmt


* =============================================================================
* N. WRITE THE PRIVATE SUPPRESSION SUMMARY
* =============================================================================

file open summary using "`review_dir'/suppression_summary.txt", write replace text
file write summary "BNR CVD TABLES: STEP 2A SUPPRESSION SUMMARY" _n
file write summary "Package: `package_id'" _n
file write summary "Coverage through: `coverage'" _n
file write summary "Primary frequency rule: 1 to 5" _n
file write summary "" _n
file write summary "Table 1: primary `t1_primary'; complementary `t1_secondary'" _n
file write summary "Table 2: primary `t2_primary'; complementary `t2_secondary'" _n
file write summary "Table 3: primary `t3_primary'; complementary `t3_secondary'" _n
file write summary "Table 4: primary `t4_primary'; complementary `t4_secondary'" _n
file write summary "Table 5: primary `t5_primary'; complementary `t5_secondary'" _n
file write summary "Table 6: primary `t6_primary'; complementary `t6_secondary'" _n
file write summary "Table 7: primary `t7_primary'; complementary `t7_secondary'" _n
file write summary "" _n
file write summary "Total primary suppressions: `total_primary'" _n
file write summary "Total complementary suppressions: `total_secondary'" _n
file write summary "Total review items: `review_items'" _n
file write summary "Additive disclosure checks: `cross_table_checks'" _n
file write summary "Exact reconstruction failures: `cross_table_failures'" _n
file write summary "" _n
file write summary "Review suppression_review.xlsx and every public_ready product." _n
file write summary "No approval or publication has been performed." _n
file close summary


* =============================================================================
* O. CREATE THE EXACT PUBLIC DOWNLOAD WORKBOOK
* =============================================================================
* Every displayed value comes from the suppressed public-safe datasets above.
* Exact private supporting counts are not present in this workbook.

putexcel set "`download_xlsx'", replace sheet("Read me")
putexcel A1 = "BNR cardiovascular disease annual tabulations", bold
putexcel A3 = "Package" B3 = "`package_id'"
putexcel A4 = "Coverage through" B4 = "`coverage'"
putexcel A6 = "Disclosure control"
putexcel B6 = "Cells supported by 1 to 5 observations are suppressed. True zeroes are not automatically suppressed. Complementary suppression is applied where required."
putexcel A7 = "Suppression symbol" B7 = "—"
putexcel A9 = "Status" B9 = "PUBLIC-READY FOR REVIEW — NOT YET APPROVED"
putexcel A11 = "Year-to-date"
putexcel B11 = "The current year is explicitly labelled YTD. Incidence and case-fatality use completed periods only."

use `present1', clear
export excel using "`download_xlsx'", sheet("Table 1", replace) firstrow(varlabels)

use `present2', clear
export excel using "`download_xlsx'", sheet("Table 2", replace) firstrow(varlabels)

use `present3', clear
export excel using "`download_xlsx'", sheet("Table 3", replace) firstrow(varlabels)

use `present4', clear
export excel using "`download_xlsx'", sheet("Table 4", replace) firstrow(varlabels)

use `present5', clear
export excel using "`download_xlsx'", sheet("Table 5", replace) firstrow(varlabels)

use `present6', clear
export excel using "`download_xlsx'", sheet("Table 6", replace) firstrow(varlabels)

use `present7', clear
export excel using "`download_xlsx'", sheet("Table 7", replace) firstrow(varlabels)

putexcel set "`download_xlsx'", sheet("Table 1") modify
putexcel A1:J1, bold hcenter border(bottom) overwritefmt
putexcel set "`download_xlsx'", sheet("Table 2") modify
putexcel A1:F1, bold hcenter border(bottom) overwritefmt
putexcel set "`download_xlsx'", sheet("Table 3") modify
putexcel A1:F1, bold hcenter border(bottom) overwritefmt
putexcel set "`download_xlsx'", sheet("Table 4") modify
putexcel A1:H1, bold hcenter border(bottom) overwritefmt
putexcel set "`download_xlsx'", sheet("Table 5") modify
putexcel A1:D1, bold hcenter border(bottom) overwritefmt
putexcel set "`download_xlsx'", sheet("Table 6") modify
putexcel A1:E1, bold hcenter border(bottom) overwritefmt
putexcel set "`download_xlsx'", sheet("Table 7") modify
putexcel A1:G1, bold hcenter border(bottom) overwritefmt


* =============================================================================
* P. GENERATE THE EXACT QUARTO MARKDOWN FRAGMENTS
* =============================================================================
* The tabbed fragments contain their complete panel-tabset structure. The main
* QMD therefore includes one stable file per table and does not need annual
* hand editing when a new year appears.

* -----------------------------------------------------------------------------
* Table 1 Markdown
* -----------------------------------------------------------------------------
use `present1', clear
file open md1 using "`public_tables'/table_cvd_annual_01_event_counts.md", write replace text
file write md1 "| Year | Stroke: female | Stroke: male | Stroke: total | AMI: female | AMI: male | AMI: total | All CVD: female | All CVD: male | All CVD: total |" _n
file write md1 "|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|" _n
forvalues row = 1/`=_N' {
    local a = year_display[`row']
    local b = stroke_female[`row']
    local c = stroke_male[`row']
    local d = stroke_total[`row']
    local e = ami_female[`row']
    local f = ami_male[`row']
    local g = ami_total[`row']
    local h = cvd_female[`row']
    local i = cvd_male[`row']
    local j = cvd_total[`row']
    file write md1 "| `a' | `b' | `c' | `d' | `e' | `f' | `g' | `h' | `i' | `j' |" _n
}
file write md1 _n "_YTD = year to date. — = suppressed because a contributing frequency is 1 to 5 or complementary protection is required._" _n
file close md1

* -----------------------------------------------------------------------------
* Table 2 Markdown: one automatically generated year tab
* -----------------------------------------------------------------------------
use `present2', clear
gen long markdown_row = _n
file open md2 using "`public_tables'/table_cvd_annual_02_monthly_counts_tabs.md", write replace text
file write md2 "::: {.panel-tabset .bnr-year-tabs}" _n _n
forvalues yr = `release_year'(-1)2010 {
    local year_heading "`yr'"
    if `yr' == `release_year' & `release_month' < 12 {
        local year_heading "`yr' (YTD through month `release_month')"
    }
    file write md2 "### `year_heading'" _n _n
    file write md2 "| Month | Stroke | AMI | All CVD |" _n
    file write md2 "|:--|--:|--:|--:|" _n
    forvalues mo = 1/12 {
        quietly count if year == `yr' & month == `mo'
        if r(N) == 1 {
            quietly summarize markdown_row if year == `yr' & month == `mo', meanonly
            local row = r(min)
            local a = month_name[`row']
            local b = stroke[`row']
            local c = ami[`row']
            local d = all_cvd[`row']
            file write md2 "| `a' | `b' | `c' | `d' |" _n
        }
    }
    file write md2 _n "_— = suppressed. Future months in the current year are shown as Not available._" _n _n
}
file write md2 ":::" _n
file close md2

* -----------------------------------------------------------------------------
* Table 3 Markdown
* -----------------------------------------------------------------------------
use `present3', clear
file open md3 using "`public_tables'/table_cvd_annual_03_age70_percent.md", write replace text
file write md3 "| Period | Event | Sex | Under 70 (%) | 70 and over (%) |" _n
file write md3 "|:--|:--|:--|--:|--:|" _n
forvalues row = 1/`=_N' {
    local a = period_display[`row']
    local b = event_group[`row']
    local c = sex_group[`row']
    local d = under_70[`row']
    local e = age_70_plus[`row']
    file write md3 "| `a' | `b' | `c' | `d' | `e' |" _n
}
file write md3 _n "_Percentages use events with known age group. Both complementary percentages are hidden when either age-group count is 1 to 5._" _n
file close md3

* -----------------------------------------------------------------------------
* Table 4 Markdown: one automatically generated completed-year tab
* -----------------------------------------------------------------------------
use `present4', clear
local last_incidence_year = `release_year' - 1
file open md4 using "`public_tables'/table_cvd_annual_04_incidence_rates_tabs.md", write replace text
file write md4 "::: {.panel-tabset .bnr-year-tabs}" _n _n
forvalues yr = `last_incidence_year'(-1)2010 {
    file write md4 "### `yr'" _n _n
    file write md4 "| Event | Sex | DCO definition | Crude rate | Adjusted rate | Lower 95% limit | Upper 95% limit |" _n
    file write md4 "|:--|:--|:--|--:|--:|--:|--:|" _n
    forvalues row = 1/`=_N' {
        if year[`row'] == `yr' {
            local a = event_group[`row']
            local b = sex_group[`row']
            local c = dco_group[`row']
            local d = display_crude[`row']
            local e = display_adjusted[`row']
            local f = display_lower[`row']
            local g = display_upper[`row']
            file write md4 "| `a' | `b' | `c' | `d' | `e' | `f' | `g' |" _n
        }
    }
    file write md4 _n "_Rates are per 100,000. Adjusted rates use the WHO standard population. — = suppressed._" _n _n
}
file write md4 ":::" _n
file close md4

* -----------------------------------------------------------------------------
* Table 5 Markdown
* -----------------------------------------------------------------------------
use `present5', clear
file open md5 using "`public_tables'/table_cvd_annual_05_incidence_rate_ratios.md", write replace text
file write md5 "| Comparison | IRR | Lower 95% limit | Upper 95% limit |" _n
file write md5 "|:--|--:|--:|--:|" _n
forvalues row = 1/`=_N' {
    local a = comparison_label[`row']
    local b = display_ratio[`row']
    local c = display_lower[`row']
    local d = display_upper[`row']
    file write md5 "| `a' | `b' | `c' | `d' |" _n
}
file write md5 _n "_IRR = incidence rate ratio. Two-year periods are compared with 2010-2011. — = suppressed._" _n
file close md5

* -----------------------------------------------------------------------------
* Table 6 Markdown
* -----------------------------------------------------------------------------
use `present6', clear
file open md6 using "`public_tables'/table_cvd_annual_06_case_fatality.md", write replace text
file write md6 "| Period | Stroke: female (%) | Stroke: male (%) | AMI: female (%) | AMI: male (%) |" _n
file write md6 "|:--|--:|--:|--:|--:|" _n
forvalues row = 1/`=_N' {
    local a = period_display[`row']
    local b = stroke_female[`row']
    local c = stroke_male[`row']
    local d = ami_female[`row']
    local e = ami_male[`row']
    file write md6 "| `a' | `b' | `c' | `d' | `e' |" _n
}
file write md6 _n "_Confirmed in-hospital deaths among non-DCO hospital events. — = suppressed._" _n
file close md6

* -----------------------------------------------------------------------------
* Table 7 Markdown: one automatically generated year tab
* -----------------------------------------------------------------------------
use `present7', clear
file open md7 using "`public_tables'/table_cvd_annual_07_length_of_stay_tabs.md", write replace text
file write md7 "::: {.panel-tabset .bnr-year-tabs}" _n _n
forvalues yr = `release_year'(-1)2010 {
    local year_heading "`yr'"
    if `yr' == `release_year' & `release_month' < 12 {
        local year_heading "`yr' (YTD through month `release_month')"
    }
    file write md7 "### `year_heading'" _n _n
    file write md7 "| Event | Sex | Median days | Lower quartile | Upper quartile |" _n
    file write md7 "|:--|:--|--:|--:|--:|" _n
    forvalues row = 1/`=_N' {
        if year[`row'] == `yr' {
            local a = event_group[`row']
            local b = sex_group[`row']
            local c = display_median[`row']
            local d = display_lower[`row']
            local e = display_upper[`row']
            file write md7 "| `a' | `b' | `c' | `d' | `e' |" _n
        }
    }
    file write md7 _n "_— = suppressed because 1 to 5 eligible stays contribute._" _n _n
}
file write md7 ":::" _n
file close md7


* =============================================================================
* Q. WRITE PUBLIC-READY METADATA AND PROPOSED MANIFEST
* =============================================================================

file open meta using "`public_metadata'/package.yml", write replace text
file write meta "package_id: `package_id'" _n
file write meta "product_type: cvd_annual_tabulations" _n
file write meta "status: public_ready_unapproved" _n
file write meta "coverage_end: `coverage'" _n
file write meta "disclosure_threshold: 6" _n
file write meta "primary_frequency_range: 1-5" _n
file write meta "suppression_symbol: '—'" _n
file write meta "workbook: workbook/workbook_cvd_annual_tabulations.xlsx" _n
file write meta "approval_required: true" _n
file write meta "publication_performed: false" _n
file close meta

file open disclosure using "`public_metadata'/disclosure_control.yml", write replace text
file write disclosure "policy: BNR small-number disclosure control" _n
file write disclosure "primary_rule: suppress values supported by 1 to 5 observations" _n
file write disclosure "complementary_suppression: true" _n
file write disclosure "cross_table_check: passed" _n
file write disclosure "cross_table_equations_checked: `cross_table_checks'" _n
file write disclosure "exact_reconstruction_failures: `cross_table_failures'" _n
file write disclosure "suppression_symbol: '—'" _n
file write disclosure "private_review_items: `review_items'" _n
file write disclosure "primary_suppressions: `total_primary'" _n
file write disclosure "complementary_suppressions: `total_secondary'" _n
file write disclosure "supporting_counts_removed_from_public_files: true" _n
file write disclosure "status: requires_human_review" _n
file close disclosure

file open catalogue using "`public_metadata'/table_catalogue.csv", write replace text
file write catalogue "table_id,title,dataset,markdown" _n
file write catalogue "table_01,Annual event counts,datasets/`table1'.csv,tables/table_cvd_annual_01_event_counts.md" _n
file write catalogue "table_02,Monthly event counts,datasets/`table2'.csv,tables/table_cvd_annual_02_monthly_counts_tabs.md" _n
file write catalogue "table_03,Broad age-group percentages,datasets/`table3'.csv,tables/table_cvd_annual_03_age70_percent.md" _n
file write catalogue "table_04,Annual incidence rates,datasets/`table4'.csv,tables/table_cvd_annual_04_incidence_rates_tabs.md" _n
file write catalogue "table_05,Incidence rate ratios,datasets/`table5'.csv,tables/table_cvd_annual_05_incidence_rate_ratios.md" _n
file write catalogue "table_06,Confirmed in-hospital case fatality,datasets/`table6'.csv,tables/table_cvd_annual_06_case_fatality.md" _n
file write catalogue "table_07,In-hospital length of stay,datasets/`table7'.csv,tables/table_cvd_annual_07_length_of_stay_tabs.md" _n
file close catalogue

file open manifest using "`public_ready'/public_manifest.csv", write replace text
file write manifest "relative_path,product_role,required" _n
foreach table_name in table1 table2 table3 table4 table5 table6 table7 {
    file write manifest "datasets/``table_name''.dta,public_dataset,1" _n
    file write manifest "datasets/``table_name''.csv,public_dataset,1" _n
}
file write manifest "workbook/workbook_cvd_annual_tabulations.xlsx,download_workbook,1" _n
file write manifest "tables/table_cvd_annual_01_event_counts.md,website_table,1" _n
file write manifest "tables/table_cvd_annual_02_monthly_counts_tabs.md,website_table,1" _n
file write manifest "tables/table_cvd_annual_03_age70_percent.md,website_table,1" _n
file write manifest "tables/table_cvd_annual_04_incidence_rates_tabs.md,website_table,1" _n
file write manifest "tables/table_cvd_annual_05_incidence_rate_ratios.md,website_table,1" _n
file write manifest "tables/table_cvd_annual_06_case_fatality.md,website_table,1" _n
file write manifest "tables/table_cvd_annual_07_length_of_stay_tabs.md,website_table,1" _n
file write manifest "metadata/package.yml,package_metadata,1" _n
file write manifest "metadata/disclosure_control.yml,package_metadata,1" _n
file write manifest "metadata/table_catalogue.csv,package_metadata,1" _n
file write manifest "readme.txt,package_readme,1" _n
file close manifest

file open readme using "`public_ready'/readme.txt", write replace text
file write readme "BNR CVD ANNUAL TABULATIONS: PUBLIC-READY REVIEW PACKAGE" _n
file write readme "Package: `package_id'" _n
file write readme "Coverage through: `coverage'" _n
file write readme "" _n
file write readme "This folder contains the exact suppressed products proposed for release." _n
file write readme "It is still inside private staging and is NOT approved or public." _n
file write readme "" _n
file write readme "Review the workbook, Markdown, datasets, metadata, and private" _n
file write readme "suppression workbook. Do not edit generated products manually." _n
file write readme "After satisfactory review, use Table Step 2B to record approval." _n
file close readme


* =============================================================================
* R. FINAL OUTPUT CONTRACT CHECKS
* =============================================================================

foreach table_name in table1 table2 table3 table4 table5 table6 table7 {
    foreach extension in dta csv {
        capture confirm file "`public_data'/``table_name''.`extension'"
        if _rc {
            display as error "Table Step 2A stopped: expected public-ready dataset is missing."
            display as result "`public_data'/``table_name''.`extension'"
            exit 601
        }
    }
}

foreach required_output in ///
    "`download_xlsx'" ///
    "`review_xlsx'" ///
    "`worklist_csv'" ///
    "`cross_table_csv'" ///
    "`review_dir'/suppression_summary.txt" ///
    "`public_ready'/public_manifest.csv" ///
    "`public_metadata'/package.yml" ///
    "`public_metadata'/disclosure_control.yml" ///
    "`public_metadata'/table_catalogue.csv" ///
    "`public_ready'/readme.txt" {
    capture confirm file "`required_output'"
    if _rc {
        display as error "Table Step 2A stopped: an expected output is missing."
        display as result "`required_output'"
        exit 601
    }
}

foreach markdown_file in ///
    table_cvd_annual_01_event_counts.md ///
    table_cvd_annual_02_monthly_counts_tabs.md ///
    table_cvd_annual_03_age70_percent.md ///
    table_cvd_annual_04_incidence_rates_tabs.md ///
    table_cvd_annual_05_incidence_rate_ratios.md ///
    table_cvd_annual_06_case_fatality.md ///
    table_cvd_annual_07_length_of_stay_tabs.md {
    capture confirm file "`public_tables'/`markdown_file'"
    if _rc {
        display as error "Table Step 2A stopped: an expected Markdown fragment is missing."
        display as result "`public_tables'/`markdown_file'"
        exit 601
    }
}


* =============================================================================
* S. OPERATIONAL RUN SUMMARY
* =============================================================================

qui {
    noi display as text _n "============================================================"
    noi display as text    "TABLE STEP 2A: OPERATIONAL RUN SUMMARY"
    noi display as text    "============================================================"
    noi display as result  "Status:           COMPLETED - PUBLIC-READY, UNAPPROVED"
    noi display as result  "Package:          `package_id'"
    noi display as result  "Coverage through: `coverage'"
    noi display as result  "Primary flags:    `total_primary'"
    noi display as result  "Secondary flags:  `total_secondary'"
    noi display as result  "Disclosure checks: `cross_table_checks' passed"
    noi display as result  "Review items:     `review_items'"
    noi display as result  "Review workbook:  `review_xlsx'"
    noi display as result  "Public workbook:  `download_xlsx'"
    noi display as result  "Public-ready:     `public_ready'"
    noi display as text    "Approval:         NOT PERFORMED"
    noi display as text    "Publication:      NOT PERFORMED"
    noi display as text    "Next: inspect every review and public-ready product, then run Step 2B."
    noi display as text    "============================================================"
}

log close

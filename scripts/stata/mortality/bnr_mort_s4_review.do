/*
===============================================================================
DO-FILE:     bnr_mort_s4_review.do
VERSION:     Pass 4 monthly-public-scope and fixed-reference candidate
              (21 August 2026)
 PROJECT:     BNR Refit Phase 2
 PURPOSE:     Step 4: validate a Step 3 mortality burden package, apply the
              approved disclosure-control decisions to a review candidate,
              and prepare concise private materials for human review.

 ROUTINE USE:
   do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 7
   do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 7 replace

 WORKFLOW BOUNDARY:
   Step 4 reads the private Step 3 staging package and writes a suppressed
   review candidate and review materials inside that same private package.
   It does not approve, create public_ready, promote, publish, copy files to
   the website, or calculate mortality rates.
===============================================================================
*/

version 19
clear all
set more off

capture program drop _bnr_mort_s4_fail
program define _bnr_mort_s4_fail
    version 19
    args return_code release_id private_log reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "MORTALITY STEP 4: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error "  Selected release:       `release_id'"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `private_log'"'
    noisily display as text  "  Action required:        Correct the issue and rerun Step 4."
    noisily display as text  "  Publication boundary:   No approval or public output was created."
    noisily display as error "============================================================================="
    capture log close mort_s4
    exit `return_code'
end

* ==============================================================================
* 1. ANALYST INPUTS -- EDITED BY THE DIALOG OR COMMAND LINE
* ==============================================================================
args release_year release_month replace_word

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Enter the Step 3 release year and month. Example: 2026 7"
    exit 198
}

capture confirm integer number `release_year'
if _rc | real("`release_year'") < 2000 | real("`release_year'") > 2100 {
    display as error "Release year must be a four-digit year from 2000 to 2100."
    exit 198
}

capture confirm integer number `release_month'
if _rc | !inrange(real("`release_month'"), 1, 12) {
    display as error "Release month must be an integer from 1 to 12."
    exit 198
}

local replace_existing = 0
if "`replace_word'" != "" {
    if lower("`replace_word'") != "replace" {
        display as error "The only optional third word is replace."
        exit 198
    }
    local replace_existing = 1
}

local release_year_4 = string(real("`release_year'"), "%04.0f")
local release_month_2 = string(real("`release_month'"), "%02.0f")
local release_id "mort_`release_year_4'_`release_month_2'"
local package_id "mort_burden_`release_id'"

* ==============================================================================
* 2. STANDARD PATHS AND FILE MAP -- DO NOT EDIT
* ==============================================================================
if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do."
        exit `config_rc'
    }
}

foreach path_name in BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" {
        display as error "Required path is not configured: `path_name'"
        exit 198
    }
}

local package_dir "$BNR_STAGING/mortality/burden/`release_id'"
local datasets_dir "`package_dir'/datasets"
local metadata_dir "`package_dir'/metadata"
local review_dir "`package_dir'/review"

* Step 3 inputs.
local release_dta "`datasets_dir'/mort_burden_metrics_`release_id'.dta"
local release_csv "`datasets_dir'/mort_burden_metrics_`release_id'.csv"
local current_dta "`datasets_dir'/mort_burden_metrics_current.dta"
local current_csv "`datasets_dir'/mort_burden_metrics_current.csv"
local package_metadata "`metadata_dir'/mort_burden_package.yml"
local step3_qa "`review_dir'/mort_burden_qa_`release_id'.csv"
local suppression_csv "`review_dir'/mort_burden_suppression_review_`release_id'.csv"
local suppression_xlsx "`review_dir'/mort_burden_suppression_review_`release_id'.xlsx"
local package_readme "`package_dir'/readme.txt"

* Step 4 private review outputs.
local review_candidate "`review_dir'/mort_s4_candidate.dta"
local review_workbook "`review_dir'/mort_s4_review_`release_id'.xlsx"
local review_qa_csv "`review_dir'/mort_s4_review_qa_`release_id'.csv"
local review_basis_csv "`review_dir'/mort_s4_review_basis_`release_id'.csv"
local reference_dta "`review_dir'/mort_s4_monthly_reference_2015_2019.dta"
local reference_csv "`review_dir'/mort_s4_monthly_reference_2015_2019.csv"
local reference_yml "`review_dir'/mort_s4_monthly_reference_2015_2019.yml"
local private_log "$BNR_PRIVATE_LOGS/bnr_mort_s4_review_`release_id'.log"

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close mort_s4
log using `"`private_log'"', text replace name(mort_s4)

* Routine commands are quiet. The short start block, failure block and final
* operational summary remain visible to mixed-experience operators.
quietly {

noisily display as text "BNR MORTALITY STEP 4: REVIEW RELEASE"
noisily display as result "  Script version:       Pass 4 monthly-public-scope and fixed-reference candidate"
noisily display as result "  Selected release:     `release_id'"
noisily display as result "  Step 3 package:       `package_dir'"
noisily display as result "  Replace authorised:   " cond(`replace_existing', "yes", "no")

* ==============================================================================
* 3. CONFIRM THE COMPLETE STEP 3 PACKAGE -- DO NOT EDIT
* ==============================================================================
* Each expected file is named explicitly so a missing component produces a
* clear, actionable error rather than a later generic import failure.
foreach required_file in ///
        `"`release_dta'"' ///
        `"`release_csv'"' ///
        `"`current_dta'"' ///
        `"`current_csv'"' ///
        `"`package_metadata'"' ///
        `"`step3_qa'"' ///
        `"`suppression_csv'"' ///
        `"`suppression_xlsx'"' ///
        `"`package_readme'"' {
    capture confirm file `"`required_file'"'
    if _rc {
        _bnr_mort_s4_fail 601 "`release_id'" `"`private_log'"' ///
            `"Required Step 3 package file not found: `required_file'"'
    }
}

* Step 4 normally refuses to overwrite a completed or partial earlier review.
* The analyst must use the explicit word replace for a deliberate rerun.
foreach output_file in ///
        `"`review_candidate'"' ///
        `"`review_workbook'"' ///
        `"`review_qa_csv'"' ///
        `"`review_basis_csv'"' ///
        `"`reference_dta'"' ///
        `"`reference_csv'"' ///
        `"`reference_yml'"' {
    capture confirm file `"`output_file'"'
    if !_rc & !`replace_existing' {
        _bnr_mort_s4_fail 602 "`release_id'" `"`private_log'"' ///
            `"Step 4 review output already exists: `output_file'. Rerun with replace only after review."'
    }
}

* The release-stamped and current files must be exact private copies within the
* selected Step 3 package. This prevents a stale current pointer being reviewed.
quietly checksum `"`release_dta'"'
local release_dta_size = r(filelen)
local release_dta_checksum = r(checksum)
quietly checksum `"`current_dta'"'
local current_dta_size = r(filelen)
local current_dta_checksum = r(checksum)

if `release_dta_size' != `current_dta_size' | ///
        `release_dta_checksum' != `current_dta_checksum' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The release-stamped and current DTA files are not identical."
}

quietly checksum `"`release_csv'"'
local release_csv_size = r(filelen)
local release_csv_checksum = r(checksum)
quietly checksum `"`current_csv'"'
local current_csv_size = r(filelen)
local current_csv_checksum = r(checksum)

if `release_csv_size' != `current_csv_size' | ///
        `release_csv_checksum' != `current_csv_checksum' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The release-stamped and current CSV files are not identical."
}

* ==============================================================================
* 4. REVALIDATE THE STEP 3 METRIC DATASET -- DO NOT EDIT
* ==============================================================================
use `"`release_dta'"', clear

local required_variables metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex age_group case_definition ///
    source_status statistic value unit numerator denominator comparison_n ///
    status_flag sdc_policy primary_suppression_threshold ///
    primary_suppression related_primary_cells ///
    related_suppression_review suppression_review suppression_reason

foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        _bnr_mort_s4_fail 111 "`release_id'" `"`private_log'"' ///
            `"Required metric variable is absent: `variable'"'
    }
}

quietly count
local metric_rows = r(N)
if `metric_rows' == 0 {
    _bnr_mort_s4_fail 2000 "`release_id'" `"`private_log'"' ///
        "The Step 3 metric dataset contains no rows."
}

capture isid metric_id period_type period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic, missok
if _rc {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "Metric rows are not unique at the CVD-compatible reporting grain."
}

quietly count if release_id != "`release_id'"
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A metric row has the wrong release identifier."
}

quietly count if !inlist(case_definition, "primary_clear_likely", ///
    "upper_clear_likely_possible")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A required Primary or Upper-bound case definition is missing or changed."
}
quietly count if case_definition == "primary_clear_likely"
local primary_definition_rows = r(N)
quietly count if case_definition == "upper_clear_likely_possible"
local upper_definition_rows = r(N)
if `primary_definition_rows' == 0 | `upper_definition_rows' == 0 | ///
        `primary_definition_rows' != `upper_definition_rows' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "Both case definitions must contain one equal dashboard lattice."
}

quietly count if sdc_policy != "bnr_sdc_v1" | ///
    primary_suppression_threshold != 6
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The Step 3 disclosure-control policy or threshold has changed."
}

quietly count if missing(metric_id) | missing(period_year) | ///
    missing(event_type) | missing(sex) | missing(age_group) | ///
    missing(statistic) | missing(unit) | ///
    (missing(value) & status_flag != "insufficient_history")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A metric row is missing a required reporting value."
}

quietly count if !inlist(metric_id, "MORT-BURDEN-001", "MORT-BURDEN-002")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The package contains an unrecognised mortality metric identifier."
}

quietly count if !inlist(event_type, "all_cvd", "heart", "stroke") | ///
    !inlist(sex, "all", "female", "male") | ///
    !inlist(age_group, "all", "under_70", "age_70_plus")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The package contains an unrecognised reporting dimension."
}

quietly summarize period_year, meanonly
local analysis_start_year = floor(r(min))
local analysis_end_year = floor(r(max))
local expected_years = `analysis_end_year' - `analysis_start_year' + 1

generate byte year_tag = 0
bysort period_year: replace year_tag = 1 if _n == 1
quietly count if year_tag == 1
local observed_years = r(N)
drop year_tag

if `analysis_start_year' != 2010 | `observed_years' != `expected_years' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The metric dataset does not contain the complete 2010-onward year series."
}

quietly count if period_complete != 1
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The Step 4 review package may contain completed reporting periods only."
}

quietly count if metric_id == "MORT-BURDEN-001"
local count_rows = r(N)
quietly count if metric_id == "MORT-BURDEN-002"
local distribution_rows = r(N)
quietly count if period_type == "annual"
local annual_rows = r(N)
quietly count if period_type == "quarterly"
local quarterly_rows = r(N)
quietly count if period_type == "monthly"
local monthly_rows = r(N)

local expected_count_rows = ///
    (`expected_years' * 11) + ((`expected_years' - 1) * 11) + ///
    (`expected_years' * 12 * 3) + ///
    (`expected_years' * 4 * 9) + ((`expected_years' - 1) * 4 * 9)
local expected_distribution_rows = `expected_years' * 10
local expected_count_rows = 2 * `expected_count_rows'
local expected_distribution_rows = 2 * `expected_distribution_rows'
if `count_rows' != `expected_count_rows' | ///
        `distribution_rows' != `expected_distribution_rows' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The metric row counts do not match the CVD dashboard reporting lattice."
}

* The upper-bound series must retain every Primary count at the exact same
* reporting grain. This makes the intended interpretation auditable before
* any public candidate is prepared.
preserve
    keep if unit == "count" & ///
        inlist(statistic, "annual_count", "monthly_count", "quarterly_count")
    keep metric_id period_type period_year period_month period_quarter ///
        event_type sex age_group statistic case_definition value
    reshape wide value, i(metric_id period_type period_year period_month ///
        period_quarter event_type sex age_group statistic) j(case_definition) string
    quietly count if valueprimary_clear_likely > ///
        valueupper_clear_likely_possible
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "A Primary count exceeds its matched Upper-bound count."
    }
restore

* Each year must reproduce the selective CVD dashboard row lattice for both
* reporting definitions: Primary and Upper bound.
forvalues yy = `analysis_start_year'/`analysis_end_year' {
    quietly count if period_year == `yy' & case_definition == "primary_clear_likely"
    local primary_rows_in_year = r(N)
    quietly count if period_year == `yy' & case_definition == "upper_clear_likely_possible"
    local upper_rows_in_year = r(N)
    local expected_rows_in_year = 140
    if `yy' == `analysis_start_year' local expected_rows_in_year = 93
    if `primary_rows_in_year' != `expected_rows_in_year' | ///
            `upper_rows_in_year' != `expected_rows_in_year' {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "Year `yy' does not match the CVD dashboard row lattice for both definitions."
    }
}

quietly count if age_group != "all" & ///
    (period_type != "annual" | event_type != "all_cvd" | sex != "all")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "An age-specific row falls outside the agreed annual all-CVD boundary."
}

quietly count if period_type == "monthly" & ///
    (event_type != "all_cvd" | age_group != "all")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A monthly row falls outside the agreed all-CVD boundary."
}

* Reconcile every all-sex observed count to female plus male.
preserve
    keep if unit == "count" & age_group == "all" & ///
        inlist(statistic, "annual_count", "monthly_count", "quarterly_count")
    generate double sex_component = value if inlist(sex, "female", "male")
    bysort case_definition period_type period_year period_month period_quarter ///
        event_type statistic: egen double sex_component_total = total(sex_component)
    quietly count if (sex == "all" & value != sex_component_total) | ///
        value != numerator | !missing(denominator) | ///
        value != floor(value) | value < 0
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "Observed count or sex-total reconciliation failed."
    }
restore

* Reconcile Heart plus Stroke to all-CVD wherever all three are reported.
preserve
    keep if unit == "count" & age_group == "all" & ///
        inlist(statistic, "annual_count", "quarterly_count")
    generate double event_component = value if inlist(event_type, "heart", "stroke")
    bysort case_definition period_type period_year period_month period_quarter ///
        sex statistic: egen double event_component_total = total(event_component)
    quietly count if event_type == "all_cvd" & value != event_component_total
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "Heart plus Stroke does not reproduce an all-CVD count."
    }
restore

* Reconcile monthly and quarterly observed counts to their annual totals.
preserve
    keep if unit == "count" & age_group == "all" & event_type == "all_cvd" & ///
        inlist(statistic, "annual_count", "monthly_count")
    generate double annual_value = value if statistic == "annual_count"
    generate double monthly_value = value if statistic == "monthly_count"
    bysort case_definition period_year sex: egen double annual_total = max(annual_value)
    bysort case_definition period_year sex: egen double monthly_total = total(monthly_value)
    quietly count if annual_total != monthly_total
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "Monthly all-CVD counts do not reproduce an annual total."
    }
restore

preserve
    keep if unit == "count" & age_group == "all" & ///
        inlist(statistic, "annual_count", "quarterly_count")
    generate double annual_value = value if statistic == "annual_count"
    generate double quarterly_value = value if statistic == "quarterly_count"
    bysort case_definition period_year event_type sex: egen double annual_total = max(annual_value)
    bysort case_definition period_year event_type sex: egen double quarterly_total = total(quarterly_value)
    quietly count if annual_total != quarterly_total
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "Quarterly counts do not reproduce an annual total."
    }
restore

* Revalidate percentage arithmetic and each annual distribution family.
quietly count if unit == "percent" & ///
    (denominator <= 0 | missing(denominator) | numerator > denominator | ///
    abs(value - (100 * numerator / denominator)) > 0.00000001)
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "Percentage arithmetic failed."
}

preserve
    keep if statistic == "event_type_distribution"
    bysort case_definition period_year: egen double percent_total = total(value)
    quietly count if abs(percent_total - 100) > 0.00000001
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "An annual event-type distribution does not sum to 100 percent."
    }
restore

preserve
    keep if statistic == "sex_distribution"
    bysort case_definition period_year event_type: egen double percent_total = total(value)
    quietly count if abs(percent_total - 100) > 0.00000001
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "An annual sex distribution does not sum to 100 percent."
    }
restore

preserve
    keep if statistic == "age_distribution"
    bysort case_definition period_year: egen double percent_total = total(value)
    quietly count if abs(percent_total - 100) > 0.00000001
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "An annual age distribution does not sum to 100 percent."
    }
restore

quietly count if primary_suppression == 1
local primary_suppression_rows = r(N)
quietly count if suppression_review == 1
local suppression_review_rows = r(N)
quietly count if primary_suppression == 1 & suppression_review != 1
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A primary-suppression row is missing from the review worklist."
}
quietly count if related_primary_cells > 0 & suppression_review != 1
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A suppression-related row is missing from the review worklist."
}

quietly summarize value if metric_id == "MORT-BURDEN-001" & ///
    statistic == "annual_count" & event_type == "heart" & ///
    sex == "all" & age_group == "all" & ///
    case_definition == "primary_clear_likely", meanonly
local heart_deaths = r(sum)
quietly summarize value if metric_id == "MORT-BURDEN-001" & ///
    statistic == "annual_count" & event_type == "stroke" & ///
    sex == "all" & age_group == "all" & ///
    case_definition == "primary_clear_likely", meanonly
local stroke_deaths = r(sum)
quietly summarize value if metric_id == "MORT-BURDEN-001" & ///
    statistic == "annual_count" & event_type == "all_cvd" & ///
    sex == "all" & age_group == "all" & ///
    case_definition == "primary_clear_likely", meanonly
local cvd_deaths = r(sum)

quietly summarize value if metric_id == "MORT-BURDEN-001" & ///
    statistic == "annual_count" & event_type == "heart" & ///
    sex == "all" & age_group == "all" & ///
    case_definition == "upper_clear_likely_possible", meanonly
local upper_heart_deaths = r(sum)
quietly summarize value if metric_id == "MORT-BURDEN-001" & ///
    statistic == "annual_count" & event_type == "stroke" & ///
    sex == "all" & age_group == "all" & ///
    case_definition == "upper_clear_likely_possible", meanonly
local upper_stroke_deaths = r(sum)
quietly summarize value if metric_id == "MORT-BURDEN-001" & ///
    statistic == "annual_count" & event_type == "all_cvd" & ///
    sex == "all" & age_group == "all" & ///
    case_definition == "upper_clear_likely_possible", meanonly
local upper_cvd_deaths = r(sum)

* Aggregate outputs must not contain record-level identifiers.
foreach forbidden_name in pid patient_id registration_id national_id name dob dod {
    capture confirm variable `forbidden_name'
    if !_rc {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            `"Record-level identifier found in aggregate output: `forbidden_name'"'
    }
}

* ==============================================================================
* 5. REVALIDATE STEP 3 QA AND SUPPRESSION WORKLIST -- DO NOT EDIT
* ==============================================================================
import delimited using `"`step3_qa'"', varnames(1) stringcols(_all) clear
foreach qa_variable in check result detail {
    capture confirm variable `qa_variable'
    if _rc {
        _bnr_mort_s4_fail 111 "`release_id'" `"`private_log'"' ///
            `"Step 3 QA variable is absent: `qa_variable'"'
    }
}
quietly count
local step3_qa_rows = r(N)
if `step3_qa_rows' != 15 {
    _bnr_mort_s4_fail 2000 "`release_id'" `"`private_log'"' ///
        "The hardened Step 3 QA receipt must contain exactly 15 checks."
}
capture isid check
if _rc {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "Step 3 QA check names are missing or duplicated."
}
local required_step3_checks required_step2_variables source_and_cohort_rows ///
    website_analysis_period date_reconciliation combined_primary_definition ///
    component_definition_comparison resolved_family cvd_dashboard_lattice ///
    metric_grain_and_rows metric_reconciliation ///
    sex_and_event_reconciliation cross_frequency_reconciliation ///
    comparator_history suppression_worklist rates_out_of_scope
foreach required_step3_check of local required_step3_checks {
    quietly count if check == "`required_step3_check'"
    if r(N) != 1 {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "A required hardened Step 3 QA check is absent: `required_step3_check'"
    }
}
quietly count if result != "PASS"
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "At least one Step 3 QA check did not pass."
}

import delimited using `"`suppression_csv'"', varnames(1) stringcols(_all) clear
foreach suppression_variable in release_id metric_id period_type period ///
        period_year period_month period_quarter case_definition event_type sex age_group ///
        statistic value unit numerator denominator ///
        primary_suppression related_primary_cells ///
        related_suppression_review suppression_reason {
    capture confirm variable `suppression_variable'
    if _rc {
        _bnr_mort_s4_fail 111 "`release_id'" `"`private_log'"' ///
            `"Suppression-worklist variable is absent: `suppression_variable'"'
    }
}
quietly count
local suppression_csv_rows = r(N)
if `suppression_csv_rows' != `suppression_review_rows' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The suppression CSV row count differs from the metric review flag count."
}

if `suppression_csv_rows' > 0 {
    generate str244 worklist_key = metric_id + "|" + period_type + "|" + ///
        period + "|" + case_definition + "|" + event_type + "|" + sex + "|" + age_group + "|" + statistic
    capture isid worklist_key
    if _rc {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "The suppression CSV contains duplicate worklist keys."
    }
    keep worklist_key
    tempfile suppression_keys
    save `suppression_keys'

    use `"`release_dta'"', clear
    keep if suppression_review == 1
    generate str244 worklist_key = metric_id + "|" + period_type + "|" + ///
        period + "|" + case_definition + "|" + event_type + "|" + sex + "|" + age_group + "|" + statistic
    keep worklist_key
    merge 1:1 worklist_key using `suppression_keys'
    quietly count if _merge != 3
    if r(N) {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "The suppression CSV does not match the flagged metric rows."
    }

    import excel using `"`suppression_xlsx'"', ///
        sheet("Suppression worklist") firstrow clear
    quietly count
    if r(N) != `suppression_review_rows' {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "The suppression workbook row count differs from the metric review flag count."
    }
}
else {
    import excel using `"`suppression_xlsx'"', ///
        sheet("Review status") firstrow clear
    capture confirm variable review_status
    if _rc {
        _bnr_mort_s4_fail 111 "`release_id'" `"`private_log'"' ///
            "The zero-row suppression workbook has an invalid structure."
    }
    quietly count if review_status == "PASS"
    if r(N) != 1 {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            "The zero-row suppression workbook does not contain one PASS status."
    }
}

* ==============================================================================
* 6. REVALIDATE STEP 3 METADATA -- DO NOT EDIT
* ==============================================================================
* Keep a copy of every metadata line for the workbook while checking the exact
* release, analysis period, definitions, row counts and workflow boundary.
local meta_schema = 0
local meta_package = 0
local meta_status = 0
local meta_step = 0
local meta_release = 0
local meta_release_year = 0
local meta_release_month = 0
local meta_start_year = 0
local meta_end_year = 0
local meta_primary_definition = 0
local meta_upper_definition = 0
local meta_no_lower = 0
local meta_website_start = 0
local meta_all_cvd = 0
local meta_heart = 0
local meta_stroke = 0
local meta_combined_primary = 0
local meta_combined_upper = 0
local meta_resolved_primary = 0
local meta_resolved_upper = 0
local meta_annual = 0
local meta_quarterly = 0
local meta_monthly = 0
local meta_monthly_no_rolling = 0
local meta_quarterly_annual_rolling = 0
local meta_monthly_public_scope = 0
local meta_monthly_reference = 0
local meta_reporting_scope = 0
local meta_metric_1 = 0
local meta_metric_2 = 0
local meta_rows = 0
local meta_count_rows = 0
local meta_distribution_rows = 0
local meta_qa_rows = 0
local meta_byte_identical = 0
local meta_rates = 0
local meta_dco = 0
local meta_primary_rows = 0
local meta_review_rows = 0
local meta_approved = 0
local meta_public_ready = 0
local meta_boundary = 0

tempfile metadata_lines
tempname metadata_post metadata_handle
postfile `metadata_post' int line_number str244 metadata_line ///
    using `metadata_lines', replace

file open `metadata_handle' using `"`package_metadata'"', read text
file read `metadata_handle' metadata_line
local line_number = 0
while r(eof) == 0 {
    local line_number = `line_number' + 1
    post `metadata_post' (`line_number') (`"`metadata_line'"')
    local cleaned_line = strtrim(`"`metadata_line'"')

    if "`cleaned_line'" == "schema: bnr_mortality_burden_package_v2" local meta_schema = 1
    if "`cleaned_line'" == "package_id: `package_id'" local meta_package = 1
    if "`cleaned_line'" == "package_status: staging" local meta_status = 1
    if "`cleaned_line'" == "workflow_step: 3" local meta_step = 1
    if "`cleaned_line'" == "release_id: `release_id'" local meta_release = 1
    if "`cleaned_line'" == "source_release_year: `release_year_4'" local meta_release_year = 1
    if "`cleaned_line'" == "source_release_month: `release_month_2'" local meta_release_month = 1
    if "`cleaned_line'" == "analysis_start_year: `analysis_start_year'" local meta_start_year = 1
    if "`cleaned_line'" == "analysis_end_year: `analysis_end_year'" local meta_end_year = 1
    if "`cleaned_line'" == "- primary_clear_likely" local meta_primary_definition = 1
    if "`cleaned_line'" == "- upper_clear_likely_possible" local meta_upper_definition = 1
    if "`cleaned_line'" == "lower_bound_included: false" local meta_no_lower = 1
    if "`cleaned_line'" == "website_analysis_start: 2010-01-01" local meta_website_start = 1
    if "`cleaned_line'" == "- all_cvd" local meta_all_cvd = 1
    if "`cleaned_line'" == "- heart" local meta_heart = 1
    if "`cleaned_line'" == "- stroke" local meta_stroke = 1
    if "`cleaned_line'" == "combined_definition_primary: Step 2 cvd_prim" local meta_combined_primary = 1
    if "`cleaned_line'" == "combined_definition_upper: Step 2 cvd_incl" local meta_combined_upper = 1
    if "`cleaned_line'" == "resolved_family_primary: Step 2 cvd_sub_p" local meta_resolved_primary = 1
    if "`cleaned_line'" == "resolved_family_upper: Step 2 cvd_sub_i" local meta_resolved_upper = 1
    if "`cleaned_line'" == "- annual" local meta_annual = 1
    if "`cleaned_line'" == "- quarterly" local meta_quarterly = 1
    if "`cleaned_line'" == "- monthly" local meta_monthly = 1
    if "`cleaned_line'" == "monthly_rolling_comparator_included: false" local meta_monthly_no_rolling = 1
    if "`cleaned_line'" == "quarterly_annual_rolling_comparators_included: true" local meta_quarterly_annual_rolling = 1
    if "`cleaned_line'" == "monthly_public_scope: all_cvd_all_sexes_all_ages_only" local meta_monthly_public_scope = 1
    if "`cleaned_line'" == "monthly_historical_reference: created_and_reviewed_in_step_4" local meta_monthly_reference = 1
    if "`cleaned_line'" == "cvd_dashboard_reporting_scope_aligned: true" local meta_reporting_scope = 1
    if "`cleaned_line'" == "- MORT-BURDEN-001" local meta_metric_1 = 1
    if "`cleaned_line'" == "- MORT-BURDEN-002" local meta_metric_2 = 1
    if "`cleaned_line'" == "metric_rows: `metric_rows'" local meta_rows = 1
    if "`cleaned_line'" == "count_rows: `count_rows'" local meta_count_rows = 1
    if "`cleaned_line'" == "distribution_rows: `distribution_rows'" local meta_distribution_rows = 1
    if "`cleaned_line'" == "qa_checks: `step3_qa_rows'" local meta_qa_rows = 1
    if "`cleaned_line'" == "release_and_current_files_byte_identical: true" local meta_byte_identical = 1
    if "`cleaned_line'" == "rates_included: false" local meta_rates = 1
    if "`cleaned_line'" == "dco_linkage_included: false" local meta_dco = 1
    if "`cleaned_line'" == "primary_suppression_rows: `primary_suppression_rows'" local meta_primary_rows = 1
    if "`cleaned_line'" == "suppression_review_rows: `suppression_review_rows'" local meta_review_rows = 1
    if "`cleaned_line'" == "approved: false" local meta_approved = 1
    if "`cleaned_line'" == "public_ready: false" local meta_public_ready = 1
    if "`cleaned_line'" == "publication_boundary: no_public_or_site_files_created" local meta_boundary = 1

    file read `metadata_handle' metadata_line
}
file close `metadata_handle'
postclose `metadata_post'

foreach metadata_check in meta_schema meta_package meta_status meta_step meta_release ///
        meta_release_year meta_release_month meta_start_year meta_end_year ///
        meta_primary_definition meta_upper_definition meta_no_lower ///
        meta_website_start meta_all_cvd meta_heart meta_stroke ///
        meta_combined_primary meta_combined_upper meta_resolved_primary ///
        meta_resolved_upper meta_annual meta_quarterly meta_monthly ///
        meta_monthly_no_rolling meta_quarterly_annual_rolling ///
        meta_monthly_public_scope meta_monthly_reference meta_reporting_scope meta_metric_1 ///
        meta_metric_2 meta_rows meta_count_rows meta_distribution_rows ///
        meta_qa_rows meta_byte_identical meta_rates meta_dco ///
        meta_primary_rows meta_review_rows meta_approved meta_public_ready ///
        meta_boundary {
    if ``metadata_check'' != 1 {
        _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
            `"Required Step 3 metadata check failed: `metadata_check'"'
    }
}

* ==============================================================================
* 7. CREATE THE INITIAL FIXED MONTHLY REFERENCE CANDIDATE -- ONE-TIME BUILD
* ==============================================================================
* This initial build is deliberately located in Step 4, not Step 3: the
* reference is a proposed public analytical asset and must be visible in the
* Step 4 workbook before Step 5 can approve it. It uses only all-CVD, all-sex,
* all-age monthly counts for 2015-2019, separately for each mortality scenario.
*
* IMPORTANT AFTER FIRST APPROVAL:
*   This active one-time block must be replaced by the commented future-run
*   template immediately below. Future releases must read and checksum-verify
*   the approved fixed asset; they must never recalculate its values.
local reference_start_year = 2015
local reference_end_year = 2019
local reference_expected_rows = 24

use `"`release_dta'"', clear
keep if metric_id == "MORT-BURDEN-001" & ///
    period_type == "monthly" & statistic == "monthly_count" & ///
    event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
    inrange(period_year, `reference_start_year', `reference_end_year')

quietly count if inrange(value, 1, 5)
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The proposed 2015-2019 monthly reference includes a protected supporting count. It cannot be released as a fixed reference asset."
}

collapse (min) reference_min = value ///
    (max) reference_max = value ///
    (mean) reference_mean = value ///
    (count) reference_n = value, ///
    by(case_definition period_month event_type sex age_group)

quietly count
if r(N) != `reference_expected_rows' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The proposed 2015-2019 monthly reference does not contain 24 scenario-month rows."
}
quietly count if reference_n != 5 | missing(reference_min) | ///
    missing(reference_max) | missing(reference_mean) | ///
    reference_min > reference_max
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The proposed monthly reference contains an invalid minimum, maximum, mean or contributing-year count."
}

generate str40 reference_id = "mortality_monthly_reference_2015_2019"
generate int reference_start_year = `reference_start_year'
generate int reference_end_year = `reference_end_year'
generate str36 source_release_id = "`release_id'"
generate str80 reference_method = ///
    "Same calendar-month minimum, maximum and mean from 2015-2019"
order reference_id case_definition event_type sex age_group period_month ///
    reference_start_year reference_end_year reference_n reference_min ///
    reference_max reference_mean source_release_id reference_method
sort case_definition period_month
label data "BNR mortality fixed monthly historical-reference candidate"
notes _dta: review_only: initial 2015-2019 reference candidate; not approved or public
save `"`reference_dta'"', replace
export delimited using `"`reference_csv'"', replace

quietly checksum `"`reference_dta'"'
local reference_dta_size = r(filelen)
local reference_dta_checksum = r(checksum)
quietly checksum `"`reference_csv'"'
local reference_csv_size = r(filelen)
local reference_csv_checksum = r(checksum)

tempname reference_meta
file open `reference_meta' using `"`reference_yml'"', write text replace
file write `reference_meta' "schema: bnr_mortality_monthly_reference_v1" _n
file write `reference_meta' "status: review_candidate_not_approved" _n
file write `reference_meta' "reference_id: mortality_monthly_reference_2015_2019" _n
file write `reference_meta' "reference_period: 2015-2019" _n
file write `reference_meta' "frequency: monthly" _n
file write `reference_meta' "public_scope: all_cvd_all_sexes_all_ages_only" _n
file write `reference_meta' "statistics: minimum_maximum_mean" _n
file write `reference_meta' "scenario_count: 2" _n
file write `reference_meta' "calendar_month_rows: 24" _n
file write `reference_meta' "source_release_id: `release_id'" _n
file write `reference_meta' "source_file: mort_burden_metrics_`release_id'.dta" _n
file write `reference_meta' "recalculation_rule: do_not_recalculate_after_initial_approval" _n
file close `reference_meta'

* FUTURE-RUN TEMPLATE -- KEEP COMMENTED OUT AFTER THE INITIAL APPROVAL.
* -----------------------------------------------------------------------------
* Future Step 4 runs must instead:
*   1. copy the approved reference DTA/CSV/YML from the authoritative Step 6
*      public mortality release into this private review package;
*   2. checksum-verify it against the approved reference manifest entry; and
*   3. stop if it differs. They must not run the calculation above.
*
* capture copy "<approved_reference_dta>" `"`reference_dta'"'
* capture copy "<approved_reference_csv>" `"`reference_csv'"'
* capture copy "<approved_reference_yml>" `"`reference_yml'"'

* ==============================================================================
* 7. CREATE THE DISCLOSURE-CONTROLLED REVIEW CANDIDATE -- DO NOT EDIT
* ==============================================================================
* Step 3 identifies primary low-cell and directly-derived risks. Step 4 then
* applies the fixed BNR complementary-suppression rule to the published
* additive lattice. This prevents a primary-suppressed female, male, Heart,
* Stroke or age cell being reconstructed from visible additive cells.
*
* The candidate remains inside private review/. It is the exact dataset that
* the analyst reviews and that Step 5 may later package after approval.
use `"`release_dta'"', clear

* The Step 3 package deliberately retains monthly female and male values for
* private QA. They are not part of the approved public monthly reporting
* contract. Remove them before any public-candidate suppression calculation.
* Quarterly and annual sex rows remain in scope.
drop if period_type == "monthly" & sex != "all"

quietly count if primary_suppression == 1
local public_primary_source_rows = r(N)

generate long candidate_row = _n

* Start with Step 3 primary risks and its existing derived-comparator flags.
generate byte primary_protection = primary_suppression == 1
generate byte secondary_protection = ///
    suppression_review == 1 & primary_suppression == 0

* ------------------------------------------------------------------------------
* COMPLEMENTARY SUPPRESSION: OBSERVED SEX COUNTS
* ------------------------------------------------------------------------------
* For every primary-suppressed count, hide one visible other-sex category. The
* convention is stable and transparent: female -> male, male -> female, and
* all-sex -> male. A selected category already subject to primary suppression is left
* as primary rather than being re-labelled secondary.
generate byte observed_count = unit == "count" & ///
    inlist(statistic, "annual_count", "monthly_count", "quarterly_count")
generate byte female_primary = observed_count & primary_protection & sex == "female"
generate byte male_primary = observed_count & primary_protection & sex == "male"
generate byte all_primary = observed_count & primary_protection & sex == "all"
bysort case_definition period_type period_year period_month period_quarter ///
    event_type age_group statistic: egen byte any_female_primary = max(female_primary)
bysort case_definition period_type period_year period_month period_quarter ///
    event_type age_group statistic: egen byte any_male_primary = max(male_primary)
bysort case_definition period_type period_year period_month period_quarter ///
    event_type age_group statistic: egen byte any_all_primary = max(all_primary)
replace secondary_protection = 1 if observed_count & !primary_protection & ///
    ((sex == "male" & (any_female_primary | any_all_primary)) | ///
     (sex == "female" & any_male_primary))

* ------------------------------------------------------------------------------
* COMPLEMENTARY SUPPRESSION: OBSERVED EVENT COUNTS
* ------------------------------------------------------------------------------
* Annual and quarterly Heart/Stroke rows sum to all-CVD. One component is
* therefore hidden whenever its counterpart is primary-suppressed. If all-CVD
* itself is primary-suppressed, Stroke is the stable secondary category.
generate byte heart_primary = observed_count & primary_protection & event_type == "heart"
generate byte stroke_primary = observed_count & primary_protection & event_type == "stroke"
generate byte cvd_primary = observed_count & primary_protection & event_type == "all_cvd"
bysort case_definition period_type period_year period_month period_quarter ///
    sex age_group statistic: egen byte any_heart_primary = max(heart_primary)
bysort case_definition period_type period_year period_month period_quarter ///
    sex age_group statistic: egen byte any_stroke_primary = max(stroke_primary)
bysort case_definition period_type period_year period_month period_quarter ///
    sex age_group statistic: egen byte any_cvd_primary = max(cvd_primary)
replace secondary_protection = 1 if observed_count & !primary_protection & ///
    ((event_type == "stroke" & (any_heart_primary | any_cvd_primary)) | ///
     (event_type == "heart" & any_stroke_primary))

* ------------------------------------------------------------------------------
* COMPLEMENTARY SUPPRESSION: ANNUAL AGE COUNTS
* ------------------------------------------------------------------------------
* The two annual age rows form a small additive table used by the age
* distribution. Protect the other age component when one is primary-suppressed.
generate byte under_primary = observed_count & primary_protection & ///
    age_group == "under_70"
generate byte age70_primary = observed_count & primary_protection & ///
    age_group == "age_70_plus"
bysort case_definition period_year event_type sex statistic: ///
    egen byte any_under_primary = max(under_primary)
bysort case_definition period_year event_type sex statistic: ///
    egen byte any_age70_primary = max(age70_primary)
replace secondary_protection = 1 if observed_count & !primary_protection & ///
    ((age_group == "age_70_plus" & any_under_primary) | ///
     (age_group == "under_70" & any_age70_primary))

* ------------------------------------------------------------------------------
* TEMPORAL DIFFERENCING PROTECTION
* ------------------------------------------------------------------------------
* A protected monthly count must not be recoverable from a visible quarterly
* total minus the other two visible months, or from a visible annual total minus
* the other eleven visible months. The same risk can also arise through visible
* Heart/Stroke and sex components of an all-CVD aggregate.
*
* The previous implementation hid the complete quarterly and annual panels.
* That was safe but unnecessarily heavy. The fixed rule below instead protects
* the smallest stable set of cells that closes the published equations:
*   - all-CVD female and male totals; and
*   - Heart female and male components.
* The two Heart cells make the hidden all-CVD female total unrecoverable from
* Heart plus Stroke. The male all-CVD total prevents reconstruction through the
* all-sex margin. Heart is the fixed component choice; this makes each run
* reproducible and avoids analyst editing.
*
* A rare primary all-sex monthly count needs two additional cells: the all-CVD
* all-sex total and Heart all-sex total. These close the corresponding all-sex
* event equation. The primary threshold itself remains unchanged at 1 to 5.
quietly count if observed_count & period_type == "monthly" & ///
    (primary_protection | secondary_protection)
local temporal_source_rows = r(N)
generate byte temporal_panel = 0

if `temporal_source_rows' > 0 {
    preserve
        keep if observed_count & period_type == "monthly" & ///
            (primary_protection | secondary_protection)
        keep case_definition period_year period_month
        generate byte period_quarter = ceil(period_month / 3)
        generate str12 period_type = "quarterly"
        keep case_definition period_type period_year period_quarter
        duplicates drop
        tempfile temporal_quarter_panels
        save `temporal_quarter_panels', replace
    restore

    preserve
        keep if observed_count & period_type == "monthly" & ///
            (primary_protection | secondary_protection)
        keep case_definition period_year
        generate byte period_quarter = .
        generate str12 period_type = "annual"
        keep case_definition period_type period_year period_quarter
        duplicates drop
        tempfile temporal_annual_panels
        save `temporal_annual_panels', replace
    restore

    preserve
        use `temporal_quarter_panels', clear
        append using `temporal_annual_panels'
        duplicates drop
        tempfile temporal_panels
        save `temporal_panels', replace
    restore

    preserve
        keep candidate_row case_definition period_type period_year period_quarter ///
            observed_count event_type sex age_group
        keep if observed_count & inlist(period_type, "annual", "quarterly") & ///
            ((event_type == "all_cvd" & inlist(sex, "female", "male")) | ///
             (event_type == "heart" & inlist(sex, "female", "male")))
        merge m:1 case_definition period_type period_year period_quarter ///
            using `temporal_panels', keep(master match) gen(temporal_match)
        keep if temporal_match == 3
        keep candidate_row
        generate byte temporal_panel_match = 1
        tempfile temporal_candidate_rows
        save `temporal_candidate_rows', replace
    restore

    merge 1:1 candidate_row using `temporal_candidate_rows', nogen
    replace temporal_panel = 1 if temporal_panel_match == 1
    drop temporal_panel_match
    replace secondary_protection = 1 if temporal_panel == 1 & ///
        !primary_protection
}

* Add the two all-sex protection cells only where the original protected
* monthly count itself was all-sex. Most mortality releases will not use this
* branch. Do not build or merge an empty optional panel: an empty temporary
* result can stop Stata with r(2000). The zero indicator remains explicit so
* that the later QA check has a stable variable on every release.
quietly count if observed_count & period_type == "monthly" & ///
    primary_protection & sex == "all"
local allsex_monthly_primary_rows = r(N)

if `allsex_monthly_primary_rows' > 0 {
    preserve
        keep if observed_count & period_type == "monthly" & primary_protection & ///
            sex == "all"
        keep case_definition period_year period_month
        generate byte period_quarter = ceil(period_month / 3)
        generate str12 period_type = "quarterly"
        keep case_definition period_type period_year period_quarter
        duplicates drop
        tempfile allsex_quarter_panels
        save `allsex_quarter_panels', replace
    restore
    preserve
        keep if observed_count & period_type == "monthly" & primary_protection & ///
            sex == "all"
        keep case_definition period_year
        generate byte period_quarter = .
        generate str12 period_type = "annual"
        keep case_definition period_type period_year period_quarter
        duplicates drop
        tempfile allsex_annual_panels
        save `allsex_annual_panels', replace
    restore
    preserve
        use `allsex_quarter_panels', clear
        append using `allsex_annual_panels'
        duplicates drop
        tempfile allsex_temporal_panels
        save `allsex_temporal_panels', replace
    restore
    preserve
        keep candidate_row case_definition period_type period_year period_quarter ///
            observed_count event_type sex age_group
        keep if observed_count & inlist(period_type, "annual", "quarterly") & ///
            sex == "all" & inlist(event_type, "all_cvd", "heart")
        merge m:1 case_definition period_type period_year period_quarter ///
            using `allsex_temporal_panels', keep(master match) gen(allsex_match)
        keep if allsex_match == 3
        keep candidate_row
        generate byte allsex_temporal_panel = 1
        tempfile allsex_temporal_candidate_rows
        save `allsex_temporal_candidate_rows', replace
    restore
    merge 1:1 candidate_row using `allsex_temporal_candidate_rows', nogen
    replace allsex_temporal_panel = 0 if missing(allsex_temporal_panel)
    replace secondary_protection = 1 if allsex_temporal_panel == 1 & ///
        !primary_protection
}
else {
    generate byte allsex_temporal_panel = 0
}

* ------------------------------------------------------------------------------
* DERIVED PERCENTAGES AND FIVE-YEAR COMPARATORS
* ------------------------------------------------------------------------------
* Annual percentages are suppressed if the same annual event/sex/age family
* contains a protected observed count. This keeps calculation simple and avoids
* releasing a percentage that would disclose a masked numerator or denominator.
generate byte protected_annual_count = observed_count & ///
    (primary_protection | secondary_protection) & period_type == "annual"
bysort case_definition period_year event_type: ///
    egen byte event_has_protected_annual_count = max(protected_annual_count)
bysort case_definition period_year: egen byte event_distribution_protected = ///
    max(protected_annual_count & sex == "all" & ///
        inlist(event_type, "heart", "stroke"))
bysort case_definition period_year: egen byte age_distribution_protected = ///
    max(protected_annual_count & event_type == "all_cvd" & sex == "all" & ///
        inlist(age_group, "under_70", "age_70_plus"))
replace secondary_protection = 1 if !primary_protection & ///
    statistic == "sex_distribution" & event_has_protected_annual_count
replace secondary_protection = 1 if !primary_protection & ///
    inlist(statistic, "event_type_distribution", "age_distribution") & ///
    ((statistic == "event_type_distribution" & event_distribution_protected) | ///
     (statistic == "age_distribution" & age_distribution_protected))

* A comparator is also protected when any of its five historical observed
* components is primary or complementary-suppressed. This extends Step 3's
* primary-only worklist to the complete additive disclosure-control rule.
quietly count if observed_count & (primary_protection | secondary_protection)
local protected_count_rows = r(N)
generate byte comp_has_protected_component = 0

if `protected_count_rows' > 0 {
    preserve
        keep if observed_count & (primary_protection | secondary_protection)
        keep case_definition period_type period_year period_month period_quarter ///
            event_type sex age_group
        rename period_year component_year
        tempfile protected_count_components
        save `protected_count_components', replace
    restore

    quietly count if inlist(statistic, "annual_previous_5yr_mean", ///
        "quarterly_same_quarter_previous_5yr_mean")
    local comparator_rows = r(N)

    if `comparator_rows' > 0 {
        preserve
            keep if inlist(statistic, "annual_previous_5yr_mean", ///
                "quarterly_same_quarter_previous_5yr_mean")
            keep candidate_row case_definition period_type period_year period_month ///
                period_quarter event_type sex age_group
            rename period_year comparator_year
            joinby case_definition period_type period_month period_quarter ///
                event_type sex age_group using `protected_count_components'
            keep if inrange(component_year, comparator_year - 5, comparator_year - 1)
            quietly count
            local comparator_matches = r(N)
            if `comparator_matches' > 0 {
                keep candidate_row
                duplicates drop
                generate byte comparator_match = 1
                tempfile protected_comparators
                save `protected_comparators', replace
            }
        restore

        if `comparator_matches' > 0 {
            merge 1:1 candidate_row using `protected_comparators', nogen
            replace comp_has_protected_component = 1 if comparator_match == 1
            drop comparator_match
        }
    }
}

replace secondary_protection = 1 if comp_has_protected_component == 1 & ///
    !primary_protection

generate str12 suppression_status = "none"
replace suppression_status = "primary" if primary_protection
replace suppression_status = "secondary" if ///
    secondary_protection & !primary_protection

* ------------------------------------------------------------------------------
* FAIL-CLOSED EQUATION AUDIT -- DO NOT EDIT
* ------------------------------------------------------------------------------
* A published additive equation is safe only when it has no protected term, or
* at least two protected terms. Exactly one protected term would allow that term
* to be reconstructed from the visible terms. The audit covers the actual
* mortality reporting lattice: sex totals, Heart/Stroke totals, monthly-to-
* quarterly totals and monthly-to-annual totals. It is private QA only.
generate byte audit_hidden = suppression_status != "none"
tempfile candidate_before_audit audit_sex audit_event audit_quarter audit_annual equation_audit
save `candidate_before_audit', replace

preserve
    keep if observed_count & age_group == "all"
    keep case_definition period_type period_year period_month period_quarter ///
        event_type statistic audit_hidden sex
    reshape wide audit_hidden, i(case_definition period_type period_year ///
        period_month period_quarter event_type statistic) j(sex) string
    generate int suppressed_terms = audit_hiddenall + audit_hiddenfemale + audit_hiddenmale
    generate str32 audit_relation = "sex_total"
    keep audit_relation suppressed_terms
    save `audit_sex', replace
restore

preserve
    * Heart and Stroke are reported only annually and quarterly. Restricting
    * this audit to those panels ensures all three event terms exist before
    * reshape checks the all-CVD = Heart + Stroke equation.
    keep if observed_count & age_group == "all" & ///
        inlist(period_type, "annual", "quarterly")
    keep case_definition period_type period_year period_month period_quarter ///
        sex statistic audit_hidden event_type
    reshape wide audit_hidden, i(case_definition period_type period_year ///
        period_month period_quarter sex statistic) j(event_type) string
    generate int suppressed_terms = audit_hiddenall_cvd + audit_hiddenheart + audit_hiddenstroke
    generate str32 audit_relation = "event_total"
    keep audit_relation suppressed_terms
    save `audit_event', replace
restore

* Prepare the monthly side and quarterly side in separate preserve/restore
* sections. Stata permits one active preserve only; do not nest these blocks.
preserve
    keep if observed_count & event_type == "all_cvd" & age_group == "all" & ///
        period_type == "monthly"
    generate byte audit_quarter = ceil(period_month / 3)
    collapse (sum) monthly_hidden = audit_hidden (count) monthly_rows = audit_hidden, ///
        by(case_definition period_year audit_quarter sex)
    keep if monthly_rows == 3
    rename audit_quarter period_quarter
    tempfile quarter_months
    save `quarter_months', replace
restore
preserve
    keep if observed_count & event_type == "all_cvd" & age_group == "all"
    keep if period_type == "quarterly"
    keep case_definition period_year period_quarter sex audit_hidden
    rename audit_hidden quarterly_hidden
    merge 1:1 case_definition period_year period_quarter sex using `quarter_months', nogen
    keep if !missing(monthly_rows)
    generate int suppressed_terms = monthly_hidden + quarterly_hidden
    generate str32 audit_relation = "monthly_to_quarter"
    keep audit_relation suppressed_terms
    save `audit_quarter', replace
restore

preserve
    keep if observed_count & event_type == "all_cvd" & age_group == "all" & ///
        period_type == "monthly"
    collapse (sum) monthly_hidden = audit_hidden (count) monthly_rows = audit_hidden, ///
        by(case_definition period_year sex)
    keep if monthly_rows == 12
    tempfile annual_months
    save `annual_months', replace
restore
preserve
    keep if observed_count & event_type == "all_cvd" & age_group == "all"
    keep if period_type == "annual"
    keep case_definition period_year sex audit_hidden
    rename audit_hidden annual_hidden
    merge 1:1 case_definition period_year sex using `annual_months', nogen
    keep if !missing(monthly_rows)
    generate int suppressed_terms = monthly_hidden + annual_hidden
    generate str32 audit_relation = "monthly_to_annual"
    keep audit_relation suppressed_terms
    save `audit_annual', replace
restore

use `audit_sex', clear
append using `audit_event' `audit_quarter' `audit_annual'
generate byte exact_reconstruction_risk = suppressed_terms == 1
generate str6 audit_result = cond(exact_reconstruction_risk, "FAIL", "PASS")
quietly count
local equation_audit_rows = r(N)
quietly count if exact_reconstruction_risk
local equation_audit_failures = r(N)
save `equation_audit', replace
if `equation_audit_failures' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The private equation audit found a reconstructable protected count."
}
use `candidate_before_audit', clear

replace suppression_reason = "complementary_or_linked_suppression" if ///
    suppression_status == "secondary" & ///
    (missing(suppression_reason) | strtrim(suppression_reason) == "")

generate str244 disclosure_note = "No disclosure restriction identified."
replace disclosure_note = ///
    "Suppressed because the supporting death count is between 1 and 5." ///
    if suppression_status == "primary"
replace disclosure_note = ///
    "Suppressed because release would otherwise disclose or permit calculation of a primary-suppressed death count." ///
    if suppression_status == "secondary"

* ------------------------------------------------------------------------------
* PRIVATE EXACT-VALUE SUPPRESSION REVIEW -- DO NOT EDIT
* ------------------------------------------------------------------------------
* The public candidate correctly removes exact protected values. That is not
* enough on its own for a practical human review: the analyst also needs a
* simple, non-programming way to see what was protected and why. This private
* review extract is therefore created BEFORE protected values are blanked. It
* is exported only to the private Step 4 workbook's Suppression review sheet.
*
* It is never saved as a public-ready dataset, never copied by Step 5 and never
* promoted by Step 6. Analysts must not copy this private sheet into a public
* report, download or dashboard.
generate str80 protection_route = ""
replace protection_route = "Primary small count (1 to 5)" if ///
    suppression_status == "primary"
replace protection_route = "Minimum quarterly or annual temporal protection" if ///
    suppression_status == "secondary" & temporal_panel == 1
replace protection_route = "All-sex temporal equation protection" if ///
    suppression_status == "secondary" & allsex_temporal_panel == 1
replace protection_route = "Five-year comparator includes protected count" if ///
    suppression_status == "secondary" & comp_has_protected_component == 1
replace protection_route = "Annual percentage derived from protected count" if ///
    suppression_status == "secondary" & ///
    inlist(statistic, "sex_distribution", "event_type_distribution", ///
        "age_distribution")
replace protection_route = "Sex-total reconstruction protection" if ///
    suppression_status == "secondary" & protection_route == "" & ///
    observed_count & inlist(sex, "female", "male")
replace protection_route = "Additive event or age reconstruction protection" if ///
    suppression_status == "secondary" & protection_route == ""
replace protection_route = "Not protected" if protection_route == ""

preserve
    keep if suppression_status != "none"
    keep release_id metric_id period_type period period_year period_month ///
        period_quarter case_definition event_type sex age_group statistic ///
        value unit numerator denominator comparison_n primary_suppression ///
        related_primary_cells related_suppression_review suppression_reason ///
        suppression_status protection_route disclosure_note
    order release_id metric_id period_type period period_year period_month ///
        period_quarter case_definition event_type sex age_group statistic ///
        value unit numerator denominator comparison_n primary_suppression ///
        related_primary_cells related_suppression_review suppression_reason ///
        suppression_status protection_route disclosure_note
    sort period_year period_type period_month period_quarter case_definition ///
        event_type sex age_group statistic
    tempfile private_suppression_review
    save `private_suppression_review', replace
restore

* This explicit acceptance check is retained before helper fields are dropped.
* It proves that every required quarterly or annual equation-closure cell is
* protected. A failure stops the run rather than allowing a reviewer to make a
* manual correction to a generated output.
quietly count if temporal_panel == 1 & observed_count & ///
    suppression_status == "none"
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A required temporal equation-closure cell remains visible."
}
quietly count if allsex_temporal_panel == 1 & observed_count & ///
    suppression_status == "none"
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A required all-sex temporal equation-closure cell remains visible."
}
quietly count if (temporal_panel == 1 | allsex_temporal_panel == 1) & ///
    observed_count
local temporal_panel_rows = r(N)

* display_value is the safe field for a dashboard, table or workbook. The
* asterisk follows the existing CVD dashboard convention. Consumers must use
* suppression_status rather than treating every missing value as suppression.
generate str24 display_value = ""
replace display_value = strtrim(string(value, "%18.8g")) if ///
    suppression_status == "none" & !missing(value)
replace display_value = "*" if suppression_status != "none"

* Remove the exact result and its supporting numeric fields from every
* protected row. The row itself remains so the public product retains its
* expected structure and can explain why the result is unavailable.
replace value = . if suppression_status != "none"
replace numerator = . if suppression_status != "none"
replace denominator = . if suppression_status != "none"
replace comparison_n = . if suppression_status != "none"

* Helper fields above are deliberately private calculation scaffolding. They
* are removed before the review candidate is saved so the public payload keeps
* its stable, documented column contract.
drop candidate_row primary_protection secondary_protection observed_count ///
    female_primary male_primary all_primary any_female_primary ///
    any_male_primary any_all_primary heart_primary stroke_primary ///
    cvd_primary any_heart_primary any_stroke_primary any_cvd_primary ///
    under_primary age70_primary any_under_primary any_age70_primary ///
    protected_annual_count event_has_protected_annual_count ///
    event_distribution_protected age_distribution_protected audit_hidden ///
    comp_has_protected_component temporal_panel allsex_temporal_panel ///
    protection_route

order value display_value unit numerator denominator comparison_n, after(statistic)
sort metric_id period_type period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic

label variable display_value ///
    "Public display value; * means suppressed"
label variable suppression_status ///
    "Disclosure-control status"
label variable disclosure_note ///
    "Plain-language disclosure-control explanation"
label data "BNR mortality burden: disclosure-controlled Step 4 review candidate"

notes _dta: private_review_candidate: not approved and not published
notes _dta: observable_contract: use suppression_status; do not infer suppression from missing value
notes _dta: suppressed_fields: value numerator denominator comparison_n

quietly count
local candidate_rows = r(N)
quietly count if suppression_status == "primary"
local candidate_primary_rows = r(N)
quietly count if suppression_status == "secondary"
local candidate_secondary_rows = r(N)
quietly count if suppression_status != "none"
local candidate_suppressed_rows = r(N)

if `candidate_rows' >= `metric_rows' | ///
        `candidate_primary_rows' != `public_primary_source_rows' {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The public candidate does not match the approved restricted monthly scope."
}

quietly count if period_type == "monthly" & ///
    (event_type != "all_cvd" | sex != "all" | age_group != "all" | ///
     statistic != "monthly_count")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The public candidate contains a monthly row outside the approved all-CVD, both-sex, all-age count scope."
}

capture isid metric_id period_type period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic, missok
if _rc {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The review candidate is not unique at the required metric grain."
}

quietly count if !inlist(suppression_status, "none", "primary", "secondary")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "The review candidate contains an unrecognised suppression status."
}

quietly count if suppression_status != "none" & ///
    (!missing(value) | !missing(numerator) | !missing(denominator) | ///
    !missing(comparison_n))
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A suppressed candidate row retains an exact numeric result or supporting count."
}

quietly count if suppression_status != "none" & display_value != "*"
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A suppressed candidate row does not contain the suppression marker."
}

quietly count if suppression_status == "none" & ///
    status_flag != "insufficient_history" & ///
    (missing(value) | display_value == "*" | display_value == "")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "An unrestricted candidate row has lost its value or display value."
}

quietly count if suppression_status == "none" & ///
    status_flag == "insufficient_history" & ///
    (!missing(value) | display_value != "")
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "An insufficient-history row contains a numeric or display value."
}

quietly count if missing(disclosure_note) | strtrim(disclosure_note) == ""
if r(N) {
    _bnr_mort_s4_fail 459 "`release_id'" `"`private_log'"' ///
        "A review-candidate row has no disclosure-control explanation."
}

save `"`review_candidate'"', replace

* ==============================================================================
* 8. CREATE MACHINE-READABLE STEP 4 QA -- DO NOT EDIT
* ==============================================================================
tempfile review_qa_dta
tempname qa_handle
postfile `qa_handle' str40 check str8 result str244 detail ///
    using `review_qa_dta', replace
post `qa_handle' ("complete_step3_package") ("PASS") ///
    ("All nine required private Step 3 package files were found.")
post `qa_handle' ("release_and_current_match") ("PASS") ///
    ("Release-stamped and current DTA/CSV files are byte-identical.")
post `qa_handle' ("metric_schema_and_grain") ("PASS") ///
    ("Required variables found; `metric_rows' rows are unique at the required metric grain.")
post `qa_handle' ("release_period") ("PASS") ///
    ("Release `release_id'; complete annual, quarterly and monthly lattice `analysis_start_year' to `analysis_end_year'.")
post `qa_handle' ("definitions") ("PASS") ///
    ("Primary uses cvd_prim/cvd_sub_p; Upper uses cvd_incl/cvd_sub_i; the lower bound is not included.")
post `qa_handle' ("dashboard_lattice") ("PASS") ///
    ("Each definition has 93 rows in 2010 and 140 in later years; monthly rolling means are intentionally absent; total rows: `metric_rows'.")
post `qa_handle' ("count_reconciliation") ("PASS") ///
    ("`count_rows' count/comparator rows; sex, event and subannual totals reconcile.")
post `qa_handle' ("distribution_reconciliation") ("PASS") ///
    ("`distribution_rows' annual event-type, sex and age distribution rows reconcile.")
post `qa_handle' ("step3_qa_receipt") ("PASS") ///
    ("All `step3_qa_rows' Step 3 QA checks passed.")
post `qa_handle' ("metadata_contract") ("PASS") ///
    ("Release, period, definitions, row counts and workflow boundary match the metric data.")
post `qa_handle' ("monthly_reference_candidate") ("PASS") ///
    ("Fixed 2015-2019 reference has 24 scenario-month rows, five contributing years per row and no protected supporting count.")
post `qa_handle' ("disclosure_control") ("PASS") ///
    ("Primary flags: `primary_suppression_rows'; Step 3 worklist rows: `suppression_review_rows'; complementary suppression is applied in the Step 4 candidate.")
post `qa_handle' ("temporal_differencing") ("PASS") ///
    ("`temporal_panel_rows' minimum temporal cells; `equation_audit_rows' published equations checked; 0 reconstructable protected counts.")
post `qa_handle' ("review_candidate_structure") ("PASS") ///
    ("Candidate has `candidate_rows' rows at the required unique grain; monthly rows are all-CVD, both sexes and all ages only.")
post `qa_handle' ("review_candidate_suppression") ("PASS") ///
    ("Protected rows: `candidate_suppressed_rows' (`candidate_primary_rows' primary; `candidate_secondary_rows' secondary); exact numeric fields removed and display marker applied.")
post `qa_handle' ("publication_boundary") ("PASS") ///
    ("Step 4 creates a private review candidate and review materials only; no approval, public_ready package or public output.")
postclose `qa_handle'

use `review_qa_dta', clear
quietly count
local step4_qa_rows = r(N)
export delimited using `"`review_qa_csv'"', replace

* ==============================================================================
* 9. FINGERPRINT THE EXACT FILES REVIEWED -- DO NOT EDIT
* ==============================================================================
tempfile review_basis_dta
tempname basis_handle
postfile `basis_handle' str36 file_role str244 file_path ///
    double file_size double checksum using `review_basis_dta', replace

quietly checksum `"`release_dta'"'
post `basis_handle' ("release_metric_dta") (`"`release_dta'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`release_csv'"'
post `basis_handle' ("release_metric_csv") (`"`release_csv'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`current_dta'"'
post `basis_handle' ("current_metric_dta") (`"`current_dta'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`current_csv'"'
post `basis_handle' ("current_metric_csv") (`"`current_csv'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`package_metadata'"'
post `basis_handle' ("step3_package_metadata") (`"`package_metadata'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`step3_qa'"'
post `basis_handle' ("step3_qa_receipt") (`"`step3_qa'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`suppression_csv'"'
post `basis_handle' ("step3_suppression_csv") (`"`suppression_csv'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`suppression_xlsx'"'
post `basis_handle' ("step3_suppression_xlsx") (`"`suppression_xlsx'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`package_readme'"'
post `basis_handle' ("step3_readme") (`"`package_readme'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`reference_dta'"'
post `basis_handle' ("monthly_reference_dta") (`"`reference_dta'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`reference_csv'"'
post `basis_handle' ("monthly_reference_csv") (`"`reference_csv'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`reference_yml'"'
post `basis_handle' ("monthly_reference_metadata") (`"`reference_yml'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`review_candidate'"'
post `basis_handle' ("reviewed_public_candidate") (`"`review_candidate'"') ///
    (r(filelen)) (r(checksum))
quietly checksum `"`review_qa_csv'"'
post `basis_handle' ("step4_qa_receipt") (`"`review_qa_csv'"') ///
    (r(filelen)) (r(checksum))
postclose `basis_handle'

use `review_basis_dta', clear
format file_size checksum %20.0f
export delimited using `"`review_basis_csv'"', replace

* ==============================================================================
* 10. CREATE THE CONCISE PRIVATE HUMAN-REVIEW WORKBOOK -- DO NOT EDIT
* ==============================================================================
clear
set obs 22
generate str36 review_item = ""
generate str244 detail = ""
replace review_item = "Review status" in 1
replace detail = "READY FOR HUMAN REVIEW" in 1
replace review_item = "Package" in 2
replace detail = "`package_id'" in 2
replace review_item = "Release" in 3
replace detail = "`release_id'" in 3
replace review_item = "Analysis period" in 4
replace detail = "`analysis_start_year' to `analysis_end_year'" in 4
replace review_item = "Case definitions" in 5
replace detail = "Primary: Clear plus Likely; Upper: Clear plus Likely plus Possible. The lower bound is not included." in 5
replace review_item = "Event definitions" in 6
replace detail = "Primary uses cvd_prim/cvd_sub_p; Upper uses cvd_incl/cvd_sub_i. Heart and Stroke are resolved reporting families." in 6
replace review_item = "All-CVD deaths" in 7
replace detail = "Primary: `cvd_deaths'; Upper: `upper_cvd_deaths' across all reviewed years" in 7
replace review_item = "BNR-Heart deaths" in 8
replace detail = "Primary: `heart_deaths'; Upper: `upper_heart_deaths' across all reviewed years" in 8
replace review_item = "BNR-Stroke deaths" in 9
replace detail = "Primary: `stroke_deaths'; Upper: `upper_stroke_deaths' across all reviewed years" in 9
replace review_item = "Reporting lattice" in 10
replace detail = "Private Step 3: `annual_rows' annual; `quarterly_rows' quarterly; `monthly_rows' monthly rows. Public monthly candidate: all-CVD, both sexes, all ages only." in 10
replace review_item = "Metric rows" in 11
replace detail = "`metric_rows' (`count_rows' count/comparator; `distribution_rows' distribution)" in 11
replace review_item = "Primary suppression flags" in 12
replace detail = "`primary_suppression_rows'" in 12
replace review_item = "Step 3 worklist rows" in 13
replace detail = "`suppression_review_rows'" in 13
replace review_item = "Candidate suppressed rows" in 14
replace detail = "`candidate_suppressed_rows' (`candidate_primary_rows' primary; `candidate_secondary_rows' secondary)" in 14
replace review_item = "Step 3 QA checks" in 15
replace detail = "`step3_qa_rows' passed" in 15
replace review_item = "Step 4 QA checks" in 16
replace detail = "`step4_qa_rows' passed" in 16
replace review_item = "Private suppression review" in 17
replace detail = "Use Suppression review for exact private values and plain-language protection routes. Do not publish or copy this sheet." in 17
replace review_item = "Public candidate check" in 18
replace detail = "Compare protected rows with Public candidate: exact numeric fields are blank and display_value is *. insufficient_history is not suppression." in 18
replace review_item = "Workflow boundary" in 19
replace detail = "Private review only: no approval, public_ready, promotion, publication or mortality rates." in 19
replace review_item = "If review finds a problem" in 20
replace detail = "Do not edit generated files. Correct the source or code, rerun Step 3, then rerun Step 4." in 20
replace review_item = "Approval status" in 21
replace detail = "Not approved. Step 5 remains the separate, deliberate human approval action." in 21
replace review_item = "Monthly historical reference" in 22
replace detail = "Review Monthly reference: fixed 2015-2019 same-calendar-month minimum, maximum and mean for both mortality scenarios. This initial candidate is approved once, then checksum-verified in future releases." in 22
export excel using `"`review_workbook'"', ///
    sheet("Review summary") firstrow(variables) replace

clear
set obs 11
generate str28 definition_item = ""
generate str244 definition = ""
replace definition_item = "MORT-BURDEN-001" in 1
replace definition = "Observed death counts; quarterly and annual include same-period prior-five-year means. Monthly rolling means are not included." in 1
replace definition_item = "MORT-BURDEN-002" in 2
replace definition = "Annual event-type, sex and age percentage distributions." in 2
replace definition_item = "Primary scenario" in 3
replace definition = "Clear plus Likely Step 2 classification: cvd_prim with cvd_sub_p reporting family." in 3
replace definition_item = "Upper scenario" in 4
replace definition = "Clear plus Likely plus Possible Step 2 classification: cvd_incl with cvd_sub_i reporting family. No lower scenario is included." in 4
replace definition_item = "All-CVD" in 5
replace definition = "Each included death is counted once within its selected scenario." in 5
replace definition_item = "Heart and Stroke" in 6
replace definition = "Mutually exclusive resolved reporting families within the selected all-CVD scenario." in 6
replace definition_item = "Sex" in 7
replace definition = "All, female and male; Step 3 excludes unknown-sex records from this reporting lattice." in 7
replace definition_item = "Age" in 8
replace definition = "Annual all-CVD only: all ages, under 70, and 70 years or older; known age for age-specific rows." in 8
replace definition_item = "Reporting periods" in 9
replace definition = "Annual and quarterly: all-CVD, Heart and Stroke. Public monthly candidate: all-CVD, both sexes and all ages only. Private Step 3 retains monthly sex detail for QA." in 9
replace definition_item = "Disclosure control" in 10
replace definition = "Counts 1 to 5 receive primary suppression; sex-total and additive reconstruction protection, plus linked derived values, receive secondary suppression." in 10
replace definition_item = "Rates" in 11
replace definition = "Population denominators and mortality rates are outside this package." in 11
export excel using `"`review_workbook'"', ///
    sheet("Definitions") firstrow(variables) sheetmodify

import delimited using `"`step3_qa'"', varnames(1) stringcols(_all) clear
generate str8 stage = "Step 3"
tempfile combined_qa
save `combined_qa'
use `review_qa_dta', clear
generate str8 stage = "Step 4"
append using `combined_qa'
order stage check result detail
export excel using `"`review_workbook'"', ///
    sheet("QA") firstrow(variables) sheetmodify

use `"`release_dta'"', clear
keep if period_type == "annual"
keep metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value unit numerator ///
    denominator comparison_n status_flag case_definition ///
    suppression_review suppression_reason
order metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value unit numerator ///
    denominator comparison_n status_flag case_definition ///
    suppression_review suppression_reason
sort period_year metric_id case_definition event_type sex age_group statistic
export excel using `"`review_workbook'"', ///
    sheet("Annual metrics") firstrow(variables) sheetmodify

use `"`release_dta'"', clear
keep if period_type == "quarterly"
keep metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value unit numerator ///
    denominator comparison_n status_flag case_definition ///
    suppression_review suppression_reason
order metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value unit numerator ///
    denominator comparison_n status_flag case_definition ///
    suppression_review suppression_reason
sort period_year period_quarter case_definition event_type sex statistic
export excel using `"`review_workbook'"', ///
    sheet("Quarterly metrics") firstrow(variables) sheetmodify

use `"`release_dta'"', clear
keep if period_type == "monthly"
keep metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value unit numerator ///
    denominator comparison_n status_flag case_definition ///
    suppression_review suppression_reason
order metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value unit numerator ///
    denominator comparison_n status_flag case_definition ///
    suppression_review suppression_reason
sort period_year period_month case_definition sex statistic
export excel using `"`review_workbook'"', ///
    sheet("Monthly metrics") firstrow(variables) sheetmodify

* The fixed reference is shown in its own short sheet so that the reviewer can
* check all 24 scenario-month values without coding or filtering a large table.
use `"`reference_dta'"', clear
sort case_definition period_month
export excel using `"`review_workbook'"', ///
    sheet("Monthly reference") firstrow(variables) sheetmodify

* This is the actual disclosure-controlled dataset proposed for approval.
* Suppressed exact values are absent. The private sheets above remain available
* so the analyst can compare the proposed public presentation with its source.
use `"`review_candidate'"', clear
keep metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value display_value ///
    unit numerator denominator comparison_n status_flag case_definition ///
    suppression_status disclosure_note
* keep retains the source dataset's variable order. State the intended review
* order explicitly so the formatting block below always addresses the same
* columns, even if the Step 3 dataset order changes in future.
order metric_id release_id period_type period period_year period_month ///
    period_quarter event_type sex age_group statistic value display_value ///
    unit numerator denominator comparison_n status_flag case_definition ///
    suppression_status disclosure_note
sort period_year period_type period_month period_quarter ///
    metric_id case_definition event_type sex age_group statistic
export excel using `"`review_workbook'"', ///
    sheet("Public candidate") firstrow(variables) sheetmodify

* The workbook must show the COMPLETE Step 4 protection set, including exact
* private values and the fixed protection route. This extract was made before
* the candidate values were blanked, and is never used as public output.
use `private_suppression_review', clear
quietly count
if r(N) > 0 {
    export excel using `"`review_workbook'"', ///
        sheet("Suppression review") firstrow(variables) sheetmodify
}
else {
    clear
    set obs 1
    generate str20 review_status = "PASS"
    generate str244 review_message = ///
        "No primary or secondary suppression rows were identified in the Step 4 candidate."
    export excel using `"`review_workbook'"', ///
        sheet("Suppression review") firstrow(variables) sheetmodify
}

use `metadata_lines', clear
export excel using `"`review_workbook'"', ///
    sheet("Metadata") firstrow(variables) sheetmodify

use `review_basis_dta', clear
format file_size checksum %20.0f
quietly count
local review_basis_rows = r(N)
export excel using `"`review_workbook'"', ///
    sheet("Files reviewed") firstrow(variables) sheetmodify

* ------------------------------------------------------------------------------
* SMALL PRESENTATION-HARDENING BLOCK
* ------------------------------------------------------------------------------
* This block changes workbook presentation only. It does not change any value,
* definition, QA result, suppression flag or disclosure-control decision.
*
* The first row is kept visible with a worksheet split. Column headers are made
* bold with a bottom border. Long narrative cells are wrapped, and numeric
* metric columns receive simple review-friendly number formats.
*
* These commands deliberately use plain, repeated putexcel statements. This is
* longer than a loop, but easier for a mixed-experience BNR team to inspect and
* alter one worksheet at a time.

local qa_excel_last_row = `step3_qa_rows' + `step4_qa_rows' + 1
local annual_excel_last_row = `annual_rows' + 1
local quarterly_excel_last_row = `quarterly_rows' + 1
local monthly_excel_last_row = `monthly_rows' + 1
local reference_excel_last_row = `reference_expected_rows' + 1
local candidate_excel_last_row = `candidate_rows' + 1
local suppression_excel_last_row = max(`candidate_suppressed_rows' + 1, 2)
local metadata_excel_last_row = `line_number' + 1
local files_excel_last_row = `review_basis_rows' + 1

putexcel set `"`review_workbook'"', sheet("Review summary") modify
putexcel A1:B1, bold hcenter border(bottom) overwritefmt
putexcel A2:B22, txtwrap top
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Definitions") modify
putexcel A1:B1, bold hcenter border(bottom) overwritefmt
putexcel A2:B11, txtwrap top
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("QA") modify
putexcel A1:D1, bold hcenter border(bottom) overwritefmt
putexcel B2:D`qa_excel_last_row', txtwrap top
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Annual metrics") modify
putexcel A1:T1, bold hcenter border(bottom) txtwrap overwritefmt
putexcel L2:L`annual_excel_last_row', nformat("#,##0.########")
putexcel N2:O`annual_excel_last_row', nformat(number_sep)
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Quarterly metrics") modify
putexcel A1:T1, bold hcenter border(bottom) txtwrap overwritefmt
putexcel L2:L`quarterly_excel_last_row', nformat("#,##0.########")
putexcel N2:O`quarterly_excel_last_row', nformat(number_sep)
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Monthly metrics") modify
putexcel A1:T1, bold hcenter border(bottom) txtwrap overwritefmt
putexcel L2:L`monthly_excel_last_row', nformat("#,##0.########")
putexcel N2:O`monthly_excel_last_row', nformat(number_sep)
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Monthly reference") modify
putexcel A1:N1, bold hcenter border(bottom) txtwrap overwritefmt
putexcel G2:L`reference_excel_last_row', nformat("#,##0.########")
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Public candidate") modify
putexcel A1:U1, bold hcenter border(bottom) txtwrap overwritefmt
putexcel L2:L`candidate_excel_last_row', nformat("#,##0.########")
putexcel O2:P`candidate_excel_last_row', nformat(number_sep)
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Suppression review") modify
putexcel A1:X1, bold hcenter border(bottom) txtwrap overwritefmt
putexcel M2:M`suppression_excel_last_row', nformat("#,##0.########")
putexcel O2:Q`suppression_excel_last_row', nformat(number_sep)
putexcel A2:X`suppression_excel_last_row', top
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Metadata") modify
putexcel A1:B1, bold hcenter border(bottom) overwritefmt
putexcel A2:B`metadata_excel_last_row', txtwrap top
putexcel sheetset, split(1)

putexcel set `"`review_workbook'"', sheet("Files reviewed") modify
putexcel A1:D1, bold hcenter border(bottom) overwritefmt
putexcel B2:B`files_excel_last_row', txtwrap top
putexcel C2:D`files_excel_last_row', nformat(number_sep)
putexcel sheetset, split(1)

* ------------------------------------------------------------------------------
* EXPLICIT COLUMN WIDTHS -- FORMATTING ONLY; DO NOT EDIT ROUTINELY
* ------------------------------------------------------------------------------
* putexcel handles values, number formats, wrapping, borders and frozen rows,
* but it does not provide a command for setting Excel column widths.
*
* Stata's own documented xl() workbook class does provide that one missing
* formatting function. The short Mata block below therefore has one tightly
* bounded responsibility: set readable widths in the completed review workbook.
*
* IMPORTANT:
*   - It performs no statistical calculation.
*   - It does not alter values, definitions, QA checks or suppression flags.
*   - It does not create approval or public output.
*   - It requires no Python package, Excel macro or external application.
*
* Widths are written out explicitly, sheet by sheet. This is intentionally
* longer than a loop so that the BNR team can see and adjust one column at a
* time if the workbook structure is deliberately changed in future.

mata:
void bnr_mort_s4_set_column_widths(string scalar workbook_path)
{
    class xl scalar workbook

    workbook = xl()
    workbook.load_book(workbook_path)
    workbook.set_mode("open")

    /* Review summary: short item label plus longer explanation. */
    workbook.set_sheet("Review summary")
    workbook.set_column_width(1, 1, 28)
    workbook.set_column_width(2, 2, 85)
    workbook.set_row_height(1, 1, 24)

    /* Definitions: definition name plus full explanatory wording. */
    workbook.set_sheet("Definitions")
    workbook.set_column_width(1, 1, 28)
    workbook.set_column_width(2, 2, 85)
    workbook.set_row_height(1, 1, 24)

    /* QA: stage, check, result and evidence/detail. */
    workbook.set_sheet("QA")
    workbook.set_column_width(1, 1, 12)
    workbook.set_column_width(2, 2, 38)
    workbook.set_column_width(3, 3, 12)
    workbook.set_column_width(4, 4, 85)
    workbook.set_row_height(1, 1, 30)

    /* Annual metrics: full dashboard dimensions and review fields. */
    workbook.set_sheet("Annual metrics")
    workbook.set_column_width(1, 2, 20)
    workbook.set_column_width(3, 4, 14)
    workbook.set_column_width(5, 7, 12)
    workbook.set_column_width(8, 10, 16)
    workbook.set_column_width(11, 11, 42)
    workbook.set_column_width(12, 17, 14)
    workbook.set_column_width(18, 18, 24)
    workbook.set_column_width(19, 19, 18)
    workbook.set_column_width(20, 20, 46)
    workbook.set_row_height(1, 1, 42)

    /* Quarterly metrics: same stable exported column contract. */
    workbook.set_sheet("Quarterly metrics")
    workbook.set_column_width(1, 2, 20)
    workbook.set_column_width(3, 4, 14)
    workbook.set_column_width(5, 7, 12)
    workbook.set_column_width(8, 10, 16)
    workbook.set_column_width(11, 11, 42)
    workbook.set_column_width(12, 17, 14)
    workbook.set_column_width(18, 18, 24)
    workbook.set_column_width(19, 19, 18)
    workbook.set_column_width(20, 20, 46)
    workbook.set_row_height(1, 1, 42)

    /* Monthly metrics: same stable exported column contract. */
    workbook.set_sheet("Monthly metrics")
    workbook.set_column_width(1, 2, 20)
    workbook.set_column_width(3, 4, 14)
    workbook.set_column_width(5, 7, 12)
    workbook.set_column_width(8, 10, 16)
    workbook.set_column_width(11, 11, 42)
    workbook.set_column_width(12, 17, 14)
    workbook.set_column_width(18, 18, 24)
    workbook.set_column_width(19, 19, 18)
    workbook.set_column_width(20, 20, 46)
    workbook.set_row_height(1, 1, 42)

    /* Monthly reference: fixed 2015-2019 values reviewed before approval. */
    workbook.set_sheet("Monthly reference")
    workbook.set_column_width(1, 1, 40)
    workbook.set_column_width(2, 5, 22)
    workbook.set_column_width(6, 10, 16)
    workbook.set_column_width(11, 12, 20)
    workbook.set_column_width(13, 13, 20)
    workbook.set_column_width(14, 14, 72)
    workbook.set_row_height(1, 1, 42)

    /* Public candidate: exact protected values absent; status and note clear. */
    workbook.set_sheet("Public candidate")
    workbook.set_column_width(1, 2, 20)
    workbook.set_column_width(3, 4, 14)
    workbook.set_column_width(5, 7, 12)
    workbook.set_column_width(8, 10, 16)
    workbook.set_column_width(11, 11, 42)
    workbook.set_column_width(12, 18, 14)
    workbook.set_column_width(19, 19, 24)
    workbook.set_column_width(20, 20, 20)
    workbook.set_column_width(21, 21, 90)
    workbook.set_row_height(1, 1, 42)

    /* Suppression review: exact private values and protection route; never publish. */
    workbook.set_sheet("Suppression review")
    workbook.set_column_width(1, 2, 20)
    workbook.set_column_width(3, 4, 14)
    workbook.set_column_width(5, 7, 12)
    workbook.set_column_width(8, 11, 16)
    workbook.set_column_width(12, 12, 42)
    workbook.set_column_width(13, 13, 14)
    workbook.set_column_width(14, 14, 12)
    workbook.set_column_width(15, 17, 14)
    workbook.set_column_width(18, 20, 14)
    workbook.set_column_width(21, 21, 42)
    workbook.set_column_width(22, 22, 14)
    workbook.set_column_width(23, 23, 48)
    workbook.set_column_width(24, 24, 90)
    workbook.set_row_height(1, 1, 42)

    /* Metadata: line number plus the complete metadata statement. */
    workbook.set_sheet("Metadata")
    workbook.set_column_width(1, 1, 14)
    workbook.set_column_width(2, 2, 110)
    workbook.set_row_height(1, 1, 24)

    /* Review basis: role, exact private path, byte size and checksum. */
    workbook.set_sheet("Files reviewed")
    workbook.set_column_width(1, 1, 30)
    workbook.set_column_width(2, 2, 110)
    workbook.set_column_width(3, 3, 18)
    workbook.set_column_width(4, 4, 20)
    workbook.set_row_height(1, 1, 30)

    workbook.close_book()
}
end

capture mata: bnr_mort_s4_set_column_widths(st_local("review_workbook"))
if _rc {
    local width_rc = _rc
    _bnr_mort_s4_fail `width_rc' "`release_id'" `"`private_log'"' ///
        "The review workbook was created, but explicit column-width formatting failed."
}
capture mata: mata drop bnr_mort_s4_set_column_widths()

* ==============================================================================
* 11. CONFIRM STEP 4 OUTPUTS AND REPORT STATUS -- DO NOT EDIT
* ==============================================================================
foreach output_file in ///
        `"`review_candidate'"' ///
        `"`review_workbook'"' ///
        `"`review_qa_csv'"' ///
        `"`review_basis_csv'"' ///
        `"`reference_dta'"' ///
        `"`reference_csv'"' ///
        `"`reference_yml'"' {
    capture confirm file `"`output_file'"'
    if _rc {
        _bnr_mort_s4_fail 603 "`release_id'" `"`private_log'"' ///
            `"Required Step 4 review output was not created: `output_file'"'
    }
}

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "MORTALITY STEP 4: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             READY FOR HUMAN REVIEW"
noisily display as text   "  Script version:         Pass 4 monthly-public-scope and fixed-reference candidate"
noisily display as text   "  Selected release:       `release_id'"
noisily display as text   "  Analysis period:        `analysis_start_year'-`analysis_end_year'"
noisily display as text   "  Metric rows:            `metric_rows'"
noisily display as text   "  Annual rows:            `annual_rows'"
noisily display as text   "  Quarterly rows:         `quarterly_rows'"
noisily display as text   "  Monthly rows:           `monthly_rows'"
noisily display as text   "  All-CVD deaths:         `cvd_deaths'"
noisily display as text   "  BNR-Heart deaths:       `heart_deaths'"
noisily display as text   "  BNR-Stroke deaths:      `stroke_deaths'"
noisily display as text   "  Step 3 worklist rows:   `suppression_review_rows'"
noisily display as text   "  Candidate suppressed:  `candidate_suppressed_rows'"
noisily display as text   "  Temporal panel rows:    `temporal_panel_rows'"
noisily display as text   "  Monthly reference:      2015-2019; 24 scenario-month rows"
noisily display as text   `"  OPEN THIS FILE FIRST:   `review_workbook'"'
noisily display as text   `"  Reviewed candidate:     `review_candidate'"'
noisily display as text   `"  Step 4 QA:              `review_qa_csv'"'
noisily display as text   `"  Review basis:           `review_basis_csv'"'
noisily display as text   `"  Reference candidate:    `reference_dta'"'
noisily display as text   `"  Private log:            `private_log'"'
noisily display as text   "  Approval/public output: NOT CREATED"
noisily display as text   "  Next step:              Complete the human review, then run Step 5 approval."
noisily display as result "============================================================================="

}

quietly log close mort_s4
capture program drop _bnr_mort_s4_fail

/*
===============================================================================
 DO-FILE:     bnr_mort_s3_stage.do
 VERSION:     Pass 4 monthly-public-scope and fixed-reference candidate
              (21 August 2026)
 PURPOSE:     Validate and package a private Step 3 mortality burden release.

 Called only by bnr_mort_s3_burden.do. This file stages exact private values;
 it does not approve, promote, publish or create website files.
===============================================================================
*/

version 19
set more off

args calculation_dta qa_dta release_id source_dataset package_dir replace_mode ///
    release_year release_month analysis_start_year analysis_end_year

if `"`calculation_dta'"' == "" | `"`qa_dta'"' == "" | ///
        "`release_id'" == "" | `"`source_dataset'"' == "" | ///
        `"`package_dir'"' == "" | "`replace_mode'" == "" | ///
        "`release_year'" == "" | "`release_month'" == "" | ///
        "`analysis_start_year'" == "" | "`analysis_end_year'" == "" {
    display as error "bnr_mort_s3_stage.do received an incomplete staging contract."
    exit 198
}

if !inlist("`replace_mode'", "0", "1") {
    display as error "Staging replace_mode must be 0 or 1."
    exit 198
}

* ==============================================================================
* 1. STANDARD PACKAGE NAMES -- DO NOT EDIT
* ==============================================================================
local datasets_dir "`package_dir'/datasets"
local metadata_dir "`package_dir'/metadata"
local review_dir "`package_dir'/review"
local release_name "mort_burden_metrics_`release_id'"
local current_name "mort_burden_metrics_current"
local qa_name "mort_burden_qa_`release_id'"

local release_dta "`datasets_dir'/`release_name'.dta"
local release_csv "`datasets_dir'/`release_name'.csv"
local current_dta "`datasets_dir'/`current_name'.dta"
local current_csv "`datasets_dir'/`current_name'.csv"
local metadata_yml "`metadata_dir'/mort_burden_package.yml"
local qa_csv "`review_dir'/`qa_name'.csv"
local suppression_csv "`review_dir'/mort_burden_suppression_review_`release_id'.csv"
local suppression_xlsx "`review_dir'/mort_burden_suppression_review_`release_id'.xlsx"
local readme "`package_dir'/readme.txt"
local ready_dir "`package_dir'/public_ready"
local ready_data "`ready_dir'/datasets"
local ready_meta "`ready_dir'/metadata"

foreach required_file in `"`calculation_dta'"' `"`qa_dta'"' `"`source_dataset'"' {
    capture confirm file `"`required_file'"'
    if _rc {
        display as error "Required staging input not found: `required_file'"
        exit 601
    }
}

* A deliberate Step 3 replace means the analytical payload is being rebuilt.
* Any earlier Step 5 approval for this release is therefore no longer valid.
* Remove only the known generated public_ready files; stop clearly if an
* unexpected file prevents the folder from being removed.
if "`replace_mode'" == "1" {
    capture erase `"`ready_data'/mort_burden_metrics_`release_id'.dta"'
    capture erase `"`ready_data'/mort_burden_metrics_`release_id'.csv"'
    capture erase `"`ready_data'/mort_burden_metrics_current.dta"'
    capture erase `"`ready_data'/mort_burden_metrics_current.csv"'
    capture erase `"`ready_meta'/mort_burden_metrics_`release_id'.yml"'
    capture erase `"`ready_meta'/mort_burden_metrics_current.yml"'
    capture erase `"`ready_meta'/mort_burden_package.yml"'
    capture erase `"`ready_dir'/public_manifest.csv"'
    capture erase `"`ready_dir'/approval.yml"'
    capture rmdir "`ready_data'"
    capture rmdir "`ready_meta'"
    capture rmdir "`ready_dir'"
    capture confirm file `"`ready_dir'/approval.yml"'
    if !_rc {
        display as error "An earlier public_ready package could not be invalidated. Remove or archive it before rerunning Step 3."
        exit 459
    }
}

* ==============================================================================
* 2. VALIDATE CALCULATED METRICS BEFORE WRITING ANY PACKAGE FILE
* ==============================================================================
use `"`calculation_dta'"', clear

local required_variables metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex age_group case_definition ///
    source_status statistic value unit numerator denominator comparison_n ///
    ci_lower_value ci_upper_value ci_level ci_method ///
    status_flag sdc_policy primary_suppression_threshold ///
    primary_suppression related_primary_cells ///
    related_suppression_review suppression_review suppression_reason

foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "Calculated metric variable is absent: `variable'"
        exit 111
    }
}

quietly count
local metric_rows = r(N)
if `metric_rows' == 0 {
    display as error "The mortality metric dataset contains no rows."
    exit 2000
}

capture isid metric_id period_type period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic, missok
if _rc {
    display as error "Calculated metrics are not unique at the CVD-compatible reporting grain."
    exit 459
}

quietly count if release_id != "`release_id'"
if r(N) {
    display as error "A metric row has a release ID that differs from the package contract."
    exit 459
}

quietly count if !inlist(case_definition, "primary_clear_likely", ///
    "upper_clear_likely_possible")
if r(N) {
    display as error "A metric row has a missing, changed or unrecognised case definition."
    exit 459
}
quietly count if case_definition == "primary_clear_likely"
local primary_definition_rows = r(N)
quietly count if case_definition == "upper_clear_likely_possible"
local upper_definition_rows = r(N)
if `primary_definition_rows' == 0 | ///
        `upper_definition_rows' == 0 | ///
        `primary_definition_rows' != `upper_definition_rows' {
    display as error "Both mortality case definitions must have one complete, equal reporting lattice."
    exit 459
}

quietly count if missing(metric_id) | missing(period_year) | ///
    missing(event_type) | missing(sex) | missing(age_group) | ///
    missing(statistic) | missing(unit) | ///
    (missing(value) & status_flag != "insufficient_history")
if r(N) {
    display as error "A metric row is missing a required reporting value."
    exit 459
}

quietly count if period_year < real("`analysis_start_year'") | ///
    period_year > real("`analysis_end_year'") | period_complete != 1
if r(N) {
    display as error "A metric row falls outside the completed analysis-year contract."
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-001"
local count_rows = r(N)
quietly count if metric_id == "MORT-BURDEN-002"
local distribution_rows = r(N)
quietly count if metric_id == "MORT-RATE-001"
local rate_rows = r(N)
quietly count if !inlist(metric_id, "MORT-BURDEN-001", "MORT-BURDEN-002", "MORT-RATE-001")
if r(N) {
    display as error "The calculated dataset contains an unrecognised metric ID."
    exit 459
}

local expected_years = ///
    real("`analysis_end_year'") - real("`analysis_start_year'") + 1
local expected_count_rows = ///
    (`expected_years' * 11) + ((`expected_years' - 1) * 11) + ///
    (`expected_years' * 12 * 3) + ///
    (`expected_years' * 4 * 9) + ((`expected_years' - 1) * 4 * 9)
local expected_distribution_rows = `expected_years' * 10
local expected_count_rows = 2 * `expected_count_rows'
local expected_distribution_rows = 2 * `expected_distribution_rows'
local expected_rate_rows = `expected_years' * 36

if `count_rows' != `expected_count_rows' | ///
        `distribution_rows' != `expected_distribution_rows' | ///
        `rate_rows' != `expected_rate_rows' {
    display as error "Calculated rows do not match the CVD dashboard reporting lattice."
    exit 459
}

quietly count if period_year < 2010
if r(N) {
    display as error "A pre-2010 row entered the Step 3 mortality package."
    exit 459
}

quietly count if !inlist(event_type, "all_cvd", "heart", "stroke") | ///
    !inlist(sex, "all", "female", "male") | ///
    !inlist(age_group, "all", "under_70", "age_70_plus", "age_standardised")
if r(N) {
    display as error "The calculated dataset contains an invalid reporting dimension."
    exit 459
}

quietly count if primary_suppression == 1
local primary_rows = r(N)
quietly count if suppression_review == 1
local review_rows = r(N)

quietly count if related_primary_cells > 0 & suppression_review != 1
if r(N) {
    display as error "A suppression-related metric row is missing from the review worklist."
    exit 459
}

* These record-level names must never appear in an aggregate metric package.
foreach forbidden_name in pid patient_id registration_id national_id name dob dod {
    capture confirm variable `forbidden_name'
    if !_rc {
        display as error "Record-level identifier found in aggregate output: `forbidden_name'"
        exit 459
    }
}

* ==============================================================================
* 3. VALIDATE THE CALCULATION QA RECEIPT
* ==============================================================================
preserve
    use `"`qa_dta'"', clear
    foreach qa_variable in check result detail {
        capture confirm variable `qa_variable'
        if _rc {
            display as error "Calculation QA variable is absent: `qa_variable'"
            exit 111
        }
    }
    quietly count
    local qa_rows = r(N)
    if `qa_rows' == 0 {
        display as error "The calculation QA receipt contains no checks."
        exit 2000
    }

    capture isid check
    if _rc {
        display as error "Calculation QA check names are missing or duplicated."
        exit 459
    }

    * Require every named check in the hardened Step 3 calculation contract.
    * This prevents an accidentally shortened QA receipt from being accepted.
    local required_qa_checks required_step2_variables source_and_cohort_rows ///
        website_analysis_period date_reconciliation ///
        combined_primary_definition component_definition_comparison ///
        resolved_family cvd_dashboard_lattice metric_grain_and_rows ///
        metric_reconciliation sex_and_event_reconciliation ///
        cross_frequency_reconciliation comparator_history ///
        suppression_worklist annual_mortality_rates
    foreach required_qa_check of local required_qa_checks {
        quietly count if check == "`required_qa_check'"
        if r(N) != 1 {
            display as error ///
                "Required calculation QA check is absent: `required_qa_check'"
            exit 459
        }
    }

    quietly count if result != "PASS"
    if r(N) {
        display as error "At least one calculation QA check did not pass."
        exit 459
    }
restore

* No package file is created until all calculated-data and QA checks above pass.
capture mkdir "`package_dir'"
capture mkdir "`datasets_dir'"
capture mkdir "`metadata_dir'"
capture mkdir "`review_dir'"

* ==============================================================================
* 4. WRITE RELEASE-STAMPED AND CURRENT PRIVATE DATASETS
* ==============================================================================
if "`replace_mode'" == "1" {
    save `"`release_dta'"', replace
    export delimited using `"`release_csv'"', replace
}
else {
    save `"`release_dta'"'
    export delimited using `"`release_csv'"'
}

* The current files are a disposable pointer within this private package. They
* are always refreshed from the release-stamped files after successful checks.
copy `"`release_dta'"' `"`current_dta'"', replace
copy `"`release_csv'"' `"`current_csv'"', replace

* The current files must be exact byte-for-byte copies of the release-stamped
* files. Later workflow steps can therefore use either name without ambiguity.
quietly checksum `"`release_dta'"'
local release_dta_size = r(filelen)
local release_dta_checksum = r(checksum)
quietly checksum `"`current_dta'"'
local current_dta_size = r(filelen)
local current_dta_checksum = r(checksum)
if `release_dta_size' != `current_dta_size' | ///
        `release_dta_checksum' != `current_dta_checksum' {
    display as error "The current DTA is not an exact copy of the release DTA."
    exit 459
}

quietly checksum `"`release_csv'"'
local release_csv_size = r(filelen)
local release_csv_checksum = r(checksum)
quietly checksum `"`current_csv'"'
local current_csv_size = r(filelen)
local current_csv_checksum = r(checksum)
if `release_csv_size' != `current_csv_size' | ///
        `release_csv_checksum' != `current_csv_checksum' {
    display as error "The current CSV is not an exact copy of the release CSV."
    exit 459
}

* ==============================================================================
* 5. WRITE PRIVATE DISCLOSURE-CONTROL REVIEW FILES
* ==============================================================================
preserve
    keep if suppression_review == 1
    keep release_id metric_id period_type period period_year period_month ///
        period_quarter case_definition event_type sex age_group statistic ///
        value unit numerator denominator primary_suppression ///
        related_primary_cells related_suppression_review suppression_reason
    order release_id metric_id period_type period period_year period_month ///
        period_quarter case_definition event_type sex age_group statistic ///
        value unit numerator denominator primary_suppression ///
        related_primary_cells related_suppression_review suppression_reason
    sort metric_id period_year period_month period_quarter ///
        case_definition event_type sex age_group statistic
    export delimited using `"`suppression_csv'"', replace

    if `review_rows' > 0 {
        export excel using `"`suppression_xlsx'"', ///
            sheet("Suppression worklist") firstrow(variables) replace
    }
    else {
        clear
        set obs 1
        generate str20 review_status = "PASS"
        generate str244 review_message = ///
            "No primary or related suppression-review rows were identified in this private staging package."
        generate str20 release_id = "`release_id'"
        generate int analysis_start_year = real("`analysis_start_year'")
        generate int analysis_end_year = real("`analysis_end_year'")
        export excel using `"`suppression_xlsx'"', ///
            sheet("Review status") firstrow(variables) replace
    }
restore

use `"`qa_dta'"', clear
export delimited using `"`qa_csv'"', replace

* ==============================================================================
* 6. WRITE MACHINE-READABLE PACKAGE METADATA
* ==============================================================================
local build_date = string(date(c(current_date), "DMY"), "%tdCCYY-NN-DD")
local build_time "`c(current_time)'"

tempname meta_handle
file open `meta_handle' using `"`metadata_yml'"', write text replace
file write `meta_handle' "schema: bnr_mortality_burden_package_v2" _n
file write `meta_handle' "package_id: mort_burden_`release_id'" _n
file write `meta_handle' "package_status: staging" _n
file write `meta_handle' "workflow_step: 3" _n
file write `meta_handle' "build_version: pass3_dual_definition_candidate" _n
file write `meta_handle' "build_date: `build_date'" _n
file write `meta_handle' "build_time: `build_time'" _n
file write `meta_handle' "release_id: `release_id'" _n
file write `meta_handle' "source_release_year: `release_year'" _n
file write `meta_handle' "source_release_month: `release_month'" _n
file write `meta_handle' "analysis_start_year: `analysis_start_year'" _n
file write `meta_handle' "analysis_end_year: `analysis_end_year'" _n
file write `meta_handle' "case_definitions:" _n
file write `meta_handle' "  - primary_clear_likely" _n
file write `meta_handle' "  - upper_clear_likely_possible" _n
file write `meta_handle' "lower_bound_included: false" _n
file write `meta_handle' "website_analysis_start: 2010-01-01" _n
file write `meta_handle' "event_types:" _n
file write `meta_handle' "  - all_cvd" _n
file write `meta_handle' "  - heart" _n
file write `meta_handle' "  - stroke" _n
file write `meta_handle' "combined_definition_primary: Step 2 cvd_prim" _n
file write `meta_handle' "combined_definition_upper: Step 2 cvd_incl" _n
file write `meta_handle' "resolved_family_primary: Step 2 cvd_sub_p" _n
file write `meta_handle' "resolved_family_upper: Step 2 cvd_sub_i" _n
file write `meta_handle' "reporting_frequencies:" _n
file write `meta_handle' "  - annual" _n
file write `meta_handle' "  - quarterly" _n
file write `meta_handle' "  - monthly" _n
file write `meta_handle' "monthly_rolling_comparator_included: false" _n
file write `meta_handle' "quarterly_annual_rolling_comparators_included: true" _n
file write `meta_handle' "monthly_public_scope: all_cvd_all_sexes_all_ages_only" _n
file write `meta_handle' "monthly_historical_reference: created_and_reviewed_in_step_4" _n
file write `meta_handle' "cvd_dashboard_reporting_scope_aligned: true" _n
file write `meta_handle' "metrics:" _n
file write `meta_handle' "  - MORT-BURDEN-001" _n
file write `meta_handle' "  - MORT-BURDEN-002" _n
file write `meta_handle' "  - MORT-RATE-001" _n
file write `meta_handle' "metric_rows: `metric_rows'" _n
file write `meta_handle' "count_rows: `count_rows'" _n
file write `meta_handle' "distribution_rows: `distribution_rows'" _n
file write `meta_handle' "rate_rows: `rate_rows'" _n
file write `meta_handle' "qa_checks: `qa_rows'" _n
file write `meta_handle' "release_and_current_files_byte_identical: true" _n
file write `meta_handle' "rates_included: true" _n
file write `meta_handle' "rate_unit: rate_per_100000" _n
file write `meta_handle' "rate_forms: crude_and_directly_age_standardised" _n
file write `meta_handle' "rate_population_source: UN_WPP_2024" _n
file write `meta_handle' "rate_standard_population: WHO_WORLD_2000_2025" _n
file write `meta_handle' "rate_ci_methods: poisson_exact_garwood_and_fay_feuer_gamma" _n
file write `meta_handle' "dco_linkage_included: false" _n
file write `meta_handle' "source_dataset: `source_dataset'" _n
file write `meta_handle' "primary_suppression_threshold: 6" _n
file write `meta_handle' "primary_suppression_rows: `primary_rows'" _n
file write `meta_handle' "suppression_review_rows: `review_rows'" _n
file write `meta_handle' "exact_values_retained_in_private_staging: true" _n
file write `meta_handle' "approved: false" _n
file write `meta_handle' "public_ready: false" _n
file write `meta_handle' "publication_boundary: no_public_or_site_files_created" _n
file close `meta_handle'

* ==============================================================================
* 7. WRITE HUMAN-READABLE PACKAGE NOTE
* ==============================================================================
tempname readme_handle
file open `readme_handle' using `"`readme'"', write text replace
file write `readme_handle' "BNR mortality Step 3 private burden staging package" _n
file write `readme_handle' "Step 2 dataset release: `release_year'-`release_month'" _n
file write `readme_handle' "Package release ID: `release_id'" _n
file write `readme_handle' "Analysis years: `analysis_start_year'-`analysis_end_year'" _n _n
file write `readme_handle' "This package is for Step 4 human review only. It is not approved or public." _n
file write `readme_handle' "It contains two BNR-CVD, Heart and Stroke scenarios from January 2010: Primary (Clear + Likely) and Upper bound (Clear + Likely + Possible)." _n
file write `readme_handle' "The lower-bound scenario is deliberately not included." _n
file write `readme_handle' "It follows the CVD dashboard's selective annual, quarterly and monthly reporting lattice." _n
file write `readme_handle' "Annual and quarterly count output includes same-period previous-five-year means. Monthly rolling means are deliberately excluded." _n
file write `readme_handle' "Private monthly output retains combined BNR-CVD all/female/male counts for calculation and QA. Step 4 restricts the public monthly candidate to all-CVD, both sexes and all ages." _n
file write `readme_handle' "Step 4 creates the initial reviewed 2015-2019 monthly historical-reference candidate for the public monthly view." _n
file write `readme_handle' "Annual crude and directly age-standardised mortality-rate rows are included for private Step 4 review. They use the approved private WPP 2024 Barbados population and WHO World Standard assets." _n
file write `readme_handle' "Rates are not approved, public, DCO-linked or calculated by the dashboard." _n
file write `readme_handle' "Exact small values remain visible only inside this private staging package." _n
file write `readme_handle' "Review the QA CSV and suppression worklist before Step 4." _n
file write `readme_handle' "Do not edit generated files manually; correct source or code and rerun." _n
file close `readme_handle'

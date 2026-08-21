/*******************************************************************************
DO-FILE:     bnr_mort_s5_approve.do
VERSION:     Pass 4.1 approved-reference metadata hardening
             (21 August 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Mortality Step 5 - record human approval

PURPOSE:     Record the authorised human approval of the exact mortality
             burden package prepared and reviewed in Step 4.

             A successful run:
             - revalidates the Step 4 public candidate and QA receipt;
             - confirms every file fingerprint recorded by Step 4;
             - creates the private staging/public_ready package;
             - creates release-stamped and current DTA/CSV payloads;
             - creates release, current and package metadata;
             - creates public_manifest.csv;
             - writes approval.yml LAST.

             This do-file DOES NOT:
             - calculate or change mortality metrics;
             - apply or alter suppression;
             - write to the authoritative public area;
             - write to downloads, the website or GitHub;
             - perform Step 6 promotion or publication.

WORKFLOW:    Step 4 public candidate and review workbook
                              |
                       human review
                              |
                              v
                    STEP 5 APPROVAL (this file)
                              |
                              v
              private staging/public_ready package
                              |
                              v
                    Step 6 promotion later

ANALYST-EDITABLE SECTION:
             Analysts supply only:
             - release year and month;
             - approver name;
             - authorised approver role;
             - the five explicit review confirmations.

             Routine paths remain in bnr_paths_LOCAL.do. Generated files must
             never be corrected by hand. If review finds a problem, correct the
             source or version-controlled code and rerun the earlier step.

COMMAND:     do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" ///
                 2026 7 "Full name" "BNR Analyst" ///
                 release definitions disclosure candidate ready

IMPORTANT:   The synthetic 2099 suppression-test release is deliberately
             blocked. It may be reviewed in Step 4 but may never be approved.
*******************************************************************************/

version 19
clear all
set more off

* ==============================================================================
* INTERNAL SUPPORT PROGRAMS -- DO NOT EDIT
* ==============================================================================

capture program drop _bnr_mort_s5_fail
program define _bnr_mort_s5_fail
    version 19
    args return_code release_id private_log reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "MORTALITY STEP 5: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error "  Script version:         Pass 4.1 approved-reference metadata hardening"
    noisily display as error "  Selected release:       `release_id'"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `private_log'"'
    noisily display as text  "  Action required:        Do not approve. Restore the reviewed files or rerun Step 4 and review again."
    noisily display as text  "  Publication boundary:   No public output or website file was created."
    noisily display as error "============================================================================="
    capture log close mort_s5
    exit `return_code'
end

* Write the approval receipt to a temporary file. The controller copies it into
* public_ready only after every other file and the manifest have succeeded.
capture program drop _bnr_mort_s5_write_approval
program define _bnr_mort_s5_write_approval
    version 19
    args approval_path package_id release_id approver_name approver_role ///
        approved_date approved_time manifest_size manifest_checksum

    tempname approval_yml
    file open `approval_yml' using `"`approval_path'"', write text replace
    file write `approval_yml' "schema: bnr_mortality_approval_v1" _n
    file write `approval_yml' "status: approved" _n
    file write `approval_yml' "package_id: `package_id'" _n
    file write `approval_yml' "release_id: `release_id'" _n
    file write `approval_yml' "domain: mortality" _n
    file write `approval_yml' "metric_family: burden" _n
    file write `approval_yml' "workflow_step: 5" _n
    file write `approval_yml' "approved_by: `approver_name'" _n
    file write `approval_yml' "approved_role: `approver_role'" _n
    file write `approval_yml' "approved_date: `approved_date'" _n
    file write `approval_yml' "approved_time: `approved_time'" _n
    file write `approval_yml' "review_standard: bnr_mortality_review_v1" _n
    file write `approval_yml' "disclosure_policy: bnr_sdc_v1" _n
    file write `approval_yml' "disclosure_check: passed" _n
    file write `approval_yml' "confirmations:" _n
    file write `approval_yml' "  release_and_period_reviewed: true" _n
    file write `approval_yml' "  definitions_and_results_reviewed: true" _n
    file write `approval_yml' "  disclosure_control_reviewed: true" _n
    file write `approval_yml' "  candidate_and_workbook_inspected: true" _n
    file write `approval_yml' "  monthly_reference_reviewed: true" _n
    file write `approval_yml' "  publication_readiness_confirmed: true" _n
    file write `approval_yml' "public_ready_manifest: public_manifest.csv" _n
    file write `approval_yml' "payload_root: ." _n
    file write `approval_yml' "manifest_scope: payload_files_only" _n
    file write `approval_yml' "manifest_required_files: 10" _n
    file write `approval_yml' "manifest_size: `manifest_size'" _n
    file write `approval_yml' "manifest_checksum: `manifest_checksum'" _n
    file write `approval_yml' "publication_performed: false" _n
    file write `approval_yml' "promotion_status: pending_step_6" _n
    file close `approval_yml'
end

* ==============================================================================
* 1. ANALYST INPUTS -- EDIT THROUGH THE DIALOG OR COMMAND LINE
* ==============================================================================

local command_line `"`0'"'
gettoken release_year remainder : command_line
gettoken release_month remainder : remainder
gettoken approver_name remainder : remainder
gettoken approver_role remainder : remainder
gettoken confirm_release remainder : remainder
gettoken confirm_definitions remainder : remainder
gettoken confirm_disclosure remainder : remainder
gettoken confirm_candidate remainder : remainder
gettoken confirm_ready remainder : remainder
local remainder : list retokenize remainder

local approver_name = strtrim(`"`approver_name'"')
local approver_role = strtrim(`"`approver_role'"')
local confirm_release = lower(strtrim(`"`confirm_release'"'))
local confirm_definitions = lower(strtrim(`"`confirm_definitions'"'))
local confirm_disclosure = lower(strtrim(`"`confirm_disclosure'"'))
local confirm_candidate = lower(strtrim(`"`confirm_candidate'"'))
local confirm_ready = lower(strtrim(`"`confirm_ready'"'))

if `"`release_year'"' == "" | `"`release_month'"' == "" | ///
        `"`approver_name'"' == "" | `"`approver_role'"' == "" {
    display as error "Release year, release month, approver name and role are required."
    exit 198
}

if `"`remainder'"' != "" {
    display as error "Unexpected text follows the five approval confirmations."
    exit 198
}

if `"`confirm_release'"' != "release" | ///
        `"`confirm_definitions'"' != "definitions" | ///
        `"`confirm_disclosure'"' != "disclosure" | ///
        `"`confirm_candidate'"' != "candidate" | ///
        `"`confirm_ready'"' != "ready" {
    display as error "All five approval confirmations are required."
    display as error "Use the Step 5 dialog and tick every review confirmation."
    exit 198
}

local role_lower = lower(`"`approver_role'"')
if !inlist(`"`role_lower'"', "bnr lead", "bnr analyst", "bnr developer") {
    display as error "Approver role must be BNR Lead, BNR Analyst or BNR Developer."
    exit 198
}
if `"`role_lower'"' == "bnr lead" local approver_role "BNR Lead"
if `"`role_lower'"' == "bnr analyst" local approver_role "BNR Analyst"
if `"`role_lower'"' == "bnr developer" local approver_role "BNR Developer"

* YAML uses the approver name as a plain scalar. Reject the few characters that
* could make that small receipt ambiguous rather than hiding complex escaping.
if strpos(`"`approver_name'"', char(34)) | ///
        strpos(`"`approver_name'"', ":") | ///
        strpos(`"`approver_name'"', "#") {
    display as error "Approver name must not contain a double quote, colon or hash."
    exit 198
}

* ==============================================================================
* 2. PATHS AND RELEASE IDENTITY -- DO NOT EDIT
* ==============================================================================

if `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        display as error "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do."
        exit `config_rc'
    }
}

foreach required_global in BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local year_num = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2024 {
    display as error "Release year must be an integer of 2024 or later."
    exit 198
}
if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Release month must be an integer from 1 to 12."
    exit 198
}

local release_year_4 : display %04.0f `year_num'
local release_month_2 : display %02.0f `month_num'
local release_id "mort_`release_year_4'_`release_month_2'"
local package_id "mort_burden_`release_id'"

local package_dir "$BNR_STAGING/mortality/burden/`release_id'"
local datasets_dir "`package_dir'/datasets"
local metadata_dir "`package_dir'/metadata"
local review_dir "`package_dir'/review"

local release_dta "`datasets_dir'/mort_burden_metrics_`release_id'.dta"
local release_csv "`datasets_dir'/mort_burden_metrics_`release_id'.csv"
local current_dta "`datasets_dir'/mort_burden_metrics_current.dta"
local current_csv "`datasets_dir'/mort_burden_metrics_current.csv"
local package_metadata "`metadata_dir'/mort_burden_package.yml"
local step3_qa "`review_dir'/mort_burden_qa_`release_id'.csv"
local suppression_csv "`review_dir'/mort_burden_suppression_review_`release_id'.csv"
local suppression_xlsx "`review_dir'/mort_burden_suppression_review_`release_id'.xlsx"
local package_readme "`package_dir'/readme.txt"

local review_candidate "`review_dir'/mort_s4_candidate.dta"
local review_workbook "`review_dir'/mort_s4_review_`release_id'.xlsx"
local review_qa "`review_dir'/mort_s4_review_qa_`release_id'.csv"
local review_basis "`review_dir'/mort_s4_review_basis_`release_id'.csv"
local reference_dta "`review_dir'/mort_s4_monthly_reference_2015_2019.dta"
local reference_csv "`review_dir'/mort_s4_monthly_reference_2015_2019.csv"
local reference_yml "`review_dir'/mort_s4_monthly_reference_2015_2019.yml"

local ready_dir "`package_dir'/public_ready"
local ready_data "`ready_dir'/datasets"
local ready_meta "`ready_dir'/metadata"

local public_release_dta "`ready_data'/mort_burden_metrics_`release_id'.dta"
local public_release_csv "`ready_data'/mort_burden_metrics_`release_id'.csv"
local public_current_dta "`ready_data'/mort_burden_metrics_current.dta"
local public_current_csv "`ready_data'/mort_burden_metrics_current.csv"
local public_release_yml "`ready_meta'/mort_burden_metrics_`release_id'.yml"
local public_current_yml "`ready_meta'/mort_burden_metrics_current.yml"
local public_package_yml "`ready_meta'/mort_burden_package.yml"
local public_reference_dta "`ready_data'/mort_monthly_reference_2015_2019.dta"
local public_reference_csv "`ready_data'/mort_monthly_reference_2015_2019.csv"
local public_reference_yml "`ready_meta'/mort_monthly_reference_2015_2019.yml"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"

local private_log "$BNR_PRIVATE_LOGS/bnr_mort_s5_approve_`release_id'.log"

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close mort_s5
log using `"`private_log'"', text replace name(mort_s5)

quietly {

noisily display as text "BNR MORTALITY STEP 5: RECORD HUMAN APPROVAL"
noisily display as result "  Script version:       Pass 4.1 approved-reference metadata hardening"
noisily display as result "  Selected release:     `release_id'"
noisily display as result "  Approver:             `approver_name' (`approver_role')"

* ==============================================================================
* 3. HARD SAFETY BOUNDARIES -- DO NOT EDIT
* ==============================================================================

* The reserved 2099 release exists only to exercise suppression rules.
if "`release_year_4'" == "2099" {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Synthetic mortality test releases may never be approved."
}

capture confirm file `"`package_dir'/SYNTHETIC_TEST_ONLY.txt"'
if !_rc {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "This package is explicitly marked as synthetic test data and may not be approved."
}

* Approval is one-time. A later correction must start by rerunning the earlier
* workflow steps and completing a new human review.
foreach output_file in ///
        `"`approval'"' ///
        `"`manifest'"' ///
        `"`public_release_dta'"' ///
        `"`public_release_csv'"' ///
        `"`public_current_dta'"' ///
        `"`public_current_csv'"' ///
        `"`public_release_yml'"' ///
        `"`public_current_yml'"' ///
        `"`public_package_yml'"' ///
        `"`public_reference_dta'"' ///
        `"`public_reference_csv'"' ///
        `"`public_reference_yml'"' {
    capture confirm file `"`output_file'"'
    if !_rc {
        _bnr_mort_s5_fail 602 "`release_id'" `"`private_log'"' ///
            `"A public-ready or approval file already exists: `output_file'"'
    }
}

* ==============================================================================
* 4. REQUIRE THE COMPLETE STEP 4 REVIEW PACKAGE -- DO NOT EDIT
* ==============================================================================

foreach required_file in ///
        `"`review_candidate'"' ///
        `"`review_workbook'"' ///
        `"`review_qa'"' ///
        `"`review_basis'"' ///
        `"`reference_dta'"' ///
        `"`reference_csv'"' ///
        `"`reference_yml'"' {
    capture confirm file `"`required_file'"'
    if _rc {
        _bnr_mort_s5_fail 601 "`release_id'" `"`private_log'"' ///
            `"Required completed Step 4 review file not found: `required_file'"'
    }
}

* ==============================================================================
* 5. REVALIDATE THE STEP 4 QA RECEIPT -- DO NOT EDIT
* ==============================================================================

import delimited using `"`review_qa'"', varnames(1) stringcols(_all) clear

foreach variable in check result detail {
    capture confirm variable `variable'
    if _rc {
        _bnr_mort_s5_fail 111 "`release_id'" `"`private_log'"' ///
            "The Step 4 QA receipt has an invalid structure."
    }
}

quietly count
if r(N) != 16 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The Step 4 QA receipt does not contain the expected 16 checks."
}

quietly count if result != "PASS"
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The Step 4 QA receipt contains a non-passing check."
}

foreach required_check in complete_step3_package release_and_current_match ///
        metric_schema_and_grain release_period definitions ///
        dashboard_lattice count_reconciliation distribution_reconciliation ///
        step3_qa_receipt metadata_contract monthly_reference_candidate ///
        disclosure_control temporal_differencing ///
        review_candidate_structure review_candidate_suppression ///
        publication_boundary {
    quietly count if check == "`required_check'" & result == "PASS"
    if r(N) != 1 {
        _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
            `"Required Step 4 QA check is absent or duplicated: `required_check'"'
    }
}

* ==============================================================================
* 6. REVALIDATE THE EXACT STEP 4 PUBLIC CANDIDATE -- DO NOT EDIT
* ==============================================================================

use `"`review_candidate'"', clear

local required_variables metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex age_group case_definition ///
    source_status statistic value display_value unit numerator denominator ///
    comparison_n status_flag sdc_policy primary_suppression ///
    primary_suppression_threshold ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason suppression_status disclosure_note

foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        _bnr_mort_s5_fail 111 "`release_id'" `"`private_log'"' ///
            `"Required reviewed-candidate variable is absent: `variable'"'
    }
}

quietly count
local public_rows = r(N)
if `public_rows' == 0 {
    _bnr_mort_s5_fail 2000 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate contains no rows."
}

capture isid metric_id period_type period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic, missok
if _rc {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate is not unique at the approved metric grain."
}

quietly count if release_id != "`release_id'"
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate contains the wrong release identifier."
}

quietly count if !inlist(case_definition, "primary_clear_likely", ///
    "upper_clear_likely_possible")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate has a missing or unrecognised case definition."
}
quietly count if case_definition == "primary_clear_likely"
local primary_definition_rows = r(N)
quietly count if case_definition == "upper_clear_likely_possible"
local upper_definition_rows = r(N)
if `primary_definition_rows' == 0 | `upper_definition_rows' == 0 | ///
        `primary_definition_rows' != `upper_definition_rows' {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate does not contain equal Primary and Upper-bound lattices."
}

quietly count if sdc_policy != "bnr_sdc_v1" | ///
    primary_suppression_threshold != 6
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate disclosure-control policy or threshold has changed."
}

quietly count if !inlist(metric_id, "MORT-BURDEN-001", "MORT-BURDEN-002")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate contains an unrecognised metric identifier."
}

quietly count if !inlist(event_type, "all_cvd", "heart", "stroke") | ///
    !inlist(sex, "all", "female", "male") | ///
    !inlist(age_group, "all", "under_70", "age_70_plus")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate contains an unrecognised reporting dimension."
}

quietly count if !inlist(suppression_status, "none", "primary", "secondary")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate contains an unrecognised suppression status."
}

quietly count if suppression_status != "none" & ///
    (!missing(value) | !missing(numerator) | !missing(denominator) | ///
     !missing(comparison_n))
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "A protected candidate row retains an exact numeric result or supporting count."
}

quietly count if suppression_status != "none" & display_value != "*"
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "A protected candidate row does not contain the suppression marker."
}

quietly count if suppression_status == "none" & ///
    status_flag != "insufficient_history" & ///
    (missing(value) | strtrim(display_value) == "" | display_value == "*")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "An unrestricted candidate row has lost its exact or display value."
}

quietly count if suppression_status == "none" & ///
    status_flag == "insufficient_history" & ///
    (!missing(value) | strtrim(display_value) != "")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "An insufficient-history candidate row contains a numeric or display value."
}

quietly count if missing(disclosure_note) | strtrim(disclosure_note) == ""
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "A reviewed-candidate row has no disclosure-control explanation."
}

* Step 4 owns the full primary and complementary-suppression calculation. Its
* disclosure-control QA result and the fingerprints below bind this approval to
* the exact reviewed candidate. Step 5 deliberately does not repeat the
* calculation: an analyst should never have to diagnose or amend suppression
* code while recording approval.

* Aggregate-only public payload: reject common person-level identifiers even if
* one were accidentally introduced in an earlier code change.
foreach forbidden_variable in id death_id person_id patient_id registration_id ///
        name first_name last_name date_of_birth dob address postcode {
    capture confirm variable `forbidden_variable'
    if !_rc {
        _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
            `"A person-level identifier is present in the reviewed candidate: `forbidden_variable'"'
    }
}

quietly count if suppression_status == "primary"
local primary_rows = r(N)
quietly count if suppression_status == "secondary"
local secondary_rows = r(N)
quietly count if suppression_status != "none"
local suppressed_rows = r(N)
quietly count if event_type == "all_cvd"
local cvd_rows = r(N)
quietly count if event_type == "heart"
local heart_rows = r(N)
quietly count if event_type == "stroke"
local stroke_rows = r(N)
quietly summarize period_year, meanonly
local analysis_start_year = floor(r(min))
local analysis_end_year = floor(r(max))

local expected_years = `analysis_end_year' - `analysis_start_year' + 1
local expected_count_rows = ///
    (`expected_years' * 11) + ((`expected_years' - 1) * 11) + ///
    (`expected_years' * 12) + ///
    (`expected_years' * 4 * 9) + ((`expected_years' - 1) * 4 * 9)
local expected_distribution_rows = `expected_years' * 10
local expected_count_rows = 2 * `expected_count_rows'
local expected_distribution_rows = 2 * `expected_distribution_rows'
local expected_public_rows = `expected_count_rows' + `expected_distribution_rows'
if `analysis_start_year' != 2010 | `public_rows' != `expected_public_rows' {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The reviewed candidate does not match the approved 2010-onward dashboard lattice."
}

quietly count if period_type == "monthly" & ///
    (event_type != "all_cvd" | sex != "all" | age_group != "all" | ///
     statistic != "monthly_count")
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "The reviewed candidate contains a monthly row outside the approved public scope."
}

* ==============================================================================
* 7. REVALIDATE THE FIXED MONTHLY REFERENCE ASSET -- DO NOT EDIT
* ==============================================================================
* Step 5 does not calculate the reference. It only checks that the exact
* Step 4-reviewed asset has the agreed fixed 2015-2019 structure and values.
use `"`reference_dta'"', clear

foreach variable in reference_id case_definition event_type sex age_group ///
        period_month reference_start_year reference_end_year reference_n ///
        reference_min reference_max reference_mean source_release_id ///
        reference_method {
    capture confirm variable `variable'
    if _rc {
        _bnr_mort_s5_fail 111 "`release_id'" `"`private_log'" ///
            "Required monthly-reference variable is absent: `variable'."
    }
}

quietly count
if r(N) != 24 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "The reviewed monthly reference does not contain 24 scenario-month rows."
}
capture isid case_definition period_month
if _rc {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "The reviewed monthly reference is not unique by mortality scenario and calendar month."
}
quietly count if reference_id != "mortality_monthly_reference_2015_2019" | ///
    !inlist(case_definition, "primary_clear_likely", ///
    "upper_clear_likely_possible") | event_type != "all_cvd" | ///
    sex != "all" | age_group != "all" | !inrange(period_month, 1, 12) | ///
    reference_start_year != 2015 | reference_end_year != 2019 | ///
    reference_n != 5 | reference_min > reference_max | ///
    missing(reference_min) | missing(reference_max) | missing(reference_mean)
if r(N) {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "The reviewed monthly reference does not match the agreed fixed 2015-2019 public contract."
}

* ==============================================================================
* 7. CONFIRM EVERY STEP 4 FINGERPRINT -- DO NOT EDIT
* ==============================================================================

import delimited using `"`review_basis'"', varnames(1) stringcols(_all) clear

foreach variable in file_role file_path file_size checksum {
    capture confirm variable `variable'
    if _rc {
        _bnr_mort_s5_fail 111 "`release_id'" `"`private_log'"' ///
            "The Step 4 review-basis file has an invalid structure."
    }
}

quietly count
if r(N) != 14 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The Step 4 review-basis file does not contain the expected 14 rows."
}

capture isid file_role
if _rc {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The Step 4 review-basis file contains duplicate file roles."
}

* Each role must point to the exact path selected for this release.
quietly count if file_role == "release_metric_dta" & file_path == `"`release_dta'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid release DTA review basis."
}
quietly count if file_role == "release_metric_csv" & file_path == `"`release_csv'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid release CSV review basis."
}
quietly count if file_role == "current_metric_dta" & file_path == `"`current_dta'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid current DTA review basis."
}
quietly count if file_role == "current_metric_csv" & file_path == `"`current_csv'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid current CSV review basis."
}
quietly count if file_role == "step3_package_metadata" & file_path == `"`package_metadata'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid Step 3 metadata review basis."
}
quietly count if file_role == "step3_qa_receipt" & file_path == `"`step3_qa'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid Step 3 QA review basis."
}
quietly count if file_role == "step3_suppression_csv" & file_path == `"`suppression_csv'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid suppression CSV review basis."
}
quietly count if file_role == "step3_suppression_xlsx" & file_path == `"`suppression_xlsx'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid suppression workbook review basis."
}
quietly count if file_role == "step3_readme" & file_path == `"`package_readme'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid Step 3 readme review basis."
}
quietly count if file_role == "monthly_reference_dta" & file_path == `"`reference_dta'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "Invalid monthly-reference DTA review basis."
}
quietly count if file_role == "monthly_reference_csv" & file_path == `"`reference_csv'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "Invalid monthly-reference CSV review basis."
}
quietly count if file_role == "monthly_reference_metadata" & file_path == `"`reference_yml'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'" ///
        "Invalid monthly-reference metadata review basis."
}
quietly count if file_role == "reviewed_public_candidate" & file_path == `"`review_candidate'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid reviewed-candidate basis."
}
quietly count if file_role == "step4_qa_receipt" & file_path == `"`review_qa'"'
if r(N) != 1 {
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "Invalid Step 4 QA review basis."
}

* Now recompute all 14 recorded file fingerprints. No selected or reviewed file
* may have changed after Step 4 created the human-review package.
forvalues basis_row = 1/14 {
    local reviewed_path = file_path[`basis_row']
    local reviewed_role = file_role[`basis_row']
    local recorded_size = real(file_size[`basis_row'])
    local recorded_checksum = real(checksum[`basis_row'])

    capture confirm file `"`reviewed_path'"'
    if _rc {
        _bnr_mort_s5_fail 601 "`release_id'" `"`private_log'"' ///
            `"A reviewed source file is absent (`reviewed_role'): `reviewed_path'"'
    }

    quietly checksum `"`reviewed_path'"'
    if r(filelen) != `recorded_size' | r(checksum) != `recorded_checksum' {
        _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
            `"A reviewed file changed after Step 4 (`reviewed_role'): `reviewed_path'"'
    }
}

* ==============================================================================
* 8. BUILD THE APPROVED PAYLOAD IN TEMPORARY FILES -- DO NOT EDIT
* ==============================================================================

tempfile public_csv metadata_release metadata_current metadata_package ///
    public_reference_metadata

use `"`review_candidate'"', clear
export delimited using `"`public_csv'"', replace

local today_iso : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")

foreach dataset_type in release current {
    local yml_file `"`metadata_release'"'
    if "`dataset_type'" == "current" local yml_file `"`metadata_current'"'

    tempname dataset_meta
    file open `dataset_meta' using `"`yml_file'"', write text replace
    file write `dataset_meta' "schema: bnr_public_mortality_dataset_v1" _n
    file write `dataset_meta' "dataset_type: `dataset_type'" _n
    file write `dataset_meta' "package_status: public_ready" _n
    file write `dataset_meta' "package_id: `package_id'" _n
    file write `dataset_meta' "release_id: `release_id'" _n
    file write `dataset_meta' "domain: mortality" _n
    file write `dataset_meta' "metric_family: burden" _n
    file write `dataset_meta' "rows: `public_rows'" _n
    file write `dataset_meta' "primary_definition_rows: `primary_definition_rows'" _n
    file write `dataset_meta' "upper_definition_rows: `upper_definition_rows'" _n
    file write `dataset_meta' "analysis_start_year: `analysis_start_year'" _n
    file write `dataset_meta' "analysis_end_year: `analysis_end_year'" _n
    file write `dataset_meta' "case_definitions:" _n
    file write `dataset_meta' "  - primary_clear_likely" _n
    file write `dataset_meta' "  - upper_clear_likely_possible" _n
    file write `dataset_meta' "lower_bound_included: false" _n
    file write `dataset_meta' "event_types:" _n
    file write `dataset_meta' "  - all_cvd" _n
    file write `dataset_meta' "  - heart" _n
    file write `dataset_meta' "  - stroke" _n
    file write `dataset_meta' "combined_definition_primary: Step 2 cvd_prim" _n
    file write `dataset_meta' "combined_definition_upper: Step 2 cvd_incl" _n
    file write `dataset_meta' "resolved_family_primary: Step 2 cvd_sub_p" _n
    file write `dataset_meta' "resolved_family_upper: Step 2 cvd_sub_i" _n
    file write `dataset_meta' "reporting_frequencies:" _n
    file write `dataset_meta' "  - annual" _n
    file write `dataset_meta' "  - quarterly" _n
    file write `dataset_meta' "  - monthly" _n
    file write `dataset_meta' "monthly_public_scope: all_cvd_all_sexes_all_ages_only" _n
    file write `dataset_meta' "monthly_rolling_comparator_included: false" _n
    file write `dataset_meta' "quarterly_annual_rolling_comparators_included: true" _n
    file write `dataset_meta' "monthly_historical_reference: mortality_monthly_reference_2015_2019" _n
    file write `dataset_meta' "cvd_rows: `cvd_rows'" _n
    file write `dataset_meta' "heart_rows: `heart_rows'" _n
    file write `dataset_meta' "stroke_rows: `stroke_rows'" _n
    file write `dataset_meta' "sdc_policy: bnr_sdc_v1" _n
    file write `dataset_meta' "primary_suppression_threshold: 6" _n
    file write `dataset_meta' "suppressed_rows: `suppressed_rows'" _n
    file write `dataset_meta' "primary_rows: `primary_rows'" _n
    file write `dataset_meta' "secondary_rows: `secondary_rows'" _n
    file write `dataset_meta' "suppression_status_values:" _n
    file write `dataset_meta' "  - none" _n
    file write `dataset_meta' "  - primary" _n
    file write `dataset_meta' "  - secondary" _n
    file write `dataset_meta' "suppressed_exact_fields:" _n
    file write `dataset_meta' "  - value" _n
    file write `dataset_meta' "  - numerator" _n
    file write `dataset_meta' "  - denominator" _n
    file write `dataset_meta' "  - comparison_n" _n
    file write `dataset_meta' "suppressed_display_value: asterisk" _n
    file write `dataset_meta' "insufficient_history_status: insufficient_history" _n
    file write `dataset_meta' "insufficient_history_is_suppression: false" _n
    file write `dataset_meta' "disclosure_note_field: disclosure_note" _n
    file write `dataset_meta' "approved: true" _n
    file write `dataset_meta' "publication_boundary: pending_step_6" _n
    file close `dataset_meta'
}

tempname package_meta
file open `package_meta' using `"`metadata_package'"', write text replace
file write `package_meta' "schema: bnr_public_mortality_package_v1" _n
file write `package_meta' "package_id: `package_id'" _n
file write `package_meta' "package_status: public_ready" _n
file write `package_meta' "release_id: `release_id'" _n
file write `package_meta' "domain: mortality" _n
file write `package_meta' "metric_family: burden" _n
file write `package_meta' "created: `today_iso'" _n
file write `package_meta' "review_standard: bnr_mortality_review_v1" _n
file write `package_meta' "disclosure_policy: bnr_sdc_v1" _n
file write `package_meta' "dashboard_suppression_field: suppression_status" _n
file write `package_meta' "dashboard_display_field: display_value" _n
file write `package_meta' "dashboard_disclosure_note_field: disclosure_note" _n
file write `package_meta' "insufficient_history_is_suppression: false" _n
file write `package_meta' "primary_definition_rows: `primary_definition_rows'" _n
file write `package_meta' "upper_definition_rows: `upper_definition_rows'" _n
file write `package_meta' "case_definitions:" _n
file write `package_meta' "  - primary_clear_likely" _n
file write `package_meta' "  - upper_clear_likely_possible" _n
file write `package_meta' "lower_bound_included: false" _n
file write `package_meta' "combined_definition_primary: Step 2 cvd_prim" _n
file write `package_meta' "combined_definition_upper: Step 2 cvd_incl" _n
file write `package_meta' "resolved_family_primary: Step 2 cvd_sub_p" _n
file write `package_meta' "resolved_family_upper: Step 2 cvd_sub_i" _n
file write `package_meta' "cvd_dashboard_reporting_scope_aligned: true" _n
file write `package_meta' "monthly_public_scope: all_cvd_all_sexes_all_ages_only" _n
file write `package_meta' "monthly_rolling_comparator_included: false" _n
file write `package_meta' "quarterly_annual_rolling_comparators_included: true" _n
file write `package_meta' "monthly_historical_reference:" _n
file write `package_meta' "  reference_id: mortality_monthly_reference_2015_2019" _n
file write `package_meta' "  reference_period: 2015-2019" _n
file write `package_meta' "  statistics: minimum_maximum_mean" _n
file write `package_meta' "  asset_dta: datasets/mort_monthly_reference_2015_2019.dta" _n
file write `package_meta' "  asset_csv: datasets/mort_monthly_reference_2015_2019.csv" _n
file write `package_meta' "  asset_metadata: metadata/mort_monthly_reference_2015_2019.yml" _n
file write `package_meta' "  routine_rule: checksum_verify_do_not_recalculate" _n
file write `package_meta' "approved: true" _n
file write `package_meta' "publication_boundary: pending_step_6" _n
file close `package_meta'

* The Step 4 reference metadata correctly describes the source review
* candidate.  The copy placed in public_ready must not retain that draft
* wording, because Step 5 has now recorded review of the exact reference
* asset.  Generate a new public-ready metadata file here rather than asking
* an analyst to edit a generated file by hand.  approval.yml is still written
* last below and remains the controlling approval receipt.
tempname public_reference_meta
file open `public_reference_meta' using `"`public_reference_metadata'"', ///
    write text replace
file write `public_reference_meta' "schema: bnr_mortality_monthly_reference_v1" _n
file write `public_reference_meta' "status: approved_reference_asset" _n
file write `public_reference_meta' "approved_via: approval.yml" _n
file write `public_reference_meta' "reference_id: mortality_monthly_reference_2015_2019" _n
file write `public_reference_meta' "reference_period: 2015-2019" _n
file write `public_reference_meta' "frequency: monthly" _n
file write `public_reference_meta' "public_scope: all_cvd_all_sexes_all_ages_only" _n
file write `public_reference_meta' "statistics: minimum_maximum_mean" _n
file write `public_reference_meta' "scenario_count: 2" _n
file write `public_reference_meta' "calendar_month_rows: 24" _n
file write `public_reference_meta' "source_release_id: `release_id'" _n
file write `public_reference_meta' "recalculation_rule: do_not_recalculate_after_initial_approval" _n
file write `public_reference_meta' "publication_boundary: pending_step_6" _n
file close `public_reference_meta'

* ==============================================================================
* 9. CREATE public_ready AND COPY THE TEN PAYLOAD FILES -- DO NOT EDIT
* ==============================================================================

capture mkdir "`ready_dir'"
capture mkdir "`ready_data'"
capture mkdir "`ready_meta'"

local copy_rc 0
local failed_target ""

capture copy `"`review_candidate'"' `"`public_release_dta'"'
if _rc {
    local copy_rc = _rc
    local failed_target `"`public_release_dta'"'
}
if !`copy_rc' {
    capture copy `"`public_csv'"' `"`public_release_csv'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_release_csv'"'
    }
}
if !`copy_rc' {
    capture copy `"`review_candidate'"' `"`public_current_dta'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_current_dta'"'
    }
}
if !`copy_rc' {
    capture copy `"`public_csv'"' `"`public_current_csv'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_current_csv'"'
    }
}
if !`copy_rc' {
    capture copy `"`metadata_release'"' `"`public_release_yml'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_release_yml'"'
    }
}
if !`copy_rc' {
    capture copy `"`metadata_current'"' `"`public_current_yml'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_current_yml'"'
    }
}
if !`copy_rc' {
    capture copy `"`metadata_package'"' `"`public_package_yml'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_package_yml'"'
    }
}
if !`copy_rc' {
    capture copy `"`reference_dta'"' `"`public_reference_dta'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_reference_dta'"'
    }
}
if !`copy_rc' {
    capture copy `"`reference_csv'"' `"`public_reference_csv'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_reference_csv'"'
    }
}
if !`copy_rc' {
    capture copy `"`public_reference_metadata'"' `"`public_reference_yml'"'
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_reference_yml'"'
    }
}

if `copy_rc' {
    capture erase `"`public_release_dta'"'
    capture erase `"`public_release_csv'"'
    capture erase `"`public_current_dta'"'
    capture erase `"`public_current_csv'"'
    capture erase `"`public_release_yml'"'
    capture erase `"`public_current_yml'"'
    capture erase `"`public_package_yml'"'
    capture erase `"`public_reference_dta'"'
    capture erase `"`public_reference_csv'"'
    capture erase `"`public_reference_yml'"'
    capture erase `"`manifest'"'
    capture erase `"`approval'"'
    capture rmdir "`ready_data'"
    capture rmdir "`ready_meta'"
    capture rmdir "`ready_dir'"
    _bnr_mort_s5_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"A public-ready payload file could not be created: `failed_target'"'
}

* ==============================================================================
* 10. MANIFEST ONLY THE TEN PROMOTABLE PAYLOAD FILES -- DO NOT EDIT
* ==============================================================================

local manifest_files ///
    datasets/mort_burden_metrics_`release_id'.dta ///
    datasets/mort_burden_metrics_`release_id'.csv ///
    datasets/mort_burden_metrics_current.dta ///
    datasets/mort_burden_metrics_current.csv ///
    metadata/mort_burden_metrics_`release_id'.yml ///
    metadata/mort_burden_metrics_current.yml ///
    metadata/mort_burden_package.yml ///
    datasets/mort_monthly_reference_2015_2019.dta ///
    datasets/mort_monthly_reference_2015_2019.csv ///
    metadata/mort_monthly_reference_2015_2019.yml

tempfile manifest_dta
tempname manifest_handle
postfile `manifest_handle' str12 payload_root str120 relative_path ///
    str12 file_type double file_size double checksum ///
    using `"`manifest_dta'"', replace

foreach relative_path of local manifest_files {
    local full_path "`ready_dir'/`relative_path'"
    quietly checksum `"`full_path'"'
    local file_type = substr("`relative_path'", ///
        strrpos("`relative_path'", ".") + 1, .)
    post `manifest_handle' (".") ("`relative_path'") ("`file_type'") ///
        (r(filelen)) (r(checksum))
}
postclose `manifest_handle'

use `"`manifest_dta'"', clear
format file_size checksum %20.0f
capture quietly export delimited using `"`manifest'"'
if _rc {
    local manifest_rc = _rc
    capture erase `"`public_release_dta'"'
    capture erase `"`public_release_csv'"'
    capture erase `"`public_current_dta'"'
    capture erase `"`public_current_csv'"'
    capture erase `"`public_release_yml'"'
    capture erase `"`public_current_yml'"'
    capture erase `"`public_package_yml'"'
    capture erase `"`public_reference_dta'"'
    capture erase `"`public_reference_csv'"'
    capture erase `"`public_reference_yml'"'
    capture erase `"`manifest'"'
    capture erase `"`approval'"'
    capture rmdir "`ready_data'"
    capture rmdir "`ready_meta'"
    capture rmdir "`ready_dir'"
    _bnr_mort_s5_fail `manifest_rc' "`release_id'" `"`private_log'"' ///
        "The public-ready manifest could not be created."
}

quietly count
if r(N) != 10 {
    capture erase `"`public_release_dta'"'
    capture erase `"`public_release_csv'"'
    capture erase `"`public_current_dta'"'
    capture erase `"`public_current_csv'"'
    capture erase `"`public_release_yml'"'
    capture erase `"`public_current_yml'"'
    capture erase `"`public_package_yml'"'
    capture erase `"`public_reference_dta'"'
    capture erase `"`public_reference_csv'"'
    capture erase `"`public_reference_yml'"'
    capture erase `"`manifest'"'
    capture erase `"`approval'"'
    capture rmdir "`ready_data'"
    capture rmdir "`ready_meta'"
    capture rmdir "`ready_dir'"
    _bnr_mort_s5_fail 459 "`release_id'" `"`private_log'"' ///
        "The public-ready manifest does not contain exactly ten payload files."
}

quietly checksum `"`manifest'"'
local manifest_size : display %20.0f r(filelen)
local manifest_checksum : display %20.0f r(checksum)

* ==============================================================================
* 11. WRITE approval.yml LAST -- DO NOT EDIT
* ==============================================================================

local approved_date_num = daily("`c(current_date)'", "DMY")
local approved_date : display %tdCCYY-NN-DD `approved_date_num'
local approved_time "`c(current_time)'"

tempfile approval_temp
capture quietly _bnr_mort_s5_write_approval ///
    `"`approval_temp'"' "`package_id'" "`release_id'" ///
    `"`approver_name'"' `"`approver_role'"' ///
    "`approved_date'" "`approved_time'" ///
    "`manifest_size'" "`manifest_checksum'"
if _rc {
    local approval_write_rc = _rc
    capture erase `"`public_release_dta'"'
    capture erase `"`public_release_csv'"'
    capture erase `"`public_current_dta'"'
    capture erase `"`public_current_csv'"'
    capture erase `"`public_release_yml'"'
    capture erase `"`public_current_yml'"'
    capture erase `"`public_package_yml'"'
    capture erase `"`public_reference_dta'"'
    capture erase `"`public_reference_csv'"'
    capture erase `"`public_reference_yml'"'
    capture erase `"`manifest'"'
    capture erase `"`approval'"'
    capture rmdir "`ready_data'"
    capture rmdir "`ready_meta'"
    capture rmdir "`ready_dir'"
    _bnr_mort_s5_fail `approval_write_rc' "`release_id'" `"`private_log'"' ///
        "The temporary approval receipt could not be written."
}

capture copy `"`approval_temp'"' `"`approval'"'
if _rc {
    local approval_copy_rc = _rc
    capture erase `"`public_release_dta'"'
    capture erase `"`public_release_csv'"'
    capture erase `"`public_current_dta'"'
    capture erase `"`public_current_csv'"'
    capture erase `"`public_release_yml'"'
    capture erase `"`public_current_yml'"'
    capture erase `"`public_package_yml'"'
    capture erase `"`public_reference_dta'"'
    capture erase `"`public_reference_csv'"'
    capture erase `"`public_reference_yml'"'
    capture erase `"`manifest'"'
    capture erase `"`approval'"'
    capture rmdir "`ready_data'"
    capture rmdir "`ready_meta'"
    capture rmdir "`ready_dir'"
    _bnr_mort_s5_fail `approval_copy_rc' "`release_id'" `"`private_log'"' ///
        "The final approval receipt could not be created."
}

* Confirm the complete approval contract before reporting success.
foreach completed_file in ///
        `"`public_release_dta'"' ///
        `"`public_release_csv'"' ///
        `"`public_current_dta'"' ///
        `"`public_current_csv'"' ///
        `"`public_release_yml'"' ///
        `"`public_current_yml'"' ///
        `"`public_package_yml'"' ///
        `"`public_reference_dta'"' ///
        `"`public_reference_csv'"' ///
        `"`public_reference_yml'"' ///
        `"`manifest'"' ///
        `"`approval'"' {
    capture confirm file `"`completed_file'"'
    if _rc {
        _bnr_mort_s5_fail 603 "`release_id'" `"`private_log'"' ///
            `"Required completed Step 5 file is absent: `completed_file'"'
    }
}

* ==============================================================================
* 12. SINGLE OPERATIONAL RUN SUMMARY -- DO NOT EDIT
* ==============================================================================

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "MORTALITY STEP 5: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             APPROVED - PENDING STEP 6"
noisily display as text   "  Script version:         Pass 4.1 approved-reference metadata hardening"
noisily display as text   "  Selected release:       `release_id'"
noisily display as text   `"  Approver:               `approver_name' (`approver_role')"'
noisily display as text   "  Public candidate rows:  `public_rows'"
noisily display as text   "  Protected rows:         `suppressed_rows' (`primary_rows' primary; `secondary_rows' secondary)"
noisily display as text   `"  Public-ready package:   `ready_dir'"'
noisily display as text   `"  Public manifest:        `manifest'"'
noisily display as text   `"  Approval record:        `approval'"'
noisily display as text   `"  Private log:            `private_log'"'
noisily display as text   "  Publication boundary:   No public output or website file was created."
noisily display as text   "  Next step:              Run Step 6 promotion only when authorised."
noisily display as result "============================================================================="

}

quietly log close mort_s5
capture program drop _bnr_mort_s5_fail
capture program drop _bnr_mort_s5_write_approval

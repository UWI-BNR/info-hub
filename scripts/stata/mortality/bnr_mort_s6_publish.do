/*******************************************************************************
DO-FILE:     bnr_mort_s6_publish.do
VERSION:     Pass 2 (21 August 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Mortality Step 6 - publish an approved mortality package

PURPOSE:     Promote the exact ten mortality burden payload files approved in
             Step 5:

             1. read them from the private public_ready folder;
             2. validate approval.yml and public_manifest.csv;
             3. verify every approved payload fingerprint;
             4. copy the ten files to the authoritative public area;
             5. create and verify one release ZIP;
             6. create one download-catalogue record; and
             7. refresh the disposable website-download mirror.

WORKFLOW BOUNDARY:
             Step 6 copies and verifies approved files. It does not calculate
             mortality metrics, apply suppression, edit approved payloads,
             approve results, rebuild the central Downloads catalogue, render
             Quarto, commit to Git or deploy the website.

PUBLICATION CHAIN:
             private staging/public_ready
                         |
                         v
             authoritative outputs/public
                         |
                         v
             disposable site/downloads/files mirror

             The website mirror is always copied from the authoritative public
             area. It is never copied independently from private staging.

ROUTINE USE:
             do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 7

DELIBERATE REPUBLICATION:
             do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 7 replace

ANALYST-EDITABLE SECTION:
             Analysts supply only:
             - release year;
             - release month; and
             - optional word replace for deliberate republication.

IMPORTANT:
             - Run Step 5 approval successfully before Step 6.
             - Stable current files are refreshed from the selected release.
             - Release-stamped files require explicit replace if they exist.
             - approval.yml and public_manifest.csv remain private controls.
             - The synthetic 2099 test release may never be published.
*******************************************************************************/

version 19
clear all
set more off

* ==============================================================================
* INTERNAL SUPPORT PROGRAMS -- DO NOT EDIT
* ==============================================================================

* Print one standard failure summary after the private Step 6 log has opened.
* A filesystem error may occur after an earlier copy has succeeded. The message
* therefore tells the operator to inspect both public destinations before a
* rerun; it does not make an unsafe claim that nothing was copied.
capture program drop _bnr_mort_s6_fail
program define _bnr_mort_s6_fail
    version 19
    args return_code release_id private_log reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "MORTALITY STEP 6: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error "  Script version:         Pass 2"
    noisily display as error "  Selected release:       `release_id'"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `private_log'"'
    noisily display as text  "  Action required:        Correct the issue and inspect both public folders"
    noisily display as text  "                          before rerunning Step 6."
    noisily display as error "============================================================================="
    capture log close mort_s6
    exit `return_code'
end

* Verify one file against an expected byte length and Stata checksum. The main
* controller still names every file explicitly; this small routine avoids
* repeating the same three mechanical checks many times.
capture program drop _bnr_mort_s6_verify_file
program define _bnr_mort_s6_verify_file, rclass
    version 19
    args file_path expected_size expected_checksum

    capture confirm file `"`file_path'"'
    if _rc {
        return scalar ok = 0
        return local reason `"File not found: `file_path'"'
        exit
    }

    capture quietly checksum `"`file_path'"'
    if _rc {
        local checksum_rc = _rc
        return scalar ok = 0
        return local reason ///
            `"Checksum could not be calculated (Stata return code `checksum_rc'): `file_path'"'
        exit
    }

    if r(filelen) != real("`expected_size'") | ///
            r(checksum) != real("`expected_checksum'") {
        return scalar ok = 0
        return local reason ///
            `"File does not match the approved manifest: `file_path'"'
        exit
    }

    return scalar ok = 1
    return local reason ""
end

* ==============================================================================
* 1. ANALYST INPUTS -- EDIT THROUGH THE DIALOG OR COMMAND LINE
* ==============================================================================

args release_year release_month replace_word

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Enter release year and release month."
    exit 198
}

local replace_existing = 0
if "`replace_word'" != "" {
    if lower("`replace_word'") != "replace" {
        display as error "The only optional final word is replace."
        exit 198
    }
    local replace_existing = 1
}

local year_num = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | ///
        `year_num' < 2024 {
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
local selected_period "`release_year_4'-`release_month_2'"
local release_id "mort_`release_year_4'_`release_month_2'"
local package_id "mort_burden_`release_id'"

* The 2099 package is a synthetic suppression test and must never cross the
* private-to-public boundary, even if an earlier control were changed in error.
if "`release_year_4'" == "2099" {
    display as error "Synthetic mortality test releases may never be published."
    exit 459
}

* ==============================================================================
* 2. LOAD THE STANDARD BNR PATHS -- DO NOT EDIT
* ==============================================================================

if `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local path_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        display as error ///
            "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do through profile.do."
        exit `path_rc'
    }
}

foreach required_global in BNR_REPO BNR_STATA BNR_STAGING BNR_PUBLIC ///
        BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

* ==============================================================================
* 3. DEFINE THE PRIVATE SOURCE AND TWO PUBLIC DESTINATIONS -- DO NOT EDIT
* ==============================================================================

* Private Step 5 source package and control files.
local staging_package ///
    "$BNR_STAGING/mortality/burden/`release_id'"
local ready_folder "`staging_package'/public_ready"
local approval_file "`ready_folder'/approval.yml"
local manifest_file "`ready_folder'/public_manifest.csv"

* Authoritative public package. Dataset files are flattened into the burden
* root, while metadata stays in a plainly named metadata subfolder.
local public_folder "$BNR_PUBLIC/metrics/mortality/burden"
local public_data "`public_folder'/datasets"
local public_metadata "`public_folder'/metadata"
local public_catalogue "`public_folder'/catalogue"

* Disposable website-download mirror. It deliberately matches the layout of
* the authoritative public output.
local website_folder ///
    "$BNR_REPO/site/downloads/files/metrics/mortality/burden"
local website_data "`website_folder'/datasets"
local website_metadata "`website_folder'/metadata"
local website_catalogue "`website_folder'/catalogue"

* Private operational log.
local private_log ///
    "$BNR_PRIVATE_LOGS/bnr_mort_s6_publish_`release_id'.log"

* The exact ten approved source payloads.
local source_release_dta ///
    "`ready_folder'/datasets/mort_burden_metrics_`release_id'.dta"
local source_release_csv ///
    "`ready_folder'/datasets/mort_burden_metrics_`release_id'.csv"
local source_current_dta ///
    "`ready_folder'/datasets/mort_burden_metrics_current.dta"
local source_current_csv ///
    "`ready_folder'/datasets/mort_burden_metrics_current.csv"
local source_release_yml ///
    "`ready_folder'/metadata/mort_burden_metrics_`release_id'.yml"
local source_current_yml ///
    "`ready_folder'/metadata/mort_burden_metrics_current.yml"
local source_package_yml ///
    "`ready_folder'/metadata/mort_burden_package.yml"
local source_reference_dta ///
    "`ready_folder'/datasets/mort_monthly_reference_2015_2019.dta"
local source_reference_csv ///
    "`ready_folder'/datasets/mort_monthly_reference_2015_2019.csv"
local source_reference_yml ///
    "`ready_folder'/metadata/mort_monthly_reference_2015_2019.yml"

* Authoritative public files.
local public_release_dta ///
    "`public_data'/mort_burden_metrics_`release_id'.dta"
local public_release_csv ///
    "`public_data'/mort_burden_metrics_`release_id'.csv"
local public_current_dta ///
    "`public_data'/mort_burden_metrics_current.dta"
local public_current_csv ///
    "`public_data'/mort_burden_metrics_current.csv"
local public_release_yml ///
    "`public_metadata'/mort_burden_metrics_`release_id'.yml"
local public_current_yml ///
    "`public_metadata'/mort_burden_metrics_current.yml"
local public_package_yml ///
    "`public_metadata'/mort_burden_package.yml"
local public_reference_dta ///
    "`public_data'/mort_monthly_reference_2015_2019.dta"
local public_reference_csv ///
    "`public_data'/mort_monthly_reference_2015_2019.csv"
local public_reference_yml ///
    "`public_metadata'/mort_monthly_reference_2015_2019.yml"

local zip_name "bnr_mort_burden_`release_id'.zip"
local public_zip "`public_folder'/`zip_name'"
local catalogue_name "`release_id'.yml"
local public_catalogue_record "`public_catalogue'/`catalogue_name'"

* Website mirror files.
local website_release_dta ///
    "`website_data'/mort_burden_metrics_`release_id'.dta"
local website_release_csv ///
    "`website_data'/mort_burden_metrics_`release_id'.csv"
local website_current_dta ///
    "`website_data'/mort_burden_metrics_current.dta"
local website_current_csv ///
    "`website_data'/mort_burden_metrics_current.csv"
local website_release_yml ///
    "`website_metadata'/mort_burden_metrics_`release_id'.yml"
local website_current_yml ///
    "`website_metadata'/mort_burden_metrics_current.yml"
local website_package_yml ///
    "`website_metadata'/mort_burden_package.yml"
local website_reference_dta ///
    "`website_data'/mort_monthly_reference_2015_2019.dta"
local website_reference_csv ///
    "`website_data'/mort_monthly_reference_2015_2019.csv"
local website_reference_yml ///
    "`website_metadata'/mort_monthly_reference_2015_2019.yml"
local website_zip "`website_folder'/`zip_name'"
local website_catalogue_record "`website_catalogue'/`catalogue_name'"

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close mort_s6
log using `"`private_log'"', text replace name(mort_s6)

quietly {

noisily display as text "BNR MORTALITY STEP 6: PUBLISH APPROVED OUTPUTS"
noisily display as result "  Script version:       Pass 2"
noisily display as result "  Selected release:     `release_id'"
noisily display as result "  Replace authorised:   " ///
    cond(`replace_existing', "yes", "no")

* ==============================================================================
* 4. REQUIRE THE COMPLETE STEP 5 public_ready PACKAGE -- DO NOT EDIT
* ==============================================================================

capture confirm file `"`approval_file'"'
if _rc {
    _bnr_mort_s6_fail 601 "`release_id'" `"`private_log'"' ///
        `"Step 5 approval record not found: `approval_file'"'
}

capture confirm file `"`manifest_file'"'
if _rc {
    _bnr_mort_s6_fail 601 "`release_id'" `"`private_log'"' ///
        `"Step 5 public manifest not found: `manifest_file'"'
}

capture confirm file `"`staging_package'/SYNTHETIC_TEST_ONLY.txt"'
if !_rc {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The selected package is explicitly marked as synthetic test data."
}

* Fingerprint the manifest before reading approval.yml. approval.yml contains
* the expected length and checksum for this exact file.
capture quietly checksum `"`manifest_file'"'
if _rc {
    local manifest_checksum_rc = _rc
    _bnr_mort_s6_fail `manifest_checksum_rc' "`release_id'" ///
        `"`private_log'"' ///
        `"The public manifest could not be checked: `manifest_file'"'
}

local actual_manifest_size = r(filelen)
local actual_manifest_checksum = r(checksum)

* ==============================================================================
* 5. READ AND VALIDATE approval.yml -- DO NOT EDIT
* ==============================================================================

* Step 5 writes one controlled key per line. Reading those exact lines avoids
* adding a YAML-parser dependency to a simple Stata publication controller.
local approval_schema_ok 0
local approval_status_ok 0
local approval_package_ok 0
local approval_release_ok 0
local approval_domain_ok 0
local approval_family_ok 0
local approval_step_ok 0
local approval_role_ok 0
local approval_review_ok 0
local approval_policy_ok 0
local approval_disclosure_ok 0
local approval_reference_ok 0
local confirmation_release_ok 0
local confirmation_definitions_ok 0
local confirmation_disclosure_ok 0
local confirmation_candidate_ok 0
local confirmation_ready_ok 0
local approval_manifest_name_ok 0
local approval_payload_root_ok 0
local approval_scope_ok 0
local approval_required_files_ok 0
local approval_publication_false_ok 0
local approval_promotion_ok 0
local approved_by ""
local approved_date ""
local approved_manifest_size .
local approved_manifest_checksum .

tempname approval_handle
capture file open `approval_handle' using `"`approval_file'"', read text
if _rc {
    local approval_open_rc = _rc
    _bnr_mort_s6_fail `approval_open_rc' "`release_id'" ///
        `"`private_log'"' ///
        `"The Step 5 approval receipt could not be read: `approval_file'"'
}
file read `approval_handle' approval_line

while r(eof) == 0 {
    local approval_line = strtrim(`"`approval_line'"')

    if `"`approval_line'"' == "schema: bnr_mortality_approval_v1" {
        local approval_schema_ok 1
    }
    if `"`approval_line'"' == "status: approved" {
        local approval_status_ok 1
    }
    if `"`approval_line'"' == "package_id: `package_id'" {
        local approval_package_ok 1
    }
    if `"`approval_line'"' == "release_id: `release_id'" {
        local approval_release_ok 1
    }
    if `"`approval_line'"' == "domain: mortality" {
        local approval_domain_ok 1
    }
    if `"`approval_line'"' == "metric_family: burden" {
        local approval_family_ok 1
    }
    if `"`approval_line'"' == "workflow_step: 5" {
        local approval_step_ok 1
    }
    if inlist(`"`approval_line'"', ///
            "approved_role: BNR Lead", ///
            "approved_role: BNR Analyst", ///
            "approved_role: BNR Developer") {
        local approval_role_ok 1
    }
    if `"`approval_line'"' == ///
            "review_standard: bnr_mortality_review_v1" {
        local approval_review_ok 1
    }
    if `"`approval_line'"' == "disclosure_policy: bnr_sdc_v1" {
        local approval_policy_ok 1
    }
    if `"`approval_line'"' == "disclosure_check: passed" {
        local approval_disclosure_ok 1
    }
    if `"`approval_line'"' == ///
            "monthly_reference_reviewed: true" {
        local approval_reference_ok 1
    }
    if `"`approval_line'"' == ///
            "release_and_period_reviewed: true" {
        local confirmation_release_ok 1
    }
    if `"`approval_line'"' == ///
            "definitions_and_results_reviewed: true" {
        local confirmation_definitions_ok 1
    }
    if `"`approval_line'"' == ///
            "disclosure_control_reviewed: true" {
        local confirmation_disclosure_ok 1
    }
    if `"`approval_line'"' == ///
            "candidate_and_workbook_inspected: true" {
        local confirmation_candidate_ok 1
    }
    if `"`approval_line'"' == ///
            "publication_readiness_confirmed: true" {
        local confirmation_ready_ok 1
    }
    if `"`approval_line'"' == ///
            "public_ready_manifest: public_manifest.csv" {
        local approval_manifest_name_ok 1
    }
    if `"`approval_line'"' == "payload_root: ." {
        local approval_payload_root_ok 1
    }
    if `"`approval_line'"' == "manifest_scope: payload_files_only" {
        local approval_scope_ok 1
    }
    if `"`approval_line'"' == "manifest_required_files: 10" {
        local approval_required_files_ok 1
    }
    if `"`approval_line'"' == "publication_performed: false" {
        local approval_publication_false_ok 1
    }
    if `"`approval_line'"' == "promotion_status: pending_step_6" {
        local approval_promotion_ok 1
    }
    if strpos(`"`approval_line'"', "approved_by:") == 1 {
        local approved_by = strtrim(substr(`"`approval_line'"', 13, .))
    }
    if strpos(`"`approval_line'"', "approved_date:") == 1 {
        local approved_date = strtrim(substr(`"`approval_line'"', 15, .))
    }
    if strpos(`"`approval_line'"', "manifest_size:") == 1 {
        local approval_value = ///
            strtrim(substr(`"`approval_line'"', 15, .))
        local approved_manifest_size = real("`approval_value'")
    }
    if strpos(`"`approval_line'"', "manifest_checksum:") == 1 {
        local approval_value = ///
            strtrim(substr(`"`approval_line'"', 19, .))
        local approved_manifest_checksum = real("`approval_value'")
    }

    file read `approval_handle' approval_line
}

file close `approval_handle'

if !`approval_schema_ok' | !`approval_status_ok' | ///
        !`approval_step_ok' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml is not a completed mortality Step 5 approval receipt."
}

if !`approval_package_ok' | !`approval_release_ok' | ///
        !`approval_domain_ok' | !`approval_family_ok' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml does not match the selected mortality burden release."
}

if !`approval_role_ok' | strtrim(`"`approved_by'"') == "" {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml does not contain a named authorised BNR approver."
}

if !`approval_review_ok' | !`approval_policy_ok' | ///
        !`approval_disclosure_ok' | !`approval_reference_ok' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The required mortality review or disclosure approval is absent."
}

if !`confirmation_release_ok' | !`confirmation_definitions_ok' | ///
        !`confirmation_disclosure_ok' | !`confirmation_candidate_ok' | ///
        !`confirmation_ready_ok' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml does not contain all five human approval confirmations."
}

if !`approval_manifest_name_ok' | !`approval_payload_root_ok' | ///
        !`approval_scope_ok' | !`approval_required_files_ok' | ///
        !`approval_publication_false_ok' | !`approval_promotion_ok' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml does not authorise this Step 6 manifest promotion."
}

if missing(daily("`approved_date'", "YMD")) {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml does not contain a valid approved_date in YYYY-MM-DD form."
}

if missing(`approved_manifest_size') | ///
        missing(`approved_manifest_checksum') {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "approval.yml does not contain a usable manifest fingerprint."
}

if `actual_manifest_size' != `approved_manifest_size' | ///
        `actual_manifest_checksum' != `approved_manifest_checksum' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "public_manifest.csv has changed since Step 5 approval."
}

* ==============================================================================
* 6. REQUIRE THE EXACT TEN-FILE MANIFEST CONTRACT -- DO NOT EDIT
* ==============================================================================

capture quietly import delimited using `"`manifest_file'"', ///
    clear varnames(1) stringcols(_all)
if _rc {
    local import_rc = _rc
    _bnr_mort_s6_fail `import_rc' "`release_id'" `"`private_log'"' ///
        "public_manifest.csv could not be read."
}

foreach variable in payload_root relative_path file_type file_size checksum {
    capture confirm variable `variable'
    if _rc {
        _bnr_mort_s6_fail 111 "`release_id'" `"`private_log'"' ///
            `"Required manifest variable is absent: `variable'"'
    }
}

capture confirm numeric variable file_size
if _rc {
    capture quietly destring file_size, replace
    if _rc {
        _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
            "The manifest file_size column is not numeric."
    }
}

capture confirm numeric variable checksum
if _rc {
    capture quietly destring checksum, replace
    if _rc {
        _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
            "The manifest checksum column is not numeric."
    }
}

quietly count
if r(N) != 10 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The public manifest must contain exactly ten approved payload files."
}

capture quietly isid relative_path
if _rc {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The public manifest contains a duplicate relative path."
}

quietly count if payload_root != "."
if r(N) {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "Every manifest payload_root value must be a single period."
}

* Check each approved relative path explicitly. Ten manifest rows plus ten
* successful checks prove that no unrecognised payload row is present.
quietly count if relative_path == ///
    "datasets/mort_burden_metrics_`release_id'.dta" & file_type == "dta"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The release-stamped DTA is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/mort_burden_metrics_`release_id'.csv" & file_type == "csv"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The release-stamped CSV is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/mort_burden_metrics_current.dta" & file_type == "dta"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The current DTA is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/mort_burden_metrics_current.csv" & file_type == "csv"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The current CSV is absent from the approved manifest."
}

quietly count if relative_path == ///
    "metadata/mort_burden_metrics_`release_id'.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The release-stamped metadata file is absent from the manifest."
}

quietly count if relative_path == ///
    "metadata/mort_burden_metrics_current.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The current metadata file is absent from the approved manifest."
}

quietly count if relative_path == ///
    "metadata/mort_burden_package.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The package metadata file is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/mort_monthly_reference_2015_2019.dta" & file_type == "dta"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The monthly reference DTA is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/mort_monthly_reference_2015_2019.csv" & file_type == "csv"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The monthly reference CSV is absent from the approved manifest."
}

quietly count if relative_path == ///
    "metadata/mort_monthly_reference_2015_2019.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The monthly reference metadata is absent from the approved manifest."
}

* Retain each approved fingerprint under a plainly named local macro.
quietly summarize file_size if relative_path == ///
    "datasets/mort_burden_metrics_`release_id'.dta", meanonly
local release_dta_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/mort_burden_metrics_`release_id'.dta", meanonly
local release_dta_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/mort_burden_metrics_`release_id'.csv", meanonly
local release_csv_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/mort_burden_metrics_`release_id'.csv", meanonly
local release_csv_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/mort_burden_metrics_current.dta", meanonly
local current_dta_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/mort_burden_metrics_current.dta", meanonly
local current_dta_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/mort_burden_metrics_current.csv", meanonly
local current_csv_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/mort_burden_metrics_current.csv", meanonly
local current_csv_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/mort_burden_metrics_`release_id'.yml", meanonly
local release_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/mort_burden_metrics_`release_id'.yml", meanonly
local release_yml_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/mort_burden_metrics_current.yml", meanonly
local current_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/mort_burden_metrics_current.yml", meanonly
local current_yml_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/mort_burden_package.yml", meanonly
local package_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/mort_burden_package.yml", meanonly
local package_yml_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/mort_monthly_reference_2015_2019.dta", meanonly
local reference_dta_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/mort_monthly_reference_2015_2019.dta", meanonly
local reference_dta_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/mort_monthly_reference_2015_2019.csv", meanonly
local reference_csv_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/mort_monthly_reference_2015_2019.csv", meanonly
local reference_csv_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/mort_monthly_reference_2015_2019.yml", meanonly
local reference_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/mort_monthly_reference_2015_2019.yml", meanonly
local reference_yml_checksum = r(mean)

clear

* ==============================================================================
* 7. VERIFY ALL TEN PRIVATE SOURCE FILES BEFORE COPYING -- DO NOT EDIT
* ==============================================================================

quietly _bnr_mort_s6_verify_file `"`source_release_dta'"' ///
    "`release_dta_size'" "`release_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_release_csv'"' ///
    "`release_csv_size'" "`release_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_current_dta'"' ///
    "`current_dta_size'" "`current_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_current_csv'"' ///
    "`current_csv_size'" "`current_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_release_yml'"' ///
    "`release_yml_size'" "`release_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_current_yml'"' ///
    "`current_yml_size'" "`current_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_package_yml'"' ///
    "`package_yml_size'" "`package_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_reference_dta'"' ///
    "`reference_dta_size'" "`reference_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_reference_csv'"' ///
    "`reference_csv_size'" "`reference_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`source_reference_yml'"' ///
    "`reference_yml_size'" "`reference_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

* The reference metadata is generated by the revised Step 5 controller.  This
* explicit text check prevents an older package carrying the obsolete
* review-candidate wording from crossing the publication boundary.
local reference_status_ok 0
local reference_receipt_ok 0
tempname reference_meta_handle
capture file open `reference_meta_handle' using `"`source_reference_yml'"', ///
    read text
if _rc {
    local reference_meta_rc = _rc
    _bnr_mort_s6_fail `reference_meta_rc' "`release_id'" ///
        `"`private_log'"' ///
        "The approved monthly-reference metadata could not be read."
}
file read `reference_meta_handle' reference_meta_line
while r(eof) == 0 {
    local reference_meta_line = strtrim(`"`reference_meta_line'"')
    if `"`reference_meta_line'"' == ///
            "status: approved_reference_asset" {
        local reference_status_ok 1
    }
    if `"`reference_meta_line'"' == ///
            "approved_via: approval.yml" {
        local reference_receipt_ok 1
    }
    file read `reference_meta_handle' reference_meta_line
}
file close `reference_meta_handle'

if !`reference_status_ok' | !`reference_receipt_ok' {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The monthly-reference metadata is not marked as an approved Step 5 asset."
}

* ==============================================================================
* 8. PROTECT AN ALREADY-PUBLISHED RELEASE -- DO NOT EDIT
* ==============================================================================

* Stable current files are expected after the first publication and are always
* refreshed. Release-stamped files, the ZIP and catalogue record are protected.
if !`replace_existing' {
    foreach protected_file in ///
            `"`public_release_dta'"' ///
            `"`public_release_csv'"' ///
            `"`public_release_yml'"' ///
            `"`public_reference_dta'"' ///
            `"`public_reference_csv'"' ///
            `"`public_reference_yml'"' ///
            `"`public_zip'"' ///
            `"`public_catalogue_record'"' ///
            `"`website_release_dta'"' ///
            `"`website_release_csv'"' ///
            `"`website_release_yml'"' ///
            `"`website_reference_dta'"' ///
            `"`website_reference_csv'"' ///
            `"`website_reference_yml'"' ///
            `"`website_zip'"' ///
            `"`website_catalogue_record'"' {
        capture confirm file `"`protected_file'"'
        if !_rc {
            _bnr_mort_s6_fail 602 "`release_id'" `"`private_log'"' ///
                `"Published release output already exists. Use replace only after checking: `protected_file'"'
        }
    }
}

* ==============================================================================
* 9. CREATE THE TWO STANDARD PUBLIC FOLDER TREES -- DO NOT EDIT
* ==============================================================================

capture mkdir "$BNR_PUBLIC/metrics"
capture mkdir "$BNR_PUBLIC/metrics/mortality"
capture mkdir "$BNR_PUBLIC/metrics/mortality/burden"
capture mkdir "$BNR_PUBLIC/metrics/mortality/burden/datasets"
capture mkdir "$BNR_PUBLIC/metrics/mortality/burden/metadata"
capture mkdir "$BNR_PUBLIC/metrics/mortality/burden/catalogue"

capture mkdir "$BNR_REPO/site/downloads"
capture mkdir "$BNR_REPO/site/downloads/files"
capture mkdir "$BNR_REPO/site/downloads/files/metrics"
capture mkdir "$BNR_REPO/site/downloads/files/metrics/mortality"
capture mkdir "$BNR_REPO/site/downloads/files/metrics/mortality/burden"
capture mkdir ///
    "$BNR_REPO/site/downloads/files/metrics/mortality/burden/datasets"
capture mkdir ///
    "$BNR_REPO/site/downloads/files/metrics/mortality/burden/metadata"
capture mkdir ///
    "$BNR_REPO/site/downloads/files/metrics/mortality/burden/catalogue"

* ==============================================================================
* 10. COPY THE TEN APPROVED FILES TO AUTHORITATIVE PUBLIC -- DO NOT EDIT
* ==============================================================================

* These copies are deliberately explicit. No recursive folder copy is allowed:
* only the ten files named and fingerprinted by the approved manifest cross
* the private-to-public boundary.
capture quietly copy `"`source_release_dta'"' ///
    `"`public_release_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create authoritative public file: `public_release_dta'"'
}

capture quietly copy `"`source_release_csv'"' ///
    `"`public_release_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create authoritative public file: `public_release_csv'"'
}

capture quietly copy `"`source_current_dta'"' ///
    `"`public_current_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh authoritative current file: `public_current_dta'"'
}

capture quietly copy `"`source_current_csv'"' ///
    `"`public_current_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh authoritative current file: `public_current_csv'"'
}

capture quietly copy `"`source_release_yml'"' ///
    `"`public_release_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create authoritative public metadata: `public_release_yml'"'
}

capture quietly copy `"`source_current_yml'"' ///
    `"`public_current_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh authoritative current metadata: `public_current_yml'"'
}

capture quietly copy `"`source_package_yml'"' ///
    `"`public_package_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh authoritative package metadata: `public_package_yml'"'
}

capture quietly copy `"`source_reference_dta'"' ///
    `"`public_reference_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create authoritative public reference DTA: `public_reference_dta'"'
}

capture quietly copy `"`source_reference_csv'"' ///
    `"`public_reference_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create authoritative public reference CSV: `public_reference_csv'"'
}

capture quietly copy `"`source_reference_yml'"' ///
    `"`public_reference_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create authoritative public reference metadata: `public_reference_yml'"'
}

* ==============================================================================
* 11. VERIFY THE AUTHORITATIVE PUBLIC COPY -- DO NOT EDIT
* ==============================================================================

quietly _bnr_mort_s6_verify_file `"`public_release_dta'"' ///
    "`release_dta_size'" "`release_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_release_csv'"' ///
    "`release_csv_size'" "`release_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_current_dta'"' ///
    "`current_dta_size'" "`current_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_current_csv'"' ///
    "`current_csv_size'" "`current_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_release_yml'"' ///
    "`release_yml_size'" "`release_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_current_yml'"' ///
    "`current_yml_size'" "`current_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_package_yml'"' ///
    "`package_yml_size'" "`package_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_reference_dta'"' ///
    "`reference_dta_size'" "`reference_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_reference_csv'"' ///
    "`reference_csv_size'" "`reference_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`public_reference_yml'"' ///
    "`reference_yml_size'" "`reference_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

* ==============================================================================
* 12. CREATE ONE RELEASE ZIP FROM VERIFIED PUBLIC OUTPUT -- DO NOT EDIT
* ==============================================================================

* Change working directory only while creating the archive so its internal
* paths stay short and useful. The original working folder is always restored.
local original_folder `"`c(pwd)'"'

capture quietly cd `"`public_folder'"'
if _rc {
    local cd_rc = _rc
    _bnr_mort_s6_fail `cd_rc' "`release_id'" `"`private_log'"' ///
        `"Could not open the public folder to create the ZIP: `public_folder'"'
}

capture quietly zipfile ///
    "datasets/mort_burden_metrics_`release_id'.dta" ///
    "datasets/mort_burden_metrics_`release_id'.csv" ///
    "datasets/mort_burden_metrics_current.dta" ///
    "datasets/mort_burden_metrics_current.csv" ///
    "metadata/mort_burden_metrics_`release_id'.yml" ///
    "metadata/mort_burden_metrics_current.yml" ///
    "metadata/mort_burden_package.yml" ///
    "datasets/mort_monthly_reference_2015_2019.dta" ///
    "datasets/mort_monthly_reference_2015_2019.csv" ///
    "metadata/mort_monthly_reference_2015_2019.yml", ///
    saving(`"`public_zip'"', replace)
local zip_rc = _rc

if !`zip_rc' {
    local zip_files = r(archived)
}

capture quietly cd `"`original_folder'"'
local restore_folder_rc = _rc

if `zip_rc' {
    _bnr_mort_s6_fail `zip_rc' "`release_id'" `"`private_log'"' ///
        `"The release ZIP could not be created: `public_zip'"'
}

if `restore_folder_rc' {
    _bnr_mort_s6_fail `restore_folder_rc' "`release_id'" ///
        `"`private_log'"' ///
        `"The original working folder could not be restored: `original_folder'"'
}

if `zip_files' != 10 {
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        "The release ZIP did not contain all ten approved payload files."
}

capture confirm file `"`public_zip'"'
if _rc {
    _bnr_mort_s6_fail 603 "`release_id'" `"`private_log'"' ///
        `"The expected release ZIP was not found: `public_zip'"'
}

quietly checksum `"`public_zip'"'
local public_zip_size = r(filelen)
local public_zip_checksum = r(checksum)

* ==============================================================================
* 13. CREATE THE DOWNLOAD-CATALOGUE RECORD -- DO NOT EDIT
* ==============================================================================

* This is publication metadata, not an eighth analytical payload. The central
* catalogue builder later reads it. Step 6 does not run Python or edit the
* generated Downloads catalogue directly.
tempname catalogue_handle
capture file open `catalogue_handle' using `"`public_catalogue_record'"', ///
    write replace text
if _rc {
    local catalogue_rc = _rc
    _bnr_mort_s6_fail `catalogue_rc' "`release_id'" ///
        `"`private_log'"' ///
        `"Could not create the catalogue record: `public_catalogue_record'"'
}

file write `catalogue_handle' "schema: bnr_download_manifest_v1" _n
file write `catalogue_handle' "package_type: metric" _n
file write `catalogue_handle' "package_id: `package_id'" _n
file write `catalogue_handle' "release_id: `release_id'" _n
file write `catalogue_handle' "surveillance_area: Mortality" _n
file write `catalogue_handle' "domain: mortality" _n
file write `catalogue_handle' "metric_family: burden" _n
file write `catalogue_handle' "period: `selected_period'" _n
file write `catalogue_handle' "release_date: `approved_date'" _n
file write `catalogue_handle' "" _n
file write `catalogue_handle' "title: |-" _n
file write `catalogue_handle' "  Mortality burden metrics" _n
file write `catalogue_handle' "" _n
file write `catalogue_handle' "description: |-" _n
file write `catalogue_handle' ///
    "  Approved BNR mortality burden datasets and metadata for release `selected_period'." _n
file write `catalogue_handle' "" _n
file write `catalogue_handle' "downloads:" _n
file write `catalogue_handle' "  - id: `package_id'_zip" _n
file write `catalogue_handle' "    title: Full public output package" _n
file write `catalogue_handle' "    artefact_type: ZIP package" _n
file write `catalogue_handle' "    format: ZIP" _n
file write `catalogue_handle' "    file: `zip_name'" _n
file write `catalogue_handle' ///
    "    href: files/metrics/mortality/burden/`zip_name'" _n
file write `catalogue_handle' "    description: |-" _n
file write `catalogue_handle' ///
    "      Release-stamped and current mortality burden datasets with metadata." _n
file write `catalogue_handle' "    include_in_listing: true" _n
file write `catalogue_handle' "    sort_order: 30" _n
file close `catalogue_handle'

capture confirm file `"`public_catalogue_record'"'
if _rc {
    _bnr_mort_s6_fail 603 "`release_id'" `"`private_log'"' ///
        `"The expected catalogue record was not found: `public_catalogue_record'"'
}

quietly checksum `"`public_catalogue_record'"'
local catalogue_size = r(filelen)
local catalogue_checksum = r(checksum)

* ==============================================================================
* 14. REFRESH THE WEBSITE MIRROR FROM AUTHORITATIVE PUBLIC -- DO NOT EDIT
* ==============================================================================

capture quietly copy `"`public_release_dta'"' ///
    `"`website_release_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create website file: `website_release_dta'"'
}

capture quietly copy `"`public_release_csv'"' ///
    `"`website_release_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create website file: `website_release_csv'"'
}

capture quietly copy `"`public_current_dta'"' ///
    `"`website_current_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh website current file: `website_current_dta'"'
}

capture quietly copy `"`public_current_csv'"' ///
    `"`website_current_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh website current file: `website_current_csv'"'
}

capture quietly copy `"`public_release_yml'"' ///
    `"`website_release_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create website metadata: `website_release_yml'"'
}

capture quietly copy `"`public_current_yml'"' ///
    `"`website_current_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh website current metadata: `website_current_yml'"'
}

capture quietly copy `"`public_package_yml'"' ///
    `"`website_package_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not refresh website package metadata: `website_package_yml'"'
}

capture quietly copy `"`public_reference_dta'"' ///
    `"`website_reference_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create website reference DTA: `website_reference_dta'"'
}

capture quietly copy `"`public_reference_csv'"' ///
    `"`website_reference_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create website reference CSV: `website_reference_csv'"'
}

capture quietly copy `"`public_reference_yml'"' ///
    `"`website_reference_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not create website reference metadata: `website_reference_yml'"'
}

capture quietly copy `"`public_zip'"' `"`website_zip'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not copy the release ZIP to the website: `website_zip'"'
}

capture quietly copy `"`public_catalogue_record'"' ///
    `"`website_catalogue_record'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_mort_s6_fail `copy_rc' "`release_id'" `"`private_log'"' ///
        `"Could not copy the catalogue record to the website: `website_catalogue_record'"'
}

* ==============================================================================
* 15. VERIFY THE WEBSITE MIRROR -- DO NOT EDIT
* ==============================================================================

quietly _bnr_mort_s6_verify_file `"`website_release_dta'"' ///
    "`release_dta_size'" "`release_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_release_csv'"' ///
    "`release_csv_size'" "`release_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_current_dta'"' ///
    "`current_dta_size'" "`current_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_current_csv'"' ///
    "`current_csv_size'" "`current_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_release_yml'"' ///
    "`release_yml_size'" "`release_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_current_yml'"' ///
    "`current_yml_size'" "`current_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_package_yml'"' ///
    "`package_yml_size'" "`package_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_reference_dta'"' ///
    "`reference_dta_size'" "`reference_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_reference_csv'"' ///
    "`reference_csv_size'" "`reference_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_reference_yml'"' ///
    "`reference_yml_size'" "`reference_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_zip'"' ///
    "`public_zip_size'" "`public_zip_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_mort_s6_verify_file `"`website_catalogue_record'"' ///
    "`catalogue_size'" "`catalogue_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_mort_s6_fail 459 "`release_id'" `"`private_log'"' ///
        `"`verify_reason'"'
}

* ==============================================================================
* 16. SINGLE OPERATIONAL RUN SUMMARY -- DO NOT EDIT
* ==============================================================================

noisily display as text ""
noisily display as text "============================================================================="
noisily display as text "MORTALITY STEP 6: OPERATIONAL RUN SUMMARY"
noisily display as result "  Run status:             PUBLISHED"
noisily display as result "  Script version:         Pass 2"
noisily display as result "  Selected release:       `release_id'"
noisily display as result `"  Approved by:            `approved_by'"'
noisily display as result "  Approved payload files: 10"
noisily display as result "  Release ZIP:            `zip_name'"
noisily display as result "  Catalogue record:       catalogue/`catalogue_name'"
noisily display as result `"  Authoritative public:   `public_folder'"'
noisily display as result `"  Website mirror:         `website_folder'"'
noisily display as result "  Verification:           PASSED"
noisily display as result `"  Private log:            `private_log'"'
noisily display as text   "  Private controls:       approval.yml and manifest were not published"
noisily display as text   "  Next action:            Run build_download_catalogue.py, inspect the"
noisily display as text   "                          Downloads page, then commit, render and deploy."
noisily display as text "============================================================================="

}

quietly log close mort_s6
capture program drop _bnr_mort_s6_verify_file
capture program drop _bnr_mort_s6_fail

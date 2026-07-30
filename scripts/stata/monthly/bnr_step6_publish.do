*===============================================================================
* DO-FILE:     bnr_step6_publish.do
* VERSION:     1.0.4 (30 July 2026)
* PROJECT:     BNR Refit Phase 2
* WORKFLOW:    Step 6 - publish an approved metric package
*
* PURPOSE:     Promote the exact seven files approved by Step 5:
*              1. from the private public_ready folder;
*              2. to the authoritative outputs/public folder;
*              3. into one release ZIP; and
*              4. to the website-download mirror.
*
* WORKFLOW BOUNDARY:
*              Step 6 copies and verifies approved files. It does not calculate
*              metrics, apply suppression, change metadata, approve results,
*              render Quarto or deploy the website.
*
* PUBLIC FOLDER COMPATIBILITY:
*              Step 5 groups datasets under public_ready/datasets/. The existing
*              dashboard expects those files at the metric-family root. Step 6
*              maps approved datasets to metrics/cvd/burden/ and approved
*              metadata to metrics/cvd/burden/metadata/. Filenames and contents
*              are never changed.
*
* ROUTINE USE:
*              do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 1 burden
*
* DELIBERATE REPUBLICATION:
*              do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 1 burden replace
*
* IMPORTANT:
*              - Run Step 5 Approve successfully before running this file.
*              - "replace" permits republication of the same release.
*              - Stable current files are refreshed from the selected release.
*              - approval.yml and public_manifest.csv remain private controls.
*===============================================================================

version 19
clear all
set more off

*===============================================================================
* SMALL, SHARED ROUTINES
*===============================================================================

* Print one consistent failure summary after the private Step 6 log has opened.
* The routine does not claim that nothing was copied: a filesystem failure can
* occur after an earlier copy succeeded, so the operator is told to inspect the
* named public folders before rerunning.
capture program drop _bnr_step6_fail
program define _bnr_step6_fail
    version 19
    args return_code selected_release private_log reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 6: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error "  Script version:         1.0.4"
    noisily display as error "  Selected release:       `selected_release'"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `private_log'"'
    noisily display as text  "  Action required:        Correct the issue, inspect both public folders,"
    noisily display as text  "                          then rerun Step 6."
    noisily display as error "============================================================================="
    capture log close step6
    exit `return_code'
end

* Verify one file against an expected byte length and checksum.
*
* This routine is intentionally small. The main controller still names every
* approved file explicitly, while this routine prevents the same three checks
* being reimplemented twenty-four times.
capture program drop _bnr_step6_verify_file
program define _bnr_step6_verify_file, rclass
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
        return local reason `"File does not match the approved manifest: `file_path'"'
        exit
    }

    return scalar ok = 1
    return local reason ""
end

*===============================================================================
* 1. READ AND CHECK THE OPERATOR'S SELECTION
*===============================================================================

args release_year release_month metric_family replace_word

if "`release_year'" == "" | "`release_month'" == "" | ///
        "`metric_family'" == "" {
    display as error "Enter release year, release month and metric family."
    display as error "The implemented metric family is: burden"
    exit 198
}

local metric_family = lower("`metric_family'")
if "`metric_family'" != "burden" {
    display as error "Step 6 currently implements the burden family only."
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

* Convert the selection into the standard workflow names.
local year4 : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local yyyymm "`year4'`month2'"
local selected_release "`year4'-`month2'"
local release_id "cvd_`year4'_`month2'"
local package_id "cvd_burden_`release_id'"

*===============================================================================
* 2. LOAD THE STANDARD PROJECT PATHS
*===============================================================================

if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local path_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `path_rc'
    }
}

foreach required_global in BNR_REPO BNR_STATA BNR_PRIVATE ///
        BNR_STAGING BNR_PUBLIC BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

*===============================================================================
* 3. DEFINE THE PRIVATE SOURCE AND TWO PUBLIC DESTINATIONS
*===============================================================================

* Step 5 source package and its two private control files.
local staging_package ///
    "$BNR_STAGING/metrics/cvd/burden/`release_id'"
local ready_folder "`staging_package'/public_ready"
local approval_file "`ready_folder'/approval.yml"
local manifest_file "`ready_folder'/public_manifest.csv"

* Authoritative public package. Dataset files are deliberately flattened into
* the family root to preserve the existing dashboard and download paths.
local public_folder "$BNR_PUBLIC/metrics/cvd/burden"
local public_metadata "`public_folder'/metadata"

* Disposable website mirror. This has the same layout as outputs/public.
local website_folder ///
    "$BNR_REPO/site/downloads/files/metrics/cvd/burden"
local website_metadata "`website_folder'/metadata"

* Private operational log.
local private_log ///
    "$BNR_PRIVATE_LOGS/bnr_step6_publish_`yyyymm'.log"

* Approved private source files.
local source_release_dta ///
    "`ready_folder'/datasets/cvd_burden_metrics_`release_id'.dta"
local source_release_csv ///
    "`ready_folder'/datasets/cvd_burden_metrics_`release_id'.csv"
local source_current_dta ///
    "`ready_folder'/datasets/cvd_burden_metrics_current.dta"
local source_current_csv ///
    "`ready_folder'/datasets/cvd_burden_metrics_current.csv"
local source_release_yml ///
    "`ready_folder'/metadata/cvd_burden_metrics_`release_id'.yml"
local source_current_yml ///
    "`ready_folder'/metadata/cvd_burden_metrics_current.yml"
local source_package_yml ///
    "`ready_folder'/metadata/metric_package.yml"

* Authoritative public files.
local public_release_dta ///
    "`public_folder'/cvd_burden_metrics_`release_id'.dta"
local public_release_csv ///
    "`public_folder'/cvd_burden_metrics_`release_id'.csv"
local public_current_dta ///
    "`public_folder'/cvd_burden_metrics_current.dta"
local public_current_csv ///
    "`public_folder'/cvd_burden_metrics_current.csv"
local public_release_yml ///
    "`public_metadata'/cvd_burden_metrics_`release_id'.yml"
local public_current_yml ///
    "`public_metadata'/cvd_burden_metrics_current.yml"
local public_package_yml ///
    "`public_metadata'/metric_package.yml"
local zip_name "bnr_cvd_burden_`release_id'.zip"
local public_zip "`public_folder'/`zip_name'"

* Website mirror files.
local website_release_dta ///
    "`website_folder'/cvd_burden_metrics_`release_id'.dta"
local website_release_csv ///
    "`website_folder'/cvd_burden_metrics_`release_id'.csv"
local website_current_dta ///
    "`website_folder'/cvd_burden_metrics_current.dta"
local website_current_csv ///
    "`website_folder'/cvd_burden_metrics_current.csv"
local website_release_yml ///
    "`website_metadata'/cvd_burden_metrics_`release_id'.yml"
local website_current_yml ///
    "`website_metadata'/cvd_burden_metrics_current.yml"
local website_package_yml ///
    "`website_metadata'/metric_package.yml"
local website_zip "`website_folder'/`zip_name'"

* Create only the private log folder at this point. Public directories are not
* created until approval and manifest checks have passed.
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close step6
log using `"`private_log'"', text replace name(step6)

* Keep the Results window and text log operational rather than developer-facing.
* All routine code below runs quietly. Only this short heading and the final
* success/failure summary are deliberately printed.
quietly {

noisily display as text "BNR CVD STEP 6: PUBLISH APPROVED OUTPUTS"
noisily display as result "  Script version:       1.0.4"
noisily display as result "  Selected release:     `selected_release'"
noisily display as result "  Metric family:        burden"
noisily display as result "  Replace authorised:   " cond(`replace_existing', "yes", "no")

*===============================================================================
* 4. REQUIRE THE STEP 5 PUBLIC-READY PACKAGE
*===============================================================================

capture confirm file `"`approval_file'"'
if _rc {
    _bnr_step6_fail 601 "`selected_release'" `"`private_log'"' ///
        `"Step 5 approval record not found: `approval_file'"'
}

capture confirm file `"`manifest_file'"'
if _rc {
    _bnr_step6_fail 601 "`selected_release'" `"`private_log'"' ///
        `"Step 5 public manifest not found: `manifest_file'"'
}

* Fingerprint the manifest before reading approval.yml. The approval record
* contains the expected length and checksum for this exact manifest.
capture quietly checksum `"`manifest_file'"'
if _rc {
    local manifest_checksum_rc = _rc
    _bnr_step6_fail `manifest_checksum_rc' "`selected_release'" ///
        `"`private_log'"' ///
        `"The public manifest could not be checked: `manifest_file'"'
}

local actual_manifest_size = r(filelen)
local actual_manifest_checksum = r(checksum)

*===============================================================================
* 5. READ AND VALIDATE THE SMALL STEP 5 APPROVAL RECORD
*===============================================================================

* approval.yml is generated by Step 5 with one key per line. A general YAML
* parser would add an unnecessary dependency, so this section reads those
* controlled lines directly and sets one plainly named flag for each rule.
local approval_status_ok 0
local approval_package_ok 0
local approval_release_ok 0
local approval_family_ok 0
local approval_role_ok 0
local approval_review_ok 0
local approval_policy_ok 0
local approval_disclosure_ok 0
local approval_manifest_name_ok 0
local approval_payload_root_ok 0
local approval_scope_ok 0
local approval_promotion_ok 0
local approved_manifest_size .
local approved_manifest_checksum .

tempname approval_handle
file open `approval_handle' using `"`approval_file'"', read text
file read `approval_handle' approval_line

while r(eof) == 0 {
    local approval_line = strtrim(`"`approval_line'"')

    if `"`approval_line'"' == "status: approved" {
        local approval_status_ok 1
    }
    if `"`approval_line'"' == "package_id: `package_id'" {
        local approval_package_ok 1
    }
    if `"`approval_line'"' == "release_id: `release_id'" {
        local approval_release_ok 1
    }
    if `"`approval_line'"' == "metric_family: burden" {
        local approval_family_ok 1
    }
    if inlist(`"`approval_line'"', ///
            "approved_role: BNR Lead", ///
            "approved_role: BNR Analyst", ///
            "approved_role: BNR Developer") {
        local approval_role_ok 1
    }
    if `"`approval_line'"' == "review_standard: bnr_metric_review_v1" {
        local approval_review_ok 1
    }
    if `"`approval_line'"' == "disclosure_policy: bnr_sdc_v1" {
        local approval_policy_ok 1
    }
    if `"`approval_line'"' == "disclosure_check: passed" {
        local approval_disclosure_ok 1
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
    if `"`approval_line'"' == "promotion_status: pending_step_6" {
        local approval_promotion_ok 1
    }

    * The generated YAML right-aligns these two numbers. Extracting everything
    * after the colon makes the check independent of harmless spacing.
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

if !`approval_status_ok' {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "approval.yml does not record status: approved."
}
if !`approval_package_ok' | !`approval_release_ok' | ///
        !`approval_family_ok' {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "approval.yml does not match the selected release and metric family."
}
if !`approval_role_ok' {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "approval.yml does not contain an authorised BNR approval role."
}
if !`approval_review_ok' | !`approval_policy_ok' | ///
        !`approval_disclosure_ok' {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The required Step 5 review or disclosure approval is absent."
}
if !`approval_manifest_name_ok' | !`approval_payload_root_ok' | ///
        !`approval_scope_ok' | !`approval_promotion_ok' {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "approval.yml does not authorise this Step 6 manifest promotion."
}
if missing(`approved_manifest_size') | ///
        missing(`approved_manifest_checksum') {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "approval.yml does not contain a usable manifest fingerprint."
}
if `actual_manifest_size' != `approved_manifest_size' | ///
        `actual_manifest_checksum' != `approved_manifest_checksum' {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "public_manifest.csv has changed since Step 5 approval."
}

*===============================================================================
* 6. REQUIRE THE EXACT SEVEN-FILE MANIFEST CONTRACT
*===============================================================================

* The manifest has only control fields. Import every field as a string, then
* explicitly convert its two numeric fingerprint columns below.  _all is
* Stata's required spelling here; "all" causes the import command to fail.
capture quietly import delimited using `"`manifest_file'"', ///
    clear varnames(1) stringcols(_all)
if _rc {
    local import_rc = _rc
    _bnr_step6_fail `import_rc' "`selected_release'" `"`private_log'"' ///
        "public_manifest.csv could not be read (Stata return code `import_rc')."
}

capture confirm variable payload_root relative_path file_type ///
    file_size checksum
if _rc {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "public_manifest.csv does not contain the five required columns."
}

capture confirm numeric variable file_size
if _rc {
    capture quietly destring file_size, replace
    if _rc {
        _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
            "The manifest file_size column is not numeric."
    }
}

capture confirm numeric variable checksum
if _rc {
    capture quietly destring checksum, replace
    if _rc {
        _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
            "The manifest checksum column is not numeric."
    }
}

quietly count
if r(N) != 7 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The public manifest must contain exactly seven approved payload files."
}

capture quietly isid relative_path
if _rc {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The public manifest contains a duplicate relative path."
}

quietly count if payload_root != "."
if r(N) != 0 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "Every manifest payload_root value must be a single period."
}

* Check each approved relative path explicitly. Seven rows plus seven successful
* checks also prove that there are no unrecognised or missing payload rows.
quietly count if relative_path == ///
    "datasets/cvd_burden_metrics_`release_id'.dta" & file_type == "dta"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The release-stamped DTA is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/cvd_burden_metrics_`release_id'.csv" & file_type == "csv"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The release-stamped CSV is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/cvd_burden_metrics_current.dta" & file_type == "dta"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The current DTA is absent from the approved manifest."
}

quietly count if relative_path == ///
    "datasets/cvd_burden_metrics_current.csv" & file_type == "csv"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The current CSV is absent from the approved manifest."
}

quietly count if relative_path == ///
    "metadata/cvd_burden_metrics_`release_id'.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The release-stamped metadata file is absent from the approved manifest."
}

quietly count if relative_path == ///
    "metadata/cvd_burden_metrics_current.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The current metadata file is absent from the approved manifest."
}

quietly count if relative_path == ///
    "metadata/metric_package.yml" & file_type == "yml"
if r(N) != 1 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The package metadata file is absent from the approved manifest."
}


* Retain the expected fingerprints under plain, descriptive local names.
quietly summarize file_size if relative_path == ///
    "datasets/cvd_burden_metrics_`release_id'.dta", meanonly
local release_dta_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/cvd_burden_metrics_`release_id'.dta", meanonly
local release_dta_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/cvd_burden_metrics_`release_id'.csv", meanonly
local release_csv_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/cvd_burden_metrics_`release_id'.csv", meanonly
local release_csv_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/cvd_burden_metrics_current.dta", meanonly
local current_dta_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/cvd_burden_metrics_current.dta", meanonly
local current_dta_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "datasets/cvd_burden_metrics_current.csv", meanonly
local current_csv_size = r(mean)
quietly summarize checksum if relative_path == ///
    "datasets/cvd_burden_metrics_current.csv", meanonly
local current_csv_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/cvd_burden_metrics_`release_id'.yml", meanonly
local release_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/cvd_burden_metrics_`release_id'.yml", meanonly
local release_yml_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/cvd_burden_metrics_current.yml", meanonly
local current_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/cvd_burden_metrics_current.yml", meanonly
local current_yml_checksum = r(mean)

quietly summarize file_size if relative_path == ///
    "metadata/metric_package.yml", meanonly
local package_yml_size = r(mean)
quietly summarize checksum if relative_path == ///
    "metadata/metric_package.yml", meanonly
local package_yml_checksum = r(mean)


clear

*===============================================================================
* 7. VERIFY ALL SEVEN PRIVATE SOURCE FILES BEFORE COPYING ANYTHING
*===============================================================================

quietly _bnr_step6_verify_file `"`source_release_dta'"' ///
    "`release_dta_size'" "`release_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`source_release_csv'"' ///
    "`release_csv_size'" "`release_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`source_current_dta'"' ///
    "`current_dta_size'" "`current_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`source_current_csv'"' ///
    "`current_csv_size'" "`current_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`source_release_yml'"' ///
    "`release_yml_size'" "`release_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`source_current_yml'"' ///
    "`current_yml_size'" "`current_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`source_package_yml'"' ///
    "`package_yml_size'" "`package_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}


*===============================================================================
* 8. PROTECT AN ALREADY-PUBLISHED RELEASE
*===============================================================================

* Stable current files are expected to exist after the first publication and
* are always refreshed. Release-stamped files and their ZIP are protected:
* publishing the same release twice requires an explicit replace instruction.
if !`replace_existing' {
    capture confirm file `"`public_release_dta'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Release already exists. Rerun with replace only after checking: `public_release_dta'"'
    }
    capture confirm file `"`public_release_csv'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Release already exists. Rerun with replace only after checking: `public_release_csv'"'
    }
    capture confirm file `"`public_release_yml'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Release already exists. Rerun with replace only after checking: `public_release_yml'"'
    }
    capture confirm file `"`public_zip'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Release ZIP already exists. Rerun with replace only after checking: `public_zip'"'
    }

    capture confirm file `"`website_release_dta'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Website release already exists. Rerun with replace only after checking: `website_release_dta'"'
    }
    capture confirm file `"`website_release_csv'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Website release already exists. Rerun with replace only after checking: `website_release_csv'"'
    }
    capture confirm file `"`website_release_yml'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Website release already exists. Rerun with replace only after checking: `website_release_yml'"'
    }
    capture confirm file `"`website_zip'"'
    if !_rc {
        _bnr_step6_fail 602 "`selected_release'" `"`private_log'"' ///
            `"Website release ZIP already exists. Rerun with replace only after checking: `website_zip'"'
    }
}

*===============================================================================
* 9. CREATE THE TWO STANDARD PUBLIC FOLDER TREES
*===============================================================================

* mkdir does nothing harmful when a folder already exists. Each level is named
* explicitly so a future maintainer can see the public layout in the code.
capture mkdir "$BNR_PUBLIC/metrics"
capture mkdir "$BNR_PUBLIC/metrics/cvd"
capture mkdir "$BNR_PUBLIC/metrics/cvd/burden"
capture mkdir "$BNR_PUBLIC/metrics/cvd/burden/metadata"

capture mkdir "$BNR_REPO/site/downloads"
capture mkdir "$BNR_REPO/site/downloads/files"
capture mkdir "$BNR_REPO/site/downloads/files/metrics"
capture mkdir "$BNR_REPO/site/downloads/files/metrics/cvd"
capture mkdir "$BNR_REPO/site/downloads/files/metrics/cvd/burden"
capture mkdir "$BNR_REPO/site/downloads/files/metrics/cvd/burden/metadata"

quietly mata: st_local("public_folder_exists", ///
    strofreal(direxists("`public_folder'")))
quietly mata: st_local("public_metadata_exists", ///
    strofreal(direxists("`public_metadata'")))
quietly mata: st_local("website_folder_exists", ///
    strofreal(direxists("`website_folder'")))
quietly mata: st_local("website_metadata_exists", ///
    strofreal(direxists("`website_metadata'")))

if "`public_folder_exists'" != "1" | "`public_metadata_exists'" != "1" {
    _bnr_step6_fail 603 "`selected_release'" `"`private_log'"' ///
        `"The authoritative public folder tree could not be created: `public_folder'"'
}
if "`website_folder_exists'" != "1" | "`website_metadata_exists'" != "1" {
    _bnr_step6_fail 603 "`selected_release'" `"`private_log'"' ///
        `"The website-download folder tree could not be created: `website_folder'"'
}

*===============================================================================
* 10. COPY THE SEVEN APPROVED FILES TO AUTHORITATIVE PUBLIC OUTPUT
*===============================================================================

* These statements are deliberately explicit. There is no dynamic filename
* construction or recursive folder copy: only the seven manifested files cross
* the private-to-public boundary.
capture quietly copy `"`source_release_dta'"' `"`public_release_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not create authoritative public file: `public_release_dta'"'
}

capture quietly copy `"`source_release_csv'"' `"`public_release_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not create authoritative public file: `public_release_csv'"'
}

capture quietly copy `"`source_current_dta'"' `"`public_current_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh authoritative current file: `public_current_dta'"'
}

capture quietly copy `"`source_current_csv'"' `"`public_current_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh authoritative current file: `public_current_csv'"'
}

capture quietly copy `"`source_release_yml'"' `"`public_release_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not create authoritative public metadata: `public_release_yml'"'
}

capture quietly copy `"`source_current_yml'"' `"`public_current_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh authoritative current metadata: `public_current_yml'"'
}

capture quietly copy `"`source_package_yml'"' `"`public_package_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh authoritative package metadata: `public_package_yml'"'
}


*===============================================================================
* 11. VERIFY THE AUTHORITATIVE PUBLIC COPY
*===============================================================================

quietly _bnr_step6_verify_file `"`public_release_dta'"' ///
    "`release_dta_size'" "`release_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`public_release_csv'"' ///
    "`release_csv_size'" "`release_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`public_current_dta'"' ///
    "`current_dta_size'" "`current_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`public_current_csv'"' ///
    "`current_csv_size'" "`current_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`public_release_yml'"' ///
    "`release_yml_size'" "`release_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`public_current_yml'"' ///
    "`current_yml_size'" "`current_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`public_package_yml'"' ///
    "`package_yml_size'" "`package_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}


*===============================================================================
* 12. CREATE ONE RELEASE ZIP FROM THE VERIFIED PUBLIC COPY
*===============================================================================

* The working directory is changed only while creating the archive. This keeps
* short, useful relative paths inside the ZIP:
*
*   cvd_burden_metrics_....dta
*   cvd_burden_metrics_....csv
*   metadata/....
local original_folder `"`c(pwd)'"'

capture quietly cd `"`public_folder'"'
if _rc {
    local cd_rc = _rc
    _bnr_step6_fail `cd_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not open the public folder to create the ZIP: `public_folder'"'
}

capture quietly zipfile ///
    "cvd_burden_metrics_`release_id'.dta" ///
    "cvd_burden_metrics_`release_id'.csv" ///
    "cvd_burden_metrics_current.dta" ///
    "cvd_burden_metrics_current.csv" ///
    "metadata/cvd_burden_metrics_`release_id'.yml" ///
    "metadata/cvd_burden_metrics_current.yml" ///
    "metadata/metric_package.yml", ///
    saving(`"`public_zip'"', replace)
local zip_rc = _rc

if !`zip_rc' {
    local zip_files = r(archived)
}

capture quietly cd `"`original_folder'"'
local restore_folder_rc = _rc

if `zip_rc' {
    _bnr_step6_fail `zip_rc' "`selected_release'" `"`private_log'"' ///
        `"The release ZIP could not be created: `public_zip'"'
}
if `restore_folder_rc' {
    _bnr_step6_fail `restore_folder_rc' "`selected_release'" ///
        `"`private_log'"' ///
        `"The original working folder could not be restored: `original_folder'"'
}
if `zip_files' != 7 {
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        "The release ZIP did not contain all seven approved payload files."
}

capture confirm file `"`public_zip'"'
if _rc {
    _bnr_step6_fail 603 "`selected_release'" `"`private_log'"' ///
        `"The expected release ZIP was not found: `public_zip'"'
}

quietly checksum `"`public_zip'"'
local public_zip_size = r(filelen)
local public_zip_checksum = r(checksum)

*===============================================================================
* 13. REFRESH THE WEBSITE MIRROR FROM AUTHORITATIVE PUBLIC OUTPUT
*===============================================================================

* The website copy comes from outputs/public, not independently from the
* private package. This preserves the intended chain:
*
*   approved private package -> authoritative public -> disposable website
capture quietly copy `"`public_release_dta'"' ///
    `"`website_release_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not create website file: `website_release_dta'"'
}

capture quietly copy `"`public_release_csv'"' ///
    `"`website_release_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not create website file: `website_release_csv'"'
}

capture quietly copy `"`public_current_dta'"' ///
    `"`website_current_dta'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh website current file: `website_current_dta'"'
}

capture quietly copy `"`public_current_csv'"' ///
    `"`website_current_csv'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh website current file: `website_current_csv'"'
}

capture quietly copy `"`public_release_yml'"' ///
    `"`website_release_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not create website metadata: `website_release_yml'"'
}

capture quietly copy `"`public_current_yml'"' ///
    `"`website_current_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh website current metadata: `website_current_yml'"'
}

capture quietly copy `"`public_package_yml'"' ///
    `"`website_package_yml'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not refresh website package metadata: `website_package_yml'"'
}


capture quietly copy `"`public_zip'"' `"`website_zip'"', replace
if _rc {
    local copy_rc = _rc
    _bnr_step6_fail `copy_rc' "`selected_release'" `"`private_log'"' ///
        `"Could not copy the release ZIP to the website: `website_zip'"'
}

*===============================================================================
* 14. VERIFY THE WEBSITE MIRROR
*===============================================================================

quietly _bnr_step6_verify_file `"`website_release_dta'"' ///
    "`release_dta_size'" "`release_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`website_release_csv'"' ///
    "`release_csv_size'" "`release_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`website_current_dta'"' ///
    "`current_dta_size'" "`current_dta_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`website_current_csv'"' ///
    "`current_csv_size'" "`current_csv_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`website_release_yml'"' ///
    "`release_yml_size'" "`release_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`website_current_yml'"' ///
    "`current_yml_size'" "`current_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

quietly _bnr_step6_verify_file `"`website_package_yml'"' ///
    "`package_yml_size'" "`package_yml_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}


quietly _bnr_step6_verify_file `"`website_zip'"' ///
    "`public_zip_size'" "`public_zip_checksum'"
if !r(ok) {
    local verify_reason `"`r(reason)'"'
    _bnr_step6_fail 459 "`selected_release'" `"`private_log'"' ///
        `"`verify_reason'"'
}

*===============================================================================
* 15. REPORT SUCCESS
*===============================================================================

noisily display as text ""
noisily display as text "============================================================================="
noisily display as text "STEP 6: OPERATIONAL RUN SUMMARY"
noisily display as result "  Run status:             PUBLISHED"
noisily display as result "  Script version:         1.0.4"
noisily display as result "  Selected release:       `selected_release'"
noisily display as result "  Metric family:          burden"
noisily display as result "  Approved payload files: 7"
noisily display as result "  Release ZIP:            `zip_name'"
noisily display as result `"  Authoritative public:   `public_folder'"'
noisily display as result `"  Website mirror:         `website_folder'"'
noisily display as result "  Verification:           PASSED"
noisily display as result `"  Private log:            `private_log'"'
noisily display as text  "  Next action:            Commit approved public files, render and deploy"
noisily display as text  "                          the Info-Hub using the normal Git/Quarto process."
noisily display as text "============================================================================="

}

quietly log close step6

capture program drop _bnr_step6_verify_file
capture program drop _bnr_step6_fail

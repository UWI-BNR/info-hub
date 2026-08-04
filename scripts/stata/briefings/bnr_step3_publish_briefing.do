/*
* ============================================================================
 DO-FILE:     bnr_step3_publish_briefing.do
 PROJECT:     BNR info-hub
 WORKFLOW:    Briefing Step 3 - publish an approved briefing package
 VERSION:     1.0.0

 PURPOSE:
   Publish exactly the briefing products approved in Briefing Step 2.

 PUBLICATION ROUTE:
   outputs/staging/briefings/{briefing_id}
       -> outputs/public/briefings/{briefing_id}
       -> site/downloads/files/briefings/{briefing_id}

 THIS STEP DOES:
   - validates approval.yml;
   - validates public_manifest.csv and every approved file fingerprint;
   - copies only manifested files to the authoritative public package;
   - creates the requested ZIP from the authoritative public files; and
   - refreshes the disposable website-download mirror.

 THIS STEP DOES NOT:
   - rerun analysis;
   - change data, figures or metadata;
   - publish private review files;
   - create or edit a QMD;
   - render Quarto; or
   - run Git.

 COMMAND-LINE EXAMPLE:
   do "$BNR_STATA/briefings/bnr_step3_publish_briefing.do" ///
       "CVD incidence rates" 2024 1 1 publish
* ============================================================================
*/

version 19.0
set more off


* ==============================================================================
* 1. READ AND VALIDATE THE DIALOG OR COMMAND-LINE INPUTS
* ==============================================================================

args briefing_type release_year release_month briefing_version publish_confirmed

if `"`briefing_type'"' == "" | "`release_year'" == "" | ///
        "`release_month'" == "" | "`briefing_version'" == "" {
    display as error "Briefing Step 3 stopped: briefing selection is incomplete."
    display as error "Use the Step 3 dialog or see help bnr_step3_publish_briefing."
    exit 198
}

if lower(strtrim("`publish_confirmed'")) != "publish" {
    display as error "Briefing Step 3 stopped: publication was not explicitly confirmed."
    exit 198
}

foreach numeric_input in release_year release_month briefing_version {
    capture confirm integer number ``numeric_input''
    if _rc {
        display as error "Briefing Step 3 stopped: `numeric_input' must be an integer."
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    display as error "Briefing Step 3 stopped: release_month must be between 1 and 12."
    exit 198
}

if `briefing_version' < 1 {
    display as error "Briefing Step 3 stopped: briefing_version must be 1 or greater."
    exit 198
}


* ==============================================================================
* 2. CONVERT THE BRIEFING SELECTION INTO THE PACKAGE ID
* ==============================================================================

local selected_type = lower(strtrim(`"`briefing_type'"'))
local target_year = `release_year' - 1

if inlist(`"`selected_type'"', "cvd incidence rates", "incidence") {
    local briefing_id "cvd_incidence_`target_year'_v`briefing_version'"
}
else {
    display as error "Briefing Step 3 currently supports CVD incidence rates only."
    display as error "No files were published."
    exit 198
}


* ==============================================================================
* 3. LOAD AND CHECK THE STANDARD PROJECT PATHS
* ==============================================================================

if "$BNR_STATA" == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local path_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `path_rc'
    }
}

foreach required_global in BNR_REPO BNR_STATA BNR_STAGING BNR_PUBLIC {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}


* ==============================================================================
* 4. DEFINE THE PRIVATE SOURCE AND TWO PUBLIC DESTINATIONS
* ==============================================================================

local staging_package "$BNR_STAGING/briefings/`briefing_id'"
local review_folder "`staging_package'/review"
local approval_file "`review_folder'/approval.yml"
local manifest_file "`review_folder'/public_manifest.csv"

local public_package "$BNR_PUBLIC/briefings/`briefing_id'"
local website_package ///
    "$BNR_REPO/site/downloads/files/briefings/`briefing_id'"

local zip_name "bnr_`briefing_id'.zip"
local public_zip "`public_package'/`zip_name'"
local website_zip "`website_package'/`zip_name'"


* ==============================================================================
* 5. REQUIRE THE STEP 2 APPROVAL AND MANIFEST
* ==============================================================================

capture confirm file "`approval_file'"
if _rc {
    display as error "Briefing Step 3 stopped: Step 2 approval.yml not found."
    display as error "  `approval_file'"
    display as error "Complete Briefing Step 2 before publication."
    exit 601
}

capture confirm file "`manifest_file'"
if _rc {
    display as error "Briefing Step 3 stopped: public_manifest.csv not found."
    display as error "  `manifest_file'"
    exit 601
}

quietly checksum "`manifest_file'"
local actual_manifest_size = r(filelen)
local actual_manifest_checksum = r(checksum)


* ==============================================================================
* 6. READ THE SMALL STEP 2 APPROVAL RECEIPT
* ==============================================================================
* This reads only exact lines written by Briefing Step 2. It is deliberately
* not a general YAML parser and adds no new dependency.

local approval_schema_ok 0
local approval_status_ok 0
local approval_type_ok 0
local approval_package_ok 0
local approval_role_ok 0
local approval_review_ok 0
local approval_disclosure_ok 0
local approval_manifest_ok 0
local approval_payload_ok 0
local approval_scope_ok 0
local approval_promotion_ok 0
local approved_manifest_size .
local approved_manifest_checksum .
local approved_file_count .
local create_zip ""

tempname approval_handle
file open `approval_handle' using "`approval_file'", read text
file read `approval_handle' approval_line

while r(eof) == 0 {
    local approval_line = strtrim(`"`approval_line'"')

    if `"`approval_line'"' == "schema: bnr_briefing_approval_v1" {
        local approval_schema_ok 1
    }
    if `"`approval_line'"' == "status: approved" {
        local approval_status_ok 1
    }
    if `"`approval_line'"' == "package_type: briefing" {
        local approval_type_ok 1
    }
    if `"`approval_line'"' == "package_id: `briefing_id'" {
        local approval_package_ok 1
    }
    if inlist(`"`approval_line'"', ///
            "approved_role: BNR Lead", ///
            "approved_role: BNR Analyst", ///
            "approved_role: BNR Developer") {
        local approval_role_ok 1
    }
    if `"`approval_line'"' == "review_standard: bnr_briefing_review_v1" {
        local approval_review_ok 1
    }
    if `"`approval_line'"' == "disclosure_check: passed" {
        local approval_disclosure_ok 1
    }
    if `"`approval_line'"' == "public_manifest: public_manifest.csv" {
        local approval_manifest_ok 1
    }
    if `"`approval_line'"' == "payload_root: .." {
        local approval_payload_ok 1
    }
    if `"`approval_line'"' == "manifest_scope: payload_files_only" {
        local approval_scope_ok 1
    }
    if `"`approval_line'"' == "promotion_status: pending_step_3" {
        local approval_promotion_ok 1
    }

    if strpos(`"`approval_line'"', "manifest_size:") == 1 {
        local approval_value = strtrim(substr(`"`approval_line'"', 15, .))
        local approved_manifest_size = real("`approval_value'")
    }
    if strpos(`"`approval_line'"', "manifest_checksum:") == 1 {
        local approval_value = strtrim(substr(`"`approval_line'"', 19, .))
        local approved_manifest_checksum = real("`approval_value'")
    }
    if strpos(`"`approval_line'"', "approved_file_count:") == 1 {
        local approval_value = strtrim(substr(`"`approval_line'"', 21, .))
        local approved_file_count = real("`approval_value'")
    }
    if strpos(`"`approval_line'"', "create_zip:") == 1 {
        local create_zip = strtrim(substr(`"`approval_line'"', 12, .))
    }

    file read `approval_handle' approval_line
}

file close `approval_handle'


* ==============================================================================
* 7. VALIDATE THE APPROVAL RECEIPT
* ==============================================================================

if !`approval_schema_ok' {
    display as error "Briefing Step 3 stopped: approval schema is missing or invalid."
    exit 459
}

if !`approval_status_ok' {
    display as error "Briefing Step 3 stopped: approval status is not approved."
    exit 459
}

if !`approval_type_ok' {
    display as error "Briefing Step 3 stopped: approval is not for a briefing package."
    exit 459
}

if !`approval_package_ok' {
    display as error "Briefing Step 3 stopped: approval package ID does not match."
    exit 459
}

if !`approval_role_ok' {
    display as error "Briefing Step 3 stopped: approval role is not authorised."
    exit 459
}

if !`approval_review_ok' | !`approval_disclosure_ok' {
    display as error "Briefing Step 3 stopped: required review evidence is incomplete."
    exit 459
}

if !`approval_manifest_ok' | !`approval_payload_ok' | !`approval_scope_ok' {
    display as error "Briefing Step 3 stopped: approval manifest contract is invalid."
    exit 459
}

if !`approval_promotion_ok' {
    display as error "Briefing Step 3 stopped: approval is not pending Step 3 publication."
    exit 459
}

if missing(`approved_manifest_size') | missing(`approved_manifest_checksum') {
    display as error "Briefing Step 3 stopped: manifest fingerprint is missing."
    exit 459
}

if `actual_manifest_size' != `approved_manifest_size' | ///
        `actual_manifest_checksum' != `approved_manifest_checksum' {
    display as error "Briefing Step 3 stopped: public_manifest.csv changed after approval."
    display as error "Rerun the analysis with a new briefing version and approve again."
    exit 459
}

if !inlist("`create_zip'", "0", "1") {
    display as error "Briefing Step 3 stopped: create_zip is missing or invalid."
    exit 459
}


* ==============================================================================
* 8. READ AND VALIDATE THE PUBLIC MANIFEST
* ==============================================================================

capture import delimited using "`manifest_file'", clear varnames(1)
if _rc {
    local import_rc = _rc
    display as error "Briefing Step 3 stopped: public_manifest.csv could not be read."
    exit `import_rc'
}

foreach required_variable in payload_root relative_path file_type file_size checksum {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Briefing Step 3 stopped: manifest variable missing: `required_variable'"
        exit 459
    }
}

capture confirm string variable relative_path
if _rc {
    display as error "Briefing Step 3 stopped: manifest relative_path must be text."
    exit 459
}

capture confirm numeric variable file_size
if _rc {
    display as error "Briefing Step 3 stopped: manifest file_size must be numeric."
    exit 459
}

capture confirm numeric variable checksum
if _rc {
    display as error "Briefing Step 3 stopped: manifest checksum must be numeric."
    exit 459
}

quietly count
local manifest_file_count = r(N)

if `manifest_file_count' < 1 {
    display as error "Briefing Step 3 stopped: public manifest is empty."
    exit 459
}

if missing(`approved_file_count') | ///
        `manifest_file_count' != `approved_file_count' {
    display as error "Briefing Step 3 stopped: manifest file count does not match approval."
    exit 459
}

capture isid relative_path
if _rc {
    display as error "Briefing Step 3 stopped: manifest paths are not unique."
    exit 459
}


* ==============================================================================
* 9. CHECK EVERY MANIFEST PATH AND PRIVATE SOURCE FILE
* ==============================================================================
* Approved paths are restricted to four named subfolders plus three standard
* top-level files. This prevents a manifest from escaping the package root.

forvalues row = 1/`manifest_file_count' {
    local payload_root = payload_root[`row']
    local relative_path = relative_path[`row']
    local file_type = file_type[`row']
    local expected_size = file_size[`row']
    local expected_checksum = checksum[`row']

    if `"`payload_root'"' != "." {
        display as error "Briefing Step 3 stopped: invalid payload_root in manifest."
        exit 459
    }

    if `"`relative_path'"' == "" | ///
            strpos(`"`relative_path'"', "..") | ///
            strpos(`"`relative_path'"', "\") | ///
            strpos(`"`relative_path'"', ":") | ///
            substr(`"`relative_path'"', 1, 1) == "/" {
        display as error "Briefing Step 3 stopped: unsafe manifest path."
        display as error "  `relative_path'"
        exit 459
    }

    local path_allowed 0
    if inlist(`"`relative_path'"', "readme.txt", "downloads.yml") {
        local path_allowed 1
    }
    if strpos(`"`relative_path'"', "datasets/") == 1 {
        local path_allowed 1
    }
    if strpos(`"`relative_path'"', "figures/") == 1 {
        local path_allowed 1
    }
    if strpos(`"`relative_path'"', "metadata/") == 1 {
        local path_allowed 1
    }
    if strpos(`"`relative_path'"', "workbook/") == 1 {
        local path_allowed 1
    }

    if !`path_allowed' {
        display as error "Briefing Step 3 stopped: manifest path is outside the public contract."
        display as error "  `relative_path'"
        exit 459
    }

    if `"`relative_path'"' == "metadata/release_control.yml" {
        display as error "Briefing Step 3 stopped: private release control is in the manifest."
        exit 459
    }

    if !inlist(`"`file_type'"', "text", "yml", "dta", "csv", "png", "xlsx") {
        display as error "Briefing Step 3 stopped: invalid manifest file_type."
        display as error "  `file_type'"
        exit 459
    }

    local source_file "`staging_package'/`relative_path'"

    capture confirm file "`source_file'"
    if _rc {
        display as error "Briefing Step 3 stopped: approved staged file is missing."
        display as error "  `source_file'"
        exit 601
    }

    quietly checksum "`source_file'"
    if r(filelen) != `expected_size' | r(checksum) != `expected_checksum' {
        display as error "Briefing Step 3 stopped: staged file changed after approval."
        display as error "  `source_file'"
        display as error "Use a new briefing version and approve the complete package again."
        exit 459
    }
}


* ==============================================================================
* 10. PROTECT ANY EXISTING AUTHORITATIVE PUBLIC FILES
* ==============================================================================
* An existing file is acceptable only when it exactly matches the approved
* manifest. This permits recovery of a missing site mirror without permitting
* silent replacement of an approved release.

forvalues row = 1/`manifest_file_count' {
    local relative_path = relative_path[`row']
    local expected_size = file_size[`row']
    local expected_checksum = checksum[`row']
    local existing_public_file "`public_package'/`relative_path'"

    capture confirm file "`existing_public_file'"
    if !_rc {
        quietly checksum "`existing_public_file'"
        if r(filelen) != `expected_size' | r(checksum) != `expected_checksum' {
            display as error "Briefing Step 3 stopped: public release differs from approval."
            display as error "  `existing_public_file'"
            display as error "Use a new briefing version; do not overwrite this release."
            exit 459
        }
    }
}


* ==============================================================================
* 11. CREATE THE TWO STANDARD PUBLIC FOLDER TREES
* ==============================================================================
* Every level is written explicitly for handover clarity. No recursive folder
* copy or operating-system shell command is used.

capture mkdir "$BNR_PUBLIC/briefings"
capture mkdir "`public_package'"
capture mkdir "`public_package'/datasets"
capture mkdir "`public_package'/figures"
capture mkdir "`public_package'/metadata"
capture mkdir "`public_package'/workbook"

capture mkdir "$BNR_REPO/site/downloads"
capture mkdir "$BNR_REPO/site/downloads/files"
capture mkdir "$BNR_REPO/site/downloads/files/briefings"
capture mkdir "`website_package'"
capture mkdir "`website_package'/datasets"
capture mkdir "`website_package'/figures"
capture mkdir "`website_package'/metadata"
capture mkdir "`website_package'/workbook"

local original_folder `"`c(pwd)'"'

capture cd "`public_package'"
if _rc {
    display as error "Briefing Step 3 stopped: public package folder could not be created."
    display as error "  `public_package'"
    exit 603
}
capture cd `"`original_folder'"'
if _rc {
    display as error "Briefing Step 3 stopped: original working folder could not be restored."
    exit 603
}

capture cd "`website_package'"
if _rc {
    display as error "Briefing Step 3 stopped: website package folder could not be created."
    display as error "  `website_package'"
    exit 603
}
capture cd `"`original_folder'"'
if _rc {
    display as error "Briefing Step 3 stopped: original working folder could not be restored."
    exit 603
}


* ==============================================================================
* 12. COPY ONLY MANIFESTED FILES TO AUTHORITATIVE PUBLIC OUTPUT
* ==============================================================================

forvalues row = 1/`manifest_file_count' {
    local relative_path = relative_path[`row']
    local expected_size = file_size[`row']
    local expected_checksum = checksum[`row']
    local source_file "`staging_package'/`relative_path'"
    local public_file "`public_package'/`relative_path'"

    capture copy "`source_file'" "`public_file'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Briefing Step 3 stopped: authoritative public copy failed."
        display as error "  `public_file'"
        exit `copy_rc'
    }

    quietly checksum "`public_file'"
    if r(filelen) != `expected_size' | r(checksum) != `expected_checksum' {
        display as error "Briefing Step 3 stopped: authoritative copy failed verification."
        display as error "  `public_file'"
        exit 459
    }
}


* ==============================================================================
* 13. CREATE THE OPTIONAL RELEASE ZIP
* ==============================================================================
* The ZIP contains the approved payload files only. Private approval and
* disclosure-control records remain outside outputs/public and the website.

local public_zip_size .
local public_zip_checksum .

if "`create_zip'" == "1" {
    capture confirm file "`public_zip'"

    if _rc {
        local zip_file_list ""

        forvalues row = 1/`manifest_file_count' {
            local relative_path = relative_path[`row']
            local zip_file_list `"`zip_file_list' "`relative_path'""'
        }

        capture cd "`public_package'"
        if _rc {
            display as error "Briefing Step 3 stopped: public folder could not be opened for ZIP creation."
            exit 603
        }

        capture zipfile `zip_file_list', saving("`public_zip'", replace)
        local zip_rc = _rc
        local archived_files .
        if !`zip_rc' {
            local archived_files = r(archived)
        }

        capture cd `"`original_folder'"'
        local restore_folder_rc = _rc

        if `zip_rc' {
            display as error "Briefing Step 3 stopped: release ZIP could not be created."
            display as error "  `public_zip'"
            exit `zip_rc'
        }

        if `restore_folder_rc' {
            display as error "Briefing Step 3 stopped: original working folder could not be restored."
            exit `restore_folder_rc'
        }

        if `archived_files' != `manifest_file_count' {
            display as error "Briefing Step 3 stopped: ZIP file count is incomplete."
            exit 459
        }
    }

    capture confirm file "`public_zip'"
    if _rc {
        display as error "Briefing Step 3 stopped: expected release ZIP not found."
        display as error "  `public_zip'"
        exit 603
    }

    quietly checksum "`public_zip'"
    local public_zip_size = r(filelen)
    local public_zip_checksum = r(checksum)
}


* ==============================================================================
* 14. REFRESH THE DISPOSABLE WEBSITE MIRROR FROM OUTPUTS/PUBLIC
* ==============================================================================
* The website copy is always made from the authoritative public package, never
* independently from private staging.

forvalues row = 1/`manifest_file_count' {
    local relative_path = relative_path[`row']
    local expected_size = file_size[`row']
    local expected_checksum = checksum[`row']
    local public_file "`public_package'/`relative_path'"
    local website_file "`website_package'/`relative_path'"

    capture copy "`public_file'" "`website_file'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Briefing Step 3 stopped: website mirror copy failed."
        display as error "  `website_file'"
        exit `copy_rc'
    }

    quietly checksum "`website_file'"
    if r(filelen) != `expected_size' | r(checksum) != `expected_checksum' {
        display as error "Briefing Step 3 stopped: website copy failed verification."
        display as error "  `website_file'"
        exit 459
    }
}

if "`create_zip'" == "1" {
    capture copy "`public_zip'" "`website_zip'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Briefing Step 3 stopped: website ZIP copy failed."
        exit `copy_rc'
    }

    quietly checksum "`website_zip'"
    if r(filelen) != `public_zip_size' | ///
            r(checksum) != `public_zip_checksum' {
        display as error "Briefing Step 3 stopped: website ZIP failed verification."
        exit 459
    }
}


* ==============================================================================
* 15. REPORT THE COMPLETED PUBLICATION
* ==============================================================================

local zip_summary "Not requested"
if "`create_zip'" == "1" {
    local zip_summary "`zip_name'"
}

display as text _n ///
    "=============================================================================" _n ///
    "BRIEFING STEP 3: OPERATIONAL RUN SUMMARY" _n ///
    as result "  Run status:             PUBLISHED" _n ///
    as result "  Briefing package:       `briefing_id'" _n ///
    as result "  Approved payload files: `manifest_file_count'" _n ///
    as result "  Release ZIP:            `zip_summary'" _n ///
    as result "  Authoritative public:   `public_package'" _n ///
    as result "  Website mirror:         `website_package'" _n ///
    as result "  Verification:           PASSED" _n ///
    as text   "  Next action:            Review the Quarto site, then use the normal" _n ///
    as text   "                          Git and GitHub deployment process." _n ///
    "============================================================================="

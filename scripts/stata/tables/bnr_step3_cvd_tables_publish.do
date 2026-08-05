/*
===============================================================================
DO-FILE:     bnr_step3_cvd_tables_publish.do
PROJECT:     BNR Info-Hub
PURPOSE:     Table workflow Step 3: publish approved CVD tables
STATUS:      Operational production file

OVERVIEW
  This file promotes one APPROVED Table Step 2 package. It validates the
  approval receipt and all 26 public-manifest products before copying anything.

  Step 3 creates:
    - an authoritative release-stamped package under outputs/public/;
    - an authoritative latest copy;
    - a public ZIP containing datasets, workbook, metadata and readme; and
    - the disposable Quarto website mirror; and
    - one downloads.yml record for the manifest-driven Downloads catalogue.

  It deliberately does NOT:
    - calculate or suppress any table;
    - rebuild the workbook or Markdown;
    - change any approved table value, suppression decision or Markdown product;
    - amend approval.yml; or
    - render or deploy the Quarto website.

  The sole publication-layer amendment is to the copied release workbook's
  Read me status label.  This makes clear to public users that the workbook
  has been approved and published; it does not alter any table content.

INPUT
  outputs/staging/tables/cvd/cvd_tables_YYYY_MM/public_ready/
    26 manifest products, public_manifest.csv and approval.yml

OUTPUT
  outputs/public/tables/cvd/
    releases/cvd_tables_YYYY_MM/   authoritative release
    latest/                        authoritative stable copy

  site/downloads/annual/cvd/latest/   disposable website mirror

COMMAND-LINE USE
  do bnr_step3_cvd_tables_publish.do release_year release_month [replace]

EXAMPLE
  do bnr_step3_cvd_tables_publish.do 2024 1
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

args release_year release_month replace_option

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Table Step 3 stopped: release year and month are required."
    display as text  "Usage: do bnr_step3_cvd_tables_publish.do year month [replace]"
    exit 198
}

foreach numeric_input in release_year release_month {
    capture confirm integer number ``numeric_input''
    if _rc {
        display as error "Table Step 3 stopped: `numeric_input' must be an integer."
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    display as error "Table Step 3 stopped: release_month must be 1 to 12."
    exit 198
}

if "`replace_option'" != "" & lower("`replace_option'") != "replace" {
    display as error "Table Step 3 stopped: optional third argument must be replace."
    exit 198
}

local replace_release = lower("`replace_option'") == "replace"
local month2 : display %02.0f `release_month'
local package_id "cvd_tables_`release_year'_`month2'"
local month_names "January February March April May June July August September October November December"
local month_name : word `release_month' of `month_names'

local coverage_date = dofm(ym(`release_year', `release_month') + 1) - 1
local coverage : display %tdCCYY-NN-DD `coverage_date'


* =============================================================================
* C. DECLARE THE PRIVATE SOURCE AND PUBLIC TARGETS
* =============================================================================

local staging_package "$BNR_STAGING/tables/cvd/`package_id'"
local public_ready     "`staging_package'/public_ready"
local package_yml      "`public_ready'/metadata/package.yml"
local public_manifest  "`public_ready'/public_manifest.csv"
local approval_file    "`public_ready'/approval.yml"

local public_root      "$BNR_PUBLIC/tables/cvd"
local releases_root    "`public_root'/releases"
local public_release   "`releases_root'/`package_id'"
local release_build    "`releases_root'/_`package_id'_build"
local public_latest    "`public_root'/latest"
local latest_build     "`public_root'/_latest_build"

local site_root        "`localpath'/site/downloads/annual/cvd"
local site_latest      "`site_root'/latest"
local site_build       "`site_root'/_latest_build"

local release_zip_name "bnr_cvd_annual_tabulations_`release_year'_`month2'.zip"
local latest_zip_name  "bnr_cvd_annual_tabulations_latest.zip"
local download_manifest_name "downloads.yml"
local workbook_relative "workbook/workbook_cvd_annual_tabulations.xlsx"
local public_workbook_status "PUBLISHED - APPROVED FOR PUBLIC RELEASE"


* =============================================================================
* D. REQUIRE THE APPROVED STEP 2 PACKAGE
* =============================================================================

foreach required_file in ///
    "`package_yml'" ///
    "`public_manifest'" ///
    "`approval_file'" ///
    "`public_ready'/readme.txt" {

    capture confirm file "`required_file'"
    if _rc {
        display as error "Table Step 3 stopped: the approved Step 2 package is incomplete."
        display as result "Missing file: `required_file'"
        exit 601
    }
}


* =============================================================================
* E. VALIDATE PACKAGE METADATA
* =============================================================================
* Step 3 reads only the fixed key/value fields written by Step 2A. It does not
* attempt to act as a general YAML parser.

local metadata_package ""
local metadata_type ""
local metadata_status ""
local metadata_coverage ""
local approval_required ""
local publication_done ""

tempname metadata_handle
file open `metadata_handle' using "`package_yml'", read text
file read `metadata_handle' metadata_line

while r(eof) == 0 {
    local metadata_line = strtrim(`"`metadata_line'"')

    if strpos(`"`metadata_line'"', "package_id:") == 1 {
        local metadata_package = strtrim(substr(`"`metadata_line'"', 12, .))
    }
    if strpos(`"`metadata_line'"', "product_type:") == 1 {
        local metadata_type = strtrim(substr(`"`metadata_line'"', 14, .))
    }
    if strpos(`"`metadata_line'"', "status:") == 1 {
        local metadata_status = strtrim(substr(`"`metadata_line'"', 8, .))
    }
    if strpos(`"`metadata_line'"', "coverage_end:") == 1 {
        local metadata_coverage = strtrim(substr(`"`metadata_line'"', 14, .))
    }
    if strpos(`"`metadata_line'"', "approval_required:") == 1 {
        local approval_required = lower(strtrim(substr(`"`metadata_line'"', 19, .)))
    }
    if strpos(`"`metadata_line'"', "publication_performed:") == 1 {
        local publication_done = lower(strtrim(substr(`"`metadata_line'"', 23, .)))
    }

    file read `metadata_handle' metadata_line
}
file close `metadata_handle'

if `"`metadata_package'"' != "`package_id'" | ///
        `"`metadata_type'"' != "cvd_annual_tabulations" | ///
        `"`metadata_coverage'"' != "`coverage'" {
    display as error "Table Step 3 stopped: package.yml does not match the selected package."
    exit 459
}

if `"`metadata_status'"' != "public_ready_unapproved" | ///
        `"`approval_required'"' != "true" | ///
        `"`publication_done'"' != "false" {
    display as error "Table Step 3 stopped: package.yml has an unexpected workflow state."
    exit 459
}


* =============================================================================
* F. VALIDATE THE APPROVAL RECEIPT
* =============================================================================
* package.yml records the Step 2A creation state. approval.yml is the authority
* for the later approval decision.

local approval_schema ""
local approval_status ""
local approval_package ""
local approval_type ""
local approval_coverage ""
local approved_by ""
local approved_role ""
local approval_manifest ""
local approval_files ""
local approval_publish ""
local confirmed_checks 0

tempname approval_handle
file open `approval_handle' using "`approval_file'", read text
file read `approval_handle' approval_line

while r(eof) == 0 {
    local approval_line = strtrim(`"`approval_line'"')

    if strpos(`"`approval_line'"', "schema:") == 1 {
        local approval_schema = strtrim(substr(`"`approval_line'"', 8, .))
    }
    if strpos(`"`approval_line'"', "status:") == 1 {
        local approval_status = strtrim(substr(`"`approval_line'"', 8, .))
    }
    if strpos(`"`approval_line'"', "package_id:") == 1 {
        local approval_package = strtrim(substr(`"`approval_line'"', 12, .))
    }
    if strpos(`"`approval_line'"', "product_type:") == 1 {
        local approval_type = strtrim(substr(`"`approval_line'"', 14, .))
    }
    if strpos(`"`approval_line'"', "coverage_end:") == 1 {
        local approval_coverage = strtrim(substr(`"`approval_line'"', 14, .))
    }
    if strpos(`"`approval_line'"', "approved_by:") == 1 {
        local approved_by = strtrim(substr(`"`approval_line'"', 13, .))
        local approved_by = subinstr(`"`approved_by'"', char(34), "", .)
    }
    if strpos(`"`approval_line'"', "approved_role:") == 1 {
        local approved_role = strtrim(substr(`"`approval_line'"', 15, .))
    }
    if strpos(`"`approval_line'"', "manifest:") == 1 {
        local approval_manifest = strtrim(substr(`"`approval_line'"', 10, .))
    }
    if strpos(`"`approval_line'"', "manifest_required_files:") == 1 {
        local approval_files = strtrim(substr(`"`approval_line'"', 25, .))
    }
    if strpos(`"`approval_line'"', "publication_performed:") == 1 {
        local approval_publish = lower(strtrim(substr(`"`approval_line'"', 23, .)))
    }
    if inlist(`"`approval_line'"', ///
        "intended_release_and_period: true", ///
        "results_and_ytd_presentation: true", ///
        "disclosure_review: true", ///
        "publication_workbook_and_public_files: true", ///
        "publication_ready: true") {
        local confirmed_checks = `confirmed_checks' + 1
    }

    file read `approval_handle' approval_line
}
file close `approval_handle'

if `"`approval_schema'"' != "bnr_tables_approval_v1" | ///
        `"`approval_status'"' != "approved" | ///
        `"`approval_package'"' != "`package_id'" | ///
        `"`approval_type'"' != "cvd_annual_tabulations" | ///
        `"`approval_coverage'"' != "`coverage'" {
    display as error "Table Step 3 stopped: approval.yml is not valid for this package."
    exit 459
}

if `"`approved_by'"' == "" | ///
        !inlist(`"`approved_role'"', "BNR Lead", "BNR Analyst", "BNR Developer") {
    display as error "Table Step 3 stopped: approval identity or role is invalid."
    exit 459
}

if `"`approval_manifest'"' != "public_manifest.csv" | ///
        `"`approval_files'"' != "26" | ///
        `"`approval_publish'"' != "false" | ///
        `confirmed_checks' != 5 {
    display as error "Table Step 3 stopped: approval.yml is incomplete or inconsistent."
    exit 459
}


* =============================================================================
* G. VALIDATE EVERY APPROVED MANIFEST PRODUCT
* =============================================================================

import delimited using "`public_manifest'", varnames(1) ///
    stringcols(_all) clear

foreach manifest_variable in relative_path product_role required {
    capture confirm variable `manifest_variable'
    if _rc {
        display as error "Table Step 3 stopped: public_manifest.csv is malformed."
        display as text  "Missing column: `manifest_variable'"
        exit 111
    }
}

quietly count
local manifest_rows = r(N)
if `manifest_rows' != 26 {
    display as error "Table Step 3 stopped: the manifest must contain 26 products."
    exit 459
}

quietly count if strtrim(relative_path) == "" | ///
    strtrim(product_role) == "" | strtrim(required) != "1"
if r(N) > 0 {
    display as error "Table Step 3 stopped: every manifest product must be complete and required."
    exit 459
}

foreach role_count in ///
    "public_dataset 14" ///
    "download_workbook 1" ///
    "website_table 7" ///
    "package_metadata 3" ///
    "package_readme 1" {

    gettoken expected_role expected_count : role_count
    quietly count if strtrim(product_role) == "`expected_role'"
    if r(N) != `expected_count' {
        display as error "Table Step 3 stopped: unexpected `expected_role' manifest count."
        exit 459
    }
}

duplicates tag relative_path, generate(duplicate_path)
quietly count if duplicate_path > 0
if r(N) > 0 {
    display as error "Table Step 3 stopped: the manifest contains duplicate paths."
    exit 459
}
drop duplicate_path

quietly count if strpos(relative_path, "..") | ///
    substr(relative_path, 1, 1) == "/" | ///
    substr(relative_path, 1, 1) == char(92) | ///
    strpos(relative_path, ":") | strpos(relative_path, char(92))
if r(N) > 0 {
    display as error "Table Step 3 stopped: the manifest contains an unsafe path."
    exit 459
}

forvalues manifest_row = 1/`=_N' {
    local relative_file = strtrim(relative_path[`manifest_row'])
    capture confirm file "`public_ready'/`relative_file'"
    if _rc {
        display as error "Table Step 3 stopped: an approved manifest product is missing."
        display as result "`public_ready'/`relative_file'"
        exit 601
    }
}


* =============================================================================
* H. PROTECT AN EXISTING RELEASE-STAMPED PACKAGE
* =============================================================================
* The release archive is immutable by default. Replacement is available only
* as an explicit recovery action for the same approved source package.

* Create the known parent folders one level at a time. Stata's mkdir returns
* an error when a folder already exists, so these preparation calls are
* deliberately captured. The write test below is the authoritative check.
capture mkdir "`localpath'/outputs"
capture mkdir "$BNR_PUBLIC"
capture mkdir "`public_root'"
capture mkdir "`releases_root'"

tempname release_folder_test
capture file open `release_folder_test' using ///
    "`releases_root'/_bnr_step3_write_test.tmp", write text replace
if _rc {
    display as error "Table Step 3 stopped: the public release folder could not be prepared."
    display as result "`releases_root'"
    exit 693
}
file write `release_folder_test' "Table Step 3 write test" _n
file close `release_folder_test'
capture erase "`releases_root'/_bnr_step3_write_test.tmp"

local release_exists 0
capture confirm file "`public_release'/publication.yml"
if !_rc {
    local release_exists 1
}
else {
    capture mkdir "`public_release'"
    if _rc {
        local release_exists 1
    }
    else {
        shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
            "Remove-Item -LiteralPath '`public_release'' -Force -ErrorAction Stop"
        if _rc {
            display as error "Table Step 3 stopped: release target could not be checked."
            exit 693
        }
    }
}

if `release_exists' == 1 & `replace_release' == 0 {
    display as error "Table Step 3 stopped: this release-stamped package already exists."
    display as result "`public_release'"
    display as text "Use replacement only to republish this same approved package deliberately."
    exit 602
}


* =============================================================================
* I. CREATE THE COMPLETE RELEASE IN A TEMPORARY BUILD FOLDER
* =============================================================================

cap log close
log using "$BNR_PRIVATE_LOGS/`package_id'_step3.log", text replace

display as text _n "------------------------------------------------------------"
display as text    "BNR CVD TABLE WORKFLOW: STEP 3"
display as text    "------------------------------------------------------------"
display as result  "Package:          `package_id'"
display as result  "Coverage through: `coverage'"
display as result  "Approved by:      `approved_by'"
display as result  "Approver role:    `approved_role'"
display as text    "Status:           APPROVED - PROMOTION STARTED"
display as text    "------------------------------------------------------------"

* Prepare the website mirror using Stata-native folder creation. This avoids
* an unnecessary PowerShell dependency and works whether the folders are new
* or already present. A temporary marker verifies actual write access.
capture mkdir "`localpath'/site"
capture mkdir "`localpath'/site/downloads"
capture mkdir "`localpath'/site/downloads/annual"
capture mkdir "`site_root'"

tempname site_folder_test
capture file open `site_folder_test' using ///
    "`site_root'/_bnr_step3_write_test.tmp", write text replace
if _rc {
    display as error "Table Step 3 stopped: the website mirror folder could not be prepared."
    display as result "`site_root'"
    exit 693
}
file write `site_folder_test' "Table Step 3 write test" _n
file close `site_folder_test'
capture erase "`site_root'/_bnr_step3_write_test.tmp"

* Remove only a stale, explicitly named build folder from an interrupted run.
shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path -LiteralPath '`release_build'') { Remove-Item -LiteralPath '`release_build'' -Recurse -Force -ErrorAction Stop }"
if _rc {
    display as error "Table Step 3 stopped: stale release build could not be removed."
    exit 693
}

cap mkdir "`release_build'"
cap mkdir "`release_build'/datasets"
cap mkdir "`release_build'/workbook"
cap mkdir "`release_build'/tables"
cap mkdir "`release_build'/metadata"

* Copy each reviewed product named by the approved manifest. No product is
* recalculated, reformatted or renamed during this copy.
forvalues manifest_row = 1/`=_N' {
    local relative_file = strtrim(relative_path[`manifest_row'])
    capture copy "`public_ready'/`relative_file'" ///
        "`release_build'/`relative_file'"
    if _rc {
        local copy_rc = _rc
        display as error "Table Step 3 stopped: a manifest product could not be copied."
        display as result "`relative_file'"
        exit `copy_rc'
    }
}

capture copy "`public_manifest'" "`release_build'/public_manifest.csv"
if _rc {
    local manifest_copy_rc = _rc
    display as error "Table Step 3 stopped: public_manifest.csv could not be copied."
    exit `manifest_copy_rc'
}

capture copy "`approval_file'" "`release_build'/approval.yml"
if _rc {
    local approval_copy_rc = _rc
    display as error "Table Step 3 stopped: approval.yml could not be copied."
    exit `approval_copy_rc'
}


* =============================================================================
* J. MARK THE COPIED PUBLIC WORKBOOK AS PUBLISHED
* =============================================================================
* Step 2A correctly labels its staging workbook as public-ready but unapproved.
* The release copy must instead give the public reader its actual status.  This
* is a publication label only: no table value, suppression decision, formula or
* review artefact is changed.

local release_workbook "`release_build'/`workbook_relative'"
capture confirm file "`release_workbook'"
if _rc {
    display as error "Table Step 3 stopped: the publication workbook is missing from the release build."
    exit 601
}

* Open the copied workbook explicitly on its Read me sheet.  The public status
* uses plain ASCII deliberately: it is unambiguous in Excel on every machine.
capture noisily putexcel set "`release_workbook'", sheet("Read me") modify
if _rc {
    local workbook_open_rc = _rc
    display as error "Table Step 3 stopped: the publication workbook could not be opened for its status update."
    display as text  "Close the workbook if it is open, then run Step 3 again."
    exit `workbook_open_rc'
}
capture noisily putexcel B9 = ("`public_workbook_status'")
if _rc {
    local workbook_write_rc = _rc
    capture putexcel clear
    display as error "Table Step 3 stopped: the public workbook status could not be written."
    exit `workbook_write_rc'
}
capture noisily putexcel clear
if _rc {
    local workbook_close_rc = _rc
    display as error "Table Step 3 stopped: the updated public workbook could not be closed and saved."
    exit `workbook_close_rc'
}

* Read the cell back immediately.  This is a publication safeguard: if Stata
* has not saved the new label, do not promote a workbook carrying the old
* Step 2A review status.
preserve
capture import excel using "`release_workbook'", ///
    sheet("Read me") cellrange(B9:B9) allstring clear
if _rc {
    local workbook_check_rc = _rc
    restore
    display as error "Table Step 3 stopped: the public workbook status could not be verified."
    exit `workbook_check_rc'
}

local workbook_status = strtrim(B[1])
restore

if "`workbook_status'" != "`public_workbook_status'" {
    display as error "Table Step 3 stopped: the public workbook still has the wrong Read me status."
    display as result "Found: `workbook_status'"
    exit 459
}


* =============================================================================
* K. ADD THE PUBLICATION RECEIPT
* =============================================================================
* publication.yml is a Step 3 audit record. It is not an amendment to any
* reviewed Step 2A product or to the Step 2B approval receipt.

local publication_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local publication_time "`c(current_time)'"
local system_user "`c(username)'"

tempname publication
file open `publication' using "`release_build'/publication.yml", write replace text
file write `publication' "schema: bnr_tables_publication_v1" _n
file write `publication' "status: published" _n
file write `publication' "package_id: `package_id'" _n
file write `publication' "product_type: cvd_annual_tabulations" _n
file write `publication' "coverage_end: `coverage'" _n
file write `publication' "approved_by: `approved_by'" _n
file write `publication' "approved_role: `approved_role'" _n
file write `publication' "published_date: `publication_date'" _n
file write `publication' `"published_time: "`publication_time'""' _n
file write `publication' `"published_by_system_user: "`system_user'""' _n
file write `publication' "workflow_step: 3" _n
file write `publication' "manifest: public_manifest.csv" _n
file write `publication' "manifest_required_files: 26" _n
file write `publication' "release_folder: releases/`package_id'" _n
file write `publication' "download_catalogue_manifest: `download_manifest_name'" _n
file write `publication' "latest_refreshed: true" _n
file write `publication' "website_mirror_refreshed: true" _n
file write `publication' "quarto_rendered: false" _n
file close `publication'


* =============================================================================
* L. CREATE THE DOWNLOAD-CATALOGUE MANIFEST
* =============================================================================
* This publication-layer record describes the stable ZIP to the existing
* site-wide catalogue builder.  The Downloads page itself remains generated;
* it contains no hard-coded tables entry.
*
* The package_id below is deliberately stable across monthly publications.
* release_id identifies the particular approved package currently represented
* by latest/.  The href is relative to site/downloads/.

tempname download_manifest
file open `download_manifest' using ///
    "`release_build'/`download_manifest_name'", write replace text

file write `download_manifest' "schema: bnr_download_manifest_v1" _n
file write `download_manifest' "package_type: tabulation" _n
file write `download_manifest' "package_id: cvd_annual_tabulations" _n
file write `download_manifest' "release_id: `package_id'" _n
file write `download_manifest' "title: CVD annual tabulations" _n
file write `download_manifest' "surveillance_area: CVD" _n
file write `download_manifest' "domain: cvd" _n
file write `download_manifest' "period: Data through `month_name' `release_year'" _n
file write `download_manifest' "release_date: `publication_date'" _n
file write `download_manifest' "downloads:" _n
file write `download_manifest' "  - title: Complete public tabulations package" _n
file write `download_manifest' "    artefact_type: ZIP package" _n
file write `download_manifest' "    format: ZIP" _n
file write `download_manifest' "    file: `latest_zip_name'" _n
file write `download_manifest' "    href: annual/cvd/latest/`latest_zip_name'" _n
file write `download_manifest' "    description: Suppressed CVD tabulations with public datasets, workbook, metadata and readme." _n
file write `download_manifest' "    include_in_listing: true" _n
file write `download_manifest' "    sort_order: 30" _n
file close `download_manifest'


* =============================================================================
* M. CREATE THE RELEASE-STAMPED DOWNLOAD ZIP
* =============================================================================
* Markdown fragments and approval identity are operational files, not user
* download contents. The ZIP contains datasets, workbook, public metadata and
* the public readme.

local release_zip "`release_build'/`release_zip_name'"

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "Compress-Archive -LiteralPath '`release_build'/datasets','`release_build'/workbook','`release_build'/metadata','`release_build'/readme.txt' -DestinationPath '`release_zip'' -CompressionLevel Optimal -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: the public download ZIP could not be created."
    exit 603
}

capture confirm file "`release_zip'"
if _rc {
    display as error "Table Step 3 stopped: the public download ZIP was not created."
    exit 603
}

* Confirm that the ZIP contains the updated workbook, not the original Step 2A
* review copy. This happens before any public folder is replaced.
local zip_check "`releases_root'/_`package_id'_zip_check"
shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path -LiteralPath '`zip_check'') { Remove-Item -LiteralPath '`zip_check'' -Recurse -Force -ErrorAction Stop }; Expand-Archive -LiteralPath '`release_zip'' -DestinationPath '`zip_check'' -Force -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: the public ZIP could not be checked."
    exit 603
}

preserve
capture import excel using "`zip_check'/`workbook_relative'", ///
    sheet("Read me") cellrange(B9:B9) allstring clear
if _rc {
    local zip_workbook_check_rc = _rc
    restore
    display as error "Table Step 3 stopped: the workbook inside the public ZIP could not be checked."
    exit `zip_workbook_check_rc'
}
local zip_workbook_status = strtrim(B[1])
restore

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "Remove-Item -LiteralPath '`zip_check'' -Recurse -Force -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: the temporary ZIP-check folder could not be removed."
    exit 693
}

if "`zip_workbook_status'" != "`public_workbook_status'" {
    display as error "Table Step 3 stopped: the ZIP contains a workbook with the wrong Read me status."
    display as result "Found: `zip_workbook_status'"
    exit 459
}


* =============================================================================
* N. VALIDATE AND PROMOTE THE RELEASE BUILD
* =============================================================================

forvalues manifest_row = 1/`=_N' {
    local relative_file = strtrim(relative_path[`manifest_row'])
    capture confirm file "`release_build'/`relative_file'"
    if _rc {
        display as error "Table Step 3 stopped: the release build is incomplete."
        display as result "`relative_file'"
        exit 601
    }
}

foreach release_control in public_manifest.csv approval.yml publication.yml downloads.yml {
    capture confirm file "`release_build'/`release_control'"
    if _rc {
        display as error "Table Step 3 stopped: the release build lacks `release_control'."
        exit 601
    }
}

if `release_exists' == 1 {
    shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
        "Remove-Item -LiteralPath '`public_release'' -Recurse -Force -ErrorAction Stop"
    if _rc {
        display as error "Table Step 3 stopped: the existing public release could not be replaced."
        exit 693
    }
}

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "Move-Item -LiteralPath '`release_build'' -Destination '`public_release'' -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: the completed release could not be promoted."
    exit 693
}


* =============================================================================
* O. REFRESH THE AUTHORITATIVE LATEST COPY
* =============================================================================
* Build first, validate, then replace latest. This prevents a failed copy from
* destroying the existing stable package.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path -LiteralPath '`latest_build'') { Remove-Item -LiteralPath '`latest_build'' -Recurse -Force -ErrorAction Stop }; Copy-Item -LiteralPath '`public_release'' -Destination '`latest_build'' -Recurse -Force -ErrorAction Stop; Move-Item -LiteralPath '`latest_build'/`release_zip_name'' -Destination '`latest_build'/`latest_zip_name'' -Force -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: the latest build could not be created."
    exit 693
}

forvalues manifest_row = 1/`=_N' {
    local relative_file = strtrim(relative_path[`manifest_row'])
    capture confirm file "`latest_build'/`relative_file'"
    if _rc {
        display as error "Table Step 3 stopped: the latest build is incomplete."
        exit 601
    }
}
capture confirm file "`latest_build'/`latest_zip_name'"
if _rc {
    display as error "Table Step 3 stopped: the stable ZIP is missing from the latest build."
    exit 601
}
capture confirm file "`latest_build'/`download_manifest_name'"
if _rc {
    display as error "Table Step 3 stopped: latest lacks its download-catalogue manifest."
    exit 601
}

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path -LiteralPath '`public_latest'') { Remove-Item -LiteralPath '`public_latest'' -Recurse -Force -ErrorAction Stop }; Move-Item -LiteralPath '`latest_build'' -Destination '`public_latest'' -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: authoritative latest could not be refreshed."
    exit 693
}


* =============================================================================
* P. REFRESH THE DISPOSABLE WEBSITE MIRROR
* =============================================================================
* The site receives the 26 public-facing manifest products, the stable ZIP and
* its downloads.yml catalogue record. approval.yml and publication.yml remain
* in outputs/public.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path -LiteralPath '`site_build'') { Remove-Item -LiteralPath '`site_build'' -Recurse -Force -ErrorAction Stop }"
if _rc {
    display as error "Table Step 3 stopped: stale website build could not be removed."
    exit 693
}

cap mkdir "`site_build'"
cap mkdir "`site_build'/datasets"
cap mkdir "`site_build'/workbook"
cap mkdir "`site_build'/tables"
cap mkdir "`site_build'/metadata"

forvalues manifest_row = 1/`=_N' {
    local relative_file = strtrim(relative_path[`manifest_row'])
    capture copy "`public_latest'/`relative_file'" ///
        "`site_build'/`relative_file'"
    if _rc {
        local mirror_rc = _rc
        display as error "Table Step 3 stopped: a website product could not be copied."
        display as result "`relative_file'"
        exit `mirror_rc'
    }
}

capture copy "`public_latest'/`latest_zip_name'" ///
    "`site_build'/`latest_zip_name'"
if _rc {
    local zip_copy_rc = _rc
    display as error "Table Step 3 stopped: the website ZIP could not be copied."
    exit `zip_copy_rc'
}

capture copy "`public_latest'/`download_manifest_name'" ///
    "`site_build'/`download_manifest_name'"
if _rc {
    local catalogue_copy_rc = _rc
    display as error "Table Step 3 stopped: downloads.yml could not be copied to the website mirror."
    exit `catalogue_copy_rc'
}

forvalues manifest_row = 1/`=_N' {
    local relative_file = strtrim(relative_path[`manifest_row'])
    capture confirm file "`site_build'/`relative_file'"
    if _rc {
        display as error "Table Step 3 stopped: the website mirror build is incomplete."
        exit 601
    }
}
capture confirm file "`site_build'/`latest_zip_name'"
if _rc {
    display as error "Table Step 3 stopped: the website mirror lacks its stable ZIP."
    exit 601
}
capture confirm file "`site_build'/`download_manifest_name'"
if _rc {
    display as error "Table Step 3 stopped: the website mirror lacks downloads.yml."
    exit 601
}

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path -LiteralPath '`site_latest'') { Remove-Item -LiteralPath '`site_latest'' -Recurse -Force -ErrorAction Stop }; Move-Item -LiteralPath '`site_build'' -Destination '`site_latest'' -ErrorAction Stop"
if _rc {
    display as error "Table Step 3 stopped: the website mirror could not be refreshed."
    exit 693
}


* =============================================================================
* Q. FINAL OUTPUT CONTRACT CHECKS
* =============================================================================

foreach final_root in public_release public_latest site_latest {
    forvalues manifest_row = 1/`=_N' {
        local relative_file = strtrim(relative_path[`manifest_row'])
        capture confirm file "``final_root''/`relative_file'"
        if _rc {
            display as error "Table Step 3 stopped: final output validation failed."
            display as result "``final_root''/`relative_file'"
            exit 601
        }
    }
}

capture confirm file "`public_release'/`release_zip_name'"
if _rc {
    display as error "Table Step 3 stopped: release-stamped ZIP is missing."
    exit 601
}

foreach stable_root in public_latest site_latest {
    capture confirm file "``stable_root''/`latest_zip_name'"
    if _rc {
        display as error "Table Step 3 stopped: stable ZIP is missing."
        exit 601
    }

    capture confirm file "``stable_root''/`download_manifest_name'"
    if _rc {
        display as error "Table Step 3 stopped: a stable output lacks downloads.yml."
        exit 601
    }
}

capture confirm file "`public_release'/`download_manifest_name'"
if _rc {
    display as error "Table Step 3 stopped: release lacks downloads.yml."
    exit 601
}

* Reopen each workbook that a user can actually reach. Earlier versions of
* Step 3 checked only the temporary build workbook; these final checks prove
* that promotion, latest refresh and website mirroring retained the update.
foreach final_workbook_root in public_release public_latest site_latest {
    preserve
    capture import excel using "``final_workbook_root''/`workbook_relative'", ///
        sheet("Read me") cellrange(B9:B9) allstring clear
    if _rc {
        local final_workbook_check_rc = _rc
        restore
        display as error "Table Step 3 stopped: a final public workbook status could not be checked."
        display as result "``final_workbook_root''/`workbook_relative'"
        exit `final_workbook_check_rc'
    }
    local final_workbook_status = strtrim(B[1])
    restore

    if "`final_workbook_status'" != "`public_workbook_status'" {
        display as error "Table Step 3 stopped: a final public workbook has the wrong Read me status."
        display as result "File:  ``final_workbook_root''/`workbook_relative'"
        display as result "Found: `final_workbook_status'"
        exit 459
    }
}


* =============================================================================
* R. OPERATIONAL RUN SUMMARY
* =============================================================================

qui {
    noi display as text _n "============================================================"
    noi display as text    "TABLE STEP 3: OPERATIONAL RUN SUMMARY"
    noi display as text    "============================================================"
    noi display as result  "Status:           COMPLETED - PUBLISHED"
    noi display as result  "Package:          `package_id'"
    noi display as result  "Coverage through: `coverage'"
    noi display as result  "Approved by:      `approved_by'"
    noi display as result  "Approver role:    `approved_role'"
    noi display as result  "Manifest files:   26 promoted"
    noi display as result  "Public release:   `public_release'"
    noi display as result  "Public latest:    `public_latest'"
    noi display as result  "Website mirror:   `site_latest'"
    noi display as result  "Download ZIP:     `site_latest'/`latest_zip_name'"
    noi display as result  "Catalogue record: `site_latest'/`download_manifest_name'"
    noi display as result  "Workbook status:  `public_workbook_status'"
    noi display as text    "Tables changed:   NONE (release workbook status label updated)"
    noi display as text    "Quarto render:    NOT PERFORMED"
    noi display as text    "Next: render the site, check Downloads, then commit and deploy."
    noi display as text    "============================================================"
}

log close

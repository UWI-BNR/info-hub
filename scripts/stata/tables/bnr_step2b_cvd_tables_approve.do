/*
===============================================================================
DO-FILE:     bnr_step2b_cvd_tables_approve.do
PROJECT:     BNR Info-Hub
PURPOSE:     Table workflow Step 2B: approve reviewed CVD tables
STATUS:      Operational production file

OVERVIEW
  This file records the completed human review of one Table Step 2A package.
  It validates the selected private package and every required entry in its
  public manifest, then writes one small approval receipt.

  It deliberately does NOT:
    - calculate or suppress tables;
    - rebuild any Step 2A product;
    - change the public manifest;
    - copy files to outputs/public/;
    - copy files into the Quarto website; or
    - render or deploy the website.

INPUT
  outputs/staging/tables/cvd/cvd_tables_YYYY_MM/
    review/          completed Step 1 and Step 2A review materials
    public_ready/    exact suppressed products reviewed for release

OUTPUT
  public_ready/approval.yml

COMMAND-LINE USE
  The five confirmation words are mandatory safeguards:

  do bnr_step2b_cvd_tables_approve.do release_year release_month ///
      "Full name" "BNR Analyst" release results disclosure workbook ready

  The operational dialog supplies these words only after all five review
  confirmations have been selected.
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
* B. READ THE DIALOG OR COMMAND-LINE INPUTS
* =============================================================================

args release_year release_month approver_name approver_role ///
    confirmation1 confirmation2 confirmation3 confirmation4 confirmation5

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Table Step 2B stopped: release year and month are required."
    display as text  "Use the Step 2B dialog or see help bnr_step2b_cvd_tables_approve."
    exit 198
}

if `"`approver_name'"' == "" {
    display as error "Table Step 2B stopped: approver full name is required."
    exit 198
}

if `"`approver_role'"' == "" {
    display as error "Table Step 2B stopped: approver role is required."
    exit 198
}

* A quoted YAML value is written below. These two characters would make that
* deliberately simple receipt ambiguous, so the name is rejected clearly.
if strpos(`"`approver_name'"', char(34)) | ///
        strpos(`"`approver_name'"', ":") {
    display as error "Approver name must not contain a double quote or colon."
    exit 198
}


* =============================================================================
* C. VALIDATE THE SELECTED RELEASE
* =============================================================================

foreach numeric_input in release_year release_month {
    capture confirm integer number ``numeric_input''
    if _rc {
        display as error "Table Step 2B stopped: `numeric_input' must be an integer."
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    display as error "Table Step 2B stopped: release_month must be 1 to 12."
    exit 198
}

local month2 : display %02.0f `release_month'
local package_id "cvd_tables_`release_year'_`month2'"

local coverage_date = dofm(ym(`release_year', `release_month') + 1) - 1
local coverage : display %tdCCYY-NN-DD `coverage_date'


* =============================================================================
* D. VALIDATE THE FIVE HUMAN-REVIEW CONFIRMATIONS
* =============================================================================
* The dialog supplies these plainly named words only when all five boxes are
* selected. Checking the words again here protects command-line use as well.

local confirmation_words ///
    "`confirmation1' `confirmation2' `confirmation3' `confirmation4' `confirmation5'"
local confirmation_words : list retokenize confirmation_words

local release_position : list posof "release" in confirmation_words
if `release_position' == 0 {
    display as error "Approval not recorded: release and reporting period were not confirmed."
    exit 198
}

local results_position : list posof "results" in confirmation_words
if `results_position' == 0 {
    display as error "Approval not recorded: results and YTD presentation were not confirmed."
    exit 198
}

local disclosure_position : list posof "disclosure" in confirmation_words
if `disclosure_position' == 0 {
    display as error "Approval not recorded: disclosure review was not confirmed."
    exit 198
}

local workbook_position : list posof "workbook" in confirmation_words
if `workbook_position' == 0 {
    display as error "Approval not recorded: the publication workbook was not confirmed."
    exit 198
}

local ready_position : list posof "ready" in confirmation_words
if `ready_position' == 0 {
    display as error "Approval not recorded: publication readiness was not confirmed."
    exit 198
}


* =============================================================================
* E. VALIDATE AND STANDARDISE THE APPROVER ROLE
* =============================================================================

local role_lower = lower(strtrim(`"`approver_role'"'))

if !inlist(`"`role_lower'"', "bnr lead", "bnr analyst", "bnr developer") {
    display as error "Approver role must be BNR Lead, BNR Analyst or BNR Developer."
    exit 198
}

if `"`role_lower'"' == "bnr lead" {
    local approver_role "BNR Lead"
}
else if `"`role_lower'"' == "bnr analyst" {
    local approver_role "BNR Analyst"
}
else {
    local approver_role "BNR Developer"
}


* =============================================================================
* F. DECLARE THE PRIVATE PACKAGE FILES
* =============================================================================

local staging_package "$BNR_STAGING/tables/cvd/`package_id'"
local review_dir       "`staging_package'/review"
local public_ready     "`staging_package'/public_ready"
local public_metadata  "`public_ready'/metadata"

local step1_qa         "`review_dir'/qa_summary.txt"
local suppression_sum  "`review_dir'/suppression_summary.txt"
local suppression_csv  "`review_dir'/suppression_worklist.csv"
local suppression_xlsx "`review_dir'/suppression_review.xlsx"

local package_yml      "`public_metadata'/package.yml"
local disclosure_yml   "`public_metadata'/disclosure_control.yml"
local catalogue_csv    "`public_metadata'/table_catalogue.csv"
local public_manifest  "`public_ready'/public_manifest.csv"
local approval_file    "`public_ready'/approval.yml"


* =============================================================================
* G. REQUIRE THE COMPLETE STEP 2A REVIEW PACKAGE
* =============================================================================

foreach required_file in ///
    "`step1_qa'" ///
    "`suppression_sum'" ///
    "`suppression_csv'" ///
    "`suppression_xlsx'" ///
    "`package_yml'" ///
    "`disclosure_yml'" ///
    "`catalogue_csv'" ///
    "`public_manifest'" ///
    "`public_ready'/readme.txt" {

    capture confirm file "`required_file'"
    if _rc {
        display as error "Table Step 2B stopped: the Step 2A package is incomplete."
        display as result "Missing file: `required_file'"
        exit 601
    }
}


* =============================================================================
* H. PROTECT AN EXISTING APPROVAL
* =============================================================================
* Approval is never silently overwritten. If Step 2A products need correction,
* rerun Step 2A with explicit replacement; that action invalidates the receipt.

capture confirm file "`approval_file'"
if !_rc {
    display as error "Table Step 2B stopped: this package is already approved."
    display as result "`approval_file'"
    display as text "To correct the products, rerun Step 2A with replacement and review again."
    exit 602
}


* =============================================================================
* I. CHECK THE SMALL STEP 2A METADATA CONTRACT
* =============================================================================
* This is not a general YAML parser. Step 2A writes known key/value lines, and
* this block reads only the fields needed to identify an approvable package.

local metadata_package_id ""
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
        local metadata_package_id = strtrim(substr(`"`metadata_line'"', 12, .))
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

if `"`metadata_package_id'"' != "`package_id'" {
    display as error "Table Step 2B stopped: package.yml identifies a different package."
    display as text  "Selected: `package_id'"
    display as text  "Metadata: `metadata_package_id'"
    exit 459
}

if `"`metadata_status'"' != "public_ready_unapproved" {
    display as error "Table Step 2B stopped: package.yml is not public-ready and unapproved."
    display as text  "Metadata status: `metadata_status'"
    exit 459
}

if `"`metadata_coverage'"' != "`coverage'" {
    display as error "Table Step 2B stopped: package coverage does not match the selection."
    display as text  "Selected coverage: `coverage'"
    display as text  "Metadata coverage: `metadata_coverage'"
    exit 459
}

if `"`approval_required'"' != "true" | `"`publication_done'"' != "false" {
    display as error "Table Step 2B stopped: package approval/publication metadata is inconsistent."
    exit 459
}


* =============================================================================
* J. CHECK EVERY REQUIRED PUBLIC-MANIFEST ENTRY
* =============================================================================
* Step 2B does not recreate or amend the manifest. It confirms that the exact
* manifest prepared by Step 2A has valid keys and that every required product
* is present before approval is recorded.

import delimited using "`public_manifest'", varnames(1) ///
    stringcols(_all) clear

foreach manifest_variable in relative_path product_role required {
    capture confirm variable `manifest_variable'
    if _rc {
        display as error "Table Step 2B stopped: public_manifest.csv is malformed."
        display as text  "Missing column: `manifest_variable'"
        exit 111
    }
}

quietly count
local manifest_rows = r(N)
if `manifest_rows' != 26 {
    display as error "Table Step 2B stopped: public_manifest.csv does not contain 26 products."
    display as text  "Rows found: `manifest_rows'"
    exit 459
}

quietly count if strtrim(relative_path) == "" | ///
    strtrim(product_role) == "" | strtrim(required) != "1"
if r(N) > 0 {
    display as error "Table Step 2B stopped: every manifest product must be complete and required."
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
        display as error "Table Step 2B stopped: unexpected `expected_role' manifest count."
        display as text  "Expected: `expected_count'; found: " r(N)
        exit 459
    }
}

duplicates tag relative_path, generate(duplicate_path)
quietly count if duplicate_path > 0
if r(N) > 0 {
    display as error "Table Step 2B stopped: public_manifest.csv contains duplicate paths."
    exit 459
}
drop duplicate_path

quietly count if strpos(relative_path, "..") | ///
    substr(relative_path, 1, 1) == "/" | strpos(relative_path, ":")
if r(N) > 0 {
    display as error "Table Step 2B stopped: public_manifest.csv contains an unsafe path."
    exit 459
}

forvalues manifest_row = 1/`=_N' {
    if strtrim(required[`manifest_row']) == "1" {
        local relative_file = strtrim(relative_path[`manifest_row'])
        capture confirm file "`public_ready'/`relative_file'"
        if _rc {
            display as error "Table Step 2B stopped: a required public-ready file is missing."
            display as result "`public_ready'/`relative_file'"
            exit 601
        }
    }
}

quietly count if strtrim(required) == "1"
local required_files = r(N)


* =============================================================================
* K. WRITE THE APPROVAL RECEIPT LAST
* =============================================================================
* The receipt is the only package file created by Step 2B. All reviewed public
* products and their manifest remain byte-for-byte as Step 2A created them.

local approval_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local approval_time "`c(current_time)'"

cap log close
log using "$BNR_PRIVATE_LOGS/`package_id'_step2b.log", text replace

tempfile approval_temp
tempname approval
file open `approval' using "`approval_temp'", write text replace
file write `approval' "schema: bnr_tables_approval_v1" _n
file write `approval' "status: approved" _n
file write `approval' "package_id: `package_id'" _n
file write `approval' "product_type: cvd_annual_tabulations" _n
file write `approval' "coverage_end: `coverage'" _n
file write `approval' `"approved_by: "`approver_name'""' _n
file write `approval' "approved_role: `approver_role'" _n
file write `approval' "approved_date: `approval_date'" _n
file write `approval' `"approved_time: "`approval_time'""' _n
file write `approval' "workflow_step: 2b" _n
file write `approval' "confirmations:" _n
file write `approval' "  intended_release_and_period: true" _n
file write `approval' "  results_and_ytd_presentation: true" _n
file write `approval' "  disclosure_review: true" _n
file write `approval' "  publication_workbook_and_public_files: true" _n
file write `approval' "  publication_ready: true" _n
file write `approval' "manifest: public_manifest.csv" _n
file write `approval' "manifest_required_files: `required_files'" _n
file write `approval' "publication_performed: false" _n
file close `approval'

capture copy "`approval_temp'" "`approval_file'"
if _rc {
    local approval_rc = _rc
    display as error "Table Step 2B stopped: approval.yml could not be written."
    exit `approval_rc'
}

capture confirm file "`approval_file'"
if _rc {
    display as error "Table Step 2B stopped: approval.yml was not created."
    exit 603
}


* =============================================================================
* L. OPERATIONAL RUN SUMMARY
* =============================================================================

qui {
    noi display as text _n "============================================================"
    noi display as text    "TABLE STEP 2B: OPERATIONAL RUN SUMMARY"
    noi display as text    "============================================================"
    noi display as result  "Status:           COMPLETED - APPROVED, NOT PUBLISHED"
    noi display as result  "Package:          `package_id'"
    noi display as result  "Coverage through: `coverage'"
    noi display as result  "Approved by:      `approver_name'"
    noi display as result  "Approver role:    `approver_role'"
    noi display as result  "Required files:   `required_files' checked"
    noi display as result  "Approval receipt: `approval_file'"
    noi display as text    "Products changed: NONE"
    noi display as text    "Publication:      NOT PERFORMED"
    noi display as text    "Next: run Table Step 3 to promote the approved package."
    noi display as text    "============================================================"
}

log close

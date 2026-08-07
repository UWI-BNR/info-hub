/*
* ============================================================================
 DO-FILE:     bnr_step2_approve_briefing.do
 PROJECT:     BNR info-hub
 WORKFLOW:    Briefing Step 2 - review and approve a staged briefing package
 VERSION:     1.2.0

 PURPOSE:
   Record the completed human review of one briefing package created by
   Briefing Step 1.

 THIS STEP DOES:
   - checks the expected Step 1 products;
   - requires five explicit human-review confirmations;
   - creates review/public_manifest.csv;
   - completes review/disclosure_review.txt; and
   - creates review/approval.yml last.

 THIS STEP DOES NOT:
   - rerun analysis;
   - apply suppression;
   - change any staged public product;
   - publish files;
   - render Quarto; or
   - run Git.

 COMMAND-LINE EXAMPLE:
   do "$BNR_STATA/briefings/bnr_step2_approve_briefing.do" ///
       "CVD incidence rates" 2024 1 1 ///
       "Full name" "BNR Analyst" source results disclosure labels complete

 AD-HOC COMMAND-LINE EXAMPLE:
   do "$BNR_STATA/briefings/bnr_step2_approve_briefing.do" ///
       "Ad-hoc briefing" 2024 1 1 ///
       "Full name" "BNR Analyst" source results disclosure labels complete ///
       "cvd_external_request_2023_v1"
* ============================================================================
*/

version 19.0
set more off


* ==============================================================================
* 1. READ THE DIALOG OR COMMAND-LINE INPUTS
* ==============================================================================

args briefing_type release_year release_month briefing_version ///
    approver_name approver_role confirmation1 confirmation2 ///
    confirmation3 confirmation4 confirmation5 ad_hoc_briefing_id

if `"`briefing_type'"' == "" | "`release_year'" == "" | ///
        "`release_month'" == "" | "`briefing_version'" == "" {
    display as error "Briefing Step 2 stopped: briefing selection is incomplete."
    display as error "Use the Step 2 dialog or see help bnr_step2_approve_briefing."
    exit 198
}

if `"`approver_name'"' == "" {
    display as error "Briefing Step 2 stopped: approver name is required."
    exit 198
}

if `"`approver_role'"' == "" {
    display as error "Briefing Step 2 stopped: approver role is required."
    exit 198
}

if strpos(`"`approver_name'"', char(34)) | ///
        strpos(`"`approver_name'"', ":") {
    display as error "Approver name must not contain a double quote or colon."
    exit 198
}


* ==============================================================================
* 2. VALIDATE THE FIVE HUMAN-REVIEW CONFIRMATIONS
* ==============================================================================
* The dialog adds one plainly named word for each ticked box. Missing words do
* not shift positional values, and the DO file checks the same contract when it
* is run directly from the command line.

local confirmation_words ///
    "`confirmation1' `confirmation2' `confirmation3' `confirmation4' `confirmation5'"
local confirmation_words : list retokenize confirmation_words

local source_position : list posof "source" in confirmation_words
if `source_position' == 0 {
    display as error "Approval not recorded: source and reporting period were not confirmed."
    exit 198
}

local results_position : list posof "results" in confirmation_words
if `results_position' == 0 {
    display as error "Approval not recorded: analysis and results were not confirmed."
    exit 198
}

local disclosure_position : list posof "disclosure" in confirmation_words
if `disclosure_position' == 0 {
    display as error "Approval not recorded: manual disclosure review was not confirmed."
    exit 198
}

local labels_position : list posof "labels" in confirmation_words
if `labels_position' == 0 {
    display as error "Approval not recorded: labels and metadata were not confirmed."
    exit 198
}

local complete_position : list posof "complete" in confirmation_words
if `complete_position' == 0 {
    display as error "Approval not recorded: publication readiness was not confirmed."
    exit 198
}


* ==============================================================================
* 3. VALIDATE AND STANDARDISE THE APPROVER ROLE
* ==============================================================================

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


* ==============================================================================
* 4. VALIDATE THE NUMERIC BRIEFING SELECTION
* ==============================================================================

foreach numeric_input in release_year release_month briefing_version {
    capture confirm integer number ``numeric_input''
    if _rc {
        display as error "Briefing Step 2 stopped: `numeric_input' must be an integer."
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    display as error "Briefing Step 2 stopped: release_month must be between 1 and 12."
    exit 198
}

if `briefing_version' < 1 {
    display as error "Briefing Step 2 stopped: briefing_version must be 1 or greater."
    exit 198
}


* ==============================================================================
* 5. CONVERT THE BRIEFING SELECTION INTO THE PACKAGE ID
* ==============================================================================
* Routine CVD briefings analyse complete calendar years through the end of the
* year before the selected Step 3 data release.
*
* Ad-hoc analyses are intentionally not dispatched by this controller. The
* analyst runs the analyst-owned DO file directly, and supplies the exact
* package ID created in staging. The package itself is checked below.

local selected_type = lower(strtrim(`"`briefing_type'"'))
local target_year = `release_year' - 1

if inlist(`"`selected_type'"', "cvd incidence rates", "incidence") {
    local briefing_id "cvd_incidence_`target_year'_v`briefing_version'"
}
else if inlist(`"`selected_type'"', "cvd case-fatality", "case_fatality") {
    local briefing_id "cvd_case_fatality_`target_year'_v`briefing_version'"
}
else if inlist(`"`selected_type'"', "cvd length of stay", "length_of_stay") {
    local briefing_id "cvd_los_`target_year'_v`briefing_version'"
}
else if inlist(`"`selected_type'"', "ad-hoc briefing", "ad hoc briefing", "ad_hoc") {
    local briefing_id = strtrim(`"`ad_hoc_briefing_id'"')

    if `"`briefing_id'"' == "" {
        display as error "Briefing Step 2 stopped: an ad-hoc package ID is required."
        exit 198
    }

    if strlen(`"`briefing_id'"') > 80 | ///
            !regexm(`"`briefing_id'"', "^[a-z][a-z0-9_]*_v[1-9][0-9]*$") {
        display as error "Briefing Step 2 stopped: invalid ad-hoc package ID."
        display as error "Use lowercase letters, numbers and underscores, ending _v1, _v2, etc."
        exit 198
    }
}
else {
    display as error "Briefing Step 2 does not yet support this routine briefing type."
    display as error "No approval record was created."
    exit 198
}


* ==============================================================================
* 6. LOAD AND CHECK THE STANDARD PROJECT PATHS
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

foreach required_global in BNR_REPO BNR_STATA BNR_STAGING {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}


* ==============================================================================
* 7. DEFINE THE PRIVATE STAGING FILES
* ==============================================================================

local staging_package "$BNR_STAGING/briefings/`briefing_id'"
local datasets_folder "`staging_package'/datasets"
local figures_folder  "`staging_package'/figures"
local workbook_folder "`staging_package'/workbook"
local metadata_folder "`staging_package'/metadata"
local review_folder   "`staging_package'/review"

local release_control "`metadata_folder'/release_control.yml"
local briefing_yml    "`metadata_folder'/briefing.yml"
local readme_file     "`staging_package'/readme.txt"
local downloads_yml   "`staging_package'/downloads.yml"
local disclosure_flags "`review_folder'/disclosure_flags.csv"
local disclosure_review "`review_folder'/disclosure_review.txt"
local public_manifest "`review_folder'/public_manifest.csv"
local approval_file   "`review_folder'/approval.yml"


* ==============================================================================
* 8. REQUIRE THE STANDARD STEP 1 CONTROL AND PACKAGE FILES
* ==============================================================================

capture confirm file "`release_control'"
if _rc {
    display as error "Briefing Step 2 stopped: release control file not found."
    display as error "  `release_control'"
    display as error "Run Briefing Step 1 first."
    exit 601
}

capture confirm file "`briefing_yml'"
if _rc {
    display as error "Briefing Step 2 stopped: briefing metadata not found."
    display as error "  `briefing_yml'"
    exit 601
}

capture confirm file "`readme_file'"
if _rc {
    display as error "Briefing Step 2 stopped: readme.txt not found."
    display as error "  `readme_file'"
    exit 601
}

capture confirm file "`downloads_yml'"
if _rc {
    display as error "Briefing Step 2 stopped: downloads.yml not found."
    display as error "  `downloads_yml'"
    exit 601
}

capture confirm file "`disclosure_flags'"
if _rc {
    display as error "Briefing Step 2 stopped: disclosure_flags.csv not found."
    display as error "  `disclosure_flags'"
    exit 601
}

capture confirm file "`disclosure_review'"
if _rc {
    display as error "Briefing Step 2 stopped: disclosure review template not found."
    display as error "  `disclosure_review'"
    exit 601
}


* ==============================================================================
* 9. PROTECT AN EXISTING APPROVAL
* ==============================================================================
* An approved package is immutable. Corrections use a new briefing version.

capture confirm file "`approval_file'"
if !_rc {
    display as error "Briefing Step 2 stopped: this package is already approved."
    display as error "  `approval_file'"
    display as error "Use a new briefing version for any correction."
    exit 602
}


* ==============================================================================
* 10. READ THE SMALL RELEASE-CONTROL CONTRACT
* ==============================================================================
* This is not a general YAML parser. Step 1 writes the required values as one
* simple key/value line each, and this section reads only those known lines.

local control_briefing_id ""
local output_type ""
local source_dataset_id ""
local source_dataset_release ""
local source_coverage_end ""
local briefing_kind ""
local released_datasets ""
local released_figures ""
local create_workbook ""
local create_zip ""
local list_zip ""
local workbook_file ""

tempname control_handle
file open `control_handle' using "`release_control'", read text
file read `control_handle' control_line

while r(eof) == 0 {
    local control_line = strtrim(`"`control_line'"')

    if strpos(`"`control_line'"', "briefing_id:") == 1 {
        local control_briefing_id = strtrim(substr(`"`control_line'"', 13, .))
    }
    if strpos(`"`control_line'"', "output_type:") == 1 {
        local output_type = strtrim(substr(`"`control_line'"', 13, .))
    }
    if strpos(`"`control_line'"', "source_dataset_id:") == 1 {
        local source_dataset_id = strtrim(substr(`"`control_line'"', 19, .))
    }
    if strpos(`"`control_line'"', "source_dataset_release:") == 1 {
        local source_dataset_release = strtrim(substr(`"`control_line'"', 24, .))
    }
    if strpos(`"`control_line'"', "source_coverage_end:") == 1 {
        local source_coverage_end = strtrim(substr(`"`control_line'"', 21, .))
    }
    if strpos(`"`control_line'"', "briefing_kind:") == 1 {
        local briefing_kind = strtrim(substr(`"`control_line'"', 16, .))
    }
    if strpos(`"`control_line'"', "released_datasets:") == 1 {
        local released_datasets = strtrim(substr(`"`control_line'"', 19, .))
    }
    if strpos(`"`control_line'"', "released_figures:") == 1 {
        local released_figures = strtrim(substr(`"`control_line'"', 18, .))
    }
    if strpos(`"`control_line'"', "create_workbook:") == 1 {
        local create_workbook = strtrim(substr(`"`control_line'"', 17, .))
    }
    if strpos(`"`control_line'"', "create_zip:") == 1 {
        local create_zip = strtrim(substr(`"`control_line'"', 12, .))
    }
    if strpos(`"`control_line'"', "list_zip:") == 1 {
        local list_zip = strtrim(substr(`"`control_line'"', 10, .))
    }
    if strpos(`"`control_line'"', "workbook_file:") == 1 {
        local workbook_file = strtrim(substr(`"`control_line'"', 15, .))
    }

    file read `control_handle' control_line
}

file close `control_handle'


* ==============================================================================
* 11. VALIDATE THE RELEASE-CONTROL VALUES
* ==============================================================================

if `"`control_briefing_id'"' != "`briefing_id'" {
    display as error "Briefing Step 2 stopped: package ID does not match the selection."
    display as error "  Selected: `briefing_id'"
    display as error "  Control:  `control_briefing_id'"
    exit 459
}

if `"`output_type'"' != "briefing" {
    display as error "Briefing Step 2 stopped: output_type must be briefing."
    exit 459
}

if inlist(`"`selected_type'"', "ad-hoc briefing", "ad hoc briefing", "ad_hoc") & ///
        `"`briefing_kind'"' != "ad_hoc" {
    display as error "Briefing Step 2 stopped: briefing_kind must be ad_hoc."
    exit 459
}

if `"`source_dataset_id'"' == "" | ///
        `"`source_dataset_release'"' == "" | ///
        `"`source_coverage_end'"' == "" {
    display as error "Briefing Step 2 stopped: source dataset metadata are incomplete."
    exit 459
}

if !inlist("`create_workbook'", "0", "1") {
    display as error "Briefing Step 2 stopped: create_workbook must be 0 or 1."
    exit 459
}

if !inlist("`create_zip'", "0", "1") {
    display as error "Briefing Step 2 stopped: create_zip must be 0 or 1."
    exit 459
}

if !inlist("`list_zip'", "0", "1") {
    display as error "Briefing Step 2 stopped: list_zip must be 0 or 1."
    exit 459
}

if "`create_zip'" != "1" | "`list_zip'" != "1" {
    display as error "Briefing Step 2 stopped: public briefings require create_zip and list_zip set to 1."
    exit 459
}

if "`create_workbook'" == "1" & `"`workbook_file'"' == "" {
    display as error "Briefing Step 2 stopped: workbook_file is missing."
    exit 459
}


* ==============================================================================
* 12. CHECK EVERY DECLARED DATASET
* ==============================================================================

foreach dataset_id of local released_datasets {
    capture confirm file "`datasets_folder'/`dataset_id'.dta"
    if _rc {
        display as error "Briefing Step 2 stopped: declared DTA file not found."
        display as error "  `datasets_folder'/`dataset_id'.dta"
        exit 601
    }

    capture confirm file "`datasets_folder'/`dataset_id'.csv"
    if _rc {
        display as error "Briefing Step 2 stopped: declared CSV file not found."
        display as error "  `datasets_folder'/`dataset_id'.csv"
        exit 601
    }

    capture confirm file "`metadata_folder'/`dataset_id'.yml"
    if _rc {
        display as error "Briefing Step 2 stopped: dataset metadata not found."
        display as error "  `metadata_folder'/`dataset_id'.yml"
        exit 601
    }
}


* ==============================================================================
* 13. CHECK EVERY DECLARED FIGURE AND OPTIONAL WORKBOOK
* ==============================================================================

foreach figure_id of local released_figures {
    capture confirm file "`figures_folder'/`figure_id'.png"
    if _rc {
        display as error "Briefing Step 2 stopped: declared PNG figure not found."
        display as error "  `figures_folder'/`figure_id'.png"
        exit 601
    }
}

if "`create_workbook'" == "1" {
    capture confirm file "`workbook_folder'/`workbook_file'"
    if _rc {
        display as error "Briefing Step 2 stopped: requested workbook not found."
        display as error "  `workbook_folder'/`workbook_file'"
        exit 601
    }
}


* ==============================================================================
* 14. BUILD THE PUBLIC MANIFEST IN A TEMPORARY DATASET
* ==============================================================================
* Only the files posted below are approved to cross the publication boundary.
* Private review and release-control files are deliberately absent.

tempfile manifest_data manifest_temp
tempname manifest_handle

postfile `manifest_handle' str12 payload_root str180 relative_path ///
    str12 file_type double file_size double checksum ///
    using "`manifest_data'", replace

quietly checksum "`readme_file'"
post `manifest_handle' (".") ("readme.txt") ("text") ///
    (r(filelen)) (r(checksum))

quietly checksum "`downloads_yml'"
post `manifest_handle' (".") ("downloads.yml") ("yml") ///
    (r(filelen)) (r(checksum))

quietly checksum "`briefing_yml'"
post `manifest_handle' (".") ("metadata/briefing.yml") ("yml") ///
    (r(filelen)) (r(checksum))

foreach dataset_id of local released_datasets {
    quietly checksum "`datasets_folder'/`dataset_id'.dta"
    post `manifest_handle' (".") ("datasets/`dataset_id'.dta") ("dta") ///
        (r(filelen)) (r(checksum))

    quietly checksum "`datasets_folder'/`dataset_id'.csv"
    post `manifest_handle' (".") ("datasets/`dataset_id'.csv") ("csv") ///
        (r(filelen)) (r(checksum))

    quietly checksum "`metadata_folder'/`dataset_id'.yml"
    post `manifest_handle' (".") ("metadata/`dataset_id'.yml") ("yml") ///
        (r(filelen)) (r(checksum))
}

foreach figure_id of local released_figures {
    quietly checksum "`figures_folder'/`figure_id'.png"
    post `manifest_handle' (".") ("figures/`figure_id'.png") ("png") ///
        (r(filelen)) (r(checksum))
}

if "`create_workbook'" == "1" {
    quietly checksum "`workbook_folder'/`workbook_file'"
    post `manifest_handle' (".") ("workbook/`workbook_file'") ("xlsx") ///
        (r(filelen)) (r(checksum))
}

postclose `manifest_handle'

preserve
use "`manifest_data'", clear
sort relative_path
format file_size checksum %20.0f
export delimited using "`manifest_temp'", replace
local approved_file_count = _N
restore

quietly checksum "`manifest_temp'"
local manifest_size : display %20.0f r(filelen)
local manifest_checksum : display %20.0f r(checksum)


* ==============================================================================
* 15. PREPARE THE COMPLETED DISCLOSURE-REVIEW RECORD
* ==============================================================================

local approved_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
tempfile disclosure_temp
tempname disclosure_handle

file open `disclosure_handle' using "`disclosure_temp'", write text replace
file write `disclosure_handle' "BNR OCCASIONAL BRIEFING DISCLOSURE REVIEW" _n
file write `disclosure_handle' "" _n
file write `disclosure_handle' "package_id: `briefing_id'" _n
file write `disclosure_handle' "source_dataset_id: `source_dataset_id'" _n
file write `disclosure_handle' "source_dataset_release: `source_dataset_release'" _n
file write `disclosure_handle' "source_coverage_end: `source_coverage_end'" _n
file write `disclosure_handle' "reviewed_by: `approver_name'" _n
file write `disclosure_handle' "reviewed_role: `approver_role'" _n
file write `disclosure_handle' "review_date: `approved_date'" _n
file write `disclosure_handle' "" _n
file write `disclosure_handle' "datasets_reviewed: YES" _n
file write `disclosure_handle' "figures_reviewed: YES" _n
file write `disclosure_handle' "narrative_reviewed: NOT APPLICABLE - narrative QMD is outside this analytical package" _n
file write `disclosure_handle' "complementary_disclosure_considered: YES" _n
file write `disclosure_handle' "differencing_considered: YES" _n
file write `disclosure_handle' "external_information_considered: YES" _n
file write `disclosure_handle' "identifiers_checked: YES" _n
file write `disclosure_handle' "" _n
file write `disclosure_handle' "automated_flags_reviewed: YES" _n
file write `disclosure_handle' "automated_flags_action: reviewed and resolved by the approver" _n
file write `disclosure_handle' "" _n
file write `disclosure_handle' "review_comments: approval recorded through Briefing Step 2" _n
file write `disclosure_handle' "" _n
file write `disclosure_handle' "review_status: APPROVE FOR PUBLICATION" _n
file close `disclosure_handle'


* ==============================================================================
* 16. PREPARE THE MACHINE-READABLE APPROVAL RECEIPT
* ==============================================================================

tempfile approval_temp
tempname approval_handle

file open `approval_handle' using "`approval_temp'", write text replace
file write `approval_handle' "schema: bnr_briefing_approval_v1" _n
file write `approval_handle' "status: approved" _n
file write `approval_handle' "package_type: briefing" _n
file write `approval_handle' "package_id: `briefing_id'" _n
file write `approval_handle' "output_type: `output_type'" _n
if `"`briefing_kind'"' != "" {
    file write `approval_handle' "briefing_kind: `briefing_kind'" _n
}
file write `approval_handle' "source_dataset_id: `source_dataset_id'" _n
file write `approval_handle' "source_dataset_release: `source_dataset_release'" _n
file write `approval_handle' "source_coverage_end: `source_coverage_end'" _n
file write `approval_handle' "approved_by: `approver_name'" _n
file write `approval_handle' "approved_role: `approver_role'" _n
file write `approval_handle' "approved_date: `approved_date'" _n
file write `approval_handle' "review_standard: bnr_briefing_review_v1" _n
file write `approval_handle' "disclosure_check: passed" _n
file write `approval_handle' "public_manifest: public_manifest.csv" _n
file write `approval_handle' "payload_root: .." _n
file write `approval_handle' "manifest_scope: payload_files_only" _n
file write `approval_handle' "manifest_size: `manifest_size'" _n
file write `approval_handle' "manifest_checksum: `manifest_checksum'" _n
file write `approval_handle' "approved_file_count: `approved_file_count'" _n
file write `approval_handle' "create_zip: `create_zip'" _n
file write `approval_handle' "promotion_status: pending_step_3" _n
file write `approval_handle' "" _n
file write `approval_handle' "confirmations:" _n
file write `approval_handle' "  source_and_period_checked: yes" _n
file write `approval_handle' "  analysis_and_results_checked: yes" _n
file write `approval_handle' "  disclosure_review_completed: yes" _n
file write `approval_handle' "  labels_and_metadata_checked: yes" _n
file write `approval_handle' "  package_complete: yes" _n
file close `approval_handle'


* ==============================================================================
* 17. WRITE THE THREE STEP 2 CONTROL FILES
* ==============================================================================
* approval.yml is copied last. Its presence therefore means that the manifest
* and completed disclosure record were both written first.

capture copy "`manifest_temp'" "`public_manifest'", replace
if _rc {
    local copy_rc = _rc
    display as error "Briefing Step 2 stopped: public_manifest.csv could not be written."
    exit `copy_rc'
}

capture copy "`disclosure_temp'" "`disclosure_review'", replace
if _rc {
    local copy_rc = _rc
    capture erase "`public_manifest'"
    display as error "Briefing Step 2 stopped: disclosure_review.txt could not be completed."
    exit `copy_rc'
}

capture copy "`approval_temp'" "`approval_file'", replace
if _rc {
    local copy_rc = _rc
    capture erase "`public_manifest'"
    display as error "Briefing Step 2 stopped: approval.yml could not be written."
    exit `copy_rc'
}


* ==============================================================================
* 18. REPORT THE COMPLETED APPROVAL
* ==============================================================================

display as text _n ///
    "=============================================================================" _n ///
    "BRIEFING STEP 2: OPERATIONAL RUN SUMMARY" _n ///
    as result "  Run status:             APPROVED" _n ///
    as result "  Briefing package:       `briefing_id'" _n ///
    as result "  Approved by:            `approver_name'" _n ///
    as result "  Approver role:          `approver_role'" _n ///
    as result "  Approved payload files: `approved_file_count'" _n ///
    as result "  Approval record:        `approval_file'" _n ///
    as result "  Public manifest:        `public_manifest'" _n ///
    as text   "  Publication performed:  No" _n ///
    as text   "  Next action:            Run Briefing Step 3." _n ///
    "============================================================================="

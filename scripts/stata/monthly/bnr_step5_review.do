/*******************************************************************************
DO-FILE:     bnr_step5_review.do
VERSION:     2.2.0 (27 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 5 - prepare, review and record approval

PURPOSE:     Run one of two deliberately separate Step 5 actions:

             PREPARE
             - checks the completed Step 4 package;
             - creates a disclosure-controlled review candidate;
             - creates the human review workbook and supporting QA files;
             - does NOT approve, promote or publish anything.

             APPROVE
             - checks that the exact files reviewed during PREPARE are unchanged;
             - records the authorised reviewer and role;
             - creates the public_ready package;
             - writes a manifest and approval record;
             - still does NOT promote or publish anything.

HANDOVER MAP:
             Step 4 staging package
                    |
                    v
             PREPARE review files
                    |
             human review outside the code
                    |
                    v
             APPROVE exact reviewed files
                    |
                    v
             public_ready package
                    |
                    v
             Step 6 promotion and publication

IMPORTANT:    "public_ready" means approved for Step 6 processing. It does not
             mean that files have been copied to the authoritative public area
             or website.

EDITING:      Analysts should normally change only:
             - authorised approval roles, when governance changes;
             - paths in bnr_paths_LOCAL.do;
             - documented disclosure rules, only after formal agreement.

             Internal file names, fingerprints and manifest checks are part of
             the approval contract and should not be casually altered.

PREPARE:     do "$BNR_STATA/monthly/bnr_step5_review.do" ///
                 2024 2 burden prepare

             do "$BNR_STATA/monthly/bnr_step5_review.do" ///
                 2024 2 burden prepare replace

APPROVE:     do "$BNR_STATA/monthly/bnr_step5_review.do" ///
                 2024 2 burden approve ///
                 "Full name" "BNR Developer"
*******************************************************************************/

version 19
clear all
set more off

* A single failure reporter writes the same standard summary used by successful runs to the screen and log
* when a run stops after the private log has opened.
capture program drop _bnr_step5_fail
program define _bnr_step5_fail
    version 19
    args return_code action release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "STEP 5: OPERATIONAL RUN SUMMARY"
    noisily display as error "  Run status:             Did not complete"
    noisily display as error "  Script version:         2.2.0"
    noisily display as error "  Selected release:       `release_id'"
    noisily display as error "  Action:                 `action'"
    noisily display as error `"  Reason:                 `reason'"'
    noisily display as error `"  Private log:            `log_path'"'
    noisily display as text  "  Action required:        Correct the issue and rerun Step 5."
    noisily display as text  "  Publication boundary:   No approval or public output was created."
    noisily display as error "============================================================================="
    capture log close step5
    exit `return_code'
end

* Write the approval record in one captured operation.  Names and roles are
* plain YAML scalars, avoiding fragile quote-generation syntax.
capture program drop _bnr_step5_write_approval
program define _bnr_step5_write_approval
    version 19
    args approval_path package_id release_id approver_name approver_role ///
        approved_date manifest_size manifest_checksum

    tempname approval_yml
    file open `approval_yml' using `"`approval_path'"', write text replace
    file write `approval_yml' "schema: bnr_approval_v1" _n
    file write `approval_yml' "status: approved" _n
    file write `approval_yml' "package_id: `package_id'" _n
    file write `approval_yml' "release_id: `release_id'" _n
    file write `approval_yml' "metric_family: burden" _n
    file write `approval_yml' "approved_by: `approver_name'" _n
    file write `approval_yml' "approved_role: `approver_role'" _n
    file write `approval_yml' "approved_date: `approved_date'" _n
    file write `approval_yml' "review_standard: bnr_metric_review_v1" _n
    file write `approval_yml' "disclosure_policy: bnr_sdc_v1" _n
    file write `approval_yml' "disclosure_check: passed" _n
    file write `approval_yml' ///
        "public_ready_manifest: public_manifest.csv" _n
    file write `approval_yml' "payload_root: ." _n
    file write `approval_yml' "manifest_scope: payload_files_only" _n
    file write `approval_yml' "manifest_size: `manifest_size'" _n
    file write `approval_yml' "manifest_checksum: `manifest_checksum'" _n
    file write `approval_yml' "promotion_status: pending_step_6" _n
    file close `approval_yml'
end

local command_line `"`0'"'
gettoken release_year remainder : command_line
gettoken release_month remainder : remainder
gettoken metric_family remainder : remainder
gettoken action remainder : remainder
local remainder : list retokenize remainder

local metric_family = lower("`metric_family'")
local action = lower("`action'")

if `"`release_year'"' == "" | `"`release_month'"' == "" | ///
        `"`metric_family'"' == "" | `"`action'"' == "" {
    display as error "Year, month, metric family and action are required."
    exit 198
}

* Each Step 5 operation is deliberately one metric family/package. The dialog
* will later run selected families as separate operations, retaining a distinct
* review workbook, approval and promotion record for each package.
if "`metric_family'" != "burden" {
    display as error "Step 5 currently implements the burden family only."
    display as error "Planned families are visible but disabled in the dialog."
    exit 198
}

if !inlist("`action'", "prepare", "approve") {
    display as error "Step 5 action must be prepare or approve."
    exit 198
}

local replace_existing 0
local approver_name ""
local approver_role ""

if "`action'" == "prepare" {
    if `"`remainder'"' != "" {
        if lower(`"`remainder'"') != "replace" {
            display as error "The only optional prepare argument is replace."
            exit 198
        }
        local replace_existing 1
    }
}
else {
    gettoken approver_name remainder : remainder
    gettoken approver_role remainder : remainder
    local remainder : list retokenize remainder
    local approver_name = strtrim(`"`approver_name'"')
    local approver_role = strtrim(`"`approver_role'"')

    if `"`approver_name'"' == "" | `"`approver_role'"' == "" | ///
            `"`remainder'"' != "" {
        display as error ///
            `"Approve requires a full name and one authorised BNR role."'
        exit 198
    }

    local role_lower = lower(strtrim(`"`approver_role'"'))
    if !inlist(`"`role_lower'"', "bnr lead", "bnr analyst", ///
            "bnr developer") {
        display as error ///
            "Approver role must be BNR Lead, BNR Analyst or BNR Developer."
        exit 198
    }
    if strpos(`"`approver_name'"', char(34)) {
        display as error "Approver name must not contain a double quote."
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
}

* ---------------------------------------------------------------------------
* Paths and release identity
* ---------------------------------------------------------------------------

if `"$BNR_STATA"' == "" {
    capture noisily do ///
        "C:/yoshimi-hot/output/analyse-bnr/info-hub/scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

foreach required_global in BNR_STATA BNR_PRIVATE BNR_STAGING BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}


local today_iso : display %tdCCYY-NN-DD ///
    daily("`c(current_date)'", "DMY")

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

* Convert the analyst's year and month into the exact forms used throughout
* the workflow. These names are kept visible here so future analysts can trace
* every generated path without searching through several helper files.
local year4 : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"
local release_id "cvd_`year4'_`month2'"
local package_id "cvd_burden_`release_id'"

* ---------------------------------------------------------------------------
* FILE MAP
*
* Step 4 provides the private metric dataset, QA file and package metadata.
* PREPARE writes only to review/.
* APPROVE writes only to public_ready/.
* Step 5 never writes to the authoritative public or website folders.
* ---------------------------------------------------------------------------

local package_dir ///
    "$BNR_STAGING/metrics/cvd/burden/`release_id'"
local private_dta ///
    "`package_dir'/datasets/cvd_burden_metrics_`release_id'.dta"
local step4_qa ///
    "`package_dir'/review/cvd_burden_qa_`release_id'.csv"
local step4_meta "`package_dir'/metadata/metric_package.yml"

local review_dir "`package_dir'/review"
local review_candidate "`review_dir'/step5_candidate.dta"
local review_disclosure_qa "`review_dir'/step5_disclosure_qa.csv"
local review_basis "`review_dir'/step5_review_basis.csv"
local review_workbook "`review_dir'/step5_review.xlsx"

local ready_dir "`package_dir'/public_ready"
local ready_data "`ready_dir'/datasets"
local ready_meta "`ready_dir'/metadata"

local public_release_dta ///
    "`ready_data'/cvd_burden_metrics_`release_id'.dta"
local public_release_csv ///
    "`ready_data'/cvd_burden_metrics_`release_id'.csv"
local public_current_dta ///
    "`ready_data'/cvd_burden_metrics_current.dta"
local public_current_csv ///
    "`ready_data'/cvd_burden_metrics_current.csv"
local public_release_yml ///
    "`ready_meta'/cvd_burden_metrics_`release_id'.yml"
local public_current_yml ///
    "`ready_meta'/cvd_burden_metrics_current.yml"
local public_package_yml "`ready_meta'/metric_package.yml"
local disclosure_qa "`ready_dir'/disclosure_qa.csv"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"
local output_log ///
    "$BNR_PRIVATE_LOGS/bnr_cvd_review_`action'_`period'.log"

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close step5
log using `"`output_log'"', text replace name(step5)

* Keep the Results window and text log operational rather than developer-facing.
* All routine code below runs quietly. Only the short run heading and the single
* final success/failure block are printed deliberately.
quietly {

noisily display as text "BNR CVD STEP 5: HUMAN REVIEW AND APPROVAL"
noisily display as result "  Script version:   2.2.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Metric family:    burden"
noisily display as result "  Action:           `action'"

* The action branches set these values only after all required work succeeds.
* One concise summary is printed below both branches. Detailed filenames remain
* in the workbook, metadata and manifest, where reviewers can inspect them.
local summary_status ""
local summary_next ""
local summary_main_file ""
local summary_candidate ""
local summary_qa ""
local summary_basis ""
local summary_ready ""
local summary_manifest ""
local summary_approval ""

* ---------------------------------------------------------------------------
* PREPARE
* ---------------------------------------------------------------------------

if "`action'" == "prepare" {

    foreach required_file in `"`private_dta'"' `"`step4_qa'"' `"`step4_meta'"' {
        capture confirm file `"`required_file'"'
        if _rc {
            _bnr_step5_fail 601 "`action'" "`release_id'" ///
                `"`output_log'"' `"Required completed Step 4 file not found: `required_file'"'
            exit _rc
        }
    }

    * PREPARE normally refuses to overwrite any earlier review output. Each
    * file is checked explicitly so a mixed-skill analyst can see exactly which
    * artefacts define a completed PREPARE run.
    foreach output_file in ///
            `"`review_candidate'"' ///
            `"`review_disclosure_qa'"' ///
            `"`review_basis'"' ///
            `"`review_workbook'"' {
        capture confirm file `"`output_file'"'
        if !_rc & !`replace_existing' {
            _bnr_step5_fail 602 "`action'" "`release_id'" ///
                `"`output_log'"' ///
                `"Review output already exists: `output_file'. Use prepare replace only for a deliberate rerun."'
            exit _rc
        }
    }

    * A previous approval or public_ready payload must also block a routine
    * PREPARE rerun. Otherwise an analyst could accidentally review one version
    * while an older approved package remains beside it.
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
            `"`disclosure_qa'"' {
        capture confirm file `"`output_file'"'
        if !_rc & !`replace_existing' {
            _bnr_step5_fail 602 "`action'" "`release_id'" ///
                `"`output_log'"' ///
                `"An approval or public-ready file already exists. Use prepare replace only to invalidate and rebuild it."'
            exit _rc
        }
    }

    * PREPARE REPLACE deliberately invalidates the complete earlier Step 5
    * state. The files are listed explicitly rather than hidden behind a list of
    * local names. This is longer, but much easier to audit and hand over.
    if `replace_existing' {
        capture erase `"`approval'"'
        capture erase `"`manifest'"'
        capture erase `"`review_candidate'"'
        capture erase `"`review_disclosure_qa'"'
        capture erase `"`review_basis'"'
        capture erase `"`review_workbook'"'
        capture erase `"`public_release_dta'"'
        capture erase `"`public_release_csv'"'
        capture erase `"`public_current_dta'"'
        capture erase `"`public_current_csv'"'
        capture erase `"`public_release_yml'"'
        capture erase `"`public_current_yml'"'
        capture erase `"`public_package_yml'"'
        capture erase `"`disclosure_qa'"'

        * rmdir succeeds only when the folder is empty. capture is intentional:
        * an absent folder is not an error during a deliberate rebuild.
        capture rmdir "`ready_data'"
        capture rmdir "`ready_meta'"
        capture rmdir "`ready_dir'"
    }

    * STEP 5 TRUSTS ONLY A PASSING STEP 4 PACKAGE
    * The Step 4 QA file is checked before any disclosure-controlled candidate
    * is created. A failed calculation package must never proceed to review.
    import delimited using `"`step4_qa'"', varnames(1) clear
    foreach variable in check result detail {
        capture confirm variable `variable'
        if _rc {
            _bnr_step5_fail 111 "`action'" "`release_id'" ///
                `"`output_log'"' "Step 4 QA file has an invalid structure."
            exit _rc
        }
    }
    quietly count if result != "PASS"
    if r(N) {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' "Step 4 QA contains a non-passing check."
        exit _rc
    }

    use `"`private_dta'"', clear
    quietly count if release_id != "`release_id'"
    if r(N) {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' ///
            "The selected Step 4 dataset has the wrong release_id."
        exit _rc
    }
    quietly count
    local private_rows = r(N)

    * CREATE THE DISCLOSURE-CONTROLLED CANDIDATE
    * The helper keeps all aggregate rows but removes exact numeric content from
    * rows that require suppression. It also creates a machine-readable QA file.
    tempfile step5_qa
    capture quietly do "$BNR_STATA/common/bnr_step5_suppress.do" ///
        `"`private_dta'"' `"`review_candidate'"' `"`step5_qa'"' ///
        "`release_id'"
    if _rc {
        local suppression_rc = _rc
        _bnr_step5_fail `suppression_rc' "`action'" "`release_id'" ///
            `"`output_log'"' ///
            "The disclosure-controlled review candidate was not created."
        exit _rc
    }

    use `"`review_candidate'"', clear
    quietly count
    local candidate_rows = r(N)
    quietly count if suppression_status == "primary"
    local primary_rows = r(N)
    quietly count if suppression_status == "secondary"
    local secondary_rows = r(N)
    quietly count if suppression_status == "derived"
    local derived_rows = r(N)
    quietly count if suppression_status != "none"
    local suppressed_rows = r(N)

    use `"`step5_qa'"', clear
    export delimited using `"`review_disclosure_qa'"', replace

    * Fingerprint the exact source and disclosure-controlled candidate reviewed.
    * Keep these five postings explicit. It is more verbose than a nested-macro
    * loop but is easier to audit and avoids fragile macro expansion.
    tempfile review_basis_dta
    tempname basis_handle
    postfile `basis_handle' str28 file_role str244 file_path ///
        double file_size double checksum using `"`review_basis_dta'"', replace

    quietly checksum `"`private_dta'"'
    post `basis_handle' ("private_metric_dataset") (`"`private_dta'"') ///
        (r(filelen)) (r(checksum))

    quietly checksum `"`step4_qa'"'
    post `basis_handle' ("step4_qa") (`"`step4_qa'"') ///
        (r(filelen)) (r(checksum))

    quietly checksum `"`step4_meta'"'
    post `basis_handle' ("step4_package_metadata") (`"`step4_meta'"') ///
        (r(filelen)) (r(checksum))

    quietly checksum `"`review_candidate'"'
    post `basis_handle' ("reviewed_public_candidate") ///
        (`"`review_candidate'"') (r(filelen)) (r(checksum))

    quietly checksum `"`review_disclosure_qa'"'
    post `basis_handle' ("step5_disclosure_qa") ///
        (`"`review_disclosure_qa'"') (r(filelen)) (r(checksum))
    postclose `basis_handle'

    use `"`review_basis_dta'"', clear
    format file_size checksum %20.0f
    export delimited using `"`review_basis'"', replace

    * -----------------------------------------------------------------------
    * Concise private reviewer workbook
    * -----------------------------------------------------------------------

    clear
    set obs 12
    generate str32 review_item = ""
    generate str244 detail = ""
    replace review_item = "Review status" in 1
    replace detail = "READY FOR HUMAN REVIEW" in 1
    replace review_item = "Package" in 2
    replace detail = "`package_id'" in 2
    replace review_item = "Release" in 3
    replace detail = "`release_id'" in 3
    replace review_item = "Metric family" in 4
    replace detail = "burden" in 4
    replace review_item = "Private rows" in 5
    replace detail = "`private_rows'" in 5
    replace review_item = "Reviewed candidate rows" in 6
    replace detail = "`candidate_rows'" in 6
    replace review_item = "Suppressed rows" in 7
    replace detail = "`suppressed_rows'" in 7
    replace review_item = "Approval covers" in 8
    replace detail = ///
        "Analytical plausibility, disclosure control, interpretation and publication readiness." in 8
    replace review_item = "Check private results" in 9
    replace detail = ///
        "Confirm values and period completeness are plausible. This sheet remains private." in 9
    replace review_item = "Check suppression" in 10
    replace detail = ///
        "Confirm every suppressed candidate row is appropriate and contains no exact value." in 10
    replace review_item = "Public-ready timing" in 11
    replace detail = ///
        "The public_ready folder will be created only by a successful approval action." in 11
    replace review_item = "If not approved" in 12
    replace detail = ///
        "Do not edit generated files. Correct the appropriate earlier source or code and rerun." in 12
    export excel using `"`review_workbook'"', ///
        sheet("Review") firstrow(variables) replace

    * STEP 5 TRUSTS ONLY A PASSING STEP 4 PACKAGE
    * The Step 4 QA file is checked before any disclosure-controlled candidate
    * is created. A failed calculation package must never proceed to review.
    import delimited using `"`step4_qa'"', varnames(1) clear
    generate str8 stage = "Step 4"
    tempfile combined_qa
    save `"`combined_qa'"', replace
    * RECHECK DISCLOSURE QA AT APPROVAL TIME
    * The reviewer may have inspected files outside Stata, but approval is
    * recorded only when the saved machine-readable QA still contains PASS for
    * every check.
    import delimited using `"`review_disclosure_qa'"', varnames(1) clear
    generate str8 stage = "Step 5"
    append using `"`combined_qa'"'
    order stage check result detail
    export excel using `"`review_workbook'"', ///
        sheet("QA") firstrow(variables) sheetmodify

    use `"`private_dta'"', clear
    keep metric_id release_id period_type period period_complete event_type ///
        sex statistic value unit numerator denominator comparison_n status_flag
    export excel using `"`review_workbook'"', ///
        sheet("Private results") firstrow(variables) sheetmodify

    use `"`private_dta'"', clear
    generate long review_row = _n
    rename value private_value
    rename numerator private_numerator
    rename denominator private_denominator
    keep review_row metric_id release_id period_type period period_complete ///
        event_type sex statistic private_value unit private_numerator ///
        private_denominator comparison_n
    tempfile private_review
    save `"`private_review'"', replace

    use `"`review_candidate'"', clear
    generate long review_row = _n
    keep review_row suppression_status suppression_note
    merge 1:1 review_row using `"`private_review'"', nogen
    keep if suppression_status != "none"
    quietly count
    if r(N) {
        order metric_id release_id period_type period period_complete ///
            event_type sex statistic private_value unit private_numerator ///
            private_denominator comparison_n suppression_status suppression_note
        drop review_row
        export excel using `"`review_workbook'"', ///
            sheet("Suppression") firstrow(variables) sheetmodify
    }
    else {
        clear
        set obs 1
        generate str20 review_status = "PASS"
        generate str244 review_message = ///
            "No suppression-review rows were identified. Disclosure-control checks passed."
        export excel using `"`review_workbook'"', ///
            sheet("Suppression") firstrow(variables) sheetmodify
    }

    use `"`review_candidate'"', clear
    export excel using `"`review_workbook'"', ///
        sheet("Public candidate") firstrow(variables) sheetmodify

    import delimited using `"`review_basis'"', varnames(1) clear
    export excel using `"`review_workbook'"', ///
        sheet("Files") firstrow(variables) sheetmodify

    * Confirm the complete PREPARE contract before reporting success.
    * These explicit checks also document the four files a reviewer should
    * expect to find after a successful run.
    foreach output_file in ///
            `"`review_candidate'"' ///
            `"`review_disclosure_qa'"' ///
            `"`review_basis'"' ///
            `"`review_workbook'"' {
        capture confirm file `"`output_file'"'
        if _rc {
            _bnr_step5_fail 603 "`action'" "`release_id'" ///
                `"`output_log'"' ///
                `"Required Step 5 review artefact is absent: `output_file'"'
            exit _rc
        }
    }

    local summary_status "READY FOR HUMAN REVIEW"
    local summary_main_file `"`review_workbook'"'
    local summary_candidate `"`review_candidate'"'
    local summary_qa `"`review_disclosure_qa'"'
    local summary_basis `"`review_basis'"'
    local summary_ready "NOT CREATED - approval required"
    local summary_next ///
        "Open the review workbook. If satisfactory, use Step 5 Approve."
}

* ---------------------------------------------------------------------------
* APPROVE
* ---------------------------------------------------------------------------

if "`action'" == "approve" {

    * APPROVAL IS A CONTROLLED HAND-OFF, NOT PUBLICATION.
    * It is allowed only once for a reviewed package. Any later correction must
    * restart at PREPARE REPLACE so the human review is repeated.
    capture confirm file `"`approval'"'
    if !_rc {
        _bnr_step5_fail 602 "`action'" "`release_id'" ///
            `"`output_log'"' ///
            "An approval record already exists for this package."
        exit _rc
    }

    foreach required_file in `"`review_workbook'"' `"`review_basis'"' ///
            `"`review_candidate'"' `"`review_disclosure_qa'"' {
        capture confirm file `"`required_file'"'
        if _rc {
            _bnr_step5_fail 601 "`action'" "`release_id'" ///
                `"`output_log'"' ///
                `"Required reviewed Step 5 file not found: `required_file'"'
            exit _rc
        }
    }

    * APPROVE never overwrites a public_ready payload. A deliberate rebuild
    * must begin with PREPARE REPLACE, followed by a fresh human review.
    foreach output_file in ///
            `"`public_release_dta'"' ///
            `"`public_release_csv'"' ///
            `"`public_current_dta'"' ///
            `"`public_current_csv'"' ///
            `"`public_release_yml'"' ///
            `"`public_current_yml'"' ///
            `"`public_package_yml'"' ///
            `"`disclosure_qa'"' ///
            `"`manifest'"' {
        capture confirm file `"`output_file'"'
        if !_rc {
            _bnr_step5_fail 602 "`action'" "`release_id'" ///
                `"`output_log'"' ///
                `"A public-ready output already exists: `output_file'. Run prepare replace and review again."'
            exit _rc
        }
    }

    * RECHECK DISCLOSURE QA AT APPROVAL TIME
    * The reviewer may have inspected files outside Stata, but approval is
    * recorded only when the saved machine-readable QA still contains PASS for
    * every check.
    import delimited using `"`review_disclosure_qa'"', varnames(1) clear
    foreach variable in check result detail {
        capture confirm variable `variable'
        if _rc {
            _bnr_step5_fail 111 "`action'" "`release_id'" ///
                `"`output_log'"' "Disclosure QA has an invalid structure."
            exit _rc
        }
    }
    quietly count if result != "PASS"
    if r(N) {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' "Disclosure QA contains a non-passing check."
        exit _rc
    }

    use `"`review_candidate'"', clear
    quietly count if release_id != "`release_id'"
    if r(N) {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' ///
            "The reviewed candidate has the wrong release_id."
        exit _rc
    }
    quietly count if suppression_status != "none" & ///
        (!missing(value) | !missing(numerator) | !missing(denominator))
    if r(N) {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' ///
            "A suppressed reviewed row retains an exact numeric value."
        exit _rc
    }

    quietly count
    local public_rows = r(N)
    quietly count if suppression_status == "primary"
    local primary_rows = r(N)
    quietly count if suppression_status == "secondary"
    local secondary_rows = r(N)
    quietly count if suppression_status == "derived"
    local derived_rows = r(N)
    quietly count if suppression_status != "none"
    local suppressed_rows = r(N)

    * Confirm the candidate and every authoritative source file are unchanged.
    * These checks are intentionally explicit to match the five-row file above.
    import delimited using `"`review_basis'"', varnames(1) stringcols(_all) clear
    if _N != 5 {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' "The review-basis file has the wrong number of rows."
        exit _rc
    }

    local expected_role "private_metric_dataset"
    local expected_path `"`private_dta'"'
    local recorded_role = file_role[1]
    local recorded_path = file_path[1]
    local recorded_size = real(file_size[1])
    local recorded_checksum = real(checksum[1])
    if `"`recorded_role'"' != `"`expected_role'"' | ///
            `"`recorded_path'"' != `"`expected_path'"' {
        _bnr_step5_fail 459 "`action'" "`release_id'" ///
            `"`output_log'"' "The review-basis file list is invalid."
        exit _rc
    }
    capture confirm file `"`expected_path'"'
    if _rc {
        _bnr_step5_fail 601 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed source file is absent: `expected_path'"'
        exit _rc
    }
    quietly checksum `"`expected_path'"'
    if r(filelen) != `recorded_size' | r(checksum) != `recorded_checksum' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed file changed after preparation: `expected_path'"'
        exit _rc
    }

    local expected_role "step4_qa"
    local expected_path `"`step4_qa'"'
    local recorded_role = file_role[2]
    local recorded_path = file_path[2]
    local recorded_size = real(file_size[2])
    local recorded_checksum = real(checksum[2])
    if `"`recorded_role'"' != `"`expected_role'"' | ///
            `"`recorded_path'"' != `"`expected_path'"' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            "The review-basis file list is invalid."
        exit _rc
    }
    capture confirm file `"`expected_path'"'
    if _rc {
        _bnr_step5_fail 601 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed source file is absent: `expected_path'"'
        exit _rc
    }
    quietly checksum `"`expected_path'"'
    if r(filelen) != `recorded_size' | r(checksum) != `recorded_checksum' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed file changed after preparation: `expected_path'"'
        exit _rc
    }

    local expected_role "step4_package_metadata"
    local expected_path `"`step4_meta'"'
    local recorded_role = file_role[3]
    local recorded_path = file_path[3]
    local recorded_size = real(file_size[3])
    local recorded_checksum = real(checksum[3])
    if `"`recorded_role'"' != `"`expected_role'"' | ///
            `"`recorded_path'"' != `"`expected_path'"' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            "The review-basis file list is invalid."
        exit _rc
    }
    capture confirm file `"`expected_path'"'
    if _rc {
        _bnr_step5_fail 601 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed source file is absent: `expected_path'"'
        exit _rc
    }
    quietly checksum `"`expected_path'"'
    if r(filelen) != `recorded_size' | r(checksum) != `recorded_checksum' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed file changed after preparation: `expected_path'"'
        exit _rc
    }

    local expected_role "reviewed_public_candidate"
    local expected_path `"`review_candidate'"'
    local recorded_role = file_role[4]
    local recorded_path = file_path[4]
    local recorded_size = real(file_size[4])
    local recorded_checksum = real(checksum[4])
    if `"`recorded_role'"' != `"`expected_role'"' | ///
            `"`recorded_path'"' != `"`expected_path'"' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            "The review-basis file list is invalid."
        exit _rc
    }
    capture confirm file `"`expected_path'"'
    if _rc {
        _bnr_step5_fail 601 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed source file is absent: `expected_path'"'
        exit _rc
    }
    quietly checksum `"`expected_path'"'
    if r(filelen) != `recorded_size' | r(checksum) != `recorded_checksum' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed file changed after preparation: `expected_path'"'
        exit _rc
    }

    local expected_role "step5_disclosure_qa"
    local expected_path `"`review_disclosure_qa'"'
    local recorded_role = file_role[5]
    local recorded_path = file_path[5]
    local recorded_size = real(file_size[5])
    local recorded_checksum = real(checksum[5])
    if `"`recorded_role'"' != `"`expected_role'"' | ///
            `"`recorded_path'"' != `"`expected_path'"' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            "The review-basis file list is invalid."
        exit _rc
    }
    capture confirm file `"`expected_path'"'
    if _rc {
        _bnr_step5_fail 601 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed source file is absent: `expected_path'"'
        exit _rc
    }
    quietly checksum `"`expected_path'"'
    if r(filelen) != `recorded_size' | r(checksum) != `recorded_checksum' {
        _bnr_step5_fail 459 "`action'" "`release_id'" `"`output_log'"' ///
            `"A reviewed file changed after preparation: `expected_path'"'
        exit _rc
    }

    * Build metadata and CSV in temporary files. public_ready is created only
    * after all review-basis and disclosure checks have passed.
    tempfile public_csv metadata_release metadata_current metadata_package
    use `"`review_candidate'"', clear
    export delimited using `"`public_csv'"', replace

    foreach dataset_type in release current {
        local yml_file "`metadata_release'"
        if "`dataset_type'" == "current" {
            local yml_file "`metadata_current'"
        }
        tempname dataset_meta
        file open `dataset_meta' using `"`yml_file'"', write text replace
        file write `dataset_meta' "schema: bnr_public_metric_dataset_v1" _n
        file write `dataset_meta' "dataset_type: `dataset_type'" _n
        file write `dataset_meta' "package_status: public_ready" _n
        file write `dataset_meta' "package_id: `package_id'" _n
        file write `dataset_meta' "release_id: `release_id'" _n
        file write `dataset_meta' "domain: cvd" _n
        file write `dataset_meta' "metric_family: burden" _n
        file write `dataset_meta' "rows: `public_rows'" _n
        file write `dataset_meta' "sdc_policy: bnr_sdc_v1" _n
        file write `dataset_meta' "suppressed_rows: `suppressed_rows'" _n
        file write `dataset_meta' "primary_rows: `primary_rows'" _n
        file write `dataset_meta' "secondary_rows: `secondary_rows'" _n
        file write `dataset_meta' "derived_rows: `derived_rows'" _n
        file write `dataset_meta' "suppression_status_values:" _n
        file write `dataset_meta' "  - none" _n
        file write `dataset_meta' "  - primary" _n
        file write `dataset_meta' "  - secondary" _n
        file write `dataset_meta' "  - derived" _n
        file write `dataset_meta' "suppressed_value: missing" _n
        file write `dataset_meta' "suppressed_display_value: asterisk" _n
        file write `dataset_meta' "approved: true" _n
        file close `dataset_meta'
    }

    tempname package_meta
    file open `package_meta' using `"`metadata_package'"', ///
        write text replace
    file write `package_meta' "schema: bnr_public_metric_package_v1" _n
    file write `package_meta' "package_id: `package_id'" _n
    file write `package_meta' "package_status: public_ready" _n
    file write `package_meta' "release_id: `release_id'" _n
    file write `package_meta' "domain: cvd" _n
    file write `package_meta' "metric_family: burden" _n
    file write `package_meta' "created: `today_iso'" _n
    file write `package_meta' "review_standard: bnr_metric_review_v1" _n
    file write `package_meta' "disclosure_policy: bnr_sdc_v1" _n
    file write `package_meta' "dashboard_suppression_field: suppression_status" _n
    file write `package_meta' "approved: true" _n
    file write `package_meta' "publication_boundary: pending_step_6" _n
    file close `package_meta'

    capture mkdir "`ready_dir'"
    capture mkdir "`ready_data'"
    capture mkdir "`ready_meta'"

    * Copy the eight approved files explicitly. This deliberately avoids
    * nested macro indirection: the longer form is easier to audit and hand over.
    local copy_rc 0
    local failed_target ""

    capture copy `"`review_candidate'"' `"`public_release_dta'"', replace
    if _rc {
        local copy_rc = _rc
        local failed_target `"`public_release_dta'"'
    }

    if !`copy_rc' {
        capture copy `"`public_csv'"' `"`public_release_csv'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`public_release_csv'"'
        }
    }

    if !`copy_rc' {
        capture copy `"`review_candidate'"' `"`public_current_dta'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`public_current_dta'"'
        }
    }

    if !`copy_rc' {
        capture copy `"`public_csv'"' `"`public_current_csv'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`public_current_csv'"'
        }
    }

    if !`copy_rc' {
        capture copy `"`metadata_release'"' `"`public_release_yml'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`public_release_yml'"'
        }
    }

    if !`copy_rc' {
        capture copy `"`metadata_current'"' `"`public_current_yml'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`public_current_yml'"'
        }
    }

    if !`copy_rc' {
        capture copy `"`metadata_package'"' `"`public_package_yml'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`public_package_yml'"'
        }
    }

    if !`copy_rc' {
        capture copy `"`review_disclosure_qa'"' `"`disclosure_qa'"', replace
        if _rc {
            local copy_rc = _rc
            local failed_target `"`disclosure_qa'"'
        }
    }

    if `copy_rc' {
        foreach cleanup_name of local ready_outputs {
            local cleanup_file `"``cleanup_name''"'
            capture erase `"`cleanup_file'"'
        }
        capture rmdir "`ready_data'"
        capture rmdir "`ready_meta'"
        capture rmdir "`ready_dir'"
        _bnr_step5_fail `copy_rc' "`action'" "`release_id'" ///
            `"`output_log'"' ///
            `"A public-ready file could not be created (Stata return code `copy_rc'): `failed_target'"'
        exit _rc
    }

    * Manifest only the files Step 6 may promote.
    local manifest_files ///
        datasets/cvd_burden_metrics_`release_id'.dta ///
        datasets/cvd_burden_metrics_`release_id'.csv ///
        datasets/cvd_burden_metrics_current.dta ///
        datasets/cvd_burden_metrics_current.csv ///
        metadata/cvd_burden_metrics_`release_id'.yml ///
        metadata/cvd_burden_metrics_current.yml ///
        metadata/metric_package.yml ///
        disclosure_qa.csv

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
    capture quietly export delimited using `"`manifest'"', replace
    if _rc {
        local manifest_rc = _rc
        foreach cleanup_name of local ready_outputs {
            local cleanup_file `"``cleanup_name''"'
            capture erase `"`cleanup_file'"'
        }
        capture rmdir "`ready_data'"
        capture rmdir "`ready_meta'"
        capture rmdir "`ready_dir'"
        _bnr_step5_fail `manifest_rc' "`action'" "`release_id'" ///
            `"`output_log'"' "The public-ready manifest was not created."
        exit _rc
    }

    quietly checksum `"`manifest'"'
    local manifest_size : display %20.0f r(filelen)
    local manifest_checksum : display %20.0f r(checksum)
    local approved_date_num = daily("`c(current_date)'", "DMY")
    local approved_date : display %tdCCYY-NN-DD `approved_date_num'

    tempfile approval_temp
    capture quietly _bnr_step5_write_approval ///
        `"`approval_temp'"' "`package_id'" "`release_id'" ///
        `"`approver_name'"' `"`approver_role'"' "`approved_date'" ///
        "`manifest_size'" "`manifest_checksum'"
    if _rc {
        local approval_write_rc = _rc
        foreach cleanup_name of local ready_outputs {
            local cleanup_file `"``cleanup_name''"'
            capture erase `"`cleanup_file'"'
        }
        capture rmdir "`ready_data'"
        capture rmdir "`ready_meta'"
        capture rmdir "`ready_dir'"
        _bnr_step5_fail `approval_write_rc' "`action'" "`release_id'" ///
            `"`output_log'"' ///
            "The approval record could not be written (Stata return code `approval_write_rc')."
        exit _rc
    }

    capture copy `"`approval_temp'"' `"`approval'"', replace
    if _rc {
        local approval_rc = _rc
        foreach cleanup_name of local ready_outputs {
            local cleanup_file `"``cleanup_name''"'
            capture erase `"`cleanup_file'"'
        }
        capture rmdir "`ready_data'"
        capture rmdir "`ready_meta'"
        capture rmdir "`ready_dir'"
        _bnr_step5_fail `approval_rc' "`action'" "`release_id'" ///
            `"`output_log'"' "The approval record was not created."
        exit _rc
    }

    local summary_status "APPROVED - PENDING STEP 6"
    local summary_main_file `"`ready_dir'"'
    local summary_ready `"`ready_dir'"'
    local summary_manifest `"`manifest'"'
    local summary_approval `"`approval'"'
    local summary_next ///
        "No public output or website file was created. Proceed to Step 6."
}

* ---------------------------------------------------------------------------
* SINGLE OPERATIONAL RUN SUMMARY
* ---------------------------------------------------------------------------
* Keep this concise. Detailed package filenames remain inside the review
* workbook, manifest and metadata rather than crowding the operational log.

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 5: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:             `summary_status'"
noisily display as text   "  Script version:         2.2.0"
noisily display as text   "  Selected release:       `release_id'"
noisily display as text   "  Metric family:          burden"

if "`action'" == "prepare" {
    noisily display as text "  Action completed:       Prepare review package"
    noisily display as text `"  OPEN THIS FILE FIRST:   `summary_main_file'"'
    noisily display as text `"  Public candidate:       `summary_candidate'"'
    noisily display as text `"  Disclosure QA:          `summary_qa'"'
    noisily display as text `"  Review basis:           `summary_basis'"'
    noisily display as text "  Public-ready package:   Not created; approval required"
}
else {
    noisily display as text "  Action completed:       Record approval"
    noisily display as text `"  Approver:               `approver_name' (`approver_role')"' 
    noisily display as text `"  Public-ready package:   `summary_ready'"'
    noisily display as text `"  Public manifest:        `summary_manifest'"'
    noisily display as text `"  Approval record:        `summary_approval'"'
}

noisily display as text   "  Private log:            `output_log'"
noisily display as text   "  Next step:              `summary_next'"
noisily display as result "============================================================================="

}

quietly log close step5
capture program drop _bnr_step5_fail
capture program drop _bnr_step5_write_approval

/*******************************************************************************
DO-FILE:     bnr_step4_stage_metric.do
VERSION:     2.0.0 (27 July 2026)
PROJECT:     BNR Refit Phase 2
PURPOSE:     Create a standard staging-only metric review package

DESIGN:      This helper owns packaging mechanics only. It does not calculate,
             approve, promote, publish or mirror metrics to the website.

USAGE:       Called by bnr_step4_metrics.do.

ARGUMENTS:   calculation_dta qa_dta domain family release_id source_dta
             source_yml package_dir replace_mode metric_ids
*******************************************************************************/

version 19
set more off

local today_iso : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")

args calculation_dta qa_dta domain metric_family release_id ///
    source_dataset source_metadata package_dir replace_mode metric_ids

if `"`calculation_dta'"' == "" | `"`qa_dta'"' == "" | ///
        `"`domain'"' == "" | `"`metric_family'"' == "" | ///
        `"`release_id'"' == "" | `"`source_dataset'"' == "" | ///
        `"`source_metadata'"' == "" | `"`package_dir'"' == "" | ///
        `"`replace_mode'"' == "" | `"`metric_ids'"' == "" {
    display as error "bnr_step4_stage_metric.do received an incomplete staging contract."
    exit 198
}

if !inlist("`replace_mode'", "0", "1") {
    display as error "replace_mode must be 0 or 1."
    exit 198
}

foreach required_file in `"`calculation_dta'"' `"`qa_dta'"' ///
        `"`source_dataset'"' `"`source_metadata'"' {
    capture confirm file `"`required_file'"'
    if _rc {
        display as error "Required staging input not found:"
        display as error `"  `required_file'"'
        exit 601
    }
}

use `"`qa_dta'"', clear
foreach variable in check result detail {
    capture confirm variable `variable'
    if _rc {
        display as error "Metric-specific QA variable is absent: `variable'"
        exit 111
    }
}
quietly count if result != "PASS"
if r(N) {
    display as error "Metric-specific QA contains a non-passing check."
    exit 459
}

local release_dataset "`domain'_`metric_family'_metrics_`release_id'"
local current_dataset "`domain'_`metric_family'_metrics_current"
local qa_dataset "`domain'_`metric_family'_qa_`release_id'"

local datasets_dir "`package_dir'/datasets"
local metadata_dir "`package_dir'/metadata"
local review_dir "`package_dir'/review"

local release_dta "`datasets_dir'/`release_dataset'.dta"
local release_csv "`datasets_dir'/`release_dataset'.csv"
local current_dta "`datasets_dir'/`current_dataset'.dta"
local current_csv "`datasets_dir'/`current_dataset'.csv"
local release_yml "`metadata_dir'/`release_dataset'.yml"
local current_yml "`metadata_dir'/`current_dataset'.yml"
local package_yml "`metadata_dir'/metric_package.yml"
local qa_csv "`review_dir'/`qa_dataset'.csv"
local suppression_csv ///
    "`review_dir'/`domain'_`metric_family'_suppression_review_`release_id'.csv"
local suppression_xlsx ///
    "`review_dir'/`domain'_`metric_family'_suppression_review_`release_id'.xlsx"
local readme "`package_dir'/readme.txt"

* The controller has already checked whether the package folder may be replaced.
* This helper therefore writes each named artefact directly and explicitly.

capture mkdir "`package_dir'"
capture mkdir "`datasets_dir'"
capture mkdir "`metadata_dir'"
capture mkdir "`review_dir'"

use `"`calculation_dta'"', clear

local required_variables metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex ///
    source_status statistic value unit numerator denominator comparison_n ///
    status_flag sdc_policy primary_suppression_threshold ///
    primary_suppression related_primary_cells related_suppression_review ///
    suppression_review suppression_reason
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "Aggregate metric variable is absent: `variable'"
        exit 111
    }
}

foreach identifier in eid recid patid fname lname name dob address telephone ///
        phone email national_id {
    capture confirm variable `identifier'
    if !_rc {
        display as error "Potential individual identifier found in staging data: `identifier'"
        exit 459
    }
}

quietly count
local metric_rows = r(N)
if `metric_rows' == 0 {
    display as error "The calculated metric dataset contains no rows."
    exit 2000
}
quietly count if primary_suppression
local primary_suppression_rows = r(N)
quietly count if related_suppression_review
local related_suppression_rows = r(N)
quietly count if suppression_review
local suppression_review_rows = r(N)

capture quietly datasignature, nonames
if _rc local metric_signature "not_available"
else local metric_signature `"`r(datasignature)'"'

if "`replace_mode'" == "1" {
    save `"`release_dta'"', replace
    export delimited using `"`release_csv'"', replace
    copy `"`release_dta'"' `"`current_dta'"', replace
    copy `"`release_csv'"' `"`current_csv'"', replace
}
else {
    save `"`release_dta'"'
    export delimited using `"`release_csv'"'
    copy `"`release_dta'"' `"`current_dta'"'
    copy `"`release_csv'"' `"`current_csv'"'
}

* Create the private Step 5 suppression worklist.  Exact values are retained
* because the complete staging package is inside the private data boundary.
preserve
    keep if suppression_review == 1
    keep release_id metric_id period_type period period_complete ///
        statistic event_type sex value unit numerator denominator comparison_n ///
        primary_suppression related_primary_cells ///
        related_suppression_review suppression_reason
    order release_id metric_id period_type period period_complete ///
        statistic event_type sex value unit numerator denominator comparison_n ///
        primary_suppression related_primary_cells ///
        related_suppression_review suppression_reason
    sort primary_suppression related_suppression_review metric_id ///
        period_type period event_type sex statistic
    export delimited using `"`suppression_csv'"', replace
    if `suppression_review_rows' > 0 {
        export excel using `"`suppression_xlsx'"', ///
            sheet("Suppression worklist") firstrow(variables) replace
    }
    else {
        clear
        set obs 1
        generate str20 review_status = "PASS"
        generate str244 review_message = ///
            "No primary or linked suppression-review rows were identified in this private staging package."
        generate str20 release = "`release_id'"
        export excel using `"`suppression_xlsx'"', ///
            sheet("Review status") firstrow(variables) replace
    }
restore

* A CSV has no worksheets.  This companion workbook keeps the CSV as the
* stable machine-readable worklist while giving reviewers a field dictionary.
tempfile suppression_dictionary
tempname dictionary_handle
postfile `dictionary_handle' str35 variable str12 storage_type ///
    str244 description str25 review_use using `"`suppression_dictionary'"', replace
post `dictionary_handle' ("metric_id") ("string") ("BNR metric identifier.") ("Identify metric")
post `dictionary_handle' ("release_id") ("string") ("Selected CVD release identifier.") ("Confirm release")
post `dictionary_handle' ("period_type") ("string") ("Time resolution of the result.") ("Assess time series")
post `dictionary_handle' ("period") ("string") ("Human-readable reporting period.") ("Locate result")
post `dictionary_handle' ("period_complete") ("0 or 1") ("Whether the reporting period is complete; current quarter/year can be 0 at a monthly extract.") ("Label period-to-date")
post `dictionary_handle' ("event_type") ("string") ("CVD event grouping, for example AMI or stroke.") ("Check disclosure context")
post `dictionary_handle' ("sex") ("string") ("Sex stratum represented by the row.") ("Check subtraction risk")
post `dictionary_handle' ("statistic") ("string") ("Statistic or output row type.") ("Interpret result")
post `dictionary_handle' ("value") ("numeric") ("Exact calculated result retained only in private staging.") ("Do not publish directly")
post `dictionary_handle' ("unit") ("string") ("Unit of the calculated value.") ("Interpret result")
post `dictionary_handle' ("numerator") ("numeric") ("Exact numerator supporting the result.") ("Identify primary cells")
post `dictionary_handle' ("denominator") ("numeric") ("Exact denominator supporting the result, where applicable.") ("Identify revealing derivatives")
post `dictionary_handle' ("comparison_n") ("integer") ("Number of earlier periods contributing to a comparator.") ("Assess comparator")
post `dictionary_handle' ("primary_suppression") ("0 or 1") ("One means the row has a frequency from 1 to 5 requiring primary suppression before publication.") ("Primary suppression")
post `dictionary_handle' ("related_primary_cells") ("integer") ("Number of primary-suppressed component cells contributing to a derived row.") ("Assess linked disclosure")
post `dictionary_handle' ("related_suppression_review") ("0 or 1") ("One means a derived row requires linked suppression review.") ("Assess secondary suppression")
post `dictionary_handle' ("suppression_reason") ("string") ("Machine-readable reason that the row is on the worklist.") ("Explain review need")
postclose `dictionary_handle'

preserve
    use `"`suppression_dictionary'"', clear
    export excel using `"`suppression_xlsx'"', ///
        sheet("Data dictionary") firstrow(variables) sheetmodify
restore

foreach dataset_id in `release_dataset' `current_dataset' {
    local yml_path "`metadata_dir'/`dataset_id'.yml"
    tempname dataset_yml
    file open `dataset_yml' using `"`yml_path'"', write text replace
    file write `dataset_yml' "schema: bnr_metric_dataset_v1" _n
    file write `dataset_yml' "dataset_id: `dataset_id'" _n
    file write `dataset_yml' "package_status: staging" _n
    file write `dataset_yml' "domain: `domain'" _n
    file write `dataset_yml' "metric_family: `metric_family'" _n
    file write `dataset_yml' "metric_ids:" _n
    foreach metric_id of local metric_ids {
        file write `dataset_yml' "  - `metric_id'" _n
    }
    file write `dataset_yml' "release_id: `release_id'" _n
    file write `dataset_yml' "created: `today_iso'" _n
    file write `dataset_yml' `"created_by: "`c(username)'""' _n
    file write `dataset_yml' `"source_dataset: "`source_dataset'""' _n
    file write `dataset_yml' `"source_metadata: "`source_metadata'""' _n
    file write `dataset_yml' "rows: `metric_rows'" _n
    file write `dataset_yml' "sdc_policy: bnr_sdc_v1" _n
    file write `dataset_yml' "primary_suppression_threshold: 6" _n
    file write `dataset_yml' "primary_suppression_rows: `primary_suppression_rows'" _n
    file write `dataset_yml' "related_suppression_rows: `related_suppression_rows'" _n
    file write `dataset_yml' "suppression_review_rows: `suppression_review_rows'" _n
    file write `dataset_yml' "exact_values_retained_in_private_staging: true" _n
    file write `dataset_yml' "public_ready: false" _n
    file write `dataset_yml' `"data_signature: "`metric_signature'""' _n
    file write `dataset_yml' "unit_of_analysis: aggregate_metric_row" _n
    file write `dataset_yml' "individual_level_data: false" _n
    file write `dataset_yml' "human_review_required: true" _n
    file close `dataset_yml'
}

tempname package_meta
file open `package_meta' using `"`package_yml'"', write text replace
file write `package_meta' "schema: bnr_metric_package_v1" _n
file write `package_meta' "package_id: `domain'_`metric_family'_`release_id'" _n
file write `package_meta' "package_status: staging" _n
file write `package_meta' "domain: `domain'" _n
file write `package_meta' "metric_family: `metric_family'" _n
file write `package_meta' "metric_ids:" _n
foreach metric_id of local metric_ids {
    file write `package_meta' "  - `metric_id'" _n
}
file write `package_meta' "release_id: `release_id'" _n
file write `package_meta' "created: `today_iso'" _n
file write `package_meta' `"created_by: "`c(username)'""' _n
file write `package_meta' "human_review_required: true" _n
file write `package_meta' "approved: false" _n
file write `package_meta' "publication_boundary: no_public_or_website_files_created" _n
file write `package_meta' "statistical_disclosure_control:" _n
file write `package_meta' "  standard: Handbook on Statistical Disclosure Control for Outputs" _n
file write `package_meta' "  reference: https://ukdataservice.ac.uk/app/uploads/sdc-handbook-v2.0.pdf" _n
file write `package_meta' "  policy: bnr_sdc_v1" _n
file write `package_meta' "  primary_suppression_rule: suppress_frequencies_1_to_5" _n
file write `package_meta' "  minimum_publishable_frequency: 6" _n
file write `package_meta' "  zeroes_primary_suppressed: false" _n
file write `package_meta' "  primary_suppression_rows: `primary_suppression_rows'" _n
file write `package_meta' "  related_suppression_rows: `related_suppression_rows'" _n
file write `package_meta' "  exact_values_retained_in_private_staging: true" _n
file write `package_meta' "  complementary_suppression_pending_step_5: true" _n
file write `package_meta' "datasets:" _n
file write `package_meta' "  release_dta: datasets/`release_dataset'.dta" _n
file write `package_meta' "  release_csv: datasets/`release_dataset'.csv" _n
file write `package_meta' "  current_dta: datasets/`current_dataset'.dta" _n
file write `package_meta' "  current_csv: datasets/`current_dataset'.csv" _n
file write `package_meta' "review:" _n
file write `package_meta' "  qa_csv: review/`qa_dataset'.csv" _n
file write `package_meta' "  suppression_csv: review/`domain'_`metric_family'_suppression_review_`release_id'.csv" _n
file write `package_meta' "  suppression_workbook: review/`domain'_`metric_family'_suppression_review_`release_id'.xlsx" _n
file write `package_meta' "build:" _n
file write `package_meta' "  stata_version: `c(version)'" _n
file write `package_meta' "  controller: bnr_step4_metrics.do" _n
file write `package_meta' "  calculator: bnr_step4_cvd_burden.do" _n
file close `package_meta'

use `"`qa_dta'"', clear
export delimited using `"`qa_csv'"', replace

tempname package_readme
file open `package_readme' using `"`readme'"', write text replace
file write `package_readme' "BNR CVD `metric_family' metric staging package" _n
file write `package_readme' "Release: `release_id'" _n
file write `package_readme' "Created: `today_iso' by `c(username)'" _n _n
file write `package_readme' "This package is for human review. It is not approved or public." _n
file write `package_readme' "The release-stamped and current datasets contain the same candidate values." _n
file write `package_readme' "Exact frequencies from 1 to 5 remain visible because this is private staging." _n
file write `package_readme' "Under bnr_sdc_v1, those frequencies require primary suppression before publication." _n
file write `package_readme' "Review the QA CSV and suppression-review workbook before Step 5 approval." _n
file write `package_readme' "The suppression CSV contains only rows requiring primary or linked suppression review and only the fields needed for that review." _n
file write `package_readme' "Its companion workbook has a Suppression worklist sheet when rows require review; otherwise it has a Review status sheet confirming that no rows were identified. Both versions include a concise Data dictionary sheet." _n
file write `package_readme' "Step 5 must apply primary and complementary suppression to the complete public-ready release." _n
file write `package_readme' "Do not manually edit generated files; correct the source or code and rerun." _n
file close `package_readme'

* Final comparison: the release-stamped and current datasets must match.
use `"`release_dta'"', clear
capture quietly datasignature, nonames
local release_signature `"`r(datasignature)'"'
use `"`current_dta'"', clear
capture quietly datasignature, nonames
local current_signature `"`r(datasignature)'"'
if `"`release_signature'"' != `"`current_signature'"' {
    display as error "Release-stamped and current staging datasets differ."
    exit 459
}

/*
* =====================================================================
* DO-FILE:     cvd_ad_hoc_workflow_test_2026_v1.do
* PROJECT:     BNR info-hub
* PURPOSE:     Harmless end-to-end test of the ad-hoc briefing pathway
*
* IMPORTANT:
*   This file creates entirely synthetic aggregate values.  It is not a
*   BNR analysis and must never be presented as a BNR result.
*
* USE:
*   1. Copy this file to scripts/stata/briefings/ad_hoc/ in info-hub-private.
*   2. Check the EDIT BLOCK only if you need a different package ID.
*   3. Run this DO file directly in Stata.
*   4. It creates a private staging package.  Then use Briefing Step 2 and
*      Step 3, selecting "Ad-hoc briefing" and entering the exact ID.
* =====================================================================
*/

version 18
clear all
set more off


* ==============================================================================
* EDIT BLOCK: TEST PACKAGE ID AND PUBLIC DESCRIPTION
* ==============================================================================
* Keep this as a harmless, obviously synthetic test.  Do not use this package
* ID again after it has been approved or published.

local briefing_id       "cvd_ad_hoc_workflow_test_2026_v1"
local briefing_name     "CVD ad-hoc workflow test 2026 v1"
local output_type       "briefing"
local briefing_kind     "ad_hoc"

local domain            "cvd"
local surveillance_area "CVD"
local registry          "Barbados National Registry"
local geography         "Barbados"
local period            "Synthetic workflow test"
local target_year       "2026"
local baseline_start    ""
local baseline_end      ""

local source_dataset_id      "synthetic_ad_hoc_workflow_test_v1"
local source_dataset_release "synthetic_test_only"
local source_coverage_end    "2026-08-04"

local briefing_title "Synthetic CVD ad-hoc workflow test"
local briefing_short "Synthetic workflow test"
local briefing_description ///
    "Synthetic aggregate values created solely to test the ad-hoc briefing approval and publication workflow. They are not BNR results."
local briefing_limitations ///
    "This is a technical test package. Values are invented and have no epidemiological interpretation."
local data_note ///
    "All records and values in this package are synthetic. No registry data, person-level data, or confidential data were used."
local rights_note "For internal BNR workflow testing only. Do not disseminate as a surveillance product."
local contact_note "BNR workflow test package"
local briefing_page ""

local output1 "cvd_ad_hoc_workflow_test_summary"
local released_datasets "`output1'"
local released_figures  "`output1'"

local create_workbook 1
local create_zip      1
local list_zip        1
local workbook_file "bnr_`briefing_id'.xlsx"

* Excel sheet names must be no longer than 31 characters.  Use short,
* descriptive names rather than allowing the longer dataset ID to become the
* default data-sheet name.
local workbook_data1 "test_summary"
local workbook_meta1 "meta_test"
local workbook_vars1 "vars_test"

local zip_title "Synthetic ad-hoc workflow test package"
local zip_description ///
    "Synthetic data, figure, metadata and documentation used only to test the controlled ad-hoc briefing workflow."


* ==============================================================================
* DO NOT TOUCH: LOAD THE LOCAL BNR PATHS
* ==============================================================================

local localpath ""
capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if _rc {
    display as error "Could not load scripts/stata/config/bnr_paths_LOCAL.do."
    display as error "Run this file from the private info-hub repository root."
    exit _rc
}

if "$BNR_STAGING" == "" | "$BNR_STATA" == "" {
    display as error "BNR_STAGING or BNR_STATA is not defined after loading local paths."
    exit 198
}


* ==============================================================================
* DO NOT TOUCH: CREATE THE PRIVATE STAGING FOLDERS
* ==============================================================================

local staging_package "$BNR_STAGING/briefings/`briefing_id'"
local staging_datasets "`staging_package'/datasets"
local staging_figures  "`staging_package'/figures"
local staging_metadata "`staging_package'/metadata"
local staging_workbook "`staging_package'/workbook"
local staging_review   "`staging_package'/review"

capture confirm file "`staging_package'/approval.yml"
if !_rc {
    display as error "This package ID has already been approved."
    display as error "Use a new versioned briefing ID; do not overwrite an approved test."
    exit 459
}

foreach folder in ///
    "`staging_package'" ///
    "`staging_datasets'" ///
    "`staging_figures'" ///
    "`staging_metadata'" ///
    "`staging_workbook'" ///
    "`staging_review'" {
    capture mkdir "`folder'"
}


* ==============================================================================
* SYNTHETIC ANALYSIS: SMALL AGGREGATE TABLE AND FIGURE
* ==============================================================================
* There is deliberately no input file.  These six invented rows test that an
* analyst-owned ad-hoc script can create an ordinary staged public package.

input str12 reporting_month int synthetic_count
"January"   18
"February"  22
"March"     17
"April"     25
"May"       21
"June"      24
end

gen byte month_order = _n
label variable reporting_month "Synthetic reporting month"
label variable synthetic_count "Synthetic aggregate count (test only)"
label variable month_order "Month order for display"
notes _dta: synthetic test data only; no BNR data were used
notes _dta: purpose: controlled test of the ad-hoc briefing workflow
notes _dta: source: synthetic_ad_hoc_workflow_test_v1

sort month_order
save "`staging_datasets'/`output1'.dta", replace
export delimited using "`staging_datasets'/`output1'.csv", replace

graph bar synthetic_count, over(reporting_month, label(labsize(small))) ///
    ytitle("Synthetic aggregate count") ///
    title("Synthetic ad-hoc workflow test") ///
    subtitle("Invented values: not BNR results") ///
    note("Created solely to test approval and publication controls") ///
    name(ad_hoc_workflow_test, replace)
graph export "`staging_figures'/`output1'.png", replace width(1800)


* ==============================================================================
* DO NOT TOUCH: CREATE THE AUTOMATIC DISCLOSURE-REVIEW WORKLIST
* ==============================================================================
* This worklist prompts human review; it does not suppress values automatically.
* For this synthetic test, it flags any positive released count below six.

preserve

    keep if synthetic_count > 0 & synthetic_count < 6

    gen str50 public_file = "`output1'.csv"
    gen str50 output_section = "Synthetic monthly counts"
    gen str80 row_reference = reporting_month
    gen str30 measure = "synthetic_count"
    gen double value = synthetic_count
    gen str100 reason = "Positive released count below 6"
    gen str80 related_output = "`output1'.png"

    keep public_file output_section row_reference measure value reason related_output

    count
    if r(N) == 0 {
        set obs 1
        replace public_file = "ALL DECLARED OUTPUTS" in 1
        replace output_section = "Whole briefing" in 1
        replace row_reference = "Not applicable" in 1
        replace measure = "none" in 1
        replace value = . in 1
        replace reason = "No automatic positive-value flags below 6" in 1
        replace related_output = "Human whole-output review still required" in 1
    }

    gen flag_id = _n
    order flag_id public_file output_section row_reference measure value reason related_output
    export delimited using "`staging_review'/disclosure_flags.csv", replace

restore


* ==============================================================================
* DO NOT TOUCH: WRITE THE RELEASE-CONTROL CONTRACT
* ==============================================================================

local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local analysis_script "scripts/stata/briefings/ad_hoc/cvd_ad_hoc_workflow_test_2026_v1.do"
local control_file "`staging_metadata'/release_control.yml"

tempname release_control
file open `release_control' using "`control_file'", write replace text

file write `release_control' "schema: bnr_release_control_v1" _n
file write `release_control' "briefing_id: `briefing_id'" _n
file write `release_control' "briefing_name: `briefing_name'" _n
file write `release_control' "output_type: `output_type'" _n
file write `release_control' "briefing_kind: `briefing_kind'" _n
file write `release_control' "domain: `domain'" _n
file write `release_control' "surveillance_area: `surveillance_area'" _n
file write `release_control' "registry: `registry'" _n
file write `release_control' "geography: `geography'" _n
file write `release_control' "period: `period'" _n
file write `release_control' "target_year: `target_year'" _n
file write `release_control' "baseline_start: `baseline_start'" _n
file write `release_control' "baseline_end: `baseline_end'" _n
file write `release_control' "release_date: `release_date'" _n
file write `release_control' "analysis_script: `analysis_script'" _n
file write `release_control' "source_dataset_id: `source_dataset_id'" _n
file write `release_control' "source_dataset_release: `source_dataset_release'" _n
file write `release_control' "source_coverage_end: `source_coverage_end'" _n
file write `release_control' "source_dataset_file: none_synthetic_test" _n
file write `release_control' "" _n

foreach item in title short_title description limitations data_note rights contact {
    local item_text "`briefing_`item''"
    if "`item'" == "short_title" local item_text "`briefing_short'"
    if "`item'" == "rights" local item_text "`rights_note'"
    if "`item'" == "contact" local item_text "`contact_note'"
    file write `release_control' "`item': |-" _n
    file write `release_control' "  `item_text'" _n
    file write `release_control' "" _n
}

file write `release_control' "briefing_page: `briefing_page'" _n
file write `release_control' "released_datasets: `released_datasets'" _n
file write `release_control' "released_figures: `released_figures'" _n
file write `release_control' "" _n
file write `release_control' "create_workbook: `create_workbook'" _n
file write `release_control' "create_zip: `create_zip'" _n
file write `release_control' "list_zip: `list_zip'" _n
file write `release_control' "workbook_file: `workbook_file'" _n
file write `release_control' "" _n

file write `release_control' "workbook_sheets:" _n
file write `release_control' "  - dataset_id: `output1'" _n
file write `release_control' "    data_sheet: `workbook_data1'" _n
file write `release_control' "    metadata_sheet: `workbook_meta1'" _n
file write `release_control' "    variable_sheet: `workbook_vars1'" _n
file write `release_control' "" _n

file write `release_control' "zip_title: |-" _n
file write `release_control' "  `zip_title'" _n
file write `release_control' "" _n
file write `release_control' "zip_description: |-" _n
file write `release_control' "  `zip_description'" _n
file close `release_control'


* ==============================================================================
* DO NOT TOUCH: COMPLETE PRIVATE PACKAGE ONLY
* ==============================================================================

do "$BNR_STATA/common/bnr_stage_briefing.do" "`briefing_id'"

display as result _n "============================================================"
display as result "Synthetic ad-hoc briefing staging package created"
display as result "Package ID: `briefing_id'"
display as result "Location:   `staging_package'"
display as result ""
display as result "Next: Briefing Step 2 > Ad-hoc briefing"
display as result "Enter exactly: `briefing_id'"
display as result "============================================================"

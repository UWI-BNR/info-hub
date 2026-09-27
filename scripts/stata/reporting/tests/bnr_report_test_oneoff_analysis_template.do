/*******************************************************************************
DO-FILE: bnr_report_test_oneoff_analysis_template.do
VERSION: 1.0.0 (27 September 2026)
PURPOSE: Harmless contract test for the reusable one-off analysis template.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_test_oneoff_analysis_template.do"

The test first runs the template in template_test mode, then checks its five
finished private inputs. It does not run publication Steps 1-3.
*******************************************************************************/

version 19
clear all
set more off

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach required_global in BNR_STATA BNR_STAGING {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

capture noisily do ///
    "$BNR_STATA/reporting/templates/bnr_report_oneoff_analysis_template.do" ///
    template_test
local template_rc = _rc
if `template_rc' {
    display as error "The one-off analysis template test run failed."
    exit `template_rc'
}

local study_id "workflow_template_test"
local output_root "$BNR_STAGING/report_inputs/one-off/`study_id'"
local report_pdf "`output_root'/bnr_cvd_oneoff_`study_id'.pdf"
local public_csv "`output_root'/`study_id'_metrics.csv"
local public_dta "`output_root'/`study_id'_metrics.dta"
local public_yml "`output_root'/`study_id'_metadata.yml"
local public_readme "`output_root'/`study_id'_readme.md"
local legacy_txt "`output_root'/`study_id'_metadata.txt"

foreach required_file in report_pdf public_csv public_dta public_yml public_readme {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Template output is missing: ``required_file''"
        exit 601
    }
    quietly checksum "``required_file''"
    assert r(filelen) > 0
}
capture confirm file "`legacy_txt'"
assert _rc != 0

local yml_schema_ok 0
local yml_methods_ok 0
local yml_variables_ok 0
local yml_description_count 0
tempname yml_handle
file open `yml_handle' using "`public_yml'", read text
file read `yml_handle' yml_line
while r(eof) == 0 {
    local yml_trim = strtrim(`"`yml_line'"')
    if "`yml_trim'" == "schema: bnr_dataset_metadata_v1" local yml_schema_ok 1
    if "`yml_trim'" == "methods:" local yml_methods_ok 1
    if "`yml_trim'" == "variables:" local yml_variables_ok 1
    if "`yml_trim'" == "description: |-" local ++yml_description_count
    file read `yml_handle' yml_line
}
file close `yml_handle'
assert `yml_schema_ok' == 1
assert `yml_methods_ok' == 1
assert `yml_variables_ok' == 1
assert `yml_description_count' == 7

use "`public_dta'", clear
assert _N == 2
assert c(k) == 7
assert inlist(release_status,"release","suppress_small_count")
assert !missing(events,deaths,estimate_pct) if release_status == "release"
assert missing(events,deaths,estimate_pct) if release_status != "release"
ds
local dta_vars `r(varlist)'

import delimited using "`public_csv'", varnames(1) asdouble clear
assert _N == 2
assert c(k) == 7
ds
assert "`r(varlist)'" == "`dta_vars'"

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF ANALYSIS TEMPLATE: CONTRACT TEST SUMMARY"
noisily display as text   "  Run status:              All template checks passed"
noisily display as text   "  Analytical content:      Harmless fictional values only"
noisily display as text  `"  Test output folder:       `output_root'"'
noisily display as text   "  Publication performed:   No"
noisily display as result "============================================================================="
}


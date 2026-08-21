/*
===============================================================================
 DO-FILE:     bnr_mort_test_suppression.do
 VERSION:     1.0.0 (20 August 2026)
 PROJECT:     BNR Refit Phase 2
 PURPOSE:     Create an unmistakably synthetic Step 2-shaped mortality dataset,
              run the real Step 3 and Step 4 scripts, and prove that primary
              and related suppression-review rules are triggered as expected.

 FIRST RUN:
   do "$BNR_STATA/mortality/bnr_mort_test_suppression.do"

 DELIBERATE RERUN:
   do "$BNR_STATA/mortality/bnr_mort_test_suppression.do" replace

 IMPORTANT:
   - This is a private QA test, not a routine menu item.
   - It uses release mort_2099_01 and death year 2098 so that it cannot be
     mistaken for a real BNR release.
   - It creates no approval, public_ready, publication or website output.
   - Keep the generated evidence for review. Do not approve or publish it.
===============================================================================
*/

version 19
clear all
set more off

* ==============================================================================
* 1. OPTIONAL ANALYST INPUT -- EDIT ONLY WHEN DELIBERATELY RERUNNING THE TEST
* ==============================================================================
args replace_word

local replace_existing = 0
if "`replace_word'" != "" {
    if lower("`replace_word'") != "replace" {
        display as error "The only optional word is replace."
        exit 198
    }
    local replace_existing = 1
}

* ==============================================================================
* 2. STANDARD PATHS AND FIXED SYNTHETIC RELEASE -- DO NOT EDIT
* ==============================================================================
if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "Start Stata from BNR_REPO or load bnr_paths_LOCAL.do."
        exit `config_rc'
    }
}

foreach path_name in BNR_STATA BNR_DATA_DERIVED BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" {
        display as error "Required path is not configured: `path_name'"
        exit 198
    }
}

local test_release_year "2099"
local test_release_month "01"
local test_release_id "mort_2099_01"
local test_analysis_year "2098"

local source_dir "$BNR_DATA_DERIVED/mortality/y2099/m01"
local source_dta "`source_dir'/bnr_mort_s2_209901.dta"
local package_dir "$BNR_STAGING/mortality/burden/`test_release_id'"
local metric_dta "`package_dir'/datasets/mort_burden_metrics_`test_release_id'.dta"
local metadata_yml "`package_dir'/metadata/mort_burden_package.yml"
local suppression_csv "`package_dir'/review/mort_burden_suppression_review_`test_release_id'.csv"
local step4_qa_csv "`package_dir'/review/mort_s4_review_qa_`test_release_id'.csv"
local step4_workbook "`package_dir'/review/mort_s4_review_`test_release_id'.xlsx"
local sentinel_txt "`package_dir'/SYNTHETIC_TEST_ONLY.txt"
local test_log "$BNR_PRIVATE_LOGS/bnr_mort_test_suppression.log"

capture mkdir "$BNR_DATA_DERIVED"
capture mkdir "$BNR_DATA_DERIVED/mortality"
capture mkdir "$BNR_DATA_DERIVED/mortality/y2099"
capture mkdir "`source_dir'"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close mort_sdc_test
log using `"`test_log'"', text replace name(mort_sdc_test)

display as text "BNR MORTALITY SYNTHETIC SUPPRESSION TEST"
display as result "  Synthetic release:    `test_release_id'"
display as result "  Synthetic death year: `test_analysis_year'"
display as result "  Replace authorised:   " cond(`replace_existing', "yes", "no")

* ==============================================================================
* 3. CREATE A STEP 2-SHAPED SYNTHETIC DEATHS DATASET -- DO NOT EDIT
* ==============================================================================
* Expected classified deaths for 2098:
*
*                         Men     Women     All
*   BNR-Heart               3         8      11
*   BNR-Stroke              7         4      11
*
* There is deliberately no Heart/Stroke overlap. Counts from 1 to 5 must be
* primary suppression flags. The connected rows must also enter the private
* worklist for related/complementary-suppression review.

capture confirm file `"`source_dta'"'
if !_rc & !`replace_existing' {
    display as error "Synthetic source already exists:"
    display as error `"`source_dta'"'
    display as text "Review the previous test, then rerun with replace if authorised."
    capture log close mort_sdc_test
    exit 602
}

clear
set obs 22

generate int dth_year = 2098
generate str2 sex = ""
generate byte age = 44 + mod(_n, 40)
generate byte qa_dod = 0
generate byte qa_sex = 0
generate byte qa_age = 0
generate byte hrt_prim = 0
generate byte str_prim = 0

* BNR-Heart: 3 men and 8 women.
replace sex = "1" in 1/3
replace sex = "2" in 4/11
replace hrt_prim = 1 in 1/11

* BNR-Stroke: 7 men and 4 women.
replace sex = "1" in 12/18
replace sex = "2" in 19/22
replace str_prim = 1 in 12/22

label data "SYNTHETIC TEST ONLY - BNR mortality suppression validation"
label variable dth_year "Synthetic calendar year of death"
label variable sex "Synthetic sex code: 1 men, 2 women"
label variable hrt_prim "Synthetic Primary BNR-Heart flag"
label variable str_prim "Synthetic Primary BNR-Stroke flag"
notes _dta: SYNTHETIC TEST ONLY. Never approve or publish.

if `replace_existing' {
    save `"`source_dta'"', replace
}
else {
    save `"`source_dta'"'
}

* ==============================================================================
* 4. RUN THE REAL STEP 3 COMPUTE/STAGE WORKFLOW -- DO NOT EDIT
* ==============================================================================
if `replace_existing' {
    capture noisily do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2099 1 replace
}
else {
    capture noisily do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2099 1
}

if _rc {
    local step3_rc = _rc
    display as error "Synthetic test stopped because Step 3 returned r(`step3_rc')."
    capture log close mort_sdc_test
    exit `step3_rc'
}

* Mark the package itself, not merely the test source, as synthetic. Step 4
* ignores unrecognised metadata keys but fingerprints the marked metadata file.
tempname metadata_handle
file open `metadata_handle' using `"`metadata_yml'"', write text append
file write `metadata_handle' "synthetic_test: true" _n
file write `metadata_handle' "synthetic_test_purpose: suppression_validation" _n
file close `metadata_handle'

tempname sentinel_handle
file open `sentinel_handle' using `"`sentinel_txt'"', write text replace
file write `sentinel_handle' "SYNTHETIC TEST ONLY" _n
file write `sentinel_handle' "Release: `test_release_id'" _n
file write `sentinel_handle' "Purpose: validate primary and related suppression-review rules." _n
file write `sentinel_handle' "Never approve, promote, publish or copy this package to a website." _n
file close `sentinel_handle'

* ==============================================================================
* 5. RUN THE REAL STEP 4 REVIEW WORKFLOW -- DO NOT EDIT
* ==============================================================================
if `replace_existing' {
    capture noisily do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2099 1 replace
}
else {
    capture noisily do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2099 1
}

if _rc {
    local step4_rc = _rc
    display as error "Synthetic test stopped because Step 4 returned r(`step4_rc')."
    capture log close mort_sdc_test
    exit `step4_rc'
}

* ==============================================================================
* 6. ASSERT THE EXPECTED SUPPRESSION RESULTS -- DO NOT EDIT
* ==============================================================================
use `"`metric_dta'"', clear

quietly count
if r(N) != 10 {
    display as error "Expected 10 synthetic metric rows."
    capture log close mort_sdc_test
    exit 459
}

quietly count if suppression_review == 1
if r(N) != 10 {
    display as error "Expected all 10 synthetic metric rows on the suppression worklist."
    capture log close mort_sdc_test
    exit 459
}

quietly count if primary_suppression == 1
if r(N) != 4 {
    display as error "Expected 4 primary suppression flags."
    capture log close mort_sdc_test
    exit 459
}

quietly count if related_suppression_review == 1
if r(N) != 6 {
    display as error "Expected 6 related suppression-review flags."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-001" & primary_suppression == 1
if r(N) != 2 {
    display as error "Expected 2 primary flags in MORT-BURDEN-001."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-001" & related_suppression_review == 1
if r(N) != 4 {
    display as error "Expected 4 related flags in MORT-BURDEN-001."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-002" & primary_suppression == 1
if r(N) != 2 {
    display as error "Expected 2 primary flags in MORT-BURDEN-002."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-002" & related_suppression_review == 1
if r(N) != 2 {
    display as error "Expected 2 related flags in MORT-BURDEN-002."
    capture log close mort_sdc_test
    exit 459
}

* Confirm the exact synthetic count pattern, not just the flag totals.
quietly count if metric_id == "MORT-BURDEN-001" & ///
    outcome == "BNR-Heart" & sex_group == "men" & value == 3
if r(N) != 1 {
    display as error "Expected BNR-Heart men count of 3."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-001" & ///
    outcome == "BNR-Heart" & sex_group == "women" & value == 8
if r(N) != 1 {
    display as error "Expected BNR-Heart women count of 8."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-001" & ///
    outcome == "BNR-Stroke" & sex_group == "men" & value == 7
if r(N) != 1 {
    display as error "Expected BNR-Stroke men count of 7."
    capture log close mort_sdc_test
    exit 459
}

quietly count if metric_id == "MORT-BURDEN-001" & ///
    outcome == "BNR-Stroke" & sex_group == "women" & value == 4
if r(N) != 1 {
    display as error "Expected BNR-Stroke women count of 4."
    capture log close mort_sdc_test
    exit 459
}

import delimited using `"`suppression_csv'"', varnames(1) clear
quietly count
if r(N) != 10 {
    display as error "Expected 10 rows in the Step 3 suppression CSV."
    capture log close mort_sdc_test
    exit 459
}

import delimited using `"`step4_qa_csv'"', varnames(1) stringcols(_all) clear
quietly count if result != "PASS"
if r(N) != 0 {
    display as error "At least one synthetic Step 4 QA check did not pass."
    capture log close mort_sdc_test
    exit 459
}

capture confirm file `"`step4_workbook'"'
if _rc {
    display as error "The synthetic Step 4 review workbook was not created."
    capture log close mort_sdc_test
    exit 603
}

capture confirm file `"`sentinel_txt'"'
if _rc {
    display as error "The SYNTHETIC_TEST_ONLY package sentinel is missing."
    capture log close mort_sdc_test
    exit 603
}

* ==============================================================================
* 7. SHORT OPERATOR SUMMARY -- DO NOT EDIT
* ==============================================================================
display as result ""
display as result "============================================================================="
display as result "BNR MORTALITY SYNTHETIC SUPPRESSION TEST: PASSED"
display as text   "  Synthetic release:      `test_release_id'"
display as text   "  Primary flags:          4"
display as text   "  Related review flags:   6"
display as text   "  Total worklist rows:    10"
display as text   `"  OPEN THIS FILE FIRST:   `step4_workbook'"'
display as text   `"  Suppression worklist:   `suppression_csv'"'
display as text   `"  Test log:               `test_log'"'
display as text   "  Approval/public output: NOT CREATED"
display as error  "  SYNTHETIC TEST ONLY:     NEVER APPROVE OR PUBLISH"
display as result "============================================================================="

capture log close mort_sdc_test

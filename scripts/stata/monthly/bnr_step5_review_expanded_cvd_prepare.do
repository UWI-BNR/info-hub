/*******************************************************************************
DO-FILE: bnr_step5_review_expanded_cvd_prepare.do
VERSION: 3.1.0 (27 August 2026)
PURPOSE: Prepare the combined CVD Step 5 disclosure-review candidate.
USAGE:   do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_prepare.do" 2024 4
         do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_prepare.do" 2024 4 replace

This is PREPARE only. It does not approve, create public_ready, or publish.
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month option
if "`release_year'" == "" | "`release_month'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")
local year = real("`release_year'")
local month = real("`release_month'")
if missing(`year') | `year' != floor(`year') | `year' < 2024 exit 198
if missing(`month') | `month' != floor(`month') | !inrange(`month', 1, 12) exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}
local year4 : display %04.0f `year'
local month2 : display %02.0f `month'
local release_id "cvd_`year4'_`month2'"
local package_dir "$BNR_STAGING/metrics/cvd/`release_id'"
local burden_dta "`package_dir'/datasets/cvd_burden_metrics_`release_id'.dta"
local rates_dta "`package_dir'/datasets/cvd_incidence_rates_`release_id'.dta"
local components_dta "`package_dir'/review/cvd_incidence_rate_components_`release_id'.dta"
local review_dir "`package_dir'/review"
local candidate_dta "`review_dir'/step5_candidate.dta"
local qa_dta "`review_dir'/step5_disclosure_qa.dta"
local qa_csv "`review_dir'/step5_disclosure_qa.csv"
local equation_dta "`review_dir'/step5_equation_audit.dta"
local equation_csv "`review_dir'/step5_equation_audit.csv"
local rows_dta "`review_dir'/step5_row_audit.dta"
local review_basis "`review_dir'/step5_review_basis.csv"
local review_workbook "`review_dir'/step5_review.xlsx"
local log_path "$BNR_PRIVATE_LOGS/bnr_cvd_review_prepare_`year4'`month2'.log"
foreach input_file in burden_dta rates_dta components_dta {
    capture confirm file "``input_file''"
    if _rc {
        display as error "Required Step 4 private calculation product not found: ``input_file''"
        exit 601
    }
}
foreach output_file in candidate_dta qa_dta qa_csv equation_dta equation_csv rows_dta review_basis review_workbook {
    capture confirm file "``output_file''"
    if !_rc & !`replace_existing' exit 602
}
capture mkdir "$BNR_PRIVATE_LOGS"
capture log close step5
log using "`log_path'", text replace name(step5)
do "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd.do" "`burden_dta'" "`rates_dta'" "`components_dta'" "`candidate_dta'" "`qa_dta'" "`equation_dta'" "`rows_dta'" "`release_id'"
use "`qa_dta'", clear
quietly count if result != "PASS"
assert r(N) == 0
export delimited using "`qa_csv'", replace
use "`equation_dta'", clear
export delimited using "`equation_csv'", replace

* Record the exact private candidate and QA evidence supplied for human review.
tempfile basis_dta
tempname basis_handle
postfile `basis_handle' str32 file_role str244 file_path double file_size double checksum using "`basis_dta'", replace
foreach item in candidate_dta qa_csv equation_csv rows_dta {
    quietly checksum "``item''"
    post `basis_handle' ("`item'") ("``item''") (r(filelen)) (r(checksum))
}
postclose `basis_handle'
use "`basis_dta'", clear
format file_size checksum %20.0f
export delimited using "`review_basis'", replace

* This concise workbook is private review evidence, not a public output.
clear
set obs 8
generate str40 review_item = ""
generate str244 detail = ""
replace review_item = "Review status" in 1
replace detail = "READY FOR HUMAN REVIEW" in 1
replace review_item = "Release" in 2
replace detail = "`release_id'" in 2
replace review_item = "Candidate" in 3
replace detail = "step5_candidate.dta" in 3
replace review_item = "Disclosure QA" in 4
replace detail = "All checks must be PASS before approval." in 4
replace review_item = "Equation audit" in 5
replace detail = "Review additive, comparator and rate-equation closure." in 5
replace review_item = "Row audit" in 6
replace detail = "Review protected-source propagation and numeric blanking." in 6
replace review_item = "Fingerprint register" in 7
replace detail = "step5_review_basis.csv identifies the exact reviewed files." in 7
replace review_item = "If not approved" in 8
replace detail = "Do not edit generated files; correct the earlier source or code and rerun." in 8
export excel using "`review_workbook'", sheet("Review") firstrow(variables) replace

* Supporting review sheets keep the machine-readable evidence visible in the
* workbook without changing the authoritative DTA and CSV review artefacts.
use "`qa_dta'", clear
export excel using "`review_workbook'", sheet("Disclosure QA") firstrow(variables) sheetreplace

use "`equation_dta'", clear
export excel using "`review_workbook'", sheet("Equation audit") firstrow(variables) sheetreplace

use "`candidate_dta'", clear
keep if suppression_status != "none"
export excel using "`review_workbook'", sheet("Protected worklist") firstrow(variables) sheetreplace

import delimited using "`review_basis'", varnames(1) clear
export excel using "`review_workbook'", sheet("Fingerprint register") firstrow(variables) sheetreplace
display as result "Expanded CVD Step 5 PREPARE passed."
log close step5

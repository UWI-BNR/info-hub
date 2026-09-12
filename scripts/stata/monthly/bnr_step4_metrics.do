/*******************************************************************************
DO-FILE: bnr_step4_metrics.do
VERSION: 3.3.1 (29 August 2026)
PURPOSE: Calculate and privately stage the combined CVD burden and annual-rate
         package. This step also creates the private DCO linkage review package.
         It does not review, approve or publish.

ROUTINE USE:
  do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 1 2026 7
  do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 1 2026 7 replace

CHANGE 3.3.1:
  Wrap the operational run-summary display block in quietly { } so Stata
  shows the summary itself without echoing each display command.

CHANGE 3.3.0:
  Add a concise operational run summary showing staged row counts, source
  quarantine status and aggregate DCO linkage-review volume.

CHANGE 3.2.0:
  Carry the Step 2 source-quarantine summary into private staging alongside the
  DCO linkage review summary so both are available to Step 5 human review.

CHANGE 3.1.0:
  Add the private DCO linkage review workbook/DTA and copy its non-identifying
  summary into the Step 4 staging review folder for Step 5 human review.
*******************************************************************************/
version 19
clear all
set more off

args cvd_year cvd_month mortality_year mortality_month option
foreach argument in cvd_year cvd_month mortality_year mortality_month {
    if "``argument''" == "" exit 198
}
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_mode = (lower("`option'") == "replace")
foreach argument in cvd_year cvd_month mortality_year mortality_month {
    local `argument'_number = real("``argument''")
    if missing(``argument'_number') | ``argument'_number' != floor(``argument'_number') exit 198
}
if !inrange(`cvd_month_number', 1, 12) | !inrange(`mortality_month_number', 1, 12) exit 198
if (`mortality_year_number' * 12 + `mortality_month_number') < (`cvd_year_number' * 12 + `cvd_month_number') exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_STATA BNR_PRIVATE BNR_STAGING BNR_DATA_DERIVED BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}
local cy : display %04.0f `cvd_year_number'
local cm : display %02.0f `cvd_month_number'
local my : display %04.0f `mortality_year_number'
local mm : display %02.0f `mortality_month_number'
local release_id "cvd_`cy'_`cm'"
local linkage_release "cvd_`cy'_`cm'_mort_`my'_`mm'"
local input_counts "$BNR_DATA_DERIVED/cvd/y`cy'/m`cm'/metric_inputs/bnr_cvd_input_count_`cy'`cm'_v01.dta"
local input_metadata "$BNR_DATA_DERIVED/cvd/y`cy'/m`cm'/metric_inputs/bnr_cvd_input_count_`cy'`cm'_v01.yml"
local linkage_dir "$BNR_PRIVATE/data/derived/cvd/y`cy'/m`cm'/linkage/mort_y`my'_m`mm'"
local rates_dta "`linkage_dir'/stage4_incidence_rates_cvd_`cy'_`cm'_mort_`my'_`mm'.dta"
local components_dta "`linkage_dir'/stage4_incidence_rate_components_cvd_`cy'_`cm'_mort_`my'_`mm'.dta"
local dco_review_summary "`linkage_dir'/review/cvd_dco_linkage_review_summary_`linkage_release'.csv"
local source_quarantine_summary "$BNR_DATA_DERIVED/cvd/y`cy'/m`cm'/review/bnr_cvd_step2_quarantine_summary_`cy'`cm'.csv"
local package_dir "$BNR_STAGING/metrics/cvd/`release_id'"
local staged_dco_review_summary "`package_dir'/review/cvd_dco_linkage_review_summary_`release_id'.csv"
local staged_quarantine_summary "`package_dir'/review/cvd_source_quarantine_summary_`release_id'.csv"
local staged_burden_dta "`package_dir'/datasets/cvd_burden_metrics_`release_id'.dta"
local staged_rates_dta "`package_dir'/datasets/cvd_incidence_rates_`release_id'.dta"

capture confirm file "`input_counts'"
if _rc exit 601
capture confirm file "`input_metadata'"
if _rc exit 601
capture confirm file "`source_quarantine_summary'"
if _rc {
    display as error "Step 2 source-quarantine summary not found: `source_quarantine_summary'"
    exit 601
}

* Linkage remains explicit and ordered. First complete deterministic person
* and episode linkage, then create the private BNR review worklist.
foreach program in bnr_cvd_prepare_linkage_inputs bnr_cvd_profile_linkage_inputs bnr_cvd_run_l01_episode_diagnostic bnr_cvd_run_l02_l03_episode_diagnostic {
    do "$BNR_STATA/metrics/cvd/`program'.do" `cy' `cm' `my' `mm' `option'
}

do "$BNR_STATA/metrics/cvd/bnr_cvd_create_dco_review_report.do" ///
    `cy' `cm' `my' `mm' `option'

* The automated workflow then continues. If BNR later corrects a source record
* after reviewing the worklist, rerun Step 4 so estimation and metrics rebuild.
foreach program in bnr_cvd_run_unresolved_estimation bnr_cvd_run_subtype_concordance_profile bnr_cvd_run_subtype_unresolved_estimation bnr_cvd_run_joint_subtype_estimation bnr_cvd_run_incidence_rate_estimation {
    do "$BNR_STATA/metrics/cvd/`program'.do" `cy' `cm' `my' `mm' `option'
}

tempfile burden_dta burden_qa
do "$BNR_STATA/metrics/cvd/bnr_step4_cvd_burden.do" "`input_counts'" "`input_metadata'" "`release_id'" "`burden_dta'" "`burden_qa'" "`cy'" "`cm'"
do "$BNR_STATA/metrics/cvd/bnr_step4_stage_expanded_cvd.do" "`burden_dta'" "`rates_dta'" "`components_dta'" "`package_dir'" "`release_id'" "`replace_mode'"

* The detailed review DTA/XLSX stays under BNR_PRIVATE. Only its aggregate,
* non-identifying summary is copied into private staging for Step 5 review.
capture confirm file "`dco_review_summary'"
if _rc {
    display as error "Private DCO review summary was not created: `dco_review_summary'"
    exit 601
}
capture mkdir "`package_dir'/review"
copy "`dco_review_summary'" "`staged_dco_review_summary'", replace
copy "`source_quarantine_summary'" "`staged_quarantine_summary'", replace

display as result "CVD Step 4 combined calculation and staging passed."
display as result "Private DCO review summary staged: `staged_dco_review_summary'"
display as result "Source quarantine summary staged: `staged_quarantine_summary'"

* Build a concise operational summary from the artefacts just staged.
use "`staged_burden_dta'", clear
quietly count
local burden_rows = r(N)

use "`staged_rates_dta'", clear
quietly count
local rate_rows = r(N)

import delimited using "`staged_dco_review_summary'", varnames(1) clear
quietly summarize candidate_n if review_required == 1, meanonly
local dco_review_n = 0
if r(N) > 0 local dco_review_n = r(mean) * r(N)

import delimited using "`staged_quarantine_summary'", varnames(1) clear
quietly count
assert r(N) == 1
quietly levelsof quarantine_status, local(quarantine_status) clean
local quarantine_n = quarantined_events[1]
local full_quarantine_n = fully_quarantined_events[1]
local partial_quarantine_n = partially_quarantined_events[1]

local burden_display : display %12.0fc `burden_rows'
local rate_display : display %12.0fc `rate_rows'
local dco_review_display : display %12.0fc `dco_review_n'
local quarantine_display : display %12.0fc `quarantine_n'
local full_quarantine_display : display %12.0fc `full_quarantine_n'
local partial_quarantine_display : display %12.0fc `partial_quarantine_n'

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 4: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:                 Completed successfully"
noisily display as text   "  Script version:             3.3.1"
noisily display as text   "  Selected CVD release:       `cy'-`cm'"
noisily display as text   "  Mortality linkage release:  `my'-`mm'"
noisily display as text   "  Burden rows staged:         `burden_display'"
noisily display as text   "  Rate/count rows staged:     `rate_display'"
noisily display as text   "  Source quarantine status:   `quarantine_status'"
noisily display as text   "  Quarantined events:         `quarantine_display'"
noisily display as text   "    Fully quarantined:        `full_quarantine_display'"
noisily display as text   "    Partially quarantined:    `partial_quarantine_display'"
noisily display as text   "  DCO records for review:     `dco_review_display'"
noisily display as text  `"  Staging folder:             `package_dir'"'
noisily display as text  `"  DCO review summary:         `staged_dco_review_summary'"'
noisily display as text  `"  Quarantine summary:         `staged_quarantine_summary'"'
noisily display as text   "  Next step:                  Prepare Step 5 disclosure review."
noisily display as result "============================================================================="
}

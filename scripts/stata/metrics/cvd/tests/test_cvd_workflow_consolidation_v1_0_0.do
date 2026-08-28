/*******************************************************************************
DO-FILE: test_cvd_workflow_consolidation_v1_0_0.do
VERSION: 1.0.0 (28 August 2026)
PURPOSE: Non-mutating regression route for the CVD workflow consolidation.

USAGE:
  do "test_cvd_workflow_consolidation_v1_0_0.do"
  do "test_cvd_workflow_consolidation_v1_0_0.do" 2024 4

This file is safe only after the named release has already completed Step 5
Prepare, Step 5 Approve and Step 6 Publish. The final three controller probes
expect r(602): existing outputs are deliberately protected and no replacement
is authorised. It does not use replace and must not create or overwrite files.
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month
if "`release_year'" == "" local release_year 2024
if "`release_month'" == "" local release_month 4

local year = real("`release_year'")
local month = real("`release_month'")
if missing(`year') | `year' != floor(`year') | `year' < 2024 exit 198
if missing(`month') | `month' != floor(`month') | !inrange(`month', 1, 12) exit 198

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_STATA BNR_STAGING BNR_PUBLIC {
    if "$`path_name'" == "" exit 198
}

local year4 : display %04.0f `year'
local month2 : display %02.0f `month'
local release_id "cvd_`year4'_`month2'"
local package_dir "$BNR_STAGING/metrics/cvd/`release_id'"
local review_dir "`package_dir'/review"
local ready_dir "`package_dir'/public_ready"

display as result "CVD workflow consolidation regression v1.0.0: synthetic tests"
foreach test_file in ///
    test_bnr_cvd_prepare_rate_reference ///
    test_bnr_cvd_stage2_disclosure ///
    test_bnr_cvd_stage4_l01_episode ///
    test_bnr_cvd_stage4_l02_l03_episode ///
    test_bnr_cvd_stage4_unresolved_estimation ///
    test_bnr_cvd_stage4_subtype_concordance ///
    test_bnr_cvd_stage4_subtype_unresolved_estimation ///
    test_bnr_cvd_stage4_joint_subtype_estimation ///
    test_bnr_cvd_construct_incidence_rates ///
    test_bnr_step4_stage_expanded_cvd ///
    test_bnr_cvd_stage5_expanded_end_to_end {
    do "$BNR_STATA/metrics/cvd/tests/`test_file'.do"
}

* Guard against accidental first-time execution of a controller probe.
foreach required_file in ///
    "`review_dir'/step5_candidate.dta" ///
    "`review_dir'/step5_disclosure_qa.csv" ///
    "`ready_dir'/approval.yml" ///
    "`ready_dir'/public_manifest.csv" ///
    "$BNR_PUBLIC/metrics/cvd/cvd_metrics_`release_id'.dta" {
    capture confirm file `"`required_file'"'
    if _rc {
        display as error "Required existing release evidence is absent: `required_file'"
        display as error "Controller no-op probes are unsafe; no controller was run."
        exit 601
    }
}

display as result "CVD workflow consolidation regression v1.0.0: canonical no-op probes"

* Existing prepare evidence makes a non-replace run stop before it writes.
capture noisily do "$BNR_STATA/monthly/bnr_step5_review.do" `year' `month' prepare
assert _rc == 602

* Existing public_ready evidence also checks approver-argument forwarding.
capture noisily do "$BNR_STATA/monthly/bnr_step5_review.do" `year' `month' ///
    approve "Controller smoke test" "BNR Developer"
assert _rc == 602

* Existing authoritative outputs make Step 6 stop before any promotion/copy.
capture noisily do "$BNR_STATA/monthly/bnr_step6_publish.do" `year' `month'
assert _rc == 602

display as result "CVD workflow consolidation regression passed without writes."

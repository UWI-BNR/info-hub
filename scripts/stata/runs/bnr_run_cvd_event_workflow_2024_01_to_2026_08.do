/*******************************************************************************
DO-FILE:     bnr_run_cvd_event_workflow_2024_01_to_2026_08.do
PURPOSE:     Manual month-by-month test runner for the CVD event workflow.

HOW TO USE:  Select and run ONE sub-block at a time in Stata.
             1. Run PREPARE (Steps 1-4 and Step 5 prepare).
             2. STOP and complete the human review.
             3. Run FINALISE (approval and Step 6).
             4. STOP, render Quarto separately and inspect the site.

FIXED INPUT: Every complete event test uses mortality release 2026-06.
BOUNDARY:    That mortality release cannot support event releases after June.
             July and August 2026 therefore test Steps 1-3 only.

IMPORTANT:   Do not run this entire file. Development commands deliberately
             use replace. Approval is still a human decision. Rolling reports
             are not created by this event workflow test runner.
*******************************************************************************/
version 19
clear all
set more off

* =============================================================================
* January 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 1 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 1
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 1 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 1 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 1 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 1 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 1 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* February 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 2 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 2
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 2 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 2 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 2 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 2 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 2 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* March 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 3 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 3
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 3 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 3 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 3 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 3 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* April 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 4 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 4
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 4 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 4 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* May 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 5 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 5
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 5 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 5 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 5 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 5 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 5 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* June 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 6 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 6
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 6 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 6 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 6 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 6 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 6 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* July 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 7 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 7
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 7 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 7 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 7 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 7 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 7 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* August 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 8 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 8
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 8 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 8 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 8 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 8 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 8 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* September 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 9 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 9
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 9 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 9 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 9 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 9 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 9 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* October 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 10 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 10
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 10 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 10 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 10 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 10 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 10 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* November 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 11 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 11
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 11 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 11 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 11 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 11 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 11 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* December 2024
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 12 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 12
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 12 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 12 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 12 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 12 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 12 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* January 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 1 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 1
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 1 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 1 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 1 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 1 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 1 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* February 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 2 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 2
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 2 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 2 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 2 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 2 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 2 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* March 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 3 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 3
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 3 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 3 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 3 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 3 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 3 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* April 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 4 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 4
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 4 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 4 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 4 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 4 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 4 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* May 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 5 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 5
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 5 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 5 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 5 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 5 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 5 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* June 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 6 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 6
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 6 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 6 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 6 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 6 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 6 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* July 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 7 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 7
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 7 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 7 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 7 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 7 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 7 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* August 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 8 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 8
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 8 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 8 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 8 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 8 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 8 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* September 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 9 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 9
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 9 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 9 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 9 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 9 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 9 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* October 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 10 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 10
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 10 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 10 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 10 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 10 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 10 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* November 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 11 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 11
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 11 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 11 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 11 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 11 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 11 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* December 2025
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 12 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 12
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 12 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 12 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 12 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 12 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 12 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* January 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 1 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 1
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 1 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 1 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 1 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* February 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 2 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 2
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 2 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 2 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 2 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 2 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 2 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* March 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 3 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 3
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 3 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 3 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 3 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 3 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 3 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* April 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 4 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 4
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 4 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 4 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 4 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 4 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 4 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* May 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 5 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 5
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 5 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 5 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 5 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 5 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 5 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* June 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 6 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 6
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 6 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 6 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 6 prepare replace

* STOP: inspect the Step 5 review package and make the approval decision.

* =============================================================================
* FINALISE -- run only after successful human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 6 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 6 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* July 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 7 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 7
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 7 count replace

* EXPECTED BOUNDARY: stop here. Mortality 2026-06 is earlier than event
* 2026-07, so Step 4 correctly rejects this pairing. Do not run Steps 4-6.

* =============================================================================
* August 2026
* PREPARE -- select these commands only, then stop for human review
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 8 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 8
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 8 count replace

* EXPECTED BOUNDARY: stop here. Mortality 2026-06 is earlier than event
* 2026-08, so Step 4 correctly rejects this pairing. Do not run Steps 4-6
* until mortality 2026-08 or later is approved.

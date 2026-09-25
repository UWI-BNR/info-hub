/*******************************************************************************
DO-FILE:     bnr_run_cvd_event_workflow_2024_01_to_2026_08.do
PURPOSE:     Command runner for the six-step monthly CVD event workflow.
             Each month is an explicit block so the release history is visible.
             Replace the approver placeholders before running Step 5.
IMPORTANT:   These are development-mode commands and include replace where the
             current workflow permits it. Step 5 approval remains a human action.
*******************************************************************************/
version 19
clear all
set more off

* =============================================================================
* January 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 1 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 1
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 1 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 1 2024 1 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 1 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 1 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 1 replace

* =============================================================================
* February 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 2 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 2
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 2 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 2 2024 2 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 2 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 2 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 2 replace

* =============================================================================
* March 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 3 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 3
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 3 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 2024 3 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 3 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 3 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 3 replace

* =============================================================================
* April 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 4 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 4
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 4 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 4 2024 4 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4 replace

* =============================================================================
* May 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 5 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 5
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 5 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 5 2024 5 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 5 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 5 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 5 replace

* =============================================================================
* June 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 6 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 6
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 6 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 6 2024 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 6 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 6 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 6 replace

* =============================================================================
* July 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 7 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 7
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 7 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 7 2024 7 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 7 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 7 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 7 replace

* =============================================================================
* August 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 8 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 8
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 8 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 8 2024 8 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 8 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 8 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 8 replace

* =============================================================================
* September 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 9 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 9
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 9 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 9 2024 9 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 9 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 9 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 9 replace

* =============================================================================
* October 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 10 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 10
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 10 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 10 2024 10 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 10 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 10 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 10 replace

* =============================================================================
* November 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 11 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 11
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 11 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 11 2024 11 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 11 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 11 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 11 replace

* =============================================================================
* December 2024
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2024 12 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 12
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 12 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 12 2024 12 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 12 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 12 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 12 replace

* =============================================================================
* January 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 1 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 1
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 1 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 1 2025 1 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 1 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 1 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 1 replace

* =============================================================================
* February 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 2 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 2
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 2 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 2 2025 2 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 2 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 2 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 2 replace

* =============================================================================
* March 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 3 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 3
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 3 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 3 2025 3 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 3 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 3 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 3 replace

* =============================================================================
* April 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 4 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 4
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 4 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 4 2025 4 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 4 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 4 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 4 replace

* =============================================================================
* May 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 5 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 5
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 5 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 5 2025 5 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 5 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 5 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 5 replace

* =============================================================================
* June 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 6 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 6
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 6 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 6 2025 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 6 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 6 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 6 replace

* =============================================================================
* July 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 7 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 7
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 7 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 7 2025 7 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 7 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 7 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 7 replace

* =============================================================================
* August 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 8 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 8
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 8 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 8 2025 8 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 8 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 8 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 8 replace

* =============================================================================
* September 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 9 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 9
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 9 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 9 2025 9 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 9 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 9 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 9 replace

* =============================================================================
* October 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 10 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 10
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 10 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 10 2025 10 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 10 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 10 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 10 replace

* =============================================================================
* November 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 11 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 11
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 11 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 11 2025 11 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 11 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 11 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 11 replace

* =============================================================================
* December 2025
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2025 12 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2025 12
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2025 12 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2025 12 2025 12 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 12 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2025 12 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2025 12 replace

* =============================================================================
* January 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 1 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 1
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 1 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 1 2026 1 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 approve "Ian Hambleton" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 1 replace

* =============================================================================
* February 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 2 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 2
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 2 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 2 2026 2 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 2 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 2 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 2 replace

* =============================================================================
* March 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 3 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 3
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 3 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 3 2026 3 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 3 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 3 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 3 replace

* =============================================================================
* April 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 4 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 4
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 4 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 4 2026 4 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 4 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 4 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 4 replace

* =============================================================================
* May 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 5 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 5
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 5 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 5 2026 5 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 5 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 5 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 5 replace

* =============================================================================
* June 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 6 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 6
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 6 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 6 2026 6 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 6 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 6 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 6 replace

* =============================================================================
* July 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 7 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 7
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 7 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 7 2026 7 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 7 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 7 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 7 replace

* =============================================================================
* August 2026
* =============================================================================
do "$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do" 2026 8 replace
do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2026 8
do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2026 8 count replace
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2026 8 2026 8 replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 8 prepare replace
do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 8 approve "FULL NAME" "BNR Analyst" replace
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2026 8 replace


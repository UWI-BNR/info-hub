/*******************************************************************************
DO-FILE:     bnr_run_cvd_mortality_workflow_2024_01_to_2026_08.do
PURPOSE:     Command runner for the six-step monthly mortality workflow.
             Each month is an explicit block so the release history is visible.
             Replace the approver placeholders before running Step 5.
*******************************************************************************/
version 19
clear all
set more off

* =============================================================================
* January 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 1 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 1 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 1 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 1 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 1 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 1 replace

* =============================================================================
* February 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 2 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 2 replace

* =============================================================================
* March 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 3 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 3 replace

* =============================================================================
* April 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 4 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 4 replace

* =============================================================================
* May 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 5 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 5 replace

* =============================================================================
* June 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 6 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 6 replace

* =============================================================================
* July 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 7 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 7 replace

* =============================================================================
* August 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 8 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 8 replace

* =============================================================================
* September 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 9 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 9 replace

* =============================================================================
* October 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 10 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 10 replace

* =============================================================================
* November 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 11 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 11 replace

* =============================================================================
* December 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 12 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 12 replace

* =============================================================================
* January 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 1 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 1 replace

* =============================================================================
* February 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 2 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 2 replace

* =============================================================================
* March 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 3 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 3 replace

* =============================================================================
* April 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 4 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 4 replace

* =============================================================================
* May 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 5 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 5 replace

* =============================================================================
* June 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 6 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 6 replace

* =============================================================================
* July 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 7 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 7 replace

* =============================================================================
* August 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 8 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 8 replace

* =============================================================================
* September 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 9 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 9 replace

* =============================================================================
* October 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 10 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 10 replace

* =============================================================================
* November 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 11 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 11 replace

* =============================================================================
* December 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 12 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 12 replace

* =============================================================================
* January 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 1 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 1 replace

* =============================================================================
* February 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 2 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 2 replace

* =============================================================================
* March 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 3 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 3 replace

* =============================================================================
* April 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 4 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 4 replace

* =============================================================================
* May 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 5 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 5 replace

* =============================================================================
* June 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 6 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 6 replace

* =============================================================================
* July 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 7 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 7 replace

* =============================================================================
* August 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 8 "FULL NAME" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 8 replace


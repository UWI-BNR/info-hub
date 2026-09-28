/*******************************************************************************
DO-FILE:     bnr_run_cvd_mortality_workflow_2024_01_to_2026_08.do
PURPOSE:     Manual month-by-month test runner for the mortality workflow.

HOW TO USE:  Select and run ONE monthly block at a time in Stata.
             1. Run PREPARE (Steps 1-4).
             2. STOP and inspect the Step 4 review outputs.
             3. Run FINALISE (Steps 5-6) only after human approval.
             4. STOP, render Quarto separately and inspect the site.

REPORTING:   January-November releases end at the preceding completed calendar
             year. December releases may include their own now-complete year.
             Thus 2024-01 to 2024-11 end in 2023; 2024-12 to 2025-11 end in
             2024; 2025-12 and the listed 2026 releases end in 2025.

IMPORTANT:   Do not run this entire file. Development commands deliberately
             use replace. Step 5 remains a human approval decision.
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

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 1 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 1 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* February 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 2 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 2 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 2 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 2 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* March 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 3 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 3 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 3 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 3 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* April 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 4 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 4 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 4 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 4 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* May 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 5 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 5 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 5 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 5 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* June 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 6 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 6 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 6 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 6 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* July 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 7 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 7 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 7 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 7 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* August 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 8 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 8 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 8 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 8 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* September 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 9 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 9 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 9 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 9 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* October 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 10 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 10 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 10 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 10 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* November 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 11 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 11 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 11 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 11 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* December 2024
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2024 12 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2024 12 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2024 12 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2024 12 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* January 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 1 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 1 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 1 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 1 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* February 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 2 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 2 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 2 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 2 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* March 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 3 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 3 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 3 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 3 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* April 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 4 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 4 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 4 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 4 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* May 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 5 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 5 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 5 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 5 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* June 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 6 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 6 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 6 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 6 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* July 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 7 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 7 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 7 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 7 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* August 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 8 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 8 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 8 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 8 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* September 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 9 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 9 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 9 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 9 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* October 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 10 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 10 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 10 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 10 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* November 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 11 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 11 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 11 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 11 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* December 2025
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2025 12 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2025 12 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2025 12 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2025 12 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* January 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 1 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 1 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 1 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 1 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* February 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 2 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 2 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 2 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 2 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* March 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 3 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 3 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 3 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replac
* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* April 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 4 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 4 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 4 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 4 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* May 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 5 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 5 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 5 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 5 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* June 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 6 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 6 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 6 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 6 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* July 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 7 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 7 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 7 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 7 replace

* STOP: render Quarto separately and inspect this release on the site.

* =============================================================================
* August 2026
* =============================================================================
do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 8 replace
do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 8 replace

* STOP: inspect the Step 4 review package and make the approval decision.

* FINALISE -- run only after successful human review
do "$BNR_STATA/mortality/bnr_mort_s5_approve.do" 2026 8 "Ian Hambleton" "BNR Analyst" release definitions disclosure candidate ready replace
do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 8 replace

* STOP: render Quarto separately and inspect this release on the site.

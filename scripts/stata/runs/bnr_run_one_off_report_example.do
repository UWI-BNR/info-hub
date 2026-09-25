
** Step 1 — prepare the private candidate package. Nothing is published.
* STEP 1. CASE-FATALITY REPORT 
do "$BNR_STATA/reporting/bnr_report_oneoff_s1_prepare.do" ///
    case_fatality_2025 1 ///
    "$BNR_PRIVATE/outputs/staging/reports/cvd/case-fatality/cvd_case_fatality_2010_2025_v01/candidate/bnr_cvd_case_fatality_2010_2025.pdf" ///
    "Thirty-day case fatality after cardiovascular events" ///
    "BNR case-fatality results for 2010-2025." 2026-09-25 replace ///
    "$BNR_PRIVATE/outputs/staging/reports/cvd/case-fatality/cvd_case_fatality_2010_2025_v01/candidate/case_fatality_metrics_candidate.csv" ///
    "$BNR_PRIVATE/outputs/staging/reports/cvd/case-fatality/cvd_case_fatality_2010_2025_v01/candidate/case_fatality_metrics_candidate.dta" ///
    "$BNR_PRIVATE/outputs/staging/reports/cvd/case-fatality/cvd_case_fatality_2010_2025_v01/candidate/case_fatality_metadata_candidate.txt"
 
* STEP 2 — run only after candidate review and formal approval.
do "$BNR_STATA/reporting/bnr_report_oneoff_s2_approve.do" ///
    case_fatality_2025 1 ///
    "Ian Hambleton" "BNR Analyst" candidate disclosure ready

* STEP 3 — publish the exact approved package. Do not use replace for v1.
do "$BNR_STATA/reporting/bnr_report_oneoff_s3_publish.do" ///
    case_fatality_2025 1

/*******************************************************************************
DO-FILE:     bnr_run_annual_cvd_reports_2024_2026.do
PURPOSE:     Command runner for annual CVD report production.
             Each block contains Step 1 build, Step 2 approval and Step 3 publish.
             Replace the approver placeholders before running.
IMPORTANT:   Annual Step 1 requires approved public event and mortality releases,
             matching website mirrors, and year-specific analyst files.
             The 2026 block is intentionally commented out until full 2026
             releases and the 2026 analyst files exist.
*******************************************************************************/
** version 19
** clear all
** set more off

* =============================================================================
* 2024 annual report
* =============================================================================
* do "$BNR_STATA/reporting/bnr_report_annual_s1_build.do" 2024 2024 12 2024 12 1 replace
* do "$BNR_STATA/reporting/bnr_report_annual_s2_approve.do" 2024 1 "FULL NAME" "BNR Analyst" candidate disclosure ready
* do "$BNR_STATA/reporting/bnr_report_annual_s3_publish.do" 2024 1 replace

* =============================================================================
* 2025 annual report — v1
* =============================================================================
do "$BNR_STATA/reporting/bnr_report_annual_s1_build.do" 2025 2026 1 2026 7 1 replace
do "$BNR_STATA/reporting/bnr_report_annual_s2_approve.do" 2025 1 "Ian Hambleton" "BNR Analyst" candidate disclosure ready
do "$BNR_STATA/reporting/bnr_report_annual_s3_publish.do" 2025 1 replace

* =============================================================================
* 2026 annual report — future block; run only after full-year releases exist
* =============================================================================
* do "$BNR_STATA/reporting/bnr_report_annual_s1_build.do" 2026 2026 12 2026 12 1 replace
* do "$BNR_STATA/reporting/bnr_report_annual_s2_approve.do" 2026 1 "FULL NAME" "BNR Analyst" candidate disclosure ready
* do "$BNR_STATA/reporting/bnr_report_annual_s3_publish.do" 2026 1 replace


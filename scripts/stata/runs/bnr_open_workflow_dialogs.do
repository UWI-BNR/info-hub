*******************************************************************************
* BNR workflow dialog launcher
*
* Run this file once from the Info-Hub project root to make the dialog folder
* available to Stata. Then run ONE uncommented `db` command below at a time.
*******************************************************************************

/// adopath ++ "scripts\stata\dialogs"

* ---------------------------------------------------------------------------
* CVD events workflow
* ---------------------------------------------------------------------------

* db bnr_step1_cvd_redcap_extract
* db bnr_step2_cvd_confidential
* db bnr_step3_metric_inputs
* db bnr_step4_metrics
* db bnr_step5_review
* db bnr_step6_publish


* ---------------------------------------------------------------------------
* CVD mortality workflow
* ---------------------------------------------------------------------------

* db bnr_mort_s1_extract
* db bnr_mort_s2_classify
* db bnr_mort_s3_burden
* db bnr_mort_s4_review
* db bnr_mort_s5_approve
* db bnr_mort_s6_publish

* ---------------------------------------------------------------------------
* Annual report workflow
* ---------------------------------------------------------------------------

* db bnr_report_annual_s1_build
* db bnr_report_annual_s2_approve
* db bnr_report_annual_s3_publish

* ---------------------------------------------------------------------------
* One-off report and report utilities
* ---------------------------------------------------------------------------

* db bnr_report_disclosure_screen
db bnr_report_oneoff_s1_prepare
db bnr_report_oneoff_s2_approve
db bnr_report_oneoff_s3_publish
* db bnr_report_update_build

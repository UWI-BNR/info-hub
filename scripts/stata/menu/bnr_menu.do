*! BNR Stata menu
*! version 1.13.0, 1 September 2026
*!
*! Adds the BNR workflow menu to Stata's built-in User menu.
*! Run once at Stata startup from profile.do.
*!
*! Do not add "window menu clear" here: that would remove other
*! user-defined menus installed in the same Stata session.

version 19.0

window menu append submenu "stUser" "BNR"


window menu append submenu "BNR" "Update CVD events dashboard"

window menu append item "Update CVD events dashboard" ///
    "Step 1: Extract REDCap data" ///
    "db bnr_step1_cvd_redcap_extract"

window menu append item "Update CVD events dashboard" ///
    "Step 2: Build cumulative dataset" ///
    "db bnr_step2_cvd_confidential"

window menu append item "Update CVD events dashboard" ///
    "Step 3: Build deidentified datasets" ///
    "db bnr_step3_metric_inputs"

window menu append item "Update CVD events dashboard" ///
    "Step 4: Calculate metrics for dashboards" ///
    "db bnr_step4_metrics"

window menu append item "Update CVD events dashboard" ///
    "Step 5: Review and approve package for release" ///
    "db bnr_step5_review"

window menu append item "Update CVD events dashboard" ///
    "Step 6: Publish approved outputs" ///
    "db bnr_step6_publish"


window menu append submenu "BNR" "Update CVD mortality dashboard"

window menu append item "Update CVD mortality dashboard" ///
    "Step 1: Extract mortality data" ///
    "db bnr_mort_s1_extract"

window menu append item "Update CVD mortality dashboard" ///
    "Step 2: Classify causes of death" ///
    "db bnr_mort_s2_classify"

window menu append item "Update CVD mortality dashboard" ///
    "Step 3: Build mortality burden data" ///
    "db bnr_mort_s3_burden"

window menu append item "Update CVD mortality dashboard" ///
    "Step 4: Review mortality release" ///
    "db bnr_mort_s4_review"

window menu append item "Update CVD mortality dashboard" ///
    "Step 5: Approve reviewed mortality release" ///
    "db bnr_mort_s5_approve"

window menu append submenu "BNR" "BNR utilities"

window menu append submenu "BNR utilities" "Create metadata for dta"

window menu append submenu "BNR utilities" "Create workbook from dta"

window menu append submenu "BNR utilities" "Check latest data release"


window menu refresh

display as text "BNR menu loaded: User > BNR"

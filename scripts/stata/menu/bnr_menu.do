*! BNR Stata menu
*! version 1.4.1, 3 August 2026
*!
*! Adds the BNR workflow menu to Stata's built-in User menu.
*! Run once at Stata startup from profile.do.
*!
*! Do not add "window menu clear" here: that would remove other
*! user-defined menus installed in the same Stata session.

version 19.0

window menu append submenu "stUser" "BNR"
window menu append submenu "BNR" "Monthly data workflow"

window menu append item "Monthly data workflow" ///
    "Step 1: Extract REDCap data" ///
    "db bnr_step1_cvd_redcap_extract"

window menu append item "Monthly data workflow" ///
    "Step 2: Build cumulative dataset" ///
    "db bnr_step2_cvd_confidential"

window menu append item "Monthly data workflow" ///
    "Step 3: Build deidentified datasets" ///
    "db bnr_step3_metric_inputs"

window menu append item "Monthly data workflow" ///
    "Step 4: Calculate metrics for dashboards" ///
    "db bnr_step4_metrics"

window menu append item "Monthly data workflow" ///
    "Step 5: Review and approve package for release" ///
    "db bnr_step5_review"

window menu append item "Monthly data workflow" ///
    "Step 6: Publish approved outputs" ///
    "db bnr_step6_publish"

window menu append submenu "BNR" "Briefing workflow"

window menu append item "Briefing workflow" ///
    "Step 1: Build review package" ///
    "db bnr_step1_build_briefing"

window menu refresh

display as text "BNR menu loaded: User > BNR"

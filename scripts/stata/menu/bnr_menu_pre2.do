*! BNR Stata menu
*! version 1.2.3, 27 July 2026
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
    "Step 1: Extract monthly REDCap data" ///
    "db bnr_step1_cvd_redcap_extract"

window menu append item "Monthly data workflow" ///
    "Step 2: Build confidential cumulative dataset" ///
    "db bnr_step2_cvd_confidential"

window menu append item "Monthly data workflow" ///
    "Step 3: Create deidentified metric-input datasets" ///
    "db bnr_cvd_create_metric_inputs"

window menu append item "Monthly data workflow" ///
    "Step 4: Calculate metrics and create private staging package" ///
    "db bnr_cvd_metric_controller"

window menu append item "Monthly data workflow" ///
    "Step 5: Review and approve staging package" ///
    "db bnr_cvd_review_controller"

window menu refresh

display as text "BNR menu loaded: User > BNR"

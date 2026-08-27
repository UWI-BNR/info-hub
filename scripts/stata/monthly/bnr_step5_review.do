/*******************************************************************************
DO-FILE: bnr_step5_review.do
VERSION: 4.0.0 (27 August 2026)
PURPOSE: Canonical Step 5 controller for the combined CVD release package.

USAGE:
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 prepare
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 prepare replace
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 approve "Full name" "BNR Analyst"
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2024 4 approve "Full name" "BNR Analyst" replace
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month action approver_name approver_role option
if "`release_year'" == "" | "`release_month'" == "" | "`action'" == "" exit 198
local action = lower("`action'")
if !inlist("`action'", "prepare", "approve") exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STATA" == "" exit 198

if "`action'" == "prepare" {
    if "`approver_name'" != "" & lower("`approver_name'") != "replace" exit 198
    if "`approver_role'" != "" | "`option'" != "" exit 198
    do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_prepare.do" `release_year' `release_month' `approver_name'
}
else {
    if "`approver_name'" == "" | "`approver_role'" == "" exit 198
    if "`option'" != "" & lower("`option'") != "replace" exit 198
    do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_approve.do" `release_year' `release_month' "`approver_name'" "`approver_role'" `option'
}
display as result "CVD Step 5 `action' completed."

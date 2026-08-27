/*******************************************************************************
DO-FILE: bnr_step6_publish.do
VERSION: 4.0.0 (27 August 2026)
PURPOSE: Canonical Step 6 publisher for the approved combined CVD package.

USAGE:
  do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4
  do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4 replace
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month option
if "`release_year'" == "" | "`release_month'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STATA" == "" exit 198
do "$BNR_STATA/monthly/bnr_step6_publish_expanded_cvd.do" `release_year' `release_month' `option'
display as result "CVD Step 6 completed."

/*******************************************************************************
DO-FILE: bnr_step6_publish.do
VERSION: 3.0.0 (28 August 2026)
PURPOSE: Canonical Step 6 controller for an approved combined CVD package.
USAGE:   do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4 [replace]

Step 6 verifies approval evidence and promotes the exact seven-file approved
payload. It does not calculate, suppress, approve, render or deploy.
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month option
if "`release_year'" == "" | "`release_month'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STATA" == "" exit 198
do "$BNR_STATA/monthly/bnr_step6_publish_expanded_cvd.do" ///
    `release_year' `release_month' `option'
exit _rc

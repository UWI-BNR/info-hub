/*******************************************************************************
BNR info-hub path configuration template

Instructions:
  1. Copy this file.
  2. Rename the copy to:

       bnr_paths_LOCAL.do

  3. Edit the copied file for your machine.
  4. Do not commit bnr_paths_LOCAL.do.

Use:
  Each BNR Stata briefing DO file should begin with:

       do "scripts/stata/config/bnr_paths_LOCAL.do"
*******************************************************************************/

version 19

* ---- Root folders ------------------------------------------------------------

global BNR_REPO     "C:/path/to/info-hub"
global BNR_PRIVATE  "C:/path/to/info-hub-private"

* ---- Main project folders ----------------------------------------------------

global BNR_SCRIPTS  "$BNR_REPO/scripts"
global BNR_STATA    "$BNR_REPO/scripts/stata"
global BNR_ADO      "$BNR_REPO/scripts/stata/ado"

global BNR_OUTPUTS  "$BNR_REPO/outputs"
global BNR_PUBLIC   "$BNR_REPO/outputs/public"
global BNR_WORK     "$BNR_REPO/outputs/work"

* ---- Private local folders ---------------------------------------------------

global BNR_DATA_RAW      "$BNR_PRIVATE/data/raw"
global BNR_DATA_FROZEN   "$BNR_PRIVATE/data/frozen"
global BNR_DATA_DERIVED  "$BNR_PRIVATE/data/derived"

global BNR_PRIVATE_WORK  "$BNR_PRIVATE/work"
global BNR_PRIVATE_LOGS  "$BNR_PRIVATE/logs/private"

* ---- Static briefing outputs -------------------------------------------------

global BNR_BRIEF_CVD_CASES_2023 "$BNR_PUBLIC/briefings/cvd_cases_2023_v1"

global BNR_BRIEF_TABLES "$BNR_BRIEF_CVD_CASES_2023/tables"
global BNR_BRIEF_FIGS   "$BNR_BRIEF_CVD_CASES_2023/figures"
global BNR_BRIEF_DATA   "$BNR_BRIEF_CVD_CASES_2023/data"

* ---- Stata setup -------------------------------------------------------------

cd "$BNR_REPO"

adopath ++ "$BNR_ADO"

display as text "BNR paths loaded:"
display as result "  Repo:      $BNR_REPO"
display as result "  Private:   $BNR_PRIVATE"
display as result "  Briefing:  $BNR_BRIEF_CVD_CASES_2023"

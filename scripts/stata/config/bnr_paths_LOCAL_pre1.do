/*******************************************************************************
BNR info-hub LOCAL path configuration

This file is machine-specific and must never be committed to Git.

Before first use:
  1. Confirm the two root paths below are correct for this machine.
  2. Create $BNR_PRIVATE/config/redcap_token.txt.
  3. Put only the REDCap API token in that text file, on one line.

The token itself must not be placed in this DO file or any Stata global.
*******************************************************************************/

version 19

* ---- Root folders ------------------------------------------------------------

global BNR_REPO     "C:/yoshimi-hot/output/analyse-bnr/info-hub"
global BNR_PRIVATE  "C:/yoshimi-hot/output/analyse-bnr/info-hub-private"

* ---- Main project folders ----------------------------------------------------

global BNR_SCRIPTS  "$BNR_REPO/scripts"
global BNR_STATA    "$BNR_REPO/scripts/stata"
global BNR_ADO      "$BNR_REPO/scripts/stata/ado"
global BNR_DIALOGS  "$BNR_REPO/scripts/stata/dialogs"
global BNR_HELP     "$BNR_REPO/scripts/stata/help"

global BNR_OUTPUTS  "$BNR_REPO/outputs"
global BNR_PUBLIC   "$BNR_REPO/outputs/public"
global BNR_WORK     "$BNR_REPO/outputs/work"

* ---- Private local folders ---------------------------------------------------

global BNR_DATA_RAW      "$BNR_PRIVATE/data/raw"
global BNR_DATA_FROZEN   "$BNR_PRIVATE/data/frozen"
global BNR_DATA_DERIVED  "$BNR_PRIVATE/data/derived"

global BNR_STAGING       "$BNR_PRIVATE/outputs/staging"
global BNR_PRIVATE_WORK  "$BNR_PRIVATE/work"
global BNR_PRIVATE_LOGS  "$BNR_PRIVATE/logs/private"

* Path only: Python reads the token directly from this untracked text file.
global BNR_REDCAP_TOKEN_FILE "$BNR_PRIVATE/config/redcap_token.txt"

* ---- Static briefing outputs -------------------------------------------------

global BNR_BRIEF_CVD_CASES_2023 "$BNR_PUBLIC/briefings/cvd_cases_2023_v1"

global BNR_BRIEF_TABLES "$BNR_BRIEF_CVD_CASES_2023/tables"
global BNR_BRIEF_FIGS   "$BNR_BRIEF_CVD_CASES_2023/figures"
global BNR_BRIEF_DATA   "$BNR_BRIEF_CVD_CASES_2023/data"

* ---- Stata setup -------------------------------------------------------------

cd "$BNR_REPO"
adopath ++ "$BNR_ADO"
adopath ++ "$BNR_DIALOGS"
adopath ++ "$BNR_HELP"

display as text "BNR paths loaded:"
display as result "  Repo:      $BNR_REPO"
display as result "  Private:   $BNR_PRIVATE"
display as result "  Staging:   $BNR_STAGING"

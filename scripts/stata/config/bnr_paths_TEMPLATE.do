/*******************************************************************************
BNR info-hub path configuration template

Instructions:
  1. Copy this file.
  2. Rename the copy to:

       bnr_paths_LOCAL.do

  3. Edit the three machine-specific values for your workstation.
  4. Do not commit bnr_paths_LOCAL.do.

Use:
  Each BNR Stata workflow DO file should begin with:

       do "scripts/stata/config/bnr_paths_LOCAL.do"
*******************************************************************************/

version 19

* ---- Machine-specific values -------------------------------------------------
*
* BNR_REDCAP_TOKEN_FILE contains the path to the token file, never the token.
* Both the private root and token file must be outside the public repository.
global BNR_REPO                    "C:/path/to/info-hub"
global BNR_PRIVATE                 "C:/secure/path/to/info-hub-private"
global BNR_REDCAP_TOKEN_FILE       "C:/secure/path/to/bnr_redcap_token.txt"
global BNR_MORT_REDCAP_TOKEN_FILE  "C:/secure/path/to/bnr_mort_redcap_token.txt"

* ---- Derived public-repository folders --------------------------------------

global BNR_SCRIPTS  "$BNR_REPO/scripts"
global BNR_STATA    "$BNR_REPO/scripts/stata"
global BNR_ADO      "$BNR_REPO/scripts/stata/ado"
global BNR_DIALOGS  "$BNR_REPO/scripts/stata/dialogs"

global BNR_OUTPUTS  "$BNR_REPO/outputs"
global BNR_PUBLIC   "$BNR_REPO/outputs/public"
global BNR_SITE     "$BNR_REPO/site"

* ---- Private local folders ---------------------------------------------------

global BNR_DATA_RAW      "$BNR_PRIVATE/data/raw"
global BNR_DATA_FROZEN   "$BNR_PRIVATE/data/frozen"
global BNR_DATA_DERIVED  "$BNR_PRIVATE/data/derived"

global BNR_STAGING       "$BNR_PRIVATE/outputs/staging"
global BNR_PRIVATE_WORK  "$BNR_PRIVATE/work"
global BNR_PRIVATE_LOGS  "$BNR_PRIVATE/logs/private"

* ---- Safety and completeness checks -----------------------------------------

if "$BNR_REPO" == "" | "$BNR_PRIVATE" == "" | ///
        "$BNR_REDCAP_TOKEN_FILE" == "" | ///
        "$BNR_MORT_REDCAP_TOKEN_FILE" == "" {
    display as error "BNR local configuration is incomplete."
    display as error ///
        "Set BNR_REPO, BNR_PRIVATE and both REDCap token-file paths."
    exit 198
}

* Normalise paths only for boundary comparisons. The configured globals above
* remain unchanged and retain forward slashes for Stata and Python portability.
local repo_check = lower(subinstr("$BNR_REPO", char(92), "/", .))
local private_check = lower(subinstr("$BNR_PRIVATE", char(92), "/", .))
local token_check = lower(subinstr("$BNR_REDCAP_TOKEN_FILE", char(92), "/", .))
local mort_token_check = ///
    lower(subinstr("$BNR_MORT_REDCAP_TOKEN_FILE", char(92), "/", .))

while substr("`repo_check'", strlen("`repo_check'"), 1) == "/" {
    local repo_check = substr("`repo_check'", 1, strlen("`repo_check'") - 1)
}
while substr("`private_check'", strlen("`private_check'"), 1) == "/" {
    local private_check = substr("`private_check'", 1, ///
        strlen("`private_check'") - 1)
}

if strpos("`private_check'/", "`repo_check'/") == 1 {
    display as error "Unsafe BNR configuration: BNR_PRIVATE is inside BNR_REPO."
    display as error "The private companion workspace must be outside Git."
    exit 198
}

if strpos("`token_check'", "`repo_check'/") == 1 {
    display as error ///
        "Unsafe BNR configuration: the REDCap token file is inside BNR_REPO."
    display as error "Move the token file outside Git and update its path."
    exit 198
}

if strpos("`mort_token_check'", "`repo_check'/") == 1 {
    display as error ///
        "Unsafe BNR configuration: the mortality REDCap token file is inside BNR_REPO."
    display as error "Move the token file outside Git and update its path."
    exit 198
}

capture confirm file "$BNR_REPO/README.md"
if _rc {
    display as error "BNR_REPO is not the root of the info-hub repository."
    display as error "Expected file: $BNR_REPO/README.md"
    exit 601
}

capture confirm file "$BNR_SITE/_quarto.yml"
if _rc {
    display as error "The configured Quarto site root is incomplete."
    display as error "Expected file: $BNR_SITE/_quarto.yml"
    exit 601
}

foreach global_name in BNR_PRIVATE BNR_DATA_RAW BNR_DATA_FROZEN ///
        BNR_DATA_DERIVED BNR_STAGING BNR_PRIVATE_WORK BNR_PRIVATE_LOGS {
    local check_path "${`global_name'}"
    quietly mata: st_local("path_exists", ///
        strofreal(direxists(st_local("check_path"))))
    if "`path_exists'" != "1" {
        display as error "Required private folder not found: `global_name'"
        display as error "  `check_path'"
        display as error ///
            "Provision the standard private workspace before running BNR jobs."
        exit 601
    }
}

* Token files themselves are checked only by the relevant Step 1 workflow.
* This allows staff without REDCap credentials to run authorised downstream workflows.

* ---- Stata session setup -----------------------------------------------------

cd "$BNR_REPO"

adopath ++ "$BNR_ADO"
adopath ++ "$BNR_DIALOGS"

display as text "BNR paths loaded:"
display as result "  Repo:      $BNR_REPO"
display as result "  Private:   $BNR_PRIVATE"
display as result "  Staging:   $BNR_STAGING"
display as result "  Public:    $BNR_PUBLIC"
display as result "  Site:      $BNR_SITE"

/*
* =====================================================================
 DO-FILE:     mirror_public_to_site.do
 PROJECT:     BNR info-hub
 PURPOSE:     Mirror an approved public briefing bundle into the Quarto
              website downloads folder.

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.0

 USAGE:
   Called from a briefing driver DO file after the public release bundle
   has been created.

   Example:
     do "scripts/stata/common/mirror_public_to_site.do" "`briefing_id'"

 REQUIRED INPUT:
   The briefing ID must be passed as argument 1.

   Example briefing ID:
     cvd_cases_2023_v1

 EXPECTED SOURCE:
   outputs/public/briefings/{briefing_id}/

 WEBSITE MIRROR TARGET:
   site/downloads/files/briefings/{briefing_id}/

 NOTES:
   This file does not create analytical outputs.
   It does not promote staging outputs to public outputs.
   It only mirrors the already-approved public bundle into the website
   folder so that Quarto can render and serve figures, workbooks, ZIP
   files, and metadata as static site resources.

   The authoritative public release remains:
     outputs/public/briefings/{briefing_id}/

   The website copy is disposable and can be regenerated.
* =====================================================================
*/


* ============================================================== 
* DO NOT TOUCH: READ REQUIRED ARGUMENT
* ============================================================== 

args briefing_id

if "`briefing_id'" == "" {
    display as error "No briefing_id supplied."
    display as error "Usage: do scripts/stata/common/mirror_public_to_site.do {briefing_id}"
    exit 198
}


* ============================================================== 
* DO NOT TOUCH: CHECK REQUIRED GLOBALS
* ============================================================== 
*
* This DO file expects the project path settings to have already been
* loaded by the calling briefing DO file, for example via:
*
*   do "scripts/stata/config/bnr_paths_LOCAL.do"
*
* Required:
*   $BNR_PUBLIC
*
* Optional:
*   $BNR_SITE
*
* If $BNR_SITE is not defined, this file derives the site folder from
* $BNR_PUBLIC by assuming the standard repository structure:
*
*   info-hub/
*     outputs/public/
*     site/

if "$BNR_PUBLIC" == "" {
    display as error "Global BNR_PUBLIC is not defined."
    display as error "Run bnr_paths_LOCAL.do before calling mirror_public_to_site.do."
    exit 198
}


* ============================================================== 
* DO NOT TOUCH: DEFINE SOURCE AND TARGET FOLDERS
* ============================================================== 

local publicbriefing "$BNR_PUBLIC/briefings/`briefing_id'"

if "$BNR_SITE" != "" {
    local site_root "$BNR_SITE"
}
else {
    local project_root = subinstr("$BNR_PUBLIC", "/outputs/public", "", .)
    local site_root "`project_root'/site"
}

local site_files_root "`site_root'/downloads/files"
local site_briefings "`site_files_root'/briefings"
local sitebriefing "`site_briefings'/`briefing_id'"


* ============================================================== 
* DO NOT TOUCH: BASIC SAFETY CHECKS
* ============================================================== 
*
* readme.txt is used as a simple marker that the public bundle exists.
* The public bundle should have been created by the main briefing DO file
* before this mirror step is called.

capture confirm file "`publicbriefing'/readme.txt"

if _rc {
    display as error "Public briefing bundle not found or incomplete."
    display as error "Expected file:"
    display as error "  `publicbriefing'/readme.txt"
    display as error "Run the public-release section of the briefing DO file first."
    exit 601
}


* ============================================================== 
* DO NOT TOUCH: MIRROR PUBLIC BUNDLE INTO WEBSITE DOWNLOADS
* ============================================================== 
*
* This uses PowerShell because the current BNR Windows workflow already
* uses PowerShell for ZIP creation. It avoids fragile hand-written
* recursive folder deletion in Stata.
*
* Steps:
*   1. Ensure the site downloads/briefings folder exists.
*   2. Remove any old website mirror for this briefing.
*   3. Copy the full approved public briefing bundle into the site.
*
* This prevents stale files remaining in the website mirror after a
* filename changes or a file is removed from the public bundle.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "New-Item -ItemType Directory -Path '`site_briefings'' -Force | Out-Null; if (Test-Path -LiteralPath '`sitebriefing'') { Remove-Item -LiteralPath '`sitebriefing'' -Recurse -Force }; Copy-Item -LiteralPath '`publicbriefing'' -Destination '`site_briefings'' -Recurse -Force"


* ============================================================== 
* DO NOT TOUCH: CONFIRM WEBSITE MIRROR
* ============================================================== 

capture confirm file "`sitebriefing'/readme.txt"

if _rc {
    display as error "Website mirror failed."
    display as error "Expected file:"
    display as error "  `sitebriefing'/readme.txt"
    exit 603
}


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR public briefing bundle mirrored to website" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:       `briefing_id'" _n ///
    as result "  Public source:     `publicbriefing'" _n ///
    as result "  Website mirror:    `sitebriefing'" _n ///
    as text "------------------------------------------------------------" _n
    
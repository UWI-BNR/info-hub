/*
* =====================================================================
 DO-FILE:     mirror_public_to_site.do
 PROJECT:     BNR info-hub
 PURPOSE:     Mirror an approved public artefact bundle into the Quarto
              website downloads folder.

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.1

 USAGE:
   Called from a briefing or artefact driver DO file after the public
   release bundle has been created.

   Example:
     do "scripts/stata/common/mirror_public_to_site.do" "`briefing_id'"

 REQUIRED INPUT:
   The briefing or artefact ID must be passed as argument 1.

   Example IDs:
     cvd_cases_2023_v1
     cvd_forensics_2025_v1

 EXPECTED SOURCE:
   outputs/public/briefings/{briefing_id}/

 WEBSITE MIRROR TARGET:
   site/downloads/files/briefings/{briefing_id}/

 NOTES:
   This file does not create analytical outputs.
   It does not promote staging outputs to public outputs.
   It only mirrors the already-approved public artefact bundle into the
   website folder so that Quarto can render and serve figures, workbooks,
   ZIP files, metadata, and other static resources.

   The authoritative public release remains:
     outputs/public/briefings/{briefing_id}/

   The website copy is disposable and can be regenerated.

   This helper deliberately allows partial artefact bundles. A public
   folder may contain only one figure, one metadata file, or any other
   approved subset of files. It does not require all standard briefing
   subfolders to be present.
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
* loaded by the calling briefing or artefact DO file, for example via:
*
*   do "scripts/stata/config/bnr_paths_LOCAL.do"
*
* Preferred:
*   $BNR_PUBLIC
*
* Also supported:
*   $BNR_OUTPUTS
*
* Optional:
*   $BNR_SITE
*
* If $BNR_SITE is not defined, this file derives the site folder from
* the standard repository structure:
*
*   info-hub/
*     outputs/public/
*     site/

local bnr_public ""

if "$BNR_PUBLIC" != "" {
    local bnr_public "$BNR_PUBLIC"
}
else if "$BNR_OUTPUTS" != "" {
    local bnr_public "$BNR_OUTPUTS/public"
}

if "`bnr_public'" == "" {
    display as error "Neither BNR_PUBLIC nor BNR_OUTPUTS is defined."
    display as error "Run bnr_paths_LOCAL.do before calling mirror_public_to_site.do."
    exit 198
}


* ============================================================== 
* DO NOT TOUCH: DEFINE SOURCE AND TARGET FOLDERS
* ============================================================== 

local publicbriefing "`bnr_public'/briefings/`briefing_id'"

if "$BNR_SITE" != "" {
    local site_root "$BNR_SITE"
}
else {
    local project_root = subinstr("`bnr_public'", "/outputs/public", "", .)
    local site_root "`project_root'/site"
}

local site_files_root "`site_root'/downloads/files"
local site_briefings "`site_files_root'/briefings"
local sitebriefing "`site_briefings'/`briefing_id'"


* ============================================================== 
* DO NOT TOUCH: BASIC SAFETY CHECKS
* ============================================================== 
*
* Earlier versions required:
*
*   readme.txt
*
* as a completeness marker. That is too strict for one-off artefacts.
* This version only requires the public source folder to exist. It may
* contain a complete briefing bundle or a deliberately partial artefact
* bundle, such as a single PNG figure.

quietly mata: st_local("public_exists", strofreal(direxists("`publicbriefing'")))

if "`public_exists'" != "1" {
    display as error "Public artefact folder not found."
    display as error "Expected folder:"
    display as error "  `publicbriefing'"
    display as error "Run the public-release section of the calling DO file first."
    exit 601
}


* Optional inventory checks.
* These are useful for full briefing bundles but are not required for
* deliberately partial artefact bundles.

local has_readme = 1
capture confirm file "`publicbriefing'/readme.txt"
if _rc {
    local has_readme = 0
}

local has_manifest = 1
capture confirm file "`publicbriefing'/downloads.yml"
if _rc {
    local has_manifest = 0
}

if `has_readme' == 0 & `has_manifest' == 0 {
    display as text _n ///
        "NOTE: No readme.txt or downloads.yml found in the public artefact folder." _n ///
        "      Continuing because partial artefact bundles are allowed." _n
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
*   2. Remove any old website mirror for this briefing or artefact.
*   3. Copy the full approved public folder into the site.
*
* This prevents stale files remaining in the website mirror after a
* filename changes or a file is removed from the public folder.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "$ErrorActionPreference = 'Stop'; New-Item -ItemType Directory -Path '`site_briefings'' -Force | Out-Null; if (Test-Path -LiteralPath '`sitebriefing'') { Remove-Item -LiteralPath '`sitebriefing'' -Recurse -Force }; Copy-Item -LiteralPath '`publicbriefing'' -Destination '`site_briefings'' -Recurse -Force"


* ============================================================== 
* DO NOT TOUCH: CONFIRM WEBSITE MIRROR
* ============================================================== 
*
* Confirmation now checks that the target folder exists. It does not
* require readme.txt, downloads.yml, figures/, datasets/, metadata/,
* workbook/, or any other standard briefing subfolder.

quietly mata: st_local("site_exists", strofreal(direxists("`sitebriefing'")))

if "`site_exists'" != "1" {
    display as error "Website mirror failed."
    display as error "Expected folder:"
    display as error "  `sitebriefing'"
    exit 603
}


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR public artefact folder mirrored to website" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Artefact ID:       `briefing_id'" _n ///
    as result "  Public source:     `publicbriefing'" _n ///
    as result "  Website mirror:    `sitebriefing'" _n ///
    as text "------------------------------------------------------------" _n
    
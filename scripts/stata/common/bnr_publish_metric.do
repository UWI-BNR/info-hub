/*
===============================================================================
 DO-FILE:     bnr_publish_metric.do
 PROJECT:     BNR info-hub
 PURPOSE:     Standard publisher for BNR metric output packages

 AUTHOR:      Ian R Hambleton / BNR Analytics Team
 VERSION:     Draft v0.1
 DATE:        2026-05-17

 USAGE:
   Called at the end of a metric DO file:

       do "$BNR_STATA/common/bnr_publish_metric.do" ///
           "{domain}" ///
           "{metric_family}" ///
           "{release_id}" ///
           "{release_dataset_id}" ///
           "{current_dataset_id}"

 EXAMPLE:
       do "$BNR_STATA/common/bnr_publish_metric.do" ///
           "cvd" ///
           "burden" ///
           "cvd_2026_05" ///
           "cvd_burden_metrics_cvd_2026_05" ///
           "cvd_burden_metrics_current"

 EXPECTED STAGING STRUCTURE:
   outputs/staging/metrics/{domain}/{metric_family}/
     {release_dataset_id}.dta
     {release_dataset_id}.csv
     {current_dataset_id}.dta
     {current_dataset_id}.csv

 CREATED BY THIS HELPER:
   In staging:
     metadata/{release_dataset_id}.yml
     metadata/{current_dataset_id}.yml
     metadata/metric_package.yml
     readme.txt
     downloads.yml

   In public:
     outputs/public/metrics/{domain}/{metric_family}/
       copied metric package
       bnr_{domain}_{metric_family}_{release_id}.zip

   In site:
     site/downloads/files/metrics/{domain}/{metric_family}/
       mirror of the public package

 DESIGN PRINCIPLE:
   This helper owns only publication mechanics.

   It does not calculate metrics.
   It does not alter metric values.
   It does not apply disclosure control.
   It packages metric artefacts already written to staging/.
===============================================================================
*/


* ==============================================================================
* READ REQUIRED ARGUMENTS
* ==============================================================================

args domain metric_family release_id release_dataset_id current_dataset_id

if "`domain'" == "" {
    display as error "No domain supplied."
    exit 198
}

if "`metric_family'" == "" {
    display as error "No metric_family supplied."
    exit 198
}

if "`release_id'" == "" {
    display as error "No release_id supplied."
    exit 198
}

if "`release_dataset_id'" == "" {
    display as error "No release_dataset_id supplied."
    exit 198
}

if "`current_dataset_id'" == "" {
    display as error "No current_dataset_id supplied."
    exit 198
}


* ==============================================================================
* CHECK REQUIRED PROJECT PATH GLOBALS
* ==============================================================================

foreach required_global in BNR_STAGING BNR_PUBLIC BNR_STATA {

    if "$`required_global'" == "" {
        display as error "Required global `required_global' is not defined."
        display as error "Run bnr_paths_LOCAL.do before calling bnr_publish_metric.do."
        exit 198
    }
}


* ==============================================================================
* DEFINE STANDARD PATHS
* ==============================================================================

local stagingpackage "$BNR_STAGING/metrics/`domain'/`metric_family'"
local stagingmetadata "`stagingpackage'/metadata"

local publicroot     "$BNR_PUBLIC/metrics/`domain'"
local publicpackage  "$BNR_PUBLIC/metrics/`domain'/`metric_family'"

local sitepackage    "$BNR_REPO/site/downloads/files/metrics/`domain'/`metric_family'"

local zip_file       "bnr_`domain'_`metric_family'_`release_id'.zip"
local publiczip      "`publicpackage'/`zip_file'"

local release_dta    "`stagingpackage'/`release_dataset_id'.dta"
local release_csv    "`stagingpackage'/`release_dataset_id'.csv"

local current_dta    "`stagingpackage'/`current_dataset_id'.dta"
local current_csv    "`stagingpackage'/`current_dataset_id'.csv"


* ==============================================================================
* BASIC SAFETY CHECKS
* ==============================================================================

quietly mata: st_local("staging_exists", strofreal(direxists("`stagingpackage'")))

if "`staging_exists'" != "1" {
    display as error "Staging metric package folder not found:"
    display as error "  `stagingpackage'"
    exit 601
}

foreach f in ///
    "`release_dta'" ///
    "`release_csv'" ///
    "`current_dta'" ///
    "`current_csv'" {

    capture confirm file "`f'"

    if _rc {
        display as error "Expected metric artefact not found:"
        display as error "  `f'"
        exit 601
    }
}

cap mkdir "`stagingmetadata'"


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR metric publisher started" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Domain:            `domain'" _n ///
    as result "  Metric family:     `metric_family'" _n ///
    as result "  Release ID:        `release_id'" _n ///
    as result "  Staging folder:    `stagingpackage'" _n ///
    as result "  Release dataset:   `release_dataset_id'" _n ///
    as result "  Current dataset:   `current_dataset_id'" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================================
* CREATE DATASET-LEVEL YAML METADATA
* ==============================================================================
* Prefer bnryml if that is the final ADO name.
* If your installed helper is named bnr_yml, change bnryml to bnr_yml below.

foreach dataset_id in `release_dataset_id' `current_dataset_id' {

    capture confirm file "`stagingpackage'/`dataset_id'.dta"

    if _rc {
        display as error "Declared metric dataset not found:"
        display as error "  `stagingpackage'/`dataset_id'.dta"
        exit 601
    }

    capture noisily bnr_yml, ///
        dtafile("`stagingpackage'/`dataset_id'.dta") ///
        ymlfile("`stagingmetadata'/`dataset_id'.yml") ///
        datasetid("`dataset_id'")

    if _rc {
        display as error "bnryml failed for dataset:"
        display as error "  `dataset_id'"
        display as error "If the helper ADO is named bnr_yml instead, update this publisher."
        exit _rc
    }

    display as result "Dataset metadata created:"
    display as result "  `stagingmetadata'/`dataset_id'.yml"
}


* ==============================================================================
* CREATE PACKAGE-LEVEL METADATA
* ==============================================================================

tempname packageyml

file open `packageyml' using "`stagingmetadata'/metric_package.yml", ///
    write replace text

file write `packageyml' "schema: bnr_metric_package_v1" _n
file write `packageyml' "domain: `domain'" _n
file write `packageyml' "metric_family: `metric_family'" _n
file write `packageyml' "release_id: `release_id'" _n
file write `packageyml' "release_date: `c(current_date)'" _n
file write `packageyml' "" _n

file write `packageyml' "title: |-" _n
file write `packageyml' "  BNR `domain' `metric_family' metric package" _n
file write `packageyml' "" _n

file write `packageyml' "description: |-" _n
file write `packageyml' "  Release-stamped and current metric outputs for the `domain' `metric_family' metric family." _n
file write `packageyml' "" _n

file write `packageyml' "datasets:" _n
file write `packageyml' "  - id: `release_dataset_id'" _n
file write `packageyml' "    dta: `release_dataset_id'.dta" _n
file write `packageyml' "    csv: `release_dataset_id'.csv" _n
file write `packageyml' "    yml: metadata/`release_dataset_id'.yml" _n
file write `packageyml' "  - id: `current_dataset_id'" _n
file write `packageyml' "    dta: `current_dataset_id'.dta" _n
file write `packageyml' "    csv: `current_dataset_id'.csv" _n
file write `packageyml' "    yml: metadata/`current_dataset_id'.yml" _n
file write `packageyml' "" _n

file write `packageyml' "build:" _n
file write `packageyml' "  build_date: `c(current_date)'" _n
file write `packageyml' "  build_time: `c(current_time)'" _n
file write `packageyml' "  stata_version: `c(version)'" _n
file write `packageyml' "  analyst: `c(username)'" _n

file close `packageyml'

display as result "Package metadata created:"
display as result "  `stagingmetadata'/metric_package.yml"


* ==============================================================================
* CREATE README
* ==============================================================================

tempname readme

file open `readme' using "`stagingpackage'/readme.txt", ///
    write replace text

file write `readme' "BNR `domain' `metric_family' metric package" _n
file write `readme' "" _n
file write `readme' "Domain: `domain'" _n
file write `readme' "Metric family: `metric_family'" _n
file write `readme' "Release ID: `release_id'" _n
file write `readme' "Release date: `c(current_date)'" _n
file write `readme' "" _n

file write `readme' "Contents:" _n
file write `readme' "- `release_dataset_id'.dta: release-stamped Stata metric dataset" _n
file write `readme' "- `release_dataset_id'.csv: release-stamped CSV metric dataset" _n
file write `readme' "- `current_dataset_id'.dta: current Stata metric dataset for publication/dashboard use" _n
file write `readme' "- `current_dataset_id'.csv: current CSV metric dataset for publication/dashboard use" _n
file write `readme' "- metadata/: dataset and package metadata" _n
file write `readme' "- downloads.yml: manifest used by the BNR website downloads catalogue" _n
file write `readme' "" _n

file write `readme' "Notes:" _n
file write `readme' "The release-stamped files are the archival/public release files." _n
file write `readme' "The current files are convenience copies for website and dashboard use." _n
file write `readme' "Metric values are calculated upstream by Stata metric DO files." _n
file write `readme' "This publisher does not alter metric values." _n

file close `readme'

display as result "README created:"
display as result "  `stagingpackage'/readme.txt"


* ==============================================================================
* CREATE DOWNLOAD MANIFEST
* ==============================================================================
* The central downloads page currently lists ZIP packages only.
* Individual CSV/DTA/YML files remain inside the ZIP package.

tempname downloads_yml

file open `downloads_yml' using "`stagingpackage'/downloads.yml", ///
    write replace text

file write `downloads_yml' "schema: bnr_download_manifest_v1" _n
file write `downloads_yml' "package_type: metric" _n
file write `downloads_yml' "domain: `domain'" _n
file write `downloads_yml' "metric_family: `metric_family'" _n
file write `downloads_yml' "release_id: `release_id'" _n
file write `downloads_yml' "release_date: `c(current_date)'" _n
file write `downloads_yml' "" _n

file write `downloads_yml' "title: |-" _n
file write `downloads_yml' "  BNR `domain' `metric_family' metric package" _n
file write `downloads_yml' "" _n

file write `downloads_yml' "description: |-" _n
file write `downloads_yml' "  Release-stamped metric outputs and metadata for the `domain' `metric_family' metric family." _n
file write `downloads_yml' "" _n

file write `downloads_yml' "downloads:" _n
file write `downloads_yml' "  - id: `domain'_`metric_family'_`release_id'_zip" _n
file write `downloads_yml' "    title: BNR `domain' `metric_family' metric package" _n
file write `downloads_yml' "    artefact_type: ZIP package" _n
file write `downloads_yml' "    format: ZIP" _n
file write `downloads_yml' "    file: `zip_file'" _n
file write `downloads_yml' "    href: files/metrics/`domain'/`metric_family'/`zip_file'" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Release-stamped metric outputs and metadata." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 20" _n

file close `downloads_yml'

display as result "Download manifest created:"
display as result "  `stagingpackage'/downloads.yml"


* ==============================================================================
* COPY STAGING PACKAGE TO PUBLIC
* ==============================================================================

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "$ErrorActionPreference = 'Stop'; New-Item -ItemType Directory -Path '`publicroot'' -Force | Out-Null; if (Test-Path -LiteralPath '`publicpackage'') { Remove-Item -LiteralPath '`publicpackage'' -Recurse -Force }; Copy-Item -LiteralPath '`stagingpackage'' -Destination '`publicroot'' -Recurse -Force"


quietly mata: st_local("public_exists", strofreal(direxists("`publicpackage'")))

if "`public_exists'" != "1" {
    display as error "Public copy failed."
    display as error "Expected folder:"
    display as error "  `publicpackage'"
    exit 603
}


* ==============================================================================
* CREATE ZIP PACKAGE IN PUBLIC
* ==============================================================================

cap erase "`publiczip'"

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "$ErrorActionPreference = 'Stop'; if (Test-Path -LiteralPath '`publiczip'') { Remove-Item -LiteralPath '`publiczip'' -Force }; Compress-Archive -LiteralPath '`publicpackage'' -DestinationPath '`publiczip'' -Force"

capture confirm file "`publiczip'"

if _rc {
    display as error "ZIP package was not created:"
    display as error "  `publiczip'"
    exit 603
}

display as result "ZIP package created:"
display as result "  `publiczip'"


* ==============================================================================
* MIRROR PUBLIC PACKAGE TO WEBSITE DOWNLOADS
* ==============================================================================
* This directly mirrors:
*
*   outputs/public/metrics/{domain}/{metric_family}/
*
* to:
*
*   site/downloads/files/metrics/{domain}/{metric_family}/
*
* This avoids reusing the briefing-specific mirror helper.

if "$BNR_REPO" == "" {
    display as error "Required global BNR_REPO is not defined."
    display as error "This helper needs BNR_REPO to mirror into site/downloads/files."
    exit 198
}

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "$ErrorActionPreference = 'Stop'; New-Item -ItemType Directory -Path '$BNR_REPO/site/downloads/files/metrics/`domain'' -Force | Out-Null; if (Test-Path -LiteralPath '`sitepackage'') { Remove-Item -LiteralPath '`sitepackage'' -Recurse -Force }; Copy-Item -LiteralPath '`publicpackage'' -Destination '$BNR_REPO/site/downloads/files/metrics/`domain'' -Recurse -Force"


quietly mata: st_local("site_exists", strofreal(direxists("`sitepackage'")))

if "`site_exists'" != "1" {
    display as error "Website mirror failed."
    display as error "Expected folder:"
    display as error "  `sitepackage'"
    exit 603
}


* ==============================================================================
* FINAL CONFIRMATION
* ==============================================================================

display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR metric package published" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Domain:            `domain'" _n ///
    as result "  Metric family:     `metric_family'" _n ///
    as result "  Release ID:        `release_id'" _n ///
    as result "  Staging folder:    `stagingpackage'" _n ///
    as result "  Public folder:     `publicpackage'" _n ///
    as result "  Site folder:       `sitepackage'" _n ///
    as result "  ZIP package:       `publiczip'" _n ///
    as text "------------------------------------------------------------" _n

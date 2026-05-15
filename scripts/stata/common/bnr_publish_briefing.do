/*
* =====================================================================
 DO-FILE:     bnr_publish_briefing.do
 PROJECT:     BNR info-hub
 PURPOSE:     Standard publisher for BNR briefing/output packages

 AUTHOR:      Ian R Hambleton
 VERSION:     v0.1-draft

 USAGE:
   Called at the end of an analyst-owned briefing/output DO file:

       do "$BNR_STATA/common/bnr_publish_briefing.do" "`briefing_id'"

   or, if using a local project path:

       do "`localpath'/scripts/stata/common/bnr_publish_briefing.do" ///
           "`briefing_id'"

 REQUIRED INPUT:
   Argument 1:
     briefing_id

   Required staging control file:
     outputs/staging/briefings/{briefing_id}/metadata/release_control.yml

 EXPECTED STAGING STRUCTURE:
   outputs/staging/briefings/{briefing_id}/
     datasets/
     figures/
     workbook/
     metadata/
       release_control.yml

 CREATED BY THIS HELPER:
   In staging:
     metadata/{dataset_id}.yml
     metadata/briefing.yml
     readme.txt
     workbook/{workbook_file}, if requested
     downloads.yml

   In public:
     outputs/public/briefings/{briefing_id}/
       complete copied public package
       bnr_{briefing_id}.zip, if requested

   In site:
     site/downloads/files/briefings/{briefing_id}/
       mirror of the public package, via mirror_public_to_site.do

 DESIGN PRINCIPLE:
   One briefing/output package should have one analyst-owned DO file.
   This helper owns the invariant release machinery so that future users
   do not need to copy, edit, or remember long metadata/copy/ZIP blocks.

   The helper deliberately uses straightforward Stata code rather than a
   compact or over-general parser. It reads only the small, restricted
   release_control.yml format written by the briefing DO template.

 IMPORTANT:
   This helper is not an analytics script.
   It should not derive surveillance measures or alter released data.
   It only packages artefacts already written to staging/.
* =====================================================================
*/


* ==============================================================================
* DO NOT TOUCH: READ REQUIRED ARGUMENT
* ==============================================================================

args briefing_id

if "`briefing_id'" == "" {
    display as error "No briefing_id supplied."
    display as error "Usage: do bnr_publish_briefing.do {briefing_id}"
    exit 198
}


* ==============================================================================
* DO NOT TOUCH: CHECK REQUIRED PROJECT PATH GLOBALS
* ==============================================================================
* The calling briefing DO file should already have loaded:
*
*   scripts/stata/config/bnr_paths_LOCAL.do
*
* This helper relies on those project globals. It does not set local
* machine-specific paths itself.

foreach required_global in BNR_STAGING BNR_PUBLIC BNR_STATA {

    if "$`required_global'" == "" {
        display as error "Required global `required_global' is not defined."
        display as error "Run bnr_paths_LOCAL.do before calling bnr_publish_briefing.do."
        exit 198
    }
}


* ==============================================================================
* DO NOT TOUCH: DEFINE STANDARD STAGING AND PUBLIC PATHS
* ==============================================================================
* The physical pathway remains:
*
*   outputs/staging/briefings/
*   outputs/public/briefings/
*   site/downloads/files/briefings/
*
* In this publication system, briefings/ is the historical release-package
* pathway. The specific type of package is recorded in release_control.yml
* using output_type.

local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures  "`stagingbriefing'/figures"
local stagingworkbook "`stagingbriefing'/workbook"
local stagingmetadata "`stagingbriefing'/metadata"

local publicbriefing "$BNR_PUBLIC/briefings/`briefing_id'"
local publiczip      "`publicbriefing'/bnr_`briefing_id'.zip"

local control_file "`stagingmetadata'/release_control.yml"


* ==============================================================================
* DO NOT TOUCH: BASIC STAGING SAFETY CHECKS
* ==============================================================================

quietly mata: st_local("staging_exists", strofreal(direxists("`stagingbriefing'")))

if "`staging_exists'" != "1" {
    display as error "Staging briefing folder not found:"
    display as error "  `stagingbriefing'"
    display as error "Run the analyst-owned briefing DO file before publishing."
    exit 601
}

capture confirm file "`control_file'"
if _rc {
    display as error "Release control file not found:"
    display as error "  `control_file'"
    display as error "The analyst-owned DO file must write metadata/release_control.yml before calling this helper."
    exit 601
}

foreach folder in datasets figures workbook metadata {
    cap mkdir "`stagingbriefing'/`folder'"
}


* ==============================================================================
* DO NOT TOUCH: READ RELEASE CONTROL FILE
* ==============================================================================
* This is a deliberately small reader for the restricted release_control.yml
* structure written by the BNR briefing template.
*
* It supports:
*   key: value
*   key: |-
*     one or more indented text lines
*
* It also supports the workbook_sheets list used by the cases briefing:
*
*   workbook_sheets:
*     - dataset_id: cvd_cases_weekly
*       data_sheet: cvd_cases_weekly
*       metadata_sheet: meta_weekly
*       variable_sheet: vars_weekly
*
* It is not intended to be a general YAML parser.

tempname control
file open `control' using "`control_file'", read text

local active_block ""
local workbook_section 0
local workbook_sheet_count 0

* Workbook sheet settings are stored as simple parallel lists.
* This is easier to read and debug than nested or indirect macro names.
local workbook_datasets    ""
local workbook_data_sheets ""
local workbook_meta_sheets ""
local workbook_vars_sheets ""

file read `control' line

while r(eof) == 0 {

    local raw `"`line'"'
    local trimmed = strtrim(`"`raw'"')

    local process_line 1

    * --------------------------------------------------------------------------
    * Continue reading an active block scalar.
    * --------------------------------------------------------------------------
    * A block scalar begins with:
    *
    *   key: |-
    *
    * and continues while lines are indented by two spaces.
    * For handover simplicity, multiple block lines are joined with spaces.
    * This keeps the parsed value easy to write back into README/YAML outputs.

    if "`active_block'" != "" {

        if substr(`"`raw'"', 1, 2) == "  " | "`trimmed'" == "" {

            if "`trimmed'" != "" {

                local block_text = substr(`"`raw'"', 3, .)
                local block_text = strtrim(`"`block_text'"')

                if "``active_block''" == "" {
                    local `active_block' `"`block_text'"'
                }
                else {
                    local `active_block' `"``active_block'' `block_text'"'
                }
            }

            local process_line 0
        }
        else {
            local active_block ""
        }
    }


    * --------------------------------------------------------------------------
    * Parse ordinary lines.
    * --------------------------------------------------------------------------

    if `process_line' == 1 & "`trimmed'" != "" {

        * Start of workbook_sheets section.
        if "`trimmed'" == "workbook_sheets:" {
            local workbook_section 1
            file read `control' line
            continue
        }

        * Start of a workbook sheet item.
        if `workbook_section' == 1 & substr("`trimmed'", 1, 13) == "- dataset_id:" {

            local ++workbook_sheet_count

            local value = substr("`trimmed'", 14, .)
            local value = strtrim("`value'")

            local workbook_datasets "`workbook_datasets' `value'"

            file read `control' line
            continue
        }

        * Other workbook sheet fields.
        if `workbook_section' == 1 & `workbook_sheet_count' > 0 {

            local colon_pos = strpos("`trimmed'", ":")

            if `colon_pos' > 0 {

                local key = substr("`trimmed'", 1, `colon_pos' - 1)
                local value = substr("`trimmed'", `colon_pos' + 1, .)
                local key = strtrim("`key'")
                local value = strtrim("`value'")

                if "`key'" == "data_sheet" {
                    local workbook_data_sheets "`workbook_data_sheets' `value'"
                    file read `control' line
                    continue
                }

                if "`key'" == "metadata_sheet" {
                    local workbook_meta_sheets "`workbook_meta_sheets' `value'"
                    file read `control' line
                    continue
                }

                if "`key'" == "variable_sheet" {
                    local workbook_vars_sheets "`workbook_vars_sheets' `value'"
                    file read `control' line
                    continue
                }
            }
        }

        * Ordinary key/value or key/block line.
        local colon_pos = strpos(`"`trimmed'"', ":")

        if `colon_pos' > 0 {

            local key = substr(`"`trimmed'"', 1, `colon_pos' - 1)
            local value = substr(`"`trimmed'"', `colon_pos' + 1, .)

            local key = strtrim(`"`key'"')
            local value = strtrim(`"`value'"')

            * If this is a block scalar, switch into block-reading mode.
            if "`value'" == "|-" {
                local `key' ""
                local active_block "`key'"
            }
            else {
                local `key' `"`value'"'
            }
        }
    }

    file read `control' line
}

file close `control'


* ==============================================================================
* DO NOT TOUCH: APPLY SAFE DEFAULTS
* ==============================================================================

if "`create_workbook'" == "" local create_workbook 0
if "`create_zip'"      == "" local create_zip 0
if "`list_zip'"        == "" local list_zip 0

if "`workbook_file'" == "" {
    local workbook_file "bnr_`briefing_id'.xlsx"
}

if "`zip_title'" == "" {
    local zip_title "Full public output package"
}

if "`zip_description'" == "" {
    local zip_description "Complete public output package containing released data, figures, metadata, and documentation."
}

if "`release_date'" == "" {
    local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
}


* ==============================================================================
* DO NOT TOUCH: VALIDATE CONTROL VALUES
* ==============================================================================

foreach required_local in ///
    briefing_id ///
    briefing_name ///
    output_type ///
    domain ///
    surveillance_area ///
    registry ///
    geography ///
    period ///
    release_date ///
    title {

    if "``required_local''" == "" {
        display as error "Required release-control field is missing: `required_local'"
        display as error "Check:"
        display as error "  `control_file'"
        exit 198
    }
}

foreach flag in create_workbook create_zip list_zip {

    if !inlist("``flag''", "0", "1") {
        display as error "Invalid release-control flag: `flag' = ``flag''"
        display as error "Expected 0 or 1."
        exit 198
    }
}

if "`list_zip'" == "1" & "`create_zip'" != "1" {
    display as error "Inconsistent release-control settings."
    display as error "list_zip is 1 but create_zip is not 1."
    display as error "A ZIP cannot be listed unless it is created."
    exit 198
}


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR standard publisher started" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:       `briefing_id'" _n ///
    as result "  Output type:       `output_type'" _n ///
    as result "  Staging folder:    `stagingbriefing'" _n ///
    as result "  Released datasets: `released_datasets'" _n ///
    as result "  Released figures:  `released_figures'" _n ///
    as result "  Create workbook:   `create_workbook'" _n ///
    as result "  Create ZIP:        `create_zip'" _n ///
    as result "  List ZIP:          `list_zip'" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================================
* DO NOT TOUCH: CREATE DATASET-LEVEL YAML METADATA
* ==============================================================================
* Dataset-level metadata are generated from the Stata DTA files.
*
* Requirement:
*   Each released dataset must have:
*     - clear variable labels;
*     - value labels where appropriate;
*     - dataset notes using notes _dta:;
*     - a DTA file saved in staging/datasets/.
*
* The helper bnr_yml reads those labels/notes and writes the companion
* metadata YAML file.

if "`released_datasets'" != "" {

    foreach dataset_id of local released_datasets {

        capture confirm file "`stagingdatasets'/`dataset_id'.dta"

        if _rc {
            display as error "Declared released dataset not found:"
            display as error "  `stagingdatasets'/`dataset_id'.dta"
            display as error "Check released_datasets in release_control.yml."
            exit 601
        }

        bnr_yml, ///
            dtafile("`stagingdatasets'/`dataset_id'.dta") ///
            ymlfile("`stagingmetadata'/`dataset_id'.yml") ///
            datasetid("`dataset_id'")

        display as result "Dataset metadata created:"
        display as result "  `stagingmetadata'/`dataset_id'.yml"
    }
}
else {
    display as text "No released datasets declared; skipping dataset-level YAML metadata."
}


* ==============================================================================
* DO NOT TOUCH: CHECK DECLARED FIGURES
* ==============================================================================
* Figures are not parsed for metadata by this helper. They are checked so that
* release_control.yml does not claim a figure that was not exported.

if "`released_figures'" != "" {

    foreach figure_id of local released_figures {

        capture confirm file "`stagingfigures'/`figure_id'.png"

        if _rc {
            display as error "Declared released figure not found:"
            display as error "  `stagingfigures'/`figure_id'.png"
            display as error "Check released_figures in release_control.yml."
            exit 601
        }
    }
}
else {
    display as text "No released figures declared."
}


* ==============================================================================
* DO NOT TOUCH: CREATE BRIEFING-LEVEL METADATA
* ==============================================================================
* This metadata file describes the whole briefing/output package.
*
* Dataset-specific metadata files remain separate:
*   metadata/{dataset_id}.yml
*
* The briefing-level metadata file provides the release context:
*   - output type;
*   - domain and surveillance area;
*   - public page;
*   - datasets;
*   - figures;
*   - rights/contact/build details.

tempname briefingyml

file open `briefingyml' using "`stagingmetadata'/briefing.yml", ///
    write replace text

file write `briefingyml' "schema: bnr_briefing_metadata_v1" _n
file write `briefingyml' "briefing_id: `briefing_id'" _n
file write `briefingyml' "briefing_name: `briefing_name'" _n
file write `briefingyml' "output_type: `output_type'" _n
file write `briefingyml' "domain: `domain'" _n
file write `briefingyml' "surveillance_area: `surveillance_area'" _n
file write `briefingyml' "registry: `registry'" _n
file write `briefingyml' "geography: `geography'" _n
file write `briefingyml' "period: `period'" _n
file write `briefingyml' "release_date: `release_date'" _n
file write `briefingyml' "" _n

file write `briefingyml' "title: |-" _n
file write `briefingyml' "  `title'" _n
file write `briefingyml' "" _n

if "`short_title'" != "" {
    file write `briefingyml' "short_title: |-" _n
    file write `briefingyml' "  `short_title'" _n
    file write `briefingyml' "" _n
}

if "`description'" != "" {
    file write `briefingyml' "description: |-" _n
    file write `briefingyml' "  `description'" _n
    file write `briefingyml' "" _n
}

if "`limitations'" != "" {
    file write `briefingyml' "limitations: |-" _n
    file write `briefingyml' "  `limitations'" _n
    file write `briefingyml' "" _n
}

if "`data_note'" != "" {
    file write `briefingyml' "data_note: |-" _n
    file write `briefingyml' "  `data_note'" _n
    file write `briefingyml' "" _n
}

if "`rights'" != "" {
    file write `briefingyml' "rights: |-" _n
    file write `briefingyml' "  `rights'" _n
    file write `briefingyml' "" _n
}

if "`contact'" != "" {
    file write `briefingyml' "contact: |-" _n
    file write `briefingyml' "  `contact'" _n
    file write `briefingyml' "" _n
}

if "`briefing_page'" != "" {
    file write `briefingyml' "briefing_page: `briefing_page'" _n
    file write `briefingyml' "" _n
}

file write `briefingyml' "datasets:" _n

if "`released_datasets'" != "" {
    foreach dataset_id of local released_datasets {
        file write `briefingyml' "  - id: `dataset_id'" _n
        file write `briefingyml' "    dta: datasets/`dataset_id'.dta" _n
        file write `briefingyml' "    csv: datasets/`dataset_id'.csv" _n
        file write `briefingyml' "    yml: metadata/`dataset_id'.yml" _n
    }
}
else {
    file write `briefingyml' "  []" _n
}

file write `briefingyml' "" _n
file write `briefingyml' "figures:" _n

if "`released_figures'" != "" {
    foreach figure_id of local released_figures {
        file write `briefingyml' "  - id: `figure_id'" _n
        file write `briefingyml' "    file: figures/`figure_id'.png" _n
    }
}
else {
    file write `briefingyml' "  []" _n
}

file write `briefingyml' "" _n
file write `briefingyml' "build:" _n
file write `briefingyml' "  build_date: `c(current_date)'" _n
file write `briefingyml' "  build_time: `c(current_time)'" _n
file write `briefingyml' "  stata_version: `c(version)'" _n
file write `briefingyml' "  analyst: `c(username)'" _n

if "`analysis_script'" != "" {
    file write `briefingyml' "  analysis_script: `analysis_script'" _n
}

file close `briefingyml'

display as result "Briefing-level metadata created:"
display as result "  `stagingmetadata'/briefing.yml"


* ==============================================================================
* DO NOT TOUCH: CREATE PACKAGE README
* ==============================================================================
* The README is deliberately plain text. It is designed for users who download
* the ZIP package or browse the public artefact folder.

tempname readme

file open `readme' using "`stagingbriefing'/readme.txt", ///
    write replace text

file write `readme' "`title'" _n
file write `readme' "" _n
file write `readme' "Briefing ID: `briefing_id'" _n
file write `readme' "Output type: `output_type'" _n
file write `readme' "Domain: `domain'" _n
file write `readme' "Surveillance area: `surveillance_area'" _n
file write `readme' "Registry: `registry'" _n
file write `readme' "Geography: `geography'" _n
file write `readme' "Period: `period'" _n
file write `readme' "Release date: `release_date'" _n
file write `readme' "" _n

if "`description'" != "" {
    file write `readme' "Description:" _n
    file write `readme' "`description'" _n
    file write `readme' "" _n
}

file write `readme' "Contents:" _n

if "`released_datasets'" != "" {
    file write `readme' "- datasets/: released DTA and CSV datasets" _n
}

if "`released_figures'" != "" {
    file write `readme' "- figures/: PNG figures used by the public site or briefing" _n
}

file write `readme' "- metadata/: dataset-level and briefing-level metadata" _n

if "`create_workbook'" == "1" {
    file write `readme' "- workbook/: Excel workbook containing released data and metadata sheets" _n
}

file write `readme' "- downloads.yml: manifest used by the BNR website downloads catalogue" _n
file write `readme' "" _n

if "`released_datasets'" != "" {
    file write `readme' "Dataset notes:" _n
    file write `readme' "The DTA files contain Stata variable labels, value labels, and dataset notes." _n
    file write `readme' "The CSV files are open machine-readable versions of the released datasets." _n
    file write `readme' "The YML files contain metadata exported from the Stata datasets." _n
    file write `readme' "" _n
}

if "`limitations'" != "" {
    file write `readme' "Limitations:" _n
    file write `readme' "`limitations'" _n
    file write `readme' "" _n
}

if "`rights'" != "" {
    file write `readme' "Rights and reuse:" _n
    file write `readme' "`rights'" _n
    file write `readme' "" _n
}

if "`contact'" != "" {
    file write `readme' "Contact:" _n
    file write `readme' "`contact'" _n
    file write `readme' "" _n
}

file close `readme'

display as result "README created:"
display as result "  `stagingbriefing'/readme.txt"


* ==============================================================================
* DO NOT TOUCH: CREATE XLSX WORKBOOK, IF REQUESTED
* ==============================================================================
* The workbook is a convenience product. It is not the canonical data source.
*
* Canonical public data remain:
*   - DTA datasets;
*   - CSV datasets;
*   - YAML metadata.
*
* If workbook_sheets are not listed in release_control.yml, the helper creates
* simple default sheet names from released_datasets.

if "`create_workbook'" == "1" {

    local workbook_path "`stagingworkbook'/`workbook_file'"

    cap erase "`workbook_path'"

    if `workbook_sheet_count' == 0 & "`released_datasets'" != "" {

        foreach dataset_id of local released_datasets {

            local ++workbook_sheet_count

            local workbook_datasets    "`workbook_datasets' `dataset_id'"
            local workbook_data_sheets "`workbook_data_sheets' `dataset_id'"
            local workbook_meta_sheets "`workbook_meta_sheets' meta_`workbook_sheet_count'"
            local workbook_vars_sheets "`workbook_vars_sheets' vars_`workbook_sheet_count'"
        }
    }

    if `workbook_sheet_count' == 0 {
        display as error "create_workbook is 1 but no workbook sheets or released datasets were found."
        display as error "Check release_control.yml."
        exit 198
    }

    * --------------------------------------------------------------------------
    * Workbook README sheet.
    * --------------------------------------------------------------------------
    * This creates a simple first sheet with enough context for non-technical
    * users opening the workbook directly.

    clear
    set obs 12

    gen str40 field = ""
    gen strL  value = ""

    replace field = "Briefing ID" in 1
    replace value = "`briefing_id'" in 1

    replace field = "Title" in 2
    replace value = "`title'" in 2

    replace field = "Output type" in 3
    replace value = "`output_type'" in 3

    replace field = "Domain" in 4
    replace value = "`domain'" in 4

    replace field = "Surveillance area" in 5
    replace value = "`surveillance_area'" in 5

    replace field = "Registry" in 6
    replace value = "`registry'" in 6

    replace field = "Geography" in 7
    replace value = "`geography'" in 7

    replace field = "Period" in 8
    replace value = "`period'" in 8

    replace field = "Release date" in 9
    replace value = "`release_date'" in 9

    replace field = "Contents" in 10
    replace value = "Data sheets, dataset metadata sheets, and variable metadata sheets" in 10

    replace field = "Data note" in 11
    replace value = "`data_note'" in 11

    replace field = "Limitation" in 12
    replace value = "`limitations'" in 12

    export excel using "`workbook_path'", ///
        sheet("readme") firstrow(variables) replace

    * --------------------------------------------------------------------------
    * Dataset sheets.
    * --------------------------------------------------------------------------
    * bnr_workbook appends:
    *   - a data sheet;
    *   - a dataset metadata sheet;
    *   - a variable metadata sheet.
    *
    * It reads metadata from the DTA labels and notes, so the analyst-owned
    * DO file must label datasets carefully before saving them.

    forvalues i = 1/`workbook_sheet_count' {

        local dataset_id : word `i' of `workbook_datasets'
        local data_sheet : word `i' of `workbook_data_sheets'
        local meta_sheet : word `i' of `workbook_meta_sheets'
        local vars_sheet : word `i' of `workbook_vars_sheets'

        capture confirm file "`stagingdatasets'/`dataset_id'.dta"

        if _rc {
            display as error "Workbook dataset not found:"
            display as error "  `stagingdatasets'/`dataset_id'.dta"
            display as error "Check workbook_sheets in release_control.yml."
            exit 601
        }

        bnr_workbook, ///
            dtafile("`stagingdatasets'/`dataset_id'.dta") ///
            xlsxfile("`workbook_path'") ///
            datasetid("`dataset_id'") ///
            datasheet("`data_sheet'") ///
            metasheet("`meta_sheet'") ///
            varsheet("`vars_sheet'")
    }

    display as result "Workbook created:"
    display as result "  `workbook_path'"
}
else {
    display as text "create_workbook is 0; skipping workbook creation."
}


* ==============================================================================
* DO NOT TOUCH: CREATE SIMPLIFIED DOWNLOAD MANIFEST
* ==============================================================================
* This writes the briefing-level downloads.yml.
*
* The central website downloads page lists ZIP packages only.
* Therefore the manifest is intentionally minimal:
*
*   - full briefing packages usually list one ZIP;
*   - supporting artefacts may use downloads: [];
*   - individual CSV/DTA/YML/PNG/XLSX files remain inside the public package
*     but are not listed separately on the central downloads page.
*
* The site-wide Python catalogue builder later reads these per-package
* downloads.yml files from site/downloads/files/briefings/.

tempname downloads_yml

file open `downloads_yml' using "`stagingbriefing'/downloads.yml", ///
    write replace text

file write `downloads_yml' "schema: bnr_download_manifest_v1" _n
file write `downloads_yml' "briefing_id: `briefing_id'" _n
file write `downloads_yml' "briefing_name: `briefing_name'" _n
file write `downloads_yml' "output_type: `output_type'" _n
file write `downloads_yml' "domain: `domain'" _n
file write `downloads_yml' "surveillance_area: `surveillance_area'" _n
file write `downloads_yml' "period: `period'" _n
file write `downloads_yml' "release_date: `release_date'" _n
file write `downloads_yml' "" _n

file write `downloads_yml' "title: |-" _n
file write `downloads_yml' "  `title'" _n
file write `downloads_yml' "" _n

if "`description'" != "" {
    file write `downloads_yml' "description: |-" _n
    file write `downloads_yml' "  `description'" _n
    file write `downloads_yml' "" _n
}

if "`briefing_page'" != "" {
    file write `downloads_yml' "briefing_page: `briefing_page'" _n
    file write `downloads_yml' "" _n
}

if "`create_zip'" == "1" & "`list_zip'" == "1" {

    local site_base "files/briefings/`briefing_id'"
    local zip_file "bnr_`briefing_id'.zip"

    file write `downloads_yml' "downloads:" _n
    file write `downloads_yml' "  - id: `briefing_id'_zip" _n
    file write `downloads_yml' "    title: `zip_title'" _n
    file write `downloads_yml' "    artefact_type: ZIP package" _n
    file write `downloads_yml' "    format: ZIP" _n
    file write `downloads_yml' "    file: `zip_file'" _n
    file write `downloads_yml' "    href: `site_base'/`zip_file'" _n
    file write `downloads_yml' "    description: |-" _n
    file write `downloads_yml' "      `zip_description'" _n
    file write `downloads_yml' "    include_in_listing: true" _n
    file write `downloads_yml' "    sort_order: 10" _n
}
else {
    file write `downloads_yml' "downloads: []" _n
}

file close `downloads_yml'

display as result "Download manifest created:"
display as result "  `stagingbriefing'/downloads.yml"


* ==============================================================================
* DO NOT TOUCH: COPY STAGING PACKAGE TO PUBLIC
* ==============================================================================
* This removes any old public copy and replaces it with the full current
* staging package.
*
* Removing the old folder first prevents stale files remaining in public/
* after a file has been renamed or removed from the staging package.
*
* PowerShell is used because this BNR workflow is Windows-first and already
* uses PowerShell for robust recursive file operations.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "$ErrorActionPreference = 'Stop'; New-Item -ItemType Directory -Path '$BNR_PUBLIC/briefings' -Force | Out-Null; if (Test-Path -LiteralPath '`publicbriefing'') { Remove-Item -LiteralPath '`publicbriefing'' -Recurse -Force }; Copy-Item -LiteralPath '`stagingbriefing'' -Destination '$BNR_PUBLIC/briefings' -Recurse -Force"


quietly mata: st_local("public_exists", strofreal(direxists("`publicbriefing'")))

if "`public_exists'" != "1" {
    display as error "Public copy failed."
    display as error "Expected folder:"
    display as error "  `publicbriefing'"
    exit 603
}


* ==============================================================================
* DO NOT TOUCH: CREATE ZIP PACKAGE, IF REQUESTED
* ==============================================================================
* The ZIP is created inside the public briefing folder.
*
* The central downloads catalogue lists ZIP packages only, so routine public
* briefings should normally set:
*
*   create_zip = 1
*   list_zip   = 1
*
* Smaller supporting artefacts may set both to 0.

if "`create_zip'" == "1" {

    cap erase "`publiczip'"

    shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
        "$ErrorActionPreference = 'Stop'; if (Test-Path -LiteralPath '`publiczip'') { Remove-Item -LiteralPath '`publiczip'' -Force }; Compress-Archive -LiteralPath '`publicbriefing'' -DestinationPath '`publiczip'' -Force"

    capture confirm file "`publiczip'"

    if _rc {
        display as error "ZIP package was requested but was not created:"
        display as error "  `publiczip'"
        exit 603
    }

    display as result "ZIP package created:"
    display as result "  `publiczip'"
}
else {
    display as text "create_zip is 0; skipping ZIP creation."
}


* ==============================================================================
* DO NOT TOUCH: MIRROR PUBLIC PACKAGE TO WEBSITE DOWNLOADS
* ==============================================================================
* The public folder is the authoritative release copy.
*
* The site/downloads/files/briefings/ folder is the website-serving mirror.
* It can be regenerated from public/ and should not be manually edited.
*
* The mirror helper should be tolerant of partial packages, because not every
* output_type has a complete briefing-style set of datasets, figures,
* workbook, metadata, and ZIP files.

do "$BNR_STATA/common/mirror_public_to_site.do" "`briefing_id'"


* ==============================================================================
* DO NOT TOUCH: FINAL CONFIRMATION
* ==============================================================================

display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR briefing/output package published" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:       `briefing_id'" _n ///
    as result "  Output type:       `output_type'" _n ///
    as result "  Staging folder:    `stagingbriefing'" _n ///
    as result "  Public folder:     `publicbriefing'" _n ///
    as result "  ZIP package:       `publiczip'" _n ///
    as text "------------------------------------------------------------" _n
    

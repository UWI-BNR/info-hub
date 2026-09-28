/*******************************************************************************
DO-FILE: bnr_report_oneoff_s1_prepare.do
VERSION: 0.3.2 (27 September 2026)
PURPOSE: Prepare a private one-off CVD report candidate from a finished PDF,
         with an optional associated CSV/DTA public-data package and metadata.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_oneoff_s1_prepare.do" ///
      workflow_test 1 "$BNR_STAGING/report_inputs/report.pdf" ///
      "One-off CVD report workflow test" ///
      "Engineering placeholder used to test the publication workflow." ///
      2026-09-02

  do "$BNR_STATA/reporting/bnr_report_oneoff_s1_prepare.do" ///
      case_fatality_2025 1 "$BNR_STAGING/report_inputs/report.pdf" ///
      "Thirty-day case fatality after cardiovascular events" ///
      "Deaths within 30 days of a heart attack or stroke event in Barbados, 2010–2025." 2026-09-25 "" ///
      "$BNR_STAGING/report_inputs/case_fatality_metrics.csv" ///
      "$BNR_STAGING/report_inputs/case_fatality_metrics.dta" ///
      "$BNR_STAGING/report_inputs/case_fatality_metadata.yml" ///
      "$BNR_STAGING/report_inputs/case_fatality_readme.md"

The bespoke analysis and PDF creation happen before this step. This step only
validates, packages and describes the finished files. It publishes nothing.
*******************************************************************************/

version 19
clear all
set more off

args study_id report_version source_pdf report_title report_description ///
    report_date option source_csv source_dta source_data_metadata ///
    source_data_readme

if "`study_id'" == "" | "`report_version'" == "" | ///
        "`source_pdf'" == "" | "`report_title'" == "" | ///
        "`report_description'" == "" | "`report_date'" == "" {
    display as error "Enter study ID, version, PDF, title, description and report date."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional Step 1 argument is replace."
    exit 198
}
local replace_existing = (lower("`option'") == "replace")

local dataset_arg_count 0
foreach dataset_arg in source_csv source_dta source_data_metadata ///
    source_data_readme {
    if "``dataset_arg''" != "" local ++dataset_arg_count
}
if !inlist(`dataset_arg_count',0,3,4) {
    display as error "CSV, DTA and metadata must be supplied together."
    exit 198
}
local has_dataset = inlist(`dataset_arg_count',3,4)
local has_readme = (`dataset_arg_count' == 4)

if !regexm("`study_id'", "^[a-z][a-z0-9_]*$") {
    display as error "Study ID must use lowercase letters, numbers and underscores."
    display as error "It must begin with a letter; example: case_fatality_2025"
    exit 198
}
local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}
if substr(lower("`source_pdf'"), -4, 4) != ".pdf" {
    display as error "The supplied report must have a .pdf extension."
    exit 198
}
if `has_dataset' {
    if substr(lower("`source_csv'"), -4, 4) != ".csv" | ///
            substr(lower("`source_dta'"), -4, 4) != ".dta" {
        display as error "Associated data inputs must include CSV and DTA files."
        exit 198
    }
    local metadata_extension = lower(substr("`source_data_metadata'", -4, 4))
    if !inlist("`metadata_extension'", ".txt", ".yml") {
        display as error "Dataset metadata must be a TXT or YML file."
        exit 198
    }
    if `has_readme' & substr(lower("`source_data_readme'"), -3, 3) != ".md" {
        display as error "Dataset README must be a Markdown (.md) file."
        exit 198
    }
    if `has_readme' & "`metadata_extension'" != ".yml" {
        display as error "A dataset README requires structured YML metadata."
        exit 198
    }
}
if strpos("`report_title'", char(34)) | ///
        strpos("`report_description'", char(34)) {
    display as error "Title and description must not contain double quotation marks."
    exit 198
}
local report_date_num = daily("`report_date'", "YMD")
if missing(`report_date_num') {
    display as error "Report date must use YYYY-MM-DD."
    exit 198
}
local canonical_date : display %tdCCYY-NN-DD `report_date_num'
if "`canonical_date'" != "`report_date'" {
    display as error "Report date must use YYYY-MM-DD."
    exit 198
}

if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}
foreach required_global in BNR_REPO BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

capture confirm file "`source_pdf'"
if _rc {
    display as error "Finished one-off report PDF not found: `source_pdf'"
    exit 601
}
quietly checksum "`source_pdf'"
local source_pdf_size = r(filelen)
local source_pdf_checksum = r(checksum)
if `source_pdf_size' < 1 {
    display as error "The supplied PDF is empty."
    exit 459
}
if `has_dataset' {
    local dataset_sources "source_csv source_dta source_data_metadata"
    if `has_readme' local dataset_sources "`dataset_sources' source_data_readme"
    foreach source_file of local dataset_sources {
        capture confirm file "``source_file''"
        if _rc {
            display as error "Associated public-data file not found: ``source_file''"
            exit 601
        }
        quietly checksum "``source_file''"
        if r(filelen) < 1 {
            display as error "Associated public-data file is empty: ``source_file''"
            exit 459
        }
    }

    * A YAML file can be syntactically readable while its descriptive block
    * values are blank. Check the standard dataset-metadata structure before
    * creating or replacing any candidate files. This is a packaging check;
    * it does not interpret or alter analytical values.
    if "`metadata_extension'" == ".yml" {
        local yml_schema_ok 0
        local yml_methods_ok 0
        local yml_variables_ok 0
        local yml_description_count 0
        local yml_block_count 0
        local yml_empty_blocks 0
        local yml_line_number 0
        tempname yml_check
        file open `yml_check' using "`source_data_metadata'", read text
        file read `yml_check' yml_line
        while r(eof) == 0 {
            local ++yml_line_number
            local yml_trim = strtrim(`"`yml_line'"')
            if "`yml_trim'" == "schema: bnr_dataset_metadata_v1" ///
                local yml_schema_ok 1
            if "`yml_trim'" == "methods:" local yml_methods_ok 1
            if "`yml_trim'" == "variables:" local yml_variables_ok 1
            if "`yml_trim'" == "description: |-" ///
                local ++yml_description_count

            local yml_length = strlen(`"`yml_trim'"')
            if `yml_length' >= 2 {
                if substr(`"`yml_trim'"',`yml_length'-1,2) == "|-" {
                    local ++yml_block_count
                    file read `yml_check' yml_value
                    local ++yml_line_number
                    if r(eof) != 0 local ++yml_empty_blocks
                    else if strtrim(`"`yml_value'"') == "" ///
                        local ++yml_empty_blocks
                }
            }
            file read `yml_check' yml_line
        }
        file close `yml_check'

        if !`yml_schema_ok' | !`yml_methods_ok' | !`yml_variables_ok' | ///
                `yml_description_count' == 0 | `yml_block_count' == 0 | ///
                `yml_empty_blocks' > 0 {
            display as error "Dataset YAML metadata is incomplete."
            display as error "Required methods and variable descriptions must not be blank."
            display as error "No candidate files were created or replaced."
            exit 459
        }
    }
}

local report_id "bnr_cvd_oneoff_`study_id'_v`version_num'"
local public_name "bnr_cvd_oneoff_`study_id'"
local reports_dir "$BNR_STAGING/reports"
local cvd_dir "`reports_dir'/cvd"
local studies_dir "`cvd_dir'/studies"
local package_dir "`studies_dir'/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local package_source "`package_dir'/package_source"
local package_data "`package_source'/data"
local package_metadata "`package_source'/metadata"
local zip_python "$BNR_REPO/venv-info-hub/Scripts/python.exe"
local zip_helper "$BNR_REPO/scripts/python/create_release_data_zip.py"
local dataset_zip_name "`public_name'_data.zip"
local dataset_catalogue_name "`public_name'_data.yml"
local candidate_dataset_zip "`candidate_dir'/`dataset_zip_name'"
local candidate_dataset_catalogue "`candidate_dir'/`dataset_catalogue_name'"
local approval "`ready_dir'/approval.yml"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_oneoff_s1_`report_id'.log"
local site_pdf_href "../../../../../downloads/files/reports/cvd/studies/`study_id'/`public_name'.pdf"
local site_dataset_href "../../../../../downloads/files/reports/cvd/studies/`study_id'/`dataset_zip_name'"

capture mkdir "`reports_dir'"
capture mkdir "`cvd_dir'"
capture mkdir "`studies_dir'"
capture mkdir "`package_dir'"
capture mkdir "`candidate_dir'"
capture mkdir "`ready_dir'"
if `has_dataset' {
    capture mkdir "`package_source'"
    capture mkdir "`package_data'"
    capture mkdir "`package_metadata'"
}
quietly mata: st_local("candidate_dir_exists", strofreal(direxists("`candidate_dir'")))
if "`candidate_dir_exists'" != "1" {
    display as error "Could not create private candidate directory: `candidate_dir'"
    exit 603
}
quietly mata: st_local("ready_dir_exists", strofreal(direxists("`ready_dir'")))
if "`ready_dir_exists'" != "1" {
    display as error "Could not create private public_ready directory: `ready_dir'"
    exit 603
}

capture confirm file "`approval'"
if !_rc {
    display as error "This one-off report version is already approved: `approval'"
    display as error "Approved packages are immutable. Prepare a higher version."
    exit 602
}

local candidate_exists 0
capture confirm file "`candidate_pdf'"
if !_rc local candidate_exists 1
capture confirm file "`candidate_qmd'"
if !_rc local candidate_exists 1
capture confirm file "`candidate_metadata'"
if !_rc local candidate_exists 1
if `has_dataset' {
    capture confirm file "`candidate_dataset_zip'"
    if !_rc local candidate_exists 1
    capture confirm file "`candidate_dataset_catalogue'"
    if !_rc local candidate_exists 1
}
if `candidate_exists' & !`replace_existing' {
    display as error "This unapproved candidate version already exists."
    display as error "Use replace only to rebuild the unapproved candidate."
    exit 602
}
if `replace_existing' & !`has_dataset' {
    capture erase "`candidate_dataset_zip'"
    capture erase "`candidate_dataset_catalogue'"
}

capture log close bnr_report_oneoff_s1
log using "`private_log'", text replace name(bnr_report_oneoff_s1)

copy "`source_pdf'" "`candidate_pdf'", replace
quietly checksum "`candidate_pdf'"
if r(filelen) != `source_pdf_size' | r(checksum) != `source_pdf_checksum' {
    capture log close bnr_report_oneoff_s1
    display as error "The private candidate PDF does not match the supplied PDF."
    exit 459
}

if `has_dataset' {
    local package_csv "data/`study_id'_metrics.csv"
    local package_dta "data/`study_id'_metrics.dta"
    local package_meta "metadata/`study_id'_metadata`metadata_extension'"
    local package_files "`package_csv' `package_dta' `package_meta'"
    if `has_readme' {
        local package_readme "metadata/README.md"
        local package_files "`package_files' `package_readme'"
    }
    copy "`source_csv'" "`package_source'/`package_csv'", replace
    copy "`source_dta'" "`package_source'/`package_dta'", replace
    copy "`source_data_metadata'" "`package_source'/`package_meta'", replace
    if `has_readme' copy "`source_data_readme'" ///
        "`package_source'/`package_readme'", replace

    foreach source_file of local dataset_sources {
        quietly checksum "``source_file''"
        local `source_file'_size = r(filelen)
        local `source_file'_checksum = r(checksum)
    }
    quietly checksum "`package_source'/`package_csv'"
    assert r(filelen) == `source_csv_size'
    assert r(checksum) == `source_csv_checksum'
    quietly checksum "`package_source'/`package_dta'"
    assert r(filelen) == `source_dta_size'
    assert r(checksum) == `source_dta_checksum'
    quietly checksum "`package_source'/`package_meta'"
    assert r(filelen) == `source_data_metadata_size'
    assert r(checksum) == `source_data_metadata_checksum'
    if `has_readme' {
        quietly checksum "`package_source'/`package_readme'"
        assert r(filelen) == `source_data_readme_size'
        assert r(checksum) == `source_data_readme_checksum'
    }

    foreach required_zip_file in zip_python zip_helper {
        capture confirm file "``required_zip_file''"
        if _rc {
            capture log close bnr_report_oneoff_s1
            display as error "Required portable-ZIP helper file is missing: ``required_zip_file''"
            exit 601
        }
    }
    local zip_command `""`zip_python'" "`zip_helper'" --output "`candidate_dataset_zip'""'
    local zip_command `"`zip_command' --entry "`package_source'/`package_csv'" "`package_csv'""'
    local zip_command `"`zip_command' --entry "`package_source'/`package_dta'" "`package_dta'""'
    local zip_command `"`zip_command' --entry "`package_source'/`package_meta'" "`package_meta'""'
    if `has_readme' local zip_command `"`zip_command' --entry "`package_source'/`package_readme'" "`package_readme'""'
    capture noisily shell `zip_command'
    local zip_rc = _rc
    if `zip_rc' {
        capture log close bnr_report_oneoff_s1
        display as error "The associated public-data ZIP could not be created."
        exit `zip_rc'
    }
    capture confirm file "`candidate_dataset_zip'"
    if _rc {
        capture log close bnr_report_oneoff_s1
        display as error "The portable-ZIP helper did not write: `candidate_dataset_zip'"
        exit 459
    }
    quietly checksum "`candidate_dataset_zip'"
    local dataset_zip_size = r(filelen)
    local dataset_zip_checksum = r(checksum)
}

quietly do "$BNR_REPO/scripts/stata/reporting/bnr_report_listing_images.do"
bnr_report_listing_images, ///
    root("$BNR_REPO/site/surveillance/cvd/reports") ///
    target1("$BNR_REPO/site/surveillance/cvd/reports/studies/`study_id'/index.qmd")
local listing_image "`r(image1)'"
local listing_alt "`r(alt1)'"

tempname qmd_handle
file open `qmd_handle' using "`candidate_qmd'", write text replace
file write `qmd_handle' "---" _n
file write `qmd_handle' `"title: "`report_title'""' _n
file write `qmd_handle' `"description: "`report_description'""' _n
file write `qmd_handle' "date: `report_date'" _n
file write `qmd_handle' "date-modified: `report_date'" _n
file write `qmd_handle' "report-id: `report_id'" _n
file write `qmd_handle' "report-type: Special report" _n
file write `qmd_handle' "report-version: v`version_num'" _n
file write `qmd_handle' "study-id: `study_id'" _n
file write `qmd_handle' "image: /assets/images/listings/`listing_image'" _n
file write `qmd_handle' "image-alt: `listing_alt'" _n
file write `qmd_handle' "categories:" _n
file write `qmd_handle' "  - CVD" _n
file write `qmd_handle' "  - Special report" _n
file write `qmd_handle' "format:" _n
file write `qmd_handle' "  html:" _n
file write `qmd_handle' "    toc: false" _n
file write `qmd_handle' "    page-layout: article" _n
file write `qmd_handle' "---" _n _n
file write `qmd_handle' "`report_description'" _n _n
file write `qmd_handle' "[Open or download the PDF report](`site_pdf_href'){.btn .btn-primary}" _n _n
if `has_dataset' {
    file write `qmd_handle' "[Download the associated dataset (ZIP)](`site_dataset_href'){.btn .btn-secondary}" _n _n
}
file write `qmd_handle' `"<iframe src="`site_pdf_href'" title="`report_title'" width="100%" height="900"></iframe>"' _n
file close `qmd_handle'

local built_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local built_time "`c(current_time)'"
tempname metadata_handle
file open `metadata_handle' using "`candidate_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: one_off_cvd_report" _n
file write `metadata_handle' "study_id: `study_id'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "public_name: `public_name'" _n
file write `metadata_handle' `"report_title: "`report_title'""' _n
file write `metadata_handle' `"report_description: "`report_description'""' _n
file write `metadata_handle' "report_date: `report_date'" _n
file write `metadata_handle' "source_pdf_size: `source_pdf_size'" _n
file write `metadata_handle' "source_pdf_checksum: `source_pdf_checksum'" _n
file write `metadata_handle' "pdf_file: `public_name'.pdf" _n
file write `metadata_handle' "landing_page: index.qmd" _n
if `has_dataset' {
    file write `metadata_handle' "dataset_package_id: `public_name'_data" _n
    file write `metadata_handle' "dataset_zip_file: `dataset_zip_name'" _n
    file write `metadata_handle' "dataset_zip_size: `dataset_zip_size'" _n
    file write `metadata_handle' "dataset_zip_checksum: `dataset_zip_checksum'" _n
    file write `metadata_handle' "dataset_catalogue_file: `dataset_catalogue_name'" _n
}
file write `metadata_handle' "built_date: `built_date'" _n
file write `metadata_handle' "built_time: `built_time'" _n
file close `metadata_handle'

if `has_dataset' {
    tempname catalogue_handle
    file open `catalogue_handle' using "`candidate_dataset_catalogue'", ///
        write text replace
    file write `catalogue_handle' "schema: bnr_download_manifest_v1" _n
    file write `catalogue_handle' "package_type: report_dataset" _n
    file write `catalogue_handle' "package_id: `public_name'_data" _n
    file write `catalogue_handle' "release_id: `report_id'" _n
    file write `catalogue_handle' "surveillance_area: CVD" _n
    file write `catalogue_handle' "domain: cvd" _n
    file write `catalogue_handle' "metric_family: case_fatality" _n
    file write `catalogue_handle' "period: `study_id'" _n
    file write `catalogue_handle' "release_date: `report_date'" _n _n
    file write `catalogue_handle' "title: |-" _n
    file write `catalogue_handle' "  Thirty-day case-fatality data" _n _n
    file write `catalogue_handle' "description: |-" _n
    file write `catalogue_handle' "  Data accompanying the report." _n _n
    file write `catalogue_handle' "downloads:" _n
    file write `catalogue_handle' "  - id: `public_name'_data_zip" _n
    file write `catalogue_handle' "    title: Thirty-day case-fatality data" _n
    file write `catalogue_handle' "    artefact_type: ZIP package" _n
    file write `catalogue_handle' "    format: ZIP" _n
    file write `catalogue_handle' "    file: `dataset_zip_name'" _n
    file write `catalogue_handle' "    href: files/reports/cvd/studies/`study_id'/`dataset_zip_name'" _n
    file write `catalogue_handle' "    description: |-" _n
    file write `catalogue_handle' "      CSV and Stata datasets, with metadata and a short guide." _n
    file write `catalogue_handle' "    include_in_listing: true" _n
    file write `catalogue_handle' "    sort_order: 40" _n
    file close `catalogue_handle'
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT STEP 1: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Candidate prepared"
noisily display as text   "  Script version:          0.3.2"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text  `"  Source PDF:              `source_pdf'"'
noisily display as text  `"  Candidate package:       `candidate_dir'"'
if `has_dataset' noisily display as text `"  Associated dataset ZIP:  `candidate_dataset_zip'"'
noisily display as text  `"  Private build log:       `private_log'"'
noisily display as text   "  Publication boundary:    Nothing approved or published"
noisily display as text   "  Next step:               Review the candidate, then run Step 2."
noisily display as result "============================================================================="
}
capture log close bnr_report_oneoff_s1

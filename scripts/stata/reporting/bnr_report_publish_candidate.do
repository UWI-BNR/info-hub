/*******************************************************************************
DO-FILE: bnr_report_publish_candidate.do
VERSION: 1.2.0 (10 September 2026)
PURPOSE: Promote one exact manifested report payload to public and site paths.

This shared helper reads only public_ready. It never reads or alters candidate
files and never renders, commits, pushes or deploys the Quarto site.

CHANGE 1.2.0:
  Optionally publish one approved companion PDF and its landing QMD alongside
  the core report payload. Existing three-file workflows remain unchanged.
*******************************************************************************/

version 19
clear all
set more off

args ready_dir report_id report_type period_key period_value report_version ///
    public_pdf public_qmd public_metadata site_pdf site_qmd site_metadata option ///
    companion_pdf_name companion_qmd_name public_companion_pdf ///
    public_companion_qmd site_companion_pdf site_companion_qmd

if "`ready_dir'" == "" | "`report_id'" == "" | "`report_type'" == "" | ///
        "`period_key'" == "" | "`period_value'" == "" | ///
        "`report_version'" == "" | "`public_pdf'" == "" | ///
        "`public_qmd'" == "" | "`public_metadata'" == "" | ///
        "`site_pdf'" == "" | "`site_qmd'" == "" | ///
        "`site_metadata'" == "" {
    display as error "Report publication received incomplete arguments."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional publication argument is replace."
    exit 198
}
local companion_arg_count 0
foreach companion_arg in companion_pdf_name companion_qmd_name public_companion_pdf public_companion_qmd site_companion_pdf site_companion_qmd {
    if "``companion_arg''" != "" local ++companion_arg_count
}
if !inlist(`companion_arg_count', 0, 6) {
    display as error "All six companion publication arguments must be supplied together."
    exit 198
}
local has_companion = (`companion_arg_count' == 6)
if `has_companion' {
    foreach companion_name in companion_pdf_name companion_qmd_name {
        if strpos("``companion_name''", "/") | strpos("``companion_name''", "\") | ///
                strpos("``companion_name''", "..") | strpos("``companion_name''", ",") {
            display as error "Companion payload names must be safe filenames: ``companion_name''"
            exit 198
        }
    }
}
local required_payload_count = 3 + (2 * `has_companion')
local replace_existing = (lower("`option'") == "replace")
local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}

local ready_pdf "`ready_dir'/`report_id'.pdf"
local ready_qmd "`ready_dir'/index.qmd"
local ready_metadata "`ready_dir'/report.yml"
local ready_companion_pdf "`ready_dir'/`companion_pdf_name'"
local ready_companion_qmd "`ready_dir'/`companion_qmd_name'"
local manifest "`ready_dir'/public_manifest.csv"
local approval "`ready_dir'/approval.yml"

foreach required_file in ready_pdf ready_qmd ready_metadata manifest approval {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Required approved-package file is missing: ``required_file''"
        display as error "Complete report approval before publication."
        exit 601
    }
}
if `has_companion' {
    foreach required_file in ready_companion_pdf ready_companion_qmd {
        capture confirm file "``required_file''"
        if _rc {
            display as error "Required approved companion file is missing: ``required_file''"
            exit 601
        }
    }
}

local schema_ok 0
local status_ok 0
local report_ok 0
local type_ok 0
local period_ok 0
local version_ok 0
local role_ok 0
local review_ok 0
local disclosure_ok 0
local candidate_ok 0
local readiness_ok 0
local manifest_name_ok 0
local manifest_scope_ok 0
local approved_manifest_count .
local approval_scope_ok 0
local approved_by ""
local approved_date ""
local approved_manifest_size .
local approved_manifest_checksum .

tempname approval_handle
file open `approval_handle' using "`approval'", read text
file read `approval_handle' line
while r(eof) == 0 {
    local line = strtrim(`"`line'"')
    local line = subinstr(`"`line'"', char(34), "", .)
    if "`line'" == "schema: bnr_report_approval_v1" local schema_ok 1
    if "`line'" == "status: approved" local status_ok 1
    if "`line'" == "report_id: `report_id'" local report_ok 1
    if "`line'" == "report_type: `report_type'" local type_ok 1
    if "`line'" == "`period_key': `period_value'" local period_ok 1
    if "`line'" == "report_version: v`version_num'" local version_ok 1
    if inlist("`line'", "approved_role: BNR Lead", ///
            "approved_role: BNR Analyst", "approved_role: BNR Developer") local role_ok 1
    if "`line'" == "review_standard: bnr_report_review_v1" local review_ok 1
    if "`line'" == "disclosure_review: completed" local disclosure_ok 1
    if "`line'" == "candidate_reviewed: true" local candidate_ok 1
    if "`line'" == "publication_readiness_confirmed: true" local readiness_ok 1
    if "`line'" == "public_ready_manifest: public_manifest.csv" local manifest_name_ok 1
    if "`line'" == "manifest_scope: payload_files_only" local manifest_scope_ok 1
    if strpos("`line'", "manifest_required_files:") == 1 local approved_manifest_count = real(strtrim(substr("`line'", 25, .)))
    if "`line'" == "approval_scope: public_ready_payload" local approval_scope_ok 1
    if strpos("`line'", "approved_by:") == 1 local approved_by = strtrim(substr("`line'", 13, .))
    if strpos("`line'", "approved_date:") == 1 local approved_date = strtrim(substr("`line'", 15, .))
    if strpos("`line'", "manifest_size:") == 1 local approved_manifest_size = real(strtrim(substr("`line'", 15, .)))
    if strpos("`line'", "manifest_checksum:") == 1 local approved_manifest_checksum = real(strtrim(substr("`line'", 19, .)))
    file read `approval_handle' line
}
file close `approval_handle'

if !`schema_ok' | !`status_ok' | !`report_ok' | !`type_ok' | ///
        !`period_ok' | !`version_ok' | !`role_ok' | !`review_ok' | ///
        !`disclosure_ok' | !`candidate_ok' | !`readiness_ok' | ///
        !`manifest_name_ok' | !`manifest_scope_ok' | ///
        `approved_manifest_count' != `required_payload_count' | ///
        !`approval_scope_ok' | "`approved_by'" == "" | "`approved_date'" == "" {
    display as error "approval.yml is not a complete report approval receipt."
    exit 459
}

quietly checksum "`manifest'"
if r(filelen) != `approved_manifest_size' | ///
        r(checksum) != `approved_manifest_checksum' {
    display as error "public_manifest.csv has changed since approval."
    exit 459
}

import delimited using "`manifest'", varnames(1) clear
foreach required_variable in file_path file_size checksum {
    capture confirm variable `required_variable'
    if _rc {
        display as error "public_manifest.csv is missing `required_variable'."
        exit 111
    }
}
quietly count
if r(N) != `required_payload_count' {
    display as error "The approved report manifest must contain exactly `required_payload_count' payload files."
    exit 459
}
capture isid file_path
if _rc {
    display as error "The approved report manifest contains duplicate file paths."
    exit 459
}
foreach expected_path in "`report_id'.pdf" "index.qmd" "report.yml" {
    quietly count if file_path == "`expected_path'"
    if r(N) != 1 {
        display as error "Manifest entry missing or duplicated: `expected_path'"
        exit 459
    }
}
if `has_companion' {
    foreach expected_path in "`companion_pdf_name'" "`companion_qmd_name'" {
        quietly count if file_path == "`expected_path'"
        if r(N) != 1 {
            display as error "Manifest companion entry missing or duplicated: `expected_path'"
            exit 459
        }
    }
}
forvalues row = 1/`required_payload_count' {
    local relative_path = file_path[`row']
    quietly checksum "`ready_dir'/`relative_path'"
    if r(filelen) != file_size[`row'] | r(checksum) != checksum[`row'] {
        display as error "Approved payload fingerprint failed: `relative_path'"
        exit 459
    }
}

local any_output 0
foreach output_file in public_pdf public_qmd public_metadata site_pdf site_qmd site_metadata {
    capture confirm file "``output_file''"
    if !_rc local any_output 1
}
if `has_companion' {
    foreach output_file in public_companion_pdf public_companion_qmd site_companion_pdf site_companion_qmd {
        capture confirm file "``output_file''"
        if !_rc local any_output 1
    }
}

local existing_version .
local existing_type_ok 0
local existing_period_ok 0
if `any_output' {
    capture confirm file "`public_metadata'"
    if _rc {
        display as error "Report publication stopped: existing outputs have no authoritative report.yml."
        display as error "Review the existing public and website package before retrying."
        exit 459
    }

    tempname existing_handle
    file open `existing_handle' using "`public_metadata'", read text
    file read `existing_handle' line
    while r(eof) == 0 {
        local line = strtrim(`"`line'"')
        local line = subinstr(`"`line'"', char(34), "", .)
        if strpos("`line'", "report_version: v") == 1 {
            local existing_version = real(substr("`line'", 18, .))
        }
        if "`line'" == "report_type: `report_type'" local existing_type_ok 1
        if "`line'" == "`period_key': `period_value'" local existing_period_ok 1
        file read `existing_handle' line
    }
    file close `existing_handle'

    if missing(`existing_version') | !`existing_type_ok' | !`existing_period_ok' {
        display as error "Report publication stopped: existing report.yml is missing or inconsistent."
        display as error "Review: `public_metadata'"
        exit 459
    }
    if `version_num' < `existing_version' {
        display as error "Report publication stopped: this would downgrade v`existing_version' to v`version_num'."
        exit 459
    }
}
if `any_output' & !`replace_existing' {
    display as error "Report publication stopped: public output already exists for this report period."
    display as error "Use replace only for an approved same-version recovery or higher version."
    exit 602
}

capture noisily copy "`ready_pdf'" "`public_pdf'", replace
if _rc {
    local copy_rc = _rc
    display as error "Report publication failed while writing: `public_pdf'"
    exit `copy_rc'
}
capture noisily copy "`ready_qmd'" "`public_qmd'", replace
if _rc {
    local copy_rc = _rc
    display as error "Report publication failed while writing: `public_qmd'"
    exit `copy_rc'
}
capture noisily copy "`ready_metadata'" "`public_metadata'", replace
if _rc {
    local copy_rc = _rc
    display as error "Report publication failed while writing: `public_metadata'"
    exit `copy_rc'
}
capture noisily copy "`ready_pdf'" "`site_pdf'", replace
if _rc {
    local copy_rc = _rc
    display as error "Report publication failed while writing: `site_pdf'"
    exit `copy_rc'
}
capture noisily copy "`ready_qmd'" "`site_qmd'", replace
if _rc {
    local copy_rc = _rc
    display as error "Report publication failed while writing: `site_qmd'"
    exit `copy_rc'
}
capture noisily copy "`ready_metadata'" "`site_metadata'", replace
if _rc {
    local copy_rc = _rc
    display as error "Report publication failed while writing: `site_metadata'"
    exit `copy_rc'
}
if `has_companion' {
    capture noisily copy "`ready_companion_pdf'" "`public_companion_pdf'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Report publication failed while writing: `public_companion_pdf'"
        exit `copy_rc'
    }
    capture noisily copy "`ready_companion_qmd'" "`public_companion_qmd'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Report publication failed while writing: `public_companion_qmd'"
        exit `copy_rc'
    }
    capture noisily copy "`ready_companion_pdf'" "`site_companion_pdf'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Report publication failed while writing: `site_companion_pdf'"
        exit `copy_rc'
    }
    capture noisily copy "`ready_companion_qmd'" "`site_companion_qmd'", replace
    if _rc {
        local copy_rc = _rc
        display as error "Report publication failed while writing: `site_companion_qmd'"
        exit `copy_rc'
    }
}

quietly checksum "`ready_pdf'"
local ready_pdf_size = r(filelen)
local ready_pdf_checksum = r(checksum)
quietly checksum "`public_pdf'"
if r(filelen) != `ready_pdf_size' | r(checksum) != `ready_pdf_checksum' {
    display as error "Published public PDF verification failed: `public_pdf'"
    exit 459
}
quietly checksum "`site_pdf'"
if r(filelen) != `ready_pdf_size' | r(checksum) != `ready_pdf_checksum' {
    display as error "Published website PDF verification failed: `site_pdf'"
    exit 459
}

quietly checksum "`ready_qmd'"
local ready_qmd_size = r(filelen)
local ready_qmd_checksum = r(checksum)
quietly checksum "`public_qmd'"
if r(filelen) != `ready_qmd_size' | r(checksum) != `ready_qmd_checksum' {
    display as error "Published public landing-page verification failed: `public_qmd'"
    exit 459
}
quietly checksum "`site_qmd'"
if r(filelen) != `ready_qmd_size' | r(checksum) != `ready_qmd_checksum' {
    display as error "Published website landing-page verification failed: `site_qmd'"
    exit 459
}

quietly checksum "`ready_metadata'"
local ready_metadata_size = r(filelen)
local ready_metadata_checksum = r(checksum)
quietly checksum "`public_metadata'"
if r(filelen) != `ready_metadata_size' | r(checksum) != `ready_metadata_checksum' {
    display as error "Published public metadata verification failed: `public_metadata'"
    exit 459
}
quietly checksum "`site_metadata'"
if r(filelen) != `ready_metadata_size' | r(checksum) != `ready_metadata_checksum' {
    display as error "Published website metadata verification failed: `site_metadata'"
    exit 459
}

if `has_companion' {
    quietly checksum "`ready_companion_pdf'"
    local companion_pdf_size = r(filelen)
    local companion_pdf_checksum = r(checksum)
    quietly checksum "`public_companion_pdf'"
    if r(filelen) != `companion_pdf_size' | r(checksum) != `companion_pdf_checksum' {
        display as error "Published public companion PDF verification failed: `public_companion_pdf'"
        exit 459
    }
    quietly checksum "`site_companion_pdf'"
    if r(filelen) != `companion_pdf_size' | r(checksum) != `companion_pdf_checksum' {
        display as error "Published website companion PDF verification failed: `site_companion_pdf'"
        exit 459
    }

    quietly checksum "`ready_companion_qmd'"
    local companion_qmd_size = r(filelen)
    local companion_qmd_checksum = r(checksum)
    quietly checksum "`public_companion_qmd'"
    if r(filelen) != `companion_qmd_size' | r(checksum) != `companion_qmd_checksum' {
        display as error "Published public companion landing-page verification failed: `public_companion_qmd'"
        exit 459
    }
    quietly checksum "`site_companion_qmd'"
    if r(filelen) != `companion_qmd_size' | r(checksum) != `companion_qmd_checksum' {
        display as error "Published website companion landing-page verification failed: `site_companion_qmd'"
        exit 459
    }
}

* Clear any return code retained by an earlier expected capture.
capture assert 1

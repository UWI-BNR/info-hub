/*******************************************************************************
DO-FILE: bnr_report_annual_s1_build.do
VERSION: 1.1.2 (4 September 2026)
PURPOSE: Build a private annual CVD report candidate package.

CHANGE 1.1.1:
  - Use a repository-relative CLI entry point so the local path configuration
    can be loaded by the builder before derived globals are required.
  - Remove the annual builder's dependency on BNR_STATA; report components are
    resolved from BNR_REPO/scripts/stata after configuration is loaded.

CHANGE 1.1.2:
  - Keep Stata/putpdf as the sole report-composition engine.
  - Apply restrained running page furniture to the completed private PDF through
    the controlled repository Python helper before the candidate is created.
  - The helper has no access to inputs or calculations; it decorates the PDF
    body only and stops Step 1 clearly if its local environment is unavailable.

USAGE (enter each command on one line):
  do "scripts/stata/reporting/bnr_report_annual_s1_build.do" 2025 2026 1 2026 7 1
  do "scripts/stata/reporting/bnr_report_annual_s1_build.do" 2025 2026 1 2026 7 1 replace

CHANGE 1.1.0:
  - Keep Step 1 as the workflow controller and final PDF writer.
  - Load year-specific interpretation before the reusable standard section so
    analyst text can be inserted at fixed editorial locations.
  - Move the cover and all standard surveillance composition into
    bnr_report_annual_standard.do.
  - Allow the year-specific Special chapter file to compose its own pages.
  - Rename the generated landing-page description from "Focus On" to
    "Special chapter". Approval, manifest, versioning and publication controls
    are unchanged.
*******************************************************************************/

*******************************************************************************
* BNR ANALYST GUIDE - READ BEFORE EDITING
*
* This is an INVARIANT WORKFLOW CONTROLLER. BNR analysts should not edit its
* executable code during routine annual-report production. It validates the
* requested releases, creates a private immutable candidate, invokes the two
* analyst-owned year files and the reusable standard report, applies page
* furniture, and writes the candidate metadata. Changing this controller can
* weaken the separation between build, approval and publication.
*
* Routine annual editing belongs in:
*   1. annual/YYYY/bnr_report_annual_YYYY_interpretation.do; and
*   2. annual/YYYY/bnr_report_annual_YYYY_focus.do.
*
* The comments below describe the control blocks. They are documentation, not
* invitations to change the corresponding executable statements.
*******************************************************************************

version 19
clear all
set more off

* INVARIANT - DO NOT EDIT.
* Read the seven positional CLI arguments. These identify the report year, the
* two already-approved public source releases, the candidate version and the
* optional permission to rebuild an unapproved candidate.
args report_year event_year event_month mortality_year mortality_month ///
    report_version option

* INVARIANT - DO NOT EDIT.
* Reject missing, non-integer or out-of-contract arguments before any file is
* read or output directory is created. These are fail-safe input controls.
if "`report_year'" == "" | "`event_year'" == "" | "`event_month'" == "" | ///
        "`mortality_year'" == "" | "`mortality_month'" == "" | ///
        "`report_version'" == "" {
    display as error "Enter report year, both source releases and report version."
    exit 198
}
if "`option'" != "" & lower("`option'") != "replace" {
    display as error "The only optional Step 1 argument is replace."
    exit 198
}
local replace_existing = (lower("`option'") == "replace")

foreach numeric_input in report_year event_year event_month mortality_year ///
        mortality_month report_version {
    local value = real("``numeric_input''")
    if missing(`value') | `value' != floor(`value') {
        display as error "All annual report period and version inputs must be integers."
        exit 198
    }
}
local report_year_num = real("`report_year'")
local event_year_num = real("`event_year'")
local event_month_num = real("`event_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")
local version_num = real("`report_version'")
if `report_year_num' < 2024 | `event_year_num' < 2024 | ///
        `mortality_year_num' < 2024 {
    display as error "Report and source-release years must be 2024 or later."
    exit 198
}
if !inrange(`event_month_num', 1, 12) | ///
        !inrange(`mortality_month_num', 1, 12) {
    display as error "Source-release months must be integers from 1 to 12."
    exit 198
}
if `version_num' < 1 {
    display as error "Report version must be a positive integer."
    exit 198
}

* INVARIANT - DO NOT EDIT.
* Load the local path configuration only when necessary, then require every
* private/public root used later. No path should be hard-coded into this file.
if "$BNR_REPO" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}
foreach required_global in BNR_REPO BNR_STAGING BNR_PUBLIC ///
        BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

* INVARIANT - DO NOT EDIT.
* Construct stable release IDs, report IDs and the locations of the two
* year-specific analyst files. These names bind the candidate to its inputs.
local report_year4 : display %04.0f `report_year_num'
local event_year4 : display %04.0f `event_year_num'
local event_month2 : display %02.0f `event_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'
local event_release "cvd_`event_year4'_`event_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local report_id "bnr_cvd_annual_report_`report_year4'_v`version_num'"
local public_name "bnr_cvd_annual_report_`report_year4'"

local event_csv "$BNR_PUBLIC/metrics/cvd/cvd_metrics_`event_release'.csv"
local mortality_csv "$BNR_PUBLIC/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local site_event_csv "$BNR_REPO/site/downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local site_mortality_csv "$BNR_REPO/site/downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local interpretation "$BNR_REPO/scripts/stata/reporting/annual/`report_year4'/bnr_report_annual_`report_year4'_interpretation.do"
local focus "$BNR_REPO/scripts/stata/reporting/annual/`report_year4'/bnr_report_annual_`report_year4'_focus.do"

* INVARIANT - DO NOT EDIT.
* Require both authoritative public releases and their website mirrors. The
* report must not silently fall back to private data or an unapproved release.
capture confirm file "`event_csv'"
if _rc {
    display as error "Required annual-report event release not found: `event_csv'"
    exit 601
}
capture confirm file "`site_event_csv'"
if _rc {
    display as error "Required website event-release mirror not found: `site_event_csv'"
    display as error "Rerun the CVD-event workflow Step 6."
    exit 601
}
capture confirm file "`mortality_csv'"
if _rc {
    display as error "Required annual-report mortality release not found: `mortality_csv'"
    exit 601
}
capture confirm file "`site_mortality_csv'"
if _rc {
    display as error "Required website mortality-release mirror not found: `site_mortality_csv'"
    display as error "Rerun the mortality workflow Step 6."
    exit 601
}
local interpretation_missing 0
local focus_missing 0
capture confirm file "`interpretation'"
if _rc local interpretation_missing 1
capture confirm file "`focus'"
if _rc local focus_missing 1
if `interpretation_missing' | `focus_missing' {
    display as error "Annual report Step 1 stopped: analyst-written files are missing."
    display as error "Create both year-specific files before running Step 1:"
    display as error "  `interpretation'"
    display as error "  `focus'"
    display as error "Use the existing annual-year folder as the structural example."
    exit 601
}

* INVARIANT - DO NOT EDIT.
* Check byte identity between each authoritative release and website mirror.
* A mismatch stops the build and must be resolved in the source workflow.
quietly checksum "`event_csv'"
local event_size = r(filelen)
local event_checksum = r(checksum)
quietly checksum "`site_event_csv'"
local site_event_size = r(filelen)
local site_event_checksum = r(checksum)
if `site_event_size' != `event_size' | ///
        `site_event_checksum' != `event_checksum' {
    display as error "The authoritative event release and website mirror differ."
    display as error "Rerun the CVD-event workflow Step 6 before building this report."
    exit 459
}

quietly checksum "`mortality_csv'"
local mortality_size = r(filelen)
local mortality_checksum = r(checksum)
quietly checksum "`site_mortality_csv'"
local site_mortality_size = r(filelen)
local site_mortality_checksum = r(checksum)
if `site_mortality_size' != `mortality_size' | ///
        `site_mortality_checksum' != `mortality_checksum' {
    display as error "The authoritative mortality release and website mirror differ."
    display as error "Rerun the mortality workflow Step 6 before building this report."
    exit 459
}

* INVARIANT - DO NOT EDIT.
* Define the private candidate, public-ready and log locations. Step 1 writes
* only to private staging; it never approves or publishes the report.
local package_dir "$BNR_STAGING/reports/cvd/annual/`report_id'"
local candidate_dir "`package_dir'/candidate"
local ready_dir "`package_dir'/public_ready"
local candidate_pdf "`candidate_dir'/`report_id'.pdf"
local candidate_body_pdf "`candidate_dir'/`report_id'_body.pdf"
local candidate_qmd "`candidate_dir'/index.qmd"
local candidate_metadata "`candidate_dir'/report.yml"
local approval "`ready_dir'/approval.yml"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_annual_s1_`report_id'.log"
local site_pdf_href "../../../../../downloads/files/reports/cvd/annual/`report_year4'/`public_name'.pdf"
local pdf_furniture_helper "$BNR_REPO/scripts/python/stamp_annual_report_pdf.py"
local pdf_furniture_python "$BNR_REPO/venv-info-hub/Scripts/python.exe"
local pdf_furniture_logo "$BNR_REPO/site/assets/images/uwi-crestonly-20p.png"

local reports_dir "$BNR_STAGING/reports"
local cvd_dir "`reports_dir'/cvd"
local annual_dir "`cvd_dir'/annual"
* INVARIANT - DO NOT EDIT.
* Create only the narrowly defined private staging directories above.
foreach required_dir in reports_dir cvd_dir annual_dir package_dir ///
        candidate_dir ready_dir {
    quietly mata: st_local("dir_exists", strofreal(direxists("``required_dir''")))
    if "`dir_exists'" != "1" {
        capture mkdir "``required_dir''"
        if _rc {
            display as error "Could not create annual-report directory: ``required_dir''"
            display as error "Check that BNR_STAGING is available and writable."
            exit 603
        }
    }
}

* INVARIANT - DO NOT EDIT.
* Require the controlled PDF-finishing helper, supported Python interpreter
* and approved crest before composition begins.
foreach required_file in pdf_furniture_helper pdf_furniture_python pdf_furniture_logo {
    capture confirm file "``required_file''"
    if _rc {
        display as error "Annual report page-furniture requirement not found: ``required_file''"
        display as error "Run the supported Python-environment check and restore the repository file."
        exit 601
    }
}

* INVARIANT - DO NOT EDIT.
* Protect approved packages from mutation and prevent accidental overwriting
* of an existing candidate unless replace was explicitly requested.
capture confirm file "`approval'"
if !_rc {
    display as error "This candidate version has already been approved: `approval'"
    display as error "Approved packages are immutable. Build a higher version."
    exit 602
}
foreach candidate_file in candidate_pdf candidate_qmd candidate_metadata {
    capture confirm file "``candidate_file''"
    if !_rc & !`replace_existing' {
        display as error "Candidate output already exists: ``candidate_file''"
        display as error "Use replace only to rebuild this unapproved candidate."
        exit 602
    }
}

capture log close bnr_report_annual_s1
log using "`private_log'", text replace name(bnr_report_annual_s1)

* -----------------------------------------------------------------------------
* PDF composition
* -----------------------------------------------------------------------------
* Step 1 owns the document lifecycle and final save. Editorial composition stays
* in the standard section and year-specific files so this controller does not
* become an analytical report script.
* BNR ANALYST: DO NOT ADD REPORT PAGES HERE. Add reusable standard pages to the
* standard DO file or annual narrative to the appropriate year-specific file.

putpdf clear
putpdf begin, pagesize(A4) ///
    margin(top, 0.55) margin(bottom, 0.55) ///
    margin(left, 0.65) margin(right, 0.65) ///
    font("Arial", 10)

* INVARIANT INCLUDE ORDER - DO NOT MOVE.
* Load analyst-owned interpretation first. The reusable standard section inserts
* these locals in fixed year-on-year locations.
include "`interpretation'"

* INVARIANT INCLUDE ORDER - DO NOT MOVE.
* Reusable annual surveillance composition. This file reads only the two
* declared approved public release datasets validated above.
include "$BNR_REPO/scripts/stata/reporting/bnr_report_annual_standard.do"

* INVARIANT INCLUDE ORDER - DO NOT MOVE.
* The year-specific Special chapter owns its analysis, figures, tables and
* narrative. It remains visually continuous with the standard section but is
* operationally separate.
include "`focus'"

* INVARIANT - DO NOT EDIT.
* Generic report identity remains a workflow-controller responsibility. This
* page provides an auditable link between the PDF and its source releases.
putpdf pagebreak
putpdf paragraph
putpdf text ("About this report"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Report identifier: `report_id'"), font("`font_body'", 8.5)
putpdf paragraph
putpdf text ("Report version: v`version_num'"), font("`font_body'", 8.5)
putpdf paragraph
putpdf text ("CVD-event release: `event_release'"), font("`font_body'", 8.5)
putpdf paragraph
putpdf text ("Mortality release: `mortality_release'"), font("`font_body'", 8.5)
putpdf paragraph
putpdf text ("The PDF is built from the declared approved public releases. Publication remains subject to the annual report Step 2 review and Step 3 publication controls."), font("`font_body'", 8)

* INVARIANT - DO NOT EDIT.
* Save the Stata-composed private body PDF. Failure stops here and leaves no
* apparently finished candidate for review.
capture noisily putpdf save "`candidate_body_pdf'", replace
if _rc {
    local save_rc = _rc
    capture log close bnr_report_annual_s1
    display as error "ANNUAL REPORT STEP 1 FAILED SAFELY"
    display as error "The annual-report PDF body could not be saved: `candidate_body_pdf'"
    display as error "Check the private staging path and ensure the PDF is not open."
    exit `save_rc'
}

* INVARIANT - DO NOT EDIT OR REORDER.
* putpdf has no native running headers, footers or automatic page numbers. This
* helper runs locally against the completed PDF only; all data, figures, tables
* and narrative remain Stata-generated above.
local pdf_furniture_command `""`pdf_furniture_python'" "`pdf_furniture_helper'" --input "`candidate_body_pdf'" --output "`candidate_pdf'" --report-title "BNR Annual CVD Report `report_year4'" --logo "`pdf_furniture_logo'" --skip-first-pages 1"'
capture noisily shell `pdf_furniture_command'
if _rc {
    local furniture_rc = _rc
    capture log close bnr_report_annual_s1
    display as error "ANNUAL REPORT STEP 1 FAILED SAFELY"
    display as error "The annual-report PDF page-furniture helper did not complete."
    display as error "Run: python scripts/python/check-python-environment.py"
    display as error "The unstamped PDF body remains private: `candidate_body_pdf'"
    exit `furniture_rc'
}
capture confirm file "`candidate_pdf'"
if _rc {
    capture log close bnr_report_annual_s1
    display as error "ANNUAL REPORT STEP 1 FAILED SAFELY"
    display as error "The page-furniture helper completed without writing: `candidate_pdf'"
    exit 603
}
capture erase "`candidate_body_pdf'"

* INVARIANT - DO NOT EDIT.
* Write the website landing page and machine-readable report metadata from the
* same validated identifiers. These are candidate artefacts, not publication.
local build_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local build_time "`c(current_time)'"
tempname qmd_handle
file open `qmd_handle' using "`candidate_qmd'", write text replace
file write `qmd_handle' "---" _n
file write `qmd_handle' `"title: "Annual CVD report: `report_year4'""' _n
file write `qmd_handle' `"description: "Annual CVD surveillance report for Barbados, including the standard surveillance section and annual Special chapter.""' _n
file write `qmd_handle' "date: `build_date'" _n
file write `qmd_handle' "date-modified: `build_date'" _n
file write `qmd_handle' "report-id: `report_id'" _n
file write `qmd_handle' "report-type: Annual report" _n
file write `qmd_handle' "report-version: v`version_num'" _n
file write `qmd_handle' "coverage-period: `report_year4'" _n
file write `qmd_handle' "event-release-id: `event_release'" _n
file write `qmd_handle' "mortality-release-id: `mortality_release'" _n
file write `qmd_handle' "image: /assets/images/listings/listing_mountain_coast.webp" _n
file write `qmd_handle' "image-alt: Barbados mountain coast." _n
file write `qmd_handle' "categories:" _n
file write `qmd_handle' "  - CVD" _n
file write `qmd_handle' "  - Annual report" _n
file write `qmd_handle' "format:" _n
file write `qmd_handle' "  html:" _n
file write `qmd_handle' "    toc: false" _n
file write `qmd_handle' "    page-layout: article" _n
file write `qmd_handle' "---" _n _n
file write `qmd_handle' "[Open or download the PDF report](`site_pdf_href'){.btn .btn-primary}" _n _n
file write `qmd_handle' `"<iframe src="`site_pdf_href'" title="Annual CVD report: `report_year4'" width="100%" height="900"></iframe>"' _n
file close `qmd_handle'

tempname metadata_handle
file open `metadata_handle' using "`candidate_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: annual_cvd_report" _n
file write `metadata_handle' "report_year: `report_year4'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "public_name: `public_name'" _n
file write `metadata_handle' "event_release_id: `event_release'" _n
file write `metadata_handle' "event_source_size: `event_size'" _n
file write `metadata_handle' "event_source_checksum: `event_checksum'" _n
file write `metadata_handle' "mortality_release_id: `mortality_release'" _n
file write `metadata_handle' "mortality_source_size: `mortality_size'" _n
file write `metadata_handle' "mortality_source_checksum: `mortality_checksum'" _n
file write `metadata_handle' "pdf_file: `public_name'.pdf" _n
file write `metadata_handle' "pdf_page_furniture: controlled_python_v1" _n
file write `metadata_handle' "landing_page: index.qmd" _n
file write `metadata_handle' "built_date: `build_date'" _n
file write `metadata_handle' "built_time: `build_time'" _n
file close `metadata_handle'

* INVARIANT - DO NOT EDIT.
* Print a concise operational receipt. It explicitly confirms that Step 1 has
* created a private candidate but has approved and published nothing.
quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ANNUAL CVD REPORT STEP 1: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Candidate created"
noisily display as text   "  Script version:          1.1.2"
noisily display as text   "  Report identifier:       `report_id'"
noisily display as text   "  CVD-event release:       `event_release'"
noisily display as text   "  Mortality release:       `mortality_release'"
noisily display as text  `"  Candidate package:       `candidate_dir'"'
noisily display as text  `"  Private build log:       `private_log'"'
noisily display as text   "  Publication boundary:    Nothing approved or published"
noisily display as text   "  Next step:               Review the candidate, then run Step 2."
noisily display as result "============================================================================="
}
capture log close bnr_report_annual_s1

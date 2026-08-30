/*******************************************************************************
DO-FILE: bnr_step6_publish_expanded_cvd.do
VERSION: 3.2.1 (29 August 2026)
PURPOSE: Verify and publish an approved combined CVD package.
USAGE:   do "$BNR_STATA/monthly/bnr_step6_publish_expanded_cvd.do" 2026 1
         do "$BNR_STATA/monthly/bnr_step6_publish_expanded_cvd.do" 2026 1 replace

CHANGE 3.2.1:
  Wrap the operational run-summary display block in quietly { } so Stata
  shows the summary itself without echoing each display command.

CHANGE 3.2.0:
  - Add a concise operational run summary after successful promotion.
  - Write a private Step 6 publication log containing the verified release and
    promoted output locations.
  - Require a non-placeholder approved_by value in the approval receipt before
    promotion, in addition to the existing approval and manifest checks.
*******************************************************************************/
version 19
clear all
set more off

args release_year release_month option
if "`release_year'" == "" | "`release_month'" == "" exit 198
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")
local year = real("`release_year'")
local month = real("`release_month'")
if missing(`year') | `year' != floor(`year') | `year' < 2024 exit 198
if missing(`month') | `month' != floor(`month') | !inrange(`month', 1, 12) exit 198
if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO BNR_STAGING BNR_PUBLIC BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}

local year4 : display %04.0f `year'
local month2 : display %02.0f `month'
local release_id "cvd_`year4'_`month2'"
local package_id "cvd_metrics_`release_id'"
local ready "$BNR_STAGING/metrics/cvd/`release_id'/public_ready"
local manifest "`ready'/public_manifest.csv"
local approval "`ready'/approval.yml"
local source_data "`ready'/datasets"
local source_meta "`ready'/metadata"
local public "$BNR_PUBLIC/metrics/cvd"
local public_meta "`public'/metadata"
local public_releases "`public'/releases"
local public_catalogue "`public'/catalogue"
local site "$BNR_REPO/site/downloads/files/metrics/cvd"
local site_releases "`site'/releases"
local site_catalogue "`site'/catalogue"
local release_dta "cvd_metrics_`release_id'.dta"
local release_csv "cvd_metrics_`release_id'.csv"
local current_dta "cvd_metrics_current.dta"
local current_csv "cvd_metrics_current.csv"
local release_yml "cvd_metrics_`release_id'.yml"
local current_yml "cvd_metrics_current.yml"
local package_yml "metric_package.yml"
local zip_name "cvd_metrics_`release_id'.zip"
local public_zip "`public_releases'/`zip_name'"
local catalogue "`public_catalogue'/`release_id'.yml"
local publication_log "$BNR_PRIVATE_LOGS/bnr_cvd_publish_`year4'`month2'.log"

foreach required_file in manifest approval {
    capture confirm file "``required_file''"
    if _rc exit 601
}

* approval.yml must explicitly authorise this release and bind its manifest.
local status_ok 0
local release_ok 0
local family_ok 0
local promotion_ok 0
local approved_size .
local approved_checksum .
local approved_date ""
local approved_by ""
local approved_role ""
tempname approval_handle
file open `approval_handle' using "`approval'", read text
file read `approval_handle' line
while r(eof) == 0 {
    local line = strtrim("`line'")
    if "`line'" == "status: approved" local status_ok 1
    if "`line'" == "release_id: `release_id'" local release_ok 1
    if "`line'" == "metric_family: combined_cvd_metrics" local family_ok 1
    if "`line'" == "promotion_status: pending_step_6" local promotion_ok 1
    if strpos("`line'", "approved_by:") == 1 local approved_by = strtrim(substr("`line'", 13, .))
    if strpos("`line'", "approved_role:") == 1 local approved_role = strtrim(substr("`line'", 15, .))
    if strpos("`line'", "approved_date:") == 1 local approved_date = strtrim(substr("`line'", 15, .))
    if strpos("`line'", "manifest_size:") == 1 local approved_size = real(strtrim(substr("`line'", 15, .)))
    if strpos("`line'", "manifest_checksum:") == 1 local approved_checksum = real(strtrim(substr("`line'", 19, .)))
    file read `approval_handle' line
}
file close `approval_handle'

quietly checksum "`manifest'"
if !`status_ok' | !`release_ok' | !`family_ok' | !`promotion_ok' | "`approved_date'" == "" | r(filelen) != `approved_size' | r(checksum) != `approved_checksum' exit 459

local approved_by_lower = lower(strtrim("`approved_by'"))
if "`approved_by_lower'" == "" | inlist("`approved_by_lower'", "full name", "actual approver name", "approver name", "your name", "<actual authorised name>") {
    display as error "Step 6 cannot promote a package with a missing or placeholder approver name."
    exit 459
}

import delimited using "`manifest'", varnames(1) clear
foreach variable in file_path file_size checksum {
    capture confirm variable `variable'
    if _rc exit 111
}
quietly count
assert r(N) == 7
local payload_files = r(N)
forvalues row = 1/7 {
    local relative_path = file_path[`row']
    quietly checksum "`ready'/`relative_path'"
    if r(filelen) != file_size[`row'] | r(checksum) != checksum[`row'] exit 459
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture mkdir "`public'"
capture mkdir "`public_meta'"
capture mkdir "`public_releases'"
capture mkdir "`public_catalogue'"
capture mkdir "`site'"
capture mkdir "`site_releases'"
capture mkdir "`site_catalogue'"
foreach output_file in "`public'/`release_dta'" "`public'/`release_csv'" "`public'/`current_dta'" "`public'/`current_csv'" "`public_meta'/`release_yml'" "`public_meta'/`current_yml'" "`public_meta'/`package_yml'" "`public_zip'" "`catalogue'" {
    capture confirm file `"`output_file'"'
    if !_rc & !`replace_existing' exit 602
}

copy "`source_data'/`release_dta'" "`public'/`release_dta'", replace
copy "`source_data'/`release_csv'" "`public'/`release_csv'", replace
copy "`source_data'/`current_dta'" "`public'/`current_dta'", replace
copy "`source_data'/`current_csv'" "`public'/`current_csv'", replace
copy "`source_meta'/`release_yml'" "`public_meta'/`release_yml'", replace
copy "`source_meta'/`current_yml'" "`public_meta'/`current_yml'", replace
copy "`source_meta'/`package_yml'" "`public_meta'/`package_yml'", replace

local original_folder "`c(pwd)'"
cd "`public'"
zipfile "`release_dta'" "`release_csv'" "`current_dta'" "`current_csv'" "metadata/`release_yml'" "metadata/`current_yml'" "metadata/`package_yml'", saving("`public_zip'", replace)
cd "`original_folder'"

tempname catalogue_handle
file open `catalogue_handle' using "`catalogue'", write text replace
file write `catalogue_handle' "schema: bnr_download_manifest_v1" _n
file write `catalogue_handle' "package_type: metric" _n
file write `catalogue_handle' "package_id: `package_id'" _n
file write `catalogue_handle' "release_id: `release_id'" _n
file write `catalogue_handle' "surveillance_area: CVD" _n
file write `catalogue_handle' "domain: cvd" _n
file write `catalogue_handle' "metric_family: combined_cvd_metrics" _n
file write `catalogue_handle' "period: `release_id'" _n
file write `catalogue_handle' "release_date: `approved_date'" _n
file write `catalogue_handle' "" _n
file write `catalogue_handle' "title: |-" _n
file write `catalogue_handle' "  Combined CVD metrics" _n
file write `catalogue_handle' "" _n
file write `catalogue_handle' "description: |-" _n
file write `catalogue_handle' "  Approved combined CVD burden and annual incidence-rate datasets for `release_id'." _n
file write `catalogue_handle' "" _n
file write `catalogue_handle' "downloads:" _n
file write `catalogue_handle' "  - id: `package_id'_zip" _n
file write `catalogue_handle' "    title: Full public output package" _n
file write `catalogue_handle' "    artefact_type: ZIP package" _n
file write `catalogue_handle' "    format: ZIP" _n
file write `catalogue_handle' "    file: `zip_name'" _n
file write `catalogue_handle' "    href: files/metrics/cvd/releases/`zip_name'" _n
file write `catalogue_handle' "    description: |-" _n
file write `catalogue_handle' "      Release-stamped and current combined CVD datasets with metadata." _n
file write `catalogue_handle' "    include_in_listing: true" _n
file write `catalogue_handle' "    sort_order: 20" _n
file close `catalogue_handle'

copy "`public'/`current_csv'" "`site'/`current_csv'", replace
copy "`public_zip'" "`site_releases'/`zip_name'", replace
copy "`catalogue'" "`site_catalogue'/`release_id'.yml", replace

* Write a concise private publication log after every promotion action succeeds.
local published_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local published_time "`c(current_time)'"
tempname publish_handle
file open `publish_handle' using "`publication_log'", write text replace
file write `publish_handle' "BNR CVD STEP 6 PUBLICATION LOG" _n
file write `publish_handle' "run_status: published_successfully" _n
file write `publish_handle' "script_version: 3.2.0" _n
file write `publish_handle' "release_id: `release_id'" _n
file write `publish_handle' "approved_by: `approved_by'" _n
file write `publish_handle' "approved_role: `approved_role'" _n
file write `publish_handle' "approved_date: `approved_date'" _n
file write `publish_handle' "published_date: `published_date'" _n
file write `publish_handle' "published_time: `published_time'" _n
file write `publish_handle' "verified_payload_files: `payload_files'" _n
file write `publish_handle' `"public_release_dataset: `public'/`release_dta'"' _n
file write `publish_handle' `"public_current_dataset: `public'/`current_dta'"' _n
file write `publish_handle' `"release_zip: `public_zip'"' _n
file write `publish_handle' `"website_current_csv: `site'/`current_csv'"' _n
file write `publish_handle' `"catalogue_entry: `catalogue'"' _n
file close `publish_handle'

display as result "Expanded CVD Step 6 publish passed."

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "STEP 6: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:                 Published successfully"
noisily display as text   "  Script version:             3.2.1"
noisily display as text   "  Selected release:           `year4'-`month2'"
noisily display as text  `"  Approved by:                `approved_by'"'
noisily display as text   "  Approved payload verified:  `payload_files' files"
noisily display as text  `"  Public release dataset:     `public'/`release_dta'"'
noisily display as text  `"  Current public dataset:     `public'/`current_dta'"'
noisily display as text  `"  Release ZIP:                `public_zip'"'
noisily display as text  `"  Website current CSV:        `site'/`current_csv'"'
noisily display as text  `"  Catalogue entry:            `catalogue'"'
noisily display as text  `"  Private publication log:    `publication_log'"'
noisily display as text   "  Publication status:         Complete"
noisily display as text   "  Next step:                  Verify dashboard and website outputs."
noisily display as result "============================================================================="
}

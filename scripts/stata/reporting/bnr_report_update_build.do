/*******************************************************************************
DO-FILE: bnr_report_update_build.do
VERSION: 1.0.0 (2 September 2026)
PURPOSE: Create one dated rolling three-month CVD surveillance-update page.

USAGE:
  do "$BNR_STATA/reporting/bnr_report_update_build.do" ///
      2026 01 2026 01 2026 07 1

  do "$BNR_STATA/reporting/bnr_report_update_build.do" ///
      2026 01 2026 01 2026 07 2 replace

ARGUMENTS:
  1-2  Report year and month. These identify the stable report location.
  3-4  CVD-event release year and month.
  5-6  Mortality release year and month.
  7    Report version (a positive integer).
  8    Optional: replace. Required only when replacing the rendered report for
       the same report period with an explicitly higher version.

WORKFLOW BOUNDARY:
  This builder creates a small Quarto/Observable page. It does not calculate
  or publish surveillance metrics, apply disclosure control, render Quarto,
  commit to Git, or deploy the website. It reads only release-stamped public
  CSVs that have already passed their source workflow's controls.

  The generated page derives a three-month total only where three consecutive
  months are present, complete, non-suppressed and numeric in BOTH sources.
  It never derives, reconstructs or substitutes a suppressed value.
*******************************************************************************/

version 19
clear all
set more off

args report_year report_month event_year event_month mortality_year mortality_month ///
    report_version option

if "`report_year'" == "" | "`report_month'" == "" | ///
        "`event_year'" == "" | "`event_month'" == "" | ///
        "`mortality_year'" == "" | "`mortality_month'" == "" | ///
        "`report_version'" == "" {
    display as error "Enter report period, event release, mortality release and version."
    exit 198
}

if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")

foreach numeric_input in report_year report_month event_year event_month mortality_year ///
        mortality_month report_version {
    local value = real("``numeric_input''")
    if missing(`value') | `value' != floor(`value') exit 198
}

local report_year_num = real("`report_year'")
local report_month_num = real("`report_month'")
local event_year_num = real("`event_year'")
local event_month_num = real("`event_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")
local version_num = real("`report_version'")

foreach year_num in report_year_num event_year_num mortality_year_num {
    if ``year_num'' < 2024 exit 198
}
foreach month_num in report_month_num event_month_num mortality_month_num {
    if !inrange(``month_num'', 1, 12) exit 198
}
if `version_num' < 1 exit 198

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
foreach path_name in BNR_REPO BNR_STATA BNR_PUBLIC BNR_PRIVATE_LOGS {
    if "$`path_name'" == "" exit 198
}

local report_year4 : display %04.0f `report_year_num'
local report_month2 : display %02.0f `report_month_num'
local event_year4 : display %04.0f `event_year_num'
local event_month2 : display %02.0f `event_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'

local report_period "`report_year4'-`report_month2'"
local event_release "cvd_`event_year4'_`event_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local report_id "bnr_cvd_update_`report_year4'_`report_month2'_v`version_num'"
local public_dir "$BNR_PUBLIC/reports/cvd/updates/`report_period'"
local public_qmd "`public_dir'/index.qmd"
local public_metadata "`public_dir'/report.yml"
local site_dir "$BNR_REPO/site/surveillance/cvd/reports/updates/`report_period'"
local site_qmd "`site_dir'/index.qmd"
local event_csv "$BNR_PUBLIC/metrics/cvd/cvd_metrics_`event_release'.csv"
local mortality_csv "$BNR_PUBLIC/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local site_event_csv "$BNR_REPO/site/downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local site_mortality_csv "$BNR_REPO/site/downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local event_href "../../../../../downloads/files/metrics/cvd/datasets/cvd_metrics_`event_release'.csv"
local mortality_href "../../../../../downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_`mortality_release'.csv"
local private_log "$BNR_PRIVATE_LOGS/bnr_report_update_`report_id'.log"

capture confirm file "`event_csv'"
if _rc {
    display as error "Authoritative CVD-event release is missing: `event_csv'"
    exit 601
}
capture confirm file "`site_event_csv'"
if _rc {
    display as error "Website CVD-event release mirror is missing: `site_event_csv'"
    display as error "Rerun CVD-event workflow Step 6."
    exit 601
}
capture confirm file "`mortality_csv'"
if _rc {
    display as error "Authoritative mortality release is missing: `mortality_csv'"
    exit 601
}
capture confirm file "`site_mortality_csv'"
if _rc {
    display as error "Website mortality release mirror is missing: `site_mortality_csv'"
    display as error "Rerun mortality workflow Step 6."
    exit 601
}

quietly checksum "`event_csv'"
local event_size = r(filelen)
local event_checksum = r(checksum)
quietly checksum "`site_event_csv'"
if r(filelen) != `event_size' | r(checksum) != `event_checksum' {
    display as error "Authoritative and website CVD-event releases differ."
    display as error "Rerun CVD-event workflow Step 6 before creating this update."
    exit 459
}
quietly checksum "`mortality_csv'"
local mortality_size = r(filelen)
local mortality_checksum = r(checksum)
quietly checksum "`site_mortality_csv'"
if r(filelen) != `mortality_size' | r(checksum) != `mortality_checksum' {
    display as error "Authoritative and website mortality releases differ."
    display as error "Rerun mortality workflow Step 6 before creating this update."
    exit 459
}

capture mkdir "$BNR_PUBLIC/reports"
capture mkdir "$BNR_PUBLIC/reports/cvd"
capture mkdir "$BNR_PUBLIC/reports/cvd/updates"
capture mkdir "`public_dir'"
capture mkdir "$BNR_REPO/site/surveillance/cvd/reports"
capture mkdir "$BNR_REPO/site/surveillance/cvd/reports/updates"
capture mkdir "`site_dir'"

local existing_version .
capture confirm file "`public_metadata'"
if !_rc {
    tempname existing_metadata_handle
    file open `existing_metadata_handle' using "`public_metadata'", read text
    file read `existing_metadata_handle' line
    while r(eof) == 0 {
        local line = strtrim(`"`line'"')
        local line = subinstr(`"`line'"', char(34), "", .)
        if strpos("`line'", "report_version: v") == 1 {
            local existing_version = real(substr("`line'", 18, .))
        }
        file read `existing_metadata_handle' line
    }
    file close `existing_metadata_handle'
}
if !missing(`existing_version') & `version_num' < `existing_version' {
    display as error "This would replace update v`existing_version' with older v`version_num'."
    exit 459
}
local output_exists 0
capture confirm file "`public_qmd'"
if !_rc local output_exists 1
capture confirm file "`public_metadata'"
if !_rc local output_exists 1
capture confirm file "`site_qmd'"
if !_rc local output_exists 1
if `output_exists' & !`replace_existing' {
    display as error "A report already exists for `report_period'."
    display as error "Use replace for an approved correction or higher version."
    exit 602
}

local published_date : display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
local report_month_name : display %tmMonth ym(`report_year_num', `report_month_num')
tempfile staged_qmd staged_metadata
local report_page "`staged_qmd'"

capture log close bnr_report_update
log using "`private_log'", text replace name(bnr_report_update)

tempname report_handle
file open `report_handle' using "`report_page'", write text replace
file write `report_handle' "---" _n
file write `report_handle' `"title: "Rolling three-month CVD surveillance update: `report_month_name' `report_year4'""' _n
file write `report_handle' `"description: "Objective CVD event and mortality counts for the latest three complete common months in the declared public releases.""' _n
file write `report_handle' "date: `published_date'" _n
file write `report_handle' "date-modified: `published_date'" _n
file write `report_handle' "image: /assets/images/listings/listing_reef_shallows.webp" _n
file write `report_handle' "image-alt: Sunlit shallow reef water in Barbados." _n
file write `report_handle' "report-id: `report_id'" _n
file write `report_handle' "report-type: Rolling three-month update" _n
file write `report_handle' "report-version: v`version_num'" _n
file write `report_handle' "event-release-id: `event_release'" _n
file write `report_handle' "mortality-release-id: `mortality_release'" _n
file write `report_handle' "categories:" _n
file write `report_handle' "  - CVD" _n
file write `report_handle' "  - Rolling three-month update" _n
file write `report_handle' "format:" _n
file write `report_handle' "  html:" _n
file write `report_handle' "    toc: true" _n
file write `report_handle' "    toc-title: On this page" _n
file write `report_handle' "    page-layout: article" _n
file write `report_handle' "---" _n _n
file write `report_handle' "This online update presents the latest three complete months that are common to" _n
file write `report_handle' "the declared CVD-event and mortality releases. It uses published counts only." _n _n
file write `report_handle' "```{ojs}" _n
file write `report_handle' "//| output: false" _n
file write `report_handle' `"eventMetrics = FileAttachment("`event_href'").csv({typed: true})"' _n
file write `report_handle' `"mortalityMetrics = FileAttachment("`mortality_href'").csv({typed: true})"' _n
file write `report_handle' "```" _n _n
file write `report_handle' "```{ojs}" _n
file write `report_handle' "//| output: false" _n
file write `report_handle' "isPublishedNumber = row => {" _n
file write `report_handle' "  const status = String(row?.suppression_status ?? '').trim().toLowerCase();" _n
file write `report_handle' "  const value = Number(row?.display_value);" _n
file write `report_handle' "  return (status === '' || status === 'none' || status === 'not_applicable') && Number.isFinite(value);" _n
file write `report_handle' "}" _n
file write `report_handle' "monthKey = row => String(row.period_year).padStart(4, '0') + '-' + String(row.period_month).padStart(2, '0')" _n
file write `report_handle' "monthSerial = key => { const [year, month] = key.split('-').map(Number); return year * 12 + month; }" _n
file write `report_handle' "complete = row => String(row.period_complete) === '1'" _n
file write `report_handle' "onlyOne = (rows, label) => {" _n
file write `report_handle' "  if (rows.length !== 1) throw new Error(label + ': expected one public row per month.');" _n
file write `report_handle' "  return rows[0];" _n
file write `report_handle' "}" _n
file write `report_handle' "```" _n _n
file write `report_handle' "```{ojs}" _n
file write `report_handle' "//| output: false" _n
file write `report_handle' "eventRows = eventMetrics.filter(row =>" _n
file write `report_handle' "  row.metric_id === 'CVD-BURDEN-001' && row.period_type === 'monthly' &&" _n
file write `report_handle' "  row.event_type === 'all_cvd' && row.sex === 'all' && row.age_group === 'all' &&" _n
file write `report_handle' "  row.ascertainment_scope === 'hospital_only' && row.statistic === 'monthly_count'" _n
file write `report_handle' ")" _n
file write `report_handle' "mortalityRows = mortalityMetrics.filter(row =>" _n
file write `report_handle' "  row.metric_id === 'MORT-BURDEN-001' && row.period_type === 'monthly' &&" _n
file write `report_handle' "  row.event_type === 'all_cvd' && row.sex === 'all' && row.age_group === 'all' &&" _n
file write `report_handle' "  row.case_definition === 'primary_clear_likely' && row.statistic === 'monthly_count'" _n
file write `report_handle' ")" _n
file write `report_handle' "eventByMonth = d3.rollup(eventRows, rows => onlyOne(rows, 'Events'), monthKey)" _n
file write `report_handle' "mortalityByMonth = d3.rollup(mortalityRows, rows => onlyOne(rows, 'Mortality'), monthKey)" _n
file write `report_handle' "commonMonths = Array.from(eventByMonth.keys()).filter(key => mortalityByMonth.has(key)).sort()" _n
file write `report_handle' "eligibleMonths = commonMonths.filter(key => isPublishedNumber(eventByMonth.get(key)) &&" _n
file write `report_handle' "  isPublishedNumber(mortalityByMonth.get(key)) && complete(eventByMonth.get(key)) && complete(mortalityByMonth.get(key)))" _n
file write `report_handle' "windowMonths = eligibleMonths.slice(-3)" _n
file write `report_handle' "windowIsConsecutive = windowMonths.length === 3 &&" _n
file write `report_handle' "  monthSerial(windowMonths[1]) === monthSerial(windowMonths[0]) + 1 &&" _n
file write `report_handle' "  monthSerial(windowMonths[2]) === monthSerial(windowMonths[1]) + 1" _n
file write `report_handle' "updateRows = windowIsConsecutive ? windowMonths.map(month => ({" _n
file write `report_handle' "  month," _n
file write `report_handle' "  events: Number(eventByMonth.get(month).display_value)," _n
file write `report_handle' "  deaths: Number(mortalityByMonth.get(month).display_value)" _n
file write `report_handle' "})) : []" _n
file write `report_handle' "```" _n _n
file write `report_handle' "## Headline" _n _n
file write `report_handle' "```{ojs}" _n
file write `report_handle' "//| echo: false" _n
file write `report_handle' "{" _n
file write `report_handle' "  if (!windowIsConsecutive) return html`<p>The declared releases do not contain three complete, non-suppressed consecutive months in common for this update.</p>`;" _n
file write `report_handle' "  const events = d3.sum(updateRows, d => d.events);" _n
file write `report_handle' "  const deaths = d3.sum(updateRows, d => d.deaths);" _n
file write `report_handle' "  const start = d3.utcFormat('%B %Y')(new Date(updateRows[0].month + '-01T00:00:00Z'));" _n
file write `report_handle' "  const end = d3.utcFormat('%B %Y')(new Date(updateRows[2].month + '-01T00:00:00Z'));" _n
file write `report_handle' "  const result = document.createElement('p');" _n
file write `report_handle' "  result.textContent = events.toLocaleString('en-GB') + ' hospital-recorded CVD events and ' + deaths.toLocaleString('en-GB') + ' CVD deaths were published for the three-month period from ' + start + ' to ' + end + '.';" _n
file write `report_handle' "  return result;" _n
file write `report_handle' "}" _n
file write `report_handle' "```" _n _n
file write `report_handle' "## Published monthly counts" _n _n
file write `report_handle' "```{ojs}" _n
file write `report_handle' "//| echo: false" _n
file write `report_handle' "updateRows.length ? Inputs.table(updateRows.map(row => ({" _n
file write `report_handle' "  Month: d3.utcFormat('%B %Y')(new Date(row.month + '-01T00:00:00Z'))," _n
file write `report_handle' "  'Hospital-recorded CVD events': row.events," _n
file write `report_handle' "  'CVD deaths (primary definition)': row.deaths" _n
file write `report_handle' "}))) : 'No comparable three-month table is available.'" _n
file write `report_handle' "```" _n _n
file write `report_handle' "## Data sources" _n _n
file write `report_handle' "- CVD-event release: [`event_release'](`event_href')" _n
file write `report_handle' "- Mortality release: [`mortality_release'](`mortality_href')" _n
file write `report_handle' "- Report version: `report_id'" _n
file close `report_handle'

tempname metadata_handle
file open `metadata_handle' using "`staged_metadata'", write text replace
file write `metadata_handle' "schema: bnr_report_metadata_v1" _n
file write `metadata_handle' "report_id: `report_id'" _n
file write `metadata_handle' "report_type: rolling_three_month_cvd_update" _n
file write `metadata_handle' "report_period: `report_period'" _n
file write `metadata_handle' "report_version: v`version_num'" _n
file write `metadata_handle' "event_release_id: `event_release'" _n
file write `metadata_handle' "event_source_size: `event_size'" _n
file write `metadata_handle' "event_source_checksum: `event_checksum'" _n
file write `metadata_handle' "mortality_release_id: `mortality_release'" _n
file write `metadata_handle' "mortality_source_size: `mortality_size'" _n
file write `metadata_handle' "mortality_source_checksum: `mortality_checksum'" _n
file write `metadata_handle' "landing_page: index.qmd" _n
file write `metadata_handle' "built_date: `published_date'" _n
file write `metadata_handle' "built_time: `c(current_time)'" _n
file close `metadata_handle'

copy "`staged_qmd'" "`public_qmd'", replace
copy "`staged_metadata'" "`public_metadata'", replace
copy "`staged_qmd'" "`site_qmd'", replace

quietly checksum "`staged_qmd'"
local qmd_size = r(filelen)
local qmd_checksum = r(checksum)
quietly checksum "`public_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' {
    capture log close bnr_report_update
    display as error "Public rolling-update QMD verification failed."
    exit 459
}
quietly checksum "`site_qmd'"
if r(filelen) != `qmd_size' | r(checksum) != `qmd_checksum' {
    capture log close bnr_report_update
    display as error "Website rolling-update QMD verification failed."
    exit 459
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ROLLING THREE-MONTH CVD UPDATE: OPERATIONAL RUN SUMMARY"
noisily display as text   "  Run status:              Published successfully"
noisily display as text   "  Script version:          1.0.0"
noisily display as text   "  Report period:           `report_period'"
noisily display as text   "  Report version:          v`version_num'"
noisily display as text   "  CVD-event release:       `event_release'"
noisily display as text   "  Mortality release:       `mortality_release'"
noisily display as text  `"  Authoritative package:   `public_dir'"'
noisily display as text  `"  Website landing page:    `site_qmd'"'
noisily display as text  `"  Private publication log: `private_log'"'
noisily display as text   "  Next step:               Render and review the dated page."
noisily display as result "============================================================================="
}
capture log close bnr_report_update
capture assert 1

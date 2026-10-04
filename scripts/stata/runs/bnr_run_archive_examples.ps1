#Requires -Version 5.1
<#
FILE: bnr_run_archive_examples.ps1
VERSION: 1.0.0 (30 September 2026)
PLACE IN: scripts/stata/runs/ (alongside the existing Stata runners).

HOW TO USE
1. Open in an editor. Select and run SETUP below in a PowerShell terminal.
2. Select ONE audit example. Inspect its listed paths.
3. Select the corresponding execution example when ready.
4. Change the example years/months/reason to suit the intended reset.

Executing this entire file runs SETUP only. All archive examples are inside
block comments; they are a command reference, not a bulk archive job.

ORDER FOR A COMPLETE DEVELOPMENT RESET
Annual -> rolling -> case-fatality -> mortality releases -> event releases.
Rebuild mortality -> events -> case-fatality/annual/rolling, then render,
inspect and merge the working branch through the normal repository process.

CURRENT RELEASES
The monthly utility blocks a single current-release request and skips it in
-AllMonths mode. Publish another approved current release before archiving
that month, or rebuild/replace the current release in place. No override exists.
-AllMonths covers ALL eligible private months, not just website downloads.
Monthly archives include raw extracts, derived data, staging and matching logs.
Frozen historical datasets are outside the monthly archive targets.

REPORTS
Annual/rolling archives: PrivateRoot/admin/report-archive.
Monthly archives: PrivateRoot/admin/release-archive.
Case-fatality requires reset-case-fatality-v1-development.ps1 v1.3.0 or later:
older versions DELETE instead of archive. v1.3.0 preserves the same eight
restricted targets under admin/report-archive and verifies their hashes.
This is a case-fatality v1 utility, not a generic reset for arbitrary one-off studies.
Archives can contain confidential files and must remain outside Git.
Local archival does not change the deployed website until deployment.
#>

# SETUP -- run these lines before selecting any example.
$repoRoot = "C:\yoshimi-hot\output\analyse-bnr\info-hub"
$privateRoot = "C:\yoshimi-hot\output\analyse-bnr\info-hub-private"
$reason = "Development rebuild following historical NRN and death-date corrections"
Set-Location -LiteralPath $repoRoot
git branch --show-current
git rev-parse HEAD
Write-Host "Setup complete. Select an audit example below; no archival has run."

<#
MORTALITY -- one month

AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Mortality -Year 2024 -Month 3 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Mortality -Year 2024 -Month 3 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
MORTALITY -- all eligible months in one year
Missing, current and dependency-blocked months are skipped; read the summary.
AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Mortality -Year 2024 -AllMonths `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Mortality -Year 2024 -AllMonths `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
EVENTS -- one month

AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2024 -Month 3 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2024 -Month 3 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
EVENTS -- all eligible months in one year
Missing, current and dependency-blocked months are skipped; read the summary.
AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2024 -AllMonths `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2024 -AllMonths `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
EVENTS -- archive dependent rolling updates together with a non-current release
Use only when those rolling reports should also be withdrawn. Annual report
references can still block archival; remove dependent annual reports first.

AUDIT
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2026 -Month 3 -IncludeRollingUpdates `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2026 -Month 3 -IncludeRollingUpdates `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
MORTALITY -- whole-year development reset, 2024-2026
This includes additional private months and skips the current release.

AUDIT
foreach ($year in 2024, 2025, 2026) {
    .\scripts\maintenance\manage-cvd-monthly-release.ps1 `
        -Workflow Mortality -Year $year -AllMonths `
        -RepoRoot $repoRoot -PrivateRoot $privateRoot `
        -Reason $reason
}

EXECUTE
foreach ($year in 2024, 2025, 2026) {
    .\scripts\maintenance\manage-cvd-monthly-release.ps1 `
        -Workflow Mortality -Year $year -AllMonths `
        -RepoRoot $repoRoot -PrivateRoot $privateRoot `
        -Reason $reason -Execute
}
#>

<#
EVENTS -- whole-year development reset, 2024-2026
This includes additional private months and skips the current release.

AUDIT
foreach ($year in 2024, 2025, 2026) {
    .\scripts\maintenance\manage-cvd-monthly-release.ps1 `
        -Workflow Events -Year $year -AllMonths `
        -RepoRoot $repoRoot -PrivateRoot $privateRoot `
        -Reason $reason
}

EXECUTE
foreach ($year in 2024, 2025, 2026) {
    .\scripts\maintenance\manage-cvd-monthly-release.ps1 `
        -Workflow Events -Year $year -AllMonths `
        -RepoRoot $repoRoot -PrivateRoot $privateRoot `
        -Reason $reason -Execute
}
#>

<#
EXACT MONTHS -- March/September 2024, March/September 2025, March/June 2026
Set Workflow to Mortality or Events. Single-month calls stop on a current
release or unresolved dependency; handle it before proceeding. Each call is
independent, so earlier successful archives remain if a later call stops.

AUDIT
$workflow = "Mortality"
$selectedReleases = @(
    @{ Year = 2024; Month = 3 }
    @{ Year = 2024; Month = 9 }
    @{ Year = 2025; Month = 3 }
    @{ Year = 2025; Month = 9 }
    @{ Year = 2026; Month = 3 }
    @{ Year = 2026; Month = 6 }
)
foreach ($release in $selectedReleases) {
    .\scripts\maintenance\manage-cvd-monthly-release.ps1 `
        -Workflow $workflow -Year $release.Year -Month $release.Month `
        -RepoRoot $repoRoot -PrivateRoot $privateRoot `
        -Reason $reason
}

EXECUTE -- uses the same workflow and selectedReleases defined above
foreach ($release in $selectedReleases) {
    .\scripts\maintenance\manage-cvd-monthly-release.ps1 `
        -Workflow $workflow -Year $release.Year -Month $release.Month `
        -RepoRoot $repoRoot -PrivateRoot $privateRoot `
        -Reason $reason -Execute
}
#>

<#
ANNUAL -- 2025, all versions
Includes the companion public-health update, private staging versions and logs.
AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual -Year 2025 -AllVersions `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual -Year 2025 -AllVersions `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
ANNUAL -- one selected version
Stable public copies are included only when they belong to the selected version.
AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual -Year 2025 -Version 1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual -Year 2025 -Version 1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
ROLLING -- one period, all versions

AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2026 -Month 3 -AllVersions `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2026 -Month 3 -AllVersions `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
ROLLING -- all periods in 2026, all versions

AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2026 -AllMonths -AllVersions `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2026 -AllMonths -AllVersions `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
ROLLING -- one selected version

AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2026 -Month 3 -Version 1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2026 -Month 3 -Version 1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
CASE-FATALITY -- restricted 2025 study / v1 development package
REQUIRED: script v1.3.0 or later. Earlier versions delete; check its header first.
Includes analytical/review/candidate files, one-off package, logs and public mirrors.
AUDIT -- no files moved
.\scripts\powershell\reset-case-fatality-v1-development.ps1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\powershell\reset-case-fatality-v1-development.ps1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
OPTIONAL MAINTENANCE -- retire legacy public CVD file structures
A separate legacy cleanup, not part of routine monthly/report withdrawal.
Retains the approved 2015-2019 monthly reference assets. Do not run by default.
AUDIT -- no files moved
.\scripts\maintenance\manage-cvd-legacy-public-files.ps1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason

EXECUTE -- after inspecting the audit
.\scripts\maintenance\manage-cvd-legacy-public-files.ps1 `
    -RepoRoot $repoRoot -PrivateRoot $privateRoot `
    -Reason $reason `
    -Execute
#>

<#
OPTIONAL MAINTENANCE -- retired private linkage tree
A historical one-time retirement utility; not part of a report/release rebuild.
Uses -Apply rather than -Execute. Stops if live references remain or its fixed
archive destination already exists. Destination differs from admin archives:
PrivateRoot/data/archive/cvd_linkage_retired_20260827.

AUDIT
.\scripts\maintenance\retire_cvd_linkage_derived_tree.ps1 `
    -PrivateRoot $privateRoot

EXECUTE
.\scripts\maintenance\retire_cvd_linkage_derived_tree.ps1 `
    -PrivateRoot $privateRoot -Apply
#>

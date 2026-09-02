<#
.SYNOPSIS
Preview or remove exact BNR reporting engineering-test artefacts.

.DESCRIPTION
Dry-run is the default. Use -Apply only after reviewing the listed targets.
This script removes superseded annual entry points and the synthetic one-off
and disclosure-screen artefacts created during reporting-workflow hardening.

It deliberately preserves the validated January 2026 rolling update, annual
report outputs, all report workflow source code, source datasets and parent
directories.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/maintenance/cleanup_reporting_hardening_test_artifacts.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/maintenance/cleanup_reporting_hardening_test_artifacts.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$RepoRoot,
    [string]$PrivateRoot
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
}
if ([string]::IsNullOrWhiteSpace($PrivateRoot)) {
    $repoParent = Split-Path -Parent $RepoRoot
    $PrivateRoot = Join-Path $repoParent "info-hub-private"
}

$requiredMarker = Join-Path $RepoRoot "scripts/stata/reporting/bnr_report_oneoff_s1_prepare.do"
if (-not (Test-Path -LiteralPath $requiredMarker -PathType Leaf)) {
    throw "Refusing cleanup: the hardened one-off workflow was not found at $requiredMarker"
}

$targets = @(
    # Superseded annual entry points. Hardened _s1_/_s2_/_s3_ replacements remain.
    (Join-Path $RepoRoot "scripts/stata/reporting/bnr_report_annual_build.do"),
    (Join-Path $RepoRoot "scripts/stata/reporting/bnr_report_annual_approve.do"),
    (Join-Path $RepoRoot "scripts/stata/reporting/bnr_report_annual_publish.do"),
    (Join-Path $RepoRoot "scripts/stata/dialogs/bnr_report_annual_build.dlg"),
    (Join-Path $RepoRoot "scripts/stata/dialogs/bnr_report_annual_approve.dlg"),
    (Join-Path $RepoRoot "scripts/stata/dialogs/bnr_report_annual_publish.dlg"),

    # Synthetic one-off source, private candidate packages and disclosure input/review.
    (Join-Path $PrivateRoot "outputs/staging/reporting_test_inputs/bnr_cvd_oneoff_workflow_test.pdf"),
    (Join-Path $PrivateRoot "outputs/staging/reporting_test_inputs/bnr_report_disclosure_screen_test.dta"),
    (Join-Path $PrivateRoot "outputs/staging/reports/cvd/studies/bnr_cvd_oneoff_workflow_test_v1"),
    (Join-Path $PrivateRoot "outputs/staging/reports/cvd/studies/bnr_cvd_oneoff_workflow_test_v2"),
    (Join-Path $PrivateRoot "outputs/staging/report_reviews/disclosure/workflow_test"),

    # Exact private operational logs from the synthetic one-off/disclosure tests.
    (Join-Path $PrivateRoot "logs/private/bnr_report_oneoff_s1_bnr_cvd_oneoff_workflow_test_v1.log"),
    (Join-Path $PrivateRoot "logs/private/bnr_report_oneoff_s2_bnr_cvd_oneoff_workflow_test_v1.log"),
    (Join-Path $PrivateRoot "logs/private/bnr_report_oneoff_s3_bnr_cvd_oneoff_workflow_test_v1.log"),
    (Join-Path $PrivateRoot "logs/private/bnr_report_oneoff_s1_bnr_cvd_oneoff_workflow_test_v2.log"),
    (Join-Path $PrivateRoot "logs/private/bnr_report_oneoff_s2_bnr_cvd_oneoff_workflow_test_v2.log"),
    (Join-Path $PrivateRoot "logs/private/bnr_report_oneoff_s3_bnr_cvd_oneoff_workflow_test_v2.log"),
    (Join-Path $PrivateRoot "logs/private/bnr_report_disclosure_screen_workflow_test.log"),

    # Synthetic public and website one-off report outputs.
    (Join-Path $RepoRoot "outputs/public/reports/cvd/studies/workflow_test"),
    (Join-Path $RepoRoot "site/downloads/files/reports/cvd/studies/workflow_test"),
    (Join-Path $RepoRoot "site/surveillance/cvd/reports/studies/workflow_test")
)

$existingTargets = @($targets | Where-Object { Test-Path -LiteralPath $_ })
$missingCount = $targets.Count - $existingTargets.Count

Write-Host "BNR reporting hardening cleanup"
Write-Host "Repository:   $RepoRoot"
Write-Host "Private root: $PrivateRoot"
Write-Host "Mode:         $(if ($Apply) { 'APPLY' } else { 'DRY RUN' })"
Write-Host ""
Write-Host "Preserved: validated rolling update 2026-01, annual report outputs and all workflow source files."
Write-Host ""

if ($existingTargets.Count -eq 0) {
    Write-Host "No listed synthetic or superseded artefacts are present. Nothing to remove."
    exit 0
}

foreach ($target in $existingTargets) {
    if ($Apply) {
        Remove-Item -LiteralPath $target -Recurse -Force
        Write-Host "REMOVED  $target"
    }
    else {
        Write-Host "WOULD REMOVE  $target"
    }
}

Write-Host ""
Write-Host "Existing targets: $($existingTargets.Count)"
Write-Host "Already absent:   $missingCount"
if (-not $Apply) {
    Write-Host "No files were changed. Re-run with -Apply to perform this exact cleanup."
}

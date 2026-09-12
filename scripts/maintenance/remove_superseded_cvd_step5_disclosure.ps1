<#
PURPOSE: Remove superseded top-level CVD Step 5 disclosure implementation files.
VERSION: 2.0.0 (27 August 2026)

Run from the info-hub repository root:
  powershell -ExecutionPolicy Bypass -File scripts\maintenance\remove_superseded_cvd_step5_disclosure.ps1

The command above is a dry run.  To apply the deletion after reviewing its
list, add -Apply.
#>
[CmdletBinding()]
param([switch]$Apply)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$cvdRoot = Join-Path $repoRoot "scripts\stata\metrics\cvd"
$wrapper = Join-Path $cvdRoot "bnr_step5_suppress_expanded_cvd.do"

if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
    throw "The v2 expanded disclosure wrapper was not found: $wrapper"
}

if (-not (Select-String -LiteralPath $wrapper -SimpleMatch 'private/expanded_disclosure' -Quiet)) {
    throw "The wrapper does not use the encapsulated private implementation. No files were removed."
}

$targets = @(
    "bnr_step5_suppress_expanded_cvd_io_smoke.do",
    "bnr_step5_suppress_expanded_cvd_stage1_combine.do",
    "bnr_step5_suppress_expanded_cvd_stage2_dco_support.do",
    "bnr_step5_suppress_expanded_cvd_stage3_primary_flags.do",
    "bnr_step5_suppress_expanded_cvd_stage4_primary_projection.do",
    "bnr_step5_suppress_expanded_cvd_stage5_structural_secondary.do",
    "bnr_step5_suppress_expanded_cvd_stage6_existing_closure.do",
    "bnr_step5_suppress_expanded_cvd_stage7_rate_equation_audit.do",
    "bnr_step5_suppress_expanded_cvd_stage8_full_projection.do",
    "bnr_step5_suppress_expanded_cvd_stage9_candidate_audit.do"
) | ForEach-Object { Join-Path $cvdRoot $_ }

$testsRoot = Join-Path $cvdRoot "tests"
$targets += @(
    "test_bnr_cvd_stage5_expanded_disclosure.do",
    "test_bnr_cvd_stage5_expanded_io_smoke.do",
    "test_bnr_cvd_stage5_expanded_stage1_combine.do",
    "test_bnr_cvd_stage5_expanded_stage2_dco_support.do",
    "test_bnr_cvd_stage5_expanded_stage3_primary_flags.do",
    "test_bnr_cvd_stage5_expanded_stage4_primary_projection.do",
    "test_bnr_cvd_stage5_expanded_stage5_structural_secondary.do",
    "test_bnr_cvd_stage5_expanded_stage6_existing_closure.do",
    "test_bnr_cvd_stage5_expanded_stage7_rate_equation_audit.do",
    "test_bnr_cvd_stage5_expanded_stage8_full_projection.do",
    "test_bnr_cvd_stage5_expanded_stage9_candidate_audit.do"
) | ForEach-Object { Join-Path $testsRoot $_ }

$existing = $targets | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }

if (-not $Apply) {
    Write-Host "Dry run: the following superseded files would be removed:"
    $existing | ForEach-Object { Write-Host "  $_" }
    Write-Host "No files were removed. Rerun with -Apply after review."
    exit 0
}

$existing | ForEach-Object { Remove-Item -LiteralPath $_ -Force }
Write-Host "Removed $($existing.Count) superseded CVD Step 5 disclosure files."

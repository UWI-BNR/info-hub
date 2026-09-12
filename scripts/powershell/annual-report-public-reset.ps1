<#
.SYNOPSIS
    Resets all generated 2025 annual CVD report artefacts for a fresh v1 run.

.DESCRIPTION
    Default mode is audit only. It lists every exact target, verifies any
    remaining public metadata or landing pages identify the expected v6
    development release, and makes no changes.

    Run again with -Execute only after reviewing the audit. Execution removes:
      * private staging packages bnr_cvd_annual_report_2025_v1 through v6;
      * matching private Step 1, Step 2 and Step 3 logs (when requested);
      * the public report package and its website mirror; and
      * both the annual-report and public-health-update website landing pages.

    The script is deliberately restricted to report year 2025 and versions
    v1-v6. It does not delete source releases, Stata code, templates, assets,
    or any other report year.

.EXAMPLE
    # First, obtain these roots in Stata:
    # display "$BNR_STAGING"
    # display "$BNR_PRIVATE_LOGS"
    .\scripts\powershell\annual-report-public-reset.ps1 -StagingRoot "D:\BNR\staging" -PrivateLogsRoot "D:\BNR\private-logs"

.EXAMPLE
    # Perform exactly the audited deletion.
    .\scripts\powershell\annual-report-public-reset.ps1 -StagingRoot "D:\BNR\staging" -PrivateLogsRoot "D:\BNR\private-logs" -Execute
#>
[CmdletBinding()]
param(
    [switch]$Execute,
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory)] [string]$StagingRoot,
    [string]$PrivateLogsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SafeChildPath {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$RelativePath
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    $rootPrefix = $rootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe target rejected: $RelativePath"
    }
    return $candidate
}

function Get-YamlValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Key
    )

    $pattern = '^' + [regex]::Escape($Key) + ':\s*(.+?)\s*$'
    $match = Select-String -LiteralPath $Path -Pattern $pattern | Select-Object -First 1
    if ($null -eq $match) {
        throw "Required key '$Key' was not found in $Path"
    }
    return $match.Matches[0].Groups[1].Value.Trim(' ', '"', "'")
}

function Test-ExpectedYamlValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [string]$ExpectedValue,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[string]]$Problems
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            if ((Get-YamlValue -Path $Path -Key $Key) -ne $ExpectedValue) {
                $Problems.Add("Unexpected $Key in $Path")
            }
        }
        catch {
            $Problems.Add($_.Exception.Message)
        }
    }
}

function Test-ExpectedQmdValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$ExpectedLine,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[string]]$Problems
    )

    if ((Test-Path -LiteralPath $Path -PathType Leaf) -and
        -not (Select-String -LiteralPath $Path -Pattern ([regex]::Escape($ExpectedLine)) -Quiet)) {
        $Problems.Add("Unexpected generated landing page: $Path")
    }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$StagingRoot = (Resolve-Path -LiteralPath $StagingRoot).Path

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "RepoRoot is not a Git repository: $RepoRoot"
}

$branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($branch -ne 'cvd-workflow-hardening') {
    throw "Safety stop: current branch is '$branch', not 'cvd-workflow-hardening'."
}

if ($PrivateLogsRoot -ne '') {
    $PrivateLogsRoot = (Resolve-Path -LiteralPath $PrivateLogsRoot).Path
}

$targets = [System.Collections.Generic.List[object]]::new()
foreach ($version in 1..6) {
    $targets.Add([pscustomobject]@{
        Label = "Private annual-report staging package v$version"
        Path = Get-SafeChildPath -Root $StagingRoot -RelativePath "reports/cvd/annual/bnr_cvd_annual_report_2025_v$version"
        Kind = 'Directory'
    })
}

if ($PrivateLogsRoot -ne '') {
    foreach ($version in 1..6) {
        foreach ($stage in 's1', 's2', 's3') {
            $targets.Add([pscustomobject]@{
                Label = "Private annual-report $stage log v$version"
                Path = Get-SafeChildPath -Root $PrivateLogsRoot -RelativePath "bnr_report_annual_$($stage)_bnr_cvd_annual_report_2025_v$version.log"
                Kind = 'File'
            })
        }
    }
}

$targets.Add([pscustomobject]@{
    Label = 'Public annual-report package (includes public-health-update PDF and QMD)'
    Path = Get-SafeChildPath -Root $RepoRoot -RelativePath 'outputs/public/reports/cvd/annual/2025'
    Kind = 'Directory'
})
$targets.Add([pscustomobject]@{
    Label = 'Website download mirror (includes public-health-update PDF)'
    Path = Get-SafeChildPath -Root $RepoRoot -RelativePath 'site/downloads/files/reports/cvd/annual/2025'
    Kind = 'Directory'
})
$targets.Add([pscustomobject]@{
    Label = 'Website annual-report landing page'
    Path = Get-SafeChildPath -Root $RepoRoot -RelativePath 'site/surveillance/cvd/reports/annual/2025/index.qmd'
    Kind = 'File'
})
$targets.Add([pscustomobject]@{
    Label = 'Website public-health-update landing page'
    Path = Get-SafeChildPath -Root $RepoRoot -RelativePath 'site/surveillance/cvd/reports/briefings/2025/index.qmd'
    Kind = 'File'
})

$problems = [System.Collections.Generic.List[string]]::new()

# Verify every remaining generated public artefact before allowing its deletion.
$publicMetadata = Get-SafeChildPath -Root $RepoRoot -RelativePath 'outputs/public/reports/cvd/annual/2025/report.yml'
$siteMetadata = Get-SafeChildPath -Root $RepoRoot -RelativePath 'site/downloads/files/reports/cvd/annual/2025/report.yml'
foreach ($metadataPath in @($publicMetadata, $siteMetadata)) {
    Test-ExpectedYamlValue -Path $metadataPath -Key 'report_id' -ExpectedValue 'bnr_cvd_annual_report_2025_v6' -Problems $problems
    Test-ExpectedYamlValue -Path $metadataPath -Key 'report_version' -ExpectedValue 'v6' -Problems $problems
    Test-ExpectedYamlValue -Path $metadataPath -Key 'public_health_update_id' -ExpectedValue 'bnr_cvd_public_health_update_2025_v6' -Problems $problems
}

$annualLandingPage = Get-SafeChildPath -Root $RepoRoot -RelativePath 'site/surveillance/cvd/reports/annual/2025/index.qmd'
$updateLandingPage = Get-SafeChildPath -Root $RepoRoot -RelativePath 'site/surveillance/cvd/reports/briefings/2025/index.qmd'
Test-ExpectedQmdValue -Path $annualLandingPage -ExpectedLine 'report-id: bnr_cvd_annual_report_2025_v6' -Problems $problems
Test-ExpectedQmdValue -Path $annualLandingPage -ExpectedLine 'report-version: v6' -Problems $problems
Test-ExpectedQmdValue -Path $updateLandingPage -ExpectedLine 'report-id: bnr_cvd_public_health_update_2025_v6' -Problems $problems
Test-ExpectedQmdValue -Path $updateLandingPage -ExpectedLine 'report-version: v6' -Problems $problems

Write-Host ''
Write-Host '2025 annual-report full reset: audit manifest' -ForegroundColor Cyan
foreach ($target in $targets) {
    $state = if (Test-Path -LiteralPath $target.Path) { 'present' } else { 'already absent' }
    Write-Host ("  [{0}] {1}" -f $state, $target.Path)
    Write-Host ("           {0}" -f $target.Label)
}
Write-Host ''

if ($problems.Count -gt 0) {
    Write-Host 'No deletion performed. Audit failed:' -ForegroundColor Yellow
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}

Write-Host 'Audit passed: every remaining public artefact is the expected v6 development release.' -ForegroundColor Green
if (-not $Execute) {
    Write-Host 'No files were changed. Re-run with -Execute to perform exactly this deletion.' -ForegroundColor Cyan
    exit 0
}

foreach ($target in $targets) {
    if (Test-Path -LiteralPath $target.Path) {
        if ($target.Kind -eq 'Directory') {
            Remove-Item -LiteralPath $target.Path -Recurse -Force
        }
        else {
            Remove-Item -LiteralPath $target.Path -Force
        }
    }
}

$logPath = Get-SafeChildPath -Root $RepoRoot -RelativePath 'docs/manual-review-update-log.md'
if (Test-Path -LiteralPath $logPath -PathType Leaf) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    $entry = [Environment]::NewLine + "- $stamp - Reset generated 2025 annual CVD report v1-v6 development artefacts, including the associated public-health update, before a fresh controlled v1 run."
    Add-Content -LiteralPath $logPath -Value $entry
}
else {
    Write-Warning 'The reset succeeded, but docs/manual-review-update-log.md was not found and was not updated.'
}

Write-Host 'Deletion completed. Review the following before committing:' -ForegroundColor Green
& git -C $RepoRoot status --short

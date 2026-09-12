<#
.SYNOPSIS
    Resets the generated public 2025 annual CVD report package for a fresh v1 run.

.DESCRIPTION
    Default mode is an audit only. It verifies that the current package is the
    expected development v6 release, prints every target, and makes no changes.

    Run again with -Execute only after reviewing the audit. Execution removes
    the annual-report and associated public-health-update artefacts, then records
    the reset in docs/manual-review-update-log.md.

.EXAMPLE
    .\annual-report-public-reset.ps1

.EXAMPLE
    .\annual-report-public-reset.ps1 -Execute
#>
[CmdletBinding()]
param(
    [switch]$Execute,

    # Run from the repository root by default; override only when necessary.
    [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryPath {
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

    $match = Select-String -LiteralPath $Path -Pattern "^$Key`:\s*(.+?)\s*$" | Select-Object -First 1
    if ($null -eq $match) {
        throw "Required key '$Key' was not found in $Path"
    }

    return $match.Matches[0].Groups[1].Value.Trim(' ', '"', "'")
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "RepoRoot is not a Git repository: $RepoRoot"
}

$branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($branch -ne 'cvd-workflow-hardening') {
    throw "Safety stop: current branch is '$branch', not 'cvd-workflow-hardening'."
}

$targets = @(
    [pscustomobject]@{
        Label = 'Public annual-report package (includes public-health-update PDF and QMD)'
        RelativePath = 'outputs/public/reports/cvd/annual/2025'
        Kind = 'Directory'
    },
    [pscustomobject]@{
        Label = 'Website download mirror (includes public-health-update PDF)'
        RelativePath = 'site/downloads/files/reports/cvd/annual/2025'
        Kind = 'Directory'
    },
    [pscustomobject]@{
        Label = 'Website annual-report landing page'
        RelativePath = 'site/surveillance/cvd/reports/annual/2025/index.qmd'
        Kind = 'File'
    }
)

$expectedFiles = @(
    'outputs/public/reports/cvd/annual/2025/bnr_cvd_annual_report_2025.pdf',
    'outputs/public/reports/cvd/annual/2025/bnr_cvd_public_health_update_2025.pdf',
    'outputs/public/reports/cvd/annual/2025/index.qmd',
    'outputs/public/reports/cvd/annual/2025/public_health_update.qmd',
    'outputs/public/reports/cvd/annual/2025/report.yml',
    'site/downloads/files/reports/cvd/annual/2025/bnr_cvd_annual_report_2025.pdf',
    'site/downloads/files/reports/cvd/annual/2025/bnr_cvd_public_health_update_2025.pdf',
    'site/downloads/files/reports/cvd/annual/2025/report.yml',
    'site/surveillance/cvd/reports/annual/2025/index.qmd'
)

$problems = [System.Collections.Generic.List[string]]::new()

foreach ($relativePath in $expectedFiles) {
    $path = Get-RepositoryPath -Root $RepoRoot -RelativePath $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $problems.Add("Missing expected file: $relativePath")
    }
}

if ($problems.Count -eq 0) {
    foreach ($relativePath in @(
        'outputs/public/reports/cvd/annual/2025/report.yml',
        'site/downloads/files/reports/cvd/annual/2025/report.yml'
    )) {
        $path = Get-RepositoryPath -Root $RepoRoot -RelativePath $relativePath
        if ((Get-YamlValue -Path $path -Key 'report_id') -ne 'bnr_cvd_annual_report_2025_v6') {
            $problems.Add("Unexpected report_id in $relativePath")
        }
        if ((Get-YamlValue -Path $path -Key 'report_version') -ne 'v6') {
            $problems.Add("Unexpected report_version in $relativePath")
        }
        if ((Get-YamlValue -Path $path -Key 'public_health_update_id') -ne 'bnr_cvd_public_health_update_2025_v6') {
            $problems.Add("Unexpected public_health_update_id in $relativePath")
        }
    }
}

$landingPage = Get-RepositoryPath -Root $RepoRoot -RelativePath 'site/surveillance/cvd/reports/annual/2025/index.qmd'
if ((Test-Path -LiteralPath $landingPage -PathType Leaf) -and
    -not (Select-String -LiteralPath $landingPage -Pattern '^report-version:\s*v6\s*$' -Quiet)) {
    $problems.Add('The website landing page does not declare report-version: v6')
}

Write-Host ''
Write-Host '2025 annual-report public reset: audit manifest' -ForegroundColor Cyan
foreach ($target in $targets) {
    Write-Host ("  [{0}] {1}" -f $target.Kind, $target.RelativePath)
    Write-Host ("         {0}" -f $target.Label)
}
Write-Host ''

if ($problems.Count -gt 0) {
    Write-Host 'No deletion performed. Audit failed:' -ForegroundColor Yellow
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}

Write-Host 'Audit passed: all targets are the expected v6 development release.' -ForegroundColor Green

if (-not $Execute) {
    Write-Host 'No files were changed. Re-run with -Execute to perform exactly this deletion.' -ForegroundColor Cyan
    exit 0
}

foreach ($target in $targets) {
    $path = Get-RepositoryPath -Root $RepoRoot -RelativePath $target.RelativePath
    if ($target.Kind -eq 'Directory') {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
    else {
        Remove-Item -LiteralPath $path -Force
    }
}

$logPath = Get-RepositoryPath -Root $RepoRoot -RelativePath 'docs/manual-review-update-log.md'
if (Test-Path -LiteralPath $logPath -PathType Leaf) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    Add-Content -LiteralPath $logPath -Value "`n- $stamp - Removed the generated 2025 annual CVD report v6 public package and associated public-health-update artefacts to reset controlled development to v1."
}
else {
    Write-Warning 'The reset succeeded, but docs/manual-review-update-log.md was not found and was not updated.'
}

Write-Host 'Deletion completed. Review the following before committing:' -ForegroundColor Green
& git -C $RepoRoot status --short

<#
.SYNOPSIS
    Resets generated case-fatality report v1 development artefacts.

.DESCRIPTION
    Default mode is audit only: it lists the exact private, public and website
    targets and verifies that any public artefacts identify the expected v1
    case-fatality release. It does not change files.

    Re-run with -Execute only after reviewing the audit. Execution removes only
    the generated v1 analysis/review package, one-off workflow package and logs,
    authoritative public package, and website mirrors. It never removes source
    event or mortality releases, Stata code, templates, assets or other reports.

.EXAMPLE
    # Audit only: no files are changed.
    .\scripts\powershell\reset-case-fatality-v1-development.ps1 `
        -RepoRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub" `
        -PrivateRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub-private"

.EXAMPLE
    # Delete exactly the audited generated artefacts.
    .\scripts\powershell\reset-case-fatality-v1-development.ps1 `
        -RepoRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub" `
        -PrivateRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub-private" `
        -Execute
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$RepoRoot,
    [Parameter(Mandatory)] [string]$PrivateRoot,
    [switch]$Execute
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
    elseif (Test-Path -LiteralPath (Split-Path -Parent $Path) -PathType Container) {
        $Problems.Add("Expected metadata file is missing: $Path")
    }
}

function Test-ExpectedQmdLine {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$ExpectedLine,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[string]]$Problems
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if (-not (Select-String -LiteralPath $Path -Pattern ([regex]::Escape($ExpectedLine)) -Quiet)) {
            $Problems.Add("Unexpected generated landing page: $Path")
        }
    }
    elseif (Test-Path -LiteralPath (Split-Path -Parent $Path) -PathType Container) {
        $Problems.Add("Expected landing page is missing: $Path")
    }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PrivateRoot = (Resolve-Path -LiteralPath $PrivateRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "RepoRoot is not a Git repository: $RepoRoot"
}
$branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($branch -ne 'case-fatality-dev') {
    throw "Safety stop: current branch is '$branch', not 'case-fatality-dev'."
}

$studyId = 'case_fatality_2025'
$reportId = 'bnr_cvd_oneoff_case_fatality_2025_v1'
$analysisId = 'cvd_case_fatality_2010_2025_v01'
$targets = [System.Collections.Generic.List[object]]::new()

foreach ($item in @(
    @{ Label = 'Private case-fatality analysis, review and candidate package'; Root = $PrivateRoot; Relative = "outputs/staging/reports/cvd/case-fatality/$analysisId"; Kind = 'Directory' },
    @{ Label = 'Private one-off v1 candidate, approval and package-source files'; Root = $PrivateRoot; Relative = "outputs/staging/reports/cvd/studies/$reportId"; Kind = 'Directory' },
    @{ Label = 'Private one-off Step 1 log'; Root = $PrivateRoot; Relative = "logs/private/bnr_report_oneoff_s1_$reportId.log"; Kind = 'File' },
    @{ Label = 'Private one-off Step 2 log'; Root = $PrivateRoot; Relative = "logs/private/bnr_report_oneoff_s2_$reportId.log"; Kind = 'File' },
    @{ Label = 'Private one-off Step 3 log'; Root = $PrivateRoot; Relative = "logs/private/bnr_report_oneoff_s3_$reportId.log"; Kind = 'File' },
    @{ Label = 'Authoritative public v1 report package'; Root = $RepoRoot; Relative = "outputs/public/reports/cvd/studies/$studyId"; Kind = 'Directory' },
    @{ Label = 'Website download mirror for v1 report and dataset'; Root = $RepoRoot; Relative = "site/downloads/files/reports/cvd/studies/$studyId"; Kind = 'Directory' },
    @{ Label = 'Website v1 report landing page'; Root = $RepoRoot; Relative = "site/surveillance/cvd/reports/studies/$studyId"; Kind = 'Directory' }
)) {
    $targets.Add([pscustomobject]@{
        Label = $item.Label
        Path = Get-SafeChildPath -Root $item.Root -RelativePath $item.Relative
        Kind = $item.Kind
    })
}

$problems = [System.Collections.Generic.List[string]]::new()
$publicMetadata = Get-SafeChildPath -Root $RepoRoot -RelativePath "outputs/public/reports/cvd/studies/$studyId/report.yml"
$siteMetadata = Get-SafeChildPath -Root $RepoRoot -RelativePath "site/downloads/files/reports/cvd/studies/$studyId/report.yml"
foreach ($metadataPath in @($publicMetadata, $siteMetadata)) {
    Test-ExpectedYamlValue -Path $metadataPath -Key 'report_id' -ExpectedValue $reportId -Problems $problems
    Test-ExpectedYamlValue -Path $metadataPath -Key 'report_version' -ExpectedValue 'v1' -Problems $problems
}
$siteQmd = Get-SafeChildPath -Root $RepoRoot -RelativePath "site/surveillance/cvd/reports/studies/$studyId/index.qmd"
Test-ExpectedQmdLine -Path $siteQmd -ExpectedLine "report-id: $reportId" -Problems $problems
Test-ExpectedQmdLine -Path $siteQmd -ExpectedLine 'report-version: v1' -Problems $problems

Write-Host ''
Write-Host 'Case-fatality v1 development reset: audit manifest' -ForegroundColor Cyan
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

Write-Host 'Audit passed: each remaining public artefact identifies the expected case-fatality v1 development release.' -ForegroundColor Green
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

Write-Host 'Deletion completed. No source data, code, templates or unrelated report outputs were targeted.' -ForegroundColor Green
& git -C $RepoRoot status --short

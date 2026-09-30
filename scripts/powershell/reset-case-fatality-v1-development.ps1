<#
.SYNOPSIS
    Archives generated case-fatality report v1 development artefacts.

.NOTES
    Version 1.3.0 (30 September 2026)

.DESCRIPTION
    Default mode is audit only: it lists the exact private, public and website
    targets and verifies that any public artefacts identify the expected v1
    case-fatality release. It does not change files.

    Re-run with -Execute only after reviewing the audit. Execution archives only
    the generated v1 analysis/review package, one-off workflow package and logs,
    authoritative public package, and website mirrors. It never removes source
    event or mortality releases, Stata code, templates, assets or other reports.
    Archives reside in PrivateRoot/admin/report-archive, retain original paths
    under private/ and repository/, and include a SHA-256 manifest and run record.
    No Remove-Item operation is used. An interrupted archive is marked incomplete;
    retain it and use its manifest to locate the preserved files.

.EXAMPLE
    # Audit only: no files are changed.
    .\scripts\powershell\reset-case-fatality-v1-development.ps1 `
        -RepoRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub" `
        -PrivateRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub-private"

.EXAMPLE
    # Archive exactly the audited generated artefacts.
    .\scripts\powershell\reset-case-fatality-v1-development.ps1 `
        -RepoRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub" `
        -PrivateRoot "C:\yoshimi-hot\output\analyse-bnr\info-hub-private" `
        -Execute
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$RepoRoot,
    [Parameter(Mandatory)] [string]$PrivateRoot,
    [string]$Reason = 'Development rebuild of case-fatality v1',
    [string]$Operator = $env:USERNAME,
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
        # This list is intentionally empty at the start of a successful audit.
        # Do not make it Mandatory: PowerShell otherwise attempts to bind an
        # empty generic list as an empty argument collection before this
        # function can add any diagnostic text.
        [System.Collections.Generic.List[string]]$Problems
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
        # See Test-ExpectedYamlValue: an empty list is valid at audit start.
        [System.Collections.Generic.List[string]]$Problems
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
# Private outputs must be outside the repository, with neither root nested.
$repoBoundary = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$privateBoundary = [System.IO.Path]::GetFullPath($PrivateRoot).TrimEnd('\', '/')
$separator = [System.IO.Path]::DirectorySeparatorChar
$comparison = [System.StringComparison]::OrdinalIgnoreCase
if ($repoBoundary.Equals($privateBoundary, $comparison) -or
    $privateBoundary.StartsWith($repoBoundary + $separator, $comparison) -or
    $repoBoundary.StartsWith($privateBoundary + $separator, $comparison)) {
    throw "Safety stop: repository and private roots must be separate, non-nested folders."
}

# Permit named working branches; protect the primary branches and detached HEAD.
$branchOutput = & git -C $RepoRoot branch --show-current
if ($LASTEXITCODE -ne 0) {
    throw "Cannot determine the repository branch."
}
$branch = "$branchOutput".Trim()
if ([string]::IsNullOrWhiteSpace($branch) -or
    $branch -in @('main', 'master')) {
    throw "Safety stop: use a named working branch, not main/master or detached HEAD."
}

$commitOutput = & git -C $RepoRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine the repository commit.' }
$commit = "$commitOutput".Trim()
if ([string]::IsNullOrWhiteSpace($Reason) -or [string]::IsNullOrWhiteSpace($Operator)) {
    throw 'Reason and Operator must not be blank.'
}
$archiveRoot = Get-SafeChildPath -Root $PrivateRoot -RelativePath 'admin/report-archive'

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
        Scope = if ($item.Root -eq $PrivateRoot) { 'private' } else { 'repository' }
        Relative = $item.Relative
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
Write-Host 'Case-fatality v1 development archive: audit manifest' -ForegroundColor Cyan
foreach ($target in $targets) {
    $state = if (Test-Path -LiteralPath $target.Path) { 'present' } else { 'already absent' }
    Write-Host ("  [{0}] {1}" -f $state, $target.Path)
    Write-Host ("           {0}" -f $target.Label)
}
Write-Host "Archive root: $archiveRoot"
Write-Host ''

if ($problems.Count -gt 0) {
    Write-Host 'No archive performed. Audit failed:' -ForegroundColor Yellow
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}

Write-Host 'Audit passed: each remaining public artefact identifies the expected case-fatality v1 development release.' -ForegroundColor Green
if (-not $Execute) {
    Write-Host 'No files were changed. Re-run with -Execute to archive these exact targets.' -ForegroundColor Cyan
    exit 0
}

# Build a complete manifest BEFORE moving any target. Include hidden files.
$presentTargets = @($targets | Where-Object { Test-Path -LiteralPath $_.Path })
if ($presentTargets.Count -eq 0) {
    Write-Host 'No remaining targets. Nothing changed.'
    exit 0
}
$archiveName = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '_' + $reportId
$runArchive = Get-SafeChildPath -Root $archiveRoot -RelativePath $archiveName
if (Test-Path -LiteralPath $runArchive) { throw "Archive already exists: $runArchive" }
$manifest = [System.Collections.Generic.List[object]]::new()
foreach ($target in $presentTargets) {
    $item = Get-Item -LiteralPath $target.Path -Force
    if (($target.Kind -eq 'Directory') -ne $item.PSIsContainer) {
        throw "Unexpected target type: $($target.Path)"
    }
    $entries = @($item)
    if ($item.PSIsContainer) {
        $entries += @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Force)
    }
    foreach ($entry in $entries) {
        if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Linked path cannot be archived: $($entry.FullName)"
        }
        if ($entry.PSIsContainer) { continue }
        $root = if ($target.Scope -eq 'private') { $privateBoundary } else { $repoBoundary }
        $relativeFile = $entry.FullName.Substring(($root + $separator).Length)
        $archivePath = Get-SafeChildPath -Root $runArchive `
            -RelativePath (Join-Path $target.Scope $relativeFile)
        $manifest.Add([pscustomobject]@{
            scope = $target.Scope
            category = $target.Label
            source_path = $entry.FullName
            archive_path = $archivePath
            bytes = $entry.Length
            sha256 = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash
        })
    }
}

New-Item -ItemType Directory -Path $runArchive -Force | Out-Null
$manifestPath = Join-Path $runArchive 'archive-manifest.csv'
if ($manifest.Count -gt 0) {
    $manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
}
else {
    '"scope","category","source_path","archive_path","bytes","sha256"' |
        Set-Content -LiteralPath $manifestPath -Encoding UTF8
}
$recordPath = Join-Path $runArchive 'archive.yml'
$recordHeader = @(
    'schema: bnr_report_archive_v1',
    'report_type: OneOff',
    "report_key: $studyId",
    "report_id: $reportId",
    'version_scope: v1',
    "archived_at_utc: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    "operator: `"$($Operator.Replace('"', "'"))`"",
    "reason: `"$($Reason.Replace('"', "'"))`"",
    "git_branch: $branch",
    "git_commit: $commit",
    "repository_root: `"$RepoRoot`"",
    "private_root: `"$PrivateRoot`"",
    'manifest: archive-manifest.csv',
    "file_count: $($manifest.Count)"
)
@($recordHeader + 'status: in_progress') | Set-Content -LiteralPath $recordPath -Encoding UTF8
try {
    foreach ($target in $presentTargets) {
        $destination = Get-SafeChildPath -Root $runArchive `
            -RelativePath (Join-Path $target.Scope $target.Relative)
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Move-Item -LiteralPath $target.Path -Destination $destination
    }
    foreach ($row in $manifest) {
        $archived = Get-Item -LiteralPath $row.archive_path -Force
        $hash = (Get-FileHash -LiteralPath $row.archive_path -Algorithm SHA256).Hash
        if ($archived.Length -ne $row.bytes -or $hash -ne $row.sha256) {
            throw "Archived file verification failed: $($row.archive_path)"
        }
    }
    @($recordHeader + 'status: complete') | Set-Content -LiteralPath $recordPath -Encoding UTF8
}
catch {
    @($recordHeader + 'status: incomplete' +
        "error: `"$($_.Exception.Message.Replace('"', "'"))`"") |
        Set-Content -LiteralPath $recordPath -Encoding UTF8
    throw "Archive incomplete; retain and inspect $runArchive. $($_.Exception.Message)"
}
Write-Host "Archive completed and verified: $runArchive" -ForegroundColor Green
Write-Host 'No source data, code, templates or unrelated report outputs were targeted.'
& git -C $RepoRoot status --short

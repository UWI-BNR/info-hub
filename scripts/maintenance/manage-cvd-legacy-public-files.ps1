#Requires -Version 5.1
# VERSION: 1.0.0 (28 September 2026)
<#
.SYNOPSIS
Audits or archives the retired CVD public-file structures.

.DESCRIPTION
Moves only explicitly allow-listed legacy public artefacts into a recoverable
private administrative archive. It never deletes files. Audit is the default;
add -Execute only after reviewing every proposed path.

The script deliberately retains the approved 2015-2019 CVD monthly reference
assets under outputs/public/metrics/cvd/burden because current event Steps 4
and 5 still use those paths. It also confirms that the website's canonical
reference CSV exists before the legacy website folder can be moved.

.EXAMPLE
$privateRoot = "C:\yoshimi-hot\output\analyse-bnr\info-hub-private"
.\scripts\maintenance\manage-cvd-legacy-public-files.ps1 `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Retire superseded public CVD release structures"

.EXAMPLE
.\scripts\maintenance\manage-cvd-legacy-public-files.ps1 `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Retire superseded public CVD release structures" `
    -Execute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Reason,

    [string]$Operator = $env:USERNAME,
    [string]$RepoRoot,
    [string]$PrivateRoot = $env:BNR_PRIVATE,
    [switch]$Execute
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Get-RelativePathWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $fullPath = Get-FullPath -Path $Path
    $fullRoot = Get-FullPath -Path $Root
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the repository root: $fullPath"
    }
    return $fullPath.Substring($prefix.Length)
}

function Add-ArchiveItem {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$List,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Category
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $fullPath = Get-FullPath -Path $Path
    foreach ($entry in $List) {
        if ($entry.Path -eq $fullPath) {
            return
        }
    }
    [void]$List.Add([pscustomobject]@{
        Path = $fullPath
        Category = $Category
    })
}

function Get-MetadataReleaseId {
    param([Parameter(Mandatory = $true)][string]$MetadataPath)
    if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        throw "Required legacy identity metadata is missing: $MetadataPath"
    }
    $match = Select-String -LiteralPath $MetadataPath `
        -Pattern '^release_id:\s*(\S+)\s*$' | Select-Object -First 1
    if ($null -eq $match) {
        throw "Legacy identity metadata has no readable release_id: $MetadataPath"
    }
    return $match.Matches[0].Groups[1].Value.Trim().Trim('"')
}

function Assert-LegacyMetadata {
    param(
        [Parameter(Mandatory = $true)][string]$MetadataPath,
        [Parameter(Mandatory = $true)][string]$ExpectedReleaseId
    )
    $actualReleaseId = Get-MetadataReleaseId -MetadataPath $MetadataPath
    if ($actualReleaseId -ne $ExpectedReleaseId) {
        throw "Refusing to archive a path that no longer has the expected legacy identity. Expected $ExpectedReleaseId but found $actualReleaseId in $MetadataPath"
    }
}

function Assert-ZipContainsEntry {
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$RequiredPattern
    )
    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        return
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $matched = $false
        foreach ($entry in $archive.Entries) {
            $entryName = $entry.FullName.Replace('\', '/')
            if ($entryName -match $RequiredPattern) {
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            throw "Refusing to archive ZIP because its known legacy marker was not found: $ZipPath"
        }
    }
    finally {
        $archive.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($Operator)) {
    throw "Operator is required. Supply -Operator if USERNAME is not set."
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $PSScriptRoot "..\.."
}
$RepoRoot = Get-FullPath -Path $RepoRoot
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ".git"))) {
    throw "RepoRoot is not the root of the Info-Hub Git repository: $RepoRoot"
}
if ([string]::IsNullOrWhiteSpace($PrivateRoot)) {
    throw "PrivateRoot is required. Set BNR_PRIVATE or supply -PrivateRoot."
}
$PrivateRoot = Get-FullPath -Path $PrivateRoot
if (-not (Test-Path -LiteralPath $PrivateRoot -PathType Container)) {
    throw "PrivateRoot does not exist: $PrivateRoot"
}
if ($RepoRoot -eq $PrivateRoot) {
    throw "RepoRoot and PrivateRoot must be different locations."
}

$branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim()
$commit = (& git -C $RepoRoot rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commit)) {
    throw "Git branch and commit could not be read from RepoRoot."
}
if ($branch -in @("main", "master")) {
    throw "Legacy archival is blocked on branch '$branch'. Use a reviewed working branch."
}
if ($branch -eq "HEAD") {
    throw "Legacy archival is blocked on a detached HEAD. Switch to a named working branch."
}

$eventPublic = Join-Path $RepoRoot "outputs\public\metrics\cvd"
$eventSite = Join-Path $RepoRoot "site\downloads\files\metrics\cvd"
$mortalityPublic = Join-Path $RepoRoot "outputs\public\metrics\mortality"

$protectedReferences = @(
    (Join-Path $eventPublic "burden\cvd_monthly_reference_2015_2019.csv"),
    (Join-Path $eventPublic "burden\cvd_monthly_reference_2015_2019.dta"),
    (Join-Path $eventPublic "burden\metadata\cvd_monthly_reference_2015_2019.yml")
)
$protectedHashes = @{}
foreach ($referencePath in $protectedReferences) {
    if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
        throw "Live CVD reference dependency is missing. No archival was attempted: $referencePath"
    }
    $protectedHashes[$referencePath] = (Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash.ToLowerInvariant()
}

$siteReference = Join-Path $eventSite "cvd_monthly_reference_2015_2019.csv"
if (-not (Test-Path -LiteralPath $siteReference -PathType Leaf)) {
    throw "The website's canonical CVD monthly reference CSV is missing: $siteReference"
}
$legacySiteReference = Join-Path $eventSite "burden\cvd_monthly_reference_2015_2019.csv"
if (Test-Path -LiteralPath $legacySiteReference -PathType Leaf) {
    $siteReferenceHash = (Get-FileHash -LiteralPath $siteReference -Algorithm SHA256).Hash
    $legacyReferenceHash = (Get-FileHash -LiteralPath $legacySiteReference -Algorithm SHA256).Hash
    if ($siteReferenceHash -ne $legacyReferenceHash) {
        throw "The canonical and legacy website reference CSVs differ. Review them before archiving the legacy folder."
    }
}

$legacySiteDirectory = Join-Path $eventSite "burden"
if (Test-Path -LiteralPath $legacySiteDirectory -PathType Container) {
    Assert-LegacyMetadata `
        -MetadataPath (Join-Path $legacySiteDirectory "metadata\cvd_burden_metrics_current.yml") `
        -ExpectedReleaseId "cvd_2024_04"
}

$legacyPublicMetadata = Join-Path $eventPublic "burden\metadata\cvd_burden_metrics_current.yml"
if (Test-Path -LiteralPath $legacyPublicMetadata -PathType Leaf) {
    Assert-LegacyMetadata -MetadataPath $legacyPublicMetadata -ExpectedReleaseId "cvd_2024_04"
}
$legacyPackageMetadata = Join-Path $eventPublic "burden\metadata\metric_package.yml"
if (Test-Path -LiteralPath $legacyPackageMetadata -PathType Leaf) {
    Assert-LegacyMetadata -MetadataPath $legacyPackageMetadata -ExpectedReleaseId "cvd_2024_04"
}

$legacyEventZip = Join-Path $eventSite "burden.zip"
Assert-ZipContainsEntry -ZipPath $legacyEventZip `
    -RequiredPattern '(^|/)bnr_cvd_burden_cvd_2024_0[12]\.zip$'

$legacyMortalityZip = Join-Path $mortalityPublic "burden.zip"
Assert-ZipContainsEntry -ZipPath $legacyMortalityZip `
    -RequiredPattern '(^|/)bnr_mort_burden_mort_2026_07\.zip$'

$items = New-Object System.Collections.ArrayList
Add-ArchiveItem -List $items -Path $legacySiteDirectory `
    -Category "legacy website CVD burden directory"
Add-ArchiveItem -List $items -Path $legacyEventZip `
    -Category "legacy website CVD burden bundle"
Add-ArchiveItem -List $items -Path $legacyMortalityZip `
    -Category "legacy authoritative mortality bundle"
Add-ArchiveItem -List $items `
    -Path (Join-Path $eventPublic "burden\cvd_burden_metrics_current.csv") `
    -Category "legacy authoritative CVD current dataset"
Add-ArchiveItem -List $items `
    -Path (Join-Path $eventPublic "burden\cvd_burden_metrics_current.dta") `
    -Category "legacy authoritative CVD current dataset"
Add-ArchiveItem -List $items -Path $legacyPublicMetadata `
    -Category "legacy authoritative CVD current metadata"
Add-ArchiveItem -List $items -Path $legacyPackageMetadata `
    -Category "legacy authoritative CVD package metadata"

if ($items.Count -eq 0) {
    Write-Host "No allow-listed legacy public artefacts remain. Nothing changed."
    exit 0
}

Write-Host ""
Write-Host "BNR LEGACY PUBLIC-FILE ARCHIVE AUDIT"
Write-Host "  Mode:       $(if ($Execute) { 'EXECUTE' } else { 'AUDIT ONLY' })"
Write-Host "  Branch:     $branch"
Write-Host "  Commit:     $commit"
Write-Host "  Operator:   $Operator"
Write-Host "  Reason:     $Reason"
Write-Host ""
Write-Host "Artefacts to archive:"
foreach ($item in $items) {
    Write-Host ("  [{0}] {1}" -f $item.Category, $item.Path)
}
Write-Host ""
Write-Host "Protected live reference assets retained in place:"
foreach ($referencePath in $protectedReferences) {
    Write-Host "  [retained CVD reference] $referencePath"
}
Write-Host "  [retained website reference] $siteReference"

if (-not $Execute) {
    Write-Host ""
    Write-Host "Audit complete. No files were moved. Add -Execute after reviewing this list."
    exit 0
}

$archiveRoot = Join-Path $PrivateRoot "admin\legacy-public-archive"
$timestamp = Get-Date -Format "yyyyMMddTHHmmss"
$archiveDirectory = Join-Path $archiveRoot "${timestamp}_cvd_legacy_public_files"
if (Test-Path -LiteralPath $archiveDirectory) {
    throw "Archive destination already exists: $archiveDirectory"
}
New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null

$manifestRows = New-Object System.Collections.ArrayList
foreach ($item in $items) {
    $files = if (Test-Path -LiteralPath $item.Path -PathType Container) {
        @(Get-ChildItem -LiteralPath $item.Path -File -Recurse)
    }
    else {
        @(Get-Item -LiteralPath $item.Path)
    }
    foreach ($file in $files) {
        $relativeFile = Get-RelativePathWithinRoot -Path $file.FullName -Root $RepoRoot
        $destinationFile = Join-Path (Join-Path $archiveDirectory "repository") $relativeFile
        [void]$manifestRows.Add([pscustomobject]@{
            category = $item.Category
            source_path = $file.FullName
            repository_relative_path = $relativeFile
            archive_path = $destinationFile
            bytes = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }
}

$manifestPath = Join-Path $archiveDirectory "archive-manifest.csv"
if ($manifestRows.Count -gt 0) {
    $manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
}
else {
    '"category","source_path","repository_relative_path","archive_path","bytes","sha256"' | `
        Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

$recordPath = Join-Path $archiveDirectory "archive.yml"
$recordHeader = @(
    "schema: bnr_legacy_public_archive_v1",
    "archive_scope: cvd_legacy_public_files",
    "archived_at_utc: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    "operator: `"$($Operator.Replace('"', "'"))`"",
    "reason: `"$($Reason.Replace('"', "'"))`"",
    "git_branch: $branch",
    "git_commit: $commit",
    "repository_root: `"$RepoRoot`"",
    "private_root: `"$PrivateRoot`"",
    "manifest: archive-manifest.csv",
    "file_count: $($manifestRows.Count)",
    "protected_cvd_reference_assets_retained: true"
)
@($recordHeader + "status: in_progress") | Set-Content -LiteralPath $recordPath -Encoding UTF8

try {
    foreach ($item in $items) {
        $relativeItem = Get-RelativePathWithinRoot -Path $item.Path -Root $RepoRoot
        $destination = Join-Path (Join-Path $archiveDirectory "repository") $relativeItem
        $destinationParent = Split-Path $destination -Parent
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        Move-Item -LiteralPath $item.Path -Destination $destination
    }

    foreach ($referencePath in $protectedReferences) {
        if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
            throw "A protected CVD reference asset is missing after archival: $referencePath"
        }
        $afterHash = (Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($afterHash -ne $protectedHashes[$referencePath]) {
            throw "A protected CVD reference asset changed during archival: $referencePath"
        }
    }
    if (-not (Test-Path -LiteralPath $siteReference -PathType Leaf)) {
        throw "The website's canonical CVD reference CSV is missing after archival: $siteReference"
    }
}
catch {
    @($recordHeader + "status: incomplete" + "error: `"$($_.Exception.Message.Replace('"', "'"))`"") | `
        Set-Content -LiteralPath $recordPath -Encoding UTF8
    throw "Archive operation stopped before completion. Inspect $recordPath and $manifestPath. $($_.Exception.Message)"
}

@($recordHeader + "status: complete") | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Host ""
Write-Host "Archived $($manifestRows.Count) legacy files to $archiveDirectory."
Write-Host "Protected CVD monthly-reference assets were retained and re-verified."
Write-Host "Review Git changes, rebuild the download catalogue, and render the site before committing."

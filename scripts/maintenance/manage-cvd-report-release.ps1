#Requires -Version 5.1
# VERSION: 1.0.0 (28 September 2026)
<#
.SYNOPSIS
Audits or archives annual and rolling CVD reports.

.DESCRIPTION
Moves explicitly allow-listed report artefacts into a recoverable private
administrative archive. It never deletes them. Audit is the default; add
-Execute only after reviewing every proposed path.

Annual reports include the stable public package, website download and landing
pages, the accompanying public-health update, all selected private versioned
staging packages, and matching private logs.

Rolling reports include the stable public and website period folders plus
matching versioned private logs. Earlier superseded public versions exist only
in Git history because the rolling builder uses stable period folders.

.EXAMPLE
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual -Year 2025 -AllVersions `
    -PrivateRoot $privateRoot -Reason "Reset annual report testing"

.EXAMPLE
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling -Year 2024 -AllMonths -AllVersions `
    -PrivateRoot $privateRoot -Reason "Reset rolling report testing" -Execute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Annual", "Rolling")]
    [string]$ReportType,

    [Parameter(Mandatory = $true)]
    [ValidateRange(2024, 2098)]
    [int]$Year,

    [ValidateRange(1, 12)]
    [int]$Month,

    [switch]$AllMonths,

    [ValidateRange(1, 9999)]
    [int]$Version,

    [switch]$AllVersions,

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
        throw "Path is outside its approved root: $fullPath"
    }
    return $fullPath.Substring($prefix.Length)
}

function Add-ArchiveItem {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$List,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("repository", "private")]
        [string]$Scope,
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
        Scope = $Scope
        Category = $Category
    })
}

function Add-MatchingFiles {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$List,
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string[]]$Patterns,
        [Parameter(Mandatory = $true)]
        [ValidateSet("repository", "private")]
        [string]$Scope,
        [Parameter(Mandatory = $true)][string]$Category
    )
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }
    foreach ($pattern in $Patterns) {
        Get-ChildItem -LiteralPath $Directory -File -Filter $pattern -ErrorAction Stop | ForEach-Object {
            Add-ArchiveItem -List $List -Path $_.FullName -Scope $Scope -Category $Category
        }
    }
}

function Get-MetadataField {
    param(
        [Parameter(Mandatory = $true)][string]$MetadataPath,
        [Parameter(Mandatory = $true)][string]$Field
    )
    $pattern = "^{0}:\s*(.+?)\s*$" -f [regex]::Escape($Field)
    $match = Select-String -LiteralPath $MetadataPath -Pattern $pattern | Select-Object -First 1
    if ($null -eq $match) {
        throw "Metadata does not contain '$Field': $MetadataPath"
    }
    return $match.Matches[0].Groups[1].Value.Trim().Trim('"')
}

function Get-PublishedVersion {
    param(
        [Parameter(Mandatory = $true)][string]$MetadataPath,
        [Parameter(Mandatory = $true)][string]$ExpectedType,
        [Parameter(Mandatory = $true)][string]$PeriodField,
        [Parameter(Mandatory = $true)][string]$ExpectedPeriod
    )
    $actualType = Get-MetadataField -MetadataPath $MetadataPath -Field "report_type"
    $actualPeriod = Get-MetadataField -MetadataPath $MetadataPath -Field $PeriodField
    $versionText = Get-MetadataField -MetadataPath $MetadataPath -Field "report_version"
    if ($actualType -ne $ExpectedType) {
        throw "Unexpected report_type in ${MetadataPath}: $actualType"
    }
    if ($actualPeriod -ne $ExpectedPeriod) {
        throw "Unexpected $PeriodField in ${MetadataPath}: $actualPeriod"
    }
    if ($versionText -notmatch '^v([1-9][0-9]*)$') {
        throw "Invalid report_version in ${MetadataPath}: $versionText"
    }
    return [int]$Matches[1]
}

function Assert-StablePackageMetadata {
    param(
        [Parameter(Mandatory = $true)][string[]]$StablePaths,
        [Parameter(Mandatory = $true)][string]$MetadataPath
    )
    $stableArtefactExists = $false
    foreach ($path in $StablePaths) {
        if (Test-Path -LiteralPath $path) {
            $stableArtefactExists = $true
        }
    }
    if ($stableArtefactExists -and -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        throw "Stable report artefacts exist without authoritative report.yml: $MetadataPath"
    }
}

if ($ReportType -eq "Annual") {
    if ($Month -ne 0 -or $AllMonths) {
        throw "Annual reports use -Year only; do not supply -Month or -AllMonths."
    }
}
else {
    if (($Month -eq 0 -and -not $AllMonths) -or ($Month -ne 0 -and $AllMonths)) {
        throw "Rolling reports require either -Month or -AllMonths, but not both."
    }
}

if (($Version -eq 0 -and -not $AllVersions) -or ($Version -ne 0 -and $AllVersions)) {
    throw "Supply either -Version or -AllVersions, but not both."
}
if ($ReportType -eq "Rolling" -and $AllMonths -and -not $AllVersions) {
    throw "Rolling -AllMonths requires -AllVersions. Select one month to archive a specific version."
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
    throw "Report archival is blocked on branch '$branch'. Use a reviewed working branch."
}
if ($branch -eq "HEAD") {
    throw "Report archival is blocked on a detached HEAD. Switch to a named working branch."
}

$year4 = "{0:D4}" -f $Year
$logsDirectory = Join-Path $PrivateRoot "logs\private"
$archiveRoot = Join-Path $PrivateRoot "admin\report-archive"
$timestamp = Get-Date -Format "yyyyMMddTHHmmss"
$plannedRuns = New-Object System.Collections.ArrayList
$versionScope = if ($AllVersions) { "all_versions" } else { "v$Version" }

if ($ReportType -eq "Annual") {
    $items = New-Object System.Collections.ArrayList
    $publicDir = Join-Path $RepoRoot "outputs\public\reports\cvd\annual\$year4"
    $metadata = Join-Path $publicDir "report.yml"
    $siteDownloads = Join-Path $RepoRoot "site\downloads\files\reports\cvd\annual\$year4"
    $siteAnnual = Join-Path $RepoRoot "site\surveillance\cvd\reports\annual\$year4"
    $siteBriefing = Join-Path $RepoRoot "site\surveillance\cvd\reports\briefings\$year4"
    $stablePaths = @($publicDir, $siteDownloads, $siteAnnual, $siteBriefing)
    Assert-StablePackageMetadata -StablePaths $stablePaths -MetadataPath $metadata

    $publishedVersion = 0
    if (Test-Path -LiteralPath $metadata -PathType Leaf) {
        $publishedVersion = Get-PublishedVersion -MetadataPath $metadata `
            -ExpectedType "annual_cvd_report" -PeriodField "report_year" `
            -ExpectedPeriod $year4
    }

    $includeStable = $AllVersions -or ($Version -eq $publishedVersion -and $publishedVersion -ne 0)
    if ($includeStable) {
        Add-ArchiveItem -List $items -Path $publicDir -Scope repository -Category "authoritative annual report package"
        Add-ArchiveItem -List $items -Path $siteDownloads -Scope repository -Category "website annual report downloads"
        Add-ArchiveItem -List $items -Path $siteAnnual -Scope repository -Category "website annual report page"
        Add-ArchiveItem -List $items -Path $siteBriefing -Scope repository -Category "website annual public-health update"
    }
    elseif ($publishedVersion -ne 0) {
        Write-Host "Published annual report $year4 is v$publishedVersion; stable outputs are not part of requested v$Version."
    }

    $stagingRoot = Join-Path $PrivateRoot "outputs\staging\reports\cvd\annual"
    if (Test-Path -LiteralPath $stagingRoot -PathType Container) {
        if ($AllVersions) {
            Get-ChildItem -LiteralPath $stagingRoot -Directory | Where-Object {
                $_.Name -match "^bnr_cvd_annual_report_${year4}_v[1-9][0-9]*$"
            } | ForEach-Object {
                Add-ArchiveItem -List $items -Path $_.FullName -Scope private -Category "private annual report version"
            }
        }
        else {
            Add-ArchiveItem -List $items `
                -Path (Join-Path $stagingRoot "bnr_cvd_annual_report_${year4}_v$Version") `
                -Scope private -Category "private annual report version"
        }
    }

    $logVersion = if ($AllVersions) { "*" } else { "$Version" }
    Add-MatchingFiles -List $items -Directory $logsDirectory `
        -Patterns @("bnr_report_annual_*bnr_cvd_annual_report_${year4}_v${logVersion}.log") `
        -Scope private -Category "annual report workflow log"

    if ($items.Count -gt 0) {
        [void]$plannedRuns.Add([pscustomobject]@{
            ReportKey = "annual_$year4"
            Period = $year4
            VersionScope = $versionScope
            Items = $items
        })
    }
}
else {
    $months = if ($AllMonths) { 1..12 } else { @($Month) }
    foreach ($selectedMonth in $months) {
        $month2 = "{0:D2}" -f $selectedMonth
        $period = "$year4-$month2"
        $token = "${year4}_${month2}"
        $items = New-Object System.Collections.ArrayList
        $publicDir = Join-Path $RepoRoot "outputs\public\reports\cvd\updates\$period"
        $metadata = Join-Path $publicDir "report.yml"
        $siteDir = Join-Path $RepoRoot "site\surveillance\cvd\reports\updates\$period"
        $stablePaths = @($publicDir, $siteDir)
        Assert-StablePackageMetadata -StablePaths $stablePaths -MetadataPath $metadata

        $publishedVersion = 0
        if (Test-Path -LiteralPath $metadata -PathType Leaf) {
            $publishedVersion = Get-PublishedVersion -MetadataPath $metadata `
                -ExpectedType "rolling_three_month_cvd_update" `
                -PeriodField "report_period" -ExpectedPeriod $period
        }

        $includeStable = $AllVersions -or ($Version -eq $publishedVersion -and $publishedVersion -ne 0)
        if ($includeStable) {
            Add-ArchiveItem -List $items -Path $publicDir -Scope repository -Category "authoritative rolling report"
            Add-ArchiveItem -List $items -Path $siteDir -Scope repository -Category "website rolling report"
        }
        elseif ($publishedVersion -ne 0) {
            Write-Host "Published rolling report $period is v$publishedVersion; stable outputs are not part of requested v$Version."
        }

        $logVersion = if ($AllVersions) { "*" } else { "$Version" }
        Add-MatchingFiles -List $items -Directory $logsDirectory `
            -Patterns @("bnr_report_update_bnr_cvd_update_${token}_v${logVersion}.log") `
            -Scope private -Category "rolling report workflow log"

        if ($items.Count -gt 0) {
            [void]$plannedRuns.Add([pscustomobject]@{
                ReportKey = "rolling_$token"
                Period = $period
                VersionScope = $versionScope
                Items = $items
            })
        }
    }
}

if ($plannedRuns.Count -eq 0) {
    Write-Host "No report artefacts matched the requested scope. Nothing changed."
    exit 0
}

Write-Host ""
Write-Host "BNR REPORT ARCHIVE AUDIT"
Write-Host "  Mode:          $(if ($Execute) { 'EXECUTE' } else { 'AUDIT ONLY' })"
Write-Host "  Report type:   $ReportType"
Write-Host "  Year:          $year4"
Write-Host "  Version scope: $versionScope"
Write-Host "  Branch:        $branch"
Write-Host "  Commit:        $commit"
Write-Host "  Operator:      $Operator"
Write-Host "  Reason:        $Reason"
Write-Host ""

foreach ($run in $plannedRuns) {
    Write-Host "Report: $($run.Period) [$($run.VersionScope)]"
    foreach ($item in $run.Items) {
        Write-Host ("  [{0}] {1}" -f $item.Category, $item.Path)
    }
}

if (-not $Execute) {
    Write-Host ""
    Write-Host "Audit complete. No files were moved. Add -Execute after reviewing this list."
    exit 0
}

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

foreach ($run in $plannedRuns) {
    $archiveName = "${timestamp}_$($run.ReportKey)_$($run.VersionScope)"
    $runArchive = Join-Path $archiveRoot $archiveName
    if (Test-Path -LiteralPath $runArchive) {
        throw "Archive destination already exists: $runArchive"
    }
    New-Item -ItemType Directory -Path $runArchive -Force | Out-Null

    $manifestRows = New-Object System.Collections.ArrayList
    foreach ($item in $run.Items) {
        $root = if ($item.Scope -eq "repository") { $RepoRoot } else { $PrivateRoot }
        $files = if (Test-Path -LiteralPath $item.Path -PathType Container) {
            @(Get-ChildItem -LiteralPath $item.Path -File -Recurse)
        }
        else {
            @(Get-Item -LiteralPath $item.Path)
        }
        foreach ($file in $files) {
            $relativeFile = Get-RelativePathWithinRoot -Path $file.FullName -Root $root
            $destinationFile = Join-Path (Join-Path $runArchive $item.Scope) $relativeFile
            [void]$manifestRows.Add([pscustomobject]@{
                report_key = $run.ReportKey
                report_period = $run.Period
                version_scope = $run.VersionScope
                category = $item.Category
                scope = $item.Scope
                source_path = $file.FullName
                archive_path = $destinationFile
                bytes = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            })
        }
    }

    $manifestPath = Join-Path $runArchive "archive-manifest.csv"
    if ($manifestRows.Count -gt 0) {
        $manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
    }
    else {
        '"report_key","report_period","version_scope","category","scope","source_path","archive_path","bytes","sha256"' | `
            Set-Content -LiteralPath $manifestPath -Encoding UTF8
    }

    $recordPath = Join-Path $runArchive "archive.yml"
    $recordHeader = @(
        "schema: bnr_report_archive_v1",
        "report_type: $ReportType",
        "report_key: $($run.ReportKey)",
        "report_period: $($run.Period)",
        "version_scope: $($run.VersionScope)",
        "archived_at_utc: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
        "operator: `"$($Operator.Replace('"', "'"))`"",
        "reason: `"$($Reason.Replace('"', "'"))`"",
        "git_branch: $branch",
        "git_commit: $commit",
        "repository_root: `"$RepoRoot`"",
        "private_root: `"$PrivateRoot`"",
        "manifest: archive-manifest.csv",
        "file_count: $($manifestRows.Count)"
    )
    @($recordHeader + "status: in_progress") | Set-Content -LiteralPath $recordPath -Encoding UTF8

    try {
        foreach ($item in $run.Items) {
            $root = if ($item.Scope -eq "repository") { $RepoRoot } else { $PrivateRoot }
            $relativeItem = Get-RelativePathWithinRoot -Path $item.Path -Root $root
            $destination = Join-Path (Join-Path $runArchive $item.Scope) $relativeItem
            $destinationParent = Split-Path $destination -Parent
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
            Move-Item -LiteralPath $item.Path -Destination $destination
        }
    }
    catch {
        @($recordHeader + "status: incomplete" + "error: `"$($_.Exception.Message.Replace('"', "'"))`"") | `
            Set-Content -LiteralPath $recordPath -Encoding UTF8
        throw "Archive operation stopped before completion. Inspect $recordPath and $manifestPath. $($_.Exception.Message)"
    }

    @($recordHeader + "status: complete") | Set-Content -LiteralPath $recordPath -Encoding UTF8
    Write-Host "Archived $($run.ReportKey) [$($run.VersionScope)] to $runArchive ($($manifestRows.Count) files)."
}

Write-Host "Report archive operation complete. Review Git changes and render the site before committing."

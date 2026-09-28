#Requires -Version 5.1
<#
.SYNOPSIS
Audits or archives one or more monthly CVD releases.

.DESCRIPTION
This administrator utility moves explicitly allow-listed release artefacts to a
recoverable private archive. It never deletes them. The default is an audit:
add -Execute only after reviewing the proposed actions.

The utility supports CVD event and mortality releases. It refuses to archive a
release represented by the current public metadata, a January 2024 event
baseline (unless explicitly allowed), or a release used by a rolling update
(unless -IncludeRollingUpdates is supplied).

.EXAMPLE
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2024 -Month 5 `
    -Reason "Development monthly workflow test cleanup"

.EXAMPLE
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
    -Workflow Events -Year 2024 -AllMonths -IncludeRollingUpdates `
    -Reason "Completed 2024 workflow test cycle" -Execute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Events", "Mortality")]
    [string]$Workflow,

    [Parameter(Mandatory = $true)]
    [ValidateRange(2024, 2098)]
    [int]$Year,

    [ValidateRange(1, 12)]
    [int]$Month,

    [switch]$AllMonths,
    [switch]$IncludeRollingUpdates,
    [switch]$AllowBaselineArchive,

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
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$List,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet("repository", "private")][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Category
    )
    if (Test-Path -LiteralPath $Path) {
        $fullPath = Get-FullPath -Path $Path
        $alreadyAdded = $false
        foreach ($entry in $List) {
            if ($entry.Path -eq $fullPath) {
                $alreadyAdded = $true
                break
            }
        }
        if (-not $alreadyAdded) {
            [void]$List.Add([pscustomobject]@{
                Path = $fullPath
                Scope = $Scope
                Category = $Category
            })
        }
    }
}

function Add-MatchingFiles {
    param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$List,
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string[]]$Patterns,
        [Parameter(Mandatory = $true)][ValidateSet("repository", "private")][string]$Scope,
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

if (($Month -eq 0 -and -not $AllMonths) -or ($Month -ne 0 -and $AllMonths)) {
    throw "Supply either -Month or -AllMonths, but not both."
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
    throw "Release archival is blocked on branch '$branch'. Use a reviewed working branch."
}
if ($branch -eq "HEAD") {
    throw "Release archival is blocked on a detached HEAD. Switch to a named working branch."
}

$months = if ($AllMonths) { 1..12 } else { @($Month) }
$archiveRoot = Join-Path $PrivateRoot "admin\release-archive"
$timestamp = Get-Date -Format "yyyyMMddTHHmmss"
$plannedRuns = New-Object System.Collections.ArrayList
$verifiedCurrentRelease = ""
$eventBaselineVerified = $false

foreach ($selectedMonth in $months) {
    $year4 = "{0:D4}" -f $Year
    $month2 = "{0:D2}" -f $selectedMonth
    $period = "$year4-$month2"
    $compactPeriod = "$year4$month2"

    if ($Workflow -eq "Events") {
        $releaseId = "cvd_${year4}_${month2}"
        if ($Year -eq 2024 -and $selectedMonth -eq 1 -and -not $AllowBaselineArchive) {
            Write-Warning "Skipping protected event baseline $releaseId. Use -AllowBaselineArchive only after an approved alternative baseline is current."
            continue
        }
        $currentMetadata = Join-Path $RepoRoot "outputs\public\metrics\cvd\metadata\cvd_metrics_current.yml"
        $dependencyKey = "event_release_id: $releaseId"
    }
    else {
        $releaseId = "mort_${year4}_${month2}"
        $currentMetadata = Join-Path $RepoRoot "outputs\public\metrics\mortality\burden\metadata\mort_burden_metrics_current.yml"
        $dependencyKey = "mortality_release_id: $releaseId"
    }

    if (-not (Test-Path -LiteralPath $currentMetadata -PathType Leaf)) {
        throw "Current public metadata is missing, so the safe fallback cannot be established: $currentMetadata"
    }
    $currentReleaseMatch = Select-String -LiteralPath $currentMetadata -Pattern '^release_id:\s+\S+' | Select-Object -First 1
    if ($null -eq $currentReleaseMatch) {
        throw "Current public metadata does not contain a readable release_id: $currentMetadata"
    }
    $currentReleaseId = ($currentReleaseMatch.Line -replace '^release_id:\s*', '').Trim()
    $verifiedCurrentRelease = $currentReleaseId
    if ($Workflow -eq "Events" -and $AllMonths -and $currentReleaseId -ne "cvd_2024_01") {
        throw "Whole-year event cleanup requires cvd_2024_01 to be current. Republish and verify that fallback through Step 6 first. Current release: $currentReleaseId"
    }
    if ($Workflow -eq "Events" -and $AllMonths -and -not $eventBaselineVerified) {
        $baselineFiles = @(
            (Join-Path $RepoRoot "outputs\public\metrics\cvd\cvd_metrics_current.csv"),
            (Join-Path $RepoRoot "outputs\public\metrics\cvd\cvd_metrics_cvd_2024_01.csv"),
            (Join-Path $RepoRoot "site\downloads\files\metrics\cvd\cvd_metrics_current.csv"),
            (Join-Path $RepoRoot "site\downloads\files\metrics\cvd\datasets\cvd_metrics_cvd_2024_01.csv")
        )
        foreach ($baselineFile in $baselineFiles) {
            if (-not (Test-Path -LiteralPath $baselineFile -PathType Leaf)) {
                throw "January 2024 fallback verification failed because a required file is missing: $baselineFile"
            }
        }
        $baselineHashes = @($baselineFiles | ForEach-Object {
            (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash
        } | Select-Object -Unique)
        if ($baselineHashes.Count -ne 1) {
            throw "January 2024 fallback verification failed because the authoritative and website CSV copies differ. Rerun Step 6 for cvd_2024_01."
        }
        $eventBaselineVerified = $true
    }
    if ($currentReleaseId -eq $releaseId) {
        throw "$releaseId is the current public release. Publish and verify an approved fallback through Step 6 before archiving it."
    }

    $items = New-Object System.Collections.ArrayList

    if ($Workflow -eq "Events") {
        Add-ArchiveItem -List $items -Path (Join-Path $PrivateRoot "data\raw\redcap\cvd\y$year4\m$month2") -Scope private -Category "raw event release"
        Add-ArchiveItem -List $items -Path (Join-Path $PrivateRoot "data\derived\cvd\y$year4\m$month2") -Scope private -Category "derived event release"
        Add-ArchiveItem -List $items -Path (Join-Path $PrivateRoot "outputs\staging\metrics\cvd\$releaseId") -Scope private -Category "staged event release"
        Add-MatchingFiles -List $items -Directory (Join-Path $PrivateRoot "logs\private") -Patterns @("bnr_cvd*$compactPeriod*.log", "bnr_cvd*$period*.log", "bnr_cvd*$releaseId*.log") -Scope private -Category "event workflow log"

        $eventPublic = Join-Path $RepoRoot "outputs\public\metrics\cvd"
        Add-ArchiveItem -List $items -Path (Join-Path $eventPublic "cvd_metrics_$releaseId.csv") -Scope repository -Category "authoritative event dataset"
        Add-ArchiveItem -List $items -Path (Join-Path $eventPublic "cvd_metrics_$releaseId.dta") -Scope repository -Category "authoritative event dataset"
        Add-ArchiveItem -List $items -Path (Join-Path $eventPublic "metadata\cvd_metrics_$releaseId.yml") -Scope repository -Category "authoritative event metadata"
        Add-ArchiveItem -List $items -Path (Join-Path $eventPublic "releases\cvd_metrics_$releaseId.zip") -Scope repository -Category "authoritative event package"
        Add-ArchiveItem -List $items -Path (Join-Path $eventPublic "catalogue\$releaseId.yml") -Scope repository -Category "authoritative event catalogue"

        $eventSite = Join-Path $RepoRoot "site\downloads\files\metrics\cvd"
        Add-ArchiveItem -List $items -Path (Join-Path $eventSite "datasets\cvd_metrics_$releaseId.csv") -Scope repository -Category "website event dataset"
        Add-ArchiveItem -List $items -Path (Join-Path $eventSite "releases\cvd_metrics_$releaseId.zip") -Scope repository -Category "website event package"
        Add-ArchiveItem -List $items -Path (Join-Path $eventSite "catalogue\$releaseId.yml") -Scope repository -Category "website event catalogue"
    }
    else {
        Add-ArchiveItem -List $items -Path (Join-Path $PrivateRoot "data\raw\redcap\mortality\y$year4\m$month2") -Scope private -Category "raw mortality release"
        Add-ArchiveItem -List $items -Path (Join-Path $PrivateRoot "data\derived\mortality\y$year4\m$month2") -Scope private -Category "derived mortality release"
        Add-ArchiveItem -List $items -Path (Join-Path $PrivateRoot "outputs\staging\mortality\burden\$releaseId") -Scope private -Category "staged mortality release"
        Add-MatchingFiles -List $items -Directory (Join-Path $PrivateRoot "logs\private") -Patterns @("bnr_mort*$compactPeriod*.log", "bnr_mort*$releaseId*.log") -Scope private -Category "mortality workflow log"

        $mortPublic = Join-Path $RepoRoot "outputs\public\metrics\mortality\burden"
        foreach ($extension in @("csv", "dta")) {
            Add-ArchiveItem -List $items -Path (Join-Path $mortPublic "datasets\mort_burden_metrics_$releaseId.$extension") -Scope repository -Category "authoritative mortality dataset"
        }
        Add-ArchiveItem -List $items -Path (Join-Path $mortPublic "metadata\mort_burden_metrics_$releaseId.yml") -Scope repository -Category "authoritative mortality metadata"
        Add-ArchiveItem -List $items -Path (Join-Path $mortPublic "bnr_mort_burden_$releaseId.zip") -Scope repository -Category "authoritative mortality package"
        Add-ArchiveItem -List $items -Path (Join-Path $mortPublic "catalogue\$releaseId.yml") -Scope repository -Category "authoritative mortality catalogue"

        $mortSite = Join-Path $RepoRoot "site\downloads\files\metrics\mortality\burden"
        foreach ($extension in @("csv", "dta")) {
            Add-ArchiveItem -List $items -Path (Join-Path $mortSite "datasets\mort_burden_metrics_$releaseId.$extension") -Scope repository -Category "website mortality dataset"
        }
        Add-ArchiveItem -List $items -Path (Join-Path $mortSite "metadata\mort_burden_metrics_$releaseId.yml") -Scope repository -Category "website mortality metadata"
        Add-ArchiveItem -List $items -Path (Join-Path $mortSite "bnr_mort_burden_$releaseId.zip") -Scope repository -Category "website mortality package"
        Add-ArchiveItem -List $items -Path (Join-Path $mortSite "catalogue\$releaseId.yml") -Scope repository -Category "website mortality catalogue"
    }

    $dependentReports = New-Object System.Collections.ArrayList
    foreach ($reportsRoot in @(
        (Join-Path $RepoRoot "outputs\public\reports\cvd\updates"),
        (Join-Path $RepoRoot "site\surveillance\cvd\reports\updates")
    )) {
        if (Test-Path -LiteralPath $reportsRoot -PathType Container) {
            Get-ChildItem -LiteralPath $reportsRoot -Filter "report.yml" -File -Recurse | ForEach-Object {
                if (Select-String -LiteralPath $_.FullName -SimpleMatch $dependencyKey -Quiet) {
                    $reportDirectory = $_.Directory.FullName
                    if (-not $dependentReports.Contains($reportDirectory)) {
                        [void]$dependentReports.Add($reportDirectory)
                    }
                }
            }
        }
    }

    # A release can also be cited by an annual report, dashboard or another
    # surveillance page. Known rolling-update folders can be archived together;
    # any other reference needs a separate human decision and therefore blocks.
    $dependentPeriods = @($dependentReports | ForEach-Object { Split-Path $_ -Leaf } | Select-Object -Unique)
    $otherReferences = New-Object System.Collections.ArrayList
    foreach ($referenceRoot in @(
        (Join-Path $RepoRoot "outputs\public\reports"),
        (Join-Path $RepoRoot "site\surveillance")
    )) {
        if (-not (Test-Path -LiteralPath $referenceRoot -PathType Container)) {
            continue
        }
        Get-ChildItem -LiteralPath $referenceRoot -File -Recurse | Where-Object {
            $_.Extension -in @(".qmd", ".yml", ".yaml", ".json", ".md")
        } | ForEach-Object {
            if (Select-String -LiteralPath $_.FullName -SimpleMatch $releaseId -Quiet) {
                $knownRollingReference = $false
                foreach ($dependentPeriod in $dependentPeriods) {
                    $publicUpdate = Get-FullPath -Path (Join-Path $RepoRoot "outputs\public\reports\cvd\updates\$dependentPeriod")
                    $siteUpdate = Get-FullPath -Path (Join-Path $RepoRoot "site\surveillance\cvd\reports\updates\$dependentPeriod")
                    $candidate = Get-FullPath -Path $_.FullName
                    if ($candidate.StartsWith($publicUpdate + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
                        $candidate.StartsWith($siteUpdate + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $knownRollingReference = $true
                        break
                    }
                }
                if (-not $knownRollingReference) {
                    [void]$otherReferences.Add($_.FullName)
                }
            }
        }
    }
    if ($otherReferences.Count -gt 0) {
        throw "$releaseId has references outside its rolling-update package: $($otherReferences -join '; '). Review those dependencies before archiving."
    }

    if ($dependentReports.Count -gt 0 -and -not $IncludeRollingUpdates) {
        $locations = $dependentReports -join "; "
        throw "$releaseId is used by one or more rolling updates: $locations. Review them and rerun with -IncludeRollingUpdates only if those reports must also be archived."
    }
    if ($IncludeRollingUpdates) {
        foreach ($reportDirectory in $dependentReports) {
            $reportPeriod = Split-Path $reportDirectory -Leaf
            Add-ArchiveItem -List $items -Path (Join-Path $RepoRoot "outputs\public\reports\cvd\updates\$reportPeriod") -Scope repository -Category "dependent rolling update"
            Add-ArchiveItem -List $items -Path (Join-Path $RepoRoot "site\surveillance\cvd\reports\updates\$reportPeriod") -Scope repository -Category "dependent rolling update"
            $reportToken = $reportPeriod.Replace("-", "_")
            Add-MatchingFiles -List $items -Directory (Join-Path $PrivateRoot "logs\private") -Patterns @("bnr_report_update_bnr_cvd_update_${reportToken}_v*.log") -Scope private -Category "rolling update log"
        }
    }

    if ($items.Count -eq 0) {
        Write-Warning "No allow-listed artefacts found for $releaseId."
        continue
    }

    [void]$plannedRuns.Add([pscustomobject]@{
        ReleaseId = $releaseId
        Period = $period
        Items = $items
    })
}

if ($plannedRuns.Count -eq 0) {
    Write-Host "No release artefacts are eligible for archival. Nothing changed."
    exit 0
}

Write-Host ""
Write-Host "BNR MONTHLY RELEASE ARCHIVE AUDIT"
Write-Host "  Mode:       $(if ($Execute) { 'EXECUTE' } else { 'AUDIT ONLY' })"
Write-Host "  Workflow:   $Workflow"
Write-Host "  Branch:     $branch"
Write-Host "  Commit:     $commit"
Write-Host "  Current:    $verifiedCurrentRelease"
Write-Host "  Operator:   $Operator"
Write-Host "  Reason:     $Reason"
Write-Host ""

foreach ($run in $plannedRuns) {
    Write-Host "Release: $($run.ReleaseId)"
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
    $archiveName = "${timestamp}_$($Workflow.ToLower())_$($run.ReleaseId)"
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
                release_id = $run.ReleaseId
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
    $manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

    $recordPath = Join-Path $runArchive "archive.yml"
    $recordHeader = @(
        "schema: bnr_release_archive_v1",
        "workflow: $Workflow",
        "release_id: $($run.ReleaseId)",
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
        @($recordHeader + "status: incomplete" + "error: `"$($_.Exception.Message.Replace('"', "'"))`"") | Set-Content -LiteralPath $recordPath -Encoding UTF8
        throw "Archive operation stopped before completion. Inspect $recordPath and $manifestPath. $($_.Exception.Message)"
    }

    @($recordHeader + "status: complete") | Set-Content -LiteralPath $recordPath -Encoding UTF8
    Write-Host "Archived $($run.ReleaseId) to $runArchive ($($manifestRows.Count) files)."
}

Write-Host "Archive operation complete. Review Git changes and render the site before committing."

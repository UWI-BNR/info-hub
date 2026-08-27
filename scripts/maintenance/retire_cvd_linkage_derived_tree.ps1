[CmdletBinding()]
param(
    [string]$PrivateRoot = "",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# This script removes the retired tree from data/derived by moving it to a
# recoverable archive outside data/derived. It never deletes private data.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($PrivateRoot)) {
    $PrivateRoot = Join-Path (Split-Path $repoRoot -Parent) "info-hub-private"
}

$retiredRoot = Join-Path $PrivateRoot "data\derived\cvd_linkage"
$archiveRoot = Join-Path $PrivateRoot "data\archive\cvd_linkage_retired_20260827"
$sourceRoots = @(
    (Join-Path $repoRoot "scripts"),
    (Join-Path $repoRoot "site"),
    (Join-Path $repoRoot "docs")
)

if (-not (Test-Path -LiteralPath $retiredRoot -PathType Container)) {
    throw "Retired private derived tree was not found: $retiredRoot"
}

if (Test-Path -LiteralPath $archiveRoot) {
    throw "Archive destination already exists: $archiveRoot"
}

$liveReferences = @()
foreach ($sourceRoot in $sourceRoots) {
    if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
        $liveReferences += Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Include *.do,*.dlg,*.sthlp,*.qmd,*.md,*.py,*.js,*.yml,*.yaml |
            Where-Object {
                $_.FullName -ne $PSCommandPath -and
                $_.FullName -notmatch '[\\/]docs[\\/]cvd-hardening-retired-files[\\/]'
            } |
            Select-String -SimpleMatch '$BNR_PRIVATE/data/derived/cvd_linkage' -ErrorAction Stop
    }
}

if ($liveReferences.Count -gt 0) {
    $liveReferences | ForEach-Object { Write-Host "Live retired-path reference: $($_.Path):$($_.LineNumber)" }
    throw "Retired tree was not moved because live source references remain."
}

if (-not $Apply) {
    Write-Host "Dry run: no private data was moved."
    Write-Host "Retired tree: $retiredRoot"
    Write-Host "Archive destination: $archiveRoot"
    Write-Host "Rerun with -Apply to move the tree outside data/derived."
    exit 0
}

New-Item -ItemType Directory -Path (Split-Path $archiveRoot -Parent) -Force | Out-Null
Move-Item -LiteralPath $retiredRoot -Destination $archiveRoot
Write-Host "Moved retired private tree to: $archiveRoot"
Write-Host "Only data/derived/cvd/ remains as the active private CVD-derived location."

[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# These are generated records from the legacy burden-only publication tree.
# A record is eligible only where the current publisher has created an exact
# same-release replacement in outputs/public/metrics/cvd/catalogue.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$legacyFolder = Join-Path $repoRoot "outputs\public\metrics\cvd\releases"
$catalogueFolder = Join-Path $repoRoot "outputs\public\metrics\cvd\catalogue"
$legacyPublicCatalogue = Join-Path $repoRoot "outputs\public\metrics\cvd\burden\catalogue"
$legacySiteCatalogue = Join-Path $repoRoot "site\downloads\files\metrics\cvd\burden\catalogue"

$removable = @()

$legacyRoots = @($legacyFolder, $legacyPublicCatalogue, $legacySiteCatalogue)
foreach ($legacyRoot in $legacyRoots) {
    if (Test-Path -LiteralPath $legacyRoot -PathType Container) {
        Get-ChildItem -LiteralPath $legacyRoot -Filter "cvd_????_??.yml" -File | ForEach-Object {
            $replacement = Join-Path $catalogueFolder $_.Name
            if (Test-Path -LiteralPath $replacement -PathType Leaf) {
                $removable += $_
            }
            else {
                Write-Host "Retained legacy record without current replacement: $($_.FullName)"
            }
        }
    }
}

if ($removable.Count -eq 0) {
    Write-Host "No superseded legacy CVD catalogue records were found."
    exit 0
}

if (-not $Apply) {
    Write-Host "Dry run: the following superseded public catalogue records would be removed:"
    $removable | ForEach-Object { Write-Host "  $($_.FullName)" }
    Write-Host "No files were removed. Rerun with -Apply after Step 6 and catalogue checks pass."
    exit 0
}

$removable | Remove-Item -Force
Write-Host "Removed $($removable.Count) superseded public catalogue record(s)."

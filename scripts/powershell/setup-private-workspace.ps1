<#
.SYNOPSIS
Creates the standard empty BNR private workspace outside Git.
.DESCRIPTION
Run from a VS Code PowerShell terminal. Requires no additional modules and
works with Windows PowerShell 5.1 or PowerShell 7. Existing files and folders
are preserved. No data, tokens, settings, approvals or public outputs are
created. Missing retained inputs are reported, not fabricated.
.EXAMPLE
.\scripts\powershell\setup-private-workspace.ps1 -PrivateRoot "C:\BNR\info-hub-private" -WhatIf
.EXAMPLE
.\scripts\powershell\setup-private-workspace.ps1 -PrivateRoot "C:\BNR\info-hub-private"
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PrivateRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    # Keep this helper in scripts/powershell so its repository is unambiguous.
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'scripts/stata/config/bnr_paths_TEMPLATE.do') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $repoRoot 'site/_quarto.yml') -PathType Leaf)) {
        throw 'Run the helper from its original scripts/powershell location in a complete info-hub repository.'
    }

    if (-not [IO.Path]::IsPathRooted($PrivateRoot) -or $PrivateRoot -match '^[A-Za-z]:[^\\/]') {
        throw 'PrivateRoot must be a full absolute folder path, for example C:\BNR\info-hub-private.'
    }
    $privatePath = [IO.Path]::GetFullPath($PrivateRoot)
    $separator = [IO.Path]::DirectorySeparatorChar
    $repoBoundary = $repoRoot.TrimEnd([char[]]'\/') + $separator
    $privateBoundary = $privatePath.TrimEnd([char[]]'\/') + $separator
    $comparison = [StringComparison]::OrdinalIgnoreCase
    if ($privateBoundary.StartsWith($repoBoundary, $comparison) -or
        $repoBoundary.StartsWith($privateBoundary, $comparison)) {
        throw 'The private workspace must be separate from the public repository, not inside it or a parent of it.'
    }

    # Reject redirects and Git workspaces before creating anything. Junctions
    # or symbolic links can otherwise defeat a simple text comparison of paths.
    function Test-PrivateLocation {
        param([string]$Path)
        $cursor = $Path
        while ($cursor) {
            if (Test-Path -LiteralPath $cursor) {
                $item = Get-Item -LiteralPath $cursor -Force
                if (-not $item.PSIsContainer) {
                    throw "A file occupies a required folder location: $cursor"
                }
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "A folder is a junction or symbolic link: $cursor. Choose a direct private folder path."
                }
                if (Test-Path -LiteralPath (Join-Path $cursor '.git')) {
                    throw "The selected location is inside a Git workspace: $cursor"
                }
            }
            $parent = [IO.Directory]::GetParent($cursor)
            if ($null -eq $parent) { break }
            $cursor = $parent.FullName
        }
    }

    # Only stable workspace folders are provisioned here. Analytical workflows
    # remain responsible for dated extracts, packages, reviews and report folders.
    $relativeFolders = @(
        'data'
        'data/raw'
        'data/raw/redcap'
        'data/raw/redcap/cvd'
        'data/raw/redcap/mortality'
        'data/frozen'
        'data/frozen/releases'
        'data/frozen/releases/y2023'
        'data/frozen/releases/y2023/m12'
        'data/derived'
        'data/derived/cvd'
        'data/derived/mortality'
        'data/reference'
        'data/reference/population'
        'outputs'
        'outputs/staging'
        'logs'
        'logs/private'
        'work'
    )
    $folderPaths = @($privatePath)
    foreach ($relativeFolder in $relativeFolders) {
        $folderPaths += Join-Path $privatePath $relativeFolder
    }
    foreach ($folderPath in $folderPaths) { Test-PrivateLocation -Path $folderPath }

    $created = 0
    $existing = 0
    $skipped = 0
    foreach ($folderPath in $folderPaths) {
        if (Test-Path -LiteralPath $folderPath -PathType Container) {
            $existing++
        }
        elseif ($PSCmdlet.ShouldProcess($folderPath, 'Create empty private folder')) {
            [void][IO.Directory]::CreateDirectory($folderPath)
            $created++
            Write-Host "CREATED: $folderPath"
        }
        else { $skipped++ }
    }

    Write-Host ''
    Write-Host "Private root: $privatePath"
    Write-Host "Folders created: $created; already present: $existing; skipped: $skipped"
    if ($WhatIfPreference) {
        Write-Host 'PREVIEW ONLY: no folders or files were changed.'
    }
    elseif ($skipped -gt 0) {
        Write-Host 'Folder setup is incomplete: some folder creations were declined.'
    }
    else {
        Write-Host 'FOLDER SETUP COMPLETE. This does not mean the analytical inputs are ready.'
    }

    Write-Host ''
    Write-Host 'Retained input checks (file presence only; contents are not read):'
    $retainedInputs = @(
        'data/frozen/releases/y2023/m12/bnr-cvd-indiv-full-202312-v02.dta'
        'data/reference/population/wpp2024_brb_population_2010_2035_5y.dta'
        'data/reference/population/who_world_standard_2000_2025.dta'
    )
    $missing = 0
    foreach ($relativeInput in $retainedInputs) {
        $inputPath = Join-Path $privatePath $relativeInput
        if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
            Write-Host "PRESENT: $relativeInput"
        }
        else {
            $missing++
            Write-Host "MISSING: $relativeInput"
        }
    }
    Write-Host "Missing retained inputs: $missing. Presence is not validation of the data."
    Write-Host 'Restore missing retained files through the approved secure-storage process.'
    Write-Host 'For fresh extracts, configure the relevant REDCap token file in Stage 4.'
    Write-Host 'No tokens were checked or created. Existing contents and permissions were not changed.'
    Write-Host 'Next: Technical Manual > Set up a workstation > Stages 3 and 4.'
    if ($skipped -gt 0 -and -not $WhatIfPreference) { exit 1 }
}
catch {
    Write-Error "Private workspace setup stopped: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

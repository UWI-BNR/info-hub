#requires -Version 5.1
<#
BNR Python setup/repair. The BAT launcher is the normal entry point.
Uses the repository's Python 3.13 venv, never an activated/global Python.
Does not edit LOCAL.do, read token files, run Stata or access REDCap.
#>
[CmdletBinding()]
param(
    [string]$ProfilePath,
    [switch]$EnvironmentOnly,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'

function Invoke-BnrPython {
    param([string]$Executable, [string[]]$PythonArguments)
    & $Executable @PythonArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed (exit $LASTEXITCODE). Read the output above."
    }
}

try {
    if ($CheckOnly -and $EnvironmentOnly) {
        throw 'Choose -CheckOnly or -EnvironmentOnly, not both.'
    }
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $venvRoot = Join-Path $repoRoot 'venv-info-hub'
    $pythonExe = Join-Path $venvRoot 'Scripts/python.exe'
    $requirements = Join-Path $repoRoot 'requirements.txt'
    $checker = Join-Path $repoRoot 'scripts/python/check-python-environment.py'
    $profileHelper = Join-Path $repoRoot 'scripts/python/configure-bnr-stata-profile.py'
    foreach ($requiredFile in @($requirements, $checker, $profileHelper)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            throw "Required repository file is missing: $requiredFile"
        }
    }
    Write-Host 'BNR Python setup'
    Write-Host "Repository: $repoRoot"
    Write-Host "Python:     $pythonExe"

    if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        if ($CheckOnly) { throw 'BNR venv is missing. Run setup-bnr-python.bat first.' }
        if (Test-Path -LiteralPath $venvRoot) {
            throw 'venv-info-hub exists but has no Windows Python executable. Rebuild this environment; do not copy a venv from another machine.'
        }
        if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
            throw 'Python launcher not found. Complete workstation setup Stage 1, then reopen this launcher.'
        }
        Write-Host 'Creating the BNR Python 3.13 virtual environment...'
        Invoke-BnrPython -Executable 'py.exe' -PythonArguments @('-3.13', '-m', 'venv', $venvRoot)
    }

    # Detect copied, wrong-version or base-Python environments before installing.
    $identityCheck = "import os,sys; expected=sys.argv[1]; ok=sys.version_info[:2]==(3,13) and sys.prefix!=sys.base_prefix and os.path.normcase(os.path.realpath(sys.prefix))==os.path.normcase(os.path.realpath(expected)); print('Python:',sys.version.split()[0]); print('Executable:',sys.executable); print('Environment:',sys.prefix); sys.exit(0 if ok else 1)"
    Invoke-BnrPython -Executable $pythonExe -PythonArguments @('-c', $identityCheck, $venvRoot)
    if (-not $CheckOnly) {
        Write-Host 'Installing the maintained BNR requirements (this may take several minutes)...'
        Invoke-BnrPython -Executable $pythonExe -PythonArguments @('-m', 'pip', 'install', '-r', $requirements)
    }
    Invoke-BnrPython -Executable $pythonExe -PythonArguments @($checker)
    Invoke-BnrPython -Executable $pythonExe -PythonArguments @('-m', 'pip', 'check')

    if ($CheckOnly -or $EnvironmentOnly) {
        Write-Host 'BNR PYTHON ENVIRONMENT PASSED. Stata profile was not changed.'
        exit 0
    }

    # Check the LOCAL file without changing it. The operator pastes one global.
    Invoke-BnrPython -Executable $pythonExe -PythonArguments @($profileHelper, '--repo', $repoRoot, '--check-local')

    if (-not $ProfilePath) {
        Write-Host 'Select profile.do from the PERSONAL directory reported by Stata sysdir.'
        Write-Host 'For a new workstation, navigate to that directory and enter profile.do.'
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = 'Select the Stata startup profile (existing or new)'
        $dialog.Filter = 'Stata startup profile (profile.do)|profile.do'
        $dialog.FileName = 'profile.do'
        $dialog.OverwritePrompt = $false
        $dialog.CheckPathExists = $true
        try {
            if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                throw 'Profile selection cancelled. The Python environment is ready; the profile was not changed.'
            }
            $ProfilePath = $dialog.FileName
        }
        finally { $dialog.Dispose() }
    }
    Invoke-BnrPython -Executable $pythonExe -PythonArguments @($profileHelper, '--repo', $repoRoot, '--profile', $ProfilePath)
    Write-Host ''
    Write-Host 'BNR PYTHON SETUP COMPLETED.'
    Write-Host 'Close Stata completely and reopen it. Run: python query'
    Write-Host 'The executable must be inside this repository: venv-info-hub/Scripts/python.exe'
    Write-Host 'Then run the PyCap check and workflow tests in workstation setup Stage 6.'
}
catch {
    Write-Error "BNR Python setup stopped: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

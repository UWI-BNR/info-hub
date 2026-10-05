# BNR Python setup helper

Use this when setting up or repairing the BNR Python environment. The everyday
website launcher is `start-bnr-info-hub-edit.bat`; it does not perform setup.

## Before you start

- Install base Python 3.13 through workstation setup Stage 1.
- Keep `setup-bnr-python.bat` in the BNR repository root.
- Configure `scripts/stata/config/bnr_paths_LOCAL.do` through Stage 4.
- In Stata, run `sysdir` and note the PERSONAL directory containing `profile.do`.
- Close Stata before updating its profile; restart it afterwards.

For an existing LOCAL file, add this under **Derived public-repository folders**:

```stata
global BNR_PYTHON_EXE "$BNR_REPO/venv-info-hub/Scripts/python.exe"
```

Replace any earlier definition of that global. Keep your existing public/private
roots and token-file settings. Updating the tracked template does not update
LOCAL.do. The helper checks the global but never changes the LOCAL file.

## Run it

1. Double-click `setup-bnr-python.bat` in the BNR repository root.
2. Wait while it creates or checks `venv-info-hub`, installs the maintained
   requirements and checks package imports and dependency compatibility.
3. Select the existing `profile.do` in the Stata PERSONAL directory. For a new
   profile, navigate to that directory and enter `profile.do` as the filename.
4. Look for `BNR PYTHON SETUP COMPLETED`, then press a key to close the window.
5. Restart Stata and follow workstation setup Stage 6's Python and menu checks.

There is no Python path to type. The helper derives it from its own repository.
The launcher uses a process-only PowerShell execution-policy override; it does
not change your persistent execution policy or require environment activation.

## What it changes

| File or folder | Change |
|---|---|
| `venv-info-hub/` | Creates the environment if absent; installs packages from the existing `requirements.txt`. It does not recreate an existing environment or install into base Python. |
| Selected personal `profile.do` | Updates the BNR configuration-file path and selects `$BNR_PYTHON_EXE` for embedded Stata Python. Adds the BNR menu only if its standard load command is missing. Existing SHG and other entries are retained. |
| `profile.bnr_backup_YYYYMMDD_HHMMSS_microseconds.bak` | Original profile backup beside the selected profile, created before a change. Repeated runs with an unchanged profile create no extra backup. |

No LOCAL file, requirement list, frozen requirements, token file, private data,
analytical DO file, public output, Git branch or website deployment is changed.
The helper does not run Stata or connect to REDCap. Package versions may change
within the existing supported ranges when required to satisfy the requirements.

## Command alternatives

In a **VS Code PowerShell terminal** at the repository root:

```powershell
# Build/check Python only; leave the profile alone (fresh setup Stage 5).
.\setup-bnr-python.bat -EnvironmentOnly

# Check the existing venv without installing anything or changing the profile.
.\setup-bnr-python.bat -CheckOnly

# Choose the profile explicitly instead of using the file chooser.
# Substitute the PERSONAL path reported by Stata sysdir.
.\setup-bnr-python.bat -ProfilePath "C:\your\Stata\PERSONAL\profile.do"
```

The BAT launcher calls `scripts/powershell/setup-bnr-python.ps1`. The PowerShell
helper calls the existing environment checker and the standard-library helper
`scripts/python/configure-bnr-stata-profile.py` for the profile update.

## If it stops

- **Python launcher/version missing:** complete Stage 1 and reopen the launcher.
- **Wrong, copied or incomplete venv:** rebuild it locally using Python 3.13;
  do not copy a venv between computers. The helper will not delete it for you.
- **Package installation/import/conflict failure:** resolve the reported error
  before configuring the Stata profile. See the Technical Manual troubleshooting page.
- **Missing BNR_PYTHON_EXE:** paste the single line above into LOCAL.do and rerun.
- **Wrong BNR_REPO:** correct the existing LOCAL.do repo root and rerun.
- **Profile cancelled:** the environment remains ready; the profile is unchanged.
- **Ambiguous or unusual profile syntax:** the updater stops without replacing
  the profile. It supports ordinary `do` and `python set exec` commands, including
  `///` continuation lines. Conditional blocks, nonstandard delimiters, multiple
  Python settings or Python execution during startup require manual review.

To undo a profile change, close Stata, copy the named backup over `profile.do`,
and restart Stata. This restores the original profile; it does not roll back
package installation. Keep the backup outside Git.

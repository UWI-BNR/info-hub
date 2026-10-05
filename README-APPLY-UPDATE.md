# Apply the BNR Python handling update

Prepared from `UWI-BNR/info-hub`, branch `info-hub-review2`, commit
`8d05d02c151603db53d0967ddad56dbbdc44cf80` on 5 October 2026.

This delivery note is for applying the ZIP; it does not need to be committed.
The enduring setup procedure is in the updated workstation setup page.

## On the main coding machine

1. Check the current branch and any uncommitted changes. Apply this update to
   your intended development branch. Extract the ZIP into the **BNR repo root**,
   retaining the relative folders and replacing only its included files. If
   you have edited a supplied source file since the commit above, compare it
   before overwriting it.
2. Remove the old daily launcher `start-info-hub-edit.bat`. Its replacement is
   `start-bnr-info-hub-edit.bat`; its daily editing behaviour is retained. Update
   any personal shortcut to the new name. The new `setup-bnr-python.bat` is a
   separate one-time setup/repair launcher. Git should show the launcher rename.
3. In **your existing** `scripts/stata/config/bnr_paths_LOCAL.do`, add this under
   **Derived public-repository folders**, replacing an earlier definition if present:

   ```stata
   global BNR_PYTHON_EXE "$BNR_REPO/venv-info-hub/Scripts/python.exe"
   ```

   Keep your current repo/private roots and both token-file paths. Do not copy
   the template over a working LOCAL file. The helper never edits LOCAL.do.
4. In Stata, run `sysdir` and note the PERSONAL directory holding the existing
   `profile.do`. Close Stata completely.
5. Double-click `setup-bnr-python.bat` from the **BNR repo root**. Let the Python
   environment checks complete. Select that existing personal `profile.do`
   when the file chooser opens. The original is backed up beside it.
6. Look for `BNR PYTHON SETUP COMPLETED`. Restart Stata and run:

   ```stata
   display "$BNR_PYTHON_EXE"
   python query

   python:
   from redcap import Project
   print("BNR Python / PyCap check passed")
   end
   ```

   Both displayed Python paths must identify the BNR repo's
   `venv-info-hub/Scripts/python.exe`. Both project menus should still be present.
7. Test a normal authorised CVD event extract and mortality extract, respecting
   existing-output safeguards. Then run the usual SHG preview in the same
   session. Inspect the updated setup/troubleshooting pages and run a complete
   Quarto render. These Windows/Stata/live-workflow checks remain your acceptance test.
8. Review the Git changes, commit only the intended tracked files, push the
   development branch and merge through the normal pull request. Pull updated
   `main` on the coding machine afterwards. Do not commit LOCAL.do, the personal
   profile, venv or profile backups.

To remove the retired launcher through Git, use **VS Code Explorer** to delete
it and stage the deletion in Source Control. The command alternative, in a
VS Code PowerShell terminal at the repo root, is:

```powershell
git rm -- start-info-hub-edit.bat
```

The replacement is already included in this ZIP. Do not rename it again.

## On the travel machine

Clone updated `main`. Install base Python 3.13 if needed, restore/configure the
authorised private workspace and LOCAL paths, and follow workstation setup
Stages 5–6. Rebuild the venv locally; do not copy the coding machine's venv or
personal profile. Configure the SHG venv separately using its own setup.

## Verification already completed

- Twelve Python profile-migration tests: supplied profile preservation, SHG
  entries, repeat runs, continued commands, comments, backups, Unicode/BOM,
  new profiles and refusal of ambiguous startup commands.
- Five orchestration tests executed in PowerShell 7.4 on Linux with package
  operations mocked: environment-only/check-only modes, profile selection by
  argument, missing LOCAL configuration and dependency failure before profile writes.
- PowerShell parser check; Python compilation; documentation structure and
  changed-link checks; bounded comparison of the delivered files.

The Windows file chooser, Windows PowerShell 5.1 execution, actual Python 3.13
package installation, Stata startup, REDCap extracts and Quarto rendering have
not been run here. The helper uses Windows PowerShell 5.1-compatible syntax and
the existing package requirements, but the main-machine acceptance checks above
must complete before merging.

Only the configuration template is changed among Stata DO files. Analytical
workflows, SHG source and both requirements files are unchanged. Documentation
updates outside setup/troubleshooting are limited to the launcher rename and
the new setup-entry description.

## Files supplied

- New root launchers: `start-bnr-info-hub-edit.bat`, `setup-bnr-python.bat`.
- New setup helper and guide: `scripts/powershell/setup-bnr-python.ps1` and `.md`.
- New standard-library profile updater: `scripts/python/configure-bnr-stata-profile.py`.
- Updated configuration template: `scripts/stata/config/bnr_paths_TEMPLATE.do`.
- Updated workstation setup, troubleshooting, reference entry and all located
  current documentation references to the renamed daily launcher.

To undo a profile change, close Stata, copy its named backup over `profile.do`
and restart Stata. Package installation is separate and is not rolled back by
restoring the profile.

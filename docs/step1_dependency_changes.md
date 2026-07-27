# BNR Step 1 refactor: dependency changes

**Date:** 27 July 2026  
**Scope:** Rename and simplify the Step 1 controller and its directly associated interface and documentation files.  
**Behavioural rule:** Preserve Step 1 inputs, private locations, generated data-product names, validation rules and outputs.

## Files renamed

| Previous repository file | Revised repository file |
|---|---|
| `scripts/stata/monthly/bnr_cvd_redcap_extract.do` | `scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do` |
| `scripts/stata/dialogs/bnr_cvd_redcap_extract.dlg` | `scripts/stata/dialogs/bnr_step1_cvd_redcap_extract.dlg` |
| `scripts/stata/dialogs/bnr_cvd_redcap_extract.sthlp` | `scripts/stata/dialogs/bnr_step1_cvd_redcap_extract.sthlp` |

Adjust the dialog/help folder above if the repository currently stores these files elsewhere. Do not move files merely to satisfy this note.

## Files updated but not renamed

| File | Required change |
|---|---|
| `bnr_menu.do` | Change the Step 1 dialog command to `db bnr_step1_cvd_redcap_extract`. |
| `bnr-monthly-cvd-run-guide.qmd` | Update Step 1 command and dialog references. This guide covers all workflow steps and retains its workflow-wide name. |
| `bnr_paths_LOCAL.do` | No content or path change. Retained only as the local configuration dependency. |

## Generated outputs deliberately unchanged

The following names and all `info-hub-private` locations remain unchanged:

- `bnr_cvd_redcap_raw_YYYYMM.csv`
- `bnr_cvd_redcap_raw_YYYYMM.dta`
- `bnr_cvd_redcap_raw_YYYYMM_manifest.yml`
- `bnr_cvd_redcap_raw_YYYYMM.log`
- `$BNR_DATA_RAW/redcap/cvd/yYYYY/mMM/`
- `$BNR_PRIVATE_LOGS/`

These are stable data-product names, not executable workflow filenames.

## Direct dependencies confirmed in the supplied files

| File | Previous reference | Revised reference |
|---|---|---|
| Step 1 dialog | `help bnr_cvd_redcap_extract` | `help bnr_step1_cvd_redcap_extract` |
| Step 1 dialog | `$BNR_STATA/monthly/bnr_cvd_redcap_extract.do` | `$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do` |
| Step 1 help | `db bnr_cvd_redcap_extract` | `db bnr_step1_cvd_redcap_extract` |
| Step 1 help | `$BNR_STATA/monthly/bnr_cvd_redcap_extract.do` | `$BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do` |
| BNR menu | `db bnr_cvd_redcap_extract` | `db bnr_step1_cvd_redcap_extract` |
| Monthly run guide | Step 1 DO and dialog references | Revised Step 1 names |

## Targeted repository searches still required

Cursor should search the repository for the exact old identifiers below. This is a targeted dependency check, not a full repository audit.

```text
bnr_cvd_redcap_extract.do
bnr_cvd_redcap_extract.dlg
bnr_cvd_redcap_extract.sthlp
bnr_cvd_redcap_extract
help bnr_cvd_redcap_extract
db bnr_cvd_redcap_extract
```

Review matches in:

- `profile.do` and installation files;
- README, QMD, Markdown and technical documentation;
- Stata test or wrapper files;
- Quarto/MkDocs navigation and download pages;
- comments that provide runnable commands;
- GitHub workflow or packaging scripts.

Do not change historical logs, archived releases or generated output files merely because they contain an old command, unless those files are intended as current operating documentation.

## Verification after implementation

1. Confirm no active-code or current-documentation reference to `bnr_cvd_redcap_extract` remains.
2. Start a fresh Stata session and confirm the menu opens the renamed dialog.
3. Confirm `help bnr_step1_cvd_redcap_extract` opens the renamed help file.
4. Run a test without `replace` against an existing month and confirm Step 1 stops safely.
5. Run an authorised test release and compare CSV, DTA and YAML structure with the behavioural reference.
6. Confirm any dataset open before Step 1 remains open and unchanged afterward.
7. Confirm all outputs still use the existing `info-hub-private` locations and original generated filenames.

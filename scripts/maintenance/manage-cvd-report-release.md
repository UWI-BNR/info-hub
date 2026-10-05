# Archive annual and rolling CVD reports

Use `manage-cvd-report-release.ps1` to move annual or rolling CVD report
artefacts into a recoverable private administrative archive. The utility does
not delete files and does not alter the underlying event or mortality metric
releases.

The default mode is an audit. Add `-Execute` only after checking every listed
path.

## Where to run it

Open PowerShell in the `info-hub` repository root on a working branch. The
utility refuses to run on `main`, `master` or a detached commit.

Set the private root if `BNR_PRIVATE` is not already a Windows environment
variable:

```powershell
$privateRoot = "C:\yoshimi-hot\output\analyse-bnr\info-hub-private"
```

## Archive an annual report and every version

Audit the 2025 annual report:

```powershell
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual `
    -Year 2025 `
    -AllVersions `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Reset annual report before rebuilding v1"
```

After reviewing the audit, repeat the command with `-Execute`:

```powershell
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual `
    -Year 2025 `
    -AllVersions `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Reset annual report before rebuilding v1" `
    -Execute
```

This archives:

- the authoritative annual report folder;
- website report downloads and metadata;
- the annual report landing page;
- the accompanying public-health update landing page;
- every matching private versioned candidate and approved package; and
- matching private Steps 1–3 logs.

The year-specific interpretation, Focus On, contents specification and shared
reporting code remain in place so the report can be rebuilt.

## Archive one annual-report version

Use `-Version` instead of `-AllVersions`:

```powershell
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Annual `
    -Year 2025 `
    -Version 2 `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Withdraw superseded annual report candidate v2"
```

If that version is the version currently represented by the stable public
files, those files are included. If another version is currently published,
only the selected private package and matching logs are included.

## Archive all rolling reports in a year

Audit every rolling report period found in 2024:

```powershell
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling `
    -Year 2024 `
    -AllMonths `
    -AllVersions `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Reset 2024 rolling reports before selected rebuild"
```

Repeat with `-Execute` after reviewing the output.

Months without matching report artefacts are ignored. Each report month is
written to a separate recoverable archive.

## Archive one rolling report and every version

```powershell
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling `
    -Year 2025 `
    -Month 3 `
    -AllVersions `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Reset March 2025 rolling report"
```

## Archive one rolling-report version

```powershell
.\scripts\maintenance\manage-cvd-report-release.ps1 `
    -ReportType Rolling `
    -Year 2025 `
    -Month 3 `
    -Version 2 `
    -PrivateRoot $privateRoot `
    -Operator "Ian Hambleton" `
    -Reason "Withdraw superseded March 2025 rolling report v2"
```

Rolling reports use stable public period folders. A higher version overwrites
those working-tree files; superseded public versions remain in Git history,
not as separate public folders. The utility archives stable public files only
when the selected version matches `report.yml`, or when `-AllVersions` is used.
It also archives every matching private log available for the requested scope.

## Archive contents

Completed archives are written beneath:

```text
$BNR_PRIVATE/admin/report-archive/
```

Each archive contains:

- `archive.yml`, recording the report, version scope, operator, reason, branch
  and commit;
- `archive-manifest.csv`, with original and archive paths, byte lengths and
  SHA-256 hashes;
- `repository/`, preserving paths formerly under the Git repository; and
- `private/`, preserving paths formerly under `$BNR_PRIVATE`.

An interrupted move is marked `status: incomplete`.

## After execution

1. Review `git status` and confirm that only the intended reports were removed.
2. Stop any running Quarto preview.
3. Run a complete `quarto render` from `site/`.
4. Restart `start-bnr-info-hub-edit.bat`.
5. Check News, annual-report listings, rolling-update listings and direct URLs.
6. Confirm that the retained event and mortality downloads remain available.
7. Commit only the intended repository changes.

## Rebuilding v1

After `-AllVersions` has archived the complete working-tree and private package
history for a report period, the normal builder can create v1 again. This is a
development reset. It does not erase earlier versions from Git history or from
the recoverable administrative archive.


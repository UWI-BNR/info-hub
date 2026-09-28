# Archive a monthly CVD release

Use `manage-cvd-monthly-release.ps1` to move selected CVD event or mortality
release artefacts from their working locations into the recoverable private
administrative archive.

The utility archives files; it does not delete them. It preserves their folder
structure and writes an administrative record plus a SHA-256 file manifest.

## Where to run it

Open PowerShell in the `info-hub` repository root on a working branch. The
utility refuses to run on `main`, `master` or a detached Git commit.

Set the private root for the session if `BNR_PRIVATE` is not a Windows
environment variable:

```powershell
$privateRoot = "C:\yoshimi-hot\output\analyse-bnr\info-hub-private"
```

Every example below is an audit unless `-Execute` is present. Always run the
audit first and inspect every path before executing it.

## Archive one event month

Audit May 2024 and include its dependent rolling update:

```powershell
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
  -Workflow Events `
  -Year 2024 `
  -Month 5 `
  -IncludeRollingUpdates `
  -PrivateRoot $privateRoot `
  -Operator "Ian Hambleton" `
  -Reason "Remove May 2024 after completed workflow testing"
```

After reviewing the audit, repeat it with `-Execute`:

```powershell
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
  -Workflow Events `
  -Year 2024 `
  -Month 5 `
  -IncludeRollingUpdates `
  -PrivateRoot $privateRoot `
  -Operator "Ian Hambleton" `
  -Reason "Remove May 2024 after completed workflow testing" `
  -Execute
```

## Archive the remaining months in a year

After May has been archived, audit the complete 2024 year:

```powershell
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
  -Workflow Events `
  -Year 2024 `
  -AllMonths `
  -IncludeRollingUpdates `
  -PrivateRoot $privateRoot `
  -Operator "Ian Hambleton" `
  -Reason "Archive remaining 2024 releases after workflow testing"
```

The utility reports May as absent and continues with the remaining eligible
months. It also skips the current release if the current release falls within
the selected year. After checking the complete audit, repeat it with
`-Execute`.

The same command can be used for 2025 or 2026 by changing `-Year`.

## Archive mortality releases

Use the same interface with `-Workflow Mortality`:

```powershell
.\scripts\maintenance\manage-cvd-monthly-release.ps1 `
  -Workflow Mortality `
  -Year 2025 `
  -AllMonths `
  -IncludeRollingUpdates `
  -PrivateRoot $privateRoot `
  -Operator "Ian Hambleton" `
  -Reason "Archive completed 2025 mortality workflow tests"
```

Only include `-IncludeRollingUpdates` when rolling reports that use the selected
release should also be archived.

## What gets skipped or blocked

For a single-month request, the utility stops if:

- the selected release is current;
- a rolling update depends on it and `-IncludeRollingUpdates` was omitted;
- an annual report, dashboard or another surveillance product refers to it;
- the current metadata cannot be read safely; or
- the repository or private root is unsafe.

For `-AllMonths`, the utility checks months 1 to 12 and continues after warning
about:

- the current release;
- a month already archived or not present;
- a rolling-report dependency not authorised for inclusion; or
- another protected report or surveillance dependency.

No particular year or January release receives special protection. The safety
rule is based on the actual current release and actual dependencies.

Rendered product contracts are detected through Quarto and machine-readable
metadata files. Plain Markdown implementation and handoff notes are not treated
as live release dependencies.

To archive a release that is currently represented by the stable `current`
files, first publish and verify a different approved release through the normal
Step 6 process. Do not edit the current files or metadata by hand.

## Archive contents

Completed archives are written beneath:

```text
$BNR_PRIVATE/admin/release-archive/
```

Each release archive contains:

- `archive.yml`, recording the release, operator, reason, Git branch and commit;
- `archive-manifest.csv`, recording every source and archive path, byte length
  and SHA-256 hash;
- `repository/`, preserving paths formerly under the Git repository; and
- `private/`, preserving paths formerly under `$BNR_PRIVATE`.

An interrupted move is marked `status: incomplete` in `archive.yml`.

## After execution

1. Review `git status` and confirm that only the intended public-safe files
   were removed from their working locations.
2. Stop any running Quarto preview.
3. Run a complete `quarto render` from `site/`.
4. Restart `start-info-hub-edit.bat` so newly removed report routes and listings
   are fully refreshed.
5. Check dashboards, tables, Downloads, News and report listings.
6. Commit only the intended repository changes.

## Restoration

Restoration is a controlled administrative action. Use `archive.yml` and
`archive-manifest.csv` to identify and verify the archived files. Restore the
appropriate private inputs, then repeat the normal review, approval and Step 6
publication pathway. Do not copy archived files directly into public locations
as a substitute for controlled publication.

# BNR Reporting Workflow Contract

**Status:** Approved implementation contract  
**Date:** 2 September 2026

This document fixes the operating boundary for the redesigned BNR reporting
products. It is an implementation contract, not a replacement for the
Operations, Technical or Public Methods Manuals.

## Purpose

Provide a small, durable reporting architecture that a Stata-skilled BNR team
can maintain without recreating the retired briefings workflow.

## Product model

| Product | Purpose | Primary production method | Public form |
|---|---|---|---|
| Rolling three-month CVD surveillance update | Objective update from approved public event and mortality metrics | Observable JS in Quarto | Dated HTML page |
| Annual CVD report | Repeatable standard surveillance report plus an annual Focus On chapter | Stata and `putpdf` | PDF plus HTML landing page |
| One-off analytical report | Bespoke analytical product | Usually Stata; final method may vary | PDF plus HTML landing page |

The rolling update is issued monthly and covers a rolling three-month period;
it is not a calendar-quarter report.

## Core rules

1. **Stata computes.** Core surveillance measures and the annual report are
   produced in readable Stata code.
2. **Observable presents the rolling update.** It consumes only approved public
   event and mortality data.
3. **Freeze dated-update inputs.** Every dated update stores and loads complete,
   exact snapshots of both declared release-stamped public CSVs. It never loads
   a `*_current.csv` file or a later-mutated website release copy.
4. **Simple update arithmetic is permitted.** The approved template may combine
   compatible published, non-suppressed values, including a three-month sum.
   It must not reconstruct suppressed values or use an unapproved formula.
5. **Human judgement remains required.** Annual and one-off reports require
   analytical, disclosure and dissemination review before publication.
6. **Quarto indexes reports.** Landing pages provide searchable metadata and
   access to PDF reports. Quarto does not reproduce annual or one-off report
   content in HTML.
7. **Git preserves superseded versions.** Each release has one rendered public
   report. A correction replaces that working-tree instance with a new version;
   the superseded version remains recoverable in Git history only.
8. **Do not create a generic one-off analysis workflow.** Shared code covers
   release mechanics, not bespoke analytical methods.

## Public data contract for rolling updates

Event Step 6 and mortality Step 6 publish release-stamped browser-readable
CSVs under both the authoritative public tree and `site/downloads/`. The update
builder first verifies those two copies agree, then freezes the complete
authoritative CSVs as `data/event_release.csv` and
`data/mortality_release.csv` inside the dated report package. Observable reads
only those local snapshots. This deliberately leaves the template free to use
any approved rows needed by a later design, including a year-to-date design.

The single design source is
`scripts/stata/reporting/templates/bnr_report_update_template.qmd`. Generated
dated pages are instances, not templates, and must not be copied forward to
create the next report.

The template must use public display values and disclosure status. If a required
component is missing, suppressed, incomplete or incompatible with the declared
definition, the corresponding derived display is unavailable or explicitly
flagged. It is never inferred.

## Report identity and versioning

Machine identifiers are lowercase with underscores:

```text
bnr_cvd_update_2026_04_v1
bnr_cvd_annual_report_2025_v1
```

Public report locations remain stable by report period:

```text
site/surveillance/cvd/reports/updates/2026-04/index.qmd
site/surveillance/cvd/reports/annual/2025/index.qmd
site/surveillance/cvd/reports/studies/{study-id}/index.qmd
```

Only the current version for a period is rendered and listed. The page metadata,
PDF title page, publication metadata and manifest must agree on the report
version.

For the one-step rolling update, an existing period may be superseded only by a
strictly higher version with the explicit `replace` argument. A published
version number is never reused. For annual and one-off reports, `replace` may
also recover the exact same approved version after an interrupted publication;
it may never downgrade an existing public version. Existing public files
without complete, consistent authoritative metadata stop publication.

## Annual-report structure

The annual report uses a small Stata composition model:

```text
bnr_report_annual_s1_build.do
    -> bnr_report_annual_standard.do
    -> include year-specific interpretation file
    -> include year-specific Focus On module
```

The interpretation file contains analyst-written local text macros. It is
included by the master DO file so the macros remain in the master scope. The
Focus On module is analyst-owned and may differ each year, while retaining the
common report style.

For each new year, the analyst creates both files at the following fixed paths;
the Step 1 dialog and failure message state this requirement explicitly:

```text
scripts/stata/reporting/annual/YYYY/bnr_report_annual_YYYY_interpretation.do
scripts/stata/reporting/annual/YYYY/bnr_report_annual_YYYY_focus.do
```

The annual builder creates exactly three private candidate files under
`$BNR_STAGING/reports/cvd/annual/<report-id>/candidate/`: the versioned PDF,
`index.qmd` and `report.yml`. `$BNR_STAGING` is the configured private staging
root; no report staging files belong under the public repository's
`outputs/staging/` tree.

Step 2 copies those exact three files into the package's `public_ready/`
directory, writes `public_manifest.csv`, and writes `approval.yml` last. The
receipt is a workflow-control record beside the approved payload, not a log.
Step 3 reads only `public_ready/`; it never publishes from `candidate/`.

Published filenames are stable per reporting period. The authoritative annual
package is held under `$BNR_PUBLIC/reports/cvd/annual/<year>/` and is mirrored
to the matching website PDF and landing-page locations. A higher version
replaces the stable working-tree files; Git retains the superseded version.

## One-off report publication

The one-off workflow begins with a finished PDF. It does not run or attempt to
standardise the bespoke analysis that produced that PDF. The three publication
steps prepare a private candidate, approve an exact manifested payload and
publish that payload using the same shared controls as the annual report.

Private packages are held under
`$BNR_STAGING/reports/cvd/studies/<report-id>/`. Authoritative published files
are held under `$BNR_PUBLIC/reports/cvd/studies/<study-id>/` and mirrored to
the corresponding website PDF and landing-page locations. The public filename
is stable for each study ID; corrections require a higher approved version.

The disclosure screen accepts a private Stata dataset containing `output_id`,
`cell_id` and numeric `cell_count`. It flags counts from zero to five, missing,
negative or non-integer counts and duplicate cell identifiers. It neither
changes the source dataset nor assesses secondary suppression. Its output is
review evidence only; human disclosure review remains required.

## Naming and menu rules

All new reporting infrastructure begins `bnr_report_`, including DO, dialog,
help and test files. Fixed analyst sequences use the mortality-style `_s1_`,
`_s2_`, `_s3_` filename grammar. Shared helpers and tests are not menu steps.

The two repeatable builders may have menu entries:

```text
User > BNR
    Rolling three-month CVD update
        Build dated online update
    Annual CVD report
        Step 1: Build annual report candidate
        Step 2: Approve annual report candidate
        Step 3: Publish approved annual report
    One-off CVD report publication
        Step 1: Prepare one-off report candidate
        Step 2: Approve one-off report candidate
        Step 3: Publish approved one-off report
    Report utilities
        Screen report counts for disclosure review
```

Shared approval, publication, metadata validation and disclosure-review helpers
are reporting utilities. One-off reports use those utilities but have no generic
analysis launcher.

## Simplicity guardrails

- No report-type dispatcher for bespoke analyses.
- No duplicate annual and one-off publishers.
- No narrative snippet hierarchy.
- No automatic Git commits or pushes.
- No manual correction of generated files.
- No new helper unless it is genuinely shared or materially reduces the annual
  report's complexity.

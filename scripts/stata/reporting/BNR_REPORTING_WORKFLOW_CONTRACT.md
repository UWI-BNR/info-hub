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
3. **No moving source files in dated updates.** Every dated update records and
   loads exact release-stamped public CSVs, never a `*_current.csv` file.
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
CSVs under `site/downloads/`. A rolling update declares both source release
identifiers and source paths in its page metadata.

The template must use public display values and disclosure status. If a required
component is missing, suppressed, incomplete or incompatible with the declared
definition, the corresponding derived display is unavailable or explicitly
flagged. It is never inferred.

## Report identity and versioning

Machine identifiers are lowercase with underscores:

```text
cvd_update_2026_04_v1
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

## Annual-report structure

The annual report uses a small Stata composition model:

```text
bnr_report_annual_build.do
    -> bnr_report_annual_standard.do
    -> include year-specific interpretation file
    -> include year-specific Focus On module
```

The interpretation file contains analyst-written local text macros. It is
included by the master DO file so the macros remain in the master scope. The
Focus On module is analyst-owned and may differ each year, while retaining the
common report style.

The annual builder creates a non-public candidate PDF and landing-page source
under `outputs/staging/reports/.../<report-id>/candidate/`. Its explicit
approval receipt is written to the same package's `public_ready/approval.yml`,
binding both candidate files by checksum. Only the annual publisher may then
promote the verified PDF to `outputs/public/` and copy the PDF and landing-page
source to the website locations.

## Naming and menu rules

All new reporting infrastructure begins `bnr_report_`, including DO, dialog,
help and test files. Use step numbers only for a true fixed sequence.

The two repeatable builders may have menu entries:

```text
User > BNR
    Rolling three-month CVD update
        Build dated online update
    Annual CVD report
        Step 1: Build annual report candidate
        Step 2: Approve annual report candidate
        Step 3: Publish approved annual report
    Report utilities
        Validate report assets and metadata
        Create disclosure-review report
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

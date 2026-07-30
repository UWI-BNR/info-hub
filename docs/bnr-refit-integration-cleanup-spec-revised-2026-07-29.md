# BNR Refit Phase 2: Revised Integration and Clean-up Specification

**Status:** Read-only audit and proposed work order  
**Audit date:** 29 July 2026  
**Evidence reviewed:** corrected `refit-release-workflow` snapshot; `tree-outputs.txt`; `tree-site-download-files.txt`; approved `cvd_burden_metrics_current.csv`; current metadata YAML; project guiderails and handover note.

## Correction to the earlier audit

The earlier specification was based on the wrong ZIP. Its main assertion that the branch lacked the working Steps 1–6 system was incorrect.

The corrected branch snapshot contains the tested Step 1–6 controllers, dialogs, help files, menu, Step 4/5 helpers, current monthly run guide, Step 6 controller, and narrow `.gitignore` exceptions for the approved public burden `.dta` files. The output tree also confirms the published `cvd_2024_01` release and the stable `current` files in both authoritative public output and the website mirror.

The `.gitignore` change therefore needs no further work in this clean-up phase. The real integration task is to refit the dashboard and catalogue to the deliberate 2024-01+ public data contract, then remove superseded development copies and retired controllers.

## Settled architecture

```text
Private source data
  -> Step 1 extract
  -> Step 2 confidential cumulative dataset
  -> Step 3 de-identified metric inputs
  -> Step 4 private staging package
  -> Step 5 review and approval
  -> Step 6 authoritative outputs/public
  -> Step 6 site/downloads/files mirror
  -> Quarto site
```

`outputs/public/` is authoritative. `site/downloads/files/` is a disposable mirror. Quarto reads approved aggregate outputs only; it must not calculate, infer, or reconstruct results.

## The 2024-01+ CVD burden public contract

The new structure is intentional. The dashboard should not be made compatible with the old 2023-12 dataset.

| Topic | Contract for `cvd_2024_01` and later |
|---|---|
| Stable input | `cvd_burden_metrics_current.csv` |
| Release identifier | Read from `release_id` (currently `cvd_2024_01`) |
| Monthly results | `CVD-BURDEN-001`, `monthly_count` and `monthly_same_month_previous_5yr_mean`, **all CVD only** |
| Quarterly results | `CVD-BURDEN-001`, all CVD, AMI and stroke; count and same-quarter five-year comparator |
| Annual results | Counts/comparators plus `CVD-BURDEN-002` sex and event-type distributions |
| Age groups | Not a public dimension in this product; there is no `age_group` or `age_group_order` field |
| Completeness | Use `period_complete`; incomplete periods should be omitted from the public chart/table rather than interpreted as final |
| Suppression | `suppression_status != none` means the numeric fields are intentionally unavailable. Display `display_value` (normally `*`) and never calculate from other rows. |
| Release ZIP | `bnr_cvd_burden_<release_id>.zip` (currently `bnr_cvd_burden_cvd_2024_01.zip`) |

The supplied current file has 2,349 rows and explicitly records 26 suppressed rows. It includes no age groups. For the incomplete 2024 annual period, several distribution rows are suppressed as primary or derived values.

## Why the current dashboard fails

The dashboard correctly reads the stable current CSV, but its code still implements the old data interface.

1. It filters count rows using `d.age_group === "all"`. That field is absent in the new CSV, so this produces no rows.
2. Its CVD-BURDEN-002 view expects `age_group_distribution` and an `age_group_order`. The new product has instead `sex_distribution` and `event_type_distribution` only.
3. Its time control offers only monthly and annual. It therefore has no route to the new quarterly AMI/stroke data.
4. The event selector allows AMI/stroke while the default view is monthly; these combinations contain no valid rows by design.
5. Its public data table still exposes an Age group column and prints `value`, rather than using `display_value` with an explicit suppression label.
6. The ZIP download remains hard-coded to `cvd_2023_12`.

This is a dashboard refit, not a Stata metric defect or a Step 6 path problem.

## Required dashboard redesign

Keep this as one bespoke CVD burden dashboard, but simplify its controls around combinations that the public release can actually support.

### 1. Use compatible views only

Replace the independent event-type and monthly/annual controls with a single **Reporting frequency** control:

| Frequency | Available event types | Statistic pair |
|---|---|---|
| Monthly | All CVD only | `monthly_count`; `monthly_same_month_previous_5yr_mean` |
| Quarterly | All CVD, AMI, stroke | `quarterly_count`; `quarterly_same_quarter_previous_5yr_mean` |
| Annual | All CVD, AMI, stroke | `annual_count`; `annual_previous_5yr_mean` |

The event selector should then be populated from the selected frequency, defaulting to `all_cvd`. This removes invalid controls rather than showing an empty chart.

### 2. Rebuild the count view against the new fields

- Remove every `age_group` and `age_group_order` condition.
- Keep all/female/male rows only where the selected statistic and event type provide them.
- Use `period_start` (or `period_year` plus `period_quarter`) for a chronological axis and label quarters clearly, for example `Q1 2024`.
- Exclude rows where `period_complete != 1` from charts, headline cards and downloadable data-table values. A short note should say that incomplete periods are not shown.
- Exclude numeric suppressed rows from plots and headline cards. Do not turn missing values into zero.

### 3. Replace the old age-distribution view

For `CVD-BURDEN-002`, show annual composition only:

- **Sex distribution:** female and male shares for the selected event type.
- **Event-type distribution:** AMI and stroke shares for all CVD.

Do not create an age composition chart or retain an age-group selector. For a suppressed row, show `*` with a plain disclosure-control note; do not show its numerator, denominator or a calculated percentage.

The simplest public-facing option is to show this composition section only for complete, displayable annual years. If all rows in the selected year are suppressed, show a short “not shown because disclosure control applies” message rather than an empty chart.

### 4. Make the data/download tab safe and release-aware

- Remove the **Age group** column.
- Add **Completeness** and **Disclosure control** columns.
- Render `display_value`, never raw `value`, `numerator` or `denominator` for suppressed rows.
- Derive the ZIP URL from the loaded `release_id`, rather than hard-coding a release name.
- Retain direct links to stable current CSV and DTA files.

The dashboard may read the release ID from the first row because `current` is a single approved release. It should fail visibly with a simple “current public dataset is empty or malformed” message if no release ID is present.

### Dashboard acceptance test

- `current` CSV loads with no browser-console error.
- Monthly all-CVD, quarterly all-CVD, quarterly AMI/stroke, and annual all-CVD/AMI/stroke each offer only valid controls.
- The incomplete 2024 quarter/annual period is not plotted as final.
- Suppressed values appear only as `*` and cannot be reconstructed from the dashboard.
- Current CSV, current DTA, and `bnr_cvd_burden_<release_id>.zip` download successfully.

## Downloads catalogue

The site-download tree shows that the metric package already contains `downloads.yml`. The existing catalogue builder scans briefing packages only, so the simplest durable fix is to extend that one builder to scan both:

```text
downloads/files/briefings/*/downloads.yml
downloads/files/metrics/*/*/downloads.yml
```

Normalise both input types into the existing catalogue row structure. Do not add a second catalogue or use the private Step 5 manifest as public catalogue input. This is a small, one-file Python change with no new dependency.

Until that change is complete, add one explicit “Current CVD burden indicators” card to the Downloads page, pointing to the dashboard and the current ZIP. This keeps the release discoverable without hand-maintaining a second data index.

## Documentation changes

| Priority | Location | Required change |
|---|---|---|
| High | `README.md` | Replace the outdated statement that approval/promotion is not complete. List the six active steps and state that Step 5 approves and Step 6 promotes. Clarify that private staging is outside the repository. |
| High | `docs/bnr-refit-operations-handover.md` | Replace the proposed combined `bnr_approve_publish.do` command with the actual Step 5 and Step 6 separation. Use the current roles: BNR Lead, BNR Analyst and BNR Developer. |
| High | `scripts/stata/README.qmd` | Rebuild the active table around Steps 1–6 and their helpers. Move retired publisher/controller entries into a short historical-reproduction section. |
| High | `site/operations/post-redcap/monthly/bnr-monthly-cvd-run-guide.qmd` | Keep as the one active monthly Operations Manual route. It is already the correct detailed guide; correct only any remaining old filenames in examples or logs. |
| Medium | `site/operations/data/sap-metrics.qmd` | Describe the new suppression-aware public contract: no public age groups; monthly all-CVD only; AMI/stroke quarterly; `period_complete`, `display_value` and `suppression_status` are mandatory consumer fields. |
| Medium | `site/technical/` reference/how-to pages | Label briefing-specific publication documents as **Historical 2023 briefing pathway**. Add one short current publication-contract page rather than rewriting every historical page. |
| Low | `DECISIONS.md` and `CHANGELOG.md` | Do not maintain large development registers. Replace their active guidance with a concise architecture note, or archive them after transferring any still-useful material to the project guiderails and Operations Manual. |

## Legacy and clean-up decisions

Delete only in a dedicated final clean-up commit, after the dashboard and documentation changes have been checked. Git history remains the recovery route.

### Safe to delete: superseded development copies

These have no active navigation or current-controller dependency.

```text
site/surveillance/cvd/metrics/index copy.qmd
site/operations/post-redcap/monthly/bnr-monthly-cvd-run-guide_pre*.qmd
scripts/stata/config/bnr_paths_LOCAL_pre*.do
scripts/stata/menu/bnr_menu_pre*.do
scripts/stata/metrics/cvd/metric_cvd_burden_pre.do
```

### Retire with the former Step 1–5 pathway

These are older controllers/helpers and their interfaces. The active menu uses only `bnr_step1_*` through `bnr_step6_*`; the current controllers do not call these older files.

```text
scripts/stata/monthly/bnr_cvd_prepare_confidential.do
scripts/stata/monthly/bnr_cvd_create_metric_inputs.do
scripts/stata/monthly/bnr_cvd_metric_controller.do
scripts/stata/monthly/bnr_cvd_review_controller.do
scripts/stata/dialogs/bnr_cvd_prepare_confidential.dlg
scripts/stata/dialogs/bnr_cvd_create_metric_inputs.dlg
scripts/stata/dialogs/bnr_cvd_metric_controller.dlg
scripts/stata/dialogs/bnr_cvd_review_controller.dlg
scripts/stata/help/bnr_cvd_prepare_confidential.sthlp
scripts/stata/help/bnr_cvd_create_metric_inputs.sthlp
scripts/stata/help/bnr_cvd_metric_controller.sthlp
scripts/stata/help/bnr_cvd_review_controller.sthlp
scripts/stata/common/bnr_stage_metric.do
scripts/stata/common/bnr_apply_suppression.do
scripts/stata/common/bnr_publish_metric.do
```

Before deletion, update or remove the transition notes in `docs/` that name these files. If you prefer a visible historical record rather than Git-only recovery, move them together to `docs/holding-bay/retired-monthly-workflow/`; do not leave them alongside live code.

### Retain as historical 2023 reproduction code

These still support the published 2023 briefing and annual products. Label them historical; do not run them for monthly releases.

```text
scripts/stata/briefings/
scripts/stata/annual/
scripts/stata/refit/
scripts/stata/common/bnrcvd_prep_2023_v1.do
scripts/stata/common/bnr_publish_briefing.do
scripts/stata/common/mirror_public_to_site.do
site/surveillance/cvd/briefings/
site/downloads/annual/
```

### Remove empty or misleading repository scaffolding

Remove only if tracked or intentionally created; Git does not preserve genuinely empty directories.

```text
outputs/staging/              # private staging belongs outside the repository
local/                        # machine-local and ignored
site/slides/                  # empty
site/technical/how-to/run-static-briefing_files/mediabag/  # empty generated residue
recycle-rescue/
recovered-current-homepage.html
docs/setup/
setup-checks/                 # retain the script only if it is actually part of onboarding
```

Keep `outputs/public/` and `site/downloads/files/`: they are empty only in the reduced audit archive, not in the working branch.

## Recommended commit order

1. `fix: refit CVD burden dashboard to 2024+ public contract`
2. `fix: list current metric packages in downloads catalogue`
3. `docs: distinguish current monthly workflow from historical 2023 pathway`
4. `chore: retire superseded controllers and development copies`

Render and check the site after commits 1–3. Commit 4 is the only deletion commit.

## Scope boundary

This audit specifies the changes; it does not alter Stata calculation logic, approval rules, public data values, output files, or the website source. The next implementation task should be the dashboard refit as one contained change, tested locally against the approved current CSV.

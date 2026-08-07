# BNR Stata Dependency Audit — Documentary Reconciliation

**Branch:** `briefing-workflow-completion`  
**Audit date:** 7 August 2026  
**Scope:** Supplied Stata source snapshot, tracked-file inventory, repository-wide Stata reference audit, fresh Git status, and the requested repository documentation.  
**Repository changes made:** None.

## Final position

The fresh Git status resolves the earlier repository-state ambiguity. The three tracked files under `scripts/stata/briefings/cvd_cases_2023/` are not deleted; their absence from the supplied Stata ZIP was a packaging mismatch.

The dependency universe is therefore **49 `.do` and `.ado` files**, classified as follows:

| Classification | Files |
|---|---:|
| Active operational code | 26 |
| Validation or migration evidence to retain | 6 |
| Direct retirement candidates | 10 |
| Coupled historical or archive decisions | 7 |
| **Total** | **49** |

No code has been deleted or moved.

## Case-count folder decision

The current briefing menu dispatches only:

- CVD incidence;
- CVD case-fatality; and
- CVD length of stay.

It does not dispatch a case-count briefing. This agrees with the current product decision that counts are covered by dashboards rather than retained as an operational briefing.

| File | Final classification | Reason | Recommended treatment |
|---|---|---|---|
| `briefings/cvd_cases_2023/cvd_cases_2023.do` | Historical v1 pathway | Calls `bnrcvd_prep_2023_v1.do` and the old combined `bnr_publish_briefing.do` | Move to the tracked holding bay with its old preparation/publication dependencies |
| `briefings/cvd_cases_2023/cvd_cases_2023_v2.do` | Migration evidence | Uses the re-engineered Step 3 input and active staging helper, but has no current menu entry | Retain as a frozen migration example, outside the live briefing tree |
| `briefings/cvd_cases_2023/cvd_cases_2023_v2_equivalence_check.do` | Validation evidence | One-time equivalence test for the v2 conversion | Retain with the v2 example in a validation/archive area |

The v2 files should not be described as current operations, but they are useful evidence of the accepted migration and should not be deleted.

## Documentation reconciliation

All six requested repository pages are materially out of date. They should be corrected before retiring the old commands.

| File | Main issue | Required direction |
|---|---|---|
| `README.md` | Says the separate approval/promotion command is not implemented; uses old approval roles | Describe the implemented workflow and use `BNR Lead`, `BNR Analyst`, and `BNR Developer` |
| `site/operations/post-redcap/occasional-briefings.md` | Instructs users to run `bnr_approve_publish_briefing.do` and the abandoned `bnr_prepare_briefing_review.do` review-profile experiment | Replace with Briefing Steps 1–3 and remove the private-review-profile pathway |
| `site/technical/how-to/run-static-briefing.qmd` | Describes the v1 case-count pilot, direct writing to `outputs/public`, and manual mirroring | Rewrite around the current three migrated briefings and the staged approval/publish flow |
| `site/technical/troubleshooting/missing-output-files.qmd` | Assumes the old v1 case-count bundle and recommends rerunning the obsolete DO file/manual copy | Diagnose current staging, approval, manifest, public package, and mirror stages separately |
| `site/technical/troubleshooting/stata-path-errors.qmd` | Treats the frozen 2023 source and v1 case-count script as current examples | Use current Step 3 inputs and current workflow controllers as examples |
| `site/technical/reference/compute-layer-stata.qmd` | Describes the old one-file static/publication model and `bnrcvd_prep_2023_v1.do` as active shared preparation | Document metrics, briefing and tables controllers plus active shared helpers; keep Quarto as a thin publish layer |

Two broader development documents are also stale:

- the project guiderails still name only `Registry Lead or Registry Statistician` at the approval gate;
- the operations/handover framework still proposes an unimplemented generic `bnr_approve_publish.do` command and old roles.

These should be reconciled to the implemented roles and product-specific Step 2/Step 3 promotion pattern before handover.

## Revised retirement groups

### Batch A — superseded monthly workflow

Move these together with their matching legacy dialogs and help files:

- `monthly/bnr_cvd_redcap_extract_pre.do`
- `monthly/bnr_cvd_prepare_confidential.do`
- `monthly/bnr_cvd_create_metric_inputs.do`
- `monthly/bnr_cvd_metric_controller.do`
- `monthly/bnr_cvd_review_controller.do`
- `common/bnr_stage_metric.do`
- `common/bnr_apply_suppression.do`

Their replacements are already dispatched by `menu/bnr_menu.do`.

### Batch B — superseded briefing entry points

After the operations and technical pages are corrected:

- `common/bnr_approve_publish_briefing.do`
- `help/bnr_approve_publish_briefing.sthlp`
- `briefings/cvd_case_fatality/cvd_case_fatality_pre1.do`

### Batch C — historical 2023 unit

Move as one archive/holding-bay decision, not as isolated deletions:

- `briefings/cvd_cases_2023/cvd_cases_2023.do`
- `annual/build_cvd_annual_tabulations.do`
- `common/bnrcvd_prep_2023_v1.do`

The v2 case-count build and equivalence test should remain nearby as clearly labelled migration/validation evidence, but not in the operational briefing directory.

### Batch D — historical forensics unit

Retain together or archive together:

- `refit/bnrcvd_2023_forensics2.do`
- `common/bnr_publish_briefing.do`
- `common/mirror_public_to_site.do`

`refit/bnrcvd-2023-forensics1.do` should also move out of the operational code tree into the holding bay. `common/bnr_publish_metric.do` is a separate strong retirement candidate with no current executable caller.

## Render safety

Moving Stata code does not itself alter Quarto rendering, but the cleanup must still protect documentary links and public artefact paths. The safe order is:

1. Update the stale operational and technical pages.
2. Search again for every Batch A and Batch B filename.
3. Move Batch A to a tracked holding bay in one reversible commit.
4. Run the current Metrics Steps 1–6, Briefing Steps 1–3, and Tables Steps 1–3 entry-point checks.
5. Run a full Quarto render and inspect briefing figures, downloads and internal links.
6. Commit Batch B separately after the same checks.
7. Decide and move the historical 2023 and forensics units in later commits.
8. Consider permanent deletion only after a period of successful operation.

## Further evidence needed

No further upload is needed to complete the classification. Before executing the cleanup, the current `scripts/stata/README.qmd` should be revised alongside the six pages above, because it still documents the superseded controllers and publishers as active. The supplied Stata ZIP already contains that file and the legacy dialog/help pairs needed to prepare the cleanup batch.


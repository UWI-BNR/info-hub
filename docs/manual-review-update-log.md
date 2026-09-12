# BNR manuals review and update log

## Control information

- Working branch: `cvd-workflow-hardening`
- Authoritative pre-update freeze: `1342bec77908de1ebac46d4ee59942cda5c5f5c7`
- Baseline recovery commit for every deletion:
  `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb`
- Primary scope: `site/methods/`, `site/operations/`, `site/technical/`
- Date started: 6 September 2026
- No review change has been committed or pushed.

Git history is the recovery mechanism. No backup copies of deleted or replaced
pages are retained in the repository.

## Agreed terminology and policy decisions

- Standing roles are **BNR Lead**, **BNR Analyst** and **BNR Developer**.
  Reviewer, approver and publisher are action labels, not additional standing
  role names.
- The BNR small-number rule is **n < 6**; positive counts 1–5 receive primary
  suppression. Complementary protection and human disclosure review remain
  necessary.
- The former tabulations and briefings workflows are retired.
- Public tables, dashboards and downloads reuse approved event and mortality
  metric releases; they are not separate analytical workflows.
- The rolling three-month update is one controlled build from approved
  releases. Annual and one-off reports use separate three-step controlled
  routes.
- CVD event and mortality releases retain separate six-step workflows.
- Stata computes and controls analytical publication; Quarto presents approved
  public outputs; GitHub deploys the static site.
- Review, disclosure review, approval, analytical publication and website
  deployment remain separate actions.
- Generated outputs are corrected through source data or version-controlled
  code and rerun, never by manual editing.
- The unsupported Data Trust construct and the unimplemented repository/DOI
  route are not presented as current process. A future DOI process requires its
  own later implementation and documentation.
- Pre-REDCap and REDCap pages remain visible for BNR-owned completion.
- `audit-summary.qmd`, `audit-full.qmd` and `cvd-data-rebuild.qmd` remain
  unchanged and **Not reviewed** for a later bounded task.

## Review-status system

The three manual `_metadata.yml` files inherit:

- `manual-review-status: not-reviewed`;
- `manual-review-display: true`; and
- the shared `_filters/manual-review-status.lua` filter.

Valid page overrides are `not-reviewed`, `reviewed-by-irh` and
`approved-by-bnr`. The filter renders the corresponding text label and
restrained colour treatment. Changing `manual-review-display` to `false` in
a manual's metadata removes the strip from that complete manual.

## Stage 1 — review status and architectural spine

### New files

| Path | Function |
|---|---|
| `docs/manual-review-update-log.md` | Controlled record of this review. |
| `site/_filters/manual-review-status.lua` | Shared status validation and HTML strip. |
| `site/operations/post-redcap/reporting-workflows.qmd` | Operational home for all three current report routes. |
| `site/technical/workflows/reporting/overview.qmd` | Technical reporting-route map. |
| `site/technical/workflows/reporting/rolling-update.qmd` | Rolling-update run and validation instructions. |
| `site/technical/workflows/reporting/annual-report.qmd` | Annual build/approve/publish instructions. |
| `site/technical/workflows/reporting/one-off-report.qmd` | One-off prepare/approve/publish instructions. |
| `site/technical/website/cvd-tables.qmd` | Presentation-layer maintenance instructions for public CVD tables. |

### Renamed or moved files

| From | To | Reason |
|---|---|---|
| `site/operations/post-redcap/dashboard-workflow.qmd` | `site/operations/post-redcap/cvd-events-workflow.qmd` | Name the analytical product rather than its website presentation. |
| `site/technical/workflows/dashboards/overview.qmd` | `site/technical/workflows/cvd-events/overview.qmd` | Establish the event release as the authoritative workflow. |
| `site/technical/workflows/dashboards/extract-redcap.qmd` | `site/technical/workflows/cvd-events/extract-redcap.qmd` | Same workflow rename. |
| `site/technical/workflows/dashboards/prepare-confidential.qmd` | `site/technical/workflows/cvd-events/prepare-confidential.qmd` | Same workflow rename. |
| `site/technical/workflows/dashboards/create-analysis-inputs.qmd` | `site/technical/workflows/cvd-events/create-analysis-inputs.qmd` | Same workflow rename. |
| `site/technical/workflows/dashboards/generate-metrics.qmd` | `site/technical/workflows/cvd-events/generate-metrics.qmd` | Same workflow rename. |
| `site/technical/workflows/dashboards/approve-metrics.qmd` | `site/technical/workflows/cvd-events/review-approve.qmd` | Reflect both Step 5 actions. |
| `site/technical/workflows/dashboards/publish-metrics.qmd` | `site/technical/workflows/cvd-events/publish-metrics.qmd` | Same workflow rename. |

### Deleted files

| Exact relative path | Reason | Current replacement | Baseline recovery commit |
|---|---|---|---|
| `site/operations/data/data-governance/dtrust.qmd` | Unsupported governance construct. | [Data sharing and governance](../site/operations/governance/data-sharing-governance.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/operations/post-redcap/tabulations-workflow.qmd` | Retired parallel analytical workflow. | [Public-table presentation](../site/technical/website/cvd-tables.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/operations/post-redcap/briefings-workflow.qmd` | Retired report workflow. | [Current reporting workflows](../site/operations/post-redcap/reporting-workflows.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/tabulations/overview.qmd` | Retired workflow documentation. | [CVD tables](../site/technical/website/cvd-tables.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/tabulations/generate.qmd` | Retired workflow step. | Event/mortality release instructions | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/tabulations/disclosure-control.qmd` | Retired workflow step. | [Shared disclosure control](../site/technical/controls/disclosure-control.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/tabulations/approve.qmd` | Retired workflow step. | Current event/mortality approval controls | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/tabulations/publish.qmd` | Retired workflow step. | Approved metric publication and Quarto presentation | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/briefings/overview.qmd` | Retired workflow documentation. | [Current reporting overview](../site/technical/workflows/reporting/overview.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/briefings/create.qmd` | Retired workflow step. | Current rolling, annual or one-off route | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/briefings/approve.qmd` | Retired workflow step. | Annual or one-off report approval | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/workflows/briefings/publish.qmd` | Retired workflow step. | Annual or one-off report publication | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/how-to/render-pdf-briefing.qmd` | Described retired PDF route. | Annual and one-off report instructions | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/reference/pdf-briefing-route.qmd` | Described retired PDF route. | [Reporting overview](../site/technical/workflows/reporting/overview.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/troubleshooting/pdf-render-errors.qmd` | Specific to retired renderer. | Current report checks and general troubleshooting | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/technical/website/update-briefing.qmd` | Specific to retired pages. | Current report and website instructions | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/operations/data/data-governance/sharing-guide.qmd` | Duplicated and contradicted the controlled request procedure. | [Governance overview](../site/operations/governance/data-sharing-governance.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/operations/data/data-governance/data-access-statement.qmd` | Superseded public statement duplicated the request route. | [Handle a data-access request](../site/operations/governance/data-access-requests.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/operations/data/data-governance/dataset-release.qmd` | Obsolete roles, thresholds and release model. | [Data-sharing procedure](../site/operations/data/data-governance/sharing-sop.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |
| `site/operations/data/data-governance/dataset-dissemination.qmd` | Duplicated obsolete release/dissemination instructions. | [Data-sharing procedure](../site/operations/data/data-governance/sharing-sop.qmd) | `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb` |

### Materially restructured pages

| Exact path | Material change |
|---|---|
| `site/operations/index.qmd` | Rebuilt the manual landing-page product map and historical-section treatment. |
| `site/operations/operating-model/roles-decision-rights.qmd` | Standardised standing roles and separated role names from workflow actions. |
| `site/operations/operating-model/routine-cycle.qmd` | Replaced retired products with current metric, presentation and report routes. |
| `site/operations/post-redcap/index.qmd` | Rebuilt the complete post-REDCap product and control map. |
| `site/operations/post-redcap/cvd-events-workflow.qmd` | Recast the renamed page as the separate six-step event release. |
| `site/operations/post-redcap/mortality-workflow.qmd` | Reconciled the separate six-step mortality release, including rates. |
| `site/operations/post-redcap/reporting-workflows.qmd` | Added operational responsibilities, evidence and stop points for all current reports. |
| `site/operations/release/review-approve-publish.qmd` | Rebuilt approval and publication actions for current products. |
| `site/operations/governance/data-sharing-governance.qmd` | Rebuilt as the single governance entry point. |
| `site/operations/governance/data-access-requests.qmd` | Rebuilt as the controlled request and decision route. |
| `site/operations/data/data-governance/sharing-sop.qmd` | Rebuilt as the current non-public data preparation and transfer procedure. |
| `site/technical/index.qmd` | Rebuilt the Technical Manual landing page and system boundary. |
| `site/technical/workflows/overview.qmd` | Rebuilt the current five-route workflow map. |
| `site/technical/controls/review-release.qmd` | Rebuilt common human review checks. |
| `site/technical/controls/disclosure-control.qmd` | Rebuilt around the definitive n < 6 rule and whole-release review. |
| `site/technical/controls/approve-publish.qmd` | Rebuilt current approval/publish bindings and actions. |
| `site/technical/reference/index.qmd` | Rebuilt from the current Stata inventory, menu and contracts. |
| `site/technical/maintenance/files-releases-versions.qmd` | Replaced obsolete package rules with current location, identity and version rules. |
| `site/technical/website/update-content.qmd` | Replaced retired report-page and catalogue instructions. |

All non-historical manual pages also had stale page-owned dates removed in
favour of inherited `date: last-modified`, inherited BNR authorship and an
explicit `reviewed-by-irh` status. The three historical audit pages were not
changed.

### Navigation changes

- Removed the retired tabulations, briefings and Data Trust entries.
- Renamed the event and mortality sections as release workflows.
- Added one Operations reporting page and four Technical reporting pages.
- Added the public CVD tables presentation page.
- Removed superseded numbered chapter labels.
- Retained the three historical audit pages under **Historical refit record**.
- Removed duplicate, non-canonical data-governance pages from the sidebar
  pending consolidation in the Operations batch.

### Permitted non-manual corrections

| Path | Correction |
|---|---|
| `scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do` | Corrected the header: deidentification occurs in Step 3; Step 2 builds the confidential cumulative dataset. |
| `scripts/stata/mortality/BNR_MORTALITY_WORKFLOW_CONTRACT.md` | Removed the retired tabulations workflow as a current reference and pointed to current event/reporting controls. |

### Stage 1 validation

- Confirmed the working branch and exact pre-update freeze before editing.
- Confirmed all changes are inside the three manual roots or the six approved
  exception paths.
- Confirmed the three deferred historical audit pages are byte-for-byte
  unchanged from the freeze.
- Parsed all three manual metadata files successfully.
- Tested all three status values and the display-off behaviour with Pandoc.
- Ran `scripts/python/check-local-links.py`: 398 local links checked. No
  missing target originates in any of the three manual roots; unrelated
  archived/generated-tree findings remain outside this review's change scope.
- Searched the three manuals for the removed governance name, Zenodo, DOI and
  `dtrust.qmd`: no match remains.
- Quarto is not installed in the current execution environment, so the complete
  Quarto render and visual desktop/narrow-screen inspection remain required in
  the final validation batch.

## Stage 2 — Operations Manual

### Completed

- Reviewed all live Operations pages while leaving the three deferred
  historical audit pages unchanged.
- Preserved the pre-REDCap and REDCap pages as explicit BNR-owned drafts; no
  unconfirmed local procedure was invented.
- Consolidated data governance into one overview, one request route, one
  operational sharing procedure and the shared DSA form.
- Removed four superseded governance pages listed in the deletion register.
- Standardised standing role names and removed obsolete small-cell thresholds,
  repository/DOI statements and retired report terminology.
- Reframed the Statistical Analysis Plan and metric register so reports consume
  approved metrics without re-establishing the retired workflow.
- Reconciled release authorisation, correction, handover and approval evidence
  with the public/private boundary.

### Validation

- All 28 retained Operations QMD pages are represented in sidebar navigation.
- All 25 current pages explicitly use `reviewed-by-irh`; the three deferred
  historical pages inherit `not-reviewed`.
- No missing local-link target originates in the Operations Manual.

## Stage 3 — Technical Manual

### Completed

- Reviewed all 35 retained Technical QMD pages.
- Reconciled menu and step names with `scripts/stata/menu/bnr_menu.do`.
- Replaced the system reference and file/version guide with current controller,
  product, storage, approval and correction rules.
- Updated the separate event and mortality six-step instructions, including
  current mortality rate outputs.
- Added and documented the three current reporting routes.
- Consolidated review, n < 6 disclosure, approval and analytical-publication
  controls.
- Recast dashboards, tables, downloads and report landing pages as Quarto
  presentation of approved public products.

### Validation

- All 35 Technical QMD pages are represented in sidebar navigation and carry
  `reviewed-by-irh`.
- Current manual text contains no retired menu names or live links to deleted
  workflow pages.
- No missing local-link target originates in the Technical Manual.

## Stage 4 — Public Methods Manual

### Completed

- Reviewed all 20 Public Methods QMD pages and kept conceptual explanation
  separate from run instructions and internal controls.
- Updated the surveillance and measures overviews to include annual mortality
  rates.
- Reconciled mortality counts, distributions, crude and age-standardised rates,
  confidence intervals, Primary/Inclusive definitions and the approximate
  classification boundary.
- Replaced retired product wording in the revisions guidance.
- Made the public disclosure wording definitive: positive counts below six are
  suppressed, and related values may require complementary protection.
- Retained the hypertension and diabetes pages as clearly labelled
  not-yet-approved measure specifications.

### Validation

- All 20 Methods QMD pages are represented in sidebar navigation and carry
  `reviewed-by-irh`.
- No implementation command or retired workflow remains in public methods text.
- No missing local-link target originates in the Public Methods Manual.

## Stage 5 — final reconciliation and validation

### Completed checks

- Parsed all 83 retained QMD front-matter blocks and the complete
  `site/_quarto.yml`.
- Confirmed sidebar coverage with no orphaned page: 20 Methods, 28 Operations
  and 35 Technical pages.
- Confirmed 80 current pages use `reviewed-by-irh`; the three frozen historical
  audit pages have no override and inherit `not-reviewed`.
- Compared the three historical file hashes with
  `1342bec77908de1ebac46d4ee59942cda5c5f5c7`; all are identical.
- Ran the local-link checker repository-wide: 398 links checked; no missing
  target originates in a manual. The remaining 20 missing targets are in
  archived, generated or other out-of-scope material.
- Confirmed current menu structure in `bnr_menu.do`: event 6 items, mortality
  6, rolling update 1, annual report 3, one-off report 3 and report utility 1.
- Searched live manuals for retired menu labels, retired workflow paths,
  superseded page names, the removed repository name and unsupported
  governance terminology; no match remains.
- The repository-wide retired-term search finds expected historical entries in
  this log and the September 2026 archive. It also finds two outdated current
  menu labels at `README.md:81-82` (`Update CVD dashboard` and
  `Update mortality dashboard`). `README.md` is outside the six permitted
  exception paths and was therefore not edited.
- Ran whitespace checks on tracked and new files.
- Confirmed Git status is unstaged and every changed path is inside a manual
  root or one of the six expressly permitted exception paths.
- Reviewed credential/security references: the manuals describe only
  role-based controls, placeholder paths and rules for keeping secrets and
  private evidence outside Git; no credential value, patient data or live
  security detail was added.

### Validation still required

Quarto is not installed in the current execution environment. The following
sign-off checks could therefore not be executed here:

- complete Quarto site render;
- rendered inspection of all three sidebars;
- representative desktop and narrow-screen visual inspection; and
- rendered confirmation that the status strip sits beneath the title on every
  page.

The Lua filter itself was exercised with Pandoc for all three states and with
the central display switch off. The outstanding Quarto and visual checks must
be run in the normal local Info-Hub environment before sign-off.

One scope decision also remains: either permit the two root `README.md` menu
labels to be corrected in a later bounded change or retain them as a known
non-manual inconsistency.

## Exact working-tree file inventory

The following is the complete unstaged `git status --short
--untracked-files=all` inventory after the review. The move and deletion
tables above provide the functional classification and recovery details.

```text
 M scripts/stata/monthly/bnr_step1_cvd_redcap_extract.do
 M scripts/stata/mortality/BNR_MORTALITY_WORKFLOW_CONTRACT.md
 M site/_quarto.yml
 M site/assets/scss/bnr.scss
 M site/methods/_metadata.yml
 M site/methods/about/bnr-surveillance.qmd
 M site/methods/about/records-to-statistics.qmd
 M site/methods/index.qmd
 M site/methods/interpretation/classifying-cvd-deaths.qmd
 M site/methods/interpretation/classifying-cvd-events.qmd
 M site/methods/interpretation/confidentiality.qmd
 M site/methods/interpretation/counts-percentages-rates.qmd
 M site/methods/interpretation/data-quality-completeness.qmd
 M site/methods/interpretation/revisions-comparability.qmd
 M site/methods/measures/case-fatality.qmd
 M site/methods/measures/cvd-event-counts.qmd
 M site/methods/measures/diabetes.qmd
 M site/methods/measures/hypertension.qmd
 M site/methods/measures/incidence.qmd
 M site/methods/measures/index.qmd
 M site/methods/measures/length-of-stay.qmd
 M site/methods/measures/mortality.qmd
 M site/methods/reference/glossary.qmd
 M site/methods/responsible-data-use/dsa-methods.qmd
 M site/methods/responsible-data-use/research-data-access.qmd
 M site/operations/_metadata.yml
 M site/operations/bnr-refit/index.qmd
 M site/operations/data/analysis-framework.qmd
 D site/operations/data/data-governance/data-access-statement.qmd
 D site/operations/data/data-governance/dataset-dissemination.qmd
 D site/operations/data/data-governance/dataset-release.qmd
 M site/operations/data/data-governance/dsa-om.qmd
 D site/operations/data/data-governance/dtrust.qmd
 D site/operations/data/data-governance/sharing-guide.qmd
 M site/operations/data/data-governance/sharing-sop.qmd
 M site/operations/data/sap-metrics.qmd
 M site/operations/data/sap.qmd
 M site/operations/governance/data-access-requests.qmd
 M site/operations/governance/data-sharing-governance.qmd
 M site/operations/index.qmd
 M site/operations/operating-model/records-handover.qmd
 M site/operations/operating-model/roles-decision-rights.qmd
 M site/operations/operating-model/routine-cycle.qmd
 D site/operations/post-redcap/briefings-workflow.qmd
 D site/operations/post-redcap/dashboard-workflow.qmd
 M site/operations/post-redcap/index.qmd
 M site/operations/post-redcap/mortality-workflow.qmd
 D site/operations/post-redcap/tabulations-workflow.qmd
 M site/operations/pre-redcap/abstract-verify.qmd
 M site/operations/pre-redcap/identify-assess.qmd
 M site/operations/redcap/approve-data-record.qmd
 M site/operations/redcap/create-complete-record.qmd
 M site/operations/redcap/database-maintenance.qmd
 M site/operations/redcap/resolve-record-queries.qmd
 M site/operations/release/correct-release.qmd
 M site/operations/release/data-release.qmd
 M site/operations/release/review-approve-publish.qmd
 M site/technical/_metadata.yml
 M site/technical/controls/approve-publish.qmd
 M site/technical/controls/disclosure-control.qmd
 M site/technical/controls/review-release.qmd
 M site/technical/getting-started/environment.qmd
 M site/technical/getting-started/workstation-setup.qmd
 D site/technical/how-to/render-pdf-briefing.qmd
 M site/technical/index.qmd
 M site/technical/maintenance/files-releases-versions.qmd
 M site/technical/maintenance/safe-code-change.qmd
 M site/technical/maintenance/troubleshooting.qmd
 M site/technical/reference/bnr-suppression-validation-2024-2025.qmd
 M site/technical/reference/index.qmd
 D site/technical/reference/pdf-briefing-route.qmd
 D site/technical/troubleshooting/pdf-render-errors.qmd
 M site/technical/website/cvd-events-dashboard.qmd
 M site/technical/website/cvd-mortality-dashboard.qmd
 M site/technical/website/render-publish.qmd
 D site/technical/website/update-briefing.qmd
 M site/technical/website/update-content.qmd
 D site/technical/workflows/briefings/approve.qmd
 D site/technical/workflows/briefings/create.qmd
 D site/technical/workflows/briefings/overview.qmd
 D site/technical/workflows/briefings/publish.qmd
 D site/technical/workflows/dashboards/approve-metrics.qmd
 D site/technical/workflows/dashboards/create-analysis-inputs.qmd
 D site/technical/workflows/dashboards/extract-redcap.qmd
 D site/technical/workflows/dashboards/generate-metrics.qmd
 D site/technical/workflows/dashboards/overview.qmd
 D site/technical/workflows/dashboards/prepare-confidential.qmd
 D site/technical/workflows/dashboards/publish-metrics.qmd
 M site/technical/workflows/mortality/approve.qmd
 M site/technical/workflows/mortality/build-burden.qmd
 M site/technical/workflows/mortality/classify.qmd
 M site/technical/workflows/mortality/extract.qmd
 M site/technical/workflows/mortality/overview.qmd
 M site/technical/workflows/mortality/publish.qmd
 M site/technical/workflows/mortality/review.qmd
 M site/technical/workflows/overview.qmd
 D site/technical/workflows/tabulations/approve.qmd
 D site/technical/workflows/tabulations/disclosure-control.qmd
 D site/technical/workflows/tabulations/generate.qmd
 D site/technical/workflows/tabulations/overview.qmd
 D site/technical/workflows/tabulations/publish.qmd
?? docs/manual-review-update-log.md
?? site/_filters/manual-review-status.lua
?? site/operations/post-redcap/cvd-events-workflow.qmd
?? site/operations/post-redcap/reporting-workflows.qmd
?? site/technical/website/cvd-tables.qmd
?? site/technical/workflows/cvd-events/create-analysis-inputs.qmd
?? site/technical/workflows/cvd-events/extract-redcap.qmd
?? site/technical/workflows/cvd-events/generate-metrics.qmd
?? site/technical/workflows/cvd-events/overview.qmd
?? site/technical/workflows/cvd-events/prepare-confidential.qmd
?? site/technical/workflows/cvd-events/publish-metrics.qmd
?? site/technical/workflows/cvd-events/review-approve.qmd
?? site/technical/workflows/reporting/annual-report.qmd
?? site/technical/workflows/reporting/one-off-report.qmd
?? site/technical/workflows/reporting/overview.qmd
?? site/technical/workflows/reporting/rolling-update.qmd
```

- 2026-09-12 12:50:12 +00:00 - Removed the generated 2025 annual CVD report v6 public package and associated public-health-update artefacts to reset controlled development to v1.

- 2026-09-12 13:07:25 +00:00 - Reset generated 2025 annual CVD report v1-v6 development artefacts, including the associated public-health update, before a fresh controlled v1 run.

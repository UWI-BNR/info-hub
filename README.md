# BNR info-hub

The **BNR info-hub** is the implementation repository for BNR Refit Phase 2. It combines the Stata analytical workflows, approved public output packages, Quarto website, and the documentation needed to operate and hand over the system.

The design is deliberately simple: a small Stata-skilled team should be able to prepare, review, approve, publish and maintain BNR surveillance outputs without a live public database or server-side application.

## Operating model

```text
Private source data
    -> Stata preparation and analysis
    -> private staging and human review
    -> recorded approval of an exact package
    -> outputs/public/        authoritative public analytical copy
    -> site/downloads/        disposable website mirror
    -> Quarto render
    -> Git and GitHub Pages deployment
```

The core rules are:

- **Stata computes:** cleaning, derivation, metrics, tables and figures remain in readable Stata code.
- **People review and approve:** a successful calculation never implies approval.
- **Controlled Stata steps publish:** only the exact approved files are promoted.
- **Quarto presents:** the website consumes approved public products and does not recalculate them.
- **GitHub deploys:** the public site is static and contains no confidential data.
- Generated outputs are corrected by changing the source data or code and rerunning, never by manual editing.
- Confidential data, tokens, logs and private review material remain outside this repository.

## Current analytical products

| Product | Implemented route | Current scope |
|---|---|---|
| Dashboard metrics | CVD Steps 1-6 | CVD burden, including registered event counts and distributions |
| Tabulations | Table Steps 1, 2A, 2B and 3 | Seven disclosure-controlled CVD table families plus workbook and ZIP |
| Briefings | Briefing Steps 1-3 | CVD incidence, case fatality and hospital length of stay |
| Mortality | Structure reserved | Workflow and public products still in development |
| Hypertension and diabetes | First-class site and Methods sections | Analytical workflows and approved measure definitions still in development |

CVD event counts are a dashboard and tabulation product. They are not duplicated as a case-count briefing.

## Repository structure

| Path | Purpose |
|---|---|
| `scripts/stata/` | Operational Stata workflows, analyst-owned analyses, shared helpers, dialogs and help |
| `scripts/python/` | Lightweight site and validation utilities |
| `scripts/powershell/` | Reserved for local Windows helpers |
| `outputs/public/` | Authoritative approved public analytical packages |
| `outputs/synthetic/` | Synthetic test fixtures and workflow checks |
| `site/` | Quarto source, the website mirror of public files, and all three manuals |
| `docs/` | Concise project guiderails and handover material not published on the site |
| `.github/` | GitHub configuration and website deployment workflow |

Private raw data, derived event-level data, staging packages, logs and REDCap credentials live in the separately controlled private environment configured by `bnr_paths_LOCAL.do`.

The website copies under `site/downloads/` can be rebuilt from `outputs/public/`; they are not the authoritative analytical archive.

## Stata entry points

Routine operators use **Stata > User > BNR**:

- **Update dashboard:** Steps 1-6;
- **Produce briefing:** Steps 1-3; and
- **Produce tables:** Steps 1, 2A, 2B and 3.

The active DO and ADO files, their responsibilities and dependencies are documented in [`scripts/stata/README.qmd`](scripts/stata/README.qmd).

Machine-specific paths are kept outside version control. To configure a workstation:

1. Copy `scripts/stata/config/bnr_paths_TEMPLATE.do`.
2. Rename the copy to `bnr_paths_LOCAL.do`.
3. Set the public repository, private companion repository and secure token-file paths.
4. Do not commit the local file or any token.

## Python environment

Python 3.13 is the tested baseline. From an activated project virtual
environment, install and check it with:

```powershell
python -m pip install -r requirements.txt
python scripts/python/check-python-environment.py
```

`requirements.txt` is the maintained, cross-platform list used for routine
setup and CI. `requirements-freeze.txt` is the exact full Windows environment
snapshot retained for troubleshooting and controlled reproduction; it is not
the routine installation file. Detailed setup and refresh instructions are in
the Technical Manual.

## Documentation

The three manuals answer different questions:

| Manual | Purpose | Location |
|---|---|---|
| Operations Manual | Who performs each task, what decision is required and when to stop | `site/operations/` |
| Technical Manual | How to configure, run, review, publish and troubleshoot the system | `site/technical/` |
| Public Methods Manual | What BNR measures mean, how they are calculated and how to interpret them | `site/methods/` |

Project-wide principles are in `docs/bnr-refit-project-guiderails.md`. The concise operating and handover summary is in `docs/bnr-refit-operations-handover.md`.

## Release and correction rule

Approval and publication are separate actions. The recognised approval roles are **BNR Lead**, **BNR Analyst** and **BNR Developer**, subject to BNR deciding who is authorised to approve dissemination.

If a released result is wrong, correct the authoritative REDCap record, reference data, configuration or analytical code; rerun from the earliest affected step; repeat review and approval; publish the corrected package; then render and deploy the site. Never repair a generated CSV, workbook, figure, manifest or approval receipt by hand.

## Current development boundary

The CVD dashboard, tabulation and three routine briefing pathways are implemented. Remaining development includes the mortality workflow, hypertension and diabetes analytical modules, and final operational testing and handover. The repository history records implementation detail; these summary documents should change only when the operating model, methods, controls or responsibilities materially change.

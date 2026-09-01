# BNR info-hub

The **BNR info-hub** is the implementation repository for BNR Refit Phase 2. It combines the Stata analytical workflows, approved public output packages, Quarto website, and the documentation needed to operate and hand over the system.

The design is deliberately simple: a small Stata-skilled team should be able to prepare, review, approve, publish and maintain BNR surveillance datasets without a live public database or server-side application. Quarto and Observable JS turn those approved datasets into the static public website.

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

- **Stata computes:** cleaning, derivation and authoritative surveillance metrics remain in readable Stata code.
- **People review and approve:** a successful calculation never implies approval.
- **Controlled Stata steps publish:** only the exact approved files are promoted.
- **Quarto presents:** the website consumes approved public metric datasets and may reshape them into tables and visual displays without creating a second authoritative analytical dataset.
- **GitHub deploys:** the public site is static and contains no confidential data.
- Generated outputs are corrected by changing the source data or code and rerunning, never by manual editing.
- Confidential data, tokens, logs and private review material remain outside this repository.

## Current analytical products

| Product | Implemented route | Current scope |
|---|---|---|
| CVD event metrics | CVD Steps 1-6 | Approved event counts, distributions, incidence estimates and related surveillance measures |
| CVD mortality metrics | Mortality Steps 1-6 | Approved mortality counts, distributions and rates |
| CVD reference tables | Quarto page using approved public metric datasets | Web tables derived directly from the CVD event and mortality releases |
| Reports and one-off analyses | Redesign pending | The former briefing workflow has been retired |
| Hypertension and diabetes | First-class site and Methods sections | Analytical workflows and approved measure definitions still in development |

CVD event counts and mortality statistics are calculated once in their respective release workflows and reused by dashboards, tables and future reports.

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

## Local editing launcher

`start-info-hub-edit.bat` is a version-controlled Windows convenience launcher
for website and documentation editing. Run it from the repository root to:

1. open the repository in VS Code (or File Explorer if VS Code is unavailable);
2. activate the local `venv-info-hub` virtual environment; and
3. start a local Quarto preview at `http://127.0.0.1:4200/`.

It derives the repository location from its own file location, so it must remain
in the repository root. It does not run Stata, access REDCap, publish outputs,
commit Git changes or deploy the website. Close the separate **BNR info-hub
Quarto Preview** command window when the edit session is complete.

The launcher requires a completed local Python environment and Quarto
installation. It is a convenience entry point, not a substitute for the
Technical Manual workstation setup or the controlled analytical workflows.

## Stata entry points

Routine operators use **Stata > User > BNR**:

- **Update CVD dashboard:** Steps 1-6;
- **Update mortality dashboard:** Steps 1-6; and
- **BNR utilities:** supporting workstation commands.

The former Stata tabulations and briefing workflows have been retired. Public
CVD tables are now generated directly from approved public metric datasets in
Quarto. The replacement route for annual, quarterly and one-off reports will
be designed separately.

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

The CVD event and mortality release workflows and their public dashboards are operational. The CVD reference-tables page consumes their approved public datasets directly. The former Stata tabulations and briefing workflows have been retired; annual, quarterly and one-off reporting will be redesigned separately. Remaining development also includes hypertension and diabetes analytical modules and final operational testing and handover. The repository history records implementation detail; these summary documents should change only when the operating model, methods, controls or responsibilities materially change.

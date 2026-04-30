# Changelog

This file records meaningful changes to the BNR `info-hub` repository.

It is not a full Git commit log. It is an institutional record of changes that affect project structure, workflow, methodology, publication, outputs, or handover.

Use this file to record changes that future users may need to understand.

---

## What should be recorded

Record changes such as:

- changes to repository structure
- changes to the compute-to-publication workflow
- changes to output naming conventions
- changes to the `outputs/` contract
- changes to Quarto site structure
- changes to GitHub deployment or automation
- changes to Python dependencies
- changes to major Stata workflow design
- changes affecting published outputs
- changes affecting documentation or handover

Minor edits, spelling fixes, and routine content updates do not usually need a changelog entry.

---

## Current changelog entries

---

## 2026-04-17

### Initial local setup scaffold

**Changes**

- Created the initial local development pathway for the BNR `info-hub`.
- Established the project as a Quarto-based publication site.
- Confirmed Stata as the primary analytics and compute tool.
- Confirmed Python as a lightweight support tool only.
- Created the initial repository scaffold:
  - `scripts/`
  - `outputs/`
  - `site/`
  - `docs/`
  - `assets/`
  - `setup-checks/`
  - `.github/`
- Created initial subfolders for:
  - Stata, Python, and PowerShell scripts
  - generated tables, figures, data, logs, and build metadata
  - reports, slides, dashboards, Operations Manual, technical pages, and site assets
- Created the initial `.gitignore`.
- Created the initial `README.md`.
- Created the initial `DECISIONS.md`.
- Created the initial `requirements.txt`.
- Created `requirements-freeze.txt` to record exact installed Python package versions.

**Reason**

The project needed a clean, documented, handover-ready local setup before substantive site development or analytics work begins.

The setup was designed for future users who may be confident Stata users but new to Git, Python, Quarto, and website development.

**Impact**

- The repository now has a clear structure for future development.
- The compute and publication layers are separated.
- Generated outputs have a defined location.
- Local setup is documented as a step-by-step process.
- Future users have a clearer starting point after cloning the repository.

**Documentation Updated**

- `README.md`
- `DECISIONS.md`
- `.gitignore`
- `docs/setup/`
- `local-setup-notes.md`

---

## 2026-04-26

### Quarto site spine and first Stata publication pilot

**Changes**

- Expanded the Quarto site navigation from a starter Home/About structure to the first full information architecture.
- Created the planned section structure for:
  - About
  - Surveillance Outputs
  - Methods & Data
  - Dashboards
  - Downloads
  - Operations Manual
  - Technical documentation
  - Archive
- Selected simple CVD case counts as the first Stata-to-Quarto pilot pathway.
- Added a formal architectural decision that Quarto should publish only approved public output bundles.
- Established `outputs/public/` as the preferred location for publication-ready artefacts consumed by the Quarto site.

**Reason**

The project is moving from local setup into the porting and build phase.

The old Material for MkDocs site is being used as a content source, not as the structural template for the new Quarto site. The new site requires a cleaner architecture before detailed content migration begins.

Simple case counts were selected as the first Stata pilot because they provide a low-complexity test of the compute-to-publication pathway before more complex indicators such as incidence, mortality, survival, or case-fatality are refactored.

**Impact**

- The Quarto site now has a clearer long-term structure.
- The first analytic pilot is defined.
- The compute and publication layers remain separated.
- GitHub Pages deployment can be designed around approved public outputs rather than confidential data or live Stata execution.
- The Operations Manual will need to document how outputs are generated, checked, promoted, published, and archived.

**Documentation Updated**

- `site/_quarto.yml`
- `DECISIONS.md`
- `CHANGELOG.md`
- `site/operations-manual/`
- `site/technical/`

---

## Template for future entries

Use the following structure for future changelog entries.

---

## YYYY-MM-DD

### Short descriptive title

**Changes**

- Describe what changed.

**Reason**

- Explain why the change was made.

**Impact**

- Explain what this affects.
- Note whether outputs, workflow, documentation, or handover are affected.

**Documentation Updated**

- List any documentation files updated at the same time.

---

## Changelog rule

If a change affects structure, workflow, methodology, generated outputs, publication, or handover, record it here.

If a change affects why the project is designed in a certain way, also consider whether `DECISIONS.md` needs to be updated.
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
# BNR info-hub

The **BNR info-hub** is the implementation repository for BNR Refit Phase 2. It brings together the Stata compute workflow, controlled analytical outputs, Quarto publication site, and the documentation needed for operation and handover.

The aim is a reproducible surveillance system that a small, Stata-skilled team can run, review, approve, and maintain.

## Operating model

```text
Private source data
    -> Stata analysis
    -> outputs/staging/       review only
    -> approval               Registry Lead or Registry Statistician
    -> outputs/public/        authoritative approved package
    -> site/downloads/files/  disposable website mirror
    -> Quarto
    -> GitHub Pages
```

The core rules are:

- **Stata computes:** cleaning, derivation, metrics, tables, and figures remain in readable Stata code.
- **Quarto publishes:** the site presents approved outputs and does not replace the analytical workflow.
- **GitHub deploys:** the public site is static and contains no confidential data.
- Compute, approval, publication, and deployment remain separate.
- Generated outputs are corrected by changing the source data or code and rerunning, never by manual editing.
- Confidential data remain outside this repository.

## Repository structure

| Path | Purpose |
|---|---|
| `scripts/stata/` | Stata preparation, analysis, metric, briefing, and publication code |
| `scripts/python/` | Lightweight support utilities only |
| `scripts/powershell/` | Local Windows helper scripts |
| `outputs/staging/` | Review packages awaiting approval |
| `outputs/public/` | Authoritative approved public packages |
| `site/` | Quarto source, operational guidance, technical guidance, and website mirror |
| `docs/` | Project, setup, development, and handover material not published on the site |
| `assets/` | Shared source assets |
| `setup-checks/` | Lightweight local setup checks |
| `.github/` | GitHub configuration and deployment workflows |

The website copy under `site/downloads/files/` is a disposable mirror of `outputs/public/`; it may be rebuilt and is not the authoritative release.

## Stata workflow

The active Stata DO files and their responsibilities are documented in [`scripts/stata/README.md`](scripts/stata/README.md).

Machine-specific paths are kept outside version control. To configure a workstation:

1. Copy `scripts/stata/config/bnr_paths_TEMPLATE.do`.
2. Rename the copy to `bnr_paths_LOCAL.do`.
3. Edit the two root paths for the local machine.
4. Do not commit the local file.

Shared release mechanics belong in common helper DO files. Analytical choices remain visible in the analyst-owned metric, briefing, or supporting-output DO file.

## Documentation

Task-specific instructions belong in:

- `site/operations/` for routine operational procedures;
- `site/technical/` for setup, code, publication, and troubleshooting guidance.

During development, Git history is the implementation record. Documentation should remain concise and should be expanded only where it supports safe operation or handover.

## Current status

The repository is under active development. The intended separate Stata approval-and-promotion command is not yet complete; until it is implemented, existing publication helpers should be run only after the combined analytical, disclosure, interpretation, and publication-readiness review has been completed.

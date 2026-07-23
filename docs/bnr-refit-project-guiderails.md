# BNR Refit Phase 2: Project Guiderails

**Status:** Development guiderails  
**Updated:** 23 July 2026

This document subsumes the earlier workflow, style, architecture and decision source files. Keep it short; detailed implementation belongs in the repository's Operations and Technical Manuals.

## Purpose

Build a reproducible, sustainable BNR surveillance system that a small, Stata-skilled team can operate, review and hand over.

## Core rules

1. **Stata computes.** Core cleaning, derivation, metrics, tables and figures remain in readable Stata code.
2. **Quarto publishes.** Quarto presents approved outputs; it must not hide or replace core analytics.
3. **GitHub deploys.** The public Info-Hub remains static and requires no confidential data, live database or Stata installation.
4. **Compute, approval, publication and deployment remain separate.**
5. **Metrics are permanent; briefings are temporary.** Metric datasets provide stable definitions and reusable values. Briefings interpret selected results and may include additional analysis.
6. **Use the simplest handover-ready solution.** Avoid new dependencies, dense Stata logic and unnecessary automation.
7. **Generated outputs are never manually corrected.** Correct the code or source data and rerun.
8. **Confidential data remain outside the repository.** Only approved public artefacts enter the publication pathway.

## Working pathway

```text
Private source data
    -> Stata analysis
    -> outputs/staging/       review only
    -> single approval gate   BNR Lead, BNR Analyst or BNR Statistician
    -> outputs/public/        authoritative approved package
    -> site/downloads/files/  disposable website mirror
    -> Quarto
    -> GitHub Pages
```

Running an analysis must not itself imply approval. Promotion from `staging` to `public` is a separate, deliberate Stata action.

## Product structure

- **Metric packages:** release-stamped and `current` datasets, with metadata. Stratifications are dimensions, not separate metrics unless the definition or method changes.
- **Briefing packages:** approved data, figures, metadata and optional workbook/ZIP supporting a dated interpretation.
- **Site mirror:** may be rebuilt from `outputs/public/`; it is not the authoritative release copy.

## Code and naming

- Prefer explicit, commented Stata code over compact metaprogramming.
- Keep machine-generated filenames lowercase with underscores.
- Keep human-facing QMD filenames lowercase with dashes.
- Use stable release or product identifiers.
- Each released dataset must have labels, notes and companion metadata.
- Shared release mechanics belong in common helper files; analytical decisions remain visible in analyst-owned DO files.

## Documentation during development

Do not maintain a detailed architectural decision register or log every development change. Keep this document current when the operating model changes. Before formal release and handover, consolidate the Operations and Technical Manuals and begin recording only material post-release changes.

## Authority

The signed Terms of Reference remains the scope baseline. The GitHub repository is the implementation record. Where they appear inconsistent, review the issue rather than silently changing the ToR.

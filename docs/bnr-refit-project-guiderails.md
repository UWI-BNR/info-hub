# BNR Refit Phase 2: Project Guiderails

**Status:** Current development guiderails
**Updated:** 12 August 2026

This is the concise architectural guardrail for BNR Refit Phase 2. Detailed procedures belong in the Operations and Technical Manuals; public definitions and interpretation belong in the Public Methods Manual.

## Purpose

Build a reproducible, governed and sustainable BNR surveillance system that a small Stata-skilled team can operate, review, approve and hand over.

## Core rules

1. **Stata computes.** Core extraction, cleaning, derivation, metrics, tables and figures remain in readable Stata code.
2. **People review and approve.** Automation may prepare review evidence, but it does not replace analytical, disclosure or publication judgement.
3. **Quarto publishes.** Quarto presents approved outputs; it must not hide or replace the analytical workflow.
4. **GitHub deploys.** The public Info-Hub remains static and requires no confidential data, live database or Stata installation.
5. **Preparation, approval, analytical publication and website deployment remain separate actions.**
6. **Use the simplest handover-ready solution.** Avoid unnecessary dependencies, compact metaprogramming and parallel pathways.
7. **Generated outputs are never manually corrected.** Correct the authoritative data, reference data, configuration or code and rerun.
8. **Confidential material remains outside Git.** This includes identifiable data, REDCap tokens, private logs, staging packages and review workbooks.
9. **Every release is identified and reproducible.** Use a defined data freeze, release period, package ID, manifest and approval receipt.
10. **Disclosure control precedes publication.** Review the complete proposed public payload, not only its headline values.

## System boundary

```text
REDCap and approved historical sources
    -> private Stata preparation
    -> deidentified analytical inputs
    -> product-specific analysis and private staging
    -> human review and recorded approval
    -> controlled Stata publication
    -> authoritative public package
    -> website mirror
    -> Quarto render
    -> Git and GitHub Pages
```

Running an analysis must not itself imply approval. An `approval.yml` receipt means **approved, not yet published** until the separate product-specific publication step succeeds.

## Product rules

| Product | Role in the system | Current design rule |
|---|---|---|
| Dashboard metrics | Stable, repeatable indicators refreshed from each approved release | CVD event counts and event distributions are dashboard measures |
| Tabulations | Disclosure-controlled tables and reusable download products | Stata creates all values, suppression and publication-ready Markdown/workbook content |
| Briefings | Dated interpretation of selected analytical questions | Routine CVD briefings cover incidence, case fatality and length of stay; counts are not duplicated as a briefing |
| Mortality | Planned CVD deaths dashboard and mortality-rate briefing | Do not describe the workflow as operational until implemented and approved |
| Hypertension and diabetes | First-class surveillance domains | Use the same architectural controls; complete holding pages only when measures and workflows are approved |

Metric definitions are stable specifications. Briefings are dated interpretive products and may contain additional analyses, but they must still start from approved deidentified inputs and use the common approval and publication contract.

## Product-specific control points

| Workflow | Analysis / preparation | Approval | Publication |
|---|---|---|---|
| Dashboard metrics | Steps 1-4; Step 5 Prepare creates the review candidate | Step 5 Approve | Step 6 |
| Tabulations | Step 1 and Step 2A | Step 2B | Step 3 |
| Briefings | Step 1 | Step 2 | Step 3 |

The recognised technical approval roles are **BNR Lead**, **BNR Analyst** and **BNR Developer**. BNR retains responsibility for deciding who is authorised to approve dissemination. The same person may perform more than one action where local governance permits, but the actions and records remain separate.

## Output and naming rules

- `outputs/public/` is the authoritative public analytical copy.
- `site/downloads/` is a disposable website mirror and may be rebuilt.
- Private staging and review material remain in the configured private environment.
- Use stable product IDs and release-stamped package IDs.
- Machine-generated filenames use lowercase with underscores.
- Human-facing QMD filenames use lowercase with hyphens.
- Each released dataset has labels, notes and companion metadata.
- Shared mechanics belong in common helpers; analytical decisions remain visible in analyst-owned DO files.
- Publication steps copy only manifested approved files and must stop on identity, checksum or completeness failures.

## Documentation boundaries

| Manual | Governing question |
|---|---|
| Operations Manual | Who does what, when, and with what authority? |
| Technical Manual | How is the task performed, checked and recovered? |
| Public Methods Manual | What does the statistic mean and how should it be interpreted? |

Do not duplicate detailed procedures across manuals. Cross-link to the authoritative page.

## Change control

During development, Git history is the implementation record. Update this document only when the operating model, architectural boundary, roles or product structure changes.

After formal handover, record changes that materially affect:

- an approved measure or analytical method;
- disclosure control;
- the approval or publication contract;
- public output structure;
- required software or infrastructure; or
- staff responsibilities.

## Authority and ToR conditions

The signed Terms of Reference remains the scope baseline. In particular:

- BNR owns data completeness, clinical accuracy and source-record corrections;
- indicator definitions and templates require approval before automation;
- Stata remains the primary analytical platform;
- BNR and its oversight authorities retain dissemination approval;
- each release uses a defined data freeze and version;
- agreed disclosure-control rules apply before publication; and
- material methodological, structural, governance or scope changes require explicit review.

Where the ToR, repository and manuals appear inconsistent, stop and resolve the discrepancy rather than silently changing the implementation.
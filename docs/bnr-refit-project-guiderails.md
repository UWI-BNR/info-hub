# BNR Refit Phase 2: Project Guiderails

**Status:** Current development guiderails

**Updated:** 6 September 2026

**Pre-manual-update baseline and recovery point:** `d34a1d1cd1a952a26a30c4a37894395ed5bdd6eb`

This is the concise architectural guardrail for BNR Refit Phase 2. Detailed procedures belong in the Operations and Technical Manuals; public definitions and interpretation belong in the Public Methods Manual.

## Purpose

Build a reproducible, governed and sustainable BNR surveillance system that a small Stata-skilled team can operate, review, approve and hand over.

## Core rules

1. **Stata computes.** Core extraction, cleaning, derivation, surveillance metrics and repeatable annual-report content remain in readable Stata code. Bespoke one-off report methods may vary but remain analyst-owned and documented. A controlled Python helper may add annual-report page furniture and contents navigation only; it must not access data or change analytical content. Public website views may filter, arrange and make only explicitly permitted presentation summaries of already approved aggregate values.
2. **People review and approve.** Automation may prepare review evidence, but it does not replace analytical, disclosure or publication judgement.
3. **The publish layer presents approved information.** Quarto provides the static website, report indexes and PDF landing pages. Observable JS presents the rolling update from frozen approved public data. Neither layer may recreate surveillance metrics, disclosure decisions or protected values.
4. **GitHub deploys.** The public Info-Hub remains static and requires no confidential data, live database or Stata installation.
5. **Preparation, approval, analytical publication and website deployment remain separate actions where the product has an approval lifecycle.** The rolling update is a narrow exception: it is built in one step from already approved public releases and adds no new surveillance metric.
6. **Use the simplest handover-ready solution.** Avoid unnecessary dependencies, compact metaprogramming and parallel pathways.
7. **Generated outputs are never manually corrected.** Correct the authoritative data, reference data, configuration or code and rerun.
8. **Confidential material remains outside Git.** This includes identifiable data, REDCap tokens, private logs, staging packages and review workbooks.
9. **Every analytical release and governed PDF report is identified and reproducible.** Use a defined data freeze, release period, package or report ID, manifest and approval receipt. A rolling update instead records its report identity and freezes complete exact snapshots of its declared approved source releases.
10. **Disclosure control precedes publication.** Review the complete proposed public payload, not only its headline values.

## System boundary

```text
REDCap and approved historical sources
    -> separate private CVD-event or mortality Stata pathway
    -> product-specific calculation and private staging
    -> human review and recorded approval
    -> controlled Stata publication
    -> authoritative public metric package and website mirror
        -> dashboards and public tables
        -> rolling update: freeze declared releases -> dated Quarto/Observable page
        -> annual report: Stata candidate -> approve -> publish PDF + Quarto landing page

Bespoke one-off analysis
    -> finished PDF -> prepare candidate -> approve -> publish PDF + Quarto landing page

Website source
    -> Quarto render -> Git -> GitHub Pages
```

Running an analysis must not itself imply approval. An `approval.yml` receipt means **approved, not yet published** until the separate product-specific publication step succeeds.

## Product rules

| Product | Role in the system | Current design rule |
|---|---|---|
| CVD event metrics | Stable approved event measures and reusable public data | The CVD Steps 1-6 pathway creates disclosure-controlled counts, distributions, rates and approved associated scope, comparator, linkage and uncertainty fields |
| CVD mortality metrics | Stable approved mortality measures and reusable public data | The separate mortality Steps 1-6 pathway creates disclosure-controlled counts, distributions, crude and age-standardised rates and their approved uncertainty fields |
| Dashboards and public tables | Interactive views of the approved CVD-event and mortality releases | They read published values and disclosure status; they may filter, arrange and make explicitly approved display calculations but must not recreate surveillance measures or suppression |
| Rolling three-month update | Monthly objective summary of recent approved CVD-event and mortality releases | One-step Stata builder freezes both exact release CSVs; the central Quarto/Observable template may perform only approved simple aggregate arithmetic |
| Annual CVD report | Repeatable standard report with a year-specific Focus On chapter | Stata/`putpdf` builds a private candidate from approved public releases; separate Steps 2 and 3 approve and publish the PDF and its Quarto landing page |
| One-off CVD report | Bespoke analytical report | Analysis remains analyst-owned; the common three-step pathway starts with the finished PDF and controls preparation, approval and publication, not analytical method |
| Hypertension and diabetes | First-class surveillance domains | Use the same architectural controls; complete holding pages only when measures and workflows are approved |

Metric definitions are stable specifications. Reports are dated products. The annual standard section and rolling update use approved public releases; bespoke annual Focus On and one-off analyses remain analyst-owned and must use inputs appropriate to their approved purpose.

The former standalone tabulation and briefing workflows are archived historical units. They must not be documented or restored as parallel operational pathways. Current public tables are website views of approved metric releases; incidence, case-fatality and length-of-stay questions may be addressed through appropriately governed annual or one-off reports.

## Product-specific control points

| Workflow | Analysis / preparation | Approval | Publication |
|---|---|---|---|
| CVD event metrics | Steps 1-4; Step 5 Prepare creates the review candidate | Step 5 Approve | Step 6 |
| CVD mortality metrics | Steps 1-4; Step 4 creates the review candidate | Step 5 | Step 6 |
| Rolling three-month update | One controlled build freezes and verifies already approved public inputs | No second product approval | The same build writes the authoritative dated package and website source; Quarto rendering and deployment remain separate |
| Annual CVD report | Step 1 builds the private candidate | Step 2 | Step 3 |
| One-off CVD report | Bespoke analysis precedes the workflow; Step 1 prepares the finished PDF candidate | Step 2 | Step 3 |

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
- Dated report locations remain stable by period or study: `reports/updates/YYYY-MM/`, `reports/annual/YYYY/` and `reports/studies/{study-id}/` under the applicable authoritative and website roots.
- A published report correction uses a higher version at the same stable public location. Do not reuse or downgrade a published version; Git retains the superseded working-tree instance.
- Generated rolling-update pages are instances of the central template and must not be copied forward as new templates.

## Local editing utility

`start-info-hub-edit.bat` is the tracked Windows launcher for a local website
and documentation editing session. It opens the repository in VS Code and starts
a local Quarto preview using `venv-info-hub`. It derives its root from its own
location and must remain in the repository root.

It is not an analytical, approval, publication, Git or deployment workflow. It
does not access REDCap or private analytical data. The controlled Stata menu and
product-specific approval and publication steps remain the only operational
entry points for surveillance outputs.

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

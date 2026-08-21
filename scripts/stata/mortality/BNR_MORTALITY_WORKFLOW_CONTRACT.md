# BNR mortality workflow contract

## Purpose

This is the controlling operational contract for changes to the BNR mortality
workflow. Read it before designing, changing, reviewing or approving mortality
workflow code. It records the agreed boundaries that make the workflow safe,
reproducible and usable by the mixed-experience BNR analyst team.

## Workflow separation

1. Step 1 extracts private data.
2. Step 2 classifies private mortality data.
3. Step 3 calculates and stages private burden data.
4. Step 4 automatically revalidates, applies deterministic disclosure control
   and creates private human-review materials.
5. Step 5 records a deliberate human approval of the exact Step 4 candidate.
6. Step 6 alone may promote an approved package for publication.

No step may quietly take on the responsibilities of a later step.

## Automation and analyst role

Steps 1–4 run automatically under the fixed, documented input structure.
Analysts must not edit generated datasets, workbooks, suppression symbols,
metadata or public-ready files by hand.

Analysts inspect the private review materials, confirm plausibility and approve
or decline the completed candidate in Step 5. They do not select extra cells,
change suppression rules, modify code or repair an automated calculation during
a routine monthly release.

## Fixed disclosure-control policy

- Supporting frequencies **1–5** receive primary suppression.
- A true zero is not automatically primary-suppressed.
- The threshold must not change as part of a routine workflow update.

Secondary protection is deterministic, automatic and documented. It prevents
reconstruction through totals, related categories, derived measures, temporal
comparisons and five-year comparators where relevant.

Technical QA checks verify this contract. Under the fixed routine structure
they are expected to pass automatically; they must not create a normal analyst
decision or repair pathway.

## Consistency with established CVD workflows

There must be **no unagreed drift** in mortality workflow concepts, safeguards,
terminology or compute/review/approve/publish separation from the established
CVD dashboard and CVD tabulations workflows.

Consistency means the same BNR policy and operational principles, not blindly
copying code between different output structures. A mortality-specific
secondary-suppression plan must be explicit, justified and tested against the
same safety principle: no protected value may be reconstructed from the full
proposed release.

The CVD dashboard and CVD tabulations workflows are reference implementations
for workflow separation, review materials, approval and publication boundaries.
They must not be weakened merely to make mortality superficially identical.

## Review and approval

Step 4 materials must support a practical spreadsheet-based review without
coding or data wrangling. They must distinguish private exact values and
protection reasons from the safe public candidate.

Step 5 confirmations must map to visible files and concrete review actions.
Step 5 records approval; it does not calculate or alter disclosure control.

## Development and change control

Before supplying a substantive mortality code change:

1. Read this contract and the detailed mortality workflow guide.
2. State which workflow steps and contract clauses the change affects.
3. Confirm it preserves the fixed threshold, automation, analyst role and
   publication separation.
4. For a new suppression rule, describe the reconstruction risk,
   deterministic response and automated QA check before implementation.
5. Use simple, heavily commented Stata with explicit sections.
6. Provide replacement files for manual installation; do not directly change
   the BNR repository unless explicitly authorised.

After a substantive change, rerun affected steps, review private outputs and
repeat Step 5 approval before Step 6 promotion.

## Exceptional conditions

An automated validation failure indicates an unexpected input-structure change
or technical defect. It is not a routine analyst task. Do not patch generated
files: stop before approval or publication, preserve the log and review
materials, correct the source or code, then rerun the affected steps.

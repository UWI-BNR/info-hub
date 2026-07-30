# Monthly CVD workflow — Step 5

## Purpose

Step 5 is the single private human-review and approval gate between exact Step 4 staging outputs and Step 6 promotion. It first gives authorised BNR staff a disclosure-controlled candidate and one concise workbook to review. Only a successful approval action creates `public_ready` and records approval against its exact files.

## Metric-family selection

The Step 5 dialog displays the planned CVD metric families. **Burden — event counts and distributions** is the only enabled selection at present. Incidence and rates, case fatality, length of stay / hospital use, data quality, care performance and mortality are shown as planned, disabled options.

When a further family is implemented, it will receive its own Step 4 contract and Step 5 disclosure policy before being enabled. The dialog may eventually run several selected families in one session, but it will run each as a separate package. Each package will keep its own review workbook, review-basis fingerprints, approval record and Step 6 promotion check.

Step 5 does **not** publish, promote, mirror, render or deploy anything.

## Responsibilities

| Component | Responsibility |
|---|---|
| `monthly/bnr_step5_review.do` | Release selection, prepare/approve actions, Step 4 acceptance, reviewer workbook, manifest and approval record |
| `common/bnr_step5_suppress.do` | Public suppression fields, removal of confidential numeric values and disclosure QA |
| `dialogs/bnr_step5_review.dlg` | Thin Stata interface to the controller |

## Folder structure

Short internal filenames limit Windows path depth:

```text
$BNR_STAGING/metrics/cvd/burden/cvd_YYYY_MM/
├── datasets/                         exact private Step 4 data
├── metadata/                         private Step 4 metadata
├── review/
│   ├── step5_review.xlsx
│   ├── step5_candidate.dta
│   ├── step5_disclosure_qa.csv
│   ├── step5_review_basis.csv
│   ├── public_manifest.csv
│   └── approval.yml                  only after approval
└── public_ready/                     only after approval
    ├── datasets/
    │   ├── release.dta
    │   ├── release.csv
    │   ├── current.dta
    │   └── current.csv
    ├── metadata/
    │   ├── release.yml
    │   ├── current.yml
    │   └── package.yml
    └── disclosure_qa.csv
```

The release identity is stored in the parent folder, datasets and metadata. Repeating it in every internal filename is unnecessary.

## Action 1: prepare the review package

```stata
do "$BNR_STATA/monthly/bnr_step5_review.do" ///
    2024 2 burden prepare
```

Use `prepare replace` only for a deliberate rerun. Replacement first invalidates any existing `approval.yml`.

Prepare:

1. confirms the requested completed Step 4 files exist;
2. confirms every Step 4 QA result is `PASS`;
3. confirms the release identity;
4. derives a private disclosure-controlled candidate without changing the private Step 4 dataset;
5. applies primary, linked, temporal and conservative complementary suppression;
6. removes exact `value`, `numerator` and `denominator` values from every suppressed public row;
7. produces disclosure QA;
8. creates `step5_review.xlsx`; and
9. records fingerprints for the exact candidate and its authoritative source files in `step5_review_basis.csv`.

The five fingerprint rows are deliberately written and checked explicitly in readable Stata code. They are not a defence against an outdated downloaded script; they prevent approval of one reviewed candidate and promotion of a subsequently altered file.

No `public_ready` folder or approval is created during preparation.

If any Step 5 review output already exists, preparation without `replace` stops. The final screen and log output state `STEP 5 DID NOT COMPLETE`, identify the existing file and show the log path. The controller does not continue.

`prepare replace` is a deliberate reset. It invalidates any earlier approval, removes the earlier `public_ready` package, and rebuilds the review materials.

## Public suppression contract

Every aggregate row remains present so dashboards can distinguish suppression from absent data.

| Field | Meaning |
|---|---|
| `value` | Numeric metric value; missing when suppressed |
| `display_value` | Formatted value, or `*` when suppressed |
| `suppression_status` | `none`, `primary`, `secondary` or `derived` |
| `suppression_note` | Public explanation on suppressed rows |

Observable must use `suppression_status`, not infer suppression from a missing value.

### Temporal differencing

Incomplete quarterly and annual disease-specific values are marked `derived` suppression. Publishing them in successive monthly releases could reveal disease-specific monthly counts by subtraction, undermining the decision to publish monthly results for all CVD only.

Completed quarters and years remain eligible for publication.

### Complementary suppression

If a complete additive panel contains a primary or linked-risk cell, Step 5 conservatively suppresses the complete panel. This is intentionally simpler and safer for handover than fragile cell-by-cell secondary-suppression choices. If this rule removes an unacceptable amount of useful output, BNR should revise the reporting specification rather than manually unsuppress a generated cell.

### Annual All-CVD age safeguard

Step 4 supplies two annual All-CVD, all-sex age rows: `under_70` and `70_plus`. A missing-age category is never public. When the private missing-age count is 1–5, Step 5 suppresses the two age rows—and any linked five-year comparator—with a public `*`. These are normally `derived` suppressions; a row that is itself 1–5 remains a `primary` suppression. This prevents reconstruction from the all-age total. The public candidate retains `age_group` and `age_group_order` for dashboards, but removes the private withholding flag.

## Action 2: complete the human review

Open:

```text
review/step5_review.xlsx
```

The workbook contains:

| Sheet | Review purpose |
|---|---|
| `Review` | Release identity, status and instructions |
| `QA` | Step 4 and Step 5 automated checks |
| `Private results` | Exact private values for plausibility review |
| `Suppression` | Exact supporting values alongside final public suppression decisions |
| `Public candidate` | Exactly the rows and values that approval will place in `public_ready` |
| `Files` | Fingerprints of the candidate and its authoritative sources |

The approver confirms one combined decision covering:

- analytical correctness and plausibility;
- disclosure control;
- interpretation and period completeness;
- completeness and publication readiness.

The authorised approval roles are `BNR Lead`, `BNR Analyst` and `BNR Developer`.

If review fails, do not edit generated files. Identify whether the issue belongs to source data, unexpected source structure, metric specification or code. Correct the authoritative source or version-controlled code, rerun from the relevant earlier step, and prepare a new Step 5 package.

## Action 3: record approval

After completing the review:

```stata
do "$BNR_STATA/monthly/bnr_step5_review.do" ///
    2024 2 burden approve ///
    "Full name" "BNR Developer"
```

The approver name is mandatory. The Stata dialog provides the three authorised roles as a drop-down list so the role cannot be mistyped.

The controller:

1. confirms disclosure QA still passes;
2. confirms suppressed public rows retain no exact numeric value;
3. recalculates the size and checksum of the reviewed candidate and every authoritative source file;
4. refuses approval if anything reviewed changed;
5. creates `public_ready`, including release/current data, metadata and disclosure QA;
6. creates `public_manifest.csv`; and
7. writes `review/approval.yml`.

The approval also stores the size and checksum of `public_manifest.csv`. This ties approval to both the exact public-ready files and the exact manifest reviewed.

Routine controller commands run quietly, so staff do not need to search through echoed Stata source code. At the end of each successful action, Stata prints a clearly separated **STEP 5: OPERATIONAL RUN SUMMARY** as the final information in both the Results window and the private log.

For **prepare**, start with the row labelled **OPEN THIS FILE FIRST**: `review/step5_review.xlsx`. The remaining rows point to the candidate, disclosure QA and review record that support that workbook. For **approve**, the summary points to the newly created `public_ready` package, its manifest and the approval record.

A failed action ends with a separate `STEP 5 DID NOT COMPLETE` block, giving the reason and private log path before stopping. This is the final reported block; no later controller code is displayed.

## What Step 6 must require

Step 6 must refuse promotion unless:

- `approval.yml` exists and says `approved`;
- the package, release and metric family match;
- the approver role is BNR Lead, BNR Analyst or BNR Developer;
- disclosure QA still passes;
- the manifest size and checksum match the approval;
- every public-ready file matches its manifested size and checksum; and
- no suppressed row retains an exact `value`, `numerator` or `denominator`.

Step 6 may promote only `public_ready`. It must never read private results from the reviewer workbook.

## Deaths and future DCO linkage

Deaths remain a separate upstream data stream. Hospital cases and deaths should be prepared separately, linked privately, and unmatched eligible CVD deaths appended as DCO cases to the appropriate incidence-analysis input. This person-level linkage belongs upstream of metric calculation, not in Step 5.

Step 5 remains source-agnostic but must retain accurate public metadata about source coverage.

## Workflow boundary

Generated Step 5 files are immutable review artefacts. Step 5 creates nothing under `outputs/public/`, `site/downloads/files/` or GitHub. Promotion is a separate Step 6 action.

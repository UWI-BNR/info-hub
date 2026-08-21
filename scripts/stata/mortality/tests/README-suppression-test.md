# BNR mortality synthetic suppression test

**Status:** Regression test implemented and passed  
**Test script:** `bnr_mort_test_suppression.do`  
**Synthetic release:** `mort_2099_01`  
**Last validated:** 20 August 2026

## Purpose

This test confirms that the BNR mortality workflow identifies small death
counts and places both primary and related cells on the private
disclosure-control review worklist.

The test runs the real mortality Step 3 and Step 4 code. It is intended to
detect accidental changes to:

- the primary suppression threshold;
- related or complementary-suppression review flags;
- count and percentage reconciliation;
- Step 3 package metadata and QA;
- Step 4 revalidation and human-review outputs; and
- the boundary preventing approval or public output.

This is a development and regression test. It is not part of the routine BNR
operator menu.

## Repository location

Keep this README and the test script together:

```text
scripts/stata/mortality/tests/
├── README.md
└── bnr_mort_test_suppression.do
```

The operational Step 3 and Step 4 files remain in:

```text
scripts/stata/mortality/
```

## Synthetic data design

The test script creates 22 wholly synthetic classified-death records for death
year 2098. No real or confidential death record is used.

| Synthetic outcome | Men | Women | All |
|---|---:|---:|---:|
| BNR-Heart | 3 | 8 | 11 |
| BNR-Stroke | 7 | 4 | 11 |

The values 3 and 4 deliberately fall within the BNR primary suppression range
of 1 to 5. The connected count and percentage cells should therefore also be
identified for related suppression review.

There is deliberately no BNR-Heart/BNR-Stroke overlap in this small test. The
purpose is disclosure-control testing, not comprehensive testing of every Step
2 classification scenario.

## Expected results

A successful run must produce all the following:

| Check | Expected result |
|---|---:|
| Synthetic source records | 22 |
| Step 3 metric rows | 10 |
| Annual count rows | 6 |
| Sex-distribution rows | 4 |
| Primary suppression flags | 4 |
| Related suppression-review flags | 6 |
| Total suppression-worklist rows | 10 |
| Step 3 QA checks passed | 9 |
| Step 4 QA checks passed | 11 |

The test script checks these values directly. A Stata run reaching the end is
not sufficient by itself: the final operational summary must state:

```text
BNR MORTALITY SYNTHETIC SUPPRESSION TEST: PASSED
```

Do not weaken or change an expected result merely to make a failed test pass.
Investigate the code, test data and intended disclosure-control rule first.

## Running the test

Start Stata using the normal BNR repository and path configuration.

### First run

```stata
do "$BNR_STATA/mortality/tests/bnr_mort_test_suppression.do"
```

### Deliberate rerun

Use `replace` only after reviewing the previous test evidence:

```stata
do "$BNR_STATA/mortality/tests/bnr_mort_test_suppression.do" replace
```

The test must not be added to the routine BNR menu. It should be run only after
relevant code changes or as part of formal workflow validation.

## Files created

The script creates a Step 2-shaped synthetic source dataset at:

```text
$BNR_DATA_DERIVED/mortality/y2099/m01/bnr_mort_s2_209901.dta
```

It creates the private synthetic Step 3 and Step 4 package at:

```text
$BNR_STAGING/mortality/burden/mort_2099_01/
```

Important review files within that package include:

```text
review/mort_burden_suppression_review_mort_2099_01.csv
review/mort_burden_suppression_review_mort_2099_01.xlsx
review/mort_s4_review_mort_2099_01.xlsx
review/mort_s4_review_qa_mort_2099_01.csv
review/mort_s4_review_basis_mort_2099_01.csv
```

The principal test log is:

```text
$BNR_PRIVATE_LOGS/bnr_mort_test_suppression.log
```

Step 3 and Step 4 also retain their normal private operational logs.

## Safety boundaries

The synthetic package is marked in three places:

- release ID `mort_2099_01`;
- metadata entry `synthetic_test: true`; and
- package file `SYNTHETIC_TEST_ONLY.txt`.

The package must never be:

- approved;
- promoted to `outputs/public/`;
- copied into the website-download mirror;
- published through Quarto; or
- used as surveillance evidence.

Mortality Step 5 must refuse approval when it detects either the synthetic
metadata marker or the package sentinel file.

## What belongs in Git

Commit only the reproducible test sources:

- `bnr_mort_test_suppression.do`; and
- this `README.md`.

Do not commit generated test artefacts, including:

- the synthetic DTA;
- the `mort_2099_01` staging package;
- generated CSV or Excel files;
- Stata logs; or
- ZIP archives of generated outputs.

A suitable commit message is:

```text
test(mortality): add synthetic suppression regression test
```

## Optional evidence archive and cleanup

If evidence of a successful formal test is required, retain one dated ZIP and
the principal test log outside the public repository, for example:

```text
info-hub-private/quality-assurance/mortality/
└── synthetic-suppression/
    └── 2026-08-20/
        ├── mort_2099_01.zip
        └── bnr_mort_test_suppression.log
```

After confirming the archive, remove the synthetic source dataset and
`mort_2099_01` package from the routine derived-data and staging trees. This
keeps synthetic releases away from normal operator activity. Use File Explorer
or another deliberate, reviewed method; do not use a broad recursive deletion
command.

The committed test script can recreate the complete synthetic package whenever
required.

## When to rerun

Rerun this test after a material change to any of the following:

- `bnr_mort_s3_calc.do`;
- `bnr_mort_s3_stage.do`;
- `bnr_mort_s3_burden.do`;
- `bnr_mort_s4_review.do`;
- the suppression threshold or related-cell rules;
- mortality metric grain or workbook structure; or
- metadata, QA or approval-boundary requirements.

It should also be rerun before final handover of the mortality workflow.

## If the test fails

Do not approve or publish any output from the failed run.

Review, in this order:

1. `bnr_mort_test_suppression.log`;
2. the Step 3 operational log;
3. the Step 4 operational log;
4. the suppression-review CSV;
5. the Step 3 and Step 4 QA receipts; and
6. recent changes to the mortality calculation, staging or review code.

Correct the source code or test design and rerun. Generated outputs must never
be manually edited to manufacture a pass.

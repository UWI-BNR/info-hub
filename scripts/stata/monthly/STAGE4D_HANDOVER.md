# CVD workflow hardening — Stage 4D handover

## Purpose

Stage 4D is a private aggregate estimation pass following the completed Stage
4C deterministic linkage. It retains every individual Stage 4C result
unchanged. It does **not** mark an unresolved death as an estimated DCO.

For each mortality definition and death year it calculates:

\[
p = \frac{A}{L+A},\qquad \widehat{U}_{DCO}=pU,
\]

where `L` is deterministic recorded 0–27-day event links, `A` is deterministic
additional DCOs and `U` is still-unresolved candidates.

The approved hierarchy is:

1. same mortality definition and annual death year, when `L+A >= 20`;
2. same definition with target year ±1, when the annual level is below 20;
3. same definition across all available candidate years, when the three-year
   pool remains below 20; otherwise
4. `insufficient_resolved`, with no central estimate.

The result contains DCO components only:

- lower = `A`;
- central = `A + pU`; and
- upper = `A + U`.

The later metric-construction pass, not this one, adds hospital count `H` to
those components. Primary and Inclusive are independent candidate subsets, not
uncertainty bounds. The result asserts that the Inclusive central DCO component
is never below the Primary component in the same year.

## Install

Copy these three new files into the repository, preserving their paths:

- `scripts/stata/metrics/cvd/bnr_cvd_estimate_unresolved_core.do`
- `scripts/stata/metrics/cvd/bnr_cvd_run_unresolved_estimation.do`
- `scripts/stata/metrics/cvd/tests/test_bnr_cvd_stage4_unresolved_estimation.do`

Stage 4C must have completed successfully. Do not edit the Stage 4C candidate
diagnostic.

## Test first

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_unresolved_estimation.do"
```

Expected final line:

```text
PASS: Stage 4D aggregate unresolved-estimation synthetic tests completed.
```

The test log is private:

`$BNR_PRIVATE_LOGS/bnr_cvd_stage4_unresolved_estimation_test.log`

## Run the private estimator

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_unresolved_estimation.do" 2024 04 2026 07
```

To deliberately replace the two private Stage 4D outputs:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_unresolved_estimation.do" 2024 04 2026 07 replace
```

## Outputs and review

Both outputs are private, in:

`$BNR_PRIVATE/data/derived/cvd_linkage/y2024/m04/mort_y2026_m07/`

- `stage4_unresolved_estimation_cvd_2024_04_mort_2026_07.dta` — private annual
  aggregate components and estimation provenance. Do **not** upload it.
- `stage4_unresolved_estimation_qa_cvd_2024_04_mort_2026_07.csv` — aggregate
  QA, safe to share for review.

Also retain:

`$BNR_PRIVATE_LOGS/bnr_cvd_unresolved_estimation_202404_mort_202607.log`

Check that annual cells select the expected fallback levels; values stay within
their lower/central/upper bounds; no `insufficient_resolved` cell is silently
given a central estimate; and the Primary/Inclusive central-component invariant
passes. Send only the aggregate QA CSV and private log for review.

## Contract record

Before moving to DCO metric construction, add the agreed hierarchy from this
handover to the **Aggregate unresolved-link estimator** section of
`BNR_CVD_WORKFLOW_HARDENING_CONTRACT.md`. It is an approved estimator-hierarchy
specification, not a routine code comment.

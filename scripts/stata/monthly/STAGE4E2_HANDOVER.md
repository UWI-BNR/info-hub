# CVD workflow hardening — Stage 4E-b handover

## Purpose

Stage 4E-b implements the approved private aggregate unresolved-linkage
estimator for Heart and Stroke. It reads the completed Stage 4E-a aggregate
concordance profile; it does not reopen or export person-level linkage data.

It produces annual DCO components separately for:

- Primary and Inclusive mortality definitions; and
- Heart and Stroke certificate families.

The estimator uses only family-concordant evidence. Both-family certificates,
family-discordant linked episodes and matched episodes without a usable family
are retained as explicit exclusions and are never assigned to a subtype.

It does not calculate hospital counts, metrics, rates or public outputs.

## Install

Copy these three files into the repository, preserving their paths:

- `scripts/stata/metrics/cvd/bnr_cvd_estimate_subtype_unresolved_core.do`
- `scripts/stata/metrics/cvd/bnr_cvd_run_subtype_unresolved_estimation.do`
- `scripts/stata/metrics/cvd/tests/test_bnr_cvd_stage4_subtype_unresolved_estimation.do`

Also retain `STAGE4E2_CONTRACT_AMENDMENT.md` with the hardening design notes.

Stage 4E-a must have completed successfully. Its aggregate concordance DTA is
the required input; the estimator does not read the Stage 4C person-level DTA.

## Test first

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_subtype_unresolved_estimation.do"
```

Expected final line:

```text
PASS: Stage 4E-b subtype unresolved-estimation synthetic tests completed.
```

The private test log is:

`$BNR_PRIVATE_LOGS/bnr_cvd_stage4_subtype_unresolved_estimation_test.log`

## Run the private estimator

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_unresolved_estimation.do" 2024 04 2026 07
```

To deliberately replace the two private outputs:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_unresolved_estimation.do" 2024 04 2026 07 replace
```

## Outputs and review

All outputs are private, in:

`$BNR_PRIVATE/data/derived/cvd/y2024/m04/linkage/mort_y2026_m07/`

- `stage4_subtype_unresolved_estimation_cvd_2024_04_mort_2026_07.dta` —
  annual aggregate DCO components. Do not upload it.
- `stage4_subtype_unresolved_estimation_qa_cvd_2024_04_mort_2026_07.csv` —
  compact aggregate QA, suitable for review.

Also retain:

`$BNR_PRIVATE_LOGS/bnr_cvd_subtype_unresolved_estimation_202404_mort_202607.log`

Review the QA CSV and log before metric construction. In particular, check:

1. each definition/subtype has plausible counts of concordant recorded links,
   deterministic additional DCOs and unresolved candidates;
2. excluded discordant and family-unclassified linked records are visible;
3. annual, three-year, all-years and insufficient-resolved fallbacks are
   plausible;
4. Primary/Inclusive subtype central-component invariant failures equal zero;
   and
5. lower is no greater than central, and central is no greater than upper.

Do not treat these components as public incidence counts or rates. The next
work block combines approved components with hospital metrics and population
denominators under the full disclosure-control workflow.

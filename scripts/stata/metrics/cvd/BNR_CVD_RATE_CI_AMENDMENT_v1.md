# CVD statistical confidence-interval amendment

**Status:** implementation candidate for local testing  
**Date:** 28 August 2026

This bounded amendment adds 95% statistical confidence intervals to
`CVD-INCIDENCE-001` without changing any existing central estimate or the
existing DCO linkage uncertainty limits.

## Frozen methods

| Rate | 95% statistical CI |
|---|---|
| Hospital crude | Exact Poisson / Garwood |
| Hospital age-standardised | Fay-Feuer gamma |
| Hospital + DCO crude | Conditional gamma using the central pseudo-count |
| Hospital + DCO age-standardised | Conditional Fay-Feuer gamma using central age-specific pseudo-counts |

The DCO-enhanced intervals are conditional on the central DCO estimate. They do
not incorporate linkage/ascertainment uncertainty, unresolved-DCO estimation
uncertainty, population uncertainty, or standard-population uncertainty.

The existing `linkage_lower_value` and `linkage_upper_value` fields remain a
separate uncertainty concept and must be unchanged by this amendment.

## Public fields

The existing `bnr_cvd_public_metric_v2` schema is retained with four additive
optional fields:

- `ci_lower_value`
- `ci_upper_value`
- `ci_level`
- `ci_method`

These fields are populated only for `CVD-INCIDENCE-001`. Count and percentage
rows retain blank CI fields.

If a rate row is disclosure-protected, `ci_lower_value` and `ci_upper_value`
are blanked with the point estimate. `ci_level` and `ci_method` remain because
they are non-disclosive method metadata.

## Implementation shape

The existing rate core is deliberately left unchanged. A new bounded helper,
`bnr_cvd_add_rate_confidence_intervals.do`, runs immediately after it from the
existing private rate controller. This reduces regression risk in the already
hardened DCO/linkage construction.

Step 5 Stage 1 validates the CI contract. Stage 8 blanks CI limits on protected
rows. Stage 9 audits the CI contract before approval.

No changes are required to Steps 1-3 or Step 6.

## Local test order

1. `do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_rate_confidence_intervals.do"`
2. `do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage5_expanded_end_to_end.do"`

Only after both pass should the 2024-05 Step 4-6 release be rebuilt.

## Operational documentation

This is not a new menu/workflow step. It is a bounded extension inside the
existing Step 4 rate calculation and existing Step 5 disclosure contract.

After the implementation passes on the live 2024-05 release, fold the method
description and the four public fields into the CVD technical handover / Ops
documentation. Do not document the amendment as an additional analyst action.

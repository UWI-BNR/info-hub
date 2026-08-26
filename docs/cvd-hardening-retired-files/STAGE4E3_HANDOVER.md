# CVD workflow hardening — Stage 4E-c handover

Stage 4E-c reconciles the independent Stage 4E-b Heart and Stroke DCO
components to the fixed All-CVD Stage 4D total. It creates three mutually
exclusive aggregate reporting categories: `heart`, `stroke` and
`mixed_unallocated`.

The independent Stage 4E-b components are retained in the output as private
`unconstrained_*` diagnostics. The `reconciled_*` components are the approved
inputs for later subtype metric construction. For each definition and year:

```text
All-CVD = Heart + Stroke + mixed/unallocated
```

Lower and upper components are reconciled if necessary by proportional
scaling. Central unresolved subtype components are proportionally scaled only
when their independent sum exceeds the All-CVD unresolved component. Any
remaining All-CVD component is assigned to `mixed_unallocated`. All three
reconciled components are non-negative and sum exactly to All-CVD at each
bound.

This is a private aggregate model pass. It does not reopen person linkage,
calculate rates, suppress rows, approve, promote or publish.

## Install and test

Copy the three DO files under `scripts/stata/metrics/cvd/` and retain this
handover. Run the synthetic test first:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_subtype_reconciliation.do"
```

Then run the private reconciliation in one CLI line:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_reconciliation.do" 2024 04 2026 07 replace
```

The QA CSV and private log must be reviewed before rates are constructed.

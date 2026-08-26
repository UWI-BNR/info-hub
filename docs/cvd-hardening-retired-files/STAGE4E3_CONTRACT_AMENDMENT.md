# Stage 4E-c contract amendment — constrained subtype reconciliation

The All-CVD estimate is the fixed combined CVD total. Heart and Stroke are
mutually exclusive subtype reporting categories, with a third private/public
category named `mixed_unallocated` for CVD evidence that cannot be assigned
reliably to either subtype.

The reconciled components must satisfy, separately for Primary and Inclusive
definitions and for every year and lower/central/upper bound:

```text
All-CVD = Heart + Stroke + mixed_unallocated
```

Stage 4E-b independent subtype estimates remain private diagnostics. Stage
4E-c applies a pre-specified constrained reconciliation: subtype components
are retained when compatible with the All-CVD bound; when their sum exceeds
the All-CVD component, the subtype unresolved components are proportionally
scaled, and any residual is assigned to `mixed_unallocated`. The resulting
components are non-negative and sum exactly to All-CVD.

This is a pragmatic aggregate reconciliation for imperfect linkage evidence,
not a person-level reclassification. The unreconciled estimates and scaling
diagnostics are retained for sensitivity analysis and audit.

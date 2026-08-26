# Stage 4E-c contract amendment — joint subtype allocation

Heart, Stroke and mixed/unallocated CVD are mutually exclusive reporting
categories. The All-CVD Stage 4D unresolved DCO component is the fixed total.
Observed deterministic additional-DCO composition is used to estimate the
category allocation probabilities, with the approved annual, three-year and
all-years fallback hierarchy.

For every definition, year and bound, the reconciled components must satisfy:

```text
All-CVD = Heart + Stroke + mixed_unallocated
```

Genuinely missing or unusable category information remains visible in private
QA and is not silently reclassified. The previous independent subtype
estimates are retained only as private sensitivity diagnostics.

# Stage 4E-b contract amendment — national Heart and Stroke incidence

## Status

Approved implementation amendment following review of the Stage 4E-a private
family-concordance profile.

This amendment extends the CVD hardening contract. It does not alter the
existing hospital-only series or the completed All-CVD Stage 4D estimator.

## Approved subtype-attribution rule

For each mortality definition, a record contributes to a private subtype
estimation stratum only when the certificate family is unambiguous.

| Certificate and episode evidence | Heart estimator | Stroke estimator | All-CVD accounting |
|---|---:|---:|---:|
| Heart-only certificate, Heart/Both 0--27-day episode | Recorded link | — | Recorded link |
| Stroke-only certificate, Stroke/Both 0--27-day episode | — | Recorded link | Recorded link |
| Heart-only certificate, no 0--27-day episode | Deterministic additional DCO | — | Deterministic additional DCO |
| Stroke-only certificate, no 0--27-day episode | — | Deterministic additional DCO | Deterministic additional DCO |
| Heart-only/Stroke-only certificate, pending identity | Unresolved candidate for stated family | Unresolved candidate for stated family | Unresolved candidate |
| Heart-only certificate with Stroke-only episode, or converse | Exclude | Exclude | Recorded All-CVD episode |
| Both-family certificate | Exclude | Exclude | All-CVD only |
| Matched episode with no usable family | Exclude | Exclude | Retain existing All-CVD outcome |
| Unclassified certificate family | Exclude | Exclude | All-CVD only |

`cvd_sub_p` and `cvd_sub_i` are not used to force a subtype assignment. The
Stage 4E-a evidence showed that inclusive both-family certificates retain the
source label `Heart/Stroke unresolved`.

## Aggregate unresolved-linkage estimator

For each mortality definition, subtype and death year, use only concordant
resolved evidence:

\[
\hat p_{subtype} = \frac{A_{subtype}}{L_{subtype}+A_{subtype}}.
\]

Apply this fraction only to unresolved candidates with the same unambiguous
certificate family. The fallback hierarchy is:

1. target year where at least 20 resolved subtype candidates are available;
2. target year plus/minus one calendar year within the same mortality definition
   and subtype, where at least 20 are available;
3. all available years within the same mortality definition and subtype, where
   at least 20 are available; or
4. insufficient resolved evidence: no central subtype estimate.

For deterministic additions `A`, unresolved candidates `U` and selected
fraction `p`, the private subtype DCO components are:

\[
\text{lower}=A,\qquad
\text{central}=A+pU,\qquad
\text{upper}=A+U.
\]

The Primary/Inclusive central component must be checked separately for Heart
and Stroke in every comparable annual cell.

## Interpretation and public boundary

Heart and Stroke are specific, family-concordant estimates. Their sum is not
required, and must not be presented as equal, to All-CVD. This reflects
intentional treatment of mixed and indeterminate evidence, not a calculation
error.

Stage 4E-b creates private aggregate components only. A later metric-build
stage will determine the approved count and rate series, disclosure equations,
public schema rows and review package.

# Stage 4E-a contract note — Heart/Stroke subtype extension

The BNR CVD workflow will evaluate private national Heart and Stroke DCO-
incidence estimates in addition to the completed All-CVD estimate. The first
pass is a private aggregate family-concordance profile using already approved
Stage 4C linkage evidence.

This profile does not alter the All-CVD estimator or public metric lattice. No
Heart/Stroke DCO attribution rule is adopted until review of the aggregate
concordance and `cvd_sub_p`/`cvd_sub_i` crosswalk outputs.

The eventual subtype specification must state, separately for Primary and
Inclusive mortality definitions:

1. the mapping of resolved mortality-family values to Heart, Stroke or
   indeterminate;
2. the treatment of a certificate with both Heart and Stroke evidence;
3. the treatment of family-discordant linked episodes;
4. the subtype-specific unresolved-estimation strata and fallback hierarchy;
5. whether the initial DCO-enhanced rates are crude, age-standardised, or both;
   and
6. the additional disclosure equations and suppression rules.

Until that decision is approved, mixed/indeterminate certificate evidence is
retained in private All-CVD design QA only and is not assigned to either
subtype.

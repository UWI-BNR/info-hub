# CVD annual rate construction and QA

**Integrated release:** 1.0.7 (26 August 2026)

Install this delivery as one unit. Every included DO-file header must report
Version 1.0.7 and the supplied release manifest records the exact files and
SHA-256 checksums.

This delivery implements the private production layer for annual CVD rates.
It does not create, approve or promote public output.

## Fixed public rate lattice

```text
Hospital-only:
  3 event types × 3 sex groups × 2 rate forms

Hospital + DCO:
  3 event types × 3 sex groups × 2 mortality definitions × 2 rate forms
  with lower, central and upper estimates
```

The event types are `all_cvd`, `heart` and `stroke`; sex groups are `all`,
`female` and `male`; rate forms are crude (`age_group = all`) and directly
age-standardised (`age_group = age_standardised`). The production grid also
contains five-year age groups and `age_unknown`, but neither is public.

## Installation

Copy the files under `scripts/` to their matching locations in `info-hub`.

## One-time reference assets

The production controller expects these exact private files:

```text
$BNR_PRIVATE/data/reference/population/wpp2024_brb_population_2010_2035_5y.dta
$BNR_PRIVATE/data/reference/population/who_world_standard_2000_2025.dta
```

The small WHO DTA is supplied under `reference_assets/` in this release. Copy
it to the second path above. The validated WPP Barbados asset is not recreated
by the production controller.

Create a private WPP 2024 Barbados population DTA containing exactly:

```text
year          integer calendar year, 2010 onwards
sex           all, female, male
age_group     age_0_4 ... age_95_99, age_100_plus
population    positive population estimate
```

Then run:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_prepare_rate_reference.do" "<private WPP 2024 Barbados input>.dta" "$BNR_PRIVATE/data/reference/population/wpp2024_brb_population_2010_2035_5y.dta" "$BNR_PRIVATE/data/reference/population/who_world_standard_2000_2025.dta" "$BNR_PRIVATE/data/reference/population/wpp2024_brb_population_2010_2035_5y_qa.csv" replace
```

The preparation script is retained as the reproducible asset-building and QA
route. It writes the fixed WHO World Standard weights and normalises their
published rounded percentages to sum exactly to one. It also requires complete
WPP coverage for 2010--2035, 21 age groups for every year/sex, and exact
all-sex = female + male population accounting.

## Test first

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_prepare_rate_reference.do"
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_construct_incidence_rates.do"
```

## Private production run

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_incidence_rate_estimation.do" 2024 04 2026 07 replace
```

The run consumes the completed Stage 4C linkage diagnostic and Stage 4E-c
joint subtype-estimation output. It writes a private public-shaped candidate
rate dataset, a private component dataset and a compact QA CSV in the existing
release-specific CVD-linkage directory.

Only complete calendar years are estimated. Therefore a CVD source release
through April 2024 produces annual rates for 2010--2023; it does not divide a
partial 2024 numerator by a full-year population denominator.

The private candidate carries the schema/release/method identifiers and the
WPP release, extraction date, country, unit, estimate/projection basis and WHO
standard identifier needed for an auditable rate package. Disclosure fields
are added only by the later review and promotion stages.

## Embedded acceptance QA

- Atomic subtype × sex × age DCO components equal the All-CVD lower, central
  and upper anchors.
- Every DCO-enhanced rate satisfies lower ≤ central ≤ upper.
- The only public-shaped event types and sexes are All-CVD/Heart/Stroke and
  all/female/male.
- The standardised rows require complete WPP 2024 population and WHO weight
  coverage.
- The public-shaped rate lattice contains exactly 54 rows per complete year.
- Primary/Inclusive subtype ordering is reported as a diagnostic because
  subtype classifications are alternative, non-nested routes. Pooled
  All-CVD ordering remains a hard acceptance check.
- All-sex crude numerators include female, male and any unknown-sex records.
- Crude rows retain numerators and denominators. Directly standardised rows do
  not expose a misleading single numerator or denominator.
- Legacy imported DCO rows are excluded from hospital-event numerators.

Candidate and component DTAs are written only after every embedded acceptance
assertion succeeds. The QA CSV may still be retained after a failed run to aid
diagnosis; it is not a public output.

Disclosure review remains a later Step 5 responsibility. It must jointly
evaluate all related All-CVD, Heart, Stroke, Primary/Inclusive and bound rows,
because their arithmetic relationships can reveal otherwise private quantities.

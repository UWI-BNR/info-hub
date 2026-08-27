# CVD workflow hardening — Stage 4E-a handover

## Purpose

Stage 4E-a is the first implementation pass for the approved Heart and Stroke
national-incidence extension. It is a **private aggregate design profile**. It
does not allocate DCOs to Heart or Stroke, estimate unresolved candidates,
calculate rates, alter the completed All-CVD Stage 4D estimate, or create any
public output.

It uses the completed Stage 4C diagnostic to profile, separately for Primary
and Inclusive mortality definitions:

- death-certificate family: Heart-only, Stroke-only, both or unclassified;
- linked 0--27-day episode family: Heart-only, Stroke-only, both, no event or
  pending identity;
- concordant and discordant linked records; and
- proposed DCO-eligibility routes for design review only.

It also produces a crosswalk of the existing mortality classifier's
`cvd_sub_p` and `cvd_sub_i` values against the broad Heart/Stroke flags. That
crosswalk is the evidence needed before deciding whether either resolved-family
field can be used as a deterministic tie-breaker for certificates mentioning
both families.

## Install

Copy these three files into the repository, preserving their paths:

- `scripts/stata/metrics/cvd/bnr_cvd_profile_subtype_concordance_core.do`
- `scripts/stata/metrics/cvd/bnr_cvd_run_subtype_concordance_profile.do`
- `scripts/stata/metrics/cvd/tests/test_bnr_cvd_stage4_subtype_concordance.do`

Stage 4C must have completed successfully. This profile does not use or alter
the Stage 4D unresolved-estimation output.

## Test first

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_subtype_concordance.do"
```

Expected final line:

```text
PASS: Stage 4E-a subtype concordance synthetic tests completed.
```

The private test log is:

`$BNR_PRIVATE_LOGS/bnr_cvd_stage4_subtype_concordance_test.log`

## Run the private profile

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_concordance_profile.do" 2024 04 2026 07
```

To deliberately replace the three private outputs:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_subtype_concordance_profile.do" 2024 04 2026 07 replace
```

## Outputs and review

All outputs are private, in:

`$BNR_PRIVATE/data/derived/cvd/y2024/m04/linkage/mort_y2026_m07/`

- `stage4_subtype_concordance_cvd_2024_04_mort_2026_07.dta` — detailed annual
  aggregate concordance cells. Do not upload it.
- `stage4_subtype_concordance_qa_cvd_2024_04_mort_2026_07.csv` — compact
  aggregate QA, suitable for review.
- `stage4_subtype_source_resolution_cvd_2024_04_mort_2026_07.csv` — aggregate
  classifier crosswalk, suitable for review.

Also retain:

`$BNR_PRIVATE_LOGS/bnr_cvd_subtype_concordance_202404_mort_202607.log`

Review the two CSV files and log before agreeing an attribution rule. In
particular, assess the frequency of both-family certificates, source-family
values among those certificates, subtype-discordant linked episodes and the
number of deterministic no-window-event candidates available for each subtype.

Do not use the profile as a DCO estimate. The next pass will implement only
the allocation rule explicitly agreed from this evidence.

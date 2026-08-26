# CVD workflow hardening — Stage 4B handover

## Purpose

Stage 4B is a deliberately narrow, private diagnostic pass within Stage 4. It
tests the cleanest deterministic linkage route before name-based matching is
introduced:

1. **L01 person linkage:** a unique valid exact NRN with no material source
   contradiction; then
2. **episode linkage:** whether that linked person has a Heart or Stroke event
   from zero to 27 days before death.

It is not the completed linkage engine. It does not apply L02/L03 name rules,
estimate unresolved records, construct final additional-DCO records, calculate
metrics, create a Step 5 review package, or make public output.

## Install

Copy these three new files into the repository, preserving their paths:

- `scripts/stata/metrics/cvd/bnr_cvd_l01_episode_core.do`
- `scripts/stata/metrics/cvd/bnr_cvd_run_l01_episode_diagnostic.do`
- `scripts/stata/metrics/cvd/tests/test_bnr_cvd_stage4_l01_episode.do`

Stage 3 inputs and the completed Stage 4A profile must already be present. Do
not edit either generated input dataset.

## Test first

Run this as one single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_l01_episode.do"
```

Expected final line:

```text
PASS: Stage 4B L01 and episode synthetic tests completed.
```

The test log is private:

`$BNR_PRIVATE_LOGS/bnr_cvd_stage4_l01_episode_test.log`

## Run the private diagnostic

Run this as one single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_l01_episode_diagnostic.do" 2024 04 2026 07
```

If deliberately rerunning the same diagnostic, use:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_l01_episode_diagnostic.do" 2024 04 2026 07 replace
```

## Outputs and review

Both outputs are private, in:

`$BNR_PRIVATE/data/derived/cvd_linkage/y2024/m04/mort_y2026_m07/`

- `stage4_l01_episode_diagnostic_cvd_2024_04_mort_2026_07.dta` — confidential
  candidate-level linkage provenance. Do **not** upload or distribute it.
- `stage4_l01_episode_qa_cvd_2024_04_mort_2026_07.csv` — aggregate counts,
  safe to share for review.

Also retain the private controller log:

`$BNR_PRIVATE_LOGS/bnr_cvd_l01_episode_202404_mort_202607.log`

Check the aggregate QA before proceeding:

- L01 matches have a unique valid exact NRN, no known sex conflict and no
  CVD group demographic conflict.
- `recorded_event_0_27_days` is limited to a same-person Heart/Stroke event
  in the agreed episode window.
- a remote prior event is retained and does not block
  `provisional_additional_dco`.
- any record not matched by L01 remains pending rather than being labelled
  unresolved or becoming a final DCO.

The Stage 4A profile's 3,084 sex-consistent exact-NRN crosswalk rows is a useful
comparison, not an assertion for this diagnostic. L01 additionally excludes
invalid NRN date prefixes, duplicate mortality NRNs, contradictory CVD DOB
groups and explicit NRN/DOB contradictions.

## Next

Send the aggregate QA CSV and private log for review. Keep the diagnostic DTA
private. Once that pass is accepted, the next Stage 4 sub-pass adds L02/L03 to
the same provenance and episode framework.

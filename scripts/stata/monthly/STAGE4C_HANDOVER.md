# CVD workflow hardening — Stage 4C handover (package 1.0.4)

## Purpose

Stage 4C extends the completed private Stage 4B diagnostic without changing
it. It preserves every L01 result, then applies the remaining deterministic
person rules and repeats the same episode classification for every final
deterministic match:

1. **L02:** exact normalized full name, canonical sex and exact
   explicit/NRN-derived date of birth, with one CVD person candidate; and
2. **L03:** exact first/surname boundary tokens in either order, canonical sex
   and exact DOB where available or a compatible age fallback, with one CVD
   person candidate.

The age fallback is deliberately narrow. The mortality record must explicitly
record the age unit as **Years** (`mortality_agetxt == "6"`), and the inferred
CVD age at death must be within one completed calendar year. A DOB mismatch is
never rescued by age.

Valid NRNs remain text. Their `yymmdd` prefix is used only to derive a DOB when
calendar-valid and when one century is supported by age/date evidence. It is
not a stand-alone L02/L03 match. L01 identifier contradictions and duplicate
mortality NRNs remain pending; name matching does not override them.

The pass is private only. It does not estimate unresolved candidates, create
final DCO records or metrics, call Steps 5/6, or create public output.

## Install

Copy these three new files into the repository, preserving their paths:

- `scripts/stata/metrics/cvd/bnr_cvd_l02_l03_episode_core.do`
- `scripts/stata/metrics/cvd/bnr_cvd_run_l02_l03_episode_diagnostic.do`
- `scripts/stata/metrics/cvd/tests/test_bnr_cvd_stage4_l02_l03_episode.do`

Stage 3 inputs and the completed Stage 4B L01 diagnostic must already be
present. Do not edit either generated dataset.

## Test first

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_l02_l03_episode.do"
```

Expected final line:

```text
PASS: Stage 4C L02/L03 and episode synthetic tests completed.
```

The private test log is:

`$BNR_PRIVATE_LOGS/bnr_cvd_stage4_l02_l03_episode_test.log`

## Run the private diagnostic

Run this single Stata command:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_l02_l03_episode_diagnostic.do" 2024 04 2026 07
```

To deliberately replace the Stage 4C outputs:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_l02_l03_episode_diagnostic.do" 2024 04 2026 07 replace
```

## Outputs and review

Both outputs are private, in:

`$BNR_PRIVATE/data/derived/cvd_linkage/y2024/m04/mort_y2026_m07/`

- `stage4_l01_l03_episode_diagnostic_cvd_2024_04_mort_2026_07.dta` —
  candidate-level linkage provenance. It is confidential: do **not** upload
  or distribute it.
- `stage4_l01_l03_episode_qa_cvd_2024_04_mort_2026_07.csv` — aggregate counts,
  safe to share for review.

Also retain the private controller log:

`$BNR_PRIVATE_LOGS/bnr_cvd_l02_l03_episode_202404_mort_202607.log`

Before moving to unresolved estimation, review the aggregate QA for:

- preserved L01 matches plus new L02 and L03 matches;
- the L03 split between exact-DOB and years-only age-fallback matches;
- L02/L03 ambiguous candidate sets, which must remain pending;
- identifier-conflict/duplicate-NRN candidates still blocked from name rules;
- final 0–27-day recorded-event links, provisional additional DCOs and remote
  prior-event indicators; and
- an exact partition of mortality candidates into final deterministic matches
  and remaining pending candidates.

Send only the aggregate QA CSV and the private log for review. The next stage
will estimate unresolved candidates at aggregate level; it must not relabel an
individual pending candidate as a final DCO.

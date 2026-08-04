# Synthetic low-count incidence input
## Ian Hambleton
## 4th August 2026

This pack tests the analyst-led disclosure review in the BNR incidence briefing workflow. It contains no genuine BNR events or identifiers and must never be published as a real output.

## Files

- `bnr_cvd_input_count_202401_v01_mock_low_counts.dta` — ready-made synthetic input.
- `bnr_cvd_input_count_202401_v01_mock_low_counts.yml` — companion test metadata.
- `create_mock_incidence_input.do` — readable Stata code that recreates both files.

The DTA has the same 11-variable contract as the supplied operational count input: `eid`, `dco`, `dco_alt`, `etype`, `doe`, `yoe`, `moe`, `sex`, `agey`, `age5`, and `age70`.

## Designed test results

The mock contains 919 synthetic event records for 2010–2023. Most annual event-type/sex cells contain 18 hospital events plus 2 DCO events, allowing the incidence analysis to run. Selected cells are deliberately small.

Under the current `cvd_incidence.do` rule—flag `event > 0 & event < 6`—`disclosure_flags.csv` should contain exactly **18 flag rows**:

| Year | Event | Sex | Incidence version | Expected count |
|---:|---|---|---|---:|
| 2016 | Stroke | Female | With DCO | 4 |
| 2017 | AMI | Female | Without DCO | 2 |
| 2017 | AMI | Female | With DCO | 2 |
| 2017 | AMI | Male | Without DCO | 3 |
| 2017 | AMI | Male | With DCO | 3 |
| 2017 | AMI | Both | Without DCO | 5 |
| 2017 | AMI | Both | With DCO | 5 |
| 2018 | AMI | Female | Without DCO | 2 |
| 2018 | AMI | Female | With DCO | 5 |
| 2019 | Stroke | Male | Without DCO | 2 |
| 2019 | Stroke | Male | With DCO | 2 |
| 2020 | AMI | Male | Without DCO | 5 |
| 2021 | Stroke | Female | Without DCO | 4 |
| 2022 | Stroke | Female | Without DCO | 4 |
| 2023 | Stroke | Female | Without DCO | 3 |
| 2023 | Stroke | Female | With DCO | 5 |
| 2023 | AMI | Male | Without DCO | 1 |
| 2023 | AMI | Male | With DCO | 5 |

Three zero-count cells test the deliberate limitation of the automatic worklist: because the rule flags only positive values below 6, these should **not** appear as automatic flags.

| Year | Event | Sex | Incidence version | Expected count |
|---:|---|---|---|---:|
| 2016 | Stroke | Female | Without DCO | 0 |
| 2022 | AMI | Female | Without DCO | 0 |
| 2022 | AMI | Female | With DCO | 0 |

Three cells should equal exactly 6 and should **not** be flagged under an `n < 6` rule:

| Year | Event | Sex | Incidence version | Expected count |
|---:|---|---|---|---:|
| 2022 | Stroke | Female | With DCO | 6 |
| 2023 | Stroke | Male | Without DCO | 6 |
| 2023 | Stroke | Male | With DCO | 6 |

The design also tests two judgement points:

- Adding DCO events sometimes moves an unsafe hospital-only count to 6 or 7. The hospital-only result must still be reviewed.
- In 2017, female AMI is 2 and male AMI is 3, producing a combined-sex count of 5. This helps the analyst consider components, totals, and complementary disclosure together.

## Safe local test method

Do not overwrite the genuine Step 3 input.

1. Run `create_mock_incidence_input.do`, optionally supplying a test output folder.
2. Make a temporary test copy of `cvd_incidence.do`.
3. In that temporary copy only, set `input_dataset_id`, `input_file`, and `input_yml` to the supplied mock DTA and YML.
4. Use a clearly non-operational briefing version, such as `99`, so the staging package cannot be confused with a real release.
5. Run Briefing Step 1 and inspect `review/disclosure_flags.csv` before attempting approval.
6. Confirm the 18 expected flag rows, the three unflagged zero cells, and the three unflagged threshold cells.
7. Do not approve or publish this test package. Remove the temporary staging package after the test.

The mock checks whether the worklist prompts the analyst correctly. It does not prove that a briefing is disclosure-safe: the complete datasets, figures, totals, components, narrative, differencing risk, and external information still require human review.


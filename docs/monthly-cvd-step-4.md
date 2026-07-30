# Monthly CVD workflow — Step 4

## Purpose

Step 4 calculates selected CVD metric families from completed Step 3 inputs and creates an exact, aggregate review package in **private staging**. It also applies the BNR primary-suppression classification so Step 5 receives a complete suppression worklist.

The first implemented family is `burden`, covering `CVD-BURDEN-001` and `CVD-BURDEN-002`.

## Responsibilities

| Component | Responsibility |
|---|---|
| `monthly/bnr_step4_metrics.do` | Release selection, metric-family authorisation, replacement authorisation, private paths, logging, orchestration and final summary |
| `metrics/cvd/bnr_step4_cvd_burden.do` | Burden definitions, exclusions, dimensions, calculations, suppression classification and metric-specific QA |
| `common/bnr_step4_stage_metric.do` | Standard exact datasets, metadata, QA, suppression worklist and readme packaging under private staging |

The staging helper contains no metric-specific analytical decision. The burden calculator creates no staging, public or website file directly.

## Command contract

```stata
do "$BNR_STATA/monthly/bnr_step4_metrics.do" year month metric_family [replace]
```

Currently implemented:

```stata
do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 burden
```

`replace` is optional, must be final, and authorises replacement only within the selected release-specific private staging package.

## Input contract

Step 4 reads:

```text
$BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/
    bnr_cvd_input_count_YYYYMM_v01.dta
    bnr_cvd_input_count_YYYYMM_v01.yml
```

Required variables are `eid`, `dco`, `etype`, `doe`, `yoe`, `moe`, `sex` and `age70`. The event identifier must be unique. Event types, DCO status, age groups and event-date structure must be valid, and no event may fall after the selected month-end.

Resident eligibility is guaranteed by Step 1. An upstream safeguard also ensures that a person cannot contribute more than one event within a given month. A monthly event frequency therefore equals the monthly number of contributing people.

## Burden rules

- DCO-only events are excluded.
- 2009 is excluded.
- `CVD-BURDEN-001` retains its annual event-type/sex counts, its all-CVD monthly counts by sex, and its quarterly event-type/sex counts.
- In addition, it contains exactly two annual age rows: All CVD / all sex / `under_70`, and All CVD / all sex / `70_plus`.
- No AMI-by-age, stroke-by-age, sex-by-age, monthly-age or quarterly-age rows are produced.
- `CVD-BURDEN-002` retains its annual event-type and sex distributions. It does not create an age distribution.
- Annual, same-calendar-month and same-calendar-quarter five-year comparator means are calculated in Stata.
- `status_flag` records analytical status only, such as `final` or `insufficient_history`.

## Statistical disclosure-control policy

BNR uses the [Handbook on Statistical Disclosure Control for Outputs](https://ukdataservice.ac.uk/app/uploads/sdc-handbook-v2.0.pdf) as its guiding reference. The Handbook uses a risk-based output-checking approach: related outputs must be considered together, and a threshold alone does not make an output safe. It does not prescribe 6 as a universal threshold.

BNR's operational policy `bnr_sdc_v1` is:

| Frequency | Step 4 classification | Required before publication |
|---:|---|---|
| `0` | Not primary suppressed solely because it is zero | Retain, subject to the whole-release review |
| `1–5` | `primary_suppression = 1` | Remove the exact value and all revealing derivatives |
| `6+` | Not automatically primary suppressed | Review for complementary disclosure and other risks |

The rule applies to the frequency supporting a result, not merely to the displayed number. Consequently, a percentage is flagged when its numerator or denominator is from 1 to 5. Comparator rows derived from one or more primary-suppression cells are separately flagged for linked review.

### Annual All-CVD age safeguard

`age70` is a private Step 3 input: `0` is under 70, `1` is 70 or older, and missing remains missing. No public missing-age row is created.

When a year has 1–5 missing-age records, the all-age count minus the two published age counts would reconstruct that small value. Step 4 therefore flags the complete two-row annual age panel, and any five-year comparator that includes an affected year, for Step 5 derived suppression. Step 5 retains the affected rows but publishes `*`, while the all-age annual count remains available.

Step 4 does **not** blank or replace values. Exact results are needed for an informed human review and remain inside private staging. It records:

- `sdc_policy`;
- `primary_suppression_threshold`;
- `primary_suppression`;
- `related_primary_cells`;
- `related_suppression_review`;
- `suppression_review`; and
- `suppression_reason`.

The private field `age_distribution_withheld` is present in the Step 4 staging package so reviewers can understand the safeguard. It must not appear in a Step 5 public candidate or approved public output.

Complementary, or secondary, suppression is a Step 5 task because it requires consideration of totals, subtotals, related tables, charts, tooltips, downloads and earlier releases together. A cell of 6 or more may therefore still need suppression if it would reveal a primary-suppressed value by subtraction or differencing.

## Private staging package

Each run creates:

```text
$BNR_STAGING/metrics/cvd/burden/cvd_YYYY_MM/
    datasets/
    metadata/
    review/
        cvd_burden_qa_cvd_YYYY_MM.csv
        cvd_burden_suppression_review_cvd_YYYY_MM.csv
    readme.txt
```

`$BNR_STAGING` must point outside the Git repository, normally to:

```text
$BNR_PRIVATE/outputs/staging
```

The repository `.gitignore` also excludes `/outputs/staging/` as a backstop, but `.gitignore` is not the confidentiality boundary.

The package contains release-stamped and `current` DTA/CSV pairs, YAML receipts, `metric_package.yml`, the metric QA CSV and the suppression-review CSV. The release-stamped and `current` datasets must be identical.

`package_status: staging`, `public_ready: false` and `exact_values_retained_in_private_staging: true` make the boundary explicit.

## Automated acceptance criteria

The run must stop if:

- either Step 3 input file is absent;
- the selected staging package already exists without `replace`;
- required variables or valid event structure are absent;
- `eid` is not unique;
- an event exceeds the selected month-end;
- the aggregate output violates its variable contract;
- an individual identifier is found in the aggregate data;
- count, percentage or distribution reconciliation fails;
- annual and monthly all-CVD totals differ;
- an age group outside `all`, `under_70` or `70_plus` enters the metric output;
- an age-specific row is anything other than an annual All-CVD, all-sex count or its comparator;
- the policy is not `bnr_sdc_v1` with a minimum publishable frequency of 6;
- any frequency from 1 to 5 is misclassified;
- a comparator linked to a primary-suppression cell is not flagged; or
- any required staging artefact is absent.

## Required Step 5 suppression review

Step 5 must create and approve a separate disclosure-controlled `public_ready` copy. The reviewer must confirm that:

1. every primary-suppression row has its exact `value`, `numerator`, `denominator` and other revealing fields removed as applicable;
2. percentages, comparators and other derivatives do not reveal a suppressed frequency;
3. complementary suppression prevents reconstruction from totals and sibling cells;
4. monthly, quarterly, annual and comparator series do not permit differencing of suppressed results;
5. datasets, tables, charts, labels, tooltips and downloads all use the same disclosure-controlled values;
6. no hidden raw-value field survives in the public-ready package;
7. any decision to publish at a broader time resolution is consistent and documented, rather than applied only to an inconvenient month; and
8. the final suppression report records zero reconstructable primary cells.

Step 5 approval must be tied to fingerprints of the exact public-ready files. If any approved file changes, approval is invalid and Step 6 must refuse promotion.

## Workflow boundary

Step 4 creates no `approval.yml`, public package, website mirror, ZIP, Quarto render or deployment. Never copy its exact staging datasets directly into `outputs/public` or `site/downloads/files`.

Rate, Outcome, Hospital use, Data quality and Care performance will be added as separate analyst-owned calculation files called by the same controller. Mortality counts and rates will require a separately prepared mortality input dataset.

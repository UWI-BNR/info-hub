# Mortality rate dashboard update

## Included files

- `site/surveillance/cvd/metrics/mortality/index.qmd`
- This readme

The approved public mortality CSV and its metadata are unchanged and are not included in this update package.

## Installation

From the repository root, extract the ZIP while preserving its repository-relative paths. The updated QMD replaces the existing file at `site/surveillance/cvd/metrics/mortality/index.qmd`.

## Changes

- Added an annual Mortality rate view with Primary and Inclusive definitions.
- Added CVD type, sex, crude-rate and age-standardised-rate controls.
- Read released mortality rates and statistical confidence intervals directly from the public CSV.
- Added PNG and SVG chart downloads.
- Removed incomplete-period line segments and used the larger orange-ring point convention.
- Updated Latest Data Release card order and titles.
- Extended the Data tab to show rate confidence intervals and CI methods.
- Preserved the existing count, distribution, monthly reference, coverage and public-download views.

## Commands

```text
quarto preview site/surveillance/cvd/metrics/mortality/index.qmd
quarto render site/surveillance/cvd/metrics/mortality/index.qmd
```

## Checks performed

- Confirmed the public CSV contains 4,194 rows and 576 `MORT-RATE-001` rows.
- Confirmed the rate lattice has two definitions, three CVD types, three sexes, crude and age-standardised statistics, annual periods, and the released CI fields.
- Confirmed the dashboard references only the Step 6 website mirror.
- Confirmed no rate, CI, suppression or comparator calculation was added.
- Confirmed incomplete-period line marks were removed from the mortality count charts.
- Confirmed the QMD contains both PNG and SVG download controls.

## Limitations / follow-up

Quarto was not available in the execution environment, so the final local preview and full render must be run after installation in the repository environment. Browser-console and narrow-screen checks should be completed during that local review.

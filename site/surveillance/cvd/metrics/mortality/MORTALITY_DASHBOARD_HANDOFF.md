# BNR mortality dashboard handoff

## Files to install

Copy these files to the matching repository-relative locations:

- `site/surveillance/cvd/metrics/mortality/index.qmd` — new mortality dashboard.
- `site/_quarto.yml` — adds **CVD mortality** beside **CVD burden** in the CVD sidebar.

No Stata, mortality workflow, CVD workflow, generated dataset, metadata, approval or catalogue file is changed by this patch.

## Public inputs used by the dashboard

The dashboard reads only the Step 6 website mirror:

- `site/downloads/files/metrics/mortality/burden/datasets/mort_burden_metrics_current.csv`
- `site/downloads/files/metrics/mortality/burden/datasets/mort_monthly_reference_2015_2019.csv`
- the release catalogue record under `site/downloads/files/metrics/mortality/burden/catalogue/` for the release date.

Download links point to the current CSV/DTA, the fixed reference asset and metadata, and the release-stamped public ZIP.

## Publication-layer YTD rule

The monthly view contains one deliberately narrow presentation-derived calculation: year-to-date count. It sums the already-published monthly combined-CVD counts from January to the selected month for the selected mortality definition. The YTD value is shown only when every contributing month is present, complete, unsuppressed and numeric. Otherwise it is unavailable. The dashboard does not write the value back to a dataset.

No monthly rolling five-year comparator is calculated or shown. The 2015–2019 monthly band is loaded directly from the fixed reviewed reference asset and is never recalculated.

## Documentation consequence

This dashboard does not create a new operator pathway, so no Operations Manual procedure is required. The Technical Manual should record the publication-layer YTD exception and the current/reference input paths when the mortality website section is updated. The explanatory comment is already embedded in `index.qmd` so the rule travels with the implementation.

## Local checks before installation/publication

1. Confirm the three changed/new source files are the only intended Git changes after installation.
2. Confirm the Step 6 website mirror exists at `site/downloads/files/metrics/mortality/burden/`.
3. Preview `site/surveillance/cvd/metrics/mortality/` locally.
4. Test **Death count** and **Death distribution**.
5. Test **Primary**, **Inclusive**, and both definitions selected.
6. Test monthly, quarterly and annual count views.
7. Confirm monthly controls expose only all CVD / both sexes / all ages.
8. Confirm annual all-CVD age options expose All ages / Under 70 / 70 and older.
9. Confirm monthly charts show the fixed 2015–2019 band and no rolling comparator.
10. Confirm quarterly/annual comparators appear only where supplied in the public dataset.
11. Confirm the Data tab links to the current files and release ZIP.
12. Run a complete site render and inspect the CVD sidebar before committing.

## Checks completed before handoff

Static checks completed against the supplied `mort_2026_07` public mirror and the supplied current CVD burden package:

- confirmed the mortality current dataset contains 3,618 rows and both approved case definitions;
- confirmed monthly count rows contain only all CVD, both sexes and all ages;
- confirmed the fixed monthly reference contains 24 rows (12 months × 2 definitions);
- confirmed there is no monthly rolling-comparator statistic in the dashboard source;
- confirmed period sliders derive their limits from the current public dataset rather than hard-coded years;
- confirmed the current 2025 monthly rows are complete for YTD calculation for both definitions;
- confirmed annual event-type and age percentage groups contain their full component pairs in the supplied release;
- confirmed all dashboard download targets exist in the supplied Step 6 website mirror;
- confirmed `site/_quarto.yml` remains valid YAML after the navigation edit;
- confirmed all Observable JavaScript blocks pass a JavaScript syntax check after normalising Observable `viewof` syntax;
- confirmed no private path, approval receipt, public manifest or Stata workflow file is referenced by the dashboard.

A full Quarto render was not possible in the execution environment used to prepare this patch because the Quarto CLI is not installed there. A local preview and full site render therefore remain required before repository installation or deployment.

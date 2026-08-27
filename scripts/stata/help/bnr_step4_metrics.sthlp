{smcl}
{title:BNR Step 4: Calculate and privately stage combined CVD metrics}

{p 4 4 2}
{cmd:db bnr_step4_metrics} opens the Step 4 dialog. It runs the private
CVD--mortality linkage and annual-rate calculations, calculates CVD burden
metrics, and stages one combined private package for Step 5.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_step4_metrics.do"} {it:cvd_year} {it:cvd_month} {it:mortality_year} {it:mortality_month} [{cmd:replace}]

{title:Example}

{p 8 8 2}
{cmd:. do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 4 2026 7 replace}

{title:Inputs}

{p 4 4 2}
The CVD release supplies the Step 3 count dataset under:

{p 8 8 2}
{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/}

{p 4 4 2}
The nominated mortality release is required because DCO linkage and the
incidence-rate calculation use the private mortality input. Step 4 creates its
private linkage calculation products under:

{p 8 8 2}
{cmd:$BNR_PRIVATE/data/derived/cvd/yYYYY/mMM/linkage/mort_yYYYY_mMM/}

{title:Private staging output}

{p 4 4 2}
The package is created outside the Git repository under:

{p 8 8 2}
{cmd:$BNR_STAGING/metrics/cvd/cvd_YYYY_MM/}

{p 4 4 2}
It contains separate private burden and incidence-rate datasets, the private DCO
component sidecar, and QA material. It is not public-ready.

{title:Disclosure boundary}

{p 4 4 2}
Step 4 retains exact values and private support components only in private
locations. Step 5 applies the full disclosure-control register, creates the
review package and requires human approval. Step 4 never writes an approval,
public or website file.

{title:Next action}

{p 4 4 2}
Run Step 5 Prepare after a successful Step 4, inspect
{cmd:review/step5_review.xlsx}, then approve only after the human review.

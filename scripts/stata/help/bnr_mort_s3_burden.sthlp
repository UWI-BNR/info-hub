{smcl}
{title:BNR Mortality Step 3: Build burden data}

{p 4 4 2}
{cmd:db bnr_mort_s3_burden} opens the Step 3 dialog. Enter the completed
Step 2 dataset release year and month. The command constructs the standard BNR
source path and creates a private staging package for review.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/mortality/bnr_mort_s3_burden.do" 2026 7 [{cmd:replace}] [{cmd:debug}]}

{title:Standard Step 2 source}

{p 4 4 2}
For release year {cmd:2026} and month {cmd:7}, Step 3 reads:

{p 8 8 2}
{cmd:$BNR_DATA_DERIVED/mortality/y2026/m07/bnr_mort_s2_202607.dta}

{p 4 4 2}
The release year and month identify the frozen Step 2 dataset. Step 2 retains
the complete classified date range. Step 3 deliberately starts the dashboard
series at January 2010 and derives the final completed year from Step 2.

{title:Step 3 metrics}

{p 4 4 2}
Step 3 creates two burden scenarios using the same selective reporting lattice
as the CVD event dashboard: Primary (Clear + Likely) and Upper bound (Clear +
Likely + Possible). The lower-bound scenario is deliberately not included.

{p 8 8 2}
Annual BNR-CVD, Heart and Stroke counts by sex; annual combined BNR-CVD age
groups; annual event-type, sex and age percentages; quarterly BNR-CVD, Heart
and Stroke counts by sex; and monthly combined BNR-CVD counts by sex. Monthly
rolling five-year comparator rows are deliberately not calculated: Step 4
builds the separate fixed 2015-2019 monthly reference candidate for review.

{p 4 4 2}
Step 3 also creates annual crude and directly age-standardised mortality rates
per 100,000 for Primary and Inclusive definitions, All CVD/Heart/Stroke and
both/female/male sex strata. Rates use the approved private WPP 2024 Barbados
population and WHO World Standard assets. Their 95% statistical confidence
intervals are retained for review; the dashboard does not calculate rates.

{p 4 4 2}
Count series also include the appropriate prior-five-year mean. Age is not
crossed with sex, individual outcome or subannual period. Monthly Heart and
Stroke rows are deliberately omitted to reduce sparse cells.

{title:Private staging output}

{p 4 4 2}
For the example above, the package is created under:

{p 8 8 2}
{cmd:$BNR_STAGING/mortality/burden/mort_2026_07/}

{p 4 4 2}
It contains release-stamped and current DTA/CSV datasets, package metadata, an
evidence-bearing QA CSV, a suppression-review CSV/XLSX and a readme. Exact
values remain private. Generated files must not be corrected manually.

{title:Replacement protection}

{p 4 4 2}
If a completed or partial package already exists, the command stops. Use
{cmd:replace} only after reviewing the earlier attempt and deliberately
authorising replacement.

{title:Diagnostic detail}

{p 4 4 2}
Routine execution is deliberately quiet and retains only the short start and
completion summaries in the Results window. If a future run stops, add
{cmd:debug} to expose the child calculation and staging commands in the private
log. The words {cmd:replace} and {cmd:debug} may be supplied in either order.

{title:Disclosure control and workflow boundary}

{p 4 4 2}
Frequencies 1 to 5 and directly connected count/percentage rows are flagged for
private review. A deliberate Step 3 replacement also invalidates any earlier
{cmd:public_ready} approval package for the same release. Step 3 does not apply final public suppression, approve, perform DCO linkage or copy anything to Quarto or the website. Rate protection is applied in Step 4 as a secondary companion to a protected annual death count.

{smcl}
{title:BNR Step 4: Calculate metrics and prepare private staging review}

{p 4 4 2}
{cmd:db bnr_step4_metrics} opens the Step 4 dialog. It calculates
the implemented burden metric family from a completed Step 3 release and creates
a private staging package for human review.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_step4_metrics.do"} {it:year} {it:month} {it:metric_family} [{it:metric_family} ...] [{cmd:replace}]

{p 4 4 2}
The only implemented family is {cmd:burden}. It calculates CVD-BURDEN-001 and
CVD-BURDEN-002 together. The grey controls show planned families but cannot be
selected yet.

{title:Examples}

{p 8 8 2}
{cmd:. do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 burden}

{p 8 8 2}
To replace the existing selected private staging package deliberately:
{cmd:. do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 3 burden replace}

{title:Input}

{p 4 4 2}
The burden family requires the Step 3 count dataset and YAML receipt under:

{p 8 8 2}
{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/}

{title:Private staging output}

{p 4 4 2}
The review package is created outside the Git repository under:

{p 8 8 2}
{cmd:$BNR_STAGING/metrics/cvd/burden/cvd_YYYY_MM/}

{p 4 4 2}
The package contains exact aggregate values, a QA CSV and a dedicated
suppression-review CSV. It is not public-ready.

{p 4 4 2}
Burden outputs contain annual counts stratified by event type and sex,
all-CVD-only monthly counts stratified by sex, and calendar-quarterly counts
stratified by event type and sex. No age strata are produced. The
dataset also records {cmd:period_complete}: monthly rows are always complete,
whereas the current quarter or year can be incomplete at a monthly extract.

{p 4 4 2}
If any monthly all-CVD sex count is from 1 to 5, Step 4 stops before staging
and lists the affected month and sex. BNR must then decide whether monthly
output should be unstratified by sex.

{title:Primary-suppression policy}

{p 4 4 2}
BNR policy {cmd:bnr_sdc_v1} requires primary suppression of every exact
frequency from 1 to 5 before publication. A true zero is not primary
suppressed. Percentages and other derived values connected to an unsafe
frequency are also flagged for linked review. Upstream safeguards ensure that
no person contributes more than one event within a month.

{p 4 4 2}
Step 4 classifies and records the risks but deliberately retains exact values in
private staging. Step 5 must create a separate public-ready copy, remove primary
values and their derivatives, apply complementary (secondary) suppression where
totals or related outputs could reconstruct them, and review the full release
across datasets, tables, charts, tooltips and previous releases.

{p 4 4 2}
The guiding reference is the {browse "https://ukdataservice.ac.uk/app/uploads/sdc-handbook-v2.0.pdf":Handbook on Statistical Disclosure Control for Outputs}.
The Handbook is risk-based and does not make 6 a universal threshold;
{cmd:n < 6} is BNR's documented operational rule.

{title:Step 5 handover}

{p 4 4 2}
Review both files under the package's {cmd:review/} folder. Step 5 must confirm
that every primary candidate is handled, derived rows are handled consistently,
complementary suppression prevents subtraction or differencing, exact values do
not survive in any public-ready field, and the dashboard and downloadable data
show the same disclosure-controlled result.

{p 4 4 2}
The suppression CSV and workbook contain only candidate rows. Their worklist is
limited to the period, disease/sex context, exact supporting values and the
suppression-decision fields needed by the Step 5 reviewer.

{p 4 4 2}
Step 4 creates no approval, public or website file. Do not copy its exact
datasets to public output or the dashboard pathway.

{title:Read the final report}

{p 4 4 2}
Routine controller and helper code runs quietly. A successful run ends with
{bf:STEP 4: OPERATIONAL RUN SUMMARY}. Check the release, QA files and private
staging folder before opening Step 5.

{p 4 4 2}
If the run cannot continue, the final block is {bf:STEP 4: OPERATIONAL RUN SUMMARY} with {bf:Run status: Did not complete}.
Read its reason and log path. No approval or public file has been created.

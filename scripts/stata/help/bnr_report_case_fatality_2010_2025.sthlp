{smcl}
{title:BNR case-fatality report, 2010-2025}

{p 4 4 2}
This help page explains the analyst-owned case-fatality DO file and every file
that a successful analytical run retains. It is specific to this one-off study
and is available from {bf:User > BNR > One-off CVD report publication}.

{title:Run the analysis}

{p 8 8 2}
{cmd:do "$BNR_STATA/reporting/case-fatality/bnr_report_case_fatality_2010_2025.do"}

{p 4 4 2}
Run it only in an authorised Stata 19 session after loading
{cmd:bnr_paths_LOCAL.do}. The analysis reads the frozen January 2026 joined CVD
event release and July 2026 all-deaths release. It writes only below
{cmd:$BNR_PRIVATE}; it does not approve or publish anything.

{title:Study definition}

{p 4 4 2}
The primary result is all-cause death on the event date or within the following
30 days. A death is counted when it is found through deterministic linkage to
the all-deaths extract or is recorded as a valid hospital death within the same
period. The denominator uses the first Heart event and first Stroke event for
each deterministic person proxy in each calendar year.

{p 4 4 2}
All CVD pools those two condition-specific cohorts. A person with an eligible
Heart event and Stroke event may therefore contribute twice to All CVD. A later
death may also be an outcome in both condition series. These are event-based
results, not counts of distinct national deaths.

{p 4 4 2}
Mortality-linked and hospital-recorded 30-day measures are retained as
condition-specific secondary results. The mortality-linked measure includes
deaths also recorded by the hospital. The PDF presents only the annual primary
results.

{title:Output location}

{p 4 4 2}
The study root is:

{p 8 8 2}
{cmd:$BNR_PRIVATE/outputs/staging/reports/cvd/case-fatality/cvd_case_fatality_2010_2025_v01/}

{p 4 4 2}
The {cmd:review/} folder contains confidential analytical review evidence. The
{cmd:candidate/} folder contains the proposed public data files, figures and
finished PDF. Candidate means prepared for review, not approved or published.

{title:Private review bundle}

{p 4 4 2}
Open {cmd:case_fatality_review_readme.txt} first. The four retained DTA files
are aggregate review evidence and contain no direct identifiers. They remain
private because some contain exact small counts or unsuppressed values.

{p 8 12 2}
{cmd:case_fatality_input_review.dta} checks source volumes, hospital outcome
fields, date and identifier quality, and selection of annual index events. An
undated mortality row retains the count of records with missing or invalid death
dates for review.

{p 8 12 2}
{cmd:case_fatality_linkage_review.dta} checks deterministic death linkage,
Heart/Stroke cohort overlap, hospital-only deaths and reconciliation of the
primary numerator across both death sources. Its
{cmd:index_event_multi_deaths} panel flags any index event linked to
more than one eligible mortality death record before the earliest is selected.
This is an aggregate source-review flag, not an automatic correction. A
nonzero count requires governed source-record review before approval.

{p 8 12 2}
{cmd:case_fatality_age_review.dta} checks age completeness, the three internal
Barbados reference populations and the exact samples used for age adjustment.

{p 8 12 2}
{cmd:case_fatality_disclosure_review.dta} contains the complete proposed public
layout before protected numeric values are blanked. It records direct and
complementary small-cell checks, source-quality exclusions and the final release
decision for each row.

{p 4 4 2}
Each review dataset is rebuilt through a clean metadata boundary and then given
only case-fatality dataset labels, variable labels and notes. In Stata use:

{p 8 8 2}
{cmd:describe}

{p 8 8 2}
{cmd:notes}

{p 8 8 2}
{cmd:tabulate review_section}

{p 4 4 2}
The first three review datasets contain several panels at different aggregate
grains. Always filter or browse by {cmd:review_section}; variables not used by a
particular panel are intentionally missing.

{title:Recommended review sequence}

{p 4 8 2}
1. In the input review, compare annual event and mortality volumes with the
declared source releases. Review extreme dates, missing age or sex, unavailable
identifiers and repeat events excluded by the annual index rule.

{p 4 8 2}
2. In the linkage review, inspect the
{cmd:annual_outcome_reconciliation} panel. For every year, event type and sex,
{cmd:primary_death_30} must equal {cmd:linked_only_death} plus
{cmd:hospital_only_death} plus {cmd:both_death_sources}. Review linkage rules,
hospital-only reasons and Heart/Stroke overlap alongside this panel.

{p 4 8 2}
3. In the age review, inspect missing or invalid age, reference weights and the
model-sample reconciliation. Confirm that rows expected to be published have
{cmd:model_status} equal to {cmd:converged_estimable}.

{p 4 8 2}
4. In the disclosure review, inspect every row whose {cmd:release_status} is
not {cmd:release}. Confirm that the matching candidate public row has blank
counts, estimate and confidence limits. This file must never be published.

{p 4 8 2}
5. Compare the candidate CSV and DTA, read the metadata TXT, and inspect every
page of the PDF before starting the separate one-off publication workflow.

{title:Candidate public data}

{p 4 4 2}
The candidate folder contains:

{p 8 12 2}
{cmd:case_fatality_metrics_candidate.csv} - portable public-data candidate;

{p 8 12 2}
{cmd:case_fatality_metrics_candidate.dta} - the same rows and values with full
Stata labels, formats and case-fatality-specific {cmd:notes}. Source-dataset
notes and characteristics are deliberately removed before this file is saved;

{p 8 12 2}
{cmd:case_fatality_metadata_candidate.txt} - plain-text definitions matching
the DTA metadata;

{p 8 12 2}
{cmd:bnr_cvd_case_fatality_2010_2025.pdf} - finished one-off report candidate.

{p 4 4 2}
Suppressed or source-quality-excluded rows remain in both datasets, but their
events, deaths, estimate and confidence limits are blank. The
{cmd:release_status} field explains why. Do not manually edit any candidate
file; correct the data or DO file and rerun.

{title:Age-standardised results}

{p 4 4 2}
Age-standardised percentages are predictive margins from logistic models using
age groups under 55, 55-64, 65-74, 75-84 and 85 and over. All CVD, Heart and
Stroke each use their own pooled 2010-2025 valid-age reference population.
Adjusted results therefore support comparison over time within a series, not
direct comparison between the three series. Counts on adjusted rows describe
the observed cohort and are not the numerator and denominator of the adjusted
percentage.

{title:Publication boundary}

{p 4 4 2}
A successful analytical run creates private review and candidate files only.
After review, the separate one-off report steps prepare, approve and publish the
exact PDF and dataset package. Approval and publication must not be inferred
from the presence of candidate files.

{p 4 4 2}
Use the three existing menu steps under
{bf:One-off CVD report publication} only after the analytical and disclosure
review is complete.

{title:If the run stops}

{p 4 4 2}
Read {cmd:case_fatality_input_audit.log} in the private review folder. Do not
repair a generated DTA, CSV, TXT or PDF. Correct the authoritative source,
configuration or version-controlled code and rerun the complete analysis.

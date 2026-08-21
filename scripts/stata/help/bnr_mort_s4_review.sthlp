{smcl}
{title:BNR Mortality Step 4: Prepare review candidate}

{p 4 4 2}
{cmd:db bnr_mort_s4_review} opens the Step 4 dialog. Select the year and
month of a completed private Step 3 mortality burden package.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/mortality/bnr_mort_s4_review.do" 2026 7 [{cmd:replace}]}

{title:Purpose}

{p 4 4 2}
Step 4 independently revalidates the Step 3 metric dataset, metadata, QA
receipt and suppression worklist. It confirms the release identity, 2010-onward
annual, quarterly and monthly reporting lattice, metric definitions, row
counts, numerical reconciliations and private disclosure-control status.

{p 4 4 2}
Step 4 then applies the fixed BNR disclosure-control rule to a complete copy of
the metrics. It carries forward Step 3 primary risks and applies complementary
suppression to sex-total and additive event and age reconstruction pathways,
linked derived values,
and annual or quarterly panels that could otherwise reveal a protected monthly
count through temporal differencing.
It removes the exact value, numerator, denominator and comparison count from
protected rows, writes an asterisk to the public display field, and creates the
exact disclosure-controlled candidate for human review. It does not recalculate
a mortality metric.

{title:Required Step 3 package}

{p 4 4 2}
For release 2026 and month 7, Step 4 reads:

{p 8 8 2}
{cmd:$BNR_STAGING/mortality/burden/mort_2026_07/}

{p 4 4 2}
The package must contain its release-stamped and current DTA/CSV datasets,
metadata, Step 3 QA receipt, suppression-review CSV/XLSX and readme. The
release-stamped and current data files must be byte-identical.

{title:Private candidate and review outputs}

{p 4 4 2}
Step 4 writes four files inside the existing private {cmd:review/} folder:

{p 8 12 2}
{cmd:mort_s4_candidate.dta} - exact disclosure-controlled candidate proposed
for later approval;

{p 8 12 2}
{cmd:mort_s4_review_mort_YYYY_MM.xlsx} - open this file first;

{p 8 12 2}
{cmd:mort_s4_review_qa_mort_YYYY_MM.csv} - machine-readable validation receipt;

{p 8 12 2}
{cmd:mort_s4_review_basis_mort_YYYY_MM.csv} - checksums and sizes for the exact files reviewed.

{p 4 4 2}
The workbook contains a concise summary, definitions, combined Step 3 and Step
4 QA, annual metrics, quarterly metrics, monthly metrics, the fixed
{bf:Monthly reference}, a private exact-value suppression review, metadata and
the file-fingerprint record. Its {bf:Public candidate} sheet shows
the complete proposed disclosure-controlled presentation alongside the private
review evidence in the other sheets.

{title:Human review}

{p 4 4 2}
The completed run status is {bf:READY FOR HUMAN REVIEW}. This is not approval.
The reviewer should inspect analytical plausibility, definitions, period,
disclosure-control status and package completeness. Review both the Primary and
Upper scenarios. The {bf:Suppression review} sheet is private: it supplies the
exact protected value, supporting fields and a plain-language protection route.
Use it to inspect all primary rows and the secondary-protection routes without
writing code. Then find the same metric keys in {bf:Public candidate} and
confirm that its exact numeric fields are blank and its display value is an
asterisk. Also spot-check unrestricted rows against the private metrics sheets
and confirm that early comparator rows marked {cmd:insufficient_history} have
no value but are not described as suppressed.

{p 4 4 2}
When a monthly count is protected, Step 4 uses a fixed minimum set of matching
quarterly and annual cells to close the relevant sex, event and temporal
equations, then protects only affected derived values and five-year comparators.
This prevents reconstruction by subtraction without masking a whole panel. The
Step 4 QA receipt includes a separate
{cmd:temporal_differencing} PASS check.

{p 4 4 2}
Step 4 also performs a private, automatic equation audit. Under the fixed BNR
input and metric structure this is expected to PASS on every routine run; it is
a technical regression safeguard, not a reviewer decision or a request for an
analyst to select extra suppressions. If it stops the run, do not edit the
candidate or code during routine production: retain the log and refer the
technical issue for correction before approval or publication.

{p 4 4 2}
If the review finds a problem, do not edit generated files. Correct the source
or version-controlled code, rerun Step 3 and then rerun Step 4.

{title:Replacement protection}

{p 4 4 2}
Step 4 stops if an earlier candidate or Step 4 review output exists. Use
{cmd:replace} only for a deliberate rebuild after the earlier materials have
been reviewed. A rebuilt candidate must receive a new human review before
approval.

{title:Workflow boundary}

{p 4 4 2}
The candidate remains private and unapproved. Step 4 creates no approval
record, {cmd:public_ready} package, authoritative public output, website file,
Quarto output or mortality rate. Step 5 verifies the exact reviewed candidate
and records approval; Step 6 handles publication.

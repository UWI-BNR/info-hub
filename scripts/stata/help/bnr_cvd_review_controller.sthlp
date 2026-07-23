{smcl}
{title:BNR Step 5: Review and approval}

{p 4 4 2}
{cmd:db bnr_cvd_review_controller} opens the Step 5 dialog. Step 5 has two
separate actions: prepare a disclosure-controlled review package, then record
approval only after the human review is complete.

{title:Metric families}

{p 4 4 2}
The dialog shows the full planned CVD metric-family menu. At present, only
{bf:Burden - event counts and distributions} is enabled. Incidence and rates,
case fatality, length of stay / hospital use, data quality, care performance and
mortality remain visible but disabled until their Step 4 outputs and
family-specific disclosure rules are implemented.

{p 4 4 2}
When further families are enabled, the dialog may prepare or approve several
selected families in one session, but it will run each family as a separate
package. Each package keeps its own workbook, fingerprints, approval record and
eventual Step 6 promotion check.

{title:Prepare syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_cvd_review_controller.do"} {it:year} {it:month} {cmd:burden prepare} [{cmd:replace}]

{p 8 8 2}
Example:
{cmd:. do "$BNR_STATA/monthly/bnr_cvd_review_controller.do" 2024 2 burden prepare}

{p 4 4 2}
Prepare reads the completed Step 4 private staging package, confirms that Step 4
QA passed, creates a disclosure-controlled candidate inside {cmd:review/},
removes exact values from suppressed rows, and creates disclosure QA, a concise
reviewer workbook and a review-basis fingerprint file. It does not create
{cmd:public_ready/}, an approval or any public file.

{title:Human review}

{p 4 4 2}
Open {cmd:review/step5_review.xlsx}. An authorised BNR Lead, BNR Analyst or BNR
Statistician must review analytical plausibility, disclosure control,
interpretation and publication readiness together.

{p 4 4 2}
If the package is not satisfactory, do not edit generated files. Correct the
appropriate earlier source or version-controlled code, rerun from that step,
then prepare a new Step 5 package.

{title:Approval syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_cvd_review_controller.do"} {it:year} {it:month} {cmd:burden approve} {it:"Full name"} {it:"BNR Lead"|"BNR Analyst"|"BNR Statistician"}

{p 8 8 2}
Example:
{cmd:. do "$BNR_STATA/monthly/bnr_cvd_review_controller.do" 2024 2 burden approve "Full name" "BNR Statistician"}

{p 4 4 2}
Approval requires a nonblank approver name, rechecks disclosure QA and confirms
that the reviewed candidate and its authoritative Step 4 sources are unchanged.
Only then does it create {cmd:public_ready/}, its file manifest and
{cmd:review/approval.yml}. The approval records the checksum and size of the
manifest itself. If a file or the manifest later changes, Step 6 must refuse
promotion.

{title:Suppression contract}

{p 4 4 2}
Suppressed rows remain in the public-ready dataset. Their exact {cmd:value},
{cmd:numerator} and {cmd:denominator} are missing, {cmd:display_value} is
{cmd:*}, and {cmd:suppression_status} is {cmd:primary}, {cmd:secondary} or
{cmd:derived}. Unsuppressed rows use {cmd:none}. Observable must read
{cmd:suppression_status}; a missing value alone does not mean suppression.

{p 4 4 2}
Incomplete quarterly and annual disease-specific values are derived-suppressed.
Otherwise, differencing successive monthly releases could reconstruct the
disease-specific monthly counts that Step 4 deliberately withholds.

{title:Boundary}

{p 4 4 2}
Step 5 never writes to {cmd:outputs/public/}, the website mirror or GitHub.
Step 6 alone may promote a valid approved {cmd:public_ready/} package.

{title:End-of-run status}

{p 4 4 2}
Routine Stata commands run quietly. The Results window and private log show a
short run heading followed by one operational result, rather than the controller
source code.

{p 4 4 2}
Every completed action ends with a clearly separated {bf:STEP 5: OPERATIONAL
RUN SUMMARY}. It appears after all preparation or approval work, immediately
before the private log closes, so it is the last substantive information in both
the Results window and the log.

{p 4 4 2}
For Prepare, start with the file labelled {bf:OPEN THIS FILE FIRST}:
{cmd:review/step5_review.xlsx}. The same summary then lists the supporting
candidate, disclosure QA, review record and private log. For Approve, it lists
the public-ready package, manifest, approval record and private log.

{p 4 4 2}
A failed action ends with {cmd:STEP 5 DID NOT COMPLETE}, the reason and the log
path. This is the final reported block; no later controller code is displayed.

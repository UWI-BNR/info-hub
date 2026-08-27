{smcl}
{title:BNR Step 5: Review and approval of the combined CVD package}

{p 4 4 2}
Step 5 has two separate actions: prepare a disclosure-controlled private review
package, then record approval only after human review is complete.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_step5_review.do"} {it:year} {it:month} {cmd:prepare} [{cmd:replace}]

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_step5_review.do"} {it:year} {it:month} {cmd:approve} {it:"Full name"} {it:"BNR Lead"|"BNR Analyst"|"BNR Developer"} [{cmd:replace}]

{title:Prepare}

{p 4 4 2}
Prepare reads the completed combined Step 4 package from:

{p 8 8 2}
{cmd:$BNR_STAGING/metrics/cvd/cvd_YYYY_MM/}

{p 4 4 2}
It creates a disclosure-controlled candidate and private review material in its
{cmd:review/} folder. Open {cmd:step5_review.xlsx} first. Its supporting
sheets show disclosure QA, the equation audit, protected-row worklist and the
fingerprint register.

{p 4 4 2}
Prepare creates no {cmd:public_ready/} folder, public file or website file.
If review identifies a problem, do not edit generated outputs. Correct the
earlier source or version-controlled code and prepare a new review package.

{title:Approve}

{p 4 4 2}
Approval rechecks the reviewed fingerprints and disclosure QA. Only then does
it create the immutable {cmd:public_ready/} payload, including release-stamped
and {cmd:current} datasets, metadata, a seven-file manifest and
{cmd:approval.yml}. DCO components and other private accounting fields never
enter that payload.

{title:Boundary}

{p 4 4 2}
Step 5 never writes to {cmd:outputs/public/} or the website mirror. Step 6
alone may promote the exact approved package.

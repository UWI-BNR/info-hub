{smcl}
{title:BNR occasional briefings: approve and publish a reviewed package}

{p 4 4 2}
{cmd:bnr_approve_publish_briefing.do} is the deliberate human gate for an
occasional briefing. It checks the completed disclosure review, records one
combined approval, copies approved artefacts to the authoritative public folder,
creates the ZIP and rebuilds the website mirror.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/common/bnr_approve_publish_briefing.do"} {break}
{cmd:    "{it:briefing_id}" "{it:approved_by}" "{it:approved_role}"}

{title:Example}

{p 8 8 2}
{cmd:do "$BNR_STATA/common/bnr_approve_publish_briefing.do" ///}{break}
{cmd:    "cvd_cases_2023_v2" ///}{break}
{cmd:    "Full name" ///}{break}
{cmd:    "Registry Statistician"}

{title:Required review}

{p 4 4 2}
Complete every required line in
{cmd:$BNR_STAGING/briefings/{it:briefing_id}/review/disclosure_review.txt}.
The helper stops unless datasets, figures, narrative, complementary disclosure,
differencing, external information, identifiers and automated flags are all
recorded as reviewed, explanatory fields are completed, and
{cmd:review_status: APPROVE FOR PUBLICATION} is present.

{title:Checks}

{p 4 4 2}
The helper confirms package identity, declared files, dataset metadata, workbook
and manifest; stops for undeclared DTA/CSV/PNG files; and checks public DTA files
for common prohibited identifier variables.

{title:Public and private files}

{p 4 4 2}
The approved package is written to
{cmd:$BNR_PUBLIC/briefings/{it:briefing_id}/}. The review folder remains private.
The copy under {cmd:site/downloads/files/briefings/} is a disposable mirror.

{title:Important}

{p 4 4 2}
This helper does not calculate results, suppress values or decide that a flagged
value is safe. Those remain documented analyst judgements.


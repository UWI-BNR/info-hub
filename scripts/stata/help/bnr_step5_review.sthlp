{smcl}
{title:BNR Step 5: Review and approve combined CVD metrics}

{pstd}Step 5 has separate {cmd:prepare} and {cmd:approve} actions. It never writes to {cmd:outputs/public/} or the website mirror.

{title:Syntax}
{phang2}{cmd:do "$BNR_STATA/monthly/bnr_step5_review.do"} {it:year month} {cmd:prepare} [{cmd:replace}]
{phang2}{cmd:do "$BNR_STATA/monthly/bnr_step5_review.do"} {it:year month} {cmd:approve} {it:"Full name"} {it:"BNR Lead"|"BNR Analyst"|"BNR Developer"} [{cmd:replace}]

{title:Prepare}
{pstd}Prepare reads the combined private Step 4 package at {cmd:$BNR_STAGING/metrics/cvd/cvd_YYYY_MM/}, creates a disclosure-controlled candidate and writes its review evidence to {cmd:review/}. Review {cmd:step5_review.xlsx}, {cmd:step5_disclosure_qa.csv}, {cmd:step5_equation_audit.csv}, {cmd:step5_row_audit.dta} and {cmd:step5_review_basis.csv}. Every automated result must be {cmd:PASS}.

{title:Approval}
{pstd}After human review, approve rechecks the saved fingerprints and QA before creating {cmd:public_ready/}, its seven-file manifest and {cmd:approval.yml}. A previous approval is immutable unless {cmd:replace} is explicitly supplied.

{title:Suppression contract}
{pstd}Protected public rows remain present but have blank numeric fields and {cmd:display_value} {cmd:*}. For the annual DCO rows, protection is audited across hospital-only, additional-DCO and hospital-plus-DCO count identities and all released rate representations. The dashboard must only filter and display these supplied public rows; it must never reconstruct a protected value.

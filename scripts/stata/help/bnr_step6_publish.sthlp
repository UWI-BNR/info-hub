{smcl}
{title:BNR Step 6: Publish the approved combined CVD package}

{pstd}
Step 6 promotes only an approved combined CVD package. It verifies
{cmd:approval.yml}, {cmd:public_manifest.csv} and every approved payload
checksum before copying anything.

{title:Syntax}

{p 8 18 2}
{cmd:do "$BNR_STATA/monthly/bnr_step6_publish.do"} {it:year} {it:month} [{cmd:replace}]

{pstd}
Example:

{phang2}
{cmd:. do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4 replace}

{title:What Step 6 creates}

{pstd}
The authoritative public release is written below:

{phang2}
{cmd:$BNR_PUBLIC/metrics/cvd/}

{pstd}
The lean website mirror contains only the current CSV, the release ZIP and its
catalogue record below:

{phang2}
{cmd:$BNR_REPO/site/downloads/files/metrics/cvd/}

{pstd}
The release ZIP contains the seven approved payload files. Step 6 also creates
a full {cmd:catalogue/cvd_YYYY_MM.yml} record which the central Downloads
catalogue builder reads. It is publication metadata, not an additional
analytical payload.

{title:Boundary}

{pstd}
Step 6 does not calculate, suppress, edit, approve, rebuild the central
Downloads catalogue, render Quarto, commit or deploy. It promotes only the
approved payload. {cmd:approval.yml} and {cmd:public_manifest.csv} remain
private controls.

{title:Next action}

{pstd}
After a successful Step 6, run:

{phang2}
{cmd:python site/scripts/build_download_catalogue.py}

{pstd}
Then inspect the Downloads page before the normal render, commit and deployment
procedure.

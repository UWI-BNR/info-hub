{smcl}
{title:BNR Step 6: Publish approved combined CVD metrics}

{pstd}Step 6 verifies {cmd:approval.yml}, {cmd:public_manifest.csv} and every approved payload checksum before promotion. It does not calculate, suppress, approve, render or deploy.

{title:Syntax}
{phang2}{cmd:do "$BNR_STATA/monthly/bnr_step6_publish.do"} {it:year month} [{cmd:replace}]

{title:Example}
{phang2}{cmd:. do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 4}

{title:Outputs}
{pstd}The authoritative public package is under {cmd:$BNR_PUBLIC/metrics/cvd/}. Step 6 refreshes only the website current CSV under {cmd:$BNR_REPO/site/downloads/files/metrics/cvd/}, copies the release ZIP to {cmd:releases/}, and writes a small catalogue record under {cmd:catalogue/}. The private approval and manifest controls are not published.

{title:Next action}
{pstd}Run {cmd:python site/scripts/build_download_catalogue.py}. An unchanged catalogue is expected when republication replaces the contents of an existing release ZIP without changing its release identifier or catalogue record.

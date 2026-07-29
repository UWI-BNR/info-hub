{smcl}
{* *! version 1.0.0 28jul2026}{...}
{title:BNR Step 6: Publish approved outputs}

{pstd}
{cmd:bnr_step6_publish} promotes one metric package already approved by
Step 5. It verifies {cmd:approval.yml}, {cmd:public_manifest.csv}, and every
approved payload checksum before copying anything.

{title:Syntax}

{p 8 18 2}
{cmd:do "$BNR_STATA/monthly/bnr_step6_publish.do"}
{it:year month metric_family} [{cmd:replace}]

{pstd}
The currently implemented metric family is {cmd:burden}.

{title:Example}

{phang2}
{cmd:do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 3 burden}

{title:What Step 6 creates}

{pstd}
The authoritative release is written below:

{phang2}
{cmd:$BNR_PUBLIC/metrics/cvd/burden/}

{pstd}
An identical disposable website copy is written below:

{phang2}
{cmd:$BNR_REPO/site/downloads/files/metrics/cvd/burden/}

{pstd}
Both CSV and de-identified Stata DTA datasets are published. Step 6 also
creates one release ZIP containing the eight approved payload files.

{title:Replace}

{pstd}
Without {cmd:replace}, Step 6 stops if the selected release-stamped files
already exist. Use {cmd:replace} only for a deliberate republication after
checking the existing release. Stable {cmd:current} files are refreshed during
every successful publication.

{title:Boundary}

{pstd}
Step 6 does not calculate, suppress, edit, approve, render, commit or deploy.
It promotes only the eight files named by the Step 5 public manifest.
{cmd:approval.yml} and {cmd:public_manifest.csv} remain private controls.


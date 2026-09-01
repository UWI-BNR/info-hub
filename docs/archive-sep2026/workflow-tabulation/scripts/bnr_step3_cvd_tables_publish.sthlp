{smcl}
{title:BNR Tables Step 3: Publish approved CVD tables}

{p 4 4 2}
{cmd:db bnr_step3_cvd_tables_publish} opens the publication dialog. Step 3
promotes the exact suppressed products approved in Step 2B. It creates the
authoritative public release, refreshes the stable latest copy, creates the
download ZIP and refreshes the disposable Quarto website mirror.

{p 4 4 2}
Step 3 does not calculate, suppress, format or approve any table. It does not
render or deploy Quarto.

{title:Before running}

{p 4 4 2}
Complete Steps 1, 2A and 2B for the selected year and month. Confirm that Step
2B ended with {cmd:COMPLETED - APPROVED, NOT PUBLISHED}. Close the public
workbook and any ZIP file that may already be open.

{title:Dialog instructions}

{p 4 4 2}
1. Open {bf:User > BNR > Produce tables > Step 3: Publish approved tables}.

{p 4 4 2}
2. Enter the release year and month of the approved package.

{p 4 4 2}
3. Leave replacement unticked for a first publication. Tick it only when
deliberately rebuilding the public copy from the same approved source package.

{p 4 4 2}
4. Select {bf:Publish approved tables}. A successful run ends with
{cmd:COMPLETED - PUBLISHED}.

{title:Command-line syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/tables/bnr_step3_cvd_tables_publish.do"} {it:year}
{it:month} [{cmd:replace}]

{title:Validation performed}

{p 4 4 2}
Step 3 requires package metadata, {cmd:public_manifest.csv} and a valid
{cmd:approval.yml}. It confirms the package identity, coverage, product type,
approved role, five approval confirmations and all 26 required manifest files.
Unsafe, duplicate or malformed manifest paths stop the run.

{title:Outputs}

{p 4 4 2}
The release-stamped authoritative package is written to:

{p 8 8 2}
{cmd:outputs/public/tables/cvd/releases/cvd_tables_YYYY_MM/}

{p 4 4 2}
The stable authoritative copy is refreshed at:

{p 8 8 2}
{cmd:outputs/public/tables/cvd/latest/}

{p 4 4 2}
The disposable site mirror is refreshed at:

{p 8 8 2}
{cmd:site/downloads/annual/cvd/latest/}

{p 4 4 2}
The public ZIP contains the suppressed DTA and CSV datasets, publication
workbook, public metadata and readme. Website Markdown, {cmd:approval.yml} and
{cmd:publication.yml} are excluded from the user download ZIP.

{title:Publication receipts}

{p 4 4 2}
The authoritative package retains the unchanged Step 2B {cmd:approval.yml} and
adds {cmd:publication.yml}. The latter records when Step 3 ran, the system user,
the selected package and that Quarto rendering was not performed.

{title:Safe replacement}

{p 4 4 2}
A release-stamped package is protected by default. Explicit replacement is for
recovering or rebuilding the public copy from the same approved source. Step 3
uses named temporary build folders and checks them before replacing the stable
latest package or website mirror.

{title:Next step}

{p 4 4 2}
Preview the CVD annual tabulations page. If the workbook, ZIP, tables and YTD
labels render correctly, commit the generated website mirror and updated QMD,
then use the established GitHub deployment process.


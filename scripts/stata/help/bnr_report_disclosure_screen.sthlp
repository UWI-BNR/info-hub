{smcl}
{* *! version 1.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_report_disclosure_screen"}{...}

{title:BNR report utility: Screen counts for disclosure review}

{title:What this utility does}

{pstd}
This optional utility screens a structured Stata dataset for small counts and
obvious structural issues. It creates private review evidence only. It does not
suppress, approve or publish anything.

{title:Before you run it}

{pstd}
Prepare a Stata dataset containing {cmd:output_id}, {cmd:cell_id} and numeric
{cmd:cell_count}. Decide a short, filesystem-safe review ID.

{title:What to enter}

{phang}{bf:Dataset path} is the full path to the structured screening input.

{phang}{bf:Review ID} identifies the private screen and its output folder.

{phang}{bf:Replace the existing private screen} should normally remain
unticked. Use it only when deliberately rerunning the same review ID.

{title:After running}

{pstd}
Inspect every flagged count and the relationships between cells. Human review
must decide any primary or secondary protection. Do not treat a passing screen
as disclosure approval.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/reporting/one-off-report.html#optional-screen-structured-counts":Technical Manual: Optional structured-count screen}.

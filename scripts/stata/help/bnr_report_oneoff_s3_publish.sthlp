{smcl}
{* *! version 1.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_report_oneoff_s3_publish"}{...}

{title:BNR one-off report Step 3: Publish the approved report}

{title:What this step does}

{pstd}
Step 3 verifies the approval, manifest and checksums, then publishes the exact
one-off report package approved in Step 2.

{title:Before you run it}

{pstd}
An unchanged Step 2 approval, manifest and public-ready package must exist for
the selected study ID and version.

{title:What to enter}

{phang}{bf:Study ID and version} must match the approved Step 2 package.

{phang}{bf:Authorise replacement} should normally remain unticked. Use it only
for an authorised recovery or republication of the same approved version.

{title:After running}

{pstd}
Confirm every published file and landing page listed in the final summary.
Render and inspect the website before deployment.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/reporting/one-off-report.html":Technical Manual: Prepare, approve and publish a one-off CVD report}.

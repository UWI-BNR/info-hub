{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_step1_cvd_redcap_extract"}{...}

{title:BNR CVD events Step 1: Extract REDCap data}

{title:What this step does}

{pstd}
Step 1 creates a private cumulative snapshot of the CVD-event records in
REDCap, from 1 January 2024 through the end of the selected month.

{title:Before you run it}

{pstd}
Confirm that the selected month is complete and that the REDCap records are
ready for extraction. The workstation must have the BNR paths and authorised
REDCap token configured.

{title:What to enter}

{phang}{bf:Release year and month} identify the final month included in the
cumulative extract.

{phang}{bf:Authorise replacement} should normally remain unticked. Use it only
when an existing extract for the same period must deliberately be rebuilt.

{title:After running}

{pstd}
Read the final operational summary and confirm the period, record count and
private file locations. If Step 1 completes successfully, continue to CVD
events Step 2. Do not edit generated files.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/cvd-events/extract-redcap.html":Technical Manual: Extract a REDCap data release}.

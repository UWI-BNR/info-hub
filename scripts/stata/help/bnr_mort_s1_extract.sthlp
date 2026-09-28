{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_mort_s1_extract"}{...}

{title:BNR mortality Step 1: Extract REDCap data}

{title:What this step does}

{pstd}
Step 1 extracts the approved mortality fields from REDCap and creates a private
analytical dataset through the end of the selected month.

{title:Before you run it}

{pstd}
Confirm that the selected month is complete and the mortality records are
ready. The workstation must have the BNR paths and authorised REDCap token
configured.

{title:What to enter}

{phang}{bf:Release year and month} identify the final month included in the
extract.

{phang}{bf:Authorise replacement} should normally remain unticked. Use it only
when an existing extract for the same period must deliberately be rebuilt.

{title:After running}

{pstd}
Check the final operational summary, coverage, record count and private file
locations. If Step 1 succeeds, continue to mortality Step 2. Do not edit the
generated extract.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/mortality/extract.html":Technical Manual: Extract mortality data}.

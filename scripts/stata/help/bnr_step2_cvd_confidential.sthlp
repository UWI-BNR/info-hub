{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_step2_cvd_confidential"}{...}

{title:BNR CVD events Step 2: Build the cumulative dataset}

{title:What this step does}

{pstd}
Step 2 combines the selected post-2023 REDCap extract with the fixed
2010-2023 history and creates one confidential cumulative CVD-event dataset.

{title:Before you run it}

{pstd}
Run Step 1 successfully for the same release year and month. Confirm that the
approved historical source is available in the configured private workspace.

{title:What to enter}

{phang}{bf:Release year and month} must match the completed Step 1 extract.
The dialog has no replacement option: the controller protects an existing
confidential release.

{title:After running}

{pstd}
Read the final operational summary. Check the record counts and any quarantine
summary before continuing to CVD events Step 3. Correct source or configuration
problems and rerun; do not edit generated files.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/cvd-events/prepare-confidential.html":Technical Manual: Prepare the confidential dataset}.

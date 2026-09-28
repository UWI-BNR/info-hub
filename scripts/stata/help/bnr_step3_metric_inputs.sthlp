{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_step3_metric_inputs"}{...}

{title:BNR CVD events Step 3: Build de-identified datasets}

{title:What this step does}

{pstd}
Step 3 creates the approved de-identified analytical input datasets from the
confidential cumulative CVD-event dataset.

{title:Before you run it}

{pstd}
Run Step 2 successfully for the same release year and month and resolve any
source-data issues that prevent the confidential dataset from being accepted.

{title:What to enter}

{phang}{bf:Release year and month} must match the completed Step 2 dataset.

{phang}{bf:Datasets to create} selects the approved analytical inputs. Leave
all five selected for the routine workflow unless a documented task requires a
smaller set.

{phang}{bf:Authorise replacement} should normally remain unticked. Use it only
for a deliberate rebuild of the same release.

{title:After running}

{pstd}
Check the final summary and output list. For the routine dashboard workflow,
continue to CVD events Step 4.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/cvd-events/create-analysis-inputs.html":Technical Manual: Create de-identified analytical inputs}.

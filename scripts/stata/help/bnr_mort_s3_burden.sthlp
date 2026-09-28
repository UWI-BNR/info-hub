{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_mort_s3_burden"}{...}

{title:BNR mortality Step 3: Calculate dashboard metrics}

{title:What this step does}

{pstd}
Step 3 calculates the approved mortality counts and rates and writes a private
staging package. It does not apply human approval or publish results.

{title:Before you run it}

{pstd}
Mortality Step 2 must have completed successfully for the selected release.
Confirm that the required population and standardisation references are
available.

{title:What to enter}

{phang}{bf:Release year and month} identify the completed Step 2 dataset.

{phang}{bf:Authorise replacement} should normally remain unticked. Rebuilding
the package means all later review and approval must be repeated.

{title:After running}

{pstd}
Check the final QA summary and private staging location. If every required
check passes, continue to mortality Step 4.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/mortality/build-burden.html":Technical Manual: Build mortality burden data}.

{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_step4_metrics"}{...}

{title:BNR CVD events Step 4: Calculate dashboard metrics}

{title:What this step does}

{pstd}
Step 4 calculates the combined CVD-event metrics and places the exact results
in a private staging package. It does not approve or publish them.

{title:Before you run it}

{pstd}
The selected CVD-event release must have completed Step 3. The selected
mortality release must also be complete and suitable for the required linkage
and rate calculations.

{title:What to enter}

{phang}{bf:CVD release} is the year and month of the completed event dataset.

{phang}{bf:Completed mortality release} is the year and month of the mortality
source used by the combined calculation.

{phang}{bf:Authorise replacement} should normally remain unticked. Rebuilding
a staged package means its review must also be repeated.

{title:After running}

{pstd}
Confirm that all final QA results pass. Continue to CVD events Step 5 and
prepare the review package. Do not treat private staging as publication.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/cvd-events/generate-metrics.html":Technical Manual: Generate combined CVD metrics}.

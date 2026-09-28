{smcl}
{* *! version 1.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_report_update_build"}{...}

{title:BNR rolling CVD update: Build the online update}

{title:What this step does}

{pstd}
This dialog builds a dated rolling three-month CVD update from already
approved public CVD-event and mortality releases. The build freezes the exact
source releases used; it does not create or approve new surveillance metrics.

{title:Before you run it}

{pstd}
Confirm that both selected source releases are approved, published and present
in the authoritative public folders. Decide the report month and version.

{title:What to enter}

{phang}{bf:Report year, month and version} identify the update being created.

{phang}{bf:CVD-event release} and {bf:mortality release} identify the approved
public datasets to freeze and use.

{phang}{bf:Authorise replacement} should normally remain unticked. A published
correction should normally use a higher version number.

{title:After running}

{pstd}
Check the final summary, frozen-source identities and generated page. Review
the rendered update before website deployment.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/reporting/rolling-update.html":Technical Manual: Build a rolling three-month CVD update}.

{smcl}
{* *! version 1.1.0 23jul2026}{...}
{vieweralsosee "BNR CVD extract dialog" "db bnr_cvd_redcap_extract"}{...}

{title:BNR CVD monthly REDCap extract}

{pstd}
The dialog creates a private cumulative snapshot of the BNR CVD REDCap
database from 1 January 2024 through the final day of a selected month.

{title:Before opening the dialog}

{pstd}
Load the workstation's local BNR configuration once in the current Stata
session. Then open the dialog with:

{phang2}{cmd:db bnr_cvd_redcap_extract}

{title:Fields}

{phang}{bf:Release year} must be 2024 or later.

{phang}{bf:Release month} is the final month included in the cumulative extract.

{phang}{bf:Replace an existing extract} should normally remain unticked. Tick it
only when an existing extract for the same month is deliberately being rerun.

{title:Equivalent command-line use}

{phang2}{cmd:do "$BNR_STATA/monthly/bnr_cvd_redcap_extract.do" 2024 1}

{pstd}
Add {cmd:replace} as the third argument only when replacement is intended.

{title:Important}

{pstd}
The token and output paths are controlled by {cmd:bnr_paths_LOCAL.do}; they are
not selected in the dialog. The extract runs in a temporary Stata frame, so any
dataset already open remains unchanged.

{title:Read the final report}

{pstd}
Routine controller code runs quietly. A successful run ends with
{bf:STEP 1: OPERATIONAL RUN SUMMARY}. Check the release, coverage, record
count and file locations shown there before continuing.

{pstd}
If the run cannot continue, the final block is {bf:STEP 1 DID NOT COMPLETE}.
Read its reason and log path. Correct the cause before rerunning; do not edit
generated extract files.

{smcl}
{* *! version 1.1.0 23jul2026}{...}
{vieweralsosee "BNR CVD Step 2 dialog" "db bnr_cvd_prepare_confidential"}{...}

{title:BNR CVD Step 2: confidential cumulative dataset}

{pstd}
This dialog creates a confidential, identifiable cumulative CVD dataset by
appending one selected cumulative post-2023 REDCap extract to the frozen
2009-2023 dataset.

{title:Before opening the dialog}

{pstd}
Complete Step 1 for the release required, then load the workstation's local
BNR configuration once in the current Stata session. Open the dialog with:

{phang2}{cmd:db bnr_cvd_prepare_confidential}

{title:Fields}

{phang}{bf:Release year} must be 2024 or later.

{phang}{bf:Release month} identifies the cumulative Step 1 release to use.
For example, March 2024 uses {cmd:bnr_cvd_redcap_raw_202403.dta}, containing
records through 31 March 2024.

{title:Equivalent command-line use}

{phang2}{cmd:do "$BNR_STATA/monthly/bnr_cvd_prepare_confidential.do" 2024 3}

{title:Outputs}

{pstd}
The command creates only confidential files:

{phang2}{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/bnr_cvd_confidential_YYYYMM_v01.dta}
{phang2}{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/bnr_cvd_confidential_YYYYMM_v01.yml}
{phang2}{cmd:$BNR_PRIVATE_LOGS/bnr_cvd_prepare_confidential_YYYYMM.log}

{title:Important}

{pstd}
Step 2 retains all records and source/operational fields. It does not apply
metric-specific eligibility restrictions, create deidentified metric inputs, or
create staging, public or website files. Those actions begin in Step 3.

{pstd}
The current post-2023 REDCap extracts contain abstracted cases only. The
variable {cmd:dco} is therefore set to zero for post-2023 records; this does
not mean that DCO surveillance is complete.

{title:Read the final report}

{pstd}
Routine controller code runs quietly. A successful run ends with
{bf:STEP 2: OPERATIONAL RUN SUMMARY}. Check the release, record counts and
private file locations before continuing.

{pstd}
If the run cannot continue, the final block is {bf:STEP 2 DID NOT COMPLETE}.
Read its reason and log path. Correct the source data or code, then rerun.

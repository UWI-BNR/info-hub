{smcl}
{* *! version 1.2.0 27jul2026}{...}
{vieweralsosee "BNR CVD Step 2 dialog" "db bnr_step2_cvd_confidential"}{...}

{title:BNR CVD Step 2: confidential cumulative dataset}

{pstd}
This dialog creates one confidential, identifiable cumulative CVD dataset. It
appends the selected cumulative post-2023 REDCap release from Step 1 to the
approved frozen 2009-2023 dataset.

{title:Before opening the dialog}

{pstd}
Complete Step 1 successfully for the required release. Use the same year and
month in Step 2. Open the dialog with:

{phang2}{cmd:db bnr_step2_cvd_confidential}

{title:Fields analysts may change}

{phang}{bf:Release year} must be 2024 or later.

{phang}{bf:Release month} identifies the cumulative Step 1 release. For
example, March 2024 uses {cmd:bnr_cvd_redcap_raw_202403.dta}, containing records
from 1 January 2024 through 31 March 2024.

{title:Equivalent command-line use}

{phang2}{cmd:do "$BNR_STATA/monthly/bnr_step2_cvd_confidential.do" 2024 3}

{title:Outputs}

{pstd}
The command creates only confidential files:

{phang2}{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/bnr_cvd_confidential_YYYYMM_v01.dta}
{phang2}{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/bnr_cvd_confidential_YYYYMM_v01.yml}
{phang2}{cmd:$BNR_PRIVATE_LOGS/bnr_cvd_prepare_confidential_YYYYMM.log}

{title:What Step 2 does not do}

{pstd}
Step 2 does not apply metric-specific exclusions, de-identify the data,
calculate metrics, create staging files, approve publication or copy files to
the website. Those actions occur in later steps.

{title:Important method rules}

{pstd}
Through 2023, age at event follows the approved {cmd:floor(cfage)} rule. From
2024, age is calculated from date of birth and event date.

{pstd}
Current post-2023 extracts contain abstracted cases only. {cmd:dco} is set to
zero after 2023 because the post-2023 DCO source is not yet included. This does
not mean that DCO ascertainment is complete.

{title:Read the final report}

{pstd}
A successful run ends with {bf:STEP 2: OPERATIONAL RUN SUMMARY}. Confirm the
release, source files, record counts and output locations before continuing.

{pstd}
A failed run ends with {bf:STEP 2 DID NOT COMPLETE}. Read the stated reason and
private log. Correct the source data, configuration or code, then rerun Step 2.
Do not continue to Step 3 with an incomplete output.

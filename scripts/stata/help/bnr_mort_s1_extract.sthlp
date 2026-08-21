{smcl}
{* *! version 0.1.0 16aug2026}{...}
{vieweralsosee "BNR mortality extract dialog" "db bnr_mort_s1_extract"}{...}

{title:BNR Mortality Step 1: extract mortality data}

{pstd}
This command extracts the BNR REDCap {bf:death_certificate} form and creates
the private all-deaths analytical input for the mortality workflow.

{pstd}
The separate REDCap tracking form is not extracted because it contains no
death information required for this workflow.

{title:Before first use}

{pstd}
The local copy of {cmd:bnr_mort_s1_extract.do} contains a clearly marked
mortality REDCap token placeholder in Section 1. Add the mortality project token
locally before the first run.

{pstd}
Never commit a populated API token to Git. The repository copy must retain the
placeholder.

{title:Open the dialog}

{phang2}{cmd:db bnr_mort_s1_extract}

{title:Fields}

{phang}{bf:Release year} is the final reporting year included in the analytical
dataset. The mortality database is expected to contain historical deaths from
2008 onward.

{phang}{bf:Release month} is the final completed month included in the release.

{phang}{bf:Replace an existing extract} should normally remain unticked. Tick it
only when the same release month is deliberately being rerun.

{title:Equivalent command-line use}

{phang2}{cmd:do "$BNR_STATA/mortality/bnr_mort_s1_extract.do" 2026 7}

{pstd}
Add {cmd:replace} as the third argument only when replacement is intended.

{title:What Step 1 keeps}

{pstd}
Step 1 retains the full death-certificate variable set, including confidential
identity and linkage information such as {cmd:nrn}. NRN is the national
identifier and is deliberately preserved for possible later DCO linkage.

{pstd}
The original cause-of-death fields {cmd:cod1a}, {cmd:cod1b}, {cmd:cod1c},
{cmd:cod1d}, {cmd:cod2a} and {cmd:cod2b} are never overwritten. Step 1 creates
cleaned analytical copies only.

{title:Date handling}

{pstd}
The raw CSV is the complete death-certificate-form extract at the time of the
run. Records with a valid death date after the selected month-end are excluded
from the analytical DTA.

{pstd}
Records with a missing or invalid death date are retained in the analytical
DTA and flagged. This allows source-data problems to be reviewed rather than
silently removed.

{title:QA approach}

{pstd}
Most data problems are retained and reported. Step 1 stops only when a
mandatory structural assumption fails, for example missing mandatory fields,
missing record IDs, a non-unique {cmd:record_id}, or an unexpected REDCap event
structure.

{title:Outputs}

{pstd}
The Step 1 package is deliberately small:

{phang2}private raw CSV{break}
{phang2}private analytical DTA{break}
{phang2}small YAML operational receipt{break}
{phang2}private Stata log

{pstd}
The files are written under:

{phang2}{cmd:$BNR_DATA_RAW/redcap/mortality/yYYYY/mMM/}

{title:Important}

{pstd}
All Step 1 mortality files are confidential. They must remain outside the Git
repository and outside the public publication pathway.

{pstd}
Step 1 does not classify AMI, stroke or underlying cause of death. Cause
classification begins only in Mortality Step 2.

{title:Read the final report}

{pstd}
A successful run ends with {bf:MORTALITY STEP 1: OPERATIONAL RUN SUMMARY}.
Review the record counts and QA counts before proceeding.

{pstd}
If the run cannot continue, the final block is
{bf:MORTALITY STEP 1 DID NOT COMPLETE}. Correct the cause and rerun; do not
manually edit generated output files.

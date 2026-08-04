{smcl}
{title:BNR Briefing Step 1: Build review package}

{p 4 4 2}
Opens the common BNR briefing-build dialog. The selected analyst-owned DO file
runs and creates a private staging package. This action does not approve,
publish, copy to the website, or render Quarto.

{title:Dialog}

{p 4 4 2}
Open {bf:User > BNR > Briefing workflow > Step 1: Build review package}.

{title:Current implementation}

{p 4 4 2}
CVD incidence is operational. Case-fatality, length of stay and mortality are
shown as the agreed four-briefing pathway but stop safely until their analyst
DO files are migrated.

{title:Inputs}

{p 4 4 2}
Select the Step 3 dataset release year and month, and the briefing version.
The analysis end year is derived automatically as the year before the dataset
release. Incidence reads Step 3 counts-and-incidence dataset version 01. Use
replacement only for an existing unapproved staging package that has already
been checked.

{title:Command-line use}

{p 8 8 2}
do "$BNR_STATA/briefings/bnr_step1_build_briefing.do" "CVD incidence rates" 2024 1 1

{title:Output boundary}

{p 4 4 2}
Successful output is written below
{bf:$BNR_STAGING/briefings/cvd_incidence_2023_v1}. Review remains a separate
human action. Inspect the staged analytical artefacts and disclosure flags,
then run Briefing Step 2 to record the completed manual approval. Step 1 does
not ask the analyst to edit disclosure_review.txt manually.

{smcl}
{title:BNR Briefing Step 2: Review and approve}

{p 4 4 2}
Records the completed human review of a private briefing package created by
Briefing Step 1. Step 2 creates a manifest and approval receipt. It does not
rerun analysis, apply suppression, publish, render Quarto or run Git.

{title:Before running Step 2}

{p 4 4 2}
Review every staged dataset, figure, workbook, metadata file and automated
disclosure flag. Disclosure control for occasional briefings is an analyst-led
human judgement; Step 2 documents that the review occurred.

{title:Ad-hoc briefings}

{p 4 4 2}
For an analyst-created or externally requested briefing, select
{bf:Ad-hoc briefing} and enter the exact package ID already created below
{bf:$BNR_STAGING/briefings}. The package ID must use lowercase letters,
numbers and underscores and end in a version suffix such as {bf:_v1}.
The routine release-year, release-month and version fields are ignored for
this selection.

{p 4 4 2}
The staged release control must declare {bf:output_type: briefing},
{bf:briefing_kind: ad_hoc}, {bf:create_zip: 1}, and {bf:list_zip: 1}.
Step 2 does not run the ad-hoc analysis; the analyst-owned DO file must already
have created and completed the private staging package.

{title:Approver roles}

{p 4 4 2}
The permitted roles are {bf:BNR Lead}, {bf:BNR Analyst} and
{bf:BNR Developer}.

{title:Required confirmations}

{p 4 4 2}
All five boxes must be ticked: source and period; analysis and results; manual
disclosure review; labels and metadata; and package completeness.

{title:Outputs}

{p 4 4 2}
The following private controls are written inside the staged package review
folder: {bf:approval.yml}, {bf:public_manifest.csv}, and the completed
{bf:disclosure_review.txt}. Only files listed in the manifest can be published
by Step 3.

{title:Command-line example}

{p 8 8 2}
do "$BNR_STATA/briefings/bnr_step2_approve_briefing.do" "CVD incidence rates" 2024 1 1 "Full name" "BNR Analyst" source results disclosure labels complete

{p 8 8 2}
do "$BNR_STATA/briefings/bnr_step2_approve_briefing.do" "Ad-hoc briefing" 2024 1 1 "Full name" "BNR Analyst" source results disclosure labels complete "cvd_external_request_2023_v1"

{title:Correction rule}

{p 4 4 2}
An existing approval is never overwritten. If an approved product needs to be
changed, rerun Step 1 with a new briefing version, review the new package, and
approve that new version.

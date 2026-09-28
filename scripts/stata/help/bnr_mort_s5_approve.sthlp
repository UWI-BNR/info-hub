{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_mort_s5_approve"}{...}

{title:BNR mortality Step 5: Approve the reviewed release}

{title:What this step does}

{pstd}
Step 5 records human approval of the exact mortality candidate reviewed in
Step 4. It creates an approved public-ready package but does not publish it.

{title:Before you run it}

{pstd}
Complete the full Step 4 review. All required QA checks must pass, disclosure
protection must be checked and the candidate must be unchanged.

{title:What to enter}

{phang}{bf:Release year and month} identify the reviewed Step 4 candidate.

{phang}{bf:Full name and BNR role} identify the authorised approver.

{phang}{bf:Review confirmations} must be ticked only after each stated action
has actually been completed. The approval button remains unavailable until all
five confirmations are ticked.

{title:After running}

{pstd}
Confirm that the summary states {bf:APPROVED - PENDING STEP 6} and identifies
the approval receipt and manifest. Continue to mortality Step 6 only when
publication is authorised.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/mortality/approve.html":Technical Manual: Approve the reviewed mortality data package}.

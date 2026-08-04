{smcl}
{title:BNR Briefing Step 3: Publish approved package}

{p 4 4 2}
Publishes exactly the analytical products approved in Briefing Step 2. Step 3
does not rerun analysis, alter suppression, modify a QMD, render Quarto or run
Git.

{title:Required approval}

{p 4 4 2}
Step 3 stops unless the selected staging package contains a valid
{bf:review/approval.yml} and {bf:review/public_manifest.csv}. The receipt must
identify the selected package and one of the authorised roles: BNR Lead, BNR
Analyst or BNR Developer.

{title:Change protection}

{p 4 4 2}
The manifest itself and every approved staged file are checked using file size
and Stata checksum. If anything changed after approval, publication stops. A
correction requires a new briefing version and a new Step 2 approval.

{title:Publication route}

{p 4 4 2}
Manifested files are copied first to the authoritative package below
{bf:$BNR_PUBLIC/briefings}. Step 3 then creates the requested ZIP and refreshes
the disposable mirror below {bf:site/downloads/files/briefings}.

{p 4 4 2}
Private approval, disclosure and release-control files remain in staging and
are never copied to either public destination.

{title:Command-line example}

{p 8 8 2}
do "$BNR_STATA/briefings/bnr_step3_publish_briefing.do" "CVD incidence rates" 2024 1 1 publish

{title:After Step 3}

{p 4 4 2}
Review the website locally, render Quarto as usual, and then use the normal Git
and GitHub deployment process. Those actions remain outside this Stata step.

{smcl}
{title:BNR Mortality Step 6: Publish approved outputs}

{p 4 4 2}
{cmd:db bnr_mort_s6_publish} opens the mortality Step 6 publication dialog.
Use it only after mortality Step 5 has successfully approved the selected
release and created its private {cmd:public_ready/} package.

{title:Purpose}

{p 4 4 2}
Mortality Step 6 promotes one already-approved mortality burden package. It
verifies {cmd:approval.yml}, verifies the approved manifest itself, and checks
every payload fingerprint before copying any analytical file.

{p 4 4 2}
Step 6 does not calculate mortality measures, apply or change suppression,
edit approved metadata, or make a new approval decision.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/mortality/bnr_mort_s6_publish.do"}
{it:year month} [{cmd:replace}]

{p 8 8 2}
Example:
{cmd:. do "$BNR_STATA/mortality/bnr_mort_s6_publish.do" 2026 7}

{title:Approval and manifest checks}

{p 4 4 2}
Step 6 requires a mortality Step 5 approval for the selected release. It checks
the package and release identifiers, authorised BNR role, disclosure-control
approval, all five human approval confirmations, the pending Step 6 status,
and the checksum and size of {cmd:public_manifest.csv}.

{p 4 4 2}
The manifest must contain exactly ten unique payloads:

{p 8 12 2}
- release-stamped DTA and CSV datasets;

{p 8 12 2}
- stable current DTA and CSV datasets;

{p 8 12 2}
- release-stamped and current YAML metadata; and

{p 8 12 2}
- mortality burden package metadata; and

{p 8 12 2}
- the fixed 2015-2019 monthly-reference DTA, CSV and approved metadata.

{p 4 4 2}
Each private source file is rechecked against the approved size and checksum
before publication. The fixed reference metadata must also say
{cmd:status: approved_reference_asset} and point to {cmd:approval.yml}. The same
checks are repeated after copying to the authoritative public area and after
refreshing the website mirror.

{title:Authoritative public output}

{p 4 4 2}
The approved release is written below:

{p 8 8 2}
{cmd:$BNR_PUBLIC/metrics/mortality/burden/}

{p 4 4 2}
Dataset files are placed under {cmd:datasets/}. Metadata is placed under
{cmd:metadata/}. The package-relative paths and file contents are not changed.

{title:Release ZIP and catalogue record}

{p 4 4 2}
After verifying the authoritative public copy, Step 6 creates one ZIP containing
the ten approved payloads:

{p 8 8 2}
{cmd:bnr_mort_burden_mort_YYYY_MM.zip}

{p 4 4 2}
It then creates one release-specific catalogue record under
{cmd:catalogue/mort_YYYY_MM.yml}. This record registers the ZIP for the central
Downloads catalogue. It is publication metadata, not an additional analytical
payload.

{title:Website-download mirror}

{p 4 4 2}
An identical disposable copy is refreshed below:

{p 8 8 2}
{cmd:$BNR_REPO/site/downloads/files/metrics/mortality/burden/}

{p 4 4 2}
The website mirror is copied from the authoritative public output, never
independently from private staging. {cmd:approval.yml} and
{cmd:public_manifest.csv} remain private and are not copied.

{title:Replace}

{p 4 4 2}
Without {cmd:replace}, Step 6 stops if release-stamped public or website files,
the release ZIP, or the catalogue record already exist. Stable current files
are refreshed during every successful publication.

{p 4 4 2}
Use {cmd:replace} only for deliberate republication after inspecting the
existing outputs and the reason for the rerun. A failed filesystem operation
may leave a partly copied release, so inspect both public destinations before
rerunning.

{title:Synthetic test protection}

{p 4 4 2}
The reserved 2099 suppression-test release is rejected by Step 6. Synthetic
mortality fixtures must remain under the repository test area and may never be
published.

{title:Workflow boundary}

{p 4 4 2}
Step 6 does not rebuild the central Downloads catalogue, render Quarto, commit
files to Git, push to GitHub or deploy the website. The mortality dashboard is
a downstream presentation consumer, not an additional analytical workflow
step.

{title:Next action}

{p 4 4 2}
After Step 6 succeeds, run:

{p 8 8 2}
{cmd:python site/scripts/build_download_catalogue.py}

{p 4 4 2}
Inspect the Downloads page and published files before the normal commit,
render and deployment process.

{title:End-of-run status}

{p 4 4 2}
Routine commands run quietly. A successful run ends with
{bf:MORTALITY STEP 6: OPERATIONAL RUN SUMMARY}, reporting {bf:PUBLISHED}, the
release, approver, ZIP, catalogue record, authoritative public location,
website mirror, verification result and private log.

{p 4 4 2}
A controlled failure uses the same heading, reports {bf:Did not complete}, and
states the reason and required response.

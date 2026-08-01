{smcl}
{title:BNR occasional briefings: complete a private staging package}

{p 4 4 2}
{cmd:bnr_stage_briefing.do} completes the routine private packaging work after an
analyst-owned occasional-briefing DO file has created its datasets, figures,
release-control file and disclosure-flags file. It does not approve or publish
the briefing.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/common/bnr_stage_briefing.do" "{it:briefing_id}"}

{title:Required staging inputs}

{p 4 4 2}
The briefing must already exist under
{cmd:$BNR_STAGING/briefings/{it:briefing_id}/}. Its
{cmd:metadata/release_control.yml} declares the intended public datasets,
figures, workbook and ZIP settings. Its
{cmd:review/disclosure_flags.csv} is created by the briefing-specific analysis.

{title:What the helper creates}

{p 4 4 2}
The helper creates dataset YAML metadata, briefing metadata, the README,
workbook, download manifest and a fresh
{cmd:review/disclosure_review.txt} template.

{title:Important}

{p 4 4 2}
The disclosure-review template is overwritten whenever the analysis is rebuilt.
This prevents an earlier approval carrying forward after results have changed.

{p 4 4 2}
The helper never writes to {cmd:outputs/public/} or
{cmd:site/downloads/files/}. After review, use
{help bnr_approve_publish_briefing:bnr_approve_publish_briefing.do}.


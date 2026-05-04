{smcl}
{* *! version 1.0.0 04may2026}{...}
{vieweralsosee "bnr_workbook" "help bnr_workbook"}{...}

{title:Title}

{p 4 8}{cmd:bnr_yml} {hline 2} write a simple YAML metadata file from a released BNR Stata dataset{p_end}

{title:Syntax}

{p 8 12 2}
{cmd:bnr_yml},
{cmd:dtafile(}{it:string}{cmd:)}
{cmd:ymlfile(}{it:string}{cmd:)}
{cmd:datasetid(}{it:string}{cmd:)}

{title:Description}

{pstd}
{cmd:bnr_yml} writes one dataset-level YAML metadata file from one released
Stata {cmd:.dta} file. It is intended for BNR static briefing output bundles.
The Stata dataset is treated as the source of truth for metadata.
{p_end}

{pstd}
The command reads metadata from:
{p_end}

{p 8 12}{c -} dataset-level Stata notes{p_end}
{p 8 12}{c -} variable names{p_end}
{p 8 12}{c -} storage types{p_end}
{p 8 12}{c -} display formats{p_end}
{p 8 12}{c -} variable labels{p_end}
{p 8 12}{c -} value-label names{p_end}
{p 8 12}{c -} observed labelled categories{p_end}

{pstd}
The output YAML is a companion metadata file for public CSV users. The DTA
retains the full Stata-native labels, value labels, and notes.
{p_end}

{title:Options}

{phang}
{cmd:dtafile(}{it:string}{cmd:)} specifies the released Stata dataset to read.
This file must already exist.

{phang}
{cmd:ymlfile(}{it:string}{cmd:)} specifies the YAML file to create. Existing
files are replaced.

{phang}
{cmd:datasetid(}{it:string}{cmd:)} specifies the short dataset identifier used
inside the YAML file and in relative file paths.

{title:Required note convention}

{pstd}
Dataset-level metadata intended for export must be stored as structured Stata
notes using this pattern:
{p_end}

{p 8 12 2}{cmd:notes _dta: field_name: field value}{p_end}

{pstd}
For example:
{p_end}

{p 8 12 2}{cmd:notes _dta: title: Weekly hospital CVD cases, Barbados, 2023}{p_end}
{p 8 12 2}{cmd:notes _dta: source: Barbados National Registry approved cardiovascular registry extract}{p_end}
{p 8 12 2}{cmd:notes _dta: limitations: Counts describe hospital-ascertained cases and should not be interpreted as population incidence.}{p_end}

{pstd}
Notes without a colon are ignored. Field names are made YAML-friendly by
converting to lower case and replacing spaces, hyphens, slashes, and periods
with underscores.
{p_end}

{title:Output structure}

{pstd}
The YAML file contains four main sections:
{p_end}

{p 8 12}{cmd:schema}: metadata schema name{p_end}
{p 8 12}{cmd:dataset_id}: short dataset identifier{p_end}
{p 8 12}{cmd:files}: relative paths for DTA, CSV, and YML files{p_end}
{p 8 12}{cmd:metadata}: dataset-level notes exported from the DTA{p_end}
{p 8 12}{cmd:variables}: variable-level metadata exported from the DTA{p_end}

{pstd}
Observed labelled categories are written as a readable string, for example:
{p_end}

{p 8 12}{cmd:1=Stroke; 2=Heart attack;}{p_end}

{title:Example}

{pstd}
Create YAML metadata for a released dataset in a briefing staging bundle:
{p_end}

{phang2}{cmd:. bnr_yml, ///}{p_end}
{phang2}{cmd:    dtafile("`stagingdatasets'/cvd_cases_weekly.dta") ///}{p_end}
{phang2}{cmd:    ymlfile("`stagingmetadata'/cvd_cases_weekly.yml") ///}{p_end}
{phang2}{cmd:    datasetid("cvd_cases_weekly")}{p_end}

{title:Remarks}

{pstd}
{cmd:bnr_yml} opens the specified DTA file and restores the current dataset when
finished. It does not create the CSV file. The briefing DO file should save the
DTA and export the CSV before calling {cmd:bnr_yml}.
{p_end}

{pstd}
This command is standard BNR release-package machinery. Do not edit it for an
individual briefing. Edit the dataset labels, value labels, and structured
Stata notes in the briefing DO file instead.
{p_end}

{title:Saved results}

{pstd}
{cmd:bnr_yml} saves no results in {cmd:r()}, {cmd:e()}, or {cmd:s()}.
{p_end}

{title:Author}

{pstd}
BNR Refit Phase 2 / BNR Information Hub workflow utility.
{p_end}

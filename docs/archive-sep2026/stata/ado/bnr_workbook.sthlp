{smcl}
{* *! version 1.0.0 04may2026}{...}
{vieweralsosee "bnr_yml" "help bnr_yml"}{...}

{title:Title}

{p 4 8}{cmd:bnr_workbook} {hline 2} add one released BNR Stata dataset and its metadata to an Excel workbook{p_end}

{title:Syntax}

{p 8 12 2}
{cmd:bnr_workbook},
{cmd:dtafile(}{it:string}{cmd:)}
{cmd:xlsxfile(}{it:string}{cmd:)}
{cmd:datasetid(}{it:string}{cmd:)}
{cmd:datasheet(}{it:string}{cmd:)}
{cmd:metasheet(}{it:string}{cmd:)}
{cmd:varsheet(}{it:string}{cmd:)}

{title:Description}

{pstd}
{cmd:bnr_workbook} adds one released Stata {cmd:.dta} dataset to a BNR public
briefing Excel workbook. It creates or updates three worksheets for that
dataset:
{p_end}

{p 8 12}{c -} a data worksheet containing the dataset values{p_end}
{p 8 12}{c -} a dataset metadata worksheet based on structured Stata notes{p_end}
{p 8 12}{c -} a variable metadata worksheet based on labels and value labels{p_end}

{pstd}
The workbook is a human-friendly convenience copy. The canonical release files
remain the DTA, CSV, and YML files in the briefing output bundle.
{p_end}

{title:Options}

{phang}
{cmd:dtafile(}{it:string}{cmd:)} specifies the released Stata dataset to add to
the workbook. This file must already exist.

{phang}
{cmd:xlsxfile(}{it:string}{cmd:)} specifies the Excel workbook to update.
In the standard BNR workflow, the briefing DO file creates a README sheet first
using {cmd:export excel, replace}; {cmd:bnr_workbook} then adds dataset and
metadata sheets using {cmd:sheetmodify}.

{phang}
{cmd:datasetid(}{it:string}{cmd:)} specifies the short dataset identifier to
write into metadata worksheets.

{phang}
{cmd:datasheet(}{it:string}{cmd:)} specifies the worksheet name for the data.

{phang}
{cmd:metasheet(}{it:string}{cmd:)} specifies the worksheet name for dataset-level
metadata.

{phang}
{cmd:varsheet(}{it:string}{cmd:)} specifies the worksheet name for variable-level
metadata.

{title:Required note convention}

{pstd}
Dataset-level metadata should be stored as structured Stata notes before the
DTA is saved:
{p_end}

{p 8 12 2}{cmd:notes _dta: field_name: field value}{p_end}

{pstd}
For example:
{p_end}

{p 8 12 2}{cmd:notes _dta: title: Weekly hospital CVD cases, Barbados, 2023}{p_end}
{p 8 12 2}{cmd:notes _dta: source: Barbados National Registry approved cardiovascular registry extract}{p_end}
{p 8 12 2}{cmd:notes _dta: limitations: Counts describe hospital-ascertained cases and should not be interpreted as population incidence.}{p_end}

{pstd}
Notes without a colon are ignored.
{p_end}

{title:Workbook sheets created}

{pstd}
For each DTA file, {cmd:bnr_workbook} writes three worksheets:
{p_end}

{phang}
{it:datasheet} contains the released data values.

{phang}
{it:metasheet} contains dataset-level metadata with columns:
{cmd:dataset_id}, {cmd:field}, and {cmd:value}.

{phang}
{it:varsheet} contains variable-level metadata with columns:
{cmd:dataset_id}, {cmd:variable_name}, {cmd:storage_type},
{cmd:display_format}, {cmd:value_label}, {cmd:variable_label}, and
{cmd:categories}.

{pstd}
Observed labelled categories are written as a readable string, for example:
{p_end}

{p 8 12}{cmd:1=Stroke; 2=Heart attack;}{p_end}

{title:Example}

{pstd}
Add the weekly cases dataset and its metadata to a briefing workbook:
{p_end}

{phang2}{cmd:. bnr_workbook, ///}{p_end}
{phang2}{cmd:    dtafile("`stagingdatasets'/cvd_cases_weekly.dta") ///}{p_end}
{phang2}{cmd:    xlsxfile("`workbook_file'") ///}{p_end}
{phang2}{cmd:    datasetid("cvd_cases_weekly") ///}{p_end}
{phang2}{cmd:    datasheet("cvd_cases_weekly") ///}{p_end}
{phang2}{cmd:    metasheet("meta_weekly") ///}{p_end}
{phang2}{cmd:    varsheet("vars_weekly")}{p_end}

{title:Recommended workflow}

{pstd}
In a briefing DO file, create the workbook with a README sheet first, then call
{cmd:bnr_workbook} once for each released dataset.
{p_end}

{phang2}{cmd:. export excel using "`workbook_file'", sheet("readme") firstrow(variables) replace}{p_end}
{phang2}{cmd:. bnr_workbook, dtafile(...) xlsxfile("`workbook_file'") datasetid(...) datasheet(...) metasheet(...) varsheet(...)}{p_end}

{title:Remarks}

{pstd}
{cmd:bnr_workbook} opens the specified DTA file and restores the current dataset
when finished. It uses {cmd:export excel, sheetmodify}; for clean output, the
briefing DO file should normally erase or recreate the workbook before adding
sheets.
{p_end}

{pstd}
This command is standard BNR release-package machinery. Do not edit it for an
individual briefing. Edit the briefing DO file, dataset labels, value labels,
and structured Stata notes instead.
{p_end}

{title:Saved results}

{pstd}
{cmd:bnr_workbook} saves no results in {cmd:r()}, {cmd:e()}, or {cmd:s()}.
{p_end}

{title:Author}

{pstd}
BNR Refit Phase 2 / BNR Information Hub workflow utility.
{p_end}

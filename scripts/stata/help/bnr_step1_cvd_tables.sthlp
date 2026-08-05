{smcl}
{title:BNR Tables Step 1: Build private CVD table package}

{p 4 4 2}
{cmd:db bnr_step1_cvd_tables} opens the operational dialog. Step 1 calculates
seven CVD table datasets from one completed Step 3 {cmd:all_variables} release
and writes an unsuppressed package to private staging for review.

{p 4 4 2}
Step 1 does not suppress cells, approve results, create public Markdown or a
public workbook, copy files to the website, or publish anything.

{title:Before running}

{p 4 4 2}
Confirm that the intended Step 3 release is complete and note its year, month
and two-digit version from this filename:

{p 8 8 2}
{cmd:bnr_cvd_input_all_variables_YYYYMM_vXX.dta}

{p 4 4 2}
The matching DTA and YML files must both be present. The controlled Barbados
population and WHO standard-population datasets must be available under
{cmd:$BNR_PRIVATE_WORK}. The user-written Stata command {cmd:distrate} must
already be installed and validated; the production file never installs it
automatically.

{title:Dialog instructions}

{p 4 4 2}
1. Open {bf:User > BNR > Produce tables > Step 1: Build private table package}.

{p 4 4 2}
2. Enter the Step 3 release year and month.

{p 4 4 2}
3. Enter the input version. For example, enter {cmd:1} for a filename ending
{cmd:_v01.dta}.

{p 4 4 2}
4. Leave replacement unticked for the first run. Tick it only when deliberately
rebuilding the same private staging package after checking the selected release.

{p 4 4 2}
5. Select {bf:Build Step 1 package}. Read the operational run summary and then
review {cmd:review/qa_summary.txt} before proceeding.

{title:Command-line syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/tables/bnr_step1_cvd_tables.do"} {it:year} {it:month} {it:input_version} [{cmd:replace}]

{title:Examples}

{p 8 8 2}
First build of the January 2024, version 01 package:
{cmd:. do "$BNR_STATA/tables/bnr_step1_cvd_tables.do" 2024 1 1}

{p 8 8 2}
Deliberate replacement of that private package:
{cmd:. do "$BNR_STATA/tables/bnr_step1_cvd_tables.do" 2024 1 1 replace}

{title:Private staging output}

{p 4 4 2}
Successful output is written outside the public repository under:

{p 8 8 2}
{cmd:$BNR_STAGING/tables/cvd/cvd_tables_YYYY_MM/}

{p 4 4 2}
The package contains:

{p 8 8 2}
{cmd:datasets/} - seven exact, unsuppressed DTA files and seven matching CSV files;

{p 8 8 2}
{cmd:metadata/} - package metadata, an input manifest and the table catalogue;

{p 8 8 2}
{cmd:review/qa_summary.txt} - run-specific missingness and chronology flags; and

{p 8 8 2}
{cmd:readme.txt} - the package boundary and next action.

{title:Period rules}

{p 4 4 2}
Year-to-date output is permanent. Annual counts and length-of-stay data label
the current year {cmd:year_to_date}; monthly counts retain the current reporting
month and future months explicitly; the age-70 table compares the current YTD
period with the preceding five years. Later presentation code can therefore add
the required row or Quarto year tab directly from the data.

{p 4 4 2}
Incidence uses completed calendar years only. Case-fatality uses completed
two-year periods only. These endpoints are derived automatically from the
selected Step 3 release.

{title:Review and stopping rules}

{p 4 4 2}
Step 1 stops if required inputs or variables are absent, event identifiers are
not unique, coded values are unexpected, known-age incidence cells do not match
the population reference, or an existing package would be overwritten without
explicit authorisation.

{p 4 4 2}
The QA report also lists review flags that do not automatically change the
source data: missing age, negative stays, very long stays and deaths dated
before an event. Correct source data or code and rerun; never edit generated
table files by hand.

{title:Legacy cleaning}

{p 4 4 2}
One clearly marked block sets implausibly large legacy dates of death and
discharge to missing in the working copy only. The Step 3 source is not changed.
This block may be retired only after upstream cleaning is confirmed and the
optional historical regression comparison is rerun.

{title:Historical regression helper}

{p 4 4 2}
The 2010-2023 regression comparison is completed implementation evidence, not a
monthly production step. {cmd:bnr_step1_cvd_tables_regression.do} is retained
outside the menu and may be rerun after a material analytical, reference-data,
legacy-cleaning or code-structure change.

{title:Next step}

{p 4 4 2}
Review the staging datasets, metadata and QA summary. Table Step 2 will apply
the BNR disclosure-control policy, create public-ready table products and record
human approval. Until Step 2 is completed, do not copy Step 1 files to a public
or website location.

{smcl}
{title:BNR Step 3: Create deidentified metric-input datasets}

{p 4 4 2}
{cmd:db bnr_step3_metric_inputs} opens the Step 3 dialog. It creates only the
private datasets selected by the analyst.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do"} {it:year} {it:month} {it:dataset} [{it:dataset} ...] [{cmd:replace}]

{p 4 4 2}
Available dataset names are {cmd:count}, {cmd:case_fatality},
{cmd:length_of_stay}, {cmd:performance}, and {cmd:all_variables}. At least one
is required. The optional final word {cmd:replace} deliberately replaces only
the selected outputs.

{title:Examples}

{p 8 8 2}
{cmd:. do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 3 count case_fatality length_of_stay performance all_variables}

{p 8 8 2}
Create only the count input:
{cmd:. do "$BNR_STATA/monthly/bnr_step3_metric_inputs.do" 2024 3 count}

{title:Outputs}

{p 4 4 2}
Selected datasets and YAML receipts are saved under:

{p 8 8 2}
{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/}

{p 4 4 2}
All outputs remain confidential and outside Git. Step 3 calculates no metrics
and creates no staging or public files.

{title:Final check}

{p 4 4 2}
A successful run ends with {bf:STEP 3: OPERATIONAL RUN SUMMARY}. Confirm the
release, record count, selected datasets, and output folder before continuing.

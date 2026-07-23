{smcl}
{title:BNR Step 3: Create deidentified metric-input datasets}

{p 4 4 2}
{cmd:db bnr_cvd_create_metric_inputs} opens the Step 3 dialog. It creates only
the private datasets whose tick boxes are selected.

{title:Syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/monthly/bnr_cvd_create_metric_inputs.do"} {it:year} {it:month} {it:dataset} [{it:dataset} ...] [{cmd:replace}]

{p 4 4 2}
State every dataset that you authorise in words: {cmd:count},
{cmd:case_fatality}, {cmd:length_of_stay} and/or {cmd:performance}. At least
one dataset is required. Use the optional final word {cmd:replace} only when
deliberately replacing selected existing files.

{title:Example}

{p 8 8 2}
{cmd:. do "$BNR_STATA/monthly/bnr_cvd_create_metric_inputs.do" 2024 3 count case_fatality length_of_stay performance}

{p 8 8 2}
To create only the count input: {cmd:. do "$BNR_STATA/monthly/bnr_cvd_create_metric_inputs.do" 2024 3 count}

{p 8 8 2}
To replace selected existing count and performance inputs deliberately:
{cmd:. do "$BNR_STATA/monthly/bnr_cvd_create_metric_inputs.do" 2024 3 count performance replace}

{title:Outputs}

{p 4 4 2}
The selected files are saved under:

{p 8 8 2}
{cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/}

{p 4 4 2}
Each Stata dataset has a YAML receipt. All outputs remain confidential and
outside Git. This step calculates no metrics and creates no staging or public
outputs.

{title:Read the final report}

{p 4 4 2}
Routine controller code runs quietly. A successful run ends with
{bf:STEP 3: OPERATIONAL RUN SUMMARY}. Confirm that every authorised dataset
and receipt is listed before continuing.

{p 4 4 2}
If the run cannot continue, the final block is {bf:STEP 3 DID NOT COMPLETE}.
Read its reason and log path. Do not use {cmd:replace} merely to bypass an
error.

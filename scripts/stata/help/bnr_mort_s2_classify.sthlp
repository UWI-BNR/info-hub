{smcl}
{* *! version 2.0.0 28sep2026}{...}
{vieweralsosee "Open this dialog" "db bnr_mort_s2_classify"}{...}

{title:BNR mortality Step 2: Classify causes of death}

{title:What this step does}

{pstd}
Step 2 applies the approved BNR rules to the recorded cause-of-death wording.
It creates practical surveillance classifications; it is not formal national
ICD underlying-cause coding.

{title:Before you run it}

{pstd}
Run mortality Step 1 successfully for the same release period. Classification
dictionaries and rules must be the approved repository versions.

{title:What to enter}

{phang}{bf:Release year and month} must match the completed Step 1 extract.

{phang}{bf:Authorise replacement} should normally remain unticked. Reclassify
an existing release only after an authorised source or rule correction.

{title:After running}

{pstd}
Read the final summary and check the classification QA results. If Step 2
succeeds, continue to mortality Step 3. Do not manually alter classifications
in generated files.

{title:Full instructions}

{pstd}
See the {browse "https://uwi-bnr.github.io/info-hub/technical/workflows/mortality/classify.html":Technical Manual: Classify CVD deaths}.

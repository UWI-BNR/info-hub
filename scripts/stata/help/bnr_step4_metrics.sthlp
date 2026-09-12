{smcl}
{title:BNR Step 4: Calculate and privately stage combined CVD metrics}

{pstd}Step 4 calculates the combined CVD package from a CVD release and a completed mortality release. It remains private: it does not review, approve or publish.

{title:Syntax}
{phang2}{cmd:do "$BNR_STATA/monthly/bnr_step4_metrics.do"} {it:cvd_year cvd_month mortality_year mortality_month} [{cmd:replace}]

{title:Example}
{phang2}{cmd:. do "$BNR_STATA/monthly/bnr_step4_metrics.do" 2024 4 2026 7}

{title:Inputs and private output}
{pstd}Step 4 requires the Step 3 count input under {cmd:$BNR_DATA_DERIVED/cvd/yYYYY/mMM/metric_inputs/} and the completed linkage/rate calculation associated with the supplied mortality release. It writes the release package under:

{phang2}{cmd:$BNR_STAGING/metrics/cvd/cvd_YYYY_MM/}

{pstd}The package contains private burden data, annual incidence-rate data and private component evidence. Annual DCO-enhanced public-shaped rows cover All CVD, Heart and Stroke; all, female and male; and Primary/Inclusive mortality definitions. Additional-DCO counts and hospital-plus-DCO counts are annual, all-age only. DCO component accounting remains private.

{title:Disclosure policy}
{pstd}Step 4 retains exact values in private staging. Policy {cmd:bnr_sdc_v1} marks supporting frequencies 1--5 for primary protection; Step 5 applies deterministic companion protection and creates the human-review material. Do not edit generated files manually.

{title:Next action}
{pstd}Run Step 5 {cmd:prepare}. The reference is the {browse "https://ukdataservice.ac.uk/app/uploads/sdc-handbook-v2.0.pdf":Handbook on Statistical Disclosure Control for Outputs}; {cmd:n < 6} is BNR's operational rule, not a universal threshold.

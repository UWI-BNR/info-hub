/*******************************************************************************
DO-FILE: bnr_report_annual_2025_interpretation.do
VERSION: 1.2.0 (7 September 2026)
PURPOSE: Analyst-owned interpretation text for the 2025 annual CVD report.

EDITING RULE:
  Edit narrative locals in this file only when updating 2025 interpretation.
  Do not place calculations, release selection or publication logic here.

The text below is a design-development interpretation based on the approved
public releases cvd_2026_01 and mort_2026_07. It is intentionally concise so
page flow can be judged in the candidate PDF. It remains subject to analyst
review before approval.

STATA NAMING NOTE:
  Local macro names are kept comfortably below Stata's 31-character limit.
*******************************************************************************/

*******************************************************************************
* BNR ANALYST GUIDE - EDITABLE ANNUAL NARRATIVE
*
* BNR ANALYST: THIS IS THE PRINCIPAL EDITABLE FILE for the 2025 standard
* section. Edit text inside the local macros below after reviewing the complete
* candidate report and its declared public releases. Keep the macro names,
* quotation marks and include location unchanged because the standard template
* calls these names directly.
*
* Appropriate edits: accurate plain-language interpretation, emphasis and
* caveats for the stated year. Inappropriate edits: calculations, metric
* filters, release selection, disclosure decisions, putpdf layout or workflow
* controls. If a number changes, correct the source release/workflow and rerun;
* do not make the narrative contradict the published table.
*******************************************************************************

* -----------------------------------------------------------------------------
* Year in brief
* -----------------------------------------------------------------------------

* EDITABLE BLOCK.
* These three messages appear in order at the bottom of the one-page annual
* summary. Each should state one decision-relevant finding in plain language.

local annual_summary_message_1 ///
    "There were 1,021 hospital-recorded CVD events in 2025, about 27% above the published previous-five-year average of 805.8. The Primary national estimate was 1,115.8 events after adding the estimated contribution from events identified through death records."

local annual_summary_message_2 ///
    "The Primary national age-standardised CVD event rate was higher in men than women: 288.8 compared with 184.0 per 100,000."

local annual_summary_message_3 ///
    "Stroke accounted for 67.9% of hospital-recorded CVD events in 2025."

local annual_summary_message_4 ///
    "There were 368 Primary CVD deaths in 2025, about 7% below the previous-five-year mean of 394.2. The Inclusive definition counted 588 deaths, close to its recent five-year comparator, showing how strongly mortality totals depend on whether Possible deaths are included. Read more about our CVD death definitions in chapter 4|Methods."

* -----------------------------------------------------------------------------
* CVD events
* -----------------------------------------------------------------------------

* EDITABLE BLOCK.
* These locals populate "WHAT THIS MEANS" beneath Chapter 1 tables. The first
* five cover All-CVD count, rate, event-type context, sex and age pages. The six
* subtype locals provide distinct Heart and Stroke count/rate/sex commentary.
* Refer to patterns visible on the same page and avoid causal claims.

* CVD COMBINED
local ann_evt_counts_text ///
    "Hospital-recorded CVD events reached 1,021 in 2025: the highest annual count in the 2010 to 2025 series and 27% above the previous-five-year mean of 805.8. After including the estimated contribution from death-certificate-only events, the Primary national estimate was 1,115.8 and the Inclusive estimate was 1,165.4. All three measures point to an unusually high CVD event burden in 2025."

local ann_evt_rates_text ///
    "After allowing for differences in population age, the Primary national CVD event rate rose from 190.9 per 100,000 in 2024 to 228.8 in 2025, close to the series high of 232.6 in 2019. The 2025 hospital-recorded rate was 210.1 and the Inclusive national rate was 238.3. The three estimates give the same broad message of a high-rate year, while their separate confidence intervals and linkage ranges describe the uncertainty around the exact national level."

local ann_evt_type_text ///
    "Stroke made up about two thirds of hospital-recorded CVD events in 2025: 693 Stroke events compared with 328 Heart events. The same ordering is visible in the Primary national age-standardised rates, at 155.1 per 100,000 for Stroke and 73.7 for Heart."

local ann_evt_sex_text ///
    "The 2025 Primary national age-standardised CVD event rate was 288.8 per 100,000 in men and 184.0 in women: about 57% higher in men. The male rate has been higher in every year of the 2010 to 2025 series, and the 2025 confidence intervals are clearly separated. This persistent difference is important for prevention and service planning; understanding its causes requires evidence on risk factors, diagnosis and access to care."

local ann_evt_age_text ///
    "Hospital-recorded events were almost evenly divided by age in 2025: 508 among people under 70 and 511 among people aged 70 or older. Both groups were above their previous-five-year means of 416.2 and 388.2, so both contributed to the high overall count. These counts describe where recorded events occurred; age-specific rates, available online at the BNR Information Hub, are the appropriate measure for comparing population risk."

* HEART and STROKE
local ann_evt_heart_counts_text ///
    "Hospital-recorded Heart events reached 328 in 2025: the highest annual count in the 2010 to 2025 series and 36% above the previous-five-year mean of 240.4. The Primary national estimate was 358.2 and the Inclusive estimate was 365.1. The closeness of the two national estimates strengthens the conclusion that 2025 was an unusually high year for Heart events."

local ann_evt_stroke_counts_text /// 
    "Hospital-recorded Stroke events reached 693 in 2025: the highest annual count in the 2010 to 2025 series and 23% above the previous-five-year mean of 565.4. The Primary national estimate was 757.5 and the Inclusive estimate was 798.2. As Stroke is the larger event group, this increase contributed most of the overall excess in CVD events above the recent mean."

local ann_evt_heart_rates_text ///
    "The 2025 Primary national Heart event rate was 73.7 per 100,000, up from 59.9 in 2024 and the highest point estimate since 2019. The hospital-recorded rate was 67.7 and the Inclusive national rate was 74.9. The 2024 and 2025 confidence intervals overlap slightly, so further years will help show whether this increase is sustained."

local ann_evt_stroke_rates_text ///
    "The 2025 Primary national Stroke event rate was 155.1 per 100,000, up from 131.0 in 2024 and the highest point estimate since 2016. The hospital-recorded rate was 142.5 and the Inclusive national rate was 163.0. The rise is visible across all three measures, supporting the broader finding of a high CVD event rate in 2025."

local ann_evt_heart_sex_text ///
    "The 2025 Primary national Heart event rate was 93.4 per 100,000 in men and 56.7 in women: about 65% higher in men. The male rate has been higher throughout the 2010 to 2025 series, and the 2025 confidence intervals are clearly separated. This persistent pattern is important for prevention and service planning, while its causes require further evidence."

local ann_evt_stroke_sex_text ///
    "The 2025 Primary national Stroke event rate was 195.4 per 100,000 in men and 127.3 in women: about 54% higher in men. Rates rose for both sexes from 2024, with a larger increase among men. The 2025 confidence intervals are clearly separated, making this an important difference to monitor and address."

* Backward-compatible umbrella local retained for the earlier standard file.
local annual_events_interpretation ///
    "`ann_evt_counts_text'"

* -----------------------------------------------------------------------------
* CVD mortality
* -----------------------------------------------------------------------------

* EDITABLE BLOCK.
* These locals populate "WHAT THIS MEANS" beneath Chapter 2 tables. Preserve
* the distinction between Primary and Inclusive definitions, and between their
* definitional difference and statistical confidence intervals.

* ALL CVD
local ann_mort_counts_text ///
    "Primary CVD deaths numbered 368 in 2025, almost unchanged from 365 in 2024 and 7% below the previous-five-year mean of 394.2. The Inclusive count was 588, up from 568 in 2024 and close to its recent mean of 583.6. The difference of 220 deaths between Primary and Inclusive measures represents the Possible CVD class included in the broader definition and shows how strongly the total depends on cause-of-death classification uncertainty."
local ann_mort_rates_text ///
    "The Primary age-standardised CVD mortality rate was broadly stable, moving from 73.9 per 100,000 in 2024 to 76.0 in 2025. The Inclusive rate moved from 115.7 to 123.7, with overlapping confidence intervals across the two years. Each line has its own statistical confidence interval; the distance between the Primary and Inclusive lines shows the sensitivity of the result to including Possible CVD deaths."

local ann_mort_type_text ///
    "Primary Heart and Stroke mortality were very similar in 2025. There were 186 Heart deaths and 182 Stroke deaths, with age-standardised rates of 39.3 and 36.7 per 100,000 respectively. Their 95% confidence intervals overlap, so the report does not interpret the small difference between them as a clear separation."

local ann_mort_sex_text ///
    "Primary CVD death counts were identical for women and men in 2025, at 184 each. After allowing for population age, the mortality rate was 106.8 per 100,000 in men and 59.7 in women: about 79% higher in men, with clearly separated confidence intervals. Age-standardised rates therefore reveal an important difference that the equal counts alone do not show."

local ann_mort_age_text ///
    "Of the 367 Primary CVD deaths with age recorded in 2025, 257 were among people aged 70 or older and 110 were among people under 70: 70% and 30% respectively. Both counts were below their previous-five-year means, so both age groups contributed to the lower overall total. One further Primary CVD death had no age classification and is excluded from these percentages."


* HEART and STROKE 
local ann_mort_heart_counts_text ///
    "Primary Heart deaths numbered 186 in 2025, almost unchanged from 185 in 2024 and 12% below the previous-five-year mean of 212.2. The Inclusive count was 292, up from 272 and almost equal to its recent mean of 293.0. The 106 deaths between the two 2025 estimates are Possible Heart deaths, showing the effect of the broader classification."

local ann_mort_stroke_counts_text ///
    "Primary Stroke deaths numbered 182 in 2025, close to 180 in 2024 and exactly equal to the previous-five-year mean of 182.0. The Inclusive count was unchanged at 296 and was also close to its recent mean of 290.6. The stable recent pattern sits alongside substantial classification sensitivity: Possible Stroke deaths make up 114 of the Inclusive total."

local ann_mort_heart_rates_text ///
    "The Primary Heart mortality rate was broadly stable, moving from 37.8 per 100,000 in 2024 to 39.3 in 2025, and remained below the rates seen in 2021 to 2023. The Inclusive rate rose from 55.7 to 62.6, although its confidence intervals overlap across the two years. The distance between the lines shows the effect of including Possible Heart deaths."

local ann_mort_stroke_rates_text ///
    "Stroke mortality rates were broadly stable between 2024 and 2025. The Primary rate moved from 36.1 to 36.7 per 100,000, while the Inclusive rate moved from 60.0 to 61.1; both pairs of confidence intervals overlap substantially. The continuing distance between the two lines shows the effect of including Possible Stroke deaths."

local ann_mort_heart_sex_text ///
    "Primary Heart death counts were similar for women and men in 2025, at 92 and 94. The age-standardised rate was higher in men, at 50.2 per 100,000 compared with 31.7 in women, as it has been throughout the series. The 2025 confidence intervals overlap slightly, so the size of the difference is estimated with some uncertainty."

local ann_mort_stroke_sex_text ///
    "Primary Stroke death counts were also similar for women and men in 2025, at 92 and 90. After allowing for population age, the mortality rate was 56.7 per 100,000 in men and 28.0 in women: about twice as high in men, with separated confidence intervals. The persistent male-female difference is important for prevention and service planning."

* Backward-compatible umbrella local retained for the earlier standard file.
local annual_mortality_interpretation ///
    "`ann_mort_counts_text'"

* -----------------------------------------------------------------------------
* How complete is the picture?
* -----------------------------------------------------------------------------

* EDITABLE BLOCK.
* These two locals interpret Chapter 3's DCO-reliance and Possible-death
* matrices. Describe reliance/sensitivity, not data-quality grades or causes.

local ann_evt_quality_text ///
    "In 2025, the estimated additional DCO contribution was about 8.5% of the Primary national event estimate for All CVD, Heart and Stroke. The similarity across the three groups is useful context: death-record ascertainment contributes meaningfully to the national estimate, but it is not the dominant component of the 2025 event total."

local ann_mort_quality_text ///
    "Possible-only deaths accounted for 37.4% of the 2025 Inclusive CVD total deaths. The corresponding proportions were also substantial for Heart and Stroke, at about 36% and 39%. These are sensitivity indicators for cause-of-death classification on death certificates. We use these sensitivity results in the absence of national underlying cause of death recording. Read more about our CVD death definitions in chapter 4|Methods."

* -----------------------------------------------------------------------------
* Methods note
* -----------------------------------------------------------------------------

* CONTROLLED EDITABLE TEXT.
* This statement summarises the annual standard section's public-data boundary.
* Edit only when the approved method or report contract has genuinely changed;
* ordinary annual wording changes belong in the findings locals above.

local annual_methods_note ///
    "This report uses information from the approved public CVD-event and mortality data releases, available online at the BNR Information Hub. All published rates, confidence intervals, uncertainty bounds, and rolling comparators used in this report are available in those data releases. Asterisks denote values protected by our published disclosure-control rules."

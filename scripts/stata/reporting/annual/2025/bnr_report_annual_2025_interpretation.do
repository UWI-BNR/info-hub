/*******************************************************************************
DO-FILE: bnr_report_annual_2025_interpretation.do
VERSION: 1.1.1 (3 September 2026)
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
    "There were 1,021 hospital-recorded CVD events in 2025, about 27% above the published previous-five-year mean of 805.8. The Primary national estimate was 1,115.8 events after adding the estimated contribution from events identified through death records."

local annual_summary_message_2 ///
    "Stroke accounted for 67.9% of hospital-recorded CVD events in 2025. The Primary national age-standardised event rate was also higher in men than women: 288.8 compared with 184.0 per 100,000."

local annual_summary_message_3 ///
    "There were 368 Primary CVD deaths in 2025, about 7% below the previous-five-year mean of 394.2. The Inclusive definition counted 588 deaths, close to its recent five-year comparator, showing how strongly mortality totals depend on whether Possible deaths are included."

* -----------------------------------------------------------------------------
* CVD events
* -----------------------------------------------------------------------------

* EDITABLE BLOCK.
* These locals populate "WHAT THIS MEANS" beneath Chapter 1 tables. The first
* five cover All-CVD count, rate, event-type context, sex and age pages. The six
* subtype locals provide distinct Heart and Stroke count/rate/sex commentary.
* Refer to patterns visible on the same page and avoid causal claims.

local ann_evt_counts_text ///
    "Hospital-recorded CVD events were higher in 2025 than in the recent comparison period: 1,021 events compared with a published previous-five-year mean of 805.8. The Primary national estimate was 1,115.8 and the Inclusive estimate 1,165.4, so adding death-record ascertainment increases the estimated national count without changing the broad message that 2025 was a high-count year relative to the recent hospital series."

local ann_evt_rates_text ///
    "The 2025 Primary national age-standardised CVD event rate was 228.8 per 100,000, compared with 210.1 for the hospital-recorded series and 238.3 for the Inclusive national estimate. Statistical confidence intervals and DCO linkage ranges overlap substantially across these definitions, so the report treats the differences as uncertainty around ascertainment rather than as separate disease trends."

local ann_evt_type_text ///
    "Stroke made up about two thirds of hospital-recorded CVD events in 2025: 693 Stroke events compared with 328 Heart events. The same ordering is visible in the Primary national age-standardised rates, at 155.1 per 100,000 for Stroke and 73.7 for Heart."

local ann_evt_sex_text ///
    "Men had a higher Primary national age-standardised CVD event rate than women in 2025: 288.8 compared with 184.0 per 100,000. The difference is also visible in the hospital-recorded series, so it is not explained solely by the addition of death-record-only events."

local ann_evt_age_text ///
    "The 2025 hospital-recorded event count was almost evenly divided by age: 508 events were among people aged under 70 and 511 among people aged 70 or older. This age profile describes the composition of recorded events; it should not be read as an age-specific population risk comparison."

local ann_evt_heart_counts_text "Heart events form the smaller of the two main event groups shown on the preceding CVD pages. The chart and table show how the hospital-recorded series compares with the published national estimates; the definitions should be compared within this page, rather than added to the Stroke rows."
local ann_evt_stroke_counts_text "Stroke remains the larger of the two main event groups shown on the preceding CVD pages. The national estimates add published death-record ascertainment to the hospital series, helping services see the likely scale of events beyond hospital records alone."
local ann_evt_heart_rates_text "This page shows the recent pattern in Heart event rates after allowing for differences in the age structure of the population. Read the solid estimate and its confidence interval together; small year-to-year movements may not represent a meaningful change."
local ann_evt_stroke_rates_text "This page shows the recent pattern in Stroke event rates after allowing for differences in the age structure of the population. The wider CVD page provides the overall context; here the focus is the Stroke contribution to that total."
local ann_evt_heart_sex_text "The comparison helps services ask whether Heart events are affecting women and men differently after age is taken into account. It is a signal for planning and prevention, not evidence on its own of why a difference has occurred."
local ann_evt_stroke_sex_text "The comparison helps services ask whether Stroke events are affecting women and men differently after age is taken into account. It should be read alongside the all-CVD comparison on the earlier page."

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

local ann_mort_counts_text ///
    "Primary CVD deaths numbered 368 in 2025, below the published previous-five-year mean of 394.2. The Inclusive count was 588, close to its comparator of 583.6. The contrast between those two patterns is important: the recent position depends substantially on whether deaths classified as Possible CVD are included."

local ann_mort_rates_text ///
    "The 2025 Primary age-standardised CVD mortality rate was 76.0 per 100,000, while the Inclusive rate was 123.7. Their statistical confidence intervals are shown separately from the definitional difference; the gap between Primary and Inclusive estimates is not a confidence interval."

local ann_mort_type_text ///
    "Primary Heart and Stroke mortality were very similar in 2025. There were 186 Heart deaths and 182 Stroke deaths, with age-standardised rates of 39.3 and 36.7 per 100,000 respectively. Their 95% confidence intervals overlap, so the report does not interpret the small difference between them as a clear separation."

local ann_mort_sex_text ///
    "Primary CVD death counts were identical for women and men in 2025 at 184 each, but the age-standardised mortality rate was higher in men: 106.8 compared with 59.7 per 100,000 in women. The published 95% confidence intervals do not overlap, illustrating why rates add information that raw counts alone cannot provide."

local ann_mort_age_text ///
    "Among Primary CVD deaths with an age classification in 2025, 70.0% were aged 70 or older and 30.0% were under 70. One Primary CVD death is outside that age-distribution denominator, so the age percentages should be read from the published distribution rather than reconstructed from the total count."

local ann_mort_heart_counts_text "Heart deaths are shown using both the Primary and Inclusive definitions. The difference between them reflects how deaths classified as Possible CVD are handled, rather than a second group of people who died."
local ann_mort_stroke_counts_text "Stroke deaths are shown using both the Primary and Inclusive definitions. This gives decision-makers a transparent view of how the reported total changes when Possible CVD deaths are included."
local ann_mort_heart_rates_text "These rates allow the Heart mortality pattern to be compared over time without changes in population age structure driving the result. The Primary and Inclusive lines answer different definition questions; they are not confidence limits around one estimate."
local ann_mort_stroke_rates_text "These rates allow the Stroke mortality pattern to be compared over time without changes in population age structure driving the result. The Primary and Inclusive lines answer different definition questions; they are not confidence limits around one estimate."
local ann_mort_heart_sex_text "The women-and-men comparison uses the Primary definition and age-standardised rates, so it is more informative for service planning than raw counts alone. The chart identifies patterns worth following up, not causes."
local ann_mort_stroke_sex_text "The women-and-men comparison uses the Primary definition and age-standardised rates, so it is more informative for service planning than raw counts alone. The chart identifies patterns worth following up, not causes."

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
    "Possible-only deaths accounted for 37.4% of the 2025 Inclusive All-CVD total. The corresponding proportions were also substantial for Heart and Stroke, at about 36% and 39%. These are sensitivity indicators for cause-of-death classification, not scores of whether the mortality data are good or bad."

* -----------------------------------------------------------------------------
* Methods note
* -----------------------------------------------------------------------------

* CONTROLLED EDITABLE TEXT.
* This statement summarises the annual standard section's public-data boundary.
* Edit only when the approved method or report contract has genuinely changed;
* ordinary annual wording changes belong in the findings locals above.

local annual_methods_note ///
    "The standard section uses only the declared approved public CVD-event and mortality releases. Published rates, confidence intervals, linkage bounds and rolling comparators are read from those releases. Simple percentages used to explain DCO or Possible-death reliance are presentation summaries of published aggregate counts; no confidential data are reopened and no surveillance rate is recalculated. Asterisks denote values protected by the published disclosure-control rules."

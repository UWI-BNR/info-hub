/*******************************************************************************
DO-FILE: bnr_report_annual_2025_interpretation.do
VERSION: 1.0.0 (3 September 2026)
PURPOSE: Analyst-owned interpretation text for the 2025 annual CVD report.

EDITING RULE:
  Edit narrative locals in this file only when updating 2025 interpretation.
  Do not place calculations, release selection or publication logic here.

The current text is deliberately editorial rather than inferential. It is a
safe design-development placeholder until the candidate figures and tables have
been reviewed by the analyst. Replace bracketed prompts before approval.
*******************************************************************************/

local annual_summary_message_1 ///
    "The annual report brings CVD events and CVD mortality together from the two approved public surveillance releases."

local annual_summary_message_2 ///
    "Rates, confidence intervals and DCO linkage bounds shown in this report are read from the approved public datasets; the report does not recalculate them."

local annual_summary_message_3 ///
    "[Analyst: add one concise 2025 finding after reviewing the completed event and mortality figures.]"

local annual_events_interpretation ///
    "[Analyst: summarise the 2025 event pattern. Comment on the direction of the age-standardised trends, any clear Heart/Stroke or sex differences, and whether the DCO-enhanced estimates materially change the interpretation. Do not describe a protected value.]"

local annual_mortality_interpretation ///
    "[Analyst: summarise the 2025 mortality pattern. Comment on the direction of the age-standardised trend, any clear sex or CVD-type differences, and the practical difference between the Primary and Inclusive mortality definitions. Do not describe a protected value.]"

local annual_methods_note ///
    "The standard section uses only the declared approved public CVD-event and mortality releases. Asterisks denote values protected by the published disclosure-control rules. Missing or protected values are never reconstructed from other published cells."

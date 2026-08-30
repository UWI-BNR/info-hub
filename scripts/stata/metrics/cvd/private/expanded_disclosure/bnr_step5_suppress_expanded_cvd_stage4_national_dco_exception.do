/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage4_national_dco_exception.do
VERSION: 1.0.0 (29 August 2026)
PURPOSE: Apply the approved national annual DCO aggregate release exception.

Approved exception lattice:
  * annual, complete/final national estimates only;
  * All CVD, Heart and Stroke;
  * all, female and male;
  * Primary and Inclusive;
  * all-age additional-DCO and Hospital + DCO annual counts;
  * Hospital + DCO crude and age-standardised annual rates.

A small PRIVATE DCO support component (1-5) does not by itself suppress an
approved national aggregate. The exception never clears protection inherited
from a small hospital-recorded count. Individual linkage evidence remains
private.

This helper changes private protection flags only. It does not blank, approve
or publish any value.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 4 national-DCO exception helper v1.0.0"

args primary_private_dta exception_private_dta qa_dta release_id
foreach argument in primary_private_dta exception_private_dta qa_dta release_id {
    if "``argument''" == "" exit 198
}

capture confirm file "`primary_private_dta'"
assert _rc == 0

use "`primary_private_dta'", clear

local required_variables metric_id release_id period_type period_complete ///
    event_type sex age_group ascertainment_scope mortality_definition ///
    statistic value status_flag primary_suppression related_suppression_review ///
    suppression_review stage3_hospital_primary stage3_dco_primary
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"

generate byte national_dco_release_exception = 0

replace national_dco_release_exception = 1 if ///
    period_type == "annual" & period_complete == 1 & status_flag == "final" & ///
    !missing(value) & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & ///
    inlist(sex, "all", "female", "male") & ///
    inlist(mortality_definition, "primary", "inclusive") & ///
    metric_id == "CVD-BURDEN-001" & age_group == "all" & ///
    statistic == "annual_count" & ///
    inlist(ascertainment_scope, "additional_dco", "hospital_plus_dco")

replace national_dco_release_exception = 1 if ///
    period_type == "annual" & period_complete == 1 & status_flag == "final" & ///
    !missing(value) & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & ///
    inlist(sex, "all", "female", "male") & ///
    inlist(mortality_definition, "primary", "inclusive") & ///
    metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_plus_dco" & ///
    ((age_group == "all" & statistic == "annual_crude_rate") | ///
     (age_group == "age_standardised" & ///
      statistic == "annual_age_standardised_rate"))

generate byte stage4_primary_before_exception = primary_suppression
generate byte stage4_dco_primary_relaxed = 0

replace stage4_dco_primary_relaxed = 1 if ///
    national_dco_release_exception == 1 & ///
    primary_suppression == 1 & stage3_dco_primary == 1 & ///
    stage3_hospital_primary == 0

replace primary_suppression = 0 if stage4_dco_primary_relaxed == 1
replace suppression_review = 0 if stage4_dco_primary_relaxed == 1 & ///
    related_suppression_review == 0

* Safety: the national DCO rule must never remove a hospital primary decision.
quietly count if stage4_dco_primary_relaxed == 1 & stage3_hospital_primary == 1
assert r(N) == 0

quietly count if national_dco_release_exception == 1 & ///
    missing(stage3_hospital_primary)
local missing_hospital_flag = r(N)

quietly count if stage4_dco_primary_relaxed == 1
local relaxed_rows = r(N)

quietly count if national_dco_release_exception == 1
local eligible_rows = r(N)

quietly count if national_dco_release_exception == 1 & ///
    stage3_hospital_primary == 1 & primary_suppression != 1
local hospital_failures = r(N)
assert `hospital_failures' == 0

save "`exception_private_dta'", replace

clear
set obs 5
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""

replace check = "Approved national DCO lattice identified" in 1
replace detail = "`eligible_rows' complete/final national annual DCO rows are eligible for the approved aggregate release rule." in 1

replace check = "Small DCO support relaxed only for approved aggregates" in 2
replace detail = "`relaxed_rows' rows had DCO-only primary protection removed." in 2

replace check = "Hospital primary protection retained" in 3
replace result = cond(`hospital_failures' == 0, "PASS", "FAIL") in 3
replace detail = "`hospital_failures' hospital-primary rows were incorrectly relaxed." in 3

replace check = "Hospital support flag present on eligible rows" in 4
replace result = cond(`missing_hospital_flag' == 0, "PASS", "FAIL") in 4
replace detail = "`missing_hospital_flag' eligible rows lack the linked hospital primary-support flag." in 4

replace check = "Exception remains private at this stage" in 5
replace detail = "No numeric field was blanked or published; the exception flag remains private review evidence." in 5

save "`qa_dta'", replace
assert `missing_hospital_flag' == 0

display as result "Expanded CVD Step 5 Stage 4 national-DCO exception helper passed."

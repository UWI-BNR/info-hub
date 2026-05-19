/*
===============================================================================
 DO-FILE:     metric_cvd_burden.do
 PROJECT:     BNR info-hub
 PURPOSE:     Create reusable CVD burden metric output dataset

 AUTHOR:      Ian R Hambleton / BNR Analytics Team
 VERSION:     Draft v0.5
 DATE:        2026-05-18

 METRICS:
   CVD-BURDEN-001
     Hospital-registered CVD event count

   CVD-BURDEN-002
     CVD event distribution

 DESIGN:
   This file is a metrics job, not a briefing job.

   It produces a long-format metric dataset that can be consumed by:
     - Quarto dashboard pages;
     - static tables;
     - future briefings;
     - public ZIP packages, once approved.

   The metric system is the permanent BNR deliverable.
   Briefings are temporary interpretations that consume these metrics.

 INPUT:
   $BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta

 REQUIRED INPUT VARIABLES:
   eid
   dco
   etype
   doe
   yoe
   moe
   sex
   agey

 OUTPUTS:
   $BNR_STAGING/metrics/cvd/burden/
     cvd_burden_metrics_{release_id}.dta
     cvd_burden_metrics_{release_id}.csv
     cvd_burden_metrics_current.dta
     cvd_burden_metrics_current.csv

 NOTES:
   - The release_id should reflect the approved monthly data release,
     for example:
       cvd_2023_12

   - The file uses all valid years available in the input dataset.

   - 2009 is excluded by design.

   - Annual burden outputs are stratified by 10-year age group.
   - The youngest age group is under_45.
   - Monthly burden outputs are not age-stratified, to avoid excessive
     sparse cells.
   - Confidence interval fields are not included because this burden product
     does not currently calculate confidence intervals.

   - Additional comparator rows are created for dashboard use:
       annual_previous_5yr_mean
       monthly_same_month_previous_5yr_mean

     These are calculated in Stata and are therefore part of the approved
     metric product, not dashboard-side calculations.
===============================================================================
*/


* ==============================================================================
* DO NOT TOUCH
* INITIALISE
* ==============================================================================

clear all
set more off


* ==============================================================================
* EDIT BLOCK:
* SET LOCAL PROJECT PATH AND LOAD SHARED SETTINGS
* ==============================================================================
* localpath is the only machine-specific path in this DO file.

local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"


* ==============================================================================
* EDIT BLOCK:
* METRIC JOB SETTINGS
* ==============================================================================

local release_id              "cvd_2023_12"
local log_id                  "2023_12"
local domain                  "cvd"
local metric_family           "burden"
local metric_job              "metric_cvd_burden"

local geography               "Barbados"
local registry                "BNR-CVD"
local source_status           "hospital_registered"

local output_release          "cvd_burden_metrics_`release_id'"
local output_current          "cvd_burden_metrics_current"

local low_count_threshold     5

* Transitional setting.
* Set to 1 while this metrics job still depends on the shared prep file.
* Later, once the approved monthly metric input dataset is agreed, this can
* become 0.
local run_prep                1

* Transitional source dataset created by the existing cases briefing workflow.
local source_dataset          "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta"


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD burden metric build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Release ID:      `release_id'" _n ///
    as result "  Domain:          `domain'" _n ///
    as result "  Metric family:   `metric_family'" _n ///
    as result "  Source dataset:  `source_dataset'" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================================
* DO NOT TOUCH:
* SET OUTPUT FOLDERS
* ==============================================================================

local stagingmetrics "$BNR_STAGING/metrics"
local stagingdomain  "$BNR_STAGING/metrics/`domain'"
local stagingfamily  "$BNR_STAGING/metrics/`domain'/`metric_family'"

cap mkdir "`stagingmetrics'"
cap mkdir "`stagingdomain'"
cap mkdir "`stagingfamily'"


* ==============================================================================
* EDIT BLOCK:
* PREPARE SHARED CVD ANALYSIS DATA
* ==============================================================================
* Transitional step.
* This reuses the existing common prep file used by the current briefing system.
* Later this should be replaced by the approved monthly metric input dataset.

if `run_prep' == 1 {
    quietly do "`localpath'/scripts/stata/common/bnrcvd_prep_2023_v1.do"
}


* ==============================================================================
* DO NOT TOUCH:
* OPEN PRIVATE LOG
* ==============================================================================

cap log close
log using "$BNR_PRIVATE_LOGS/`metric_job'_`log_id'", replace


* ==============================================================================
* DO NOT TOUCH:
* LOAD SOURCE DATASET
* ==============================================================================

capture confirm file "`source_dataset'"
if _rc {
    display as error "Source dataset not found:"
    display as error "  `source_dataset'"
    exit 601
}

use "`source_dataset'", clear


* ==============================================================================
* EDIT BLOCK:
* VALIDATE REQUIRED VARIABLES
* ==============================================================================

local required_vars "eid dco etype doe yoe moe sex agey"

foreach v of local required_vars {
    capture confirm variable `v'
    if _rc {
        display as error "Required variable missing: `v'"
        exit 111
    }
}


* ==============================================================================
* EDIT BLOCK:
* VALIDATE EVENT IDENTIFIER
* ==============================================================================
* The count dataset is documented as one row per event.
* If this fails, the metric output should not be created silently.

capture isid eid
if _rc {
    display as error "eid is not unique. The input dataset is not one row per event."
    duplicates report eid
    exit 459
}


* ==============================================================================
* EDIT BLOCK:
* APPLY STANDARD CVD BURDEN RESTRICTIONS
* ==============================================================================
* CVD-BURDEN-001 is currently defined as hospital-registered events.
* DCO-only records are excluded for this metric unless a future source_status
* dimension explicitly includes them.

drop if dco == 1

* 2009 is excluded by design.
drop if yoe == 2009

drop if missing(yoe)
drop if missing(etype)

gen byte event = 1


* ==============================================================================
* EDIT BLOCK:
* CREATE STANDARD STRING DIMENSIONS
* ==============================================================================
* These dimensions are designed for a simple long-format metric dataset.
* Labels are decoded where possible, with safe fallbacks for unlabeled variables.


* ------------------------------------------------------------------------------
* EDIT BLOCK:
* Event type dimension
* ------------------------------------------------------------------------------

capture decode etype, gen(metric_event_type)

if _rc {
    gen str30 metric_event_type = ""
    replace metric_event_type = "stroke" if etype == 1
    replace metric_event_type = "ami"    if etype == 2
    replace metric_event_type = "etype_" + string(etype) ///
        if metric_event_type == "" & !missing(etype)
}

replace metric_event_type = lower(strtrim(metric_event_type))
replace metric_event_type = subinstr(metric_event_type, " ", "_", .)
replace metric_event_type = subinstr(metric_event_type, "-", "_", .)

replace metric_event_type = "stroke" if inlist(metric_event_type, "1", "str")
replace metric_event_type = "ami" ///
    if inlist(metric_event_type, "2", "acute_mi", "heart_attack", ///
              "acute_myocardial_infarction", "myocardial_infarction")

replace metric_event_type = "unknown" ///
    if metric_event_type == "" | metric_event_type == "."


* ------------------------------------------------------------------------------
* EDIT BLOCK:
* Sex dimension
* ------------------------------------------------------------------------------

capture decode sex, gen(metric_sex)

if _rc {
    gen str20 metric_sex = ""
    replace metric_sex = "female" if sex == 1
    replace metric_sex = "male"   if sex == 2
    replace metric_sex = "sex_" + string(sex) ///
        if metric_sex == "" & !missing(sex)
}

replace metric_sex = lower(strtrim(metric_sex))
replace metric_sex = subinstr(metric_sex, " ", "_", .)
replace metric_sex = subinstr(metric_sex, "-", "_", .)

replace metric_sex = "female" if inlist(metric_sex, "1", "f")
replace metric_sex = "male"   if inlist(metric_sex, "2", "m")

replace metric_sex = "unknown" if metric_sex == "" | metric_sex == "."


* ------------------------------------------------------------------------------
* EDIT BLOCK:
* 10-year age-group dimension
* ------------------------------------------------------------------------------
* Use agey to derive a broad age grouping for routine metric output.
* The youngest group is under_45 to reduce sparse cells.

gen str20 metric_age_group = ""
gen byte  age_group_order  = .

replace metric_age_group = "under_45" if agey < 45 & !missing(agey)
replace age_group_order  = 1          if agey < 45 & !missing(agey)

replace metric_age_group = "45_54"    if inrange(agey, 45, 54)
replace age_group_order  = 2          if inrange(agey, 45, 54)

replace metric_age_group = "55_64"    if inrange(agey, 55, 64)
replace age_group_order  = 3          if inrange(agey, 55, 64)

replace metric_age_group = "65_74"    if inrange(agey, 65, 74)
replace age_group_order  = 4          if inrange(agey, 65, 74)

replace metric_age_group = "75_84"    if inrange(agey, 75, 84)
replace age_group_order  = 5          if inrange(agey, 75, 84)

replace metric_age_group = "85_plus"  if agey >= 85 & !missing(agey)
replace age_group_order  = 6          if agey >= 85 & !missing(agey)

replace metric_age_group = "unknown"  if missing(agey)
replace age_group_order  = 99         if missing(agey)


* ==============================================================================
* DO NOT TOUCH:
* SAVE BASE METRIC ANALYSIS DATASET
* ==============================================================================

tempfile base
save `base', replace


* ==============================================================================
* CREATE EXPANDED DATASET FOR ANNUAL COUNT STRATIFICATIONS
* ==============================================================================
* Annual counts allow stratification by:
*   - event type
*   - sex
*   - 10-year age group
*
* Each event contributes to actual and "all" levels for each dimension:
*   event type: actual event type or all_cvd
*   sex:        actual sex or all
*   age group:  actual age group or all
*
* This gives 2^3 = 8 rows per event.
* The later collapse creates totals for all marginal and fully stratified
* combinations.

use `base', clear

gen long __source_id = _n
expand 8

bysort __source_id: gen byte __copy = _n

gen byte __all_event = mod(__copy - 1, 2)
gen byte __all_sex   = mod(floor((__copy - 1) / 2), 2)
gen byte __all_age   = mod(floor((__copy - 1) / 4), 2)

replace metric_event_type = "all_cvd" if __all_event == 1
replace metric_sex        = "all"     if __all_sex == 1
replace metric_age_group  = "all"     if __all_age == 1
replace age_group_order   = 0         if __all_age == 1

drop __source_id __copy __all_event __all_sex __all_age

tempfile expanded_annual_counts
save `expanded_annual_counts', replace


* ==============================================================================
* CVD-BURDEN-001: ANNUAL EVENT COUNTS
* ==============================================================================

use `expanded_annual_counts', clear

collapse (sum) value = event, ///
    by(yoe metric_event_type metric_sex metric_age_group age_group_order)

rename yoe period_year

gen str20 metric_id     = "CVD-BURDEN-001"
gen str20 release_id    = "`release_id'"
gen str12 period_type   = "annual"
gen int   period_month  = .
gen str10 period_start  = string(period_year, "%04.0f") + "-01-01"
gen str20 period        = string(period_year, "%04.0f")

gen str45 statistic     = "annual_count"
gen str15 unit          = "count"
gen double numerator    = value
gen double denominator  = .
gen int comparison_n    = .

gen str25 status_flag   = "final"
replace status_flag     = "low_count" if numerator < `low_count_threshold'

tempfile annual_counts
save `annual_counts', replace


* ==============================================================================
* CVD-BURDEN-001: ANNUAL PREVIOUS 5-YEAR MEAN
* ==============================================================================
* For each annual count row, calculate the mean of the same stratum over the
* previous five calendar years.
*
* Example:
*   2023 comparator = mean of 2018, 2019, 2020, 2021, 2022
*
* Early years are retained but flagged as insufficient_history if fewer than
* five previous years are available.

use `annual_counts', clear

keep period_year metric_event_type metric_sex metric_age_group ///
    age_group_order value

fillin period_year metric_event_type metric_sex metric_age_group ///
    age_group_order

replace value = 0 if missing(value)
drop _fillin

tempfile annual_for_comparison
save `annual_for_comparison', replace

levelsof period_year, local(annual_years)

tempfile annual_previous_5yr
local annual_first 1

foreach yy of local annual_years {

    use `annual_for_comparison', clear

    keep if inrange(period_year, `yy' - 5, `yy' - 1)

    if _N > 0 {

        collapse ///
            (mean) value = value ///
            (sum)  numerator = value ///
            (count) comparison_n = value, ///
            by(metric_event_type metric_sex metric_age_group age_group_order)

        gen int period_year    = `yy'
        gen int period_month   = .
        gen str10 period_start = string(period_year, "%04.0f") + "-01-01"
        gen str20 period       = string(period_year, "%04.0f")

        gen str20 metric_id    = "CVD-BURDEN-001"
        gen str20 release_id   = "`release_id'"
        gen str12 period_type  = "annual"
        gen str45 statistic    = "annual_previous_5yr_mean"
        gen str15 unit         = "count"
        gen double denominator = .

        gen str25 status_flag  = "final"
        replace status_flag    = "insufficient_history" if comparison_n < 5
        replace value          = . if comparison_n < 5
        replace numerator      = . if comparison_n < 5

        if `annual_first' {
            save `annual_previous_5yr', replace
            local annual_first 0
        }
        else {
            append using `annual_previous_5yr'
            save `annual_previous_5yr', replace
        }
    }
}


* ==============================================================================
* CREATE EXPANDED DATASET FOR MONTHLY COUNT STRATIFICATIONS
* ==============================================================================
* Monthly counts are not age-stratified.
* This avoids excessive sparse cells and keeps the dashboard product useful.
*
* Monthly counts allow stratification by:
*   - event type
*   - sex

use `base', clear

replace metric_age_group = "all"
replace age_group_order  = 0

gen long __source_id = _n

expand 4

bysort __source_id: gen byte __copy = _n

gen byte __all_event = mod(__copy - 1, 2)
gen byte __all_sex   = mod(floor((__copy - 1) / 2), 2)

replace metric_event_type = "all_cvd" if __all_event == 1
replace metric_sex        = "all"     if __all_sex == 1

drop __source_id __copy __all_event __all_sex

tempfile expanded_monthly_counts
save `expanded_monthly_counts', replace


* ==============================================================================
* CVD-BURDEN-001: MONTHLY EVENT COUNTS
* ==============================================================================

use `expanded_monthly_counts', clear

drop if missing(moe)

collapse (sum) value = event, ///
    by(yoe moe metric_event_type metric_sex metric_age_group age_group_order)

rename yoe period_year
rename moe period_month

gen str20 metric_id     = "CVD-BURDEN-001"
gen str20 release_id    = "`release_id'"
gen str12 period_type   = "monthly"
gen str10 period_start  = string(period_year, "%04.0f") + "-" + ///
                          string(period_month, "%02.0f") + "-01"
gen str20 period        = string(period_year, "%04.0f") + "_m" + ///
                          string(period_month, "%02.0f")

gen str45 statistic     = "monthly_count"
gen str15 unit          = "count"
gen double numerator    = value
gen double denominator  = .
gen int comparison_n    = .

gen str25 status_flag   = "final"
replace status_flag     = "low_count" if numerator < `low_count_threshold'

tempfile monthly_counts
save `monthly_counts', replace


* ==============================================================================
* CVD-BURDEN-001: MONTHLY SAME-MONTH PREVIOUS 5-YEAR MEAN
* ==============================================================================
* For each monthly count row, calculate the mean count for the same calendar
* month over the previous five years.
*
* Example:
*   2023_m12 comparator = mean of Dec 2018, Dec 2019, Dec 2020,
*                         Dec 2021, Dec 2022
*
* This supports dashboard cards and comparator lines while preserving seasonal
* structure in monthly counts.

use `monthly_counts', clear

keep period_year period_month metric_event_type metric_sex ///
    metric_age_group age_group_order value

fillin period_year period_month metric_event_type metric_sex ///
    metric_age_group age_group_order

replace value = 0 if missing(value)
drop _fillin

tempfile monthly_for_comparison
save `monthly_for_comparison', replace

levelsof period_year, local(monthly_years)
levelsof period_month, local(months)

tempfile monthly_same_month_previous_5yr
local monthly_first 1

foreach yy of local monthly_years {

    foreach mm of local months {

        use `monthly_for_comparison', clear

        keep if period_month == `mm'
        keep if inrange(period_year, `yy' - 5, `yy' - 1)

        if _N > 0 {

            collapse ///
                (mean) value = value ///
                (sum)  numerator = value ///
                (count) comparison_n = value, ///
                by(metric_event_type metric_sex metric_age_group age_group_order)

            gen int period_year    = `yy'
            gen int period_month   = `mm'
            gen str10 period_start = string(period_year, "%04.0f") + "-" + ///
                                      string(period_month, "%02.0f") + "-01"
            gen str20 period       = string(period_year, "%04.0f") + "_m" + ///
                                      string(period_month, "%02.0f")

            gen str20 metric_id    = "CVD-BURDEN-001"
            gen str20 release_id   = "`release_id'"
            gen str12 period_type  = "monthly"
            gen str45 statistic    = "monthly_same_month_previous_5yr_mean"
            gen str15 unit         = "count"
            gen double denominator = .

            gen str25 status_flag  = "final"
            replace status_flag    = "insufficient_history" if comparison_n < 5
            replace value          = . if comparison_n < 5
            replace numerator      = . if comparison_n < 5

            if `monthly_first' {
                save `monthly_same_month_previous_5yr', replace
                local monthly_first 0
            }
            else {
                append using `monthly_same_month_previous_5yr'
                save `monthly_same_month_previous_5yr', replace
            }
        }
    }
}


* ==============================================================================
* CVD-BURDEN-002: EVENT-TYPE DISTRIBUTION
* ==============================================================================
* Annual distribution of event type within all eligible CVD events.

use `base', clear

collapse (sum) numerator = event, by(yoe metric_event_type)

bysort yoe: egen denominator = total(numerator)

gen double value = (numerator / denominator) * 100

rename yoe period_year

gen str20 metric_id          = "CVD-BURDEN-002"
gen str20 release_id         = "`release_id'"
gen str12 period_type        = "annual"
gen int   period_month       = .
gen str10 period_start       = string(period_year, "%04.0f") + "-01-01"
gen str20 period             = string(period_year, "%04.0f")

gen str20 metric_sex         = "all"
gen str20 metric_age_group   = "all"
gen byte  age_group_order    = 0

gen str45 statistic          = "event_type_distribution"
gen str15 unit               = "percent"
gen int comparison_n         = .

gen str25 status_flag        = "final"
replace status_flag          = "low_count" ///
    if numerator < `low_count_threshold' | denominator < `low_count_threshold'

tempfile dist_event_type
save `dist_event_type', replace


* ==============================================================================
* CVD-BURDEN-002: SEX DISTRIBUTION
* ==============================================================================
* Annual distribution by sex within event type.
* Includes all_cvd as a parent event-type level.

use `base', clear

gen long __source_id = _n

expand 2
bysort __source_id: gen byte __copy = _n

replace metric_event_type = "all_cvd" if __copy == 2

drop __source_id __copy

collapse (sum) numerator = event, by(yoe metric_event_type metric_sex)

bysort yoe metric_event_type: egen denominator = total(numerator)

gen double value = (numerator / denominator) * 100

rename yoe period_year

gen str20 metric_id          = "CVD-BURDEN-002"
gen str20 release_id         = "`release_id'"
gen str12 period_type        = "annual"
gen int   period_month       = .
gen str10 period_start       = string(period_year, "%04.0f") + "-01-01"
gen str20 period             = string(period_year, "%04.0f")

gen str20 metric_age_group   = "all"
gen byte  age_group_order    = 0

gen str45 statistic          = "sex_distribution"
gen str15 unit               = "percent"
gen int comparison_n         = .

gen str25 status_flag        = "final"
replace status_flag          = "low_count" ///
    if numerator < `low_count_threshold' | denominator < `low_count_threshold'

tempfile dist_sex
save `dist_sex', replace


* ==============================================================================
* CVD-BURDEN-002: AGE-GROUP DISTRIBUTION
* ==============================================================================
* Annual distribution by 10-year age group within event type and sex.
* Includes all_cvd and all-sex parent levels.

use `base', clear

gen long __source_id = _n

expand 4
bysort __source_id: gen byte __copy = _n

gen byte __all_event = mod(__copy - 1, 2)
gen byte __all_sex   = mod(floor((__copy - 1) / 2), 2)

replace metric_event_type = "all_cvd" if __all_event == 1
replace metric_sex        = "all"     if __all_sex == 1

drop __source_id __copy __all_event __all_sex

collapse (sum) numerator = event, ///
    by(yoe metric_event_type metric_sex metric_age_group age_group_order)

bysort yoe metric_event_type metric_sex: egen denominator = total(numerator)

gen double value = (numerator / denominator) * 100

rename yoe period_year

gen str20 metric_id     = "CVD-BURDEN-002"
gen str20 release_id    = "`release_id'"
gen str12 period_type   = "annual"
gen int   period_month  = .
gen str10 period_start  = string(period_year, "%04.0f") + "-01-01"
gen str20 period        = string(period_year, "%04.0f")

gen str45 statistic     = "age_group_distribution"
gen str15 unit          = "percent"
gen int comparison_n    = .

gen str25 status_flag   = "final"
replace status_flag     = "low_count" ///
    if numerator < `low_count_threshold' | denominator < `low_count_threshold'

tempfile dist_age_group
save `dist_age_group', replace


* ==============================================================================
* COMBINE METRIC OUTPUTS
* ==============================================================================

use `annual_counts', clear

append using `annual_previous_5yr'
append using `monthly_counts'
append using `monthly_same_month_previous_5yr'
append using `dist_event_type'
append using `dist_sex'
append using `dist_age_group'


* ==============================================================================
* STANDARDISE OUTPUT VARIABLE NAMES
* ==============================================================================

rename metric_event_type event_type
rename metric_sex        sex
rename metric_age_group  age_group

gen str30 source_status = "`source_status'"


* ==============================================================================
* ORDER, SORT, LABEL
* ==============================================================================

order ///
    metric_id release_id period_type period period_start ///
    period_year period_month ///
    event_type sex age_group age_group_order source_status ///
    statistic value unit numerator denominator comparison_n status_flag

sort ///
    metric_id period_type period_year period_month ///
    event_type sex age_group_order age_group statistic

label data "BNR CVD burden metrics"

label var metric_id        "Metric identifier"
label var release_id       "Data release identifier"
label var period_type      "Period type"
label var period           "Reporting period"
label var period_start     "Start date of reporting period"
label var period_year      "Reporting year"
label var period_month     "Reporting month"
label var event_type       "Event type"
label var sex              "Sex"
label var age_group        "Age group"
label var age_group_order  "Age group order"
label var source_status    "Source status"
label var statistic        "Statistic"
label var value            "Metric value"
label var unit             "Metric unit"
label var numerator        "Numerator"
label var denominator      "Denominator"
label var comparison_n     "Number of previous periods contributing to comparator"
label var status_flag      "Status flag"


* ==============================================================================
* DATASET NOTES
* ==============================================================================

notes drop _all

notes _dta: title: BNR CVD burden metrics
notes _dta: release_id: `release_id'
notes _dta: registry: `registry'
notes _dta: geography: `geography'
notes _dta: domain: `domain'
notes _dta: metric_family: `metric_family'
notes _dta: metric_ids: CVD-BURDEN-001; CVD-BURDEN-002
notes _dta: source_dataset: `source_dataset'
notes _dta: source_metadata: bnrcvd_count_2023_v1.yml
notes _dta: unit_of_analysis: Event
notes _dta: content: Long-format aggregate CVD burden metric output
notes _dta: restrictions: Hospital-registered CVD events; DCO-only records excluded; 2009 excluded by design
notes _dta: age_dimension: Derived 10-year age groups from agey: under_45, 45_54, 55_64, 65_74, 75_84, 85_plus
notes _dta: time_dimension: Annual counts by age group; monthly counts not age-stratified
notes _dta: comparator_annual: annual_previous_5yr_mean is the mean of the same stratum in the previous five calendar years
notes _dta: comparator_monthly: monthly_same_month_previous_5yr_mean is the mean of the same calendar month and stratum in the previous five years
notes _dta: confidence_intervals: Not calculated for this burden metric product
notes _dta: caveat: Draft metrics product created from current count input dataset
notes _dta: software: Stata
notes _dta: created: `c(current_date)' `c(current_time)'


* ==============================================================================
* SAVE RELEASE-STAMPED AND CURRENT OUTPUTS
* ==============================================================================

save "`stagingfamily'/`output_release'.dta", replace
export delimited using "`stagingfamily'/`output_release'.csv", replace

save "`stagingfamily'/`output_current'.dta", replace
export delimited using "`stagingfamily'/`output_current'.csv", replace


display as text _n ///
    "------------------------------------------------------------" _n ///
    "CVD burden metric outputs created" _n ///
    "------------------------------------------------------------" _n ///
    as result "  `stagingfamily'/`output_release'.dta" _n ///
    as result "  `stagingfamily'/`output_release'.csv" _n ///
    as result "  `stagingfamily'/`output_current'.dta" _n ///
    as result "  `stagingfamily'/`output_current'.csv" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================================
* PUBLISH METRIC PACKAGE
* ==============================================================================

do "$BNR_STATA/common/bnr_publish_metric.do" ///
    "`domain'" ///
    "`metric_family'" ///
    "`release_id'" ///
    "`output_release'" ///
    "`output_current'"


* ==============================================================================
* CLOSE LOG
* ==============================================================================

log close

/*
===============================================================================
 DO-FILE:     bnr_step4_cvd_burden.do
 VERSION:     2.0.0 (27 July 2026)
 PROJECT:     BNR Refit Phase 2
 PURPOSE:     Calculate CVD-BURDEN-001 and CVD-BURDEN-002

 DESIGN:
   This is the analyst-owned burden calculation. It reads one completed Step 3
   count input and writes one temporary aggregate metric dataset for the Step 4
   controller. It does not select releases, open logs, create staging folders,
   publish files or touch the website.

 USAGE:
   Called by bnr_step4_metrics.do. Do not run routinely by itself.

 ARGUMENTS:
   source_dta source_yml release_id output_dta qa_dta release_year release_month

 METRICS:
   CVD-BURDEN-001  Hospital-registered CVD event count
   CVD-BURDEN-002  CVD event distribution
===============================================================================
*/

version 19
set more off

args source_dataset source_metadata release_id output_dta qa_dta release_year release_month

if `"`source_dataset'"' == "" | `"`source_metadata'"' == "" | ///
        `"`release_id'"' == "" | `"`output_dta'"' == "" | `"`qa_dta'"' == "" | ///
        `"`release_year'"' == "" | `"`release_month'"' == "" {
    display as error "bnr_step4_cvd_burden.do received an incomplete calculation contract."
    exit 198
}

foreach required_file in `"`source_dataset'"' `"`source_metadata'"' {
    capture confirm file `"`required_file'"'
    if _rc {
        display as error "Required Step 3 burden input not found:"
        display as error `"  `required_file'"'
        exit 601
    }
}

local year_num = real("`release_year'")
local month_num = real("`release_month'")
local release_end = dofm(ym(`year_num', `month_num') + 1) - 1
local domain "cvd"
local metric_family "burden"
local geography "Barbados"
local registry "BNR-CVD"
local source_status "hospital_registered"
local primary_suppression_threshold 6

use `"`source_dataset'"', clear


* ==============================================================================
* EDIT BLOCK:
* VALIDATE REQUIRED VARIABLES
* ==============================================================================

local required_vars "eid dco etype doe yoe moe sex"

foreach v of local required_vars {
    capture confirm variable `v'
    if _rc {
        display as error "Required variable missing: `v'"
        exit 111
    }
}

quietly count
if r(N) == 0 {
    display as error "The Step 3 count input contains no events."
    exit 2000
}

quietly count if missing(doe) | yoe != year(doe) | moe != month(doe)
if r(N) {
    display as error "The Step 3 count input has an invalid event-date structure."
    exit 459
}

quietly count if doe > `release_end'
if r(N) {
    display as error "The Step 3 count input contains events after the selected month-end."
    exit 459
}

quietly count if !inlist(etype, 1, 2) | missing(etype)
if r(N) {
    display as error "The Step 3 count input contains an unrecognised event type."
    exit 459
}

quietly count if !inlist(dco, 0, 1) | missing(dco)
if r(N) {
    display as error "The Step 3 count input contains an invalid dco value."
    exit 459
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


* ==============================================================================
* DO NOT TOUCH:
* SAVE BASE METRIC ANALYSIS DATASET
* ==============================================================================

tempfile base
save `base', replace


* ==============================================================================
* CREATE EXPANDED DATASET FOR ANNUAL COUNT STRATIFICATIONS
* ==============================================================================
* Annual counts allow stratification by event type and sex only.
*
* Each event contributes to actual and "all" levels for each dimension:
*   event type: actual event type or all_cvd
*   sex:        actual sex or all
*
* This gives 2^2 = 4 rows per event.
* The later collapse creates totals for all marginal and fully stratified
* combinations.

use `base', clear

gen long __source_id = _n
expand 4

bysort __source_id: gen byte __copy = _n

gen byte __all_event = mod(__copy - 1, 2)
gen byte __all_sex   = mod(floor((__copy - 1) / 2), 2)

replace metric_event_type = "all_cvd" if __all_event == 1
replace metric_sex        = "all"     if __all_sex == 1

drop __source_id __copy __all_event __all_sex

tempfile expanded_annual_counts
save `expanded_annual_counts', replace


* ==============================================================================
* CVD-BURDEN-001: ANNUAL EVENT COUNTS
* ==============================================================================

use `expanded_annual_counts', clear

collapse (sum) value = event, by(yoe metric_event_type metric_sex)

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

keep period_year metric_event_type metric_sex value

fillin period_year metric_event_type metric_sex

replace value = 0 if missing(value)
gen byte __primary_component = ///
    inrange(value, 1, `primary_suppression_threshold' - 1)
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
            (sum)  related_primary_cells = __primary_component ///
            (count) comparison_n = value, ///
            by(metric_event_type metric_sex)

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
* Monthly counts are not age-stratified and are restricted to all CVD.
* This avoids sparse disease-type cells while keeping the dashboard product
* useful. Disease-type stratification is provided at quarterly and annual
* resolution.

use `base', clear

gen long __source_id = _n

expand 2

bysort __source_id: gen byte __copy = _n

replace metric_event_type = "all_cvd"
replace metric_sex        = "all" if __copy == 2

drop __source_id __copy

tempfile expanded_monthly_counts
save `expanded_monthly_counts', replace


* ==============================================================================
* CVD-BURDEN-001: MONTHLY EVENT COUNTS
* ==============================================================================

use `expanded_monthly_counts', clear

drop if missing(moe)

collapse (sum) value = event, by(yoe moe metric_event_type metric_sex)

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

tempfile monthly_counts
save `monthly_counts', replace

* The agreed monthly product is all CVD by sex. If any actual sex stratum has
* a frequency from 1 to 5, stop here so BNR can decide whether monthly output
* should instead be unstratified by sex.
quietly count if metric_sex != "all" & inrange(value, 1, 5)
if r(N) {
    display as error ///
        "Monthly all-CVD sex counts from 1 to 5 were found."
    display as error ///
        "Step 4 has stopped before creating a staging package."
    display as error ///
        "Review whether monthly results should be all-sex only."
    list period_year period_month metric_sex value ///
        if metric_sex != "all" & inrange(value, 1, 5), ///
        noobs clean abbreviate(20)
    exit 459
}


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

keep period_year period_month metric_event_type metric_sex value

fillin period_year period_month metric_event_type metric_sex

replace value = 0 if missing(value)
gen byte __primary_component = ///
    inrange(value, 1, `primary_suppression_threshold' - 1)
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

        if _N > 0 & (`yy' < `year_num' | ///
                (`yy' == `year_num' & `mm' <= `month_num')) {

            collapse ///
                (mean) value = value ///
                (sum)  numerator = value ///
                (sum)  related_primary_cells = __primary_component ///
                (count) comparison_n = value, ///
                by(metric_event_type metric_sex)

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
* CREATE EXPANDED DATASET FOR QUARTERLY COUNT STRATIFICATIONS
* ==============================================================================
* Calendar quarters run Jan-Mar, Apr-Jun, Jul-Sep and Oct-Dec. Quarterly rows
* retain event-type and sex stratification, providing a less sparse resolution
* for AMI and stroke than the all-CVD-only monthly output.

use `base', clear

gen long __source_id = _n
expand 4

bysort __source_id: gen byte __copy = _n

gen byte __all_event = mod(__copy - 1, 2)
gen byte __all_sex   = mod(floor((__copy - 1) / 2), 2)

replace metric_event_type = "all_cvd" if __all_event == 1
replace metric_sex        = "all"     if __all_sex == 1

drop __source_id __copy __all_event __all_sex
drop if missing(moe)

gen byte period_quarter = ceil(moe / 3)

tempfile expanded_quarterly_counts
save `expanded_quarterly_counts', replace


* ==============================================================================
* CVD-BURDEN-001: QUARTERLY EVENT COUNTS
* ==============================================================================

use `expanded_quarterly_counts', clear

collapse (sum) value = event, ///
    by(yoe period_quarter metric_event_type metric_sex)

rename yoe period_year
gen int period_month = 3 * (period_quarter - 1) + 1

gen str20 metric_id     = "CVD-BURDEN-001"
gen str20 release_id    = "`release_id'"
gen str12 period_type   = "quarterly"
gen str10 period_start  = string(period_year, "%04.0f") + "-" + ///
                          string(period_month, "%02.0f") + "-01"
gen str20 period        = string(period_year, "%04.0f") + "_q" + ///
                          string(period_quarter, "%1.0f")

gen str45 statistic     = "quarterly_count"
gen str15 unit          = "count"
gen double numerator    = value
gen double denominator  = .
gen int comparison_n    = .

gen str25 status_flag   = "final"

tempfile quarterly_counts
save `quarterly_counts', replace


* ==============================================================================
* CVD-BURDEN-001: QUARTERLY SAME-QUARTER PREVIOUS 5-YEAR MEAN
* ==============================================================================

use `quarterly_counts', clear

keep period_year period_quarter metric_event_type metric_sex value

fillin period_year period_quarter metric_event_type metric_sex

replace value = 0 if missing(value)
gen byte __primary_component = ///
    inrange(value, 1, `primary_suppression_threshold' - 1)
drop _fillin

tempfile quarterly_for_comparison
save `quarterly_for_comparison', replace

levelsof period_year, local(quarterly_years)
levelsof period_quarter, local(quarters)

tempfile quarterly_5yr_compare
local quarterly_first 1

foreach yy of local quarterly_years {

    foreach qq of local quarters {

        use `quarterly_for_comparison', clear

        keep if period_quarter == `qq'
        keep if inrange(period_year, `yy' - 5, `yy' - 1)

        if _N > 0 & (`yy' < `year_num' | ///
                (`yy' == `year_num' & ///
                 `qq' <= ceil(`month_num' / 3))) {

            collapse ///
                (mean) value = value ///
                (sum)  numerator = value ///
                (sum)  related_primary_cells = __primary_component ///
                (count) comparison_n = value, ///
                by(metric_event_type metric_sex)

            gen int period_year     = `yy'
            gen byte period_quarter = `qq'
            gen int period_month    = 3 * (period_quarter - 1) + 1
            gen str10 period_start  = string(period_year, "%04.0f") + "-" + ///
                                       string(period_month, "%02.0f") + "-01"
            gen str20 period         = string(period_year, "%04.0f") + "_q" + ///
                                       string(period_quarter, "%1.0f")

            gen str20 metric_id     = "CVD-BURDEN-001"
            gen str20 release_id    = "`release_id'"
            gen str12 period_type   = "quarterly"
            gen str45 statistic     = "quarterly_same_quarter_previous_5yr_mean"
            gen str15 unit          = "count"
            gen double denominator  = .

            gen str25 status_flag   = "final"
            replace status_flag     = "insufficient_history" if comparison_n < 5
            replace value           = . if comparison_n < 5
            replace numerator       = . if comparison_n < 5

            if `quarterly_first' {
                save `quarterly_5yr_compare', replace
                local quarterly_first 0
            }
            else {
                append using `quarterly_5yr_compare'
                save `quarterly_5yr_compare', replace
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

gen str45 statistic          = "event_type_distribution"
gen str15 unit               = "percent"
gen int comparison_n         = .

gen str25 status_flag        = "final"

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

gen str45 statistic          = "sex_distribution"
gen str15 unit               = "percent"
gen int comparison_n         = .

gen str25 status_flag        = "final"

tempfile dist_sex
save `dist_sex', replace


* ==============================================================================
* COMBINE METRIC OUTPUTS
* ==============================================================================

use `annual_counts', clear

append using `annual_previous_5yr'
append using `monthly_counts'
append using `monthly_same_month_previous_5yr'
append using `quarterly_counts'
append using `quarterly_5yr_compare'
append using `dist_event_type'
append using `dist_sex'


* ==============================================================================
* STANDARDISE OUTPUT VARIABLE NAMES
* ==============================================================================

rename metric_event_type event_type
rename metric_sex        sex

gen str30 source_status = "`source_status'"

* Complete-period indicator. Monthly rows are always complete because the
* selected extract represents a completed month. The current quarter and year
* remain incomplete until their final month is included in the extract.
gen byte period_complete = .
replace period_complete = 1 if period_type == "monthly"
replace period_complete = (period_year < `year_num' | ///
    (period_year == `year_num' & `month_num' >= period_month + 2)) ///
    if period_type == "quarterly"
replace period_complete = (period_year < `year_num' | ///
    (period_year == `year_num' & `month_num' == 12)) ///
    if period_type == "annual"


* ==============================================================================
* APPLY THE STEP 4 PRIMARY-SUPPRESSION REVIEW POLICY
* ==============================================================================
* Step 4 retains exact values in private staging.  It identifies cells that
* must be suppressed before publication and derived comparator rows that need
* linked review in Step 5.  Complementary (secondary) suppression is applied
* and verified only when Step 5 creates the public-ready copy.

replace related_primary_cells = 0 if missing(related_primary_cells)

gen str20 sdc_policy = "bnr_sdc_v1"
gen byte primary_suppression_threshold = `primary_suppression_threshold'

gen byte primary_suppression = 0
replace primary_suppression = 1 ///
    if inlist(statistic, "annual_count", "monthly_count", "quarterly_count", ///
        "event_type_distribution", "sex_distribution") & ///
       (inrange(numerator, 1, `primary_suppression_threshold' - 1) | ///
        inrange(denominator, 1, `primary_suppression_threshold' - 1))

gen byte related_suppression_review = related_primary_cells > 0
gen byte suppression_review = primary_suppression | related_suppression_review

gen str60 suppression_reason = ""
replace suppression_reason = "numerator_1_to_5" ///
    if primary_suppression & ///
       inrange(numerator, 1, `primary_suppression_threshold' - 1) & ///
       !inrange(denominator, 1, `primary_suppression_threshold' - 1)
replace suppression_reason = "denominator_1_to_5" ///
    if primary_suppression & ///
       !inrange(numerator, 1, `primary_suppression_threshold' - 1) & ///
       inrange(denominator, 1, `primary_suppression_threshold' - 1)
replace suppression_reason = "numerator_and_denominator_1_to_5" ///
    if primary_suppression & ///
       inrange(numerator, 1, `primary_suppression_threshold' - 1) & ///
       inrange(denominator, 1, `primary_suppression_threshold' - 1)
replace suppression_reason = "derived_from_primary_suppression" ///
    if !primary_suppression & related_suppression_review


* ==============================================================================
* ORDER, SORT, LABEL
* ==============================================================================

order ///
    metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex source_status ///
    statistic value unit numerator denominator comparison_n status_flag ///
    sdc_policy primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

sort ///
    metric_id period_type period_year period_month ///
    event_type sex statistic

label data "BNR CVD burden metrics"

label var metric_id        "Metric identifier"
label var release_id       "Data release identifier"
label var period_type      "Period type"
label var period           "Reporting period"
label var period_start     "Start date of reporting period"
label var period_year      "Reporting year"
label var period_month     "Reporting month"
label var period_quarter   "Calendar quarter number"
label var period_complete  "Whether the reporting period is complete"
label var event_type       "Event type"
label var sex              "Sex"
label var source_status    "Source status"
label var statistic        "Statistic"
label var value            "Metric value"
label var unit             "Metric unit"
label var numerator        "Numerator"
label var denominator      "Denominator"
label var comparison_n     "Number of previous periods contributing to comparator"
label var status_flag      "Analytical status flag"
label var sdc_policy       "Statistical disclosure-control policy"
label var primary_suppression_threshold "Minimum publishable cell frequency"
label var primary_suppression "Primary suppression required before publication"
label var related_primary_cells "Primary-suppressed component cells in derived value"
label var related_suppression_review "Derived value requires linked suppression review"
label var suppression_review "Row requires Step 5 suppression review"
label var suppression_reason "Reason for Step 5 suppression review"


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
notes _dta: source_metadata: `source_metadata'
notes _dta: unit_of_analysis: Aggregate metric row
notes _dta: content: Long-format aggregate CVD burden metric output
notes _dta: restrictions: Hospital-registered CVD events; DCO-only records excluded; 2009 excluded by design
notes _dta: age_dimension: No age stratification is produced
notes _dta: time_dimension: Monthly all-CVD counts by sex; quarterly and annual counts by event type and sex
notes _dta: distribution_dimension: Annual event-type and sex distributions only; no age distribution is produced
notes _dta: comparator_annual: annual_previous_5yr_mean is the mean of the same stratum in the previous five calendar years
notes _dta: comparator_monthly: monthly_same_month_previous_5yr_mean is the mean of the same calendar month and stratum in the previous five years
notes _dta: comparator_quarterly: quarterly_same_quarter_previous_5yr_mean is the mean of the same calendar quarter and stratum in the previous five years
notes _dta: completeness: period_complete is 1 for complete periods and 0 for the current incomplete quarter or year; monthly rows are always complete
notes _dta: confidence_intervals: Not calculated for this burden metric product
notes _dta: sdc_standard: Handbook on Statistical Disclosure Control for Outputs
notes _dta: sdc_policy: bnr_sdc_v1; exact frequencies 1 to 5 require primary suppression before publication; zeroes are retained
notes _dta: sdc_boundary: Exact values remain in private staging; Step 5 applies and reviews primary and complementary suppression across the complete public-ready release
notes _dta: monthly_contributors: Upstream safeguards ensure no person contributes more than one event within a month
notes _dta: workflow_status: Staging candidate; requires human review before approval or publication
notes _dta: software: Stata
notes _dta: created: `c(current_date)' `c(current_time)'


* ==============================================================================
* FINAL ACCEPTANCE CHECKS
* ==============================================================================
* Keep this section deliberately short. Earlier calculation blocks already
* make the analytical rules visible. These checks protect the essential final
* contract without repeating every derivation.

local required_output_variables metric_id release_id period_type period ///
    period_start period_year period_month period_quarter period_complete ///
    event_type sex source_status statistic value unit numerator denominator ///
    comparison_n status_flag sdc_policy primary_suppression_threshold ///
    primary_suppression related_primary_cells related_suppression_review ///
    suppression_review suppression_reason

foreach variable of local required_output_variables {
    confirm variable `variable'
}

capture confirm variable eid
if !_rc {
    display as error "Individual event identifiers must not enter metric output."
    exit 459
}

isid metric_id period_type period_year period_month event_type sex statistic, missok
assert inlist(metric_id, "CVD-BURDEN-001", "CVD-BURDEN-002")
assert release_id == "`release_id'"
assert inlist(period_type, "annual", "monthly", "quarterly")
assert inlist(unit, "count", "percent")
assert !missing(period_complete)
assert primary_suppression_threshold == 6
assert sdc_policy == "bnr_sdc_v1"
assert suppression_review == (primary_suppression | related_suppression_review)

quietly count if unit == "percent" & denominator > 0 & ///
    abs(value - (100 * numerator / denominator)) > 1e-8
assert r(N) == 0

quietly count if unit == "count" & ///
    inlist(statistic, "annual_count", "monthly_count", "quarterly_count") & ///
    value != numerator
assert r(N) == 0

quietly count
local metric_rows = r(N)
quietly count if metric_id == "CVD-BURDEN-001"
local metric_001_rows = r(N)
quietly count if metric_id == "CVD-BURDEN-002"
local metric_002_rows = r(N)
quietly count if primary_suppression
local primary_suppression_rows = r(N)
quietly count if related_suppression_review
local related_suppression_rows = r(N)

save `"`output_dta'"', replace

* A small, plain QA dataset is easier to review than a long catalogue of checks
* that duplicate assertions already visible above.
clear
set obs 10
generate str44 check = ""
generate str8 result = "PASS"
generate str120 detail = ""

replace check = "Input files and variables" in 1
replace detail = "Step 3 count dataset, metadata and required variables found" in 1
replace check = "One row per event" in 2
replace detail = "eid unique before aggregation" in 2
replace check = "Release boundary" in 3
replace detail = "No event after the selected completed month" in 3
replace check = "Metric row contract" in 4
replace detail = "Required aggregate variables present and eid absent" in 4
replace check = "Unique metric rows" in 5
replace detail = "One row per metric, period and stratum" in 5
replace check = "Count arithmetic" in 6
replace detail = "Count values equal their numerators" in 6
replace check = "Percentage arithmetic" in 7
replace detail = "Percentages reconcile with numerator and denominator" in 7
replace check = "Period completeness" in 8
replace detail = "Every row has a complete or incomplete period flag" in 8
replace check = "Suppression worklist" in 9
replace detail = "`primary_suppression_rows' primary and `related_suppression_rows' linked review rows" in 9
replace check = "Metric rows created" in 10
replace detail = "`metric_rows' rows: `metric_001_rows' CVD-BURDEN-001 and `metric_002_rows' CVD-BURDEN-002" in 10

label data "BNR CVD burden metric QA checks"
save `"`qa_dta'"', replace

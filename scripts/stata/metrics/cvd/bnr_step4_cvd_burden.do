/*
===============================================================================
 DO-FILE:     bnr_step4_cvd_burden.do
 VERSION:     2.3.0 (24 August 2026)
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
   CVD-BURDEN-001  Hospital-recorded CVD event count
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

local required_vars "eid dco etype doe yoe moe sex age70"

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


* ------------------------------------------------------------------------------
* EDIT BLOCK:
* Validate the under-70 / 70-plus age grouping
* ------------------------------------------------------------------------------
* Step 3 codes age70 as:
*   0 = under 70 years
*   1 = 70 years and older
*
* Missing age70 values are allowed in the Step 3 input. They continue to
* contribute to all existing all-age metrics, but they are excluded from the
* new age-specific annual rows because their age group is unknown.

quietly count if !inlist(age70, 0, 1, .)
if r(N) {
    display as error "The Step 3 count input contains an unrecognised age70 value."
    display as error "Expected values are 0, 1 or missing."
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
* CVD-BURDEN-001 is currently defined as hospital-recorded events.
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
    replace metric_event_type = "heart"  if etype == 2
    replace metric_event_type = "etype_" + string(etype) ///
        if metric_event_type == "" & !missing(etype)
}

replace metric_event_type = lower(strtrim(metric_event_type))
replace metric_event_type = subinstr(metric_event_type, " ", "_", .)
replace metric_event_type = subinstr(metric_event_type, "-", "_", .)

replace metric_event_type = "stroke" if inlist(metric_event_type, "1", "str")
replace metric_event_type = "heart" ///
    if inlist(metric_event_type, "2", "ami", "acute_mi", "heart_attack", ///
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
* CVD-BURDEN-001: ANNUAL ALL-CVD EVENT COUNTS BY AGE GROUP
* ==============================================================================
* This is a deliberately separate calculation block. The existing annual
* event-type and sex expansion above remains unchanged.
*
* The new age rows are restricted to:
*   - all CVD only;
*   - both sexes combined;
*   - annual counts only;
*   - under 70 years and 70 years and older.
*
* age70 is not combined with event type or sex. Missing age70 values are
* excluded from these age-specific rows only; they remain in all-age outputs.

use `base', clear

keep if inlist(age70, 0, 1)

gen str20 age_group = ""
replace age_group = "under_70"    if age70 == 0
replace age_group = "age_70_plus" if age70 == 1

collapse (sum) value = event, by(yoe age_group)

rename yoe period_year

gen str20 metric_id     = "CVD-BURDEN-001"
gen str20 release_id    = "`release_id'"
gen str12 period_type   = "annual"
gen int   period_month  = .
gen str10 period_start  = string(period_year, "%04.0f") + "-01-01"
gen str20 period        = string(period_year, "%04.0f")

gen str30 metric_event_type = "all_cvd"
gen str20 metric_sex        = "all"

gen str45 statistic     = "annual_count"
gen str15 unit          = "count"
gen double numerator    = value
gen double denominator  = .
gen int comparison_n    = .

gen str25 status_flag   = "final"

tempfile annual_age_counts
save `annual_age_counts', replace


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
* CVD-BURDEN-001: ANNUAL PREVIOUS 5-YEAR MEAN BY AGE GROUP
* ==============================================================================
* Apply the same comparator rule used for the existing annual rows:
* the mean of the same age group in the previous five calendar years.
*
* Early years remain in the output but are flagged as insufficient_history
* until five previous years are available.

use `annual_age_counts', clear

keep period_year age_group value

fillin period_year age_group

replace value = 0 if missing(value)
gen byte __primary_component = ///
    inrange(value, 1, `primary_suppression_threshold' - 1)
drop _fillin

tempfile annual_age_for_comparison
save `annual_age_for_comparison', replace

levelsof period_year, local(annual_age_years)

tempfile annual_age_previous_5yr
local annual_age_first 1

foreach yy of local annual_age_years {

    use `annual_age_for_comparison', clear

    keep if inrange(period_year, `yy' - 5, `yy' - 1)

    if _N > 0 {

        collapse ///
            (mean) value = value ///
            (sum)  numerator = value ///
            (sum)  related_primary_cells = __primary_component ///
            (count) comparison_n = value, ///
            by(age_group)

        gen int period_year    = `yy'
        gen int period_month   = .
        gen str10 period_start = string(period_year, "%04.0f") + "-01-01"
        gen str20 period       = string(period_year, "%04.0f")

        gen str20 metric_id    = "CVD-BURDEN-001"
        gen str20 release_id   = "`release_id'"
        gen str12 period_type  = "annual"
        gen str30 metric_event_type = "all_cvd"
        gen str20 metric_sex        = "all"
        gen str45 statistic    = "annual_previous_5yr_mean"
        gen str15 unit         = "count"
        gen double denominator = .

        gen str25 status_flag  = "final"
        replace status_flag    = "insufficient_history" if comparison_n < 5
        replace value          = . if comparison_n < 5
        replace numerator      = . if comparison_n < 5

        if `annual_age_first' {
            save `annual_age_previous_5yr', replace
            local annual_age_first 0
        }
        else {
            append using `annual_age_previous_5yr'
            save `annual_age_previous_5yr', replace
        }
    }
}


* ==============================================================================
* CREATE THE APPROVED MONTHLY PUBLIC LATTICE
* ==============================================================================
* Monthly publication is deliberately limited to one directly calculated row:
*   - all CVD;
*   - both sexes combined; and
*   - all ages.
*
* Keep detailed sex, age and event-type data in the private Step 2 and Step 3
* layers. They do not enter the monthly public metric lattice and therefore
* cannot create a public small-number or reconstruction route.

use `base', clear

replace metric_event_type = "all_cvd"
replace metric_sex        = "all"

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

* ==============================================================================
* CREATE EXPANDED DATASET FOR QUARTERLY COUNT STRATIFICATIONS
* ==============================================================================
* Calendar quarters run Jan-Mar, Apr-Jun, Jul-Sep and Oct-Dec. Quarterly rows
* retain event-type and sex stratification, providing a less sparse resolution
* for Heart and Stroke than the all-CVD-only monthly output.

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
* CVD-BURDEN-002: AGE DISTRIBUTION
* ==============================================================================
* Annual distribution by the under-70 / 70-plus age grouping.
*
* This is deliberately restricted to:
*   - all CVD events;
*   - both sexes combined; and
*   - annual reporting periods.
*
* Records with missing age70 are excluded from both the numerator and the
* denominator. The two age-group percentages therefore describe the
* distribution among events with a known age group and should sum to 100%.

use `base', clear

keep if inlist(age70, 0, 1)

gen str20 age_group = ""
replace age_group = "under_70"    if age70 == 0
replace age_group = "age_70_plus" if age70 == 1

collapse (sum) numerator = event, by(yoe age_group)

bysort yoe: egen denominator = total(numerator)

gen double value = (numerator / denominator) * 100

rename yoe period_year

gen str20 metric_id          = "CVD-BURDEN-002"
gen str20 release_id         = "`release_id'"
gen str12 period_type        = "annual"
gen int   period_month       = .
gen str10 period_start       = string(period_year, "%04.0f") + "-01-01"
gen str20 period             = string(period_year, "%04.0f")

gen str30 metric_event_type = "all_cvd"
gen str20 metric_sex        = "all"

gen str45 statistic          = "age_distribution"
gen str15 unit               = "percent"
gen int comparison_n         = .

gen str25 status_flag        = "final"

tempfile dist_age
save `dist_age', replace


* ==============================================================================
* COMBINE METRIC OUTPUTS
* ==============================================================================

use `annual_counts', clear

append using `annual_previous_5yr'
append using `annual_age_counts'
append using `annual_age_previous_5yr'
append using `monthly_counts'
append using `quarterly_counts'
append using `quarterly_5yr_compare'
append using `dist_event_type'
append using `dist_sex'
append using `dist_age'


* ==============================================================================
* STANDARDISE OUTPUT VARIABLE NAMES
* ==============================================================================

rename metric_event_type event_type
rename metric_sex        sex

* All pre-existing metric rows are explicitly identified as all-age rows.
* Only the two new annual all-CVD age strata carry a specific age group.
capture confirm variable age_group
if _rc gen str20 age_group = "all"
replace age_group = "all" if missing(age_group) | age_group == ""

gen str30 source_status = "`source_status'"

* ------------------------------------------------------------------------------
* HARDENED PUBLIC-SCHEMA FIELDS
* ------------------------------------------------------------------------------
* Stage 2 remains hospital-only. Add the stable v2 fields now, with their only
* valid hospital-only values, so later DCO work adds rows rather than changing
* the meaning of existing public rows.
gen str28 schema_version = "bnr_cvd_public_metric_v2"
gen str24 ascertainment_scope = "hospital_only"
gen str20 mortality_definition = "not_applicable"
gen str12 estimate_basis = "observed"
gen double linkage_lower_value = .
gen double linkage_upper_value = .

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
        "event_type_distribution", "sex_distribution", "age_distribution") & ///
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
    schema_version metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex age_group source_status ascertainment_scope ///
    mortality_definition estimate_basis statistic value linkage_lower_value ///
    linkage_upper_value unit numerator denominator comparison_n status_flag ///
    sdc_policy primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

sort ///
    metric_id period_type period_year period_month ///
    event_type sex age_group statistic

label data "BNR CVD burden metrics"

label var metric_id        "Metric identifier"
label var schema_version   "Public metric schema version"
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
label var age_group        "Age group"
label var source_status    "Source status"
label var ascertainment_scope "Event ascertainment scope"
label var mortality_definition "Mortality definition for DCO estimate"
label var estimate_basis   "Observed or estimated metric basis"
label var statistic        "Statistic"
label var value            "Metric value"
label var linkage_lower_value "Linkage lower bound; DCO rows only"
label var linkage_upper_value "Linkage upper bound; DCO rows only"
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
notes _dta: restrictions: Hospital-recorded CVD events; legacy DCO-only records excluded; 2009 excluded by design
notes _dta: age_dimension: Annual all-CVD counts, annual previous-five-year means and annual age distributions are provided for under_70 and age_70_plus; age is not combined with sex or individual event type
notes _dta: time_dimension: Monthly all-CVD both-sex counts only; quarterly counts by event type and sex; annual counts by event type and sex plus separate all-CVD age-group rows
notes _dta: distribution_dimension: Annual event-type, sex and known-age distributions are produced; age distribution is all-CVD and both-sexes only
notes _dta: comparator_annual: annual_previous_5yr_mean is the mean of the same stratum in the previous five calendar years
notes _dta: comparator_monthly: No rolling monthly comparator is produced; a separately approved fixed 2015-2019 seasonal reference asset is prepared during review
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
    event_type sex age_group source_status schema_version ascertainment_scope ///
    mortality_definition estimate_basis linkage_lower_value linkage_upper_value ///
    statistic value unit numerator denominator ///
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

isid metric_id period_type period_year period_month event_type sex age_group statistic, missok
assert inlist(metric_id, "CVD-BURDEN-001", "CVD-BURDEN-002")
assert release_id == "`release_id'"
assert schema_version == "bnr_cvd_public_metric_v2"
assert ascertainment_scope == "hospital_only"
assert mortality_definition == "not_applicable"
assert estimate_basis == "observed"
assert missing(linkage_lower_value) & missing(linkage_upper_value)
assert inlist(period_type, "annual", "monthly", "quarterly")
assert inlist(unit, "count", "percent")
assert !missing(period_complete)
assert primary_suppression_threshold == 6
assert sdc_policy == "bnr_sdc_v1"
assert suppression_review == (primary_suppression | related_suppression_review)
assert inlist(age_group, "all", "under_70", "age_70_plus")

* Validate the fixed public reference when it already exists.  The first
* hardened release has no authoritative asset yet: Step 5 creates it from this
* approved Step 4 output, after which all later Step 4 runs validate the copy.
local reference_asset_status "first_hardened_release_pending"
local reference_dta "$BNR_PUBLIC/metrics/cvd/burden/cvd_monthly_reference_2015_2019.dta"
local reference_csv "$BNR_PUBLIC/metrics/cvd/burden/cvd_monthly_reference_2015_2019.csv"
local reference_yml "$BNR_PUBLIC/metrics/cvd/burden/metadata/cvd_monthly_reference_2015_2019.yml"
capture confirm file `"`reference_dta'"'
local reference_dta_exists = (_rc == 0)
capture confirm file `"`reference_csv'"'
local reference_csv_exists = (_rc == 0)
capture confirm file `"`reference_yml'"'
local reference_yml_exists = (_rc == 0)
local reference_files = `reference_dta_exists' + `reference_csv_exists' + ///
    `reference_yml_exists'
if `reference_files' > 0 & `reference_files' < 3 {
    display as error "The published CVD monthly reference asset is incomplete."
    exit 459
}
if `reference_files' == 3 {
    preserve
        use `"`reference_dta'"', clear
        isid period_month
        assert _N == 12
        assert schema_version == "bnr_cvd_monthly_reference_v1"
        assert ascertainment_scope == "hospital_only"
        assert event_type == "all_cvd"
        assert sex == "all" & age_group == "all"
        assert reference_start_year == 2015 & reference_end_year == 2019
        assert !missing(reference_min, reference_mean, reference_max)
        assert reference_min <= reference_mean & reference_mean <= reference_max
    restore
    local reference_asset_status "existing_asset_validated"
}

* The monthly public contract is deliberately one all-CVD, both-sex, all-age
* count series. It must never quietly regain sex, age, subtype or rolling rows.
quietly count if period_type == "monthly" & ///
    !(metric_id == "CVD-BURDEN-001" & statistic == "monthly_count" & ///
      event_type == "all_cvd" & sex == "all" & age_group == "all")
assert r(N) == 0

* Protect the agreed boundary for age stratification. Any age-specific row must
* be annual, all-CVD and both-sexes. CVD-BURDEN-001 contributes the observed
* annual count and its previous-five-year mean; CVD-BURDEN-002 contributes the
* annual age distribution only.
quietly count if age_group != "all" & ///
    (period_type != "annual" | event_type != "all_cvd" | sex != "all" | ///
     !((metric_id == "CVD-BURDEN-001" & ///
        inlist(statistic, "annual_count", "annual_previous_5yr_mean")) | ///
       (metric_id == "CVD-BURDEN-002" & statistic == "age_distribution")))
assert r(N) == 0

* Each annual age distribution must use the known-age denominator. Where both
* age groups are present, their percentages should sum to 100% apart from tiny
* floating-point differences.
preserve
    keep if statistic == "age_distribution"
    bysort period_year: egen double __age_percent_total = total(value)
    quietly count if abs(__age_percent_total - 100) > 1e-8
    assert r(N) == 0
restore

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
quietly count if age_group != "all"
local age_specific_rows = r(N)

save `"`output_dta'"', replace

* A small, plain QA dataset is easier to review than a long catalogue of checks
* that duplicate assertions already visible above.
clear
set obs 13
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
replace check = "Age-stratification boundary" in 10
replace detail = "`age_specific_rows' annual all-CVD age-stratified rows; no age-by-sex or age-by-event rows" in 10
replace check = "Metric rows created" in 11
replace detail = "`metric_rows' rows: `metric_001_rows' CVD-BURDEN-001 and `metric_002_rows' CVD-BURDEN-002" in 11
replace check = "Monthly public lattice" in 12
replace detail = "Monthly output is all-CVD, both-sex, all-age monthly_count only; no rolling comparator rows" in 12
replace check = "Fixed monthly reference asset" in 13
replace detail = "`reference_asset_status'" in 13

label data "BNR CVD burden metric QA checks"
save `"`qa_dta'"', replace

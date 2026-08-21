/*
===============================================================================
 DO-FILE:     bnr_mort_s3_calc.do
 VERSION:     Pass 4 monthly-public-scope and fixed-reference candidate
              (21 August 2026)
 PURPOSE:     Calculate private BNR mortality burden dashboard metrics.

 DESIGN:
   This is the analyst-owned mortality burden calculation. It deliberately
   follows the familiar CVD burden-dashboard reporting lattice:

     CASE DEFINITIONS
       - Primary: Clear + Likely
       - Upper bound: Clear + Likely + Possible

     FOR EACH CASE DEFINITION -- ANNUAL
       - BNR-CVD, BNR-Heart and BNR-Stroke by all/female/male
       - BNR-CVD by under 70 / 70 and older
       - event-type, sex and age distributions
       - previous-five-year mean counts

     QUARTERLY
       - BNR-CVD, BNR-Heart and BNR-Stroke by all/female/male
       - same-quarter previous-five-year mean counts

     MONTHLY
       - BNR-CVD only by all/female/male
       - observed counts only in the private calculation lattice

   The reporting lattice is intentionally selective. Age is never crossed
   with sex, individual outcome or subannual period. Monthly Heart and Stroke
   rows are not created because they would create unnecessarily sparse cells.
   Monthly rolling means are deliberately not calculated: the public monthly
   view uses a separately reviewed, fixed 2015-2019 reference profile.

 WORKFLOW BOUNDARY:
   Called only by bnr_mort_s3_burden.do. This file never creates folders,
   approval files, public outputs, website files or mortality rates.
===============================================================================
*/

version 19
set more off

args source_dataset release_id analysis_start_year analysis_end_year output_dta qa_dta

if `"`source_dataset'"' == "" | "`release_id'" == "" | ///
        "`analysis_start_year'" == "" | "`analysis_end_year'" == "" | ///
        `"`output_dta'"' == "" | `"`qa_dta'"' == "" {
    display as error "bnr_mort_s3_calc.do received an incomplete calculation contract."
    exit 198
}

local start_year = real("`analysis_start_year'")
local end_year = real("`analysis_end_year'")
local expected_years = `end_year' - `start_year' + 1
local primary_suppression_threshold = 6

if `start_year' != 2010 {
    display as error "Mortality dashboard reporting must start in 2010."
    exit 198
}

if `end_year' < `start_year' {
    display as error "The mortality analysis end year precedes 2010."
    exit 198
}

use `"`source_dataset'"', clear


* ==============================================================================
* EDIT BLOCK: REQUIRED STEP 2 VARIABLES AND FROZEN DEFINITIONS
* ==============================================================================
* Step 2 remains the full confidential classification archive, including 2008
* and 2009. Step 3 deliberately applies the website reporting start date of
* 1 January 2010.
*
* Frozen reporting definitions:
*   hrt_prim  = Clear + Likely BNR-Heart
*   str_prim  = Clear + Likely BNR-Stroke
*   cvd_prim  = Clear + Likely combined BNR-Heart-or-Stroke
*   cvd_sub_p = resolved Heart/Stroke family within the Primary definition
*   hrt_incl  = Clear + Likely + Possible BNR-Heart
*   str_incl  = Clear + Likely + Possible BNR-Stroke
*   cvd_incl  = Clear + Likely + Possible combined BNR-Heart-or-Stroke
*   cvd_sub_i = resolved Heart/Stroke family within the Upper definition

local required_vars ///
    "dth_date dth_year dth_month dth_qtr sex age qa_dod qa_sex qa_age hrt_prim str_prim cvd_prim cvd_sub_p hrt_incl str_incl cvd_incl cvd_sub_i"

foreach variable of local required_vars {
    capture confirm variable `variable'
    if _rc {
        display as error "Required Step 2 variable missing: `variable'"
        exit 111
    }
}

quietly count
local source_rows = r(N)
if `source_rows' == 0 {
    display as error "The Step 2 classification dataset is empty."
    exit 2000
}


* ==============================================================================
* DO NOT EDIT: STANDARDISE STEP 2 YES/NO FLAGS
* ==============================================================================
* The live DTA stores labelled numeric flags. Text is also accepted so that a
* carefully exported test dataset can exercise the same calculation code.

foreach variable in qa_dod qa_sex qa_age {
    capture confirm string variable `variable'
    if !_rc {
        generate str3 `variable'_text = lower(strtrim(`variable'))
        quietly count if !inlist(`variable'_text, "no", "yes")
        if r(N) {
            display as error "Unrecognised or missing text value in `variable'."
            exit 459
        }
    }
    else {
        quietly count if !inlist(`variable', 0, 1)
        if r(N) {
            display as error "Unrecognised or missing numeric value in `variable'. Expected 0 or 1."
            exit 459
        }
        generate str3 `variable'_text = ""
        replace `variable'_text = "no"  if `variable' == 0
        replace `variable'_text = "yes" if `variable' == 1
    }
}

foreach variable in hrt_prim str_prim cvd_prim hrt_incl str_incl cvd_incl {
    capture confirm string variable `variable'
    if !_rc {
        generate str3 `variable'_text = lower(strtrim(`variable'))
        quietly count if !inlist(`variable'_text, "no", "yes")
        if r(N) {
            display as error "Unrecognised or missing text value in `variable'."
            exit 459
        }
        generate byte `variable'_yes = (`variable'_text == "yes")
    }
    else {
        quietly count if !inlist(`variable', 0, 1)
        if r(N) {
            display as error "Unrecognised or missing numeric value in `variable'. Expected 0 or 1."
            exit 459
        }
        generate byte `variable'_yes = (`variable' == 1)
    }
}


* ==============================================================================
* DO NOT EDIT: STANDARDISE SEX, AGE AND RESOLVED CVD FAMILY
* ==============================================================================
* Internal sex code used below:
*   1 = male
*   2 = female
*  99 = unknown

capture confirm string variable sex
if !_rc {
    generate str20 sex_text = lower(strtrim(sex))
    generate byte sex_code = .
    replace sex_code = 1  if inlist(sex_text, "1", "m", "male", "man", "men")
    replace sex_code = 2  if inlist(sex_text, "2", "f", "female", "woman", "women")
    replace sex_code = 99 if inlist(sex_text, "99", "unknown", "not_known", "not known")
}
else {
    generate byte sex_code = sex
}

quietly count if !inlist(sex_code, 1, 2, 99) & !missing(sex_code)
if r(N) {
    display as error "The Step 2 dataset contains an unrecognised sex value."
    exit 459
}

capture confirm string variable age
if !_rc {
    generate double age_years = real(strtrim(age))
}
else {
    generate double age_years = age
}

* Decode the resolved Primary and Upper CVD families. This is preferable to
* inferring a family after Step 2 has already resolved it. A conservative
* fallback uses the component flags only where exactly one component is positive.
capture decode cvd_sub_p, generate(cvd_sub_text)
if _rc {
    capture confirm string variable cvd_sub_p
    if !_rc {
        generate str80 cvd_sub_text = cvd_sub_p
    }
    else {
        tostring cvd_sub_p, generate(cvd_sub_text) force
    }
}

replace cvd_sub_text = lower(strtrim(cvd_sub_text))
replace cvd_sub_text = subinstr(cvd_sub_text, "-", "_", .)
replace cvd_sub_text = subinstr(cvd_sub_text, " ", "_", .)

generate str20 resolved_event_type_primary = ""
replace resolved_event_type_primary = "heart"  if strpos(cvd_sub_text, "heart") > 0
replace resolved_event_type_primary = "stroke" if strpos(cvd_sub_text, "stroke") > 0

replace resolved_event_type_primary = "heart" ///
    if cvd_prim_yes == 1 & resolved_event_type_primary == "" & ///
       hrt_prim_yes == 1 & str_prim_yes == 0
replace resolved_event_type_primary = "stroke" ///
    if cvd_prim_yes == 1 & resolved_event_type_primary == "" & ///
       hrt_prim_yes == 0 & str_prim_yes == 1

capture decode cvd_sub_i, generate(cvd_sub_upper_text)
if _rc {
    capture confirm string variable cvd_sub_i
    if !_rc {
        generate str80 cvd_sub_upper_text = cvd_sub_i
    }
    else {
        tostring cvd_sub_i, generate(cvd_sub_upper_text) force
    }
}

replace cvd_sub_upper_text = lower(strtrim(cvd_sub_upper_text))
replace cvd_sub_upper_text = subinstr(cvd_sub_upper_text, "-", "_", .)
replace cvd_sub_upper_text = subinstr(cvd_sub_upper_text, " ", "_", .)

generate str20 resolved_event_type_upper = ""
replace resolved_event_type_upper = "heart"  if strpos(cvd_sub_upper_text, "heart") > 0
replace resolved_event_type_upper = "stroke" if strpos(cvd_sub_upper_text, "stroke") > 0

replace resolved_event_type_upper = "heart" ///
    if cvd_incl_yes == 1 & resolved_event_type_upper == "" & ///
       hrt_incl_yes == 1 & str_incl_yes == 0
replace resolved_event_type_upper = "stroke" ///
    if cvd_incl_yes == 1 & resolved_event_type_upper == "" & ///
       hrt_incl_yes == 0 & str_incl_yes == 1


* ==============================================================================
* EDIT BLOCK: VALIDATE DATES AND APPLY THE STANDARD ANALYSIS COHORT
* ==============================================================================

quietly count if qa_dod_text == "no" & ///
    (missing(dth_date) | missing(dth_year) | missing(dth_month) | missing(dth_qtr))
if r(N) {
    display as error "A record marked as having a valid death date has a missing date component."
    exit 459
}

quietly count if qa_dod_text == "no" & ///
    (dth_year != year(dth_date) | dth_month != month(dth_date) | ///
     dth_qtr != ceil(dth_month / 3))
if r(N) {
    display as error "The Step 2 death date, month, quarter and year do not reconcile."
    exit 459
}

quietly count if !missing(dth_year) & dth_year != floor(dth_year)
if r(N) {
    display as error "The Step 2 dataset contains a non-integer death year."
    exit 459
}

* All mortality dashboard rows use valid dates and known male/female sex.
* Invalid or unknown age does not remove a death from all-age metrics; it is
* excluded only from the two annual age-specific rows.
keep if qa_dod_text == "no" & qa_sex_text == "no"
keep if inlist(sex_code, 1, 2)
keep if inrange(dth_year, `start_year', `end_year')

quietly count
local eligible_rows = r(N)
if `eligible_rows' == 0 {
    display as error "No records remain in the standard Step 3 analysis cohort."
    exit 2000
}

quietly summarize dth_year, meanonly
if r(min) != `start_year' | r(max) != `end_year' {
    display as error "The eligible cohort does not cover the configured 2010-onward analysis years."
    exit 459
}

generate byte year_tag = 0
bysort dth_year: replace year_tag = 1 if _n == 1
quietly count if year_tag == 1
local observed_years = r(N)
drop year_tag

if `observed_years' != `expected_years' {
    display as error "The eligible cohort has a gap in its annual death-year series."
    exit 459
}


* ==============================================================================
* EDIT BLOCK: VALIDATE THE COMBINED PRIMARY AND UPPER DEFINITIONS
* ==============================================================================
* IMPORTANT: cvd_prim and cvd_incl are Step 2 combined classifications in
* their own right. Neither is required to equal a simple Boolean union of the
* Heart and Stroke component flags. cvd_sub_p and cvd_sub_i are the matching
* resolved Heart/Stroke reporting families.
*
* The component flags are retained below as QA evidence. Differences between
* their union and cvd_prim are reported, not treated as calculation failures.

generate byte component_primary_union = ///
    (hrt_prim_yes == 1 | str_prim_yes == 1)
generate byte component_upper_union = ///
    (hrt_incl_yes == 1 | str_incl_yes == 1)

quietly count if cvd_prim_yes == 1 & ///
    !inlist(resolved_event_type_primary, "heart", "stroke")
if r(N) {
    display as error "A combined Primary CVD death has no resolved Heart/Stroke family."
    exit 459
}

quietly count if cvd_prim_yes == 0 & ///
    inlist(resolved_event_type_primary, "heart", "stroke")
if r(N) {
    display as error "A resolved Primary CVD family is present where cvd_prim is No."
    exit 459
}

quietly count if cvd_incl_yes == 1 & ///
    !inlist(resolved_event_type_upper, "heart", "stroke")
if r(N) {
    display as error "A combined Upper-bound CVD death has no resolved Heart/Stroke family."
    exit 459
}

quietly count if cvd_incl_yes == 0 & ///
    inlist(resolved_event_type_upper, "heart", "stroke")
if r(N) {
    display as error "A resolved Upper-bound CVD family is present where cvd_incl is No."
    exit 459
}

* The upper definition must contain the primary definition. This is an
* important quantitative guard: a purported upper bound cannot discard a
* Primary death.
quietly count if cvd_prim_yes == 1 & cvd_incl_yes == 0
if r(N) {
    display as error "The Upper-bound definition does not contain every Primary CVD death."
    exit 459
}

quietly count if hrt_prim_yes == 1
local heart_flag_rows = r(N)
quietly count if str_prim_yes == 1
local stroke_flag_rows = r(N)
quietly count if hrt_prim_yes == 1 & str_prim_yes == 1
local overlap_rows = r(N)
quietly count if component_primary_union == 1
local component_union_rows = r(N)
quietly count if cvd_prim_yes == 1
local cvd_rows = r(N)
quietly count if cvd_prim_yes == 1 & component_primary_union == 0
local combined_only_rows = r(N)
quietly count if cvd_prim_yes == 0 & component_primary_union == 1
local component_only_rows = r(N)
quietly count if cvd_prim_yes == 1 & resolved_event_type_primary == "heart"
local resolved_heart_rows = r(N)
quietly count if cvd_prim_yes == 1 & resolved_event_type_primary == "stroke"
local resolved_stroke_rows = r(N)

quietly count if cvd_incl_yes == 1
local upper_cvd_rows = r(N)
quietly count if cvd_incl_yes == 1 & resolved_event_type_upper == "heart"
local upper_resolved_heart_rows = r(N)
quietly count if cvd_incl_yes == 1 & resolved_event_type_upper == "stroke"
local upper_resolved_stroke_rows = r(N)

if `cvd_rows' == 0 | `upper_cvd_rows' == 0 {
    display as error "Both the Primary and Upper-bound CVD definitions must contain deaths."
    exit 2000
}

* Create one transparent, stacked working dataset. All later calculations use
* this explicit case_definition field, so the familiar reporting lattice is
* reproduced independently for Primary and Upper-bound mortality.
generate long source_row = _n
expand 2
bysort source_row: generate byte definition_number = _n
generate str32 case_definition = ""
replace case_definition = "primary_clear_likely" if definition_number == 1
replace case_definition = "upper_clear_likely_possible" if definition_number == 2

generate byte scenario_cvd = .
replace scenario_cvd = cvd_prim_yes if definition_number == 1
replace scenario_cvd = cvd_incl_yes if definition_number == 2

generate str20 scenario_event_type = ""
replace scenario_event_type = resolved_event_type_primary if definition_number == 1
replace scenario_event_type = resolved_event_type_upper if definition_number == 2

keep if scenario_cvd == 1
if _N == 0 {
    display as error "No deaths remain after applying the two mortality reporting definitions."
    exit 2000
}

generate str20 event_type = scenario_event_type
drop source_row definition_number scenario_cvd scenario_event_type
generate str20 metric_sex = cond(sex_code == 1, "male", "female")
generate str20 age_group = ""
replace age_group = "under_70" if qa_age_text == "no" & ///
    inrange(age_years, 0, 69)
replace age_group = "age_70_plus" if qa_age_text == "no" & ///
    inrange(age_years, 70, 120)
generate byte death = 1

tempfile base
save `base', replace


* ==============================================================================
* DO NOT EDIT: CREATE THE COMPLETE ANNUAL COUNT GRID
* ==============================================================================
* Nine all-age rows are created per year:
*   all_cvd, heart, stroke x all, female, male
*
* Two additional age rows are created per year:
*   all_cvd x all x under_70 / age_70_plus
*
* Total annual observed count rows per year = 11.

use `base', clear
generate long source_row = _n
expand 4
bysort source_row: generate byte copy_number = _n
generate byte use_all_event = mod(copy_number - 1, 2)
generate byte use_all_sex = mod(floor((copy_number - 1) / 2), 2)
replace event_type = "all_cvd" if use_all_event == 1
replace metric_sex = "all" if use_all_sex == 1
collapse (sum) value = death, by(dth_year case_definition event_type metric_sex)
rename dth_year period_year
tempfile annual_observed
save `annual_observed', replace

clear
set obs `expected_years'
generate int period_year = `start_year' + _n - 1
expand 2
bysort period_year: generate byte definition_number = _n
generate str32 case_definition = ""
replace case_definition = "primary_clear_likely" if definition_number == 1
replace case_definition = "upper_clear_likely_possible" if definition_number == 2
drop definition_number
expand 3
bysort period_year case_definition: generate byte event_number = _n
generate str20 event_type = ""
replace event_type = "all_cvd" if event_number == 1
replace event_type = "heart"   if event_number == 2
replace event_type = "stroke"  if event_number == 3
drop event_number
expand 3
bysort period_year case_definition event_type: generate byte sex_number = _n
generate str20 metric_sex = ""
replace metric_sex = "all"    if sex_number == 1
replace metric_sex = "female" if sex_number == 2
replace metric_sex = "male"   if sex_number == 3
drop sex_number
merge 1:1 period_year case_definition event_type metric_sex using `annual_observed', nogen
replace value = 0 if missing(value)
generate str20 age_group = "all"
tempfile annual_all_age_counts
save `annual_all_age_counts', replace

use `base', clear
keep if inlist(age_group, "under_70", "age_70_plus")
collapse (sum) value = death, by(dth_year case_definition age_group)
rename dth_year period_year
tempfile annual_age_observed
save `annual_age_observed', replace

clear
set obs `expected_years'
generate int period_year = `start_year' + _n - 1
expand 2
bysort period_year: generate byte definition_number = _n
generate str32 case_definition = ""
replace case_definition = "primary_clear_likely" if definition_number == 1
replace case_definition = "upper_clear_likely_possible" if definition_number == 2
drop definition_number
expand 2
bysort period_year case_definition: generate byte age_number = _n
generate str20 age_group = ""
replace age_group = "under_70"    if age_number == 1
replace age_group = "age_70_plus" if age_number == 2
drop age_number
merge 1:1 period_year case_definition age_group using `annual_age_observed', nogen
replace value = 0 if missing(value)
generate str20 event_type = "all_cvd"
generate str20 metric_sex = "all"
tempfile annual_age_counts
save `annual_age_counts', replace

use `annual_all_age_counts', clear
append using `annual_age_counts'
generate str20 metric_id = "MORT-BURDEN-001"
generate str20 release_id = "`release_id'"
generate str12 period_type = "annual"
generate str20 period = string(period_year, "%04.0f")
generate str10 period_start = period + "-01-01"
generate byte period_month = .
generate byte period_quarter = .
generate str45 statistic = "annual_count"
generate str15 unit = "count"
generate double numerator = value
generate double denominator = .
generate byte comparison_n = .
generate str25 status_flag = "final"
generate int related_primary_cells = 0
tempfile annual_counts
save `annual_counts', replace


* ==============================================================================
* DO NOT EDIT: ANNUAL PREVIOUS-FIVE-YEAR MEAN COUNTS
* ==============================================================================
* A comparator row begins in 2011 because at least one previous year exists.
* Its value remains missing and status is insufficient_history until five
* previous years are available. This matches the CVD dashboard convention.

use `annual_counts', clear
keep period_year case_definition event_type metric_sex age_group value
generate byte primary_component = ///
    inrange(value, 1, `primary_suppression_threshold' - 1)
tempfile annual_for_comparison
save `annual_for_comparison', replace

tempfile annual_previous_5yr
local annual_first = 1
local first_comparator_year = `start_year' + 1

forvalues yy = `first_comparator_year'/`end_year' {
    use `annual_for_comparison', clear
    keep if inrange(period_year, `yy' - 5, `yy' - 1)

    collapse ///
        (mean) value = value ///
        (sum) numerator = value ///
        (sum) related_primary_cells = primary_component ///
        (count) comparison_n = value, ///
        by(case_definition event_type metric_sex age_group)

    generate int period_year = `yy'
    generate str20 metric_id = "MORT-BURDEN-001"
    generate str20 release_id = "`release_id'"
    generate str12 period_type = "annual"
    generate str20 period = string(period_year, "%04.0f")
    generate str10 period_start = period + "-01-01"
    generate byte period_month = .
    generate byte period_quarter = .
    generate str45 statistic = "annual_previous_5yr_mean"
    generate str15 unit = "count"
    generate double denominator = .
    generate str25 status_flag = "final"
    replace status_flag = "insufficient_history" if comparison_n < 5
    replace value = . if comparison_n < 5
    replace numerator = . if comparison_n < 5

    if `annual_first' {
        save `annual_previous_5yr', replace
        local annual_first = 0
    }
    else {
        append using `annual_previous_5yr'
        save `annual_previous_5yr', replace
    }
}


* ==============================================================================
* DO NOT EDIT: CREATE THE COMPLETE MONTHLY COUNT GRID
* ==============================================================================
* Monthly reporting is deliberately all-CVD only, with all/female/male rows.
* Total monthly observed count rows per calendar month = 3.

use `base', clear
replace event_type = "all_cvd"
generate long source_row = _n
expand 2
bysort source_row: generate byte copy_number = _n
replace metric_sex = "all" if copy_number == 2
collapse (sum) value = death, by(dth_year dth_month case_definition event_type metric_sex)
rename dth_year period_year
rename dth_month period_month
tempfile monthly_observed
save `monthly_observed', replace

clear
set obs `expected_years'
generate int period_year = `start_year' + _n - 1
expand 2
bysort period_year: generate byte definition_number = _n
generate str32 case_definition = ""
replace case_definition = "primary_clear_likely" if definition_number == 1
replace case_definition = "upper_clear_likely_possible" if definition_number == 2
drop definition_number
expand 12
bysort period_year case_definition: generate byte period_month = _n
expand 3
bysort period_year case_definition period_month: generate byte sex_number = _n
generate str20 metric_sex = ""
replace metric_sex = "all"    if sex_number == 1
replace metric_sex = "female" if sex_number == 2
replace metric_sex = "male"   if sex_number == 3
drop sex_number
generate str20 event_type = "all_cvd"
merge 1:1 period_year period_month case_definition event_type metric_sex ///
    using `monthly_observed', nogen
replace value = 0 if missing(value)
generate str20 age_group = "all"
generate str20 metric_id = "MORT-BURDEN-001"
generate str20 release_id = "`release_id'"
generate str12 period_type = "monthly"
generate str20 period = string(period_year, "%04.0f") + "_m" + ///
    string(period_month, "%02.0f")
generate str10 period_start = string(period_year, "%04.0f") + "-" + ///
    string(period_month, "%02.0f") + "-01"
generate byte period_quarter = .
generate str45 statistic = "monthly_count"
generate str15 unit = "count"
generate double numerator = value
generate double denominator = .
generate byte comparison_n = .
generate str25 status_flag = "final"
generate int related_primary_cells = 0
tempfile monthly_counts
save `monthly_counts', replace


* ==============================================================================
* DO NOT EDIT: MONTHLY ROLLING MEANS ARE OUT OF SCOPE
* ============================================================================== 
* Do not reintroduce a monthly same-month previous-five-year mean here. A
* visible rolling comparator can disclose a protected monthly component through
* later subtraction. The public monthly display instead uses the fixed,
* separately reviewed 2015-2019 historical reference built in Step 4.


* ==============================================================================
* DO NOT EDIT: CREATE THE COMPLETE QUARTERLY COUNT GRID
* ==============================================================================
* Quarterly reporting retains BNR-CVD, Heart and Stroke by all/female/male.
* Total quarterly observed count rows per calendar quarter = 9.

use `base', clear
generate long source_row = _n
expand 4
bysort source_row: generate byte copy_number = _n
generate byte use_all_event = mod(copy_number - 1, 2)
generate byte use_all_sex = mod(floor((copy_number - 1) / 2), 2)
replace event_type = "all_cvd" if use_all_event == 1
replace metric_sex = "all" if use_all_sex == 1
collapse (sum) value = death, by(dth_year dth_qtr case_definition event_type metric_sex)
rename dth_year period_year
rename dth_qtr period_quarter
tempfile quarterly_observed
save `quarterly_observed', replace

clear
set obs `expected_years'
generate int period_year = `start_year' + _n - 1
expand 2
bysort period_year: generate byte definition_number = _n
generate str32 case_definition = ""
replace case_definition = "primary_clear_likely" if definition_number == 1
replace case_definition = "upper_clear_likely_possible" if definition_number == 2
drop definition_number
expand 4
bysort period_year case_definition: generate byte period_quarter = _n
expand 3
bysort period_year case_definition period_quarter: generate byte event_number = _n
generate str20 event_type = ""
replace event_type = "all_cvd" if event_number == 1
replace event_type = "heart"   if event_number == 2
replace event_type = "stroke"  if event_number == 3
drop event_number
expand 3
bysort period_year case_definition period_quarter event_type: generate byte sex_number = _n
generate str20 metric_sex = ""
replace metric_sex = "all"    if sex_number == 1
replace metric_sex = "female" if sex_number == 2
replace metric_sex = "male"   if sex_number == 3
drop sex_number
merge 1:1 period_year period_quarter case_definition event_type metric_sex ///
    using `quarterly_observed', nogen
replace value = 0 if missing(value)
generate byte period_month = 3 * (period_quarter - 1) + 1
generate str20 age_group = "all"
generate str20 metric_id = "MORT-BURDEN-001"
generate str20 release_id = "`release_id'"
generate str12 period_type = "quarterly"
generate str20 period = string(period_year, "%04.0f") + "_q" + ///
    string(period_quarter, "%1.0f")
generate str10 period_start = string(period_year, "%04.0f") + "-" + ///
    string(period_month, "%02.0f") + "-01"
generate str45 statistic = "quarterly_count"
generate str15 unit = "count"
generate double numerator = value
generate double denominator = .
generate byte comparison_n = .
generate str25 status_flag = "final"
generate int related_primary_cells = 0
tempfile quarterly_counts
save `quarterly_counts', replace


* ==============================================================================
* DO NOT EDIT: QUARTERLY SAME-QUARTER PREVIOUS-FIVE-YEAR MEANS
* ==============================================================================

use `quarterly_counts', clear
keep period_year period_quarter case_definition event_type metric_sex age_group value
generate byte primary_component = ///
    inrange(value, 1, `primary_suppression_threshold' - 1)
tempfile quarterly_for_comparison
save `quarterly_for_comparison', replace

tempfile quarterly_previous_5yr
local quarterly_first = 1

forvalues yy = `first_comparator_year'/`end_year' {
    forvalues qq = 1/4 {
        use `quarterly_for_comparison', clear
        keep if period_quarter == `qq'
        keep if inrange(period_year, `yy' - 5, `yy' - 1)

        collapse ///
            (mean) value = value ///
            (sum) numerator = value ///
            (sum) related_primary_cells = primary_component ///
            (count) comparison_n = value, ///
            by(case_definition event_type metric_sex age_group)

        generate int period_year = `yy'
        generate byte period_quarter = `qq'
        generate byte period_month = 3 * (period_quarter - 1) + 1
        generate str20 metric_id = "MORT-BURDEN-001"
        generate str20 release_id = "`release_id'"
        generate str12 period_type = "quarterly"
        generate str20 period = string(period_year, "%04.0f") + "_q" + ///
            string(period_quarter, "%1.0f")
        generate str10 period_start = string(period_year, "%04.0f") + "-" + ///
            string(period_month, "%02.0f") + "-01"
        generate str45 statistic = "quarterly_same_quarter_previous_5yr_mean"
        generate str15 unit = "count"
        generate double denominator = .
        generate str25 status_flag = "final"
        replace status_flag = "insufficient_history" if comparison_n < 5
        replace value = . if comparison_n < 5
        replace numerator = . if comparison_n < 5

        if `quarterly_first' {
            save `quarterly_previous_5yr', replace
            local quarterly_first = 0
        }
        else {
            append using `quarterly_previous_5yr'
            save `quarterly_previous_5yr', replace
        }
    }
}


* ==============================================================================
* DO NOT EDIT: ANNUAL EVENT-TYPE DISTRIBUTION
* ==============================================================================
* Heart and Stroke percentages use the combined all-CVD count as denominator.

use `annual_counts', clear
keep if age_group == "all" & metric_sex == "all"
keep if inlist(event_type, "all_cvd", "heart", "stroke")
keep period_year case_definition event_type metric_sex age_group value
preserve
    keep if event_type == "all_cvd"
    keep period_year case_definition value
    rename value denominator
    tempfile annual_cvd_denominator
    save `annual_cvd_denominator', replace
restore
keep if inlist(event_type, "heart", "stroke")
rename value numerator
merge m:1 period_year case_definition using `annual_cvd_denominator', nogen keep(match)
generate double value = 100 * numerator / denominator
generate str20 metric_id = "MORT-BURDEN-002"
generate str20 release_id = "`release_id'"
generate str12 period_type = "annual"
generate str20 period = string(period_year, "%04.0f")
generate str10 period_start = period + "-01-01"
generate byte period_month = .
generate byte period_quarter = .
generate str45 statistic = "event_type_distribution"
generate str15 unit = "percent"
generate byte comparison_n = .
generate str25 status_flag = "final"
generate int related_primary_cells = 0
tempfile event_distribution
save `event_distribution', replace


* ==============================================================================
* DO NOT EDIT: ANNUAL SEX DISTRIBUTION
* ==============================================================================

use `annual_counts', clear
keep if age_group == "all" & ///
    inlist(event_type, "all_cvd", "heart", "stroke")
keep period_year case_definition event_type metric_sex age_group value
preserve
    keep if metric_sex == "all"
    keep period_year case_definition event_type value
    rename value denominator
    tempfile annual_sex_denominator
    save `annual_sex_denominator', replace
restore
keep if inlist(metric_sex, "female", "male")
rename value numerator
merge m:1 period_year case_definition event_type using `annual_sex_denominator', nogen keep(match)
generate double value = 100 * numerator / denominator
generate str20 metric_id = "MORT-BURDEN-002"
generate str20 release_id = "`release_id'"
generate str12 period_type = "annual"
generate str20 period = string(period_year, "%04.0f")
generate str10 period_start = period + "-01-01"
generate byte period_month = .
generate byte period_quarter = .
generate str45 statistic = "sex_distribution"
generate str15 unit = "percent"
generate byte comparison_n = .
generate str25 status_flag = "final"
generate int related_primary_cells = 0
tempfile sex_distribution
save `sex_distribution', replace


* ==============================================================================
* DO NOT EDIT: ANNUAL AGE DISTRIBUTION
* ==============================================================================

use `annual_age_counts', clear
bysort period_year case_definition: egen double denominator = total(value)
rename value numerator
generate double value = 100 * numerator / denominator
generate str20 metric_id = "MORT-BURDEN-002"
generate str20 release_id = "`release_id'"
generate str12 period_type = "annual"
generate str20 period = string(period_year, "%04.0f")
generate str10 period_start = period + "-01-01"
generate byte period_month = .
generate byte period_quarter = .
generate str45 statistic = "age_distribution"
generate str15 unit = "percent"
generate byte comparison_n = .
generate str25 status_flag = "final"
generate int related_primary_cells = 0
tempfile age_distribution
save `age_distribution', replace


* ==============================================================================
* DO NOT EDIT: COMBINE AND STANDARDISE THE METRIC OUTPUT
* ==============================================================================

use `annual_counts', clear
append using `annual_previous_5yr'
append using `monthly_counts'
append using `quarterly_counts'
append using `quarterly_previous_5yr'
append using `event_distribution'
append using `sex_distribution'
append using `age_distribution'

rename metric_sex sex
generate byte period_complete = 1
generate str30 source_status = "death_certificate"
generate str20 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = `primary_suppression_threshold'

replace related_primary_cells = 0 if missing(related_primary_cells)

generate byte primary_suppression = 0
replace primary_suppression = 1 ///
    if inlist(statistic, "annual_count", "monthly_count", "quarterly_count", ///
        "event_type_distribution", "sex_distribution", "age_distribution") & ///
       (inrange(numerator, 1, `primary_suppression_threshold' - 1) | ///
        inrange(denominator, 1, `primary_suppression_threshold' - 1))

generate byte related_suppression_review = related_primary_cells > 0
generate byte suppression_review = ///
    primary_suppression | related_suppression_review

generate str60 suppression_reason = ""
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

order ///
    metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex age_group case_definition source_status ///
    statistic value unit numerator denominator comparison_n status_flag ///
    sdc_policy primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

sort metric_id period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic


* ==============================================================================
* DO NOT EDIT: MACHINE-CHECK THE COMPLETED METRIC DATASET
* ==============================================================================

local required_output_variables ///
    metric_id release_id period_type period period_start ///
    period_year period_month period_quarter period_complete ///
    event_type sex age_group case_definition source_status ///
    statistic value unit numerator denominator comparison_n status_flag ///
    sdc_policy primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

foreach variable of local required_output_variables {
    confirm variable `variable'
}

capture isid metric_id period_type period_year period_month period_quarter ///
    case_definition event_type sex age_group statistic, missok
if _rc {
    display as error "Metric rows are not unique at the CVD-compatible reporting grain."
    exit 459
}

quietly count if period_year < 2010
if r(N) {
    display as error "A pre-2010 record entered the mortality dashboard dataset."
    exit 459
}

quietly count if release_id != "`release_id'" | ///
    !inlist(case_definition, "primary_clear_likely", ///
    "upper_clear_likely_possible") | period_complete != 1
if r(N) {
    display as error "A metric row violates the release, definition or complete-period contract."
    exit 459
}

quietly count if !inlist(event_type, "all_cvd", "heart", "stroke") | ///
    !inlist(sex, "all", "female", "male") | ///
    !inlist(age_group, "all", "under_70", "age_70_plus")
if r(N) {
    display as error "A metric row contains an unrecognised reporting dimension."
    exit 459
}

quietly count if age_group != "all" & ///
    (period_type != "annual" | event_type != "all_cvd" | sex != "all")
if r(N) {
    display as error "An age-specific row falls outside the agreed annual all-CVD boundary."
    exit 459
}

quietly count if period_type == "monthly" & ///
    (event_type != "all_cvd" | age_group != "all")
if r(N) {
    display as error "A monthly row falls outside the agreed all-CVD boundary."
    exit 459
}

* Each completed year must reproduce the CVD dashboard row lattice for EACH
* definition: 93 rows in 2010 and 140 rows in later complete years. The
* difference from the earlier lattice is intentional: monthly rolling means
* are deliberately absent and the public monthly comparator is a separate
* fixed historical-reference asset built in Step 4.
forvalues yy = `start_year'/`end_year' {
    quietly count if period_year == `yy' & case_definition == "primary_clear_likely"
    local primary_rows_in_year = r(N)
    quietly count if period_year == `yy' & case_definition == "upper_clear_likely_possible"
    local upper_rows_in_year = r(N)
    local expected_rows_in_year = 140
    if `yy' == `start_year' local expected_rows_in_year = 93
    if `primary_rows_in_year' != `expected_rows_in_year' | ///
            `upper_rows_in_year' != `expected_rows_in_year' {
        display as error "Year `yy' does not contain the expected rows for both case definitions."
        exit 459
    }
}

local expected_count_metric_rows = ///
    (`expected_years' * 11) + ((`expected_years' - 1) * 11) + ///
    (`expected_years' * 12 * 3) + ///
    (`expected_years' * 4 * 9) + ((`expected_years' - 1) * 4 * 9)
local expected_distribution_rows = `expected_years' * 10
local expected_metric_rows = ///
    2 * (`expected_count_metric_rows' + `expected_distribution_rows')
local expected_count_metric_rows = 2 * `expected_count_metric_rows'
local expected_distribution_rows = 2 * `expected_distribution_rows'

quietly count
local metric_rows = r(N)
quietly count if metric_id == "MORT-BURDEN-001"
local count_metric_rows = r(N)
quietly count if metric_id == "MORT-BURDEN-002"
local distribution_metric_rows = r(N)

if `metric_rows' != `expected_metric_rows' | ///
        `count_metric_rows' != `expected_count_metric_rows' | ///
        `distribution_metric_rows' != `expected_distribution_rows' {
    display as error "The metric dataset does not match the expected CVD dashboard row lattice."
    exit 459
}

quietly count if unit == "percent" & ///
    (denominator <= 0 | missing(denominator) | numerator > denominator | ///
     abs(value - (100 * numerator / denominator)) > 0.00000001)
if r(N) {
    display as error "Percentage arithmetic failed."
    exit 459
}

quietly count if unit == "count" & ///
    inlist(statistic, "annual_count", "monthly_count", "quarterly_count") & ///
    (value != numerator | value < 0 | value != floor(value))
if r(N) {
    display as error "Observed count arithmetic failed."
    exit 459
}

* Every matched dashboard count in the Upper-bound series must be at least the
* corresponding Primary count. This is checked at every published frequency,
* event, sex and age stratum rather than only at the overall total.
preserve
    keep if unit == "count" & ///
        inlist(statistic, "annual_count", "monthly_count", "quarterly_count")
    keep metric_id period_type period_year period_month period_quarter ///
        event_type sex age_group statistic case_definition value
    reshape wide value, i(metric_id period_type period_year period_month ///
        period_quarter event_type sex age_group statistic) j(case_definition) string
    quietly count if valueprimary_clear_likely > ///
        valueupper_clear_likely_possible
    if r(N) {
        display as error "A Primary dashboard count exceeds its Upper-bound counterpart."
        exit 459
    }
restore

* Confirm that the all-sex count is exactly the sum of the female and male
* counts. This is checked separately within every event and reporting period.
preserve
    keep if unit == "count" & age_group == "all" & ///
        inlist(statistic, "annual_count", "monthly_count", "quarterly_count")
    generate double sex_component = value if inlist(sex, "female", "male")
    bysort case_definition period_type period_year period_month period_quarter ///
        event_type statistic: egen double sex_component_total = total(sex_component)
    quietly count if sex == "all" & value != sex_component_total
    if r(N) {
        display as error "Female plus male counts do not reproduce an all-sex count."
        exit 459
    }
restore

* Confirm that Heart plus Stroke is exactly the all-CVD count. Monthly data are
* excluded because the agreed dashboard lattice contains monthly all-CVD only.
preserve
    keep if unit == "count" & age_group == "all" & ///
        inlist(statistic, "annual_count", "quarterly_count")
    generate double event_component = value if inlist(event_type, "heart", "stroke")
    bysort case_definition period_type period_year period_month period_quarter ///
        sex statistic: egen double event_component_total = total(event_component)
    quietly count if event_type == "all_cvd" & value != event_component_total
    if r(N) {
        display as error "Heart plus Stroke counts do not reproduce an all-CVD count."
        exit 459
    }
restore

* Reconcile subannual reporting to the annual totals. These checks guard
* against an omitted month or quarter even when the total row count is correct.
preserve
    keep if unit == "count" & age_group == "all" & event_type == "all_cvd" & ///
        inlist(statistic, "annual_count", "monthly_count")
    generate double annual_value = value if statistic == "annual_count"
    generate double monthly_value = value if statistic == "monthly_count"
    bysort case_definition period_year sex: egen double annual_total = max(annual_value)
    bysort case_definition period_year sex: egen double monthly_total = total(monthly_value)
    quietly count if annual_total != monthly_total
    if r(N) {
        display as error "Monthly all-CVD counts do not reproduce an annual total."
        exit 459
    }
restore

preserve
    keep if unit == "count" & age_group == "all" & ///
        inlist(statistic, "annual_count", "quarterly_count")
    generate double annual_value = value if statistic == "annual_count"
    generate double quarterly_value = value if statistic == "quarterly_count"
    bysort case_definition period_year event_type sex: egen double annual_total = max(annual_value)
    bysort case_definition period_year event_type sex: egen double quarterly_total = total(quarterly_value)
    quietly count if annual_total != quarterly_total
    if r(N) {
        display as error "Quarterly counts do not reproduce an annual total."
        exit 459
    }
restore

* Check the rolling-comparator history contract. Years with fewer than five
* predecessors remain explicit but have no value; later years use exactly five.
preserve
    keep if inlist(statistic, "annual_previous_5yr_mean", ///
        "quarterly_same_quarter_previous_5yr_mean")
    generate byte expected_comparison_n = min(5, period_year - `start_year')
    quietly count if comparison_n != expected_comparison_n
    if r(N) {
        display as error "A previous-five-year comparator uses the wrong number of years."
        exit 459
    }
    quietly count if expected_comparison_n < 5 & ///
        (status_flag != "insufficient_history" | !missing(value) | !missing(numerator))
    if r(N) {
        display as error "An incomplete-history comparator is not correctly marked or blanked."
        exit 459
    }
    quietly count if expected_comparison_n == 5 & ///
        (status_flag != "final" | missing(value) | missing(numerator))
    if r(N) {
        display as error "A full-history comparator is not final and populated."
        exit 459
    }
restore

preserve
    keep if statistic == "event_type_distribution"
    bysort case_definition period_year: egen double percent_total = total(value)
    quietly count if abs(percent_total - 100) > 0.00000001
    if r(N) {
        display as error "Annual event-type distributions do not sum to 100 percent."
        exit 459
    }
restore

preserve
    keep if statistic == "sex_distribution"
    bysort case_definition period_year event_type: egen double percent_total = total(value)
    quietly count if abs(percent_total - 100) > 0.00000001
    if r(N) {
        display as error "Annual sex distributions do not sum to 100 percent."
        exit 459
    }
restore

preserve
    keep if statistic == "age_distribution"
    bysort case_definition period_year: egen double percent_total = total(value)
    quietly count if abs(percent_total - 100) > 0.00000001
    if r(N) {
        display as error "Annual age distributions do not sum to 100 percent."
        exit 459
    }
restore

quietly count if primary_suppression == 1
local primary_suppression_rows = r(N)
quietly count if related_suppression_review == 1
local related_suppression_rows = r(N)
quietly count if suppression_review == 1
local suppression_review_rows = r(N)

quietly count if related_primary_cells > 0 & suppression_review != 1
if r(N) {
    display as error "A comparator linked to a small component is absent from the review worklist."
    exit 459
}


* ==============================================================================
* DO NOT EDIT: LABEL, NOTE AND SAVE THE PRIVATE METRIC DATASET
* ==============================================================================

label data "BNR mortality Step 3 private aggregate burden metrics"
label variable metric_id "Permanent metric identifier"
label variable release_id "Step 2 dataset release identifier"
label variable period_type "Reporting-period type"
label variable period "Reporting period"
label variable period_start "Start date of reporting period"
label variable period_year "Calendar year of death"
label variable period_month "Calendar month or quarter-start month"
label variable period_quarter "Calendar quarter"
label variable period_complete "Whether reporting period is complete"
label variable event_type "Mortality event type"
label variable sex "Sex reporting group"
label variable age_group "Age reporting group"
label variable case_definition "BNR mortality case-definition scenario"
label variable source_status "Mortality source status"
label variable statistic "Statistic"
label variable value "Metric value"
label variable unit "Metric unit"
label variable numerator "Metric numerator"
label variable denominator "Metric denominator"
label variable comparison_n "Previous years contributing to comparator"
label variable status_flag "Analytical status flag"
label variable sdc_policy "Statistical disclosure-control policy"
label variable primary_suppression_threshold "Minimum publishable cell frequency"
label variable primary_suppression "Primary suppression required before publication"
label variable related_primary_cells "Small component cells in derived value"
label variable related_suppression_review "Derived row requires linked review"
label variable suppression_review "Row requires Step 4 disclosure-control review"
label variable suppression_reason "Reason for disclosure-control review"

notes drop _all
notes _dta: title: BNR mortality burden dashboard metrics
notes _dta: release_id: `release_id'
notes _dta: analysis_start: 2010-01-01
notes _dta: analysis_end_year: `analysis_end_year'
notes _dta: case_definitions: primary_clear_likely and upper_clear_likely_possible; no lower-bound series is released
notes _dta: combined_definition: all_cvd uses Step 2 cvd_prim for Primary and cvd_incl for Upper; each combined death is counted once per definition
notes _dta: family_resolution: Heart and Stroke use Step 2 cvd_sub_p for Primary and cvd_sub_i for Upper
notes _dta: component_flags: Heart and Stroke component flags are QA evidence and are not assumed to reproduce either combined definition by simple union
notes _dta: reporting_lattice: Mirrors the CVD burden dashboard selective annual, quarterly and monthly structure
notes _dta: age_dimension: Annual all-CVD only; under_70 and age_70_plus; known age only
notes _dta: monthly_dimension: Monthly all-CVD by all, female and male only
notes _dta: quarterly_dimension: Quarterly all-CVD, Heart and Stroke by all, female and male
notes _dta: comparators: Annual and quarterly previous-five-year same-period means only; insufficient history retained with missing value
notes _dta: sdc_policy: Exact frequencies 1 to 5 require primary suppression before publication
notes _dta: workflow_status: Private staging candidate; not approved or public

save `"`output_dta'"', replace


* ==============================================================================
* DO NOT EDIT: EVIDENCE-BEARING QA RECEIPT
* ==============================================================================

tempname qa_handle
postfile `qa_handle' str44 check str8 result str244 detail ///
    using `"`qa_dta'"', replace

post `qa_handle' ("required_step2_variables") ("PASS") ///
    ("All required Step 2 date, classification, sex and age variables were found.")
post `qa_handle' ("source_and_cohort_rows") ("PASS") ///
    ("Source rows: `source_rows'; eligible known-sex rows from 2010: `eligible_rows'.")
post `qa_handle' ("website_analysis_period") ("PASS") ///
    ("Dashboard analysis begins at 2010-01-01 and ends in `analysis_end_year'; Step 2 remains unchanged.")
post `qa_handle' ("date_reconciliation") ("PASS") ///
    ("Death date, year, month and quarter reconcile for the analytical cohort.")
post `qa_handle' ("combined_primary_definition") ("PASS") ///
    ("Primary cvd_prim rows: `cvd_rows'; Upper cvd_incl rows: `upper_cvd_rows'; Primary rows are contained within Upper.")
post `qa_handle' ("component_definition_comparison") ("PASS") ///
    ("Component union: `component_union_rows'; combined-only: `combined_only_rows'; component-only: `component_only_rows'; overlapping component flags: `overlap_rows'.")
post `qa_handle' ("resolved_family") ("PASS") ///
    ("Every Primary and Upper death has one matching resolved Heart or Stroke reporting family; no resolved family occurs outside its combined definition.")
post `qa_handle' ("cvd_dashboard_lattice") ("PASS") ///
    ("Each definition has 93 rows in 2010 and 140 rows in every later complete year; monthly rolling means are intentionally excluded.")
post `qa_handle' ("metric_grain_and_rows") ("PASS") ///
    ("Unique reporting grain; total rows: `metric_rows'; count/comparator rows: `count_metric_rows'; distribution rows: `distribution_metric_rows'.")
post `qa_handle' ("metric_reconciliation") ("PASS") ///
    ("Counts and annual distributions reconcile; every Primary dashboard count is no larger than its Upper-bound counterpart.")
post `qa_handle' ("sex_and_event_reconciliation") ("PASS") ///
    ("Female plus male reproduces all-sex; Heart plus Stroke reproduces all-CVD wherever components are reported.")
post `qa_handle' ("cross_frequency_reconciliation") ("PASS") ///
    ("Monthly and quarterly observed counts reproduce their corresponding annual totals.")
post `qa_handle' ("comparator_history") ("PASS") ///
    ("Previous-five-year means use the expected history and correctly mark incomplete history.")
post `qa_handle' ("suppression_worklist") ("PASS") ///
    ("Primary rows: `primary_suppression_rows'; linked derived rows: `related_suppression_rows'; total review rows: `suppression_review_rows'.")
post `qa_handle' ("rates_out_of_scope") ("PASS") ///
    ("No population denominator or mortality rate was calculated in Step 3.")

postclose `qa_handle'

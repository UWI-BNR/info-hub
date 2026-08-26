/*******************************************************************************
DO-FILE:     bnr_cvd_construct_incidence_rates_core_debug_v1_0_6.do
VERSION:     1.0.6 (26 August 2026)
RELEASE:     Stage 3 rate-construction integrated release 1.0.6
PURPOSE:     Diagnostic copy of the private annual CVD rate-construction core.

             Uses the completed aggregate joint All-CVD DCO anchor, then
             allocates its unresolved component over mutually exclusive
             subtype x sex x five-year-age cells. The public-facing rate rows
             are annual only; the age-specific components remain private.

INPUTS:      hospital-event DTA       : eid, doe, etype, dco, sex, agey
             final linkage DTA        : Stage 4C candidate diagnostic
             joint-anchor DTA         : Stage 4E-c joint subtype output
             WPP population DTA       : prepared private reference asset
             WHO standard DTA         : prepared private reference asset

OUTPUTS:     private public-shaped rate candidate DTA, private component DTA,
             aggregate QA CSV. No public output is created.
*******************************************************************************/
version 19
clear all
set more off

args events_input linkage_input joint_input population_input standard_input ///
    rates_output components_output qa_output cvd_release_year cvd_release_month
if `"`events_input'"' == "" | `"`linkage_input'"' == "" | ///
        `"`joint_input'"' == "" | `"`population_input'"' == "" | ///
        `"`standard_input'"' == "" | `"`rates_output'"' == "" | ///
        `"`components_output'"' == "" | `"`qa_output'"' == "" | ///
        `"`cvd_release_year'"' == "" | `"`cvd_release_month'"' == "" {
    display as error "Rate-construction core received an incomplete file contract."
    exit 198
}

local cvd_year_num = real("`cvd_release_year'")
local cvd_month_num = real("`cvd_release_month'")
if missing(`cvd_year_num', `cvd_month_num') | ///
        !inrange(`cvd_month_num', 1, 12) {
    display as error "CVD release year/month must be numeric and the month must be 1--12."
    exit 198
}
local last_complete_year = `cvd_year_num'
if `cvd_month_num' < 12 local last_complete_year = `cvd_year_num' - 1
if `last_complete_year' < 2010 {
    display as error "No complete annual CVD period is available from 2010 onwards."
    exit 459
}
local cvd_year_text : display %04.0f `cvd_year_num'
local cvd_month_text : display %02.0f `cvd_month_num'
local release_id "cvd_`cvd_year_text'_`cvd_month_text'"

foreach f in events_input linkage_input joint_input population_input standard_input {
    capture confirm file ``f''
    if _rc {
        display as error "Required private rate input was not found: ``f''"
        exit 601
    }
}

tempfile population standard hospital linkage_rows ///
    anchor atomic_grid grid source_a components_atomic components rates_crude ///
    rates_asr qa_dta all_age_population rates_candidate
tempname qa_handle category_handle

* ---------------------------------------------------------------------------
* 1. Validate private reference assets.
* ---------------------------------------------------------------------------
use `"`population_input'"', clear
foreach v in year sex age_group population {
    capture confirm variable `v'
    if _rc exit 111
}
capture confirm numeric variable year
if _rc exit 109
capture confirm numeric variable population
if _rc exit 109
capture confirm string variable sex
if _rc exit 109
capture confirm string variable age_group
if _rc exit 109
replace sex = lower(strtrim(sex))
replace age_group = lower(strtrim(age_group))
assert inlist(sex, "all", "female", "male")
assert inrange(year, 2010, 2035)
assert population > 0 & !missing(population)
isid year sex age_group
bysort year sex: assert _N == 21
quietly summarize year, meanonly
assert r(min) == 2010
assert r(max) >= `last_complete_year'
preserve
    keep year sex age_group population
    reshape wide population, i(year age_group) j(sex) string
    assert !missing(populationall, populationfemale, populationmale)
    assert abs(populationall - populationfemale - populationmale) < 0.000001
restore
save `"`population'"', replace

use `"`standard_input'"', clear
foreach v in age_group standard_weight {
    capture confirm variable `v'
    if _rc exit 111
}
capture confirm string variable age_group
if _rc exit 109
capture confirm numeric variable standard_weight
if _rc exit 109
replace age_group = lower(strtrim(age_group))
isid age_group
assert _N == 21
assert standard_weight > 0 & !missing(standard_weight)
quietly summarize standard_weight, meanonly
assert abs(r(sum) - 1) < 0.000000001
keep age_group standard_weight
save `"`standard'"', replace

* Retain the complete Stage 4E-c source-year range for reproducing its selected
* annual/three-year/all-years composition pools. Target annual rates are still
* restricted to complete CVD calendar years below.
use `"`joint_input'"', clear
capture confirm numeric variable dth_year
if _rc exit 109
quietly summarize dth_year if dth_year >= 2010, meanonly
if r(N) == 0 {
    display as error "Joint DCO input contains no analytical years from 2010."
    exit 2000
}
local joint_source_min_year = r(min)
local joint_source_max_year = r(max)
assert `joint_source_min_year' == 2010
assert `joint_source_max_year' >= `last_complete_year'

* ---------------------------------------------------------------------------
* 2. Hospital-event numerator, expanded to all CVD and all sex.
*    Legacy imported DCO rows remain outside the new rate numerator.
* ---------------------------------------------------------------------------
use `"`events_input'"', clear
foreach v in eid doe etype dco sex agey {
    capture confirm variable `v'
    if _rc exit 111
}
foreach v in doe etype dco sex agey {
    capture confirm numeric variable `v'
    if _rc {
        display as error "Hospital-event input variable must be numeric: `v'"
        exit 109
    }
}
isid eid
assert inlist(dco, 0, 1)
keep if dco == 0 & inrange(year(doe), 2010, `last_complete_year')
assert inlist(etype, 1, 2)
generate int dth_year = year(doe)
generate str12 event_type = "stroke" if etype == 1
replace event_type = "heart" if etype == 2
generate str10 sex_atomic = "unknown"
replace sex_atomic = "female" if sex == 1
replace sex_atomic = "male" if sex == 2
drop sex
generate str16 age_group = "age_unknown"
replace age_group = "age_0_4" if inrange(agey, 0, 4)
replace age_group = "age_5_9" if inrange(agey, 5, 9)
replace age_group = "age_10_14" if inrange(agey, 10, 14)
replace age_group = "age_15_19" if inrange(agey, 15, 19)
replace age_group = "age_20_24" if inrange(agey, 20, 24)
replace age_group = "age_25_29" if inrange(agey, 25, 29)
replace age_group = "age_30_34" if inrange(agey, 30, 34)
replace age_group = "age_35_39" if inrange(agey, 35, 39)
replace age_group = "age_40_44" if inrange(agey, 40, 44)
replace age_group = "age_45_49" if inrange(agey, 45, 49)
replace age_group = "age_50_54" if inrange(agey, 50, 54)
replace age_group = "age_55_59" if inrange(agey, 55, 59)
replace age_group = "age_60_64" if inrange(agey, 60, 64)
replace age_group = "age_65_69" if inrange(agey, 65, 69)
replace age_group = "age_70_74" if inrange(agey, 70, 74)
replace age_group = "age_75_79" if inrange(agey, 75, 79)
replace age_group = "age_80_84" if inrange(agey, 80, 84)
replace age_group = "age_85_89" if inrange(agey, 85, 89)
replace age_group = "age_90_94" if inrange(agey, 90, 94)
replace age_group = "age_95_99" if inrange(agey, 95, 99)
replace age_group = "age_100_plus" if agey >= 100 & !missing(agey)
generate long hospital_n = 1

generate long __event_row = _n
expand 4
bysort __event_row: generate byte __copy = _n
replace event_type = "all_cvd" if inlist(__copy, 2, 4)
generate str10 sex = sex_atomic
replace sex = "all" if inlist(__copy, 3, 4)
drop __event_row __copy etype dco sex_atomic agey doe eid
collapse (sum) hospital_n, by(dth_year event_type sex age_group)
isid dth_year event_type sex age_group
save `"`hospital'"', replace

* ---------------------------------------------------------------------------
* 3. Recreate the mutually exclusive linkage categories at record level.
*    DCO age is the death-certificate age, only where the unit is Years.
* ---------------------------------------------------------------------------
use `"`linkage_input'"', clear
foreach v in record_id dth_year mortality_age mortality_agetxt ///
        mortality_sex_canonical cvd_prim cvd_incl hrt_prim hrt_incl ///
        str_prim str_incl final_person_match final_episode_outcome {
    capture confirm variable `v'
    if _rc {
        display as error "Final linkage diagnostic is missing variable: `v'"
        exit 111
    }
}
capture confirm string variable mortality_age
if _rc exit 109
capture confirm string variable mortality_agetxt
if _rc exit 109
capture confirm string variable final_episode_outcome
if _rc exit 109
foreach v in dth_year mortality_sex_canonical cvd_prim cvd_incl hrt_prim ///
        hrt_incl str_prim str_incl final_person_match {
    capture confirm numeric variable `v'
    if _rc exit 109
}
isid record_id
keep if inrange(dth_year, 2010, `joint_source_max_year')
foreach v in cvd_prim cvd_incl hrt_prim hrt_incl str_prim str_incl ///
        final_person_match {
    assert inlist(`v', 0, 1)
}
assert cvd_prim <= cvd_incl
assert inlist(mortality_sex_canonical, 1, 2) | missing(mortality_sex_canonical)
assert final_person_match == 1 if final_episode_outcome == "provisional_additional_dco"
generate double __death_age = real(strtrim(mortality_age))
generate str16 age_group = "age_unknown"
replace age_group = "age_0_4" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 0, 4)
replace age_group = "age_5_9" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 5, 9)
replace age_group = "age_10_14" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 10, 14)
replace age_group = "age_15_19" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 15, 19)
replace age_group = "age_20_24" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 20, 24)
replace age_group = "age_25_29" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 25, 29)
replace age_group = "age_30_34" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 30, 34)
replace age_group = "age_35_39" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 35, 39)
replace age_group = "age_40_44" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 40, 44)
replace age_group = "age_45_49" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 45, 49)
replace age_group = "age_50_54" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 50, 54)
replace age_group = "age_55_59" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 55, 59)
replace age_group = "age_60_64" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 60, 64)
replace age_group = "age_65_69" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 65, 69)
replace age_group = "age_70_74" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 70, 74)
replace age_group = "age_75_79" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 75, 79)
replace age_group = "age_80_84" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 80, 84)
replace age_group = "age_85_89" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 85, 89)
replace age_group = "age_90_94" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 90, 94)
replace age_group = "age_95_99" if strtrim(mortality_agetxt) == "6" & inrange(__death_age, 95, 99)
replace age_group = "age_100_plus" if strtrim(mortality_agetxt) == "6" & __death_age >= 100 & !missing(__death_age)
generate str10 sex_atomic = "unknown"
replace sex_atomic = "female" if mortality_sex_canonical == 1
replace sex_atomic = "male" if mortality_sex_canonical == 2
tempfile primary_rows
preserve
    keep if cvd_prim == 1
    generate str10 mortality_definition = "primary"
    generate str20 category = "mixed_unallocated"
    replace category = "heart" if hrt_prim == 1 & str_prim == 0 & ///
        final_person_match == 1 & final_episode_outcome == "provisional_additional_dco"
    replace category = "stroke" if hrt_prim == 0 & str_prim == 1 & ///
        final_person_match == 1 & final_episode_outcome == "provisional_additional_dco"
    generate long current_additional_n = final_episode_outcome == "provisional_additional_dco"
    keep dth_year mortality_definition category sex_atomic age_group current_additional_n
    save `"`primary_rows'"', replace
restore
keep if cvd_incl == 1
generate str10 mortality_definition = "inclusive"
generate str20 category = "mixed_unallocated"
replace category = "heart" if hrt_incl == 1 & str_incl == 0 & ///
    final_person_match == 1 & final_episode_outcome == "provisional_additional_dco"
replace category = "stroke" if hrt_incl == 0 & str_incl == 1 & ///
    final_person_match == 1 & final_episode_outcome == "provisional_additional_dco"
generate long current_additional_n = final_episode_outcome == "provisional_additional_dco"
keep dth_year mortality_definition category sex_atomic age_group current_additional_n
append using `"`primary_rows'"'
collapse (sum) current_additional_n, by(mortality_definition dth_year category sex_atomic age_group)
isid mortality_definition dth_year category sex_atomic age_group
save `"`linkage_rows'"', replace

* ---------------------------------------------------------------------------
* 4. Collapse the Stage 4E-c output to its All-CVD anchor and retain its
*    selected fallback level. The anchor must have one row per definition/year.
* ---------------------------------------------------------------------------
use `"`joint_input'"', clear
foreach v in mortality_definition dth_year category estimation_level ///
        selected_total_A joint_lower_component_n joint_central_component_n ///
        joint_upper_component_n {
    capture confirm variable `v'
    if _rc exit 111
}
keep if inrange(dth_year, 2010, `last_complete_year')
assert inlist(mortality_definition, "primary", "inclusive")
assert inlist(category, "heart", "stroke", "mixed_unallocated")
assert inlist(estimation_level, "annual", "three_year", "all_years")
isid mortality_definition dth_year category
bysort mortality_definition dth_year: assert _N == 3
bysort mortality_definition dth_year (estimation_level): assert ///
    estimation_level[1] == estimation_level[_N]
assert !missing(joint_lower_component_n, joint_central_component_n, ///
    joint_upper_component_n)
collapse (sum) all_lower = joint_lower_component_n ///
    all_central = joint_central_component_n all_upper = joint_upper_component_n ///
    (firstnm) estimation_level anchor_selected_total_A = selected_total_A, ///
    by(mortality_definition dth_year)
isid mortality_definition dth_year
assert all_lower <= all_central & all_central <= all_upper
assert all_lower >= 0
quietly summarize dth_year, meanonly
assert r(min) == 2010
assert r(max) == `last_complete_year'
save `"`anchor'"', replace

* ---------------------------------------------------------------------------
* 5. Build a complete atomic category x sex x age grid and select the observed
*    additional-DCO composition from the same annual/three-year/all-years
*    fallback used by Stage 4E-c. Unknown age and sex remain private atoms.
* ---------------------------------------------------------------------------
postfile `category_handle' str20 category using `"`atomic_grid'"', replace
post `category_handle' ("heart")
post `category_handle' ("stroke")
post `category_handle' ("mixed_unallocated")
postclose `category_handle'
use `"`atomic_grid'"', clear
generate byte __key = 1
tempfile categories
save `"`categories'"', replace

clear
set obs 3
generate str10 sex_atomic = "female" if _n == 1
replace sex_atomic = "male" if _n == 2
replace sex_atomic = "unknown" if _n == 3
generate byte __key = 1
tempfile sexes
save `"`sexes'"', replace

use `"`standard'"', clear
keep age_group
set obs `=_N + 1'
replace age_group = "age_unknown" if missing(age_group)
generate byte __key = 1
tempfile ages
save `"`ages'"', replace

use `"`categories'"', clear
joinby __key using `"`sexes'"'
joinby __key using `"`ages'"'
drop __key
isid category sex_atomic age_group
generate byte __key = 1
save `"`atomic_grid'"', replace

use `"`anchor'"', clear
generate byte __key = 1
joinby __key using `"`atomic_grid'"'
drop __key
merge 1:1 mortality_definition dth_year category sex_atomic age_group ///
    using `"`linkage_rows'"', nogen keep(master match)
replace current_additional_n = 0 if missing(current_additional_n)
isid mortality_definition dth_year category sex_atomic age_group
save `"`grid'"', replace

* Selected source additional-DCO composition.
use `"`linkage_rows'"', clear
rename dth_year source_year
rename current_additional_n source_additional_n
save `"`source_a'"', replace

use `"`grid'"', clear
keep mortality_definition dth_year estimation_level category sex_atomic age_group
rename dth_year target_year
joinby mortality_definition category sex_atomic age_group using `"`source_a'"'
keep if (estimation_level == "annual" & source_year == target_year) | ///
    (estimation_level == "three_year" & inrange(source_year, target_year - 1, target_year + 1)) | ///
    (estimation_level == "all_years")
collapse (sum) selected_additional_n = source_additional_n, ///
    by(mortality_definition target_year category sex_atomic age_group)
rename target_year dth_year
save `"`source_a'"', replace

use `"`grid'"', clear
merge 1:1 mortality_definition dth_year category sex_atomic age_group ///
    using `"`source_a'"', nogen keep(master match)
replace selected_additional_n = 0 if missing(selected_additional_n)
bysort mortality_definition dth_year: egen double selected_total_additional_n = total(selected_additional_n)
assert selected_total_additional_n > 0
assert abs(selected_total_additional_n - anchor_selected_total_A) < 0.000001
generate double allocation_probability = selected_additional_n / selected_total_additional_n
assert allocation_probability >= 0 & allocation_probability <= 1
bysort mortality_definition dth_year: egen double __allocation_sum = total(allocation_probability)
assert abs(__allocation_sum - 1) < 0.000000001
drop __allocation_sum
generate double all_unresolved_central = all_central - all_lower
generate double all_unresolved_upper = all_upper - all_lower
assert all_unresolved_central >= 0 & all_unresolved_upper >= all_unresolved_central
generate double dco_lower_component_n = current_additional_n
generate double dco_central_component_n = current_additional_n + ///
    allocation_probability * all_unresolved_central
generate double dco_upper_component_n = current_additional_n + ///
    allocation_probability * all_unresolved_upper
assert dco_lower_component_n <= dco_central_component_n
assert dco_central_component_n <= dco_upper_component_n
save `"`components_atomic'"', replace

* Add the all-sex components as direct sums of the atomic female/male/unknown
* components. Unknown remains private after the all-sex sum is created.
use `"`components_atomic'"', clear
preserve
    collapse (sum) current_additional_n selected_additional_n ///
        dco_lower_component_n dco_central_component_n dco_upper_component_n ///
        (firstnm) estimation_level selected_total_additional_n ///
        all_lower all_central all_upper, by(mortality_definition dth_year category age_group)
    generate str10 sex = "all"
    save `"`components'"', replace
restore
rename sex_atomic sex
append using `"`components'"'

* Add the all-CVD DCO component. Keep unknown sex and mixed/unallocated in the
* private file; they are removed only from the public-shaped rate lattice.
preserve
    collapse (sum) current_additional_n selected_additional_n ///
        dco_lower_component_n dco_central_component_n dco_upper_component_n, ///
        by(mortality_definition dth_year sex age_group)
    generate str20 category = "all_cvd"
    tempfile all_cvd_components
    save `"`all_cvd_components'"', replace
restore
append using `"`all_cvd_components'"'
sort mortality_definition dth_year category sex age_group
save `"`components'"', replace

* ---------------------------------------------------------------------------
* 6. Create annual crude rates. Mixed rows stay in the component output but do
*    not enter public-shaped rate output.
* ---------------------------------------------------------------------------
use `"`components'"', clear
keep if inlist(category, "all_cvd", "heart", "stroke") & ///
    inlist(sex, "all", "female", "male")
rename category event_type
merge m:1 dth_year event_type sex age_group using `"`hospital'"', ///
    nogen keep(master match)
replace hospital_n = 0 if missing(hospital_n)
collapse (sum) hospital_n dco_lower_component_n dco_central_component_n ///
    dco_upper_component_n, by(mortality_definition dth_year event_type sex)
save `"`rates_crude'"', replace

use `"`population'"', clear
collapse (sum) denominator = population, by(year sex)
rename year dth_year
isid dth_year sex
save `"`all_age_population'"', replace

use `"`rates_crude'"', clear
merge m:1 dth_year sex using `"`all_age_population'"', nogen keep(master match)
assert denominator > 0 & !missing(denominator)
generate double hospital_rate = 100000 * hospital_n / denominator
generate double dco_lower_rate = 100000 * (hospital_n + dco_lower_component_n) / denominator
generate double dco_central_rate = 100000 * (hospital_n + dco_central_component_n) / denominator
generate double dco_upper_rate = 100000 * (hospital_n + dco_upper_component_n) / denominator
assert dco_lower_rate <= dco_central_rate & dco_central_rate <= dco_upper_rate
save `"`rates_crude'"', replace

* ---------------------------------------------------------------------------
* 7. Direct age standardisation. age_unknown is deliberately excluded.
* ---------------------------------------------------------------------------
use `"`components'"', clear
keep if inlist(category, "all_cvd", "heart", "stroke") & ///
    inlist(sex, "all", "female", "male") & age_group != "age_unknown"
rename category event_type
merge m:1 dth_year event_type sex age_group using `"`hospital'"', ///
    nogen keep(master match)
replace hospital_n = 0 if missing(hospital_n)
preserve
    use `"`population'"', clear
    rename year dth_year
    isid dth_year sex age_group
    tempfile population_asr
    save `"`population_asr'"', replace
restore
merge m:1 dth_year sex age_group using `"`population_asr'"', nogen keep(master match)
assert population > 0 & !missing(population)
merge m:1 age_group using `"`standard'"', nogen keep(master match)
assert standard_weight > 0 & !missing(standard_weight)
generate double hospital_rate_component = standard_weight * 100000 * hospital_n / population
generate double dco_lower_rate_component = standard_weight * 100000 * ///
    (hospital_n + dco_lower_component_n) / population
generate double dco_central_rate_component = standard_weight * 100000 * ///
    (hospital_n + dco_central_component_n) / population
generate double dco_upper_rate_component = standard_weight * 100000 * ///
    (hospital_n + dco_upper_component_n) / population
collapse (sum) hospital_rate = hospital_rate_component ///
    dco_lower_rate = dco_lower_rate_component ///
    dco_central_rate = dco_central_rate_component ///
    dco_upper_rate = dco_upper_rate_component ///
    hospital_n dco_lower_component_n dco_central_component_n ///
    dco_upper_component_n, by(mortality_definition dth_year event_type sex)
generate double denominator = .
assert dco_lower_rate <= dco_central_rate & dco_central_rate <= dco_upper_rate
save `"`rates_asr'"', replace

* ---------------------------------------------------------------------------
* 8. Shape private candidate rate rows. Lower and upper are fields on the same
*    row as the central estimate; they are not duplicate public rows.
* ---------------------------------------------------------------------------
use `"`rates_crude'"', clear
generate str20 age_group = "all"
tempfile crude_rows
save `"`crude_rows'"', replace
use `"`rates_asr'"', clear
generate str20 age_group = "age_standardised"
append using `"`crude_rows'"'

preserve
    keep dth_year event_type sex age_group hospital_n hospital_rate denominator
    collapse (firstnm) hospital_n hospital_rate denominator, ///
        by(dth_year event_type sex age_group)
    generate str24 metric_id = "CVD-INCIDENCE-001"
    generate str12 period_type = "annual"
    generate byte period_month = .
    generate str22 ascertainment_scope = "hospital_only"
    generate str16 mortality_definition = "not_applicable"
    generate str12 estimate_basis = "observed"
    generate str18 unit = "rate_per_100000"
    generate double value = hospital_rate
    generate double numerator = hospital_n
    replace numerator = . if age_group == "age_standardised"
    generate double linkage_lower_value = .
    generate double linkage_upper_value = .
    generate byte period_complete = 1
    generate str24 schema_version = "bnr_cvd_public_metric_v2"
    generate str16 release_id = "`release_id'"
    generate str12 status_flag = "final"
    generate str18 method_version = "cvd_rates_v1_0_6"
    generate str12 population_source = "UN_WPP_2024"
    generate str3 country_iso3 = "BRB"
    generate str10 population_unit = "persons"
    generate str10 population_extraction_date = "2026-08-26"
    generate str28 population_basis = "historical_estimate"
    replace population_basis = "medium_variant_projection" if dth_year >= 2024
    generate str28 standard_population = "WHO_WORLD_2000_2025"
    keep schema_version release_id metric_id period_type dth_year period_month ///
        event_type sex age_group ///
        ascertainment_scope mortality_definition estimate_basis unit value ///
        numerator denominator linkage_lower_value linkage_upper_value ///
        period_complete status_flag method_version population_source country_iso3 ///
        population_unit population_extraction_date population_basis standard_population
    tempfile hospital_rows
    save `"`hospital_rows'"', replace
restore

keep dth_year event_type sex age_group mortality_definition hospital_n ///
    dco_lower_component_n dco_central_component_n dco_upper_component_n ///
    dco_central_rate dco_lower_rate dco_upper_rate denominator
generate str24 metric_id = "CVD-INCIDENCE-001"
generate str12 period_type = "annual"
generate byte period_month = .
generate str22 ascertainment_scope = "hospital_plus_dco"
generate str12 estimate_basis = "estimated"
generate str18 unit = "rate_per_100000"
generate double value = dco_central_rate
generate double numerator = hospital_n + dco_central_component_n
replace numerator = . if age_group == "age_standardised"
generate double linkage_lower_value = dco_lower_rate
generate double linkage_upper_value = dco_upper_rate
generate byte period_complete = 1
generate str24 schema_version = "bnr_cvd_public_metric_v2"
generate str16 release_id = "`release_id'"
generate str12 status_flag = "final"
generate str18 method_version = "cvd_rates_v1_0_6"
generate str12 population_source = "UN_WPP_2024"
generate str3 country_iso3 = "BRB"
generate str10 population_unit = "persons"
generate str10 population_extraction_date = "2026-08-26"
generate str28 population_basis = "historical_estimate"
replace population_basis = "medium_variant_projection" if dth_year >= 2024
generate str28 standard_population = "WHO_WORLD_2000_2025"
keep schema_version release_id metric_id period_type dth_year period_month ///
    event_type sex age_group ///
    ascertainment_scope mortality_definition estimate_basis unit value ///
    numerator denominator linkage_lower_value linkage_upper_value ///
    period_complete status_flag method_version population_source country_iso3 ///
    population_unit population_extraction_date population_basis standard_population
append using `"`hospital_rows'"'
sort release_id metric_id period_type dth_year event_type sex age_group ///
    ascertainment_scope mortality_definition
isid release_id metric_id period_type dth_year event_type sex age_group ///
    ascertainment_scope mortality_definition
save `"`rates_candidate'"', replace

* ---------------------------------------------------------------------------
* 9. Private component output and aggregate acceptance QA.
* ---------------------------------------------------------------------------
use `"`components'"', clear
sort mortality_definition dth_year category sex age_group
isid mortality_definition dth_year category sex age_group
save `"`components'"', replace

postfile `qa_handle' str96 check double value str220 detail using `"`qa_dta'"', replace
use `"`components_atomic'"', clear
collapse (sum) dco_lower_component_n dco_central_component_n dco_upper_component_n, ///
    by(mortality_definition dth_year)
merge 1:1 mortality_definition dth_year using `"`anchor'"', nogen
generate double lower_gap = dco_lower_component_n - all_lower
generate double central_gap = dco_central_component_n - all_central
generate double upper_gap = dco_upper_component_n - all_upper
quietly count if abs(lower_gap) > 0.000001
local lower_failures = r(N)
quietly count if abs(central_gap) > 0.000001
local central_failures = r(N)
quietly count if abs(upper_gap) > 0.000001
local upper_failures = r(N)
post `qa_handle' ("Age-sex DCO lower accounting failures") (`lower_failures') ///
    ("Atomic subtype-sex-age components equal the All-CVD lower anchor")
post `qa_handle' ("Age-sex DCO central accounting failures") (`central_failures') ///
    ("Atomic subtype-sex-age components equal the All-CVD central anchor")
post `qa_handle' ("Age-sex DCO upper accounting failures") (`upper_failures') ///
    ("Atomic subtype-sex-age components equal the All-CVD upper anchor")

use `"`components'"', clear
quietly count
local expected_component_rows = 704 * (`last_complete_year' - 2009)
local component_lattice_failures = abs(r(N) - `expected_component_rows')
post `qa_handle' ("Private component-lattice row difference") ///
    (`component_lattice_failures') ///
    ("Expected 704 rows per year including unknown sex/age and mixed/unallocated")

use `"`rates_candidate'"', clear
quietly count if ascertainment_scope == "hospital_plus_dco" & ///
    (value < linkage_lower_value | value > linkage_upper_value)
local bound_failures = r(N)
post `qa_handle' ("Published DCO rate-bound failures") (`bound_failures') ///
    ("Lower <= central <= upper for every DCO-enhanced crude and ASR row")

quietly count if age_group == "age_standardised" & missing(value)
local missing_asr = r(N)
post `qa_handle' ("Missing age-standardised rate rows") (`missing_asr') ///
    ("Population and WHO standard coverage must support every annual ASR row")

quietly count if !inlist(sex, "all", "female", "male") | ///
    !inlist(event_type, "all_cvd", "heart", "stroke") | ///
    !inlist(age_group, "all", "age_standardised")
local invalid_public_dimension = r(N)
post `qa_handle' ("Invalid public rate dimensions") (`invalid_public_dimension') ///
    ("Unknown sex and mixed/unallocated are private only")

quietly count if schema_version != "bnr_cvd_public_metric_v2" | ///
    release_id != "`release_id'" | method_version != "cvd_rates_v1_0_6" | ///
    population_source != "UN_WPP_2024" | country_iso3 != "BRB" | ///
    population_unit != "persons" | standard_population != "WHO_WORLD_2000_2025"
local metadata_failures = r(N)
post `qa_handle' ("Rate-method metadata failures") (`metadata_failures') ///
    ("Schema, release, method, denominator and standard identifiers are fixed")

quietly count if (age_group == "all" & ///
        (missing(numerator) | missing(denominator))) | ///
    (age_group == "age_standardised" & ///
        (!missing(numerator) | !missing(denominator)))
local numerator_denominator_failures = r(N)
post `qa_handle' ("Rate numerator/denominator field failures") ///
    (`numerator_denominator_failures') ///
    ("Crude rows retain both fields; ASR rows retain neither misleading pseudo-field")

quietly count if dth_year < 2010 | dth_year > `last_complete_year' | ///
    period_complete != 1 | status_flag != "final"
local period_failures = r(N)
post `qa_handle' ("Incomplete or out-of-range annual rate rows") (`period_failures') ///
    ("Annual rates cover complete calendar years 2010 through `last_complete_year' only")

quietly levelsof dth_year, local(rate_years)
local rate_year_n : word count `rate_years'
local expected_year_n = `last_complete_year' - 2009
local expected_rate_rows = 54 * `expected_year_n'
quietly count
local lattice_failures = abs(r(N) - `expected_rate_rows') + ///
    abs(`rate_year_n' - `expected_year_n')
post `qa_handle' ("Annual public-shaped rate-lattice row difference") (`lattice_failures') ///
    ("Expected 54 rows per complete year: 18 hospital-only and 36 DCO-enhanced")

preserve
    keep if ascertainment_scope == "hospital_plus_dco"
    keep dth_year event_type sex age_group mortality_definition value ///
        linkage_lower_value linkage_upper_value
    generate str10 definition = mortality_definition
    drop mortality_definition
    rename value estimate
    rename linkage_lower_value lower
    rename linkage_upper_value upper
    reshape wide estimate lower upper, i(dth_year event_type sex age_group) ///
        j(definition) string
    quietly count if estimateinclusive + 0.000001 < estimateprimary | ///
        lowerinclusive + 0.000001 < lowerprimary | ///
        upperinclusive + 0.000001 < upperprimary
    local definition_order_failures = r(N)
    if `definition_order_failures' > 0 {
        noisily display as error "Primary/Inclusive ordering diagnostic follows."
        noisily list dth_year event_type sex age_group ///
            estimateprimary estimateinclusive lowerprimary lowerinclusive ///
            upperprimary upperinclusive if ///
            estimateinclusive + 0.000001 < estimateprimary | ///
            lowerinclusive + 0.000001 < lowerprimary | ///
            upperinclusive + 0.000001 < upperprimary, noobs clean
    }
restore
post `qa_handle' ("Primary/Inclusive rate-ordering failures") (`definition_order_failures') ///
    ("Inclusive lower, central and upper rates must not be below Primary")

preserve
    keep if age_group == "all"
    keep dth_year event_type ascertainment_scope mortality_definition sex numerator
    reshape wide numerator, i(dth_year event_type ascertainment_scope ///
        mortality_definition) j(sex) string
    quietly count if numeratorall + 0.000001 < numeratorfemale + numeratormale
    local all_sex_accounting_failures = r(N)
restore
post `qa_handle' ("All-sex numerator accounting failures") ///
    (`all_sex_accounting_failures') ///
    ("All-sex crude numerator includes female, male and any unknown-sex records")
postclose `qa_handle'

use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace
assert `lower_failures' == 0
assert `central_failures' == 0
assert `upper_failures' == 0
assert `component_lattice_failures' == 0
assert `bound_failures' == 0
assert `missing_asr' == 0
assert `invalid_public_dimension' == 0
assert `metadata_failures' == 0
assert `numerator_denominator_failures' == 0
assert `period_failures' == 0
assert `lattice_failures' == 0
assert `definition_order_failures' == 0
assert `all_sex_accounting_failures' == 0

use `"`rates_candidate'"', clear
save `"`rates_output'"', replace
use `"`components'"', clear
save `"`components_output'"', replace

display as result "Private CVD annual rate candidate and QA created."
display as result "  Complete annual range: 2010--`last_complete_year'"

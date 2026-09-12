/*******************************************************************************
DO-FILE:     bnr_cvd_estimate_joint_subtype_core.do
VERSION:     1.0.6 (25 August 2026)
PURPOSE:     Stage 4E-c joint Heart/Stroke/mixed DCO estimator.

             All-CVD Stage 4D supplies the unresolved DCO total. Stage 4E-a
             supplies mutually exclusive reporting categories. The observed
             deterministic additional-DCO composition is used to allocate the
             All-CVD unresolved central component jointly across Heart, Stroke
             and mixed/unallocated CVD.
*******************************************************************************/
version 19
clear
set more off
args all_input concordance_input results_output qa_output
if `"`all_input'"' == "" | `"`concordance_input'"' == "" | ///
        `"`results_output'"' == "" | `"`qa_output'"' == "" {
    display as error "Joint subtype estimator received an incomplete file contract."
    exit 198
}
capture confirm file `"`all_input'"'
if _rc exit 601
capture confirm file `"`concordance_input'"'
if _rc exit 601

tempfile all years categories current_categories source annual_total annual_source_total annual_categories annual_current ///
    three_total all_total three_categories all_categories qa_dta

* All-CVD anchor.
use `"`all_input'"', clear
foreach v in mortality_definition dth_year dco_lower_component_n ///
        dco_central_component_n dco_upper_component_n {
    capture confirm variable `v'
    if _rc {
        display as error "All-CVD output is missing: `v'"
        exit 111
    }
}
keep mortality_definition dth_year dco_lower_component_n ///
    dco_central_component_n dco_upper_component_n
rename dco_lower_component_n all_lower
rename dco_central_component_n all_central
rename dco_upper_component_n all_upper
keep if dth_year >= 2010
isid mortality_definition dth_year
save `"`all'"', replace

* Convert every Stage 4E-a route into one mutually exclusive category and one
* outcome. Anything not explicitly concordant Heart/Stroke is mixed/unallocated.
use `"`concordance_input'"', clear
foreach v in mortality_definition dth_year final_episode_outcome ///
        attribution_route candidate_n {
    capture confirm variable `v'
    if _rc {
        display as error "Stage 4E-a profile is missing: `v'"
        exit 111
    }
}
generate str20 category = "mixed_unallocated"
replace category = "heart" if inlist(attribution_route, ///
    "heart_recorded_concordant", "heart_dco_eligible")
replace category = "stroke" if inlist(attribution_route, ///
    "stroke_recorded_concordant", "stroke_dco_eligible")
generate long recorded_link_n = 0
generate long additional_dco_n = 0
generate long unresolved_n = candidate_n
replace recorded_link_n = candidate_n if ///
    final_episode_outcome == "recorded_event_0_27_days"
replace additional_dco_n = candidate_n if ///
    final_episode_outcome == "provisional_additional_dco"
replace unresolved_n = 0 if inlist(final_episode_outcome, ///
    "recorded_event_0_27_days", "provisional_additional_dco")
collapse (sum) recorded_link_n additional_dco_n unresolved_n, ///
    by(mortality_definition dth_year category)
generate long resolved_n = recorded_link_n + additional_dco_n
generate long candidate_n = resolved_n + unresolved_n
isid mortality_definition dth_year category
save `"`source'"', replace

* Build a complete three-category annual grid, retaining zero cells.
use `"`all'"', clear
keep mortality_definition dth_year
duplicates drop
expand 3
bysort mortality_definition dth_year: generate byte __cat_order = _n
generate str20 category = "heart" if __cat_order == 1
replace category = "stroke" if __cat_order == 2
replace category = "mixed_unallocated" if __cat_order == 3
drop __cat_order
merge 1:1 mortality_definition dth_year category using `"`source'"', ///
    nogen keep(master match)
foreach v in recorded_link_n additional_dco_n unresolved_n resolved_n candidate_n {
    replace `v' = 0 if missing(`v')
}
isid mortality_definition dth_year category
save `"`categories'"', replace
save `"`current_categories'"', replace

* Annual resolved totals and category A counts.
use `"`categories'"', clear
collapse (sum) annual_resolved_n = resolved_n, by(mortality_definition dth_year)
save `"`annual_total'"', replace
preserve
    rename dth_year source_year
    save `"`annual_source_total'"', replace
restore

use `"`categories'"', clear
keep mortality_definition dth_year category additional_dco_n resolved_n
save `"`annual_current'"', replace
keep mortality_definition dth_year category additional_dco_n resolved_n
rename dth_year source_year
rename additional_dco_n source_additional_dco_n
rename resolved_n source_resolved_n
save `"`annual_categories'"', replace

* The target grid is the All-CVD year grid crossed with three categories.
use `"`all'"', clear
keep mortality_definition dth_year
duplicates drop
save `"`years'"', replace
expand 3
bysort mortality_definition dth_year: generate byte __cat_order = _n
generate str20 category = "heart" if __cat_order == 1
replace category = "stroke" if __cat_order == 2
replace category = "mixed_unallocated" if __cat_order == 3
drop __cat_order
save `"`categories'"', replace

* Three-year category pools.
use `"`categories'"', clear
joinby mortality_definition category using `"`annual_categories'"'
keep if inrange(source_year, dth_year - 1, dth_year + 1)
collapse (sum) three_additional_dco_n = source_additional_dco_n ///
    three_resolved_n = source_resolved_n, ///
    by(mortality_definition dth_year category)
save `"`three_categories'"', replace

use `"`years'"', clear
joinby mortality_definition using `"`annual_source_total'"'
keep if inrange(source_year, dth_year - 1, dth_year + 1)
collapse (sum) three_total_resolved_n = annual_resolved_n, ///
    by(mortality_definition dth_year)
save `"`three_total'"', replace

* All-years category pools and totals.
use `"`annual_categories'"', clear
collapse (sum) all_additional_dco_n = source_additional_dco_n ///
    all_resolved_n = source_resolved_n, by(mortality_definition category)
save `"`all_categories'"', replace
use `"`annual_total'"', clear
collapse (sum) all_total_resolved_n = annual_resolved_n, ///
    by(mortality_definition)
save `"`all_total'"', replace

* Select the common resolved-DCO composition source for each target year.
use `"`years'"', clear
merge 1:1 mortality_definition dth_year using `"`annual_total'"', ///
    nogen keep(master match)
rename annual_resolved_n annual_total_resolved_n
merge 1:1 mortality_definition dth_year using `"`three_total'"', ///
    nogen keep(master match)
merge m:1 mortality_definition using `"`all_total'"', ///
    nogen keep(master match)
generate str24 estimation_level = "insufficient_resolved"
replace estimation_level = "annual" if annual_total_resolved_n >= 20
replace estimation_level = "three_year" if estimation_level == ///
    "insufficient_resolved" & three_total_resolved_n >= 20
replace estimation_level = "all_years" if estimation_level == ///
    "insufficient_resolved" & all_total_resolved_n >= 20
generate long selected_resolved_n = .
replace selected_resolved_n = annual_total_resolved_n if estimation_level == "annual"
replace selected_resolved_n = three_total_resolved_n if estimation_level == "three_year"
replace selected_resolved_n = all_total_resolved_n if estimation_level == "all_years"
keep mortality_definition dth_year estimation_level selected_resolved_n
save `"`years'"', replace

* Attach category A counts from the same selected fallback window.
use `"`years'"', clear
expand 3
bysort mortality_definition dth_year: generate byte __cat_order = _n
generate str20 category = "heart" if __cat_order == 1
replace category = "stroke" if __cat_order == 2
replace category = "mixed_unallocated" if __cat_order == 3
drop __cat_order
merge 1:1 mortality_definition dth_year category using `"`annual_current'"', ///
    nogen keep(master match)
foreach v in additional_dco_n resolved_n {
    replace `v' = 0 if missing(`v')
}
rename additional_dco_n annual_A
rename resolved_n annual_resolved
merge 1:1 mortality_definition dth_year category using `"`three_categories'"', ///
    nogen keep(master match)
merge m:1 mortality_definition category using `"`all_categories'"', ///
    nogen keep(master match)
foreach v in three_additional_dco_n three_resolved_n all_additional_dco_n all_resolved_n {
    replace `v' = 0 if missing(`v')
}
generate double selected_A = annual_A if estimation_level == "annual"
replace selected_A = three_additional_dco_n if estimation_level == "three_year"
replace selected_A = all_additional_dco_n if estimation_level == "all_years"
generate double selected_total_A = .
bysort mortality_definition dth_year: egen double __sum_selected_A = total(selected_A)
replace selected_total_A = __sum_selected_A
generate double allocation_probability = selected_A / selected_total_A if ///
    estimation_level != "insufficient_resolved" & selected_total_A > 0
assert allocation_probability >= 0 & allocation_probability <= 1 if ///
    !missing(allocation_probability)
save `"`years'"', replace

* Combine the current-year category counts with the All-CVD anchor.
use `"`current_categories'"', clear
merge 1:1 mortality_definition dth_year category using `"`years'"', ///
    nogen keep(master match)
merge m:1 mortality_definition dth_year using `"`all'"', ///
    nogen keep(master match)
generate double all_unresolved_central = all_central - all_lower
generate double all_unresolved_upper = all_upper - all_lower
generate double joint_lower_component_n = additional_dco_n
generate double joint_central_component_n = additional_dco_n + ///
    allocation_probability * all_unresolved_central if ///
    !missing(allocation_probability, all_unresolved_central)
generate double joint_upper_component_n = additional_dco_n + ///
    allocation_probability * all_unresolved_upper if ///
    !missing(allocation_probability, all_unresolved_upper)
assert joint_lower_component_n <= joint_central_component_n if ///
    !missing(joint_central_component_n)
assert joint_central_component_n <= joint_upper_component_n if ///
    !missing(joint_central_component_n)
order mortality_definition dth_year category candidate_n recorded_link_n ///
    additional_dco_n unresolved_n resolved_n estimation_level ///
    selected_resolved_n selected_A selected_total_A allocation_probability ///
    joint_lower_component_n joint_central_component_n joint_upper_component_n
sort mortality_definition dth_year category
save `"`results_output'"', replace

* QA: candidate partition, exact accounting and missing composition shares.
tempname qa_handle
postfile `qa_handle' str96 check double value str200 detail using `"`qa_dta'"', replace
preserve
    collapse (sum) candidate_n unresolved_n joint_lower_component_n ///
        joint_central_component_n joint_upper_component_n, ///
        by(mortality_definition dth_year)
    merge 1:1 mortality_definition dth_year using `"`all'"', nogen
    generate double lower_gap = joint_lower_component_n - all_lower
    generate double central_gap = joint_central_component_n - all_central
    generate double upper_gap = joint_upper_component_n - all_upper
    generate double unresolved_gap = unresolved_n - (all_upper - all_lower)
    quietly count if abs(lower_gap) > 0.000001
    local lower_failures = r(N)
    quietly count if abs(central_gap) > 0.000001
    local central_failures = r(N)
    quietly count if abs(upper_gap) > 0.000001
    local upper_failures = r(N)
    quietly count if abs(unresolved_gap) > 0.000001
    local unresolved_failures = r(N)
    if `lower_failures' | `central_failures' | `upper_failures' | ///
            `unresolved_failures' {
        noisily display as error "Joint accounting diagnostic follows."
        noisily list mortality_definition dth_year joint_lower_component_n ///
            all_lower lower_gap joint_central_component_n all_central ///
            central_gap joint_upper_component_n all_upper upper_gap ///
            unresolved_n unresolved_gap, noobs clean
    }
restore
quietly count if missing(allocation_probability)
local missing_share_cells = r(N)
post `qa_handle' ("Joint lower accounting failures") (`lower_failures') ///
    ("Heart plus Stroke plus mixed/unallocated equals All-CVD lower")
post `qa_handle' ("Joint central accounting failures") (`central_failures') ///
    ("Joint Heart/Stroke/mixed allocation equals All-CVD central")
post `qa_handle' ("Joint upper accounting failures") (`upper_failures') ///
    ("Heart plus Stroke plus mixed/unallocated equals All-CVD upper")
post `qa_handle' ("Unresolved candidate partition failures") (`unresolved_failures') ///
    ("Joint category unresolved candidates equal the All-CVD unresolved pool")
post `qa_handle' ("Missing allocation-probability cells") (`missing_share_cells') ///
    ("No joint central estimate is produced without a resolved-DCO composition")
postclose `qa_handle'
use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace
assert `lower_failures' == 0
assert `central_failures' == 0
assert `upper_failures' == 0
assert `unresolved_failures' == 0
assert `missing_share_cells' == 0
display as result "Joint subtype DCO estimation created."

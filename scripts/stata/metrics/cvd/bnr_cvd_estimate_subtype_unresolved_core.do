/*******************************************************************************

DO-FILE:     bnr_cvd_estimate_subtype_unresolved_core.do

VERSION:     1.0.2 (25 August 2026)

PURPOSE:     Stage 4E-b private aggregate unresolved-linkage estimator for
             Heart and Stroke national-incidence DCO components.

             It starts from the completed Stage 4E-a aggregate concordance
             profile. It uses family-specific, concordant evidence only:

             - Heart-only certificate + Heart/Both episode = recorded Heart;
             - Stroke-only certificate + Stroke/Both episode = recorded Stroke;
             - Heart-only or Stroke-only certificate + no episode =
               deterministic additional DCO for that same family; and
             - pending identity with an unambiguous certificate family is an
               unresolved candidate for that family.

             Both-family certificates, family-discordant linked episodes and
             matched episodes with no usable family are never allocated to a
             subtype by this pass. They remain explicit private exclusions.

             Within each mortality definition, subtype and death year:
             p = A / (L + A). A year uses its own fraction only when L+A is
             at least 20. Otherwise the fallback is same subtype/definition
             year plus/minus one, then all available years, then insufficient
             resolved evidence.

             The output contains DCO components only. It does not add hospital
             events, calculate rates, alter All-CVD Stage 4D results, make a
             person-level decision, call Steps 5/6 or create public output.

INPUT:       Private Stage 4E-a aggregate concordance-cell DTA.

OUTPUTS:      Private annual Heart/Stroke aggregate-estimation DTA and QA CSV.

*******************************************************************************/

version 19

clear

set more off

args concordance_input results_output qa_output

if `"`concordance_input'"' == "" | `"`results_output'"' == "" | ///
        `"`qa_output'"' == "" {
    display as error "Subtype unresolved-estimation core received an incomplete file contract."
    exit 198
}

capture confirm file `"`concordance_input'"'
if _rc {
    display as error "Required Stage 4E-a concordance profile was not found: `concordance_input'"
    exit 601
}

tempfile annual_source three_year_source three_year_estimate ///
    all_year_estimate qa_dta primary_estimate

* ---------------------------------------------------------------------------
* 1. Validate the aggregate profile and create family-specific candidate
*    categories. No person-level linkage is repeated or exported here.
* ---------------------------------------------------------------------------
use `"`concordance_input'"', clear

foreach required_variable in mortality_definition dth_year ///
        certificate_family episode_family final_episode_outcome ///
        attribution_route candidate_n {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Stage 4E-a concordance profile is missing required variable: `required_variable'"
        exit 111
    }
}

isid mortality_definition dth_year certificate_family episode_family ///
    final_episode_outcome attribution_route

assert inlist(mortality_definition, "primary", "inclusive")
assert inlist(certificate_family, "heart_only", "stroke_only", "both", ///
    "unclassified")
assert candidate_n >= 0 & candidate_n == floor(candidate_n)

* Mixed and unclassified certificate families are deliberately not retained in
* a subtype denominator. They remain available in the Stage 4E-a profile and
* in the All-CVD Stage 4D estimator.
keep if inlist(certificate_family, "heart_only", "stroke_only")

generate str10 event_type = "heart" if certificate_family == "heart_only"
replace event_type = "stroke" if certificate_family == "stroke_only"
assert inlist(event_type, "heart", "stroke")

generate long family_candidate_n = candidate_n
generate long deterministic_recorded_link_n = 0
generate long deterministic_additional_dco_n = 0
generate long unresolved_candidate_n = 0
generate long linked_subtype_discordant_n = 0
generate long matched_episode_unclassified_n = 0

replace deterministic_recorded_link_n = candidate_n if ///
    attribution_route == "heart_recorded_concordant" & event_type == "heart"
replace deterministic_recorded_link_n = candidate_n if ///
    attribution_route == "stroke_recorded_concordant" & event_type == "stroke"

replace deterministic_additional_dco_n = candidate_n if ///
    attribution_route == "heart_dco_eligible" & event_type == "heart"
replace deterministic_additional_dco_n = candidate_n if ///
    attribution_route == "stroke_dco_eligible" & event_type == "stroke"

replace unresolved_candidate_n = candidate_n if ///
    attribution_route == "pending_identity"
replace linked_subtype_discordant_n = candidate_n if ///
    attribution_route == "linked_subtype_discordant"
replace matched_episode_unclassified_n = candidate_n if ///
    attribution_route == "matched_episode_unclassified"

generate long recognised_route_n = deterministic_recorded_link_n + ///
    deterministic_additional_dco_n + unresolved_candidate_n + ///
    linked_subtype_discordant_n + matched_episode_unclassified_n

quietly count if family_candidate_n != recognised_route_n
if r(N) {
    display as error "A Heart-only or Stroke-only concordance cell has an unrecognised attribution route."
    exit 459
}

collapse (sum) family_candidate_n deterministic_recorded_link_n ///
    deterministic_additional_dco_n unresolved_candidate_n ///
    linked_subtype_discordant_n matched_episode_unclassified_n, ///
    by(mortality_definition event_type dth_year)

generate long resolved_n = deterministic_recorded_link_n + ///
    deterministic_additional_dco_n
generate long calibration_candidate_n = resolved_n + unresolved_candidate_n
generate long excluded_candidate_n = linked_subtype_discordant_n + ///
    matched_episode_unclassified_n

assert family_candidate_n == calibration_candidate_n + excluded_candidate_n
assert resolved_n == deterministic_recorded_link_n + ///
    deterministic_additional_dco_n

generate double annual_additional_fraction = ///
    deterministic_additional_dco_n / resolved_n if resolved_n > 0

isid mortality_definition event_type dth_year
save `"`annual_source'"', replace

* ---------------------------------------------------------------------------
* 2. Build the target-year plus/minus one fallback table within each subtype
*    and mortality definition. Only actual available years are pooled.
* ---------------------------------------------------------------------------
preserve
    keep mortality_definition event_type dth_year
    rename dth_year target_year
    save `"`three_year_estimate'"', replace
restore

use `"`annual_source'"', clear
keep mortality_definition event_type dth_year deterministic_recorded_link_n ///
    deterministic_additional_dco_n
rename dth_year source_year
rename deterministic_recorded_link_n source_recorded_link_n
rename deterministic_additional_dco_n source_additional_dco_n
save `"`three_year_source'"', replace

use `"`three_year_estimate'"', clear
joinby mortality_definition event_type using `"`three_year_source'"'
keep if inrange(source_year, target_year - 1, target_year + 1)
collapse (sum) three_year_recorded_link_n = source_recorded_link_n ///
    three_year_additional_dco_n = source_additional_dco_n ///
    (min) three_year_source_start = source_year ///
    (max) three_year_source_end = source_year, ///
    by(mortality_definition event_type target_year)
rename target_year dth_year
generate long three_year_resolved_n = ///
    three_year_recorded_link_n + three_year_additional_dco_n
generate double three_year_additional_fraction = ///
    three_year_additional_dco_n / three_year_resolved_n if ///
    three_year_resolved_n > 0
isid mortality_definition event_type dth_year
save `"`three_year_estimate'"', replace

* ---------------------------------------------------------------------------
* 3. Build the all-years fallback within each subtype and mortality definition.
* ---------------------------------------------------------------------------
use `"`annual_source'"', clear
collapse (sum) all_year_recorded_link_n = deterministic_recorded_link_n ///
    all_year_additional_dco_n = deterministic_additional_dco_n ///
    (min) all_year_source_start = dth_year ///
    (max) all_year_source_end = dth_year, ///
    by(mortality_definition event_type)
generate long all_year_resolved_n = ///
    all_year_recorded_link_n + all_year_additional_dco_n
generate double all_year_additional_fraction = ///
    all_year_additional_dco_n / all_year_resolved_n if all_year_resolved_n > 0
isid mortality_definition event_type
save `"`all_year_estimate'"', replace

* ---------------------------------------------------------------------------
* 4. Select the approved fallback and calculate aggregate-only lower, central
*    and upper DCO components for each annual subtype cell.
* ---------------------------------------------------------------------------
use `"`annual_source'"', clear
merge 1:1 mortality_definition event_type dth_year ///
    using `"`three_year_estimate'"', keep(master match) gen(__three_year_merge)
assert __three_year_merge == 3
drop __three_year_merge
merge m:1 mortality_definition event_type ///
    using `"`all_year_estimate'"', keep(master match) gen(__all_year_merge)
assert __all_year_merge == 3
drop __all_year_merge

generate str24 estimation_level = "insufficient_resolved"
generate long selected_resolved_n = .
generate long selected_additional_dco_n = .
generate int selected_source_start = .
generate int selected_source_end = .

replace estimation_level = "annual" if resolved_n >= 20
replace selected_resolved_n = resolved_n if estimation_level == "annual"
replace selected_additional_dco_n = deterministic_additional_dco_n if ///
    estimation_level == "annual"
replace selected_source_start = dth_year if estimation_level == "annual"
replace selected_source_end = dth_year if estimation_level == "annual"

replace estimation_level = "three_year" if estimation_level == ///
    "insufficient_resolved" & three_year_resolved_n >= 20
replace selected_resolved_n = three_year_resolved_n if ///
    estimation_level == "three_year"
replace selected_additional_dco_n = three_year_additional_dco_n if ///
    estimation_level == "three_year"
replace selected_source_start = three_year_source_start if ///
    estimation_level == "three_year"
replace selected_source_end = three_year_source_end if ///
    estimation_level == "three_year"

replace estimation_level = "all_years" if estimation_level == ///
    "insufficient_resolved" & all_year_resolved_n >= 20
replace selected_resolved_n = all_year_resolved_n if ///
    estimation_level == "all_years"
replace selected_additional_dco_n = all_year_additional_dco_n if ///
    estimation_level == "all_years"
replace selected_source_start = all_year_source_start if ///
    estimation_level == "all_years"
replace selected_source_end = all_year_source_end if ///
    estimation_level == "all_years"

generate double selected_additional_fraction = ///
    selected_additional_dco_n / selected_resolved_n if ///
    estimation_level != "insufficient_resolved"

assert selected_resolved_n >= 20 if estimation_level != "insufficient_resolved"
assert !missing(selected_additional_dco_n, selected_additional_fraction) if ///
    estimation_level != "insufficient_resolved"
assert missing(selected_resolved_n) & missing(selected_additional_dco_n) & ///
    missing(selected_additional_fraction) if ///
    estimation_level == "insufficient_resolved"
assert inrange(selected_additional_fraction, 0, 1) if ///
    estimation_level != "insufficient_resolved"

generate double estimated_unresolved_dco_n = ///
    selected_additional_fraction * unresolved_candidate_n if ///
    estimation_level != "insufficient_resolved"
generate double dco_lower_component_n = deterministic_additional_dco_n
generate double dco_central_component_n = deterministic_additional_dco_n + ///
    estimated_unresolved_dco_n if estimation_level != "insufficient_resolved"
generate double dco_upper_component_n = deterministic_additional_dco_n + ///
    unresolved_candidate_n

assert dco_lower_component_n <= dco_central_component_n if ///
    estimation_level != "insufficient_resolved"
assert dco_central_component_n <= dco_upper_component_n if ///
    estimation_level != "insufficient_resolved"

order mortality_definition event_type dth_year family_candidate_n ///
    deterministic_recorded_link_n deterministic_additional_dco_n ///
    unresolved_candidate_n linked_subtype_discordant_n ///
    matched_episode_unclassified_n excluded_candidate_n ///
    calibration_candidate_n resolved_n estimation_level ///
    selected_source_start selected_source_end selected_resolved_n ///
    selected_additional_dco_n selected_additional_fraction ///
    estimated_unresolved_dco_n dco_lower_component_n ///
    dco_central_component_n dco_upper_component_n ///
    annual_additional_fraction three_year_resolved_n ///
    three_year_additional_fraction all_year_resolved_n ///
    all_year_additional_fraction
sort mortality_definition event_type dth_year

label data "BNR private annual subtype unresolved-linkage estimation"
label variable event_type "Certificate family used for subtype estimation"
label variable family_candidate_n "Candidates with a Heart-only or Stroke-only certificate"
label variable excluded_candidate_n "Concordance routes excluded from subtype allocation"
label variable selected_additional_fraction "p = subtype deterministic additional DCOs / resolved subtype candidates"
label variable estimated_unresolved_dco_n "Aggregate estimated subtype DCOs among unresolved candidates"
label variable dco_lower_component_n "Subtype DCO lower: deterministic additional DCOs"
label variable dco_central_component_n "Subtype DCO central: deterministic plus estimated unresolved"
label variable dco_upper_component_n "Subtype DCO upper: deterministic additional plus all unresolved"

save `"`results_output'"', replace

* ---------------------------------------------------------------------------
* 5. Aggregate QA. The Primary/Inclusive lower and upper comparisons are
*    assessed separately for Heart and Stroke. Their central estimates are
*    separately calibrated model estimates and have no required ordering.
* ---------------------------------------------------------------------------
tempname qa_handle
postfile `qa_handle' str96 check double value str200 detail using `qa_dta', replace

foreach definition in primary inclusive {
    foreach subtype in heart stroke {
        quietly summarize family_candidate_n if ///
            mortality_definition == "`definition'" & event_type == "`subtype'", meanonly
        local family_total = r(sum)
        post `qa_handle' ("`definition' `subtype': family-specific candidates") ///
            (`family_total') ///
            ("Heart-only or Stroke-only certificate candidates; mixed certificates excluded")

        quietly summarize deterministic_recorded_link_n if ///
            mortality_definition == "`definition'" & event_type == "`subtype'", meanonly
        local recorded_total = r(sum)
        post `qa_handle' ("`definition' `subtype': concordant recorded links") ///
            (`recorded_total') ///
            ("Resolved 0-27-day episode with the same certificate family")

        quietly summarize deterministic_additional_dco_n if ///
            mortality_definition == "`definition'" & event_type == "`subtype'", meanonly
        local additional_total = r(sum)
        post `qa_handle' ("`definition' `subtype': deterministic additional DCOs") ///
            (`additional_total') ///
            ("Family-specific certificate with no same-person 0-27-day event")

        quietly summarize unresolved_candidate_n if ///
            mortality_definition == "`definition'" & event_type == "`subtype'", meanonly
        local unresolved_total = r(sum)
        post `qa_handle' ("`definition' `subtype': unresolved candidates") ///
            (`unresolved_total') ///
            ("Pending identity with an unambiguous certificate family")

        quietly summarize excluded_candidate_n if ///
            mortality_definition == "`definition'" & event_type == "`subtype'", meanonly
        local excluded_total = r(sum)
        post `qa_handle' ("`definition' `subtype': excluded concordance routes") ///
            (`excluded_total') ///
            ("Discordant or family-unclassified linked episodes are not subtype allocated")

        quietly summarize estimated_unresolved_dco_n if ///
            mortality_definition == "`definition'" & event_type == "`subtype'", meanonly
        local estimated_total = r(sum)
        post `qa_handle' ("`definition' `subtype': estimated unresolved DCOs") ///
            (`estimated_total') ///
            ("Sum of aggregate central estimates; may be fractional")

        foreach level in annual three_year all_years insufficient_resolved {
            quietly count if mortality_definition == "`definition'" & ///
                event_type == "`subtype'" & estimation_level == "`level'"
            local level_cells = r(N)
            post `qa_handle' ("`definition' `subtype': cells using `level'") ///
                (`level_cells') ///
                ("Cells selected by the approved subtype fallback hierarchy")
        }
    }
}

preserve
    keep if mortality_definition == "primary"
    keep event_type dth_year dco_lower_component_n dco_upper_component_n
    rename dco_lower_component_n primary_lower_component_n
    rename dco_upper_component_n primary_upper_component_n
    save `"`primary_estimate'"', replace
restore

preserve
    keep if mortality_definition == "inclusive"
    keep event_type dth_year dco_lower_component_n dco_upper_component_n
    rename dco_lower_component_n inclusive_lower_component_n
    rename dco_upper_component_n inclusive_upper_component_n
    merge 1:1 event_type dth_year using `"`primary_estimate'"', ///
        keep(master match) gen(__definition_merge)
    quietly count if __definition_merge == 3 & ///
        !missing(inclusive_lower_component_n, primary_lower_component_n) & ///
        inclusive_lower_component_n < primary_lower_component_n
    local lower_invariant_failures = r(N)
    quietly count if __definition_merge == 3 & ///
        !missing(inclusive_upper_component_n, primary_upper_component_n) & ///
        inclusive_upper_component_n < primary_upper_component_n
    local upper_invariant_failures = r(N)
restore

post `qa_handle' ("Primary/Inclusive subtype lower-component invariant failures") ///
    (`lower_invariant_failures') ///
    ("Inclusive deterministic subtype DCO component must not be below Primary in the same subtype/year")
post `qa_handle' ("Primary/Inclusive subtype upper-component invariant failures") ///
    (`upper_invariant_failures') ///
    ("Inclusive maximum subtype DCO component must not be below Primary in the same subtype/year")
assert `lower_invariant_failures' == 0
assert `upper_invariant_failures' == 0

postclose `qa_handle'

use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace

use `"`results_output'"', clear
quietly count if estimation_level == "insufficient_resolved"
local insufficient_cells = r(N)
quietly count
local annual_cells = r(N)

display as result "Subtype unresolved-linkage estimation created."
display as result "  Annual definition/subtype/year cells: `annual_cells'"
display as result "  Insufficient-resolved cells:          `insufficient_cells'"
display as result "  Mixed/discordant records:            Not subtype allocated"

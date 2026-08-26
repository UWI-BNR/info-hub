/*******************************************************************************

DO-FILE:     bnr_cvd_estimate_unresolved_core.do

VERSION:     1.0.1 (25 August 2026)

PURPOSE:     Stage 4D private aggregate unresolved-linkage estimator.

              Starting from the completed Stage 4C candidate diagnostic, this
              pass estimates the additional-DCO fraction among deterministically
              resolved deaths and applies that fraction only to aggregate
              unresolved counts. It is not a person-level classifier.

              For each mortality definition (Primary and Inclusive) and death
              year, p = A / (L + A), where L is a recorded 0--27-day episode
              and A is a deterministic additional DCO. A year uses its own p
              only when L+A is at least 20. Otherwise the fallback order is:

              1. same definition, target year plus/minus one calendar year;
              2. same definition, all available candidate years; or
              3. insufficient resolved candidates (no central estimate).

              The output contains aggregate DCO components only:
              lower=A; central=A+(p*U); upper=A+U. Hospital counts are not
              added until the later private metric-construction pass.

              It does not modify linkage results, label an unresolved person as
              a DCO, calculate public metrics, call Step 5/6, or create public
              output.

INPUT:        Private Stage 4C L01--L03 candidate diagnostic DTA.

OUTPUTS:      Private annual aggregate-estimation DTA and aggregate QA CSV.

*******************************************************************************/

version 19

clear

set more off

args linkage_input results_output qa_output

if `"`linkage_input'"' == "" | `"`results_output'"' == "" | ///
        `"`qa_output'"' == "" {
    display as error "Unresolved-estimation core received an incomplete file contract."
    exit 198
}

capture confirm file `"`linkage_input'"'
if _rc {
    display as error "Required Stage 4C private diagnostic was not found: `linkage_input'"
    exit 601
}

tempfile primary_candidates annual_source three_year_source ///
    three_year_estimate all_year_estimate qa_dta primary_estimate

* ---------------------------------------------------------------------------
* 1. Validate the Stage 4C input and create mutually exclusive aggregate
*    candidate categories. A candidate is either resolved as a recorded event,
*    resolved as a deterministic additional DCO, or remains unresolved.
* ---------------------------------------------------------------------------
use `"`linkage_input'"', clear

isid record_id

foreach required_variable in record_id dth_date dth_year cvd_prim cvd_incl ///
        final_person_match final_episode_outcome {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Stage 4C diagnostic is missing required variable: `required_variable'"
        exit 111
    }
}

assert inlist(cvd_prim, 0, 1)
assert inlist(cvd_incl, 0, 1)
assert cvd_prim <= cvd_incl
assert cvd_incl == 1
assert !missing(dth_date, dth_year)
assert dth_year == year(dth_date)
assert inlist(final_person_match, 0, 1)

generate byte recorded_event_link = ///
    final_episode_outcome == "recorded_event_0_27_days"
generate byte deterministic_additional_dco = ///
    final_episode_outcome == "provisional_additional_dco"
generate byte unresolved_candidate = final_person_match == 0
generate byte resolved_candidate = recorded_event_link == 1 | ///
    deterministic_additional_dco == 1

assert resolved_candidate + unresolved_candidate == 1
assert recorded_event_link + deterministic_additional_dco <= 1
assert final_person_match == 1 if resolved_candidate == 1
assert final_person_match == 0 if unresolved_candidate == 1

* One deterministic linkage is run against the Inclusive candidate pool. The
* same resolved outcomes are then subset independently for the Primary and
* Inclusive mortality definitions; neither is a linkage uncertainty bound.
preserve
    keep if cvd_prim == 1
    generate str10 mortality_definition = "primary"
    keep record_id dth_year mortality_definition recorded_event_link ///
        deterministic_additional_dco unresolved_candidate resolved_candidate
    save `"`primary_candidates'"', replace
restore

keep if cvd_incl == 1
generate str10 mortality_definition = "inclusive"
keep record_id dth_year mortality_definition recorded_event_link ///
    deterministic_additional_dco unresolved_candidate resolved_candidate
append using `"`primary_candidates'"'

generate byte candidate_n = 1
collapse (sum) candidate_n recorded_event_link deterministic_additional_dco ///
    unresolved_candidate resolved_candidate, by(mortality_definition dth_year)

assert candidate_n == resolved_candidate + unresolved_candidate
assert resolved_candidate == recorded_event_link + deterministic_additional_dco

rename recorded_event_link deterministic_recorded_link_n
rename deterministic_additional_dco deterministic_additional_dco_n
rename unresolved_candidate unresolved_candidate_n
rename resolved_candidate resolved_n
generate double annual_additional_fraction = ///
    deterministic_additional_dco_n / resolved_n if resolved_n > 0

save `"`annual_source'"', replace

* ---------------------------------------------------------------------------
* 2. Build the target-year plus/minus one fallback table. The pool contains
*    actual available candidate years only; no empty year is fabricated.
* ---------------------------------------------------------------------------
preserve
    keep mortality_definition dth_year
    rename dth_year target_year
    save `"`three_year_estimate'"', replace
restore

use `"`annual_source'"', clear
keep mortality_definition dth_year deterministic_recorded_link_n ///
    deterministic_additional_dco_n
rename dth_year source_year
rename deterministic_recorded_link_n source_recorded_link_n
rename deterministic_additional_dco_n source_additional_dco_n
save `"`three_year_source'"', replace

use `"`three_year_estimate'"', clear
joinby mortality_definition using `"`three_year_source'"'
keep if inrange(source_year, target_year - 1, target_year + 1)
collapse (sum) three_year_recorded_link_n = source_recorded_link_n ///
    three_year_additional_dco_n = source_additional_dco_n ///
    (min) three_year_source_start = source_year ///
    (max) three_year_source_end = source_year, ///
    by(mortality_definition target_year)
rename target_year dth_year
generate long three_year_resolved_n = ///
    three_year_recorded_link_n + three_year_additional_dco_n
generate double three_year_additional_fraction = ///
    three_year_additional_dco_n / three_year_resolved_n if ///
    three_year_resolved_n > 0
isid mortality_definition dth_year
save `"`three_year_estimate'"', replace

* ---------------------------------------------------------------------------
* 3. Build the final all-years fallback table for each mortality definition.
* ---------------------------------------------------------------------------
use `"`annual_source'"', clear
collapse (sum) all_year_recorded_link_n = deterministic_recorded_link_n ///
    all_year_additional_dco_n = deterministic_additional_dco_n ///
    (min) all_year_source_start = dth_year ///
    (max) all_year_source_end = dth_year, by(mortality_definition)
generate long all_year_resolved_n = ///
    all_year_recorded_link_n + all_year_additional_dco_n
generate double all_year_additional_fraction = ///
    all_year_additional_dco_n / all_year_resolved_n if all_year_resolved_n > 0
isid mortality_definition
save `"`all_year_estimate'"', replace

* ---------------------------------------------------------------------------
* 4. Select one approved estimation level, calculate aggregate-only DCO
*    lower/central/upper components, and retain the selected evidence.
* ---------------------------------------------------------------------------
use `"`annual_source'"', clear
merge 1:1 mortality_definition dth_year using `"`three_year_estimate'"', ///
    keep(master match) gen(__three_year_merge)
assert __three_year_merge == 3
drop __three_year_merge
merge m:1 mortality_definition using `"`all_year_estimate'"', ///
    keep(master match) gen(__all_year_merge)
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

order mortality_definition dth_year candidate_n deterministic_recorded_link_n ///
    deterministic_additional_dco_n unresolved_candidate_n resolved_n ///
    estimation_level selected_source_start selected_source_end ///
    selected_resolved_n selected_additional_dco_n selected_additional_fraction ///
    estimated_unresolved_dco_n dco_lower_component_n ///
    dco_central_component_n dco_upper_component_n ///
    annual_additional_fraction three_year_resolved_n ///
    three_year_additional_fraction all_year_resolved_n ///
    all_year_additional_fraction
sort mortality_definition dth_year

label data "BNR private annual aggregate unresolved-linkage estimation"
label variable mortality_definition "Mortality definition for aggregate candidate subset"
label variable estimation_level "Selected annual, three-year or all-years estimation level"
label variable selected_additional_fraction "p = deterministic additional DCOs / resolved candidates"
label variable estimated_unresolved_dco_n "Aggregate estimated DCOs among unresolved candidates"
label variable dco_lower_component_n "DCO component lower: deterministic additional DCOs"
label variable dco_central_component_n "DCO component central: deterministic plus estimated unresolved"
label variable dco_upper_component_n "DCO component upper: deterministic additional plus all unresolved"

save `"`results_output'"', replace

* ---------------------------------------------------------------------------
* 5. Aggregate QA and the required Primary/Inclusive central-component
*    invariant. The input candidate-level diagnostic remains private.
* ---------------------------------------------------------------------------
tempname qa_handle
postfile `qa_handle' str72 check double value str190 detail using `qa_dta', replace

foreach definition in primary inclusive {
    quietly summarize candidate_n if mortality_definition == "`definition'", meanonly
    local candidate_total = r(sum)
    post `qa_handle' ("`definition': candidate records") (`candidate_total') ///
        ("Candidate subset used for this mortality definition")

    quietly summarize deterministic_recorded_link_n if ///
        mortality_definition == "`definition'", meanonly
    local recorded_total = r(sum)
    post `qa_handle' ("`definition': deterministic recorded links") (`recorded_total') ///
        ("Resolved candidates with a Heart/Stroke event 0--27 days before death")

    quietly summarize deterministic_additional_dco_n if ///
        mortality_definition == "`definition'", meanonly
    local additional_total = r(sum)
    post `qa_handle' ("`definition': deterministic additional DCOs") (`additional_total') ///
        ("Resolved candidates with no same-person 0--27-day event")

    quietly summarize unresolved_candidate_n if ///
        mortality_definition == "`definition'", meanonly
    local unresolved_total = r(sum)
    post `qa_handle' ("`definition': unresolved candidates") (`unresolved_total') ///
        ("Not assigned an individual estimated-DCO label")

    quietly summarize estimated_unresolved_dco_n if ///
        mortality_definition == "`definition'", meanonly
    local estimated_total = r(sum)
    post `qa_handle' ("`definition': estimated unresolved DCOs") (`estimated_total') ///
        ("Sum of aggregate central estimates; may be fractional")
}

foreach level in annual three_year all_years insufficient_resolved {
    quietly count if estimation_level == "`level'"
    local level_cells = r(N)
    post `qa_handle' ("Annual cells using `level'") (`level_cells') ///
        ("Cells selected by the approved resolved-count fallback hierarchy")
}

preserve
    keep if mortality_definition == "primary"
    keep dth_year dco_central_component_n
    rename dco_central_component_n primary_central_component_n
    save `"`primary_estimate'"', replace
restore

preserve
    keep if mortality_definition == "inclusive"
    keep dth_year dco_central_component_n
    rename dco_central_component_n inclusive_central_component_n
    merge 1:1 dth_year using `"`primary_estimate'"', keep(master match) ///
        gen(__definition_merge)
    quietly count if __definition_merge == 3 & ///
        inclusive_central_component_n < primary_central_component_n
    local invariant_failures = r(N)
restore

post `qa_handle' ("Primary/Inclusive central-component invariant failures") ///
    (`invariant_failures') ///
    ("Inclusive aggregate DCO component must not be below Primary in the same year")
assert `invariant_failures' == 0

postclose `qa_handle'

use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace

use `"`results_output'"', clear
quietly count if estimation_level == "insufficient_resolved"
local insufficient_cells = r(N)
quietly count
local annual_cells = r(N)

display as result "Aggregate unresolved-linkage estimation created."
display as result "  Annual definition/year cells: `annual_cells'"
display as result "  Insufficient-resolved cells:  `insufficient_cells'"
display as result "  Individual pending records:   Not reclassified"

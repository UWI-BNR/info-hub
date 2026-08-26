/*******************************************************************************

DO-FILE:     bnr_cvd_profile_subtype_concordance_core.do

VERSION:     1.0.1 (25 August 2026)

PURPOSE:     Stage 4E-a private aggregate profile for the proposed Heart and
             Stroke DCO-incidence extension.

             It profiles the relation between the mortality classifier's
             Heart/Stroke family flags and the family of any same-person
             0--27-day CVD event retained by Stage 4C. It does not relink
             people, allocate a DCO to a subtype, estimate unresolved records,
             calculate rates, modify Stage 4C/4D outputs or create public data.

INPUT:       Private Stage 4C L01--L03 candidate diagnostic DTA.

OUTPUTS:     Private aggregate concordance-cell DTA; aggregate QA CSV; and
             aggregate source-family-resolution CSV.

*******************************************************************************/

version 19

clear

set more off

args linkage_input cells_output qa_output resolution_output

if `"`linkage_input'"' == "" | `"`cells_output'"' == "" | ///
        `"`qa_output'"' == "" | `"`resolution_output'"' == "" {
    display as error "Subtype-concordance core received an incomplete file contract."
    exit 198
}

capture confirm file `"`linkage_input'"'
if _rc {
    display as error "Required Stage 4C private diagnostic was not found: `linkage_input'"
    exit 601
}

tempfile primary_rows qa_dta primary_resolution

* ---------------------------------------------------------------------------
* 1. Validate the Stage 4C diagnostic. The profile deliberately works from
*    the existing final person and episode results; no matching is repeated.
* ---------------------------------------------------------------------------
use `"`linkage_input'"', clear

isid record_id

foreach required_variable in record_id dth_year cvd_prim cvd_incl ///
        hrt_prim hrt_incl str_prim str_incl cvd_sub_p cvd_sub_i ///
        final_person_match final_episode_outcome ///
        episode_heart_count_0_27 episode_stroke_count_0_27 {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Stage 4C diagnostic is missing required variable: `required_variable'"
        exit 111
    }
}

foreach binary_variable in cvd_prim cvd_incl hrt_prim hrt_incl ///
        str_prim str_incl final_person_match {
    assert inlist(`binary_variable', 0, 1)
}

assert cvd_prim <= cvd_incl
assert hrt_prim <= hrt_incl
assert str_prim <= str_incl
assert inlist(final_episode_outcome, "recorded_event_0_27_days", ///
    "provisional_additional_dco", "pending_no_deterministic_match")

generate long __episode_heart_n = episode_heart_count_0_27
generate long __episode_stroke_n = episode_stroke_count_0_27
replace __episode_heart_n = 0 if missing(__episode_heart_n)
replace __episode_stroke_n = 0 if missing(__episode_stroke_n)
assert __episode_heart_n >= 0 & __episode_stroke_n >= 0

* ---------------------------------------------------------------------------
* 2. Create one aggregate row set for each mortality definition. The proposed
*    attribution routes are diagnostic labels only. They are not DCO decisions.
* ---------------------------------------------------------------------------
preserve
    keep if cvd_prim == 1
    generate str10 mortality_definition = "primary"
    generate str24 certificate_family = "unclassified"
    replace certificate_family = "heart_only" if hrt_prim == 1 & str_prim == 0
    replace certificate_family = "stroke_only" if hrt_prim == 0 & str_prim == 1
    replace certificate_family = "both" if hrt_prim == 1 & str_prim == 1

    generate str24 episode_family = "pending_identity"
    replace episode_family = "no_window_event" if final_person_match == 1 & ///
        final_episode_outcome == "provisional_additional_dco"
    replace episode_family = "heart_only" if final_person_match == 1 & ///
        final_episode_outcome == "recorded_event_0_27_days" & ///
        __episode_heart_n > 0 & __episode_stroke_n == 0
    replace episode_family = "stroke_only" if final_person_match == 1 & ///
        final_episode_outcome == "recorded_event_0_27_days" & ///
        __episode_heart_n == 0 & __episode_stroke_n > 0
    replace episode_family = "both" if final_person_match == 1 & ///
        final_episode_outcome == "recorded_event_0_27_days" & ///
        __episode_heart_n > 0 & __episode_stroke_n > 0
    replace episode_family = "unclassified_matched" if final_person_match == 1 & ///
        episode_family == "pending_identity"

    generate str40 attribution_route = "pending_identity"
    replace attribution_route = "heart_dco_eligible" if ///
        certificate_family == "heart_only" & episode_family == "no_window_event"
    replace attribution_route = "stroke_dco_eligible" if ///
        certificate_family == "stroke_only" & episode_family == "no_window_event"
    replace attribution_route = "mixed_dco_all_cvd_only" if ///
        certificate_family == "both" & episode_family == "no_window_event"
    replace attribution_route = "heart_recorded_concordant" if ///
        certificate_family == "heart_only" & ///
        inlist(episode_family, "heart_only", "both")
    replace attribution_route = "stroke_recorded_concordant" if ///
        certificate_family == "stroke_only" & ///
        inlist(episode_family, "stroke_only", "both")
    replace attribution_route = "linked_subtype_discordant" if ///
        (certificate_family == "heart_only" & episode_family == "stroke_only") | ///
        (certificate_family == "stroke_only" & episode_family == "heart_only")
    replace attribution_route = "mixed_certificate_recorded" if ///
        certificate_family == "both" & ///
        inlist(episode_family, "heart_only", "stroke_only", "both")
    replace attribution_route = "certificate_unclassified" if ///
        certificate_family == "unclassified"
    replace attribution_route = "matched_episode_unclassified" if ///
        final_person_match == 1 & episode_family == "unclassified_matched"

    keep record_id dth_year mortality_definition certificate_family ///
        episode_family final_episode_outcome attribution_route
    save `"`primary_rows'"', replace
restore

keep if cvd_incl == 1
generate str10 mortality_definition = "inclusive"
generate str24 certificate_family = "unclassified"
replace certificate_family = "heart_only" if hrt_incl == 1 & str_incl == 0
replace certificate_family = "stroke_only" if hrt_incl == 0 & str_incl == 1
replace certificate_family = "both" if hrt_incl == 1 & str_incl == 1

generate str24 episode_family = "pending_identity"
replace episode_family = "no_window_event" if final_person_match == 1 & ///
    final_episode_outcome == "provisional_additional_dco"
replace episode_family = "heart_only" if final_person_match == 1 & ///
    final_episode_outcome == "recorded_event_0_27_days" & ///
    __episode_heart_n > 0 & __episode_stroke_n == 0
replace episode_family = "stroke_only" if final_person_match == 1 & ///
    final_episode_outcome == "recorded_event_0_27_days" & ///
    __episode_heart_n == 0 & __episode_stroke_n > 0
replace episode_family = "both" if final_person_match == 1 & ///
    final_episode_outcome == "recorded_event_0_27_days" & ///
    __episode_heart_n > 0 & __episode_stroke_n > 0
replace episode_family = "unclassified_matched" if final_person_match == 1 & ///
    episode_family == "pending_identity"

generate str40 attribution_route = "pending_identity"
replace attribution_route = "heart_dco_eligible" if ///
    certificate_family == "heart_only" & episode_family == "no_window_event"
replace attribution_route = "stroke_dco_eligible" if ///
    certificate_family == "stroke_only" & episode_family == "no_window_event"
replace attribution_route = "mixed_dco_all_cvd_only" if ///
    certificate_family == "both" & episode_family == "no_window_event"
replace attribution_route = "heart_recorded_concordant" if ///
    certificate_family == "heart_only" & ///
    inlist(episode_family, "heart_only", "both")
replace attribution_route = "stroke_recorded_concordant" if ///
    certificate_family == "stroke_only" & ///
    inlist(episode_family, "stroke_only", "both")
replace attribution_route = "linked_subtype_discordant" if ///
    (certificate_family == "heart_only" & episode_family == "stroke_only") | ///
    (certificate_family == "stroke_only" & episode_family == "heart_only")
replace attribution_route = "mixed_certificate_recorded" if ///
    certificate_family == "both" & ///
    inlist(episode_family, "heart_only", "stroke_only", "both")
replace attribution_route = "certificate_unclassified" if ///
    certificate_family == "unclassified"
replace attribution_route = "matched_episode_unclassified" if ///
    final_person_match == 1 & episode_family == "unclassified_matched"

keep record_id dth_year mortality_definition certificate_family ///
    episode_family final_episode_outcome attribution_route
append using `"`primary_rows'"'

generate long candidate_n = 1
collapse (sum) candidate_n, by(mortality_definition dth_year ///
    certificate_family episode_family final_episode_outcome attribution_route)
isid mortality_definition dth_year certificate_family episode_family ///
    final_episode_outcome attribution_route
sort mortality_definition dth_year certificate_family episode_family

label data "BNR private CVD subtype family-concordance profile"
label variable certificate_family "Heart/Stroke mortality-family classification"
label variable episode_family "Family of linked 0-27-day CVD episode"
label variable attribution_route "Proposed subtype-attribution diagnostic route"
label variable candidate_n "Number of mortality candidates in aggregate cell"
save `"`cells_output'"', replace

* ---------------------------------------------------------------------------
* 3. Create the aggregate source-family-resolution crosswalk. This lets the
*    team inspect the classifier's cvd_sub values before any tie-break rule is
*    adopted for certificates carrying both broad family flags.
* ---------------------------------------------------------------------------
use `"`linkage_input'"', clear

preserve
    keep if cvd_prim == 1
    generate str10 mortality_definition = "primary"
    generate str24 certificate_family = "unclassified"
    replace certificate_family = "heart_only" if hrt_prim == 1 & str_prim == 0
    replace certificate_family = "stroke_only" if hrt_prim == 0 & str_prim == 1
    replace certificate_family = "both" if hrt_prim == 1 & str_prim == 1
    generate str20 subtype_source_value = string(cvd_sub_p, "%12.0g")
    replace subtype_source_value = "<missing>" if missing(cvd_sub_p)
    decode cvd_sub_p, generate(subtype_source_label)
    replace subtype_source_label = "<missing>" if ///
        strtrim(subtype_source_label) == ""
    contract mortality_definition subtype_source_value subtype_source_label certificate_family, ///
        freq(candidate_n)
    save `"`primary_resolution'"', replace
restore

keep if cvd_incl == 1
generate str10 mortality_definition = "inclusive"
generate str24 certificate_family = "unclassified"
replace certificate_family = "heart_only" if hrt_incl == 1 & str_incl == 0
replace certificate_family = "stroke_only" if hrt_incl == 0 & str_incl == 1
replace certificate_family = "both" if hrt_incl == 1 & str_incl == 1
generate str20 subtype_source_value = string(cvd_sub_i, "%12.0g")
replace subtype_source_value = "<missing>" if missing(cvd_sub_i)
decode cvd_sub_i, generate(subtype_source_label)
replace subtype_source_label = "<missing>" if strtrim(subtype_source_label) == ""
contract mortality_definition subtype_source_value subtype_source_label certificate_family, ///
    freq(candidate_n)
append using `"`primary_resolution'"'
sort mortality_definition certificate_family subtype_source_value
order mortality_definition certificate_family subtype_source_value ///
    subtype_source_label candidate_n
export delimited using `"`resolution_output'"', replace

* ---------------------------------------------------------------------------
* 4. Compact aggregate QA for review. The detailed concordance cells remain
*    private and support the later subtype-estimator design.
* ---------------------------------------------------------------------------
use `"`cells_output'"', clear

tempname qa_handle
postfile `qa_handle' str72 check double value str190 detail using `qa_dta', replace

foreach definition in primary inclusive {
    quietly summarize candidate_n if mortality_definition == "`definition'", meanonly
    local candidate_total = r(sum)
    post `qa_handle' ("`definition': candidate records") (`candidate_total') ///
        ("Candidate records in the completed Stage 4C linkage diagnostic")

    foreach family in heart_only stroke_only both unclassified {
        quietly summarize candidate_n if mortality_definition == "`definition'" & ///
            certificate_family == "`family'", meanonly
        local family_total = r(sum)
        post `qa_handle' ("`definition': certificate `family'") (`family_total') ///
            ("Mortality-family classification before subtype DCO allocation")
    }

    foreach route in heart_dco_eligible stroke_dco_eligible ///
            mixed_dco_all_cvd_only heart_recorded_concordant ///
            stroke_recorded_concordant linked_subtype_discordant ///
            mixed_certificate_recorded pending_identity {
        quietly summarize candidate_n if mortality_definition == "`definition'" & ///
            attribution_route == "`route'", meanonly
        local route_total = r(sum)
        post `qa_handle' ("`definition': `route'") (`route_total') ///
            ("Private subtype-attribution diagnostic route; not a final DCO decision")
    }
}

postclose `qa_handle'

use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace

use `"`cells_output'"', clear
quietly count
local concordance_cells = r(N)
display as result "Private subtype family-concordance profile created."
display as result "  Aggregate concordance cells: `concordance_cells'"
display as result "  Individual linkage records:  Not exported"

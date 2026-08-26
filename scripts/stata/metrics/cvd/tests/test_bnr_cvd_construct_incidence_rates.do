/*******************************************************************************
DO-FILE:     test_bnr_cvd_construct_incidence_rates.do
VERSION:     1.0.7 (26 August 2026)
RELEASE:     Stage 3 rate-construction integrated release 1.0.7
PURPOSE:     Synthetic tests for private annual CVD rate construction and QA.
*******************************************************************************/
version 19
clear all
set more off

tempfile events linkage joint population standard rates components qa_output
tempname event_handle linkage_handle joint_handle population_handle standard_handle

* Minimal hospital-event source: three events per year, with one unknown sex.
postfile `event_handle' str18 eid int doe byte etype dco sex int agey using `"`events'"', replace
foreach y in 2010 2011 2012 {
    post `event_handle' ("E`y'01") (mdy(1, 1, `y')) (1) (0) (1) (55)
    post `event_handle' ("E`y'02") (mdy(2, 1, `y')) (2) (0) (2) (65)
    post `event_handle' ("E`y'03") (mdy(3, 1, `y')) (1) (0) (99) (.)
}
postclose `event_handle'

* Four deterministic additional DCOs each year: Heart=2, Stroke=1, Mixed=1.
postfile `linkage_handle' str8 record_id int dth_year str3 mortality_age ///
    str2 mortality_agetxt byte mortality_sex_canonical cvd_prim cvd_incl ///
    hrt_prim hrt_incl str_prim str_incl final_person_match ///
    str36 final_episode_outcome long episode_heart_count_0_27 ///
    episode_stroke_count_0_27 using `"`linkage'"', replace
foreach y in 2010 2011 2012 {
    post `linkage_handle' ("D`y'01") (`y') ("55") ("6") (1) (1) (1) (1) (1) (0) (0) (1) ("provisional_additional_dco") (0) (0)
    post `linkage_handle' ("D`y'02") (`y') ("65") ("6") (2) (1) (1) (1) (1) (0) (0) (1) ("provisional_additional_dco") (0) (0)
    post `linkage_handle' ("D`y'03") (`y') ("75") ("6") (1) (1) (1) (0) (0) (1) (1) (1) ("provisional_additional_dco") (0) (0)
    post `linkage_handle' ("D`y'04") (`y') ("85") ("6") (2) (1) (1) (1) (1) (1) (1) (1) ("provisional_additional_dco") (0) (0)
}
postclose `linkage_handle'

postfile `joint_handle' str10 mortality_definition int dth_year str24 category ///
    str24 estimation_level double joint_lower_component_n ///
    joint_central_component_n joint_upper_component_n selected_total_A ///
    using `"`joint'"', replace
foreach d in primary inclusive {
    post `joint_handle' ("`d'") (2010) ("heart") ("annual") (2) (3) (4) (4)
    post `joint_handle' ("`d'") (2010) ("stroke") ("annual") (1) (2) (3) (4)
    post `joint_handle' ("`d'") (2010) ("mixed_unallocated") ("annual") (1) (1) (1) (4)
    post `joint_handle' ("`d'") (2011) ("heart") ("annual") (2) (2.5) (3) (4)
    post `joint_handle' ("`d'") (2011) ("stroke") ("annual") (1) (1.5) (2) (4)
    post `joint_handle' ("`d'") (2011) ("mixed_unallocated") ("annual") (1) (1) (1) (4)
    post `joint_handle' ("`d'") (2012) ("heart") ("annual") (2) (3) (4) (4)
    post `joint_handle' ("`d'") (2012) ("stroke") ("annual") (1) (2) (3) (4)
    post `joint_handle' ("`d'") (2012) ("mixed_unallocated") ("annual") (1) (1) (1) (4)
}
postclose `joint_handle'

postfile `population_handle' int year str10 sex str16 age_group double population using `"`population'"', replace
foreach y in 2010 2011 {
    foreach s in all female male {
        forvalues a = 0(5)95 {
            local b = `a' + 4
            local pop = 10000
            if "`s'" == "all" local pop = 20000
            post `population_handle' (`y') ("`s'") ("age_`a'_`b'") (`pop')
        }
        local pop100 = 10000
        if "`s'" == "all" local pop100 = 20000
        post `population_handle' (`y') ("`s'") ("age_100_plus") (`pop100')
    }
}
postclose `population_handle'

postfile `standard_handle' str16 age_group double standard_weight using `"`standard'"', replace
forvalues a = 0(5)95 {
    local b = `a' + 4
    post `standard_handle' ("age_`a'_`b'") (1/21)
}
post `standard_handle' ("age_100_plus") (1/21)
postclose `standard_handle'

do "$BNR_STATA/metrics/cvd/bnr_cvd_construct_incidence_rates_core.do" `"`events'"' `"`linkage'"' `"`joint'"' `"`population'"' `"`standard'"' `"`rates'"' `"`components'"' `"`qa_output'"' 2012 04

use `"`components'"', clear
assert _N == 1408
quietly count if sex == "unknown"
assert r(N) > 0
quietly summarize dco_central_component_n if mortality_definition == "primary" & dth_year == 2010 & sex == "all" & category == "all_cvd", meanonly
assert abs(r(sum) - 6) < 0.000001
quietly summarize dco_upper_component_n if mortality_definition == "primary" & dth_year == 2010 & sex == "all" & category == "all_cvd", meanonly
assert abs(r(sum) - 8) < 0.000001
quietly summarize dco_central_component_n if mortality_definition == "primary" & dth_year == 2010 & sex == "all" & inlist(category, "heart", "stroke", "mixed_unallocated"), meanonly
assert abs(r(sum) - 6) < 0.000001

use `"`rates'"', clear
assert _N == 108
assert inrange(dth_year, 2010, 2011)
assert release_id == "cvd_2012_04"
assert schema_version == "bnr_cvd_public_metric_v2"
assert status_flag == "final"
assert inlist(sex, "all", "female", "male")
assert inlist(event_type, "all_cvd", "heart", "stroke")
assert inlist(age_group, "all", "age_standardised")
assert ascertainment_scope == "hospital_only" if mortality_definition == "not_applicable"
assert ascertainment_scope == "hospital_plus_dco" if inlist(mortality_definition, "primary", "inclusive")
assert linkage_lower_value <= value & value <= linkage_upper_value if ascertainment_scope == "hospital_plus_dco"
assert missing(linkage_lower_value, linkage_upper_value) if ascertainment_scope == "hospital_only"
assert !missing(numerator) & !missing(denominator) if age_group == "all"
assert missing(numerator) & missing(denominator) if age_group == "age_standardised"

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if value != 0
assert r(N) == 0
noisily display as result "PASS: CVD private annual rate-construction synthetic tests completed."

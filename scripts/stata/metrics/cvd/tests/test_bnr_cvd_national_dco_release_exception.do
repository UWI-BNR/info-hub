/*******************************************************************************
DO-FILE: test_bnr_cvd_national_dco_release_exception.do
VERSION: 1.0.2 (29 August 2026)
PURPOSE: Synthetic test of the approved national annual DCO release exception.

SAFETY:
  Uses generated aggregate rows and tempfiles only. It does not read private
  registry data, call Step 5 approval, or call Step 6 publication.

TESTS:
  1. All / female / male and All-CVD / Heart / Stroke annual DCO aggregates
     are eligible for the approved release rule.
  2. The rule covers annual DCO counts, crude rates and age-standardised rates.
  3. DCO-only primary protection is relaxed on that lattice.
  4. A hospital-primary decision is never relaxed.
  5. Incomplete and non-approved DCO representations remain outside the rule.
  6. Unknown-sex and mixed/unallocated residuals do not structurally suppress
     approved national annual DCO aggregates.
*******************************************************************************/

version 19
clear all
set more off

if "$BNR_STATA" == "" {
    display as error "Load bnr_paths_LOCAL.do before running this synthetic test."
    exit 198
}

local component_dir "$BNR_STATA/metrics/cvd/private/expanded_disclosure"
local stage4_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage4_national_dco_exception.do"
local stage5_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage5_structural_secondary.do"

foreach required_file in stage4_path stage5_path {
    capture confirm file "``required_file''"
    if _rc exit 601
}

tempfile primary_private exception_private support_private structural_private ///
    stage4_qa stage5_qa

* ---------------------------------------------------------------------------
* Build 36 approved rows:
*   3 event families x 3 sex groups x 4 annual representations.
*
* Representations are:
*   1. Hospital + DCO count
*   2. Additional DCO count
*   3. Hospital + DCO crude rate
*   4. Hospital + DCO age-standardised rate
*
* Each begins with DCO-only primary protection so the exception has something
* real to relax. Three edge rows are added afterwards.
* ---------------------------------------------------------------------------
clear
set obs 36

generate byte stratum = ceil(_n / 4)
generate byte representation = mod(_n - 1, 4) + 1

generate str20 metric_id = "CVD-BURDEN-001"
replace metric_id = "CVD-INCIDENCE-001" if inlist(representation, 3, 4)

generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int period_year = 2020
generate byte period_complete = 1

generate str20 event_type = "all_cvd"
replace event_type = "heart" if inrange(stratum, 4, 6)
replace event_type = "stroke" if inrange(stratum, 7, 9)

generate byte sex_index = mod(stratum - 1, 3) + 1
generate str8 sex = "all"
replace sex = "female" if sex_index == 2
replace sex = "male" if sex_index == 3

generate str12 age_group = "all"
replace age_group = "age_standardised" if representation == 4

generate str24 ascertainment_scope = "hospital_plus_dco"
replace ascertainment_scope = "additional_dco" if representation == 2

generate str20 mortality_definition = "primary"
generate str45 statistic = "annual_count"
replace statistic = "annual_crude_rate" if representation == 3
replace statistic = "annual_age_standardised_rate" if representation == 4

generate double value = 103
replace value = 3 if representation == 2
replace value = 250 if representation == 3
replace value = 240 if representation == 4

generate str25 status_flag = "final"
generate byte primary_suppression = 1
generate byte related_suppression_review = 0
generate byte suppression_review = 1
generate byte stage3_hospital_primary = 0
generate byte stage3_dco_primary = 1
generate byte stage3_original_primary = 0

* Add three edge rows using the same simple variable contract.
set obs 39

* Row 37: incomplete approved-shaped count. It must stay outside the exception.
replace stratum = 1 in 37
replace representation = 1 in 37
replace metric_id = "CVD-BURDEN-001" in 37
replace release_id = "cvd_2099_01" in 37
replace period_type = "annual" in 37
replace period_year = 2020 in 37
replace period_complete = 0 in 37
replace event_type = "all_cvd" in 37
replace sex_index = 3 in 37
replace sex = "male" in 37
replace age_group = "all" in 37
replace ascertainment_scope = "hospital_plus_dco" in 37
replace mortality_definition = "primary" in 37
replace statistic = "annual_count" in 37
replace value = 103 in 37
replace status_flag = "incomplete" in 37
replace primary_suppression = 1 in 37
replace related_suppression_review = 0 in 37
replace suppression_review = 1 in 37
replace stage3_hospital_primary = 0 in 37
replace stage3_dco_primary = 1 in 37
replace stage3_original_primary = 0 in 37

* Row 38: complete approved count but its hospital component is primary.
replace stratum = 1 in 38
replace representation = 1 in 38
replace metric_id = "CVD-BURDEN-001" in 38
replace release_id = "cvd_2099_01" in 38
replace period_type = "annual" in 38
replace period_year = 2020 in 38
replace period_complete = 1 in 38
replace event_type = "all_cvd" in 38
replace sex_index = 3 in 38
replace sex = "male" in 38
replace age_group = "all" in 38
replace ascertainment_scope = "hospital_plus_dco" in 38
replace mortality_definition = "primary" in 38
replace statistic = "annual_count" in 38
replace value = 103 in 38
replace status_flag = "final" in 38
replace primary_suppression = 1 in 38
replace related_suppression_review = 0 in 38
replace suppression_review = 1 in 38
replace stage3_hospital_primary = 1 in 38
replace stage3_dco_primary = 1 in 38
replace stage3_original_primary = 0 in 38

* Row 39: additional-DCO rate. This representation is not in the public rule.
replace stratum = 1 in 39
replace representation = 3 in 39
replace metric_id = "CVD-INCIDENCE-001" in 39
replace release_id = "cvd_2099_01" in 39
replace period_type = "annual" in 39
replace period_year = 2020 in 39
replace period_complete = 1 in 39
replace event_type = "all_cvd" in 39
replace sex_index = 3 in 39
replace sex = "male" in 39
replace age_group = "all" in 39
replace ascertainment_scope = "additional_dco" in 39
replace mortality_definition = "primary" in 39
replace statistic = "annual_crude_rate" in 39
replace value = 7 in 39
replace status_flag = "final" in 39
replace primary_suppression = 1 in 39
replace related_suppression_review = 0 in 39
replace suppression_review = 1 in 39
replace stage3_hospital_primary = 0 in 39
replace stage3_dco_primary = 1 in 39
replace stage3_original_primary = 0 in 39

drop stratum representation sex_index
save "`primary_private'", replace

do "`stage4_path'" "`primary_private'" "`exception_private'" ///
    "`stage4_qa'" "cvd_2099_01"

use "`stage4_qa'", clear
quietly count if result != "PASS"
assert r(N) == 0

use "`exception_private'", clear

* 36 normal approved rows plus the hospital-primary edge row are eligible.
quietly count if national_dco_release_exception == 1
assert r(N) == 37

* The 36 rows with DCO-only protection are relaxed.
quietly count if national_dco_release_exception == 1 & ///
    stage3_hospital_primary == 0 & stage4_dco_primary_relaxed == 1 & ///
    primary_suppression == 0
assert r(N) == 36

* Both rate representations are included across all event/sex combinations.
quietly count if national_dco_release_exception == 1 & ///
    metric_id == "CVD-INCIDENCE-001" & statistic == "annual_crude_rate"
assert r(N) == 9
quietly count if national_dco_release_exception == 1 & ///
    metric_id == "CVD-INCIDENCE-001" & ///
    statistic == "annual_age_standardised_rate"
assert r(N) == 9

* Incomplete and non-approved representations remain outside the exception.
quietly count if period_complete == 0 & ///
    national_dco_release_exception == 0 & primary_suppression == 1
assert r(N) == 1
quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "additional_dco" & ///
    national_dco_release_exception == 0 & primary_suppression == 1
assert r(N) == 1

* Hospital primary protection is never cleared.
quietly count if period_complete == 1 & stage3_hospital_primary == 1 & ///
    national_dco_release_exception == 1 & ///
    stage4_dco_primary_relaxed == 0 & primary_suppression == 1
assert r(N) == 1

* ---------------------------------------------------------------------------
* Build private residual support that would trigger the OLD structural rules:
* unknown-sex support for all three event families and mixed subtype support
* for all/female/male.
* ---------------------------------------------------------------------------
clear
set obs 6
generate str20 mortality_definition = "primary"
generate int period_year = 2020
generate str20 event_type = ""
generate str8 sex = ""
generate str12 age_group = "all"
generate double dco_lower_component_n = 1
generate double dco_central_component_n = 1.5
generate double dco_upper_component_n = 2

replace event_type = "all_cvd" in 1
replace event_type = "heart" in 2
replace event_type = "stroke" in 3
replace sex = "unknown" in 1/3

replace event_type = "mixed_unallocated" in 4/6
replace sex = "all" in 4
replace sex = "female" in 5
replace sex = "male" in 6

save "`support_private'", replace

do "`stage5_path'" "`exception_private'" "`support_private'" ///
    "`structural_private'" "`stage5_qa'" "cvd_2099_01"

use "`stage5_qa'", clear
quietly count if result != "PASS"
assert r(N) == 0

use "`structural_private'", clear

* All 36 relaxable approved rows remain free of structural secondary protection.
quietly count if national_dco_release_exception == 1 & ///
    stage3_hospital_primary == 0 & stage5_structural_secondary != 0
assert r(N) == 0

* The private audit shows that the exception prevented 20 old-style structural
* companion suppressions: 12 male + 12 Stroke - 4 overlapping male-Stroke.
quietly count if stage5_structural_exception == 1
assert r(N) == 20

* Rows that were not relaxed remain primary protected.
quietly count if period_complete == 0 & primary_suppression == 1
assert r(N) == 1
quietly count if stage3_hospital_primary == 1 & primary_suppression == 1
assert r(N) == 1
quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "additional_dco" & primary_suppression == 1
assert r(N) == 1

display as result "PASS: national annual DCO release-exception synthetic test completed."

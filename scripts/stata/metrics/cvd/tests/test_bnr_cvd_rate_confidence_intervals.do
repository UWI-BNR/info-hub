/*******************************************************************************
DO-FILE: test_bnr_cvd_rate_confidence_intervals.do
VERSION: 1.0.1 (28 August 2026)
PURPOSE: Synthetic test for the bounded statistical-CI extension.

SAFETY:
  Uses only generated aggregate data and tempfiles. It does not call Step 5,
  approve a release, or publish any output.
*******************************************************************************/

version 19
clear all
set more off

if "$BNR_STATA" == "" {
    display as error "Load bnr_paths_LOCAL.do before running this test."
    exit 198
}

local ci_helper "$BNR_STATA/metrics/cvd/bnr_cvd_add_rate_confidence_intervals.do"
capture confirm file "`ci_helper'"
assert _rc == 0

tempfile events components population standard rates qa
tempname event_handle component_handle population_handle standard_handle

* ---------------------------------------------------------------------------
* 1. Two observed hospital events in different age groups.
* ---------------------------------------------------------------------------
postfile `event_handle' str12 eid int doe byte etype dco sex int agey ///
    using "`events'", replace
post `event_handle' ("E1") (mdy(1,1,2010)) (1) (0) (1) (55)
post `event_handle' ("E2") (mdy(2,1,2010)) (2) (0) (2) (65)
postclose `event_handle'

* ---------------------------------------------------------------------------
* 2. Public age-specific DCO central components for Primary and Inclusive.
*    Primary adds 1.0 DCO in total; Inclusive adds 2.0.
* ---------------------------------------------------------------------------
postfile `component_handle' str10 mortality_definition int dth_year ///
    str20 category str8 sex str16 age_group double dco_central_component_n ///
    using "`components'", replace

foreach definition in primary inclusive {
    forvalues lower = 0(5)95 {
        local upper = `lower' + 4
        local dco = 0
        if "`definition'" == "primary" & inlist(`lower',55,65) local dco = 0.5
        if "`definition'" == "inclusive" & inlist(`lower',55,65) local dco = 1
        post `component_handle' ("`definition'") (2010) ("all_cvd") ///
            ("all") ("age_`lower'_`upper'") (`dco')
    }
    post `component_handle' ("`definition'") (2010) ("all_cvd") ///
        ("all") ("age_100_plus") (0)
}
postclose `component_handle'

* ---------------------------------------------------------------------------
* 3. Population and WHO-standard test assets.
*    Unequal weights/populations make the ASR test genuinely standardised.
* ---------------------------------------------------------------------------
postfile `population_handle' int year str8 sex str16 age_group double population ///
    using "`population'", replace

forvalues lower = 0(5)95 {
    local upper = `lower' + 4
    local pop = 10000
    if `lower' == 55 local pop = 5000
    post `population_handle' (2010) ("all") ("age_`lower'_`upper'") (`pop')
}
post `population_handle' (2010) ("all") ("age_100_plus") (10000)
postclose `population_handle'

postfile `standard_handle' str16 age_group double standard_weight ///
    using "`standard'", replace

local other_weight = 0.85 / 19
forvalues lower = 0(5)95 {
    local upper = `lower' + 4
    local weight = `other_weight'
    if `lower' == 55 local weight = 0.10
    if `lower' == 65 local weight = 0.05
    post `standard_handle' ("age_`lower'_`upper'") (`weight')
}
post `standard_handle' ("age_100_plus") (`other_weight')
postclose `standard_handle'

* 20 ordinary five-year groups plus 100+ = 21.
use "`standard'", clear
quietly summarize standard_weight, meanonly
assert abs(r(sum) - 1) < 0.000000001

* ---------------------------------------------------------------------------
* 4. Minimal private public-shaped rate candidate.
* ---------------------------------------------------------------------------
local denominator_all = 205000
local hospital_crude = 100000 * 2 / `denominator_all'
local primary_crude = 100000 * 3 / `denominator_all'
local inclusive_crude = 100000 * 4 / `denominator_all'

* ASR point estimates from the two occupied age groups.
* 55-59 weight=0.10, population=5000 => coefficient 2.0
* 65-69 weight=0.05, population=10000 => coefficient 0.5
local hospital_asr = 2.0 + 0.5
local primary_asr = 2.0 * 1.5 + 0.5 * 1.5
local inclusive_asr = 2.0 * 2 + 0.5 * 2

clear
set obs 7
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str12 release_id = "cvd_2010_12"
generate str24 metric_id = "CVD-INCIDENCE-001"
replace metric_id = "CVD-BURDEN-001" in 7
generate str12 period_type = "annual"
generate int dth_year = 2010
generate byte period_month = .
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str20 age_group = "all"
replace age_group = "age_standardised" in 2
replace age_group = "age_standardised" in 4
replace age_group = "age_standardised" in 6

generate str24 ascertainment_scope = "hospital_only"
replace ascertainment_scope = "hospital_plus_dco" in 3/6
replace ascertainment_scope = "additional_dco" in 7

generate str20 mortality_definition = "not_applicable"
replace mortality_definition = "primary" in 3/4
replace mortality_definition = "inclusive" in 5/6
replace mortality_definition = "primary" in 7

generate str12 estimate_basis = "observed"
replace estimate_basis = "estimated" in 3/7

generate str18 unit = "rate_per_100000"
replace unit = "count" in 7

generate double value = .
replace value = `hospital_crude' in 1
replace value = `hospital_asr' in 2
replace value = `primary_crude' in 3
replace value = `primary_asr' in 4
replace value = `inclusive_crude' in 5
replace value = `inclusive_asr' in 6
replace value = 1 in 7

generate double numerator = .
replace numerator = 2 in 1
replace numerator = 3 in 3
replace numerator = 4 in 5
replace numerator = 1 in 7

generate double denominator = .
replace denominator = `denominator_all' in 1
replace denominator = `denominator_all' in 3
replace denominator = `denominator_all' in 5

generate double linkage_lower_value = .
generate double linkage_upper_value = .
replace linkage_lower_value = value * 0.9 in 3/6
replace linkage_upper_value = value * 1.1 in 3/6
replace linkage_lower_value = 0.5 in 7
replace linkage_upper_value = 1.5 in 7

generate byte period_complete = 1
generate str20 status_flag = "final"

save "`rates'", replace

* Existing core QA is deliberately tiny. The CI helper appends its checks.
clear
set obs 1
generate str96 check = "Synthetic core QA"
generate double value = 0
generate str220 detail = "Pre-existing rate-core check."
export delimited using "`qa'", replace

* ---------------------------------------------------------------------------
* 5. Run the bounded CI helper.
* ---------------------------------------------------------------------------
do "`ci_helper'" "`events'" "`components'" "`population'" "`standard'" ///
    "`rates'" "`qa'" 2010 12

use "`rates'", clear

* Every rate gets a 95% CI; the count row does not.
assert !missing(ci_lower_value, ci_upper_value) ///
    if metric_id == "CVD-INCIDENCE-001"
assert ci_level == 95 if metric_id == "CVD-INCIDENCE-001"
assert missing(ci_lower_value) & missing(ci_upper_value) & ///
    missing(ci_level) if metric_id == "CVD-BURDEN-001"
assert ci_method == "" if metric_id == "CVD-BURDEN-001"

* Frozen method labels. Use row identities rather than observation order,
* because merge operations are free to reorder the synthetic candidate.
assert ci_method == "poisson_exact_garwood" ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_only" & age_group == "all"

assert ci_method == "fay_feuer_gamma" ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_only" & age_group == "age_standardised"

assert ci_method == "conditional_gamma" ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_plus_dco" & age_group == "all"

assert ci_method == "conditional_fay_feuer_gamma" ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_plus_dco" & ///
    age_group == "age_standardised"

* All numerical intervals contain the central estimate.
assert ci_lower_value >= 0 if metric_id == "CVD-INCIDENCE-001"
assert ci_lower_value <= value if metric_id == "CVD-INCIDENCE-001"
assert value <= ci_upper_value if metric_id == "CVD-INCIDENCE-001"

* Exact Poisson / Garwood check for the observed crude rate.
local expected_lower = ///
    0.5 * (100000 / `denominator_all') * invchi2(4, 0.025)
local expected_upper = ///
    0.5 * (100000 / `denominator_all') * invchi2(6, 0.975)
assert abs(ci_lower_value - `expected_lower') < 0.0000001 ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_only" & age_group == "all"
assert abs(ci_upper_value - `expected_upper') < 0.0000001 ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_only" & age_group == "all"

* Fay-Feuer check for the observed ASR.
local asr_point = `hospital_asr'
local asr_variance = (2.0^2) + (0.5^2)
local max_weight = 2.0
local ff_lower = 0.5 * (`asr_variance' / `asr_point') * ///
    invchi2(2 * (`asr_point'^2) / `asr_variance', 0.025)
local upper_point = `asr_point' + `max_weight'
local upper_variance = `asr_variance' + (`max_weight'^2)
local ff_upper = 0.5 * (`upper_variance' / `upper_point') * ///
    invchi2(2 * (`upper_point'^2) / `upper_variance', 0.975)

assert abs(ci_lower_value - `ff_lower') < 0.0000001 ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_only" & ///
    age_group == "age_standardised"
assert abs(ci_upper_value - `ff_upper') < 0.0000001 ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_only" & ///
    age_group == "age_standardised"

* Existing linkage limits survive unchanged for both Primary and Inclusive.
assert abs(linkage_lower_value - value * 0.9) < 0.0000001 ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_plus_dco"
assert abs(linkage_upper_value - value * 1.1) < 0.0000001 ///
    if metric_id == "CVD-INCIDENCE-001" & ///
    ascertainment_scope == "hospital_plus_dco"

import delimited using "`qa'", varnames(1) clear
quietly count if value != 0
assert r(N) == 0

display as result "PASS: CVD statistical-CI synthetic test completed."

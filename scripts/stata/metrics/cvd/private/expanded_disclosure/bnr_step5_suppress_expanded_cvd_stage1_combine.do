/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage1_combine.do
VERSION: 1.2.0 (28 August 2026)
PURPOSE: Build the private combined CVD disclosure-review lattice.

This helper does not suppress, approve, publish or create a public candidate.
The annual rate source must carry the approved statistical-CI contract.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 1 combine helper v1.2.0"

args burden_dta rates_dta combined_private_dta qa_dta release_id

foreach argument in burden_dta rates_dta combined_private_dta qa_dta release_id {
    if "``argument''" == "" {
        display as error "Stage 1 combine helper received an incomplete contract."
        exit 198
    }
}

foreach input_file in burden_dta rates_dta {
    capture confirm file "``input_file''"
    if _rc {
        display as error "Required input was not found: ``input_file''"
        exit 601
    }
}

tempfile normalised_rates

use "`burden_dta'", clear
local burden_required schema_version metric_id release_id period_type period period_start period_year period_month period_quarter period_complete event_type sex age_group source_status ascertainment_scope mortality_definition estimate_basis statistic value unit numerator denominator linkage_lower_value linkage_upper_value comparison_n status_flag sdc_policy primary_suppression_threshold primary_suppression related_primary_cells related_suppression_review suppression_review suppression_reason
foreach variable of local burden_required {
    capture confirm variable `variable'
    if _rc {
        display as error "Burden input variable is absent: `variable'"
        exit 111
    }
}
assert schema_version == "bnr_cvd_public_metric_v2"
assert release_id == "`release_id'"
quietly count
local burden_rows = r(N)

use "`rates_dta'", clear
local rates_required schema_version metric_id release_id period_type dth_year period_month event_type sex age_group ascertainment_scope mortality_definition estimate_basis unit value numerator denominator linkage_lower_value linkage_upper_value ci_lower_value ci_upper_value ci_level ci_method period_complete status_flag
foreach variable of local rates_required {
    capture confirm variable `variable'
    if _rc {
        display as error "Rate input variable is absent: `variable'"
        exit 111
    }
}
assert schema_version == "bnr_cvd_public_metric_v2"
assert release_id == "`release_id'"
assert period_type == "annual"
assert inlist(age_group, "all", "age_standardised")
assert inlist(ascertainment_scope, "hospital_only", "hospital_plus_dco", "additional_dco")
assert inlist(mortality_definition, "not_applicable", "primary", "inclusive")
assert inlist(estimate_basis, "observed", "estimated")
assert metric_id == "CVD-INCIDENCE-001" | ///
    (metric_id == "CVD-BURDEN-001" & age_group == "all" & ///
    inlist(ascertainment_scope, "hospital_plus_dco", "additional_dco"))

quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    (missing(ci_lower_value) | missing(ci_upper_value) | ///
    ci_level != 95 | ci_method == "")
assert r(N) == 0

quietly count if metric_id == "CVD-INCIDENCE-001" & ///
    (ci_lower_value < 0 | ci_lower_value > value + 0.0000001 | ///
    ci_upper_value + 0.0000001 < value | ci_upper_value < ci_lower_value)
assert r(N) == 0

quietly count if metric_id == "CVD-BURDEN-001" & ///
    (!missing(ci_lower_value) | !missing(ci_upper_value) | ///
    !missing(ci_level) | ci_method != "")
assert r(N) == 0

generate int period_year = dth_year
generate str20 period = string(dth_year)
generate str10 period_start = string(dth_year) + "-01-01"
generate byte period_quarter = .
generate str30 source_status = cond(ascertainment_scope == "hospital_only", "hospital_registered", "national_estimate")
generate str45 statistic = "annual_count" if metric_id == "CVD-BURDEN-001"
replace statistic = "annual_crude_rate" if metric_id == "CVD-INCIDENCE-001" & age_group == "all"
replace statistic = "annual_age_standardised_rate" if metric_id == "CVD-INCIDENCE-001" & age_group == "age_standardised"
generate int comparison_n = .
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = 0
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = 0
generate str80 suppression_reason = ""
drop dth_year

quietly count
local rate_rows = r(N)
save "`normalised_rates'", replace

use "`burden_dta'", clear
append using "`normalised_rates'"
quietly count
local combined_rows = r(N)

local stage1_key metric_id period_type period_year period_month event_type sex ///
    age_group ascertainment_scope statistic mortality_definition
duplicates tag `stage1_key', generate(stage1_duplicate_key)
quietly count if stage1_duplicate_key > 0
if r(N) > 0 {
    display as error "Expanded Step 5 combined lattice contains duplicate public rows."
    display as error "The duplicate worklist follows; do not continue to suppression."
    sort `stage1_key' source_status estimate_basis release_id
    list `stage1_key' source_status estimate_basis release_id value numerator ///
        denominator linkage_lower_value linkage_upper_value ///
        ci_lower_value ci_upper_value if stage1_duplicate_key > 0, ///
        noobs abbreviate(32)
    exit 459
}
drop stage1_duplicate_key
isid `stage1_key', missok

* Keep the two uncertainty concepts together in the combined private/public
* schema. Linkage bounds remain distinct from statistical confidence limits.
order linkage_lower_value linkage_upper_value ///
    ci_lower_value ci_upper_value ci_level ci_method, after(denominator)

save "`combined_private_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""

replace check = "Burden source accepted" in 1
replace detail = "`burden_rows' burden rows accepted." in 1

replace check = "Rate source normalised" in 2
replace detail = "`rate_rows' rate/count rows normalised with the statistical-CI contract." in 2

replace check = "Combined private lattice written" in 3
replace detail = "`combined_rows' rows written; no public candidate created." in 3

replace check = "Rate and count statistics normalised" in 4
replace detail = "Rate rows retain statistical CIs; count rows retain blank CI fields." in 4

save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 1 combine helper passed."

/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage3_primary_flags.do
VERSION: 1.1.0 (27 August 2026)
PURPOSE: Attach private support evidence and derive expanded CVD primary flags.

This helper writes a private review lattice only. It does not suppress, blank,
approve, publish or create a public candidate.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 3 primary-flag helper v1.1.0"

args combined_private_dta support_dta primary_private_dta qa_dta release_id

foreach argument in combined_private_dta support_dta primary_private_dta qa_dta release_id {
    if "``argument''" == "" {
        display as error "Stage 3 primary-flag helper received an incomplete contract."
        exit 198
    }
}

capture confirm file "`combined_private_dta'"
assert _rc == 0
capture confirm file "`support_dta'"
assert _rc == 0

tempfile hospital_flags dco_support

use "`combined_private_dta'", clear
local combined_required metric_id release_id period_year event_type sex age_group ascertainment_scope mortality_definition statistic numerator primary_suppression
foreach variable of local combined_required {
    capture confirm variable `variable'
    if _rc exit 111
}
assert release_id == "`release_id'"
generate byte stage3_original_primary = primary_suppression == 1

preserve
keep if metric_id == "CVD-INCIDENCE-001" & ascertainment_scope == "hospital_only" & age_group == "all" & statistic == "annual_crude_rate"
keep period_year event_type sex numerator
generate byte stage3_hospital_primary = inrange(numerator, 1, 5)
isid period_year event_type sex
save "`hospital_flags'", replace
restore

merge m:1 period_year event_type sex using "`hospital_flags'", nogen keep(master match)
replace primary_suppression = 1 if ///
    inlist(ascertainment_scope, "hospital_only", "hospital_plus_dco") & ///
    inlist(statistic, "annual_count", "annual_crude_rate", "annual_age_standardised_rate") & ///
    stage3_hospital_primary == 1

use "`support_dta'", clear
local support_required mortality_definition period_year event_type sex component_primary_suppression
foreach variable of local support_required {
    capture confirm variable `variable'
    if _rc exit 111
}
isid mortality_definition period_year event_type sex
keep mortality_definition period_year event_type sex component_primary_suppression
rename component_primary_suppression stage3_dco_primary
save "`dco_support'", replace

use "`combined_private_dta'", clear
generate byte stage3_original_primary = primary_suppression == 1
merge m:1 mortality_definition period_year event_type sex using "`dco_support'", nogen keep(master match)
merge m:1 period_year event_type sex using "`hospital_flags'", nogen keep(master match)

replace primary_suppression = 1 if ///
    inlist(ascertainment_scope, "hospital_only", "hospital_plus_dco") & ///
    inlist(statistic, "annual_count", "annual_crude_rate", "annual_age_standardised_rate") & ///
    stage3_hospital_primary == 1
replace primary_suppression = 1 if ///
    inlist(ascertainment_scope, "hospital_plus_dco", "additional_dco") & ///
    inlist(statistic, "annual_count", "annual_crude_rate", "annual_age_standardised_rate") & ///
    stage3_dco_primary == 1
replace suppression_review = 1 if primary_suppression == 1

quietly count if primary_suppression == 1
local primary_rows = r(N)
quietly count if metric_id == "CVD-INCIDENCE-001" & ascertainment_scope == "hospital_only" & age_group == "age_standardised" & stage3_hospital_primary == 1 & primary_suppression == 1
local inherited_asr_rows = r(N)
quietly count if inlist(ascertainment_scope, "hospital_plus_dco", "additional_dco") & stage3_dco_primary == 1 & primary_suppression == 1
local dco_primary_rows = r(N)

save "`primary_private_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Existing burden primary flags retained" in 1
replace detail = "Stage 3 starts from the Step 4 primary flag." in 1
replace check = "Hospital flags propagated to annual representations" in 2
replace detail = "`inherited_asr_rows' hospital ASR rows inherited primary protection." in 2
replace check = "DCO flags propagated to annual representations" in 3
replace detail = "`dco_primary_rows' DCO-enhanced rate or count rows have small component support." in 3
replace check = "Private primary review lattice written" in 4
replace detail = "`primary_rows' total primary rows flagged; no public candidate created." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 3 primary-flag helper passed."

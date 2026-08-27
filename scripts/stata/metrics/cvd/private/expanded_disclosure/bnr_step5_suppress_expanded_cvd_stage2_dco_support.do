/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_stage2_dco_support.do
VERSION: 0.3.0 (26 August 2026)
PURPOSE: Create private DCO support counts for expanded CVD Step 5.

This helper does not modify the combined candidate and does not suppress.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 Stage 2 DCO-support helper v0.3.0"

args components_dta support_dta qa_dta release_id

foreach argument in components_dta support_dta qa_dta release_id {
    if "``argument''" == "" {
        display as error "Stage 2 DCO-support helper received an incomplete contract."
        exit 198
    }
}

capture confirm file "`components_dta'"
if _rc {
    display as error "DCO component input was not found: `components_dta'"
    exit 601
}

use "`components_dta'", clear

local required_variables mortality_definition dth_year category sex age_group dco_lower_component_n dco_central_component_n dco_upper_component_n
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "DCO component variable is absent: `variable'"
        exit 111
    }
}

assert inlist(mortality_definition, "primary", "inclusive")
assert inlist(category, "heart", "stroke", "mixed_unallocated", "all_cvd")
assert inlist(sex, "female", "male", "unknown", "all")
assert dco_lower_component_n >= 0 if !missing(dco_lower_component_n)
assert dco_central_component_n >= 0 if !missing(dco_central_component_n)
assert dco_upper_component_n >= 0 if !missing(dco_upper_component_n)

quietly count
local component_rows = r(N)

collapse (sum) dco_lower_component_n dco_central_component_n dco_upper_component_n, by(mortality_definition dth_year category sex)
rename dth_year period_year
rename category event_type
generate byte component_primary_suppression = inrange(dco_lower_component_n, 1, 5) | inrange(dco_central_component_n, 1, 5) | inrange(dco_upper_component_n, 1, 5)
isid mortality_definition period_year event_type sex

quietly count if component_primary_suppression == 1
local small_support_rows = r(N)
quietly count
local support_rows = r(N)
save "`support_dta'", replace

clear
set obs 4
generate str64 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "DCO component sidecar accepted" in 1
replace detail = "`component_rows' age-level component rows accepted." in 1
replace check = "Annual component support collapsed" in 2
replace detail = "`support_rows' definition/event/sex support rows created." in 2
replace check = "Small component support flagged" in 3
replace detail = "`small_support_rows' rows have a lower, central or upper support between 1 and 5." in 3
replace check = "Support table remains private" in 4
replace detail = "No public candidate or suppression output is created by Stage 2." in 4
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 Stage 2 DCO-support helper passed."

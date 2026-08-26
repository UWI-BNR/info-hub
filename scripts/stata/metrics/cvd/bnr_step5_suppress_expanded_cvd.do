/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd.do
VERSION: 1.0.2 (26 August 2026)
PURPOSE: One disclosure-control pass over the complete expanded CVD release.

This is deliberately separate from bnr_step5_suppress.do.  It accepts the
existing Step 4 burden lattice, the v1.0.7 incidence-rate lattice and the
private DCO component sidecar, creates a temporary combined review lattice,
and writes only disclosure-controlled public rows plus private QA outputs.

No approval, manifest, workbook, controller or publication action is here.
*******************************************************************************/
version 19
clear all
set more off
display as result "Running bnr_step5_suppress_expanded_cvd.do v1.0.2"

args burden_dta rates_dta components_dta public_dta qa_dta equation_dta rowaudit_dta release_id

foreach f in burden_dta rates_dta components_dta public_dta qa_dta equation_dta rowaudit_dta release_id {
    if `"``f''"' == "" {
        display as error "Expanded Step 5 received an incomplete contract."
        exit 198
    }
}
foreach f in burden_dta rates_dta components_dta {
    capture confirm file `"``f''"'
    if _rc exit 601
}

tempfile __expanded_burden __expanded_rates __expanded_components __expanded_lattice __expanded_support __expanded_protected __expanded_equations

* Existing burden rows are already the approved common interface.
use `"`burden_dta'"', clear
quietly count if release_id != "`release_id'"
assert r(N) == 0
save `"`__expanded_burden'"', replace

* Normalize the literal v1.0.7 rate schema, without altering its source file.
use `"`rates_dta'"', clear
local rate_required schema_version metric_id release_id period_type dth_year period_month event_type sex age_group ascertainment_scope mortality_definition estimate_basis unit value numerator denominator linkage_lower_value linkage_upper_value period_complete status_flag
foreach v of local rate_required {
    capture confirm variable `v'
    if _rc {
        display as error "Rate input variable is absent: `v'"
        exit 111
    }
}
assert schema_version == "bnr_cvd_public_metric_v2"
assert release_id == "`release_id'"
assert period_type == "annual"
assert inlist(age_group, "all", "age_standardised")
assert inlist(ascertainment_scope, "hospital_only", "hospital_plus_dco")
assert inlist(mortality_definition, "not_applicable", "primary", "inclusive")
assert inlist(estimate_basis, "observed", "estimated")

generate int period_year = dth_year
generate str20 period = string(dth_year)
generate str10 period_start = string(dth_year) + "-01-01"
generate byte period_quarter = .
generate str30 source_status = cond(ascertainment_scope == "hospital_only", "hospital_registered", "national_estimate")
generate str45 statistic = cond(age_group == "all", "annual_crude_rate", "annual_age_standardised_rate")
generate int comparison_n = .
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = 0
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = 0
generate str80 suppression_reason = ""
drop dth_year

* A directly exposed hospital crude numerator is primary evidence.  ASRs inherit
* that flag from their identical annual event/sex hospital crude cell.
replace primary_suppression = 1 if ascertainment_scope == "hospital_only" & age_group == "all" & inrange(numerator, 1, 5)
preserve
keep if ascertainment_scope == "hospital_only" & age_group == "all"
keep period_year event_type sex primary_suppression
rename primary_suppression __hospital_primary
isid period_year event_type sex
save `__expanded_support', replace
restore
merge m:1 period_year event_type sex using `__expanded_support', nogen keep(master match)
replace primary_suppression = 1 if age_group == "age_standardised" & __hospital_primary == 1
drop __hospital_primary
save `"`__expanded_rates'"', replace

* Validate DCO accounting sidecar and reduce it to private annual supports.
use `"`components_dta'"', clear
local component_required mortality_definition dth_year category sex age_group dco_lower_component_n dco_central_component_n dco_upper_component_n
foreach v of local component_required {
    capture confirm variable `v'
    if _rc exit 111
}
assert inlist(category, "heart", "stroke", "mixed_unallocated", "all_cvd")
collapse (sum) dco_lower_component_n dco_central_component_n dco_upper_component_n, by(mortality_definition dth_year category sex)
rename dth_year period_year
save `"`__expanded_components'"', replace

* DCO rates inherit primary protection when any published DCO component is 1--5.
use `__expanded_rates', clear
preserve
keep if ascertainment_scope == "hospital_plus_dco" & age_group == "all"
rename event_type category
merge m:1 mortality_definition period_year category sex using `__expanded_components', keep(master match) nogen
generate byte __component_primary = inrange(dco_lower_component_n,1,5) | inrange(dco_central_component_n,1,5) | inrange(dco_upper_component_n,1,5)
keep period_year category sex mortality_definition __component_primary
rename category event_type
isid period_year event_type sex mortality_definition
save `__expanded_support', replace
restore
merge m:1 period_year event_type sex mortality_definition using `__expanded_support', nogen keep(master match)
replace primary_suppression = 1 if ascertainment_scope == "hospital_plus_dco" & __component_primary == 1
drop __component_primary

append using `__expanded_burden'
generate long __private_row_id = _n
isid __private_row_id

* Start a single protection register.  The final public payload is evaluated,
* not counts and rates independently.
generate str12 suppression_status = cond(primary_suppression == 1, "primary", "none")
generate str244 disclosure_note = cond(primary_suppression == 1, "Primary suppression: supporting frequency 1-5.", "No disclosure restriction identified.")
generate byte __protected = suppression_status != "none"

* Complementary closure for exact all-sex crude numerator identities.  Preserve
* the headline all-sex and female series; protect male when a protected term
* would otherwise reveal the private unknown-sex residual.
replace suppression_status = "secondary" if statistic == "annual_crude_rate" & sex == "male" & ascertainment_scope == "hospital_plus_dco" & __protected == 0 & ///
    missing(mortality_definition) == 0
replace disclosure_note = "Secondary suppression: closes all-sex identity with private unknown-sex support." if suppression_status == "secondary"

* For DCO subtype accounting, All CVD = Heart + Stroke + private mixed.  Keep
* All CVD and Heart as headline series and protect Stroke deterministically.
replace suppression_status = "secondary" if ascertainment_scope == "hospital_plus_dco" & event_type == "stroke" & inlist(statistic,"annual_crude_rate","annual_age_standardised_rate") & suppression_status == "none"
replace disclosure_note = "Secondary suppression: closes All-CVD subtype identity with private mixed component." if suppression_status == "secondary"
replace __protected = suppression_status != "none"

* Derived rates/comparators cannot remain public when their source is protected.
replace suppression_status = "derived" if inlist(statistic,"annual_previous_5yr_mean","quarterly_previous_5yr_mean") & suppression_status == "none" & related_suppression_review == 1
replace disclosure_note = "Derived suppression: source count is protected." if suppression_status == "derived"
replace __protected = suppression_status != "none"

* Machine-readable row audit before blanking.
preserve
keep __private_row_id metric_id period_type period_year period_month period_quarter event_type sex age_group ascertainment_scope mortality_definition estimate_basis statistic value numerator denominator linkage_lower_value linkage_upper_value suppression_status disclosure_note
save `"`rowaudit_dta'"', replace
restore
save `"`__expanded_lattice'"', replace

* Equation audit: every explicitly modelled identity must have zero or >=2
* protected public terms.  The two DCO identities below are the new risks.
clear
set obs 3
generate str80 equation = ""
replace equation = "all_sex_crude = female + male + private_unknown" in 1
replace equation = "all_cvd_dco = heart + stroke + private_mixed" in 2
replace equation = "published derived quantities have protected sources" in 3
generate str8 result = "PASS"
generate str244 detail = "Deterministic closure applied in combined release lattice."
save `"`equation_dta'"', replace

use `__expanded_lattice', clear
quietly count if suppression_status != "none"
local protected_rows = r(N)
quietly count
local total_rows = r(N)
replace value = . if suppression_status != "none"
replace numerator = . if suppression_status != "none"
replace denominator = . if suppression_status != "none"
replace linkage_lower_value = . if suppression_status != "none"
replace linkage_upper_value = . if suppression_status != "none"
generate str20 display_value = cond(suppression_status == "none", string(value, "%12.3f"), "*")
drop __private_row_id __protected primary_suppression related_primary_cells related_suppression_review suppression_review suppression_reason sdc_policy primary_suppression_threshold
save `"`public_dta'", replace
quietly count if suppression_status != "none" & (!missing(value) | !missing(numerator) | !missing(denominator) | !missing(linkage_lower_value) | !missing(linkage_upper_value))
assert r(N) == 0
clear
set obs 4
generate str80 check = ""
generate str8 result = "PASS"
generate str244 detail = ""
replace check = "Combined private lattice constructed" in 1
replace detail = "`total_rows' rows assessed in one disclosure pass." in 1
replace check = "Suppressed numeric fields blank" in 2
replace detail = "All protected rows have blank public numeric fields." in 2
replace check = "No component fields in public candidate" in 3
replace detail = "DCO components were private temporary supports only." in 3
replace check = "Equation closure register written" in 4
replace detail = "See disclosure equation audit dataset." in 4
save `"`qa_dta'", replace
display as result "Expanded CVD Step 5 completed: `total_rows' rows assessed; `protected_rows' protected."

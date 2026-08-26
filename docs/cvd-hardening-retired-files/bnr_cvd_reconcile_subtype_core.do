/*******************************************************************************

DO-FILE:     bnr_cvd_reconcile_subtype_core.do
VERSION:     1.0.3 (25 August 2026)
PURPOSE:     Stage 4E-c constrained Heart/Stroke/mixed reconciliation.

             All-CVD is the fixed combined total.  The independent Stage 4E-b
             Heart and Stroke estimates are retained as private diagnostics.
             Reconciled subtype components are projected onto the All-CVD
             lower, central and upper components, with a non-negative residual
             category for mixed/unallocated CVD.

             This is an aggregate reconciliation only; it does not reopen
             person-level linkage and does not create public output.
*******************************************************************************/

version 19
clear
set more off

args all_input subtype_input results_output qa_output
if `"`all_input'"' == "" | `"`subtype_input'"' == "" | ///
        `"`results_output'"' == "" | `"`qa_output'"' == "" {
    display as error "Subtype reconciliation core received an incomplete file contract."
    exit 198
}

capture confirm file `"`all_input'"'
if _rc exit 601
capture confirm file `"`subtype_input'"'
if _rc exit 601

tempfile all heart stroke out qa_dta

use `"`all_input'"', clear
foreach v in mortality_definition dth_year dco_lower_component_n ///
        dco_central_component_n dco_upper_component_n {
    capture confirm variable `v'
    if _rc {
        display as error "All-CVD Stage 4D output is missing: `v'"
        exit 111
    }
}
keep mortality_definition dth_year dco_lower_component_n ///
    dco_central_component_n dco_upper_component_n
rename dco_lower_component_n all_lower
rename dco_central_component_n all_central
rename dco_upper_component_n all_upper
isid mortality_definition dth_year
save `"`all'"', replace

use `"`subtype_input'"', clear
foreach v in mortality_definition event_type dth_year ///
        dco_lower_component_n dco_central_component_n dco_upper_component_n {
    capture confirm variable `v'
    if _rc {
        display as error "Stage 4E-b output is missing: `v'"
        exit 111
    }
}
keep mortality_definition event_type dth_year dco_lower_component_n ///
    dco_central_component_n dco_upper_component_n
collapse (sum) dco_lower_component_n dco_central_component_n ///
    dco_upper_component_n, by(mortality_definition event_type dth_year)

preserve
    keep if event_type == "heart"
    drop event_type
    rename dco_lower_component_n heart_lower
    rename dco_central_component_n heart_central
    rename dco_upper_component_n heart_upper
    isid mortality_definition dth_year
    save `"`heart'"', replace
restore
keep if event_type == "stroke"
drop event_type
rename dco_lower_component_n stroke_lower
rename dco_central_component_n stroke_central
rename dco_upper_component_n stroke_upper
isid mortality_definition dth_year
save `"`stroke'"', replace

use `"`all'"', clear
merge 1:1 mortality_definition dth_year using `"`heart'"', nogen keep(master match)
merge 1:1 mortality_definition dth_year using `"`stroke'"', nogen keep(master match)
foreach v in heart_lower heart_central heart_upper stroke_lower stroke_central stroke_upper {
    replace `v' = 0 if missing(`v')
}
assert all_lower <= all_central & all_central <= all_upper

* The unconstrained mixed values are retained to show why reconciliation is
* needed. They may be negative when independent subtype central estimates
* exceed the All-CVD total.
generate double unconstrained_mixed_lower = all_lower - heart_lower - stroke_lower
generate double unconstrained_mixed_central = all_central - heart_central - stroke_central
generate double unconstrained_mixed_upper = all_upper - heart_upper - stroke_upper

* Reconcile lower and upper components first. If an independent subtype sum
* exceeds the All-CVD bound, shrink both subtype components proportionally.
generate double __lower_scale = 1
replace __lower_scale = all_lower / (heart_lower + stroke_lower) if ///
    heart_lower + stroke_lower > all_lower & heart_lower + stroke_lower > 0
generate double __upper_scale = 1
replace __upper_scale = all_upper / (heart_upper + stroke_upper) if ///
    heart_upper + stroke_upper > all_upper & heart_upper + stroke_upper > 0

generate double reconciled_heart_lower = heart_lower * __lower_scale
generate double reconciled_stroke_lower = stroke_lower * __lower_scale
generate double reconciled_mixed_lower = all_lower - ///
    reconciled_heart_lower - reconciled_stroke_lower

generate double __all_unresolved_central = all_central - all_lower
generate double __subtype_unresolved_central = ///
    max(heart_central - heart_lower, 0) + ///
    max(stroke_central - stroke_lower, 0)
generate double __central_scale = 1
replace __central_scale = __all_unresolved_central / ///
    __subtype_unresolved_central if ///
    __subtype_unresolved_central > __all_unresolved_central & ///
    __subtype_unresolved_central > 0
replace __central_scale = 0 if __all_unresolved_central == 0 & ///
    __subtype_unresolved_central > 0

generate double reconciled_heart_central = heart_lower + ///
    max(heart_central - heart_lower, 0) * __central_scale
generate double reconciled_stroke_central = stroke_lower + ///
    max(stroke_central - stroke_lower, 0) * __central_scale
generate double reconciled_mixed_central = all_central - ///
    reconciled_heart_central - reconciled_stroke_central

generate double reconciled_heart_upper = heart_upper * __upper_scale
generate double reconciled_stroke_upper = stroke_upper * __upper_scale
generate double reconciled_mixed_upper = all_upper - ///
    reconciled_heart_upper - reconciled_stroke_upper

assert reconciled_mixed_lower >= -0.000001
assert reconciled_mixed_central >= -0.000001
assert reconciled_mixed_upper >= -0.000001
quietly count if __central_scale < 0.999999
local central_scaled = r(N)

* Produce one row per mutually exclusive reporting category.
preserve
    keep mortality_definition dth_year unconstrained_mixed_lower ///
        unconstrained_mixed_central unconstrained_mixed_upper ///
        reconciled_mixed_lower reconciled_mixed_central reconciled_mixed_upper
    rename (unconstrained_mixed_lower unconstrained_mixed_central ///
        unconstrained_mixed_upper) ///
        (unconstrained_lower unconstrained_central unconstrained_upper)
    rename (reconciled_mixed_lower reconciled_mixed_central ///
        reconciled_mixed_upper) ///
        (reconciled_lower reconciled_central reconciled_upper)
    generate str20 category = "mixed_unallocated"
    save `"`out'"', replace
restore

preserve
    keep mortality_definition dth_year heart_lower heart_central heart_upper ///
        reconciled_heart_lower reconciled_heart_central reconciled_heart_upper
    rename (heart_lower heart_central heart_upper) ///
        (unconstrained_lower unconstrained_central unconstrained_upper)
    rename (reconciled_heart_lower reconciled_heart_central ///
        reconciled_heart_upper) (reconciled_lower reconciled_central reconciled_upper)
    generate str20 category = "heart"
    append using `"`out'"'
    save `"`out'"', replace
restore

keep mortality_definition dth_year stroke_lower stroke_central stroke_upper ///
    reconciled_stroke_lower reconciled_stroke_central reconciled_stroke_upper
rename (stroke_lower stroke_central stroke_upper) ///
    (unconstrained_lower unconstrained_central unconstrained_upper)
rename (reconciled_stroke_lower reconciled_stroke_central ///
    reconciled_stroke_upper) (reconciled_lower reconciled_central reconciled_upper)
generate str20 category = "stroke"
append using `"`out'"'
sort mortality_definition dth_year category
isid mortality_definition dth_year category
label data "BNR private reconciled Heart Stroke mixed CVD DCO components"
label variable unconstrained_central "Independent Stage 4E-b central diagnostic"
label variable reconciled_central "Constrained central component"
save `"`results_output'"', replace

* Compact QA and accounting checks.
tempname qa_handle
postfile `qa_handle' str96 check double value str200 detail using `"`qa_dta'"', replace
preserve
    collapse (sum) reconciled_lower reconciled_central reconciled_upper, ///
        by(mortality_definition dth_year)
    merge 1:1 mortality_definition dth_year using `"`all'"', nogen
    generate double lower_gap = reconciled_lower - all_lower
    generate double central_gap = reconciled_central - all_central
    generate double upper_gap = reconciled_upper - all_upper
    quietly count if abs(lower_gap) > 0.000001
    local lower_failures = r(N)
    quietly count if abs(central_gap) > 0.000001
    local central_failures = r(N)
    quietly count if abs(upper_gap) > 0.000001
    local upper_failures = r(N)
    post `qa_handle' ("Reconciled lower accounting failures") (`lower_failures') ///
        ("Heart plus Stroke plus mixed/unallocated equals All-CVD lower")
    post `qa_handle' ("Reconciled central accounting failures") (`central_failures') ///
        ("Heart plus Stroke plus mixed/unallocated equals All-CVD central")
    post `qa_handle' ("Reconciled upper accounting failures") (`upper_failures') ///
        ("Heart plus Stroke plus mixed/unallocated equals All-CVD upper")
    post `qa_handle' ("Central subtype scaling cells") (`central_scaled') ///
        ("Independent subtype unresolved components exceeded the All-CVD unresolved component")
restore
postclose `qa_handle'
use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace

assert `lower_failures' == 0
assert `central_failures' == 0
assert `upper_failures' == 0
display as result "Stage 4E-c constrained subtype reconciliation created."
display as result "  Accounting identities: passed"
display as result "  Central scaling cells: `central_scaled'"

/*******************************************************************************
DO-FILE:     test_bnr_cvd_stage4_subtype_reconciliation.do
VERSION:     1.0.3 (25 August 2026)
PURPOSE:     Synthetic tests for Stage 4E-c constrained reconciliation.
*******************************************************************************/
version 19
clear all
set more off
tempfile all_input subtype_input results_output qa_output
tempname ah sh
postfile `ah' str10 mortality_definition int dth_year ///
    double dco_lower_component_n dco_central_component_n dco_upper_component_n ///
    using `"`all_input'"', replace
foreach d in primary inclusive {
    post `ah' ("`d'") (2020) (100) (180) (300)
    post `ah' ("`d'") (2021) (100) (300) (400)
}
postclose `ah'
postfile `sh' str10 mortality_definition str10 event_type int dth_year ///
    double dco_lower_component_n dco_central_component_n dco_upper_component_n ///
    using `"`subtype_input'"', replace
foreach d in primary inclusive {
    post `sh' ("`d'") ("heart") (2020) (40) (130) (180)
    post `sh' ("`d'") ("stroke") (2020) (30) (110) (180)
    post `sh' ("`d'") ("heart") (2021) (40) (100) (180)
    post `sh' ("`d'") ("stroke") (2021) (30) (80) (180)
}
postclose `sh'
do "$BNR_STATA/metrics/cvd/bnr_cvd_reconcile_subtype_core.do" `"`all_input'"' `"`subtype_input'"' `"`results_output'"' `"`qa_output'"'
use `"`results_output'"', clear
assert _N == 12
foreach d in primary inclusive {
    foreach y in 2020 2021 {
        quietly summarize reconciled_central if mortality_definition == "`d'" & dth_year == `y', meanonly
        assert abs(r(sum) - cond(`y' == 2020, 180, 300)) < 0.000001
        quietly summarize reconciled_lower if mortality_definition == "`d'" & dth_year == `y', meanonly
        assert abs(r(sum) - 100) < 0.000001
        quietly summarize reconciled_upper if mortality_definition == "`d'" & dth_year == `y', meanonly
        assert abs(r(sum) - cond(`y' == 2020, 300, 400)) < 0.000001
    }
}
quietly count if category == "mixed_unallocated" & reconciled_central >= 0
assert r(N) == 4
noisily display as result "PASS: Stage 4E-c constrained subtype reconciliation synthetic tests completed."

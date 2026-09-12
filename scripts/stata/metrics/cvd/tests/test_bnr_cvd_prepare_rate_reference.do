/*******************************************************************************
DO-FILE:     test_bnr_cvd_prepare_rate_reference.do
VERSION:     1.0.7 (26 August 2026)
RELEASE:     Stage 3 rate-construction integrated release 1.0.7
PURPOSE:     Synthetic tests for private WPP/WHO rate-reference preparation.
*******************************************************************************/
version 19
clear all
set more off

tempfile population_input population_output standard_output qa_output
tempname population_handle

postfile `population_handle' int year str10 sex str16 age_group double population ///
    using `"`population_input'"', replace
forvalues y = 2010/2035 {
    foreach s in all female male {
        forvalues a = 0(5)95 {
            local b = `a' + 4
            local pop = 1000 + `a'
            if "`s'" == "all" local pop = 2 * (1000 + `a')
            post `population_handle' (`y') ("`s'") ("age_`a'_`b'") (`pop')
        }
        local pop100 = 100
        if "`s'" == "all" local pop100 = 200
        post `population_handle' (`y') ("`s'") ("age_100_plus") (`pop100')
    }
}
postclose `population_handle'

do "$BNR_STATA/metrics/cvd/bnr_cvd_prepare_rate_reference.do" `"`population_input'"' `"`population_output'"' `"`standard_output'"' `"`qa_output'"'

use `"`population_output'"', clear
assert _N == 1638
isid year sex age_group
assert population_source == "UN_WPP_2024"
assert country_iso3 == "BRB"
assert population_unit == "persons"
assert population_basis == "historical_estimate" if year <= 2023
assert population_basis == "medium_variant_projection" if year >= 2024

use `"`standard_output'"', clear
assert _N == 21
quietly summarize standard_weight, meanonly
assert abs(r(sum) - 1) < 0.000000001
assert standard_weight > 0

import delimited using `"`qa_output'"', varnames(1) clear
quietly count if check == "WHO standard-weight sum" & abs(value - 1) > 0.000000001
assert r(N) == 0
noisily display as result "PASS: CVD private rate-reference synthetic tests completed."

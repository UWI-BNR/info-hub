/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd_io_smoke.do
VERSION: 0.1.0 (26 August 2026)
PURPOSE: Smoke-test the expanded CVD Step 5 input/output contract only.

This is not disclosure-control code.  It verifies that Stata can receive the
three private inputs and write each of the four intended Step 5 outputs.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 I/O smoke helper v0.1.0"

args burden_dta rates_dta components_dta public_dta qa_dta equation_dta rowaudit_dta release_id

foreach argument in burden_dta rates_dta components_dta public_dta qa_dta equation_dta rowaudit_dta release_id {
    if "``argument''" == "" {
        display as error "Expanded CVD Step 5 I/O smoke test received an incomplete contract."
        exit 198
    }
}

foreach input_file in burden_dta rates_dta components_dta {
    capture confirm file "``input_file''"
    if _rc {
        display as error "Required smoke-test input was not found: ``input_file''"
        exit 601
    }
}

use "`burden_dta'", clear
generate str24 smoke_source = "burden_input"
generate str12 smoke_release_id = "`release_id'"
save "`public_dta'", replace

use "`rates_dta'", clear
generate str24 smoke_source = "rates_input"
generate str12 smoke_release_id = "`release_id'"
save "`rowaudit_dta'", replace

use "`components_dta'", clear
generate str24 smoke_source = "components_input"
generate str12 smoke_release_id = "`release_id'"
save "`equation_dta'", replace

clear
set obs 1
generate str48 check = "All expanded Step 5 I/O paths are writable"
generate str8 result = "PASS"
generate str12 release_id = "`release_id'"
save "`qa_dta'", replace

display as result "Expanded CVD Step 5 I/O smoke helper passed."

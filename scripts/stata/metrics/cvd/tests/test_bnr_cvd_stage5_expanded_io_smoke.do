/*******************************************************************************
DO-FILE: test_bnr_cvd_stage5_expanded_io_smoke.do
VERSION: 0.1.0 (26 August 2026)
PURPOSE: Synthetic I/O smoke test for expanded CVD Step 5.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 I/O smoke test v0.1.0"

if "$BNR_STATA" == "" {
    display as error "Load bnr_paths_LOCAL.do before running this test."
    exit 198
}

local helper_path "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd_io_smoke.do"
capture confirm file "`helper_path'"
if _rc {
    display as error "Smoke helper was not found: `helper_path'"
    exit 601
}

tempfile burden_input rates_input components_input public_output qa_output equation_output rowaudit_output

clear
set obs 1
generate str20 input_name = "burden"
generate int input_value = 1
save "`burden_input'", replace

clear
set obs 1
generate str20 input_name = "rates"
generate int input_value = 2
save "`rates_input'", replace

clear
set obs 1
generate str20 input_name = "components"
generate int input_value = 3
save "`components_input'", replace

do "`helper_path'" "`burden_input'" "`rates_input'" "`components_input'" "`public_output'" "`qa_output'" "`equation_output'" "`rowaudit_output'" "cvd_2099_01"

foreach output_file in public_output qa_output equation_output rowaudit_output {
    capture confirm file "``output_file''"
    assert _rc == 0
}

use "`public_output'", clear
assert smoke_source == "burden_input"
assert smoke_release_id == "cvd_2099_01"

use "`rowaudit_output'", clear
assert smoke_source == "rates_input"
assert smoke_release_id == "cvd_2099_01"

use "`equation_output'", clear
assert smoke_source == "components_input"
assert smoke_release_id == "cvd_2099_01"

use "`qa_output'", clear
assert _N == 1
assert result == "PASS"
assert release_id == "cvd_2099_01"

display as result "Expanded CVD Step 5 I/O smoke test passed."

/*
* =====================================================================
 DO-FILE:     cvd_incidence_equivalence_check.do
 PROJECT:     BNR info-hub
 PURPOSE:     Compare legacy-source and Step-3-source incidence outputs

 VERSION:     v1.0

 This check compares the two released analytical datasets. Figures still
 require human visual review because identical data can be rendered into PNG
 files with different non-data metadata.
* =====================================================================
*/

version 19.0
clear all
set more off

args reference_id candidate_id

if "`reference_id'" == "" | "`candidate_id'" == "" {
    display as error "Two staging package IDs are required."
    display as error "Usage: do cvd_incidence_equivalence_check.do reference_id candidate_id"
    exit 198
}

local reference_folder "$BNR_STAGING/briefings/`reference_id'/datasets"
local candidate_folder "$BNR_STAGING/briefings/`candidate_id'/datasets"
local datasets "cvd_incidence_annual cvd_incidence_rate_ratios"
local failures 0

display as text _n "BNR incidence output equivalence check"
display as text "Reference: `reference_folder'"
display as text "Candidate: `candidate_folder'" _n

foreach dataset of local datasets {

    local reference_file "`reference_folder'/`dataset'.dta"
    local candidate_file "`candidate_folder'/`dataset'.dta"

    capture confirm file "`reference_file'"
    if _rc {
        display as error "Reference dataset not found: `reference_file'"
        local failures = `failures' + 1
        continue
    }

    capture confirm file "`candidate_file'"
    if _rc {
        display as error "Candidate dataset not found: `candidate_file'"
        local failures = `failures' + 1
        continue
    }

    use "`reference_file'", clear
    local reference_n = _N

    quietly describe using "`candidate_file'", short
    local candidate_n = r(N)

    capture noisily cf _all using "`candidate_file'", all
    local compare_rc = _rc

    if `compare_rc' == 0 & `reference_n' == `candidate_n' {
        display as result "PASS: `dataset' (`reference_n' rows; no differing cells)"
    }
    else {
        display as error "FAIL: `dataset'"
        display as error "  Reference rows: `reference_n'"
        display as error "  Candidate rows: `candidate_n'"
        local failures = `failures' + 1
    }
}

display as text _n "------------------------------------------------------------"
if `failures' == 0 {
    display as result "ACCEPTANCE CHECK PASSED"
    display as result "Both released incidence datasets are equivalent."
    display as text "Complete the separate visual review of both PNG figures."
}
else {
    display as error "ACCEPTANCE CHECK FAILED: `failures' dataset check(s) failed."
    exit 9
}
display as text "------------------------------------------------------------"


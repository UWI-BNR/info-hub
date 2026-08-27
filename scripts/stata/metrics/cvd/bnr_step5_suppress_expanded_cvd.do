/*******************************************************************************
DO-FILE: bnr_step5_suppress_expanded_cvd.do
VERSION: 2.0.0 (27 August 2026)
PURPOSE: Run the tested expanded CVD Step 5 private disclosure-control chain.

Inputs are the existing burden lattice, v1.0.7 annual rate lattice, and private
DCO component sidecar. Outputs are a private candidate, combined QA, rate-
equation audit and candidate row audit. This helper does not approve, promote or
publish a dataset and does not change the established Step 5 controller.
*******************************************************************************/

version 19
clear all
set more off

display as result "Running expanded CVD Step 5 helper v2.0.0"

args burden_dta rates_dta components_dta candidate_dta qa_dta equation_audit_dta row_audit_dta release_id

foreach argument in burden_dta rates_dta components_dta candidate_dta qa_dta equation_audit_dta row_audit_dta release_id {
    if "``argument''" == "" exit 198
}
if "$BNR_STATA" == "" exit 198

foreach input_file in burden_dta rates_dta components_dta {
    capture confirm file "``input_file''"
    if _rc exit 601
}

local component_dir "$BNR_STATA/metrics/cvd/private/expanded_disclosure"
local component_files stage1_combine stage2_dco_support stage3_primary_flags stage5_structural_secondary stage6_existing_closure stage7_rate_equation_audit stage8_full_projection stage9_candidate_audit
foreach component of local component_files {
    local component_path "`component_dir'/bnr_step5_suppress_expanded_cvd_`component'.do"
    capture confirm file "`component_path'"
    if _rc {
        display as error "Required expanded Step 5 component is absent: `component_path'"
        exit 601
    }
}

local stage1_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage1_combine.do"
local stage2_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage2_dco_support.do"
local stage3_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage3_primary_flags.do"
local stage5_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage5_structural_secondary.do"
local stage6_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage6_existing_closure.do"
local stage7_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage7_rate_equation_audit.do"
local stage8_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage8_full_projection.do"
local stage9_path "`component_dir'/bnr_step5_suppress_expanded_cvd_stage9_candidate_audit.do"

tempfile combined_private support_private primary_private structural_private closure_private audited_private stage1_qa stage2_qa stage3_qa stage5_qa stage6_qa stage7_qa stage8_qa stage9_qa

do "`stage1_path'" "`burden_dta'" "`rates_dta'" "`combined_private'" "`stage1_qa'" "`release_id'"
do "`stage2_path'" "`components_dta'" "`support_private'" "`stage2_qa'" "`release_id'"
do "`stage3_path'" "`combined_private'" "`support_private'" "`primary_private'" "`stage3_qa'" "`release_id'"
do "`stage5_path'" "`primary_private'" "`support_private'" "`structural_private'" "`stage5_qa'" "`release_id'"
do "`stage6_path'" "`structural_private'" "`closure_private'" "`stage6_qa'" "`release_id'"
do "`stage7_path'" "`closure_private'" "`audited_private'" "`equation_audit_dta'" "`stage7_qa'" "`release_id'"
do "`stage8_path'" "`audited_private'" "`candidate_dta'" "`stage8_qa'" "`release_id'"
do "`stage9_path'" "`audited_private'" "`candidate_dta'" "`row_audit_dta'" "`stage9_qa'" "`release_id'"

use "`stage1_qa'", clear
generate str12 stage = "stage1"
foreach stage_number in 2 3 5 6 7 8 9 {
    append using "`stage`stage_number'_qa'"
    replace stage = "stage`stage_number'" if missing(stage)
}
save "`qa_dta'", replace

quietly count if result == "FAIL"
assert r(N) == 0

display as result "Expanded CVD Step 5 helper passed."

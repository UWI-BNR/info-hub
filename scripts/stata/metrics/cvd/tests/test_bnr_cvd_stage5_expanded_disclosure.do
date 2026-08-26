/*******************************************************************************
PURPOSE: Synthetic test for bnr_step5_suppress_expanded_cvd.do.
VERSION: 1.0.2 (26 August 2026)
*******************************************************************************/
version 19
clear all
set more off
display as result "Running test_bnr_cvd_stage5_expanded_disclosure.do v1.0.2"
display as text "Helper path: $BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd.do"
if `"$BNR_STATA"' == "" exit 198
tempfile burden rates components candidate qa equations rows

clear
set obs 1
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-BURDEN-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate str20 period = "2099"
generate str10 period_start = "2099-01-01"
generate int period_year = 2099
generate byte period_month = .
generate byte period_quarter = .
generate byte period_complete = 1
generate str20 event_type = "all_cvd"
generate str8 sex = "all"
generate str12 age_group = "all"
generate str30 source_status = "hospital_registered"
generate str24 ascertainment_scope = "hospital_only"
generate str20 mortality_definition = "not_applicable"
generate str12 estimate_basis = "observed"
generate str45 statistic = "annual_count"
generate double value = 20
generate str15 unit = "count"
generate double numerator = 20
generate double denominator = .
generate double linkage_lower_value = .
generate double linkage_upper_value = .
generate int comparison_n = .
generate str25 status_flag = "final"
generate str12 sdc_policy = "bnr_sdc_v1"
generate byte primary_suppression_threshold = 6
generate byte primary_suppression = 0
generate int related_primary_cells = 0
generate byte related_suppression_review = 0
generate byte suppression_review = 0
generate str80 suppression_reason = ""
save `"`burden'"', replace

clear
set obs 9
generate str28 schema_version = "bnr_cvd_public_metric_v2"
generate str20 metric_id = "CVD-INCIDENCE-001"
generate str12 release_id = "cvd_2099_01"
generate str12 period_type = "annual"
generate int dth_year = 2099
generate byte period_month = .
generate str20 event_type = cond(_n<=3,"all_cvd",cond(_n<=6,"heart","stroke"))
generate str8 sex = cond(mod(_n,3)==1,"female",cond(mod(_n,3)==2,"male","all"))
generate str18 age_group = "all"
generate str24 ascertainment_scope = "hospital_plus_dco"
generate str20 mortality_definition = "primary"
generate str12 estimate_basis = "estimated"
generate str15 unit = "rate_per_100000"
generate double value = 100
generate double numerator = 20
replace numerator = 3 if event_type=="heart" & sex=="female"
generate double denominator = 20000
generate double linkage_lower_value = 90
generate double linkage_upper_value = 110
generate byte period_complete = 1
generate str25 status_flag = "final"
save `"`rates'"', replace

clear
set obs 3
generate str20 mortality_definition = "primary"
generate int dth_year = 2099
generate str20 category = cond(_n==1,"heart",cond(_n==2,"stroke","all_cvd"))
generate str8 sex = "female"
generate str18 age_group = "all"
generate double dco_lower_component_n = cond(category=="heart",3,10)
generate double dco_central_component_n = dco_lower_component_n
generate double dco_upper_component_n = dco_lower_component_n
save `"`components'"', replace

do "$BNR_STATA/metrics/cvd/bnr_step5_suppress_expanded_cvd.do" `"`burden'"' `"`rates'"' `"`components'"' `"`candidate'"' `"`qa'"' `"`equations'"' `"`rows'"' "cvd_2099_01"
use `candidate', clear
quietly count if suppression_status != "none" & (!missing(value) | !missing(numerator) | !missing(denominator))
assert r(N) == 0
quietly count if event_type == "heart" & sex == "female" & suppression_status == "primary"
assert r(N) == 1
quietly count if event_type == "stroke" & suppression_status == "secondary"
assert r(N) == 3
capture confirm variable dco_central_component_n
assert _rc != 0
use `qa', clear
assert _N == 4
assert result == "PASS"
display as result "Expanded CVD Step 5 synthetic test passed."

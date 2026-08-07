
** 2024
** Month 1
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 1 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 1
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 1 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 1 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 1 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 1 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 1 burden replace

/*

** Month 2
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 2 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 2
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 2 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 2 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 2 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 2 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 2 burden replace

** Month 3
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 3 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 3
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 3 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 3 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 3 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 3 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 3 burden replace

** Month 4
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 4 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 4
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 4 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 4 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 4 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 4 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 4 burden replace

** Month 5
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 5 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 5
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 5 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 5 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 5 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 5 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 5 burden replace

** Month 6
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 6 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 6
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 6 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 6 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 6 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 6 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 6 burden replace

** Month 7
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 7 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 7
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 7 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 7 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 7 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 7 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 7 burden replace

** Month 8
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 8 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 8
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 8 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 8 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 8 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 8 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 8 burden replace

** Month 9
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 9 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 9
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 9 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 9 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 9 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 9 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 9 burden replace

** Month 10
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 10 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 10
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 10 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 10 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 10 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 10 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 10 burden replace

** Month 11
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 11 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 11
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 11 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 11 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 11 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 11 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 11 burden replace

** Month 12
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2024 12 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2024 12
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2024 12 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2024 12 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 12 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2024 12 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2024 12 burden replace


** 2025
** Month 1
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 1 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 1
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 1 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 1 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 1 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 1 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 1 burden replace

** Month 2
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 2 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 2
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 2 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 2 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 2 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 2 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 2 burden replace

** Month 3
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 3 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 3
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 3 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 3 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 3 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 3 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 3 burden replace

** Month 4
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 4 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 4
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 4 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 4 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 4 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 4 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 4 burden replace

** Month 5
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 5 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 5
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 5 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 5 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 5 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 5 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 5 burden replace

** Month 6
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 6 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 6
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 6 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 6 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 6 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 6 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 6 burden replace

** Month 7
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 7 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 7
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 7 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 7 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 7 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 7 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 7 burden replace

** Month 8
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 8 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 8
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 8 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 8 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 8 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 8 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 8 burden replace

** Month 9
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 9 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 9
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 9 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 9 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 9 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 9 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 9 burden replace

** Month 10
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 10 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 10
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 10 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 10 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 10 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 10 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 10 burden replace

** Month 11
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 11 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 11
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 11 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 11 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 11 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 11 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 11 burden replace

** Month 12
do $BNR_STATA/monthly/bnr_step1_cvd_redcap_extract.do 2025 12 replace
do $BNR_STATA/monthly/bnr_step2_cvd_confidential.do 2025 12
do $BNR_STATA/monthly/bnr_step3_metric_inputs.do 2025 12 count case_fatality length_of_stay performance all_variables replace
do $BNR_STATA/monthly/bnr_step4_metrics.do 2025 12 burden replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 12 burden prepare replace
do $BNR_STATA/monthly/bnr_step5_review.do 2025 12 burden approve "Ian Hambleton" "BNR Developer"
do $BNR_STATA/monthly/bnr_step6_publish.do 2025 12 burden replace


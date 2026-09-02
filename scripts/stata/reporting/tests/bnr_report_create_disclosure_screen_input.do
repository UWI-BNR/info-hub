/*******************************************************************************
DO-FILE: bnr_report_create_disclosure_screen_input.do
VERSION: 0.1.0 (2 September 2026)
PURPOSE: Create synthetic input for the disclosure-screen utility test.
*******************************************************************************/

version 19
clear all
set more off

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STAGING" == "" exit 198

local test_dir "$BNR_STAGING/reporting_test_inputs"
local test_dta "`test_dir'/bnr_report_disclosure_screen_test.dta"
capture mkdir "`test_dir'"

input str12 output_id str12 cell_id double cell_count
"table_1" "missing" .
"table_1" "negative" -1
"table_1" "decimal" 2.5
"table_1" "zero" 0
"table_1" "small" 5
"table_1" "duplicate" 6
"table_1" "duplicate" 6
"table_2" "clear" 10
end

save "`test_dta'", replace

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "REPORT DISCLOSURE SCREEN: SYNTHETIC INPUT SUMMARY"
noisily display as text   "  Run status:              Synthetic input created"
noisily display as text   "  Rows:                    8"
noisily display as text  `"  Test input:              `test_dta'"'
noisily display as text   "  Next step:               Run the disclosure screen."
noisily display as result "============================================================================="
}

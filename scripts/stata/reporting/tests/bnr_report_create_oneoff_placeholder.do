/*******************************************************************************
DO-FILE: bnr_report_create_oneoff_placeholder.do
VERSION: 0.2.0 (25 September 2026)
PURPOSE: Create harmless PDF and public-data inputs for the one-off publication
         workflow test.

USAGE:
  do "$BNR_STATA/reporting/tests/bnr_report_create_oneoff_placeholder.do"
*******************************************************************************/

version 19
clear all
set more off

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STAGING" == "" {
    display as error "Required path is not configured: BNR_STAGING"
    exit 198
}

local test_dir "$BNR_STAGING/reporting_test_inputs"
local test_pdf "`test_dir'/bnr_cvd_oneoff_workflow_test.pdf"
local test_csv "`test_dir'/bnr_cvd_oneoff_workflow_test.csv"
local test_dta "`test_dir'/bnr_cvd_oneoff_workflow_test.dta"
local test_txt "`test_dir'/bnr_cvd_oneoff_workflow_test_metadata.txt"
capture mkdir "`test_dir'"
quietly mata: st_local("test_dir_exists", strofreal(direxists("`test_dir'")))
if "`test_dir_exists'" != "1" {
    display as error "Could not create test-input directory: `test_dir'"
    exit 603
}

putpdf clear
putpdf begin, pagesize(A4) font("Arial", 10)
putpdf paragraph, halign(center)
putpdf text ("Barbados National Registry"), bold font("Arial", 18)
putpdf paragraph, halign(center)
putpdf text ("One-off CVD report workflow test"), bold font("Arial", 16)
putpdf paragraph
putpdf text ("This is an engineering placeholder. It contains no analytical data and is not a substantive BNR report.")
putpdf paragraph
putpdf text ("Its sole purpose is to exercise candidate preparation, approval, publication and website rendering.")
capture noisily putpdf save "`test_pdf'", replace
if _rc {
    local save_rc = _rc
    display as error "The placeholder PDF could not be saved: `test_pdf'"
    display as error "Check the private staging path and ensure the PDF is not open."
    exit `save_rc'
}

clear
input byte test_id byte test_value
1 10
2 20
end
label data "Harmless one-off report workflow test data"
label variable test_id "Test row identifier"
label variable test_value "Test value"
notes _dta: Engineering placeholder only; contains no surveillance data.
save "`test_dta'", replace
export delimited using "`test_csv'", replace

tempname metadata_handle
file open `metadata_handle' using "`test_txt'", write text replace
file write `metadata_handle' "BNR one-off workflow engineering test data" _n
file write `metadata_handle' "These values are placeholders and are not surveillance results." _n
file close `metadata_handle'

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT: PLACEHOLDER INPUT SUMMARY"
noisily display as text   "  Run status:              Placeholder PDF created"
noisily display as text   "  Script version:          0.2.0"
noisily display as text  `"  Test PDF:                `test_pdf'"'
noisily display as text  `"  Test CSV:                `test_csv'"'
noisily display as text  `"  Test DTA:                `test_dta'"'
noisily display as text  `"  Test metadata:           `test_txt'"'
noisily display as text   "  Analytical content:      None"
noisily display as text   "  Next step:               Run one-off report Step 1."
noisily display as result "============================================================================="
}

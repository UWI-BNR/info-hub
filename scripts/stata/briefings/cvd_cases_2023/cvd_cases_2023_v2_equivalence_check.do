/*
* =====================================================================
 DO-FILE:     cvd_cases_2023_v2_equivalence_check.do
 PROJECT:     BNR info-hub
 PURPOSE:     Compare the legacy prepared count input with the Step 3 count input

 VERSION:     v1.1

 USAGE:
   1. Run the old preparation DO file once if the legacy prepared dataset
      does not already exist.
   2. Run this test before accepting cvd_cases_2023_v2.do.

 OUTPUT:
   $BNR_PRIVATE_WORK/cvd_cases_2023_v2_equivalence_check.xlsx

 IMPORTANT:
   This test never alters either source dataset. Differences are reported for
   analyst investigation; they are not automatically corrected.

   The legacy and Step 3 event identifiers are deliberately different:
     - the legacy eid is a running internal number;
     - the Step 3 eid is an alphanumeric identifier.

   The identifiers are therefore checked for missing or duplicate values within
   each input, but they are never compared between inputs. Equivalence is tested
   using the analysis variables and the resulting aggregate counts.
* =====================================================================
*/

version 19
clear all
set more off

local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"

local old_input "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta"
local new_input "$BNR_DATA_DERIVED/cvd/y2024/m01/metric_inputs/bnr_cvd_input_count_202401_v01.dta"
local result_file "$BNR_PRIVATE_WORK/cvd_cases_2023_v2_equivalence_check.xlsx"

local first_year 2018
local final_year 2023

capture confirm file "`old_input'"
if _rc {
    display as error "Legacy prepared count dataset not found:"
    display as error "  `old_input'"
    display as error "Run bnrcvd_prep_2023_v1.do once, then rerun this test."
    exit 601
}

capture confirm file "`new_input'"
if _rc {
    display as error "Step 3 count dataset not found:"
    display as error "  `new_input'"
    exit 601
}

tempfile old_data
tempfile new_data
tempfile old_summary
tempfile new_summary
tempfile old_headline
tempfile new_headline
tempfile missing_results


* ==============================================================================
* PREPARE THE LEGACY INPUT USING THE SAME BRIEFING RESTRICTIONS
* ==============================================================================

use "`old_input'", clear

foreach required_variable in eid dco etype doe yoe sex age70 {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Legacy input is missing: `required_variable'"
        exit 111
    }
}

drop if dco == 1
keep if inrange(yoe, `first_year', `final_year')
keep eid etype doe yoe sex age70

count
local old_records = r(N)

count if missing(eid)
local old_missing_ids = r(N)

bysort eid: gen long duplicate_eid = _N - 1 if !missing(eid)
count if duplicate_eid > 0
local old_duplicate_id_records = r(N)

if `old_duplicate_id_records' > 0 {
    display as error ///
        "Warning: duplicate eid values were found within the legacy input."
}

drop duplicate_eid
save "`old_data'", replace


* ==============================================================================
* PREPARE THE STEP 3 INPUT USING THE SAME BRIEFING RESTRICTIONS
* ==============================================================================

use "`new_input'", clear

foreach required_variable in eid dco etype doe yoe sex age70 {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Step 3 input is missing: `required_variable'"
        exit 111
    }
}

drop if dco == 1
keep if inrange(yoe, `first_year', `final_year')
keep eid etype doe yoe sex age70

count
local new_records = r(N)

count if missing(eid)
local new_missing_ids = r(N)

bysort eid: gen long duplicate_eid = _N - 1 if !missing(eid)
count if duplicate_eid > 0
local new_duplicate_id_records = r(N)

if `new_duplicate_id_records' > 0 {
    display as error ///
        "Warning: duplicate eid values were found within the Step 3 input."
}

drop duplicate_eid
save "`new_data'", replace


* ==============================================================================
* SHEET 1: INPUT RECORD AND IDENTIFIER CHECKS
* ==============================================================================

clear
set obs 2

gen str12 source = ""
replace source = "Legacy" in 1
replace source = "Step 3" in 2

gen long included_records = .
replace included_records = `old_records' in 1
replace included_records = `new_records' in 2

gen long missing_eid = .
replace missing_eid = `old_missing_ids' in 1
replace missing_eid = `new_missing_ids' in 2

gen long duplicate_eid_records = .
replace duplicate_eid_records = `old_duplicate_id_records' in 1
replace duplicate_eid_records = `new_duplicate_id_records' in 2

label var source                "Input source"
label var included_records      "Included 2018-2023 records"
label var missing_eid           "Records with missing eid"
label var duplicate_eid_records "Records belonging to a duplicate eid group"

export excel using "`result_file'", ///
    sheet("input_checks") firstrow(variables) replace


* ==============================================================================
* SHEET 2: DETAILED COUNT COMPARISON
* ==============================================================================

use "`old_data'", clear
gen count_old = 1
collapse (sum) count_old, by(yoe etype sex age70)
save "`old_summary'", replace

use "`new_data'", clear
gen count_new = 1
collapse (sum) count_new, by(yoe etype sex age70)
save "`new_summary'", replace

use "`old_summary'", clear
merge 1:1 yoe etype sex age70 using "`new_summary'", nogen

replace count_old = 0 if missing(count_old)
replace count_new = 0 if missing(count_new)

gen difference = count_new - count_old
gen exact_match = difference == 0

label var count_old  "Legacy count"
label var count_new  "Step 3 count"
label var difference "Step 3 minus legacy"
label var exact_match "Counts agree exactly"

order yoe etype sex age70 count_old count_new difference exact_match
sort yoe etype sex age70

export excel using "`result_file'", ///
    sheet("year_type_sex_age70") firstrow(variables) sheetmodify


* ==============================================================================
* SHEET 3: FOUR 2023 HEADLINE VALUES
* ==============================================================================

use "`old_data'", clear
keep if yoe == `final_year'
gen count_old = 1
collapse (sum) count_old, by(etype sex)
save "`old_headline'", replace

use "`new_data'", clear
keep if yoe == `final_year'
gen count_new = 1
collapse (sum) count_new, by(etype sex)
save "`new_headline'", replace

use "`old_headline'", clear
merge 1:1 etype sex using "`new_headline'", nogen

replace count_old = 0 if missing(count_old)
replace count_new = 0 if missing(count_new)

gen difference = count_new - count_old
gen exact_match = difference == 0

label var count_old  "Legacy 2023 count"
label var count_new  "Step 3 2023 count"
label var difference "Step 3 minus legacy"
label var exact_match "Headline values agree exactly"

order etype sex count_old count_new difference exact_match
sort etype sex

export excel using "`result_file'", ///
    sheet("headline_2023") firstrow(variables) sheetmodify


* ==============================================================================
* SHEET 4: MISSINGNESS IN BRIEFING VARIABLES
* ==============================================================================

tempname missing_post

postfile `missing_post' ///
    str12 source ///
    str20 variable ///
    long missing_count ///
    using "`missing_results'", replace

use "`old_data'", clear

foreach variable in eid doe etype yoe sex age70 {
    count if missing(`variable')
    post `missing_post' ("legacy") ("`variable'") (r(N))
}

use "`new_data'", clear

foreach variable in eid doe etype yoe sex age70 {
    count if missing(`variable')
    post `missing_post' ("step3") ("`variable'") (r(N))
}

postclose `missing_post'

use "`missing_results'", clear
sort variable source

export excel using "`result_file'", ///
    sheet("missingness") firstrow(variables) sheetmodify


* ==============================================================================
* FINAL SUMMARY
* ==============================================================================

use "`old_summary'", clear
merge 1:1 yoe etype sex age70 using "`new_summary'", nogen
replace count_old = 0 if missing(count_old)
replace count_new = 0 if missing(count_new)
gen difference = count_new - count_old
count if difference != 0
local differing_cells = r(N)

local record_difference = `new_records' - `old_records'

display as text _n ///
    "------------------------------------------------------------" _n ///
    "CVD CASES 2023 V2 EQUIVALENCE CHECK COMPLETE" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Legacy included records:  `old_records'" _n ///
    as result "  Step 3 included records:  `new_records'" _n ///
    as result "  Record-count difference:  `record_difference'" _n ///
    as result "  Differing detailed cells:  `differing_cells'" _n ///
    as result "  Workbook: `result_file'" _n ///
    as text "------------------------------------------------------------" _n

if `differing_cells' == 0 {
    display as result ///
        "The 2018-2023 aggregate counts agree for this briefing."
}
else {
    display as error "Differences require analyst review before v2 is accepted."
}

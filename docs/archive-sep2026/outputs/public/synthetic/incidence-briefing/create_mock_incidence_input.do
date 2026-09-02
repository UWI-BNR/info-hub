/*
* =====================================================================
 DO-FILE:     create_mock_incidence_input.do
 PROJECT:     BNR info-hub
 PURPOSE:     Create a synthetic Step 3 incidence input with low counts

 IMPORTANT:
   - This file creates TEST DATA ONLY.
   - It does not read, alter, or overwrite the genuine BNR dataset.
   - Every identifier begins with SYNTHETIC.
   - The output filename includes mock_low_counts so that it cannot be
     mistaken for the operational Step 3 input.

 USAGE:
   do create_mock_incidence_input.do

   Or supply a different output folder:

   do create_mock_incidence_input.do "C:/path/to/test/folder"

 OUTPUTS:
   bnr_cvd_input_count_202401_v01_mock_low_counts.dta
   bnr_cvd_input_count_202401_v01_mock_low_counts.yml
* =====================================================================
*/


* ============================================================================
* INITIALISE
* ============================================================================

clear all
set more off


* ============================================================================
* READ THE OPTIONAL OUTPUT FOLDER
* ============================================================================
* If no folder is supplied, the files are written to Stata's current folder.

args output_folder

if `"`output_folder'"' == "" {
    local output_folder "`c(pwd)'"
}

local mock_id "bnr_cvd_input_count_202401_v01_mock_low_counts"
local mock_dta "`output_folder'/`mock_id'.dta"
local mock_yml "`output_folder'/`mock_id'.yml"


* ============================================================================
* CREATE ONE ROW FOR EVERY YEAR / EVENT / SEX / DCO DESIGN CELL
* ============================================================================
* The ordinary test cells contain:
*   - 18 hospital-ascertained events; and
*   -  2 additional death-certificate-only events.
*
* These comfortably large cells allow the incidence calculations and figures
* to run while selected cells below are deliberately reduced.

clear
set obs 14

generate int yoe = 2009 + _n

expand 2
bysort yoe: generate byte etype = _n

expand 2
bysort yoe etype: generate byte sex = _n

expand 2
bysort yoe etype sex: generate byte dco = _n - 1

generate int n_events = 18 if dco == 0
replace n_events = 2 if dco == 1


* ============================================================================
* DELIBERATELY CREATE LOW, ZERO, THRESHOLD, AND PASSING CELLS
* ============================================================================
* Event type: 1 = Stroke; 2 = AMI
* Sex:        1 = Female; 2 = Male
* DCO:        0 = Hospital-ascertained; 1 = additional DCO events
*
* The incidence script creates two versions of each annual count:
*   dco = 0 : hospital events only
*   dco = 1 : hospital events plus DCO events

* 2023 Stroke, women: 3 hospital + 2 DCO = 5 with DCO.
replace n_events = 3 if yoe == 2023 & etype == 1 & sex == 1 & dco == 0
replace n_events = 2 if yoe == 2023 & etype == 1 & sex == 1 & dco == 1

* 2023 Stroke, men: exactly 6, testing the unsuppressed boundary.
replace n_events = 6 if yoe == 2023 & etype == 1 & sex == 2 & dco == 0
replace n_events = 0 if yoe == 2023 & etype == 1 & sex == 2 & dco == 1

* 2023 AMI, women: 7, immediately above the threshold.
replace n_events = 7 if yoe == 2023 & etype == 2 & sex == 1 & dco == 0
replace n_events = 0 if yoe == 2023 & etype == 2 & sex == 1 & dco == 1

* 2023 AMI, men: 1 hospital + 4 DCO = 5 with DCO.
replace n_events = 1 if yoe == 2023 & etype == 2 & sex == 2 & dco == 0
replace n_events = 4 if yoe == 2023 & etype == 2 & sex == 2 & dco == 1

* 2022 AMI, women: zero with and without DCO.
* The current automatic rule flags only positive counts below 6, so this is
* deliberately a manual-review test rather than an expected automatic flag.
replace n_events = 0 if yoe == 2022 & etype == 2 & sex == 1 & dco == 0
replace n_events = 0 if yoe == 2022 & etype == 2 & sex == 1 & dco == 1

* 2022 Stroke, women: 4 hospital + 2 DCO = exactly 6 with DCO.
replace n_events = 4 if yoe == 2022 & etype == 1 & sex == 1 & dco == 0
replace n_events = 2 if yoe == 2022 & etype == 1 & sex == 1 & dco == 1

* 2021 Stroke, women: 4 hospital + 3 DCO = 7 with DCO.
replace n_events = 4 if yoe == 2021 & etype == 1 & sex == 1 & dco == 0
replace n_events = 3 if yoe == 2021 & etype == 1 & sex == 1 & dco == 1

* 2020 AMI, men: 5 hospital + 2 DCO = 7 with DCO.
replace n_events = 5 if yoe == 2020 & etype == 2 & sex == 2 & dco == 0
replace n_events = 2 if yoe == 2020 & etype == 2 & sex == 2 & dco == 1

* 2019 Stroke, men: 2 hospital and no additional DCO events.
replace n_events = 2 if yoe == 2019 & etype == 1 & sex == 2 & dco == 0
replace n_events = 0 if yoe == 2019 & etype == 1 & sex == 2 & dco == 1

* 2018 AMI, women: 2 hospital + 3 DCO = 5 with DCO.
replace n_events = 2 if yoe == 2018 & etype == 2 & sex == 1 & dco == 0
replace n_events = 3 if yoe == 2018 & etype == 2 & sex == 1 & dco == 1

* 2017 AMI: women = 2 and men = 3. The combined-sex total is 5.
* This deliberately creates both component flags and a combined-sex flag.
replace n_events = 2 if yoe == 2017 & etype == 2 & sex == 1 & dco == 0
replace n_events = 0 if yoe == 2017 & etype == 2 & sex == 1 & dco == 1
replace n_events = 3 if yoe == 2017 & etype == 2 & sex == 2 & dco == 0
replace n_events = 0 if yoe == 2017 & etype == 2 & sex == 2 & dco == 1

* 2016 Stroke, women: zero hospital events but 4 DCO events.
replace n_events = 0 if yoe == 2016 & etype == 1 & sex == 1 & dco == 0
replace n_events = 4 if yoe == 2016 & etype == 1 & sex == 1 & dco == 1


* ============================================================================
* EXPAND THE DESIGN CELLS INTO ONE SYNTHETIC RECORD PER EVENT
* ============================================================================
* Zero-event cells correctly have no event records in an event-level dataset.
* The incidence analysis recreates those zero cells during its fill-in stage.

drop if n_events == 0
expand n_events

bysort yoe etype sex dco: generate int event_sequence = _n

* Ordinary 18-event hospital cells cover all 18 five-year age groups.
* Smaller cells are placed among adult age groups 50 years and older.
generate byte age5 = mod(event_sequence - 1, 18) + 1 ///
    if n_events >= 18
replace age5 = 11 + mod(event_sequence - 1, 8) if missing(age5)

generate int agey = ((age5 - 1) * 5) + 2
replace agey = 87 if age5 == 18

generate byte age70 = agey >= 70

generate byte moe = mod(event_sequence + etype + sex - 3, 12) + 1
generate int doe = mdy(moe, mod(event_sequence - 1, 27) + 1, yoe)
format doe %tdCCYY-NN-DD

generate byte dco_alt = dco
generate str18 eid = "SYNTHETIC" + string(_n, "%09.0f")

drop n_events event_sequence


* ============================================================================
* APPLY THE OPERATIONAL VARIABLE ORDER, LABELS, AND VALUE LABELS
* ============================================================================

order eid dco dco_alt etype doe yoe moe sex agey age5 age70
sort yoe moe doe etype sex dco eid

label variable eid     "CVD event unique identifier"
label variable dco     "Death-certificate-only case"
label variable dco_alt "Abstraction status"
label variable etype   "CVD event type"
label variable doe     "Date of Event"
label variable yoe     "CVD event year"
label variable moe     "CVD event month"
label variable sex     "Sex at birth"
label variable agey    "Age at event in completed years"
label variable age5    "Age at event in 5-year groups"
label variable age70   "Age at event: under 70 or 70+"

label define dco_ 0 "Abstracted" 1 "DCO"
label values dco dco_

label define dco_alt_ 0 "Abstracted" 1 "DCO" 2 "Partial abstraction"
label values dco_alt dco_alt_

label define etype_ 1 "Stroke" 2 "AMI"
label values etype etype_

label define sex_ 1 "Female" 2 "Male"
label values sex sex_

label define age5_ ///
     1 "0-4"   2 "5-9"   3 "10-14" 4 "15-19" ///
     5 "20-24" 6 "25-29" 7 "30-34" 8 "35-39" ///
     9 "40-44" 10 "45-49" 11 "50-54" 12 "55-59" ///
     13 "60-64" 14 "65-69" 15 "70-74" 16 "75-79" ///
     17 "80-84" 18 "85+"
label values age5 age5_

label define age70_ 0 "Under 70 years" 1 "70 years and older"
label values age70 age70_

label data "SYNTHETIC BNR CVD incidence input: low-count disclosure test"
notes _dta: TEST DATA ONLY - NOT REAL BNR EVENTS AND NOT FOR PUBLICATION
notes _dta: Purpose: exercise the analyst-led briefing disclosure review
notes _dta: Expected automatic positive-numerator flags below 6: 18


* ============================================================================
* VERIFY THE SYNTHETIC DATASET BEFORE SAVING
* ============================================================================

assert _N == 919
isid eid
assert inrange(yoe, 2010, 2023)
assert inlist(etype, 1, 2)
assert inlist(sex, 1, 2)
assert inlist(dco, 0, 1)
assert age5 == floor(age5) & inrange(age5, 1, 18)
assert age70 == (agey >= 70)
assert year(doe) == yoe
assert month(doe) == moe


* ============================================================================
* SAVE THE MOCK DTA FILE
* ============================================================================

save "`mock_dta'", replace


* ============================================================================
* WRITE A SMALL COMPANION YML FILE
* ============================================================================
* The operational incidence script confirms that the companion YML exists.

capture file close mock_metadata
file open mock_metadata using "`mock_yml'", write text replace
file write mock_metadata "dataset_id: `mock_id'" _n
file write mock_metadata "status: synthetic_test_data" _n
file write mock_metadata "created: `c(current_date)'" _n
file write mock_metadata "release: 2024-01" _n
file write mock_metadata "coverage_start: 2010" _n
file write mock_metadata "coverage_end: 2023-12-31" _n
file write mock_metadata "unit_of_analysis: one_synthetic_cvd_event" _n
file write mock_metadata "records_total: 919" _n
file write mock_metadata "expected_positive_numerator_flags_below_6: 18" _n
file write mock_metadata "direct_identifiers_present: false" _n
file write mock_metadata "synthetic: true" _n
file write mock_metadata "publication_authorised: false" _n
file write mock_metadata "warning: TEST DATA ONLY - NOT REAL BNR EVENTS" _n
file write mock_metadata "variables:" _n
file write mock_metadata "  - eid" _n
file write mock_metadata "  - dco" _n
file write mock_metadata "  - dco_alt" _n
file write mock_metadata "  - etype" _n
file write mock_metadata "  - doe" _n
file write mock_metadata "  - yoe" _n
file write mock_metadata "  - moe" _n
file write mock_metadata "  - sex" _n
file write mock_metadata "  - agey" _n
file write mock_metadata "  - age5" _n
file write mock_metadata "  - age70" _n
file close mock_metadata


* ============================================================================
* PRINT ONE CLEAR TEST-DATA SUMMARY
* ============================================================================

display as text _n ///
    "------------------------------------------------------------" _n ///
    "SYNTHETIC INCIDENCE INPUT CREATED" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Records:              919" _n ///
    as result "  Years:                2010-2023" _n ///
    as result "  Expected auto-flags:  18" _n ///
    as result "  DTA: `mock_dta'" _n ///
    as result "  YML: `mock_yml'" _n ///
    as error  "  TEST DATA ONLY - DO NOT PUBLISH" _n ///
    as text   "------------------------------------------------------------" _n

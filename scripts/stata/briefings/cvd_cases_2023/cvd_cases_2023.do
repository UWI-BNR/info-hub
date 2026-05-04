/* 
* =====================================================================
 DO-FILE:     cvd_cases_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD case-count briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.0

 NOTES:
   This DO file creates the approved output bundle for the static
   2023 CVD case-count briefing.

   It does not create the final PDF briefing.
   Publication layout is handled by Quarto.

 OUTPUT BUNDLE:
  STAGING: outputs/staging/briefings/cvd_cases_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_cases_2023_v1/

  readme.txt

  datasets/
    cvd_cases_weekly.dta
    cvd_cases_weekly.csv
    cvd_cases_weekly.yml
    cvd_cases_age_group.dta
    cvd_cases_age_group.csv
    cvd_cases_age_group.yml

  figures/
    cvd_cases_weekly.png
    cvd_cases_age_group.png

  workbook/
    bnr_cvd_cases_2023_v1.xlsx

  metadata/
    briefing.yml

  ZIP:
    bnr_cvd_cases_2023_v1.zip
    Stored inside the public briefing folder.
* =====================================================================
*/


* ==============================================================
* DO NOT TOUCH: INITIALIZE DO FILE 
* ==============================================================
clear all
set more off

* ==============================================================
* DO NOT TOUCH:    SET LOCAL PATH LOCATION
*                  AND LOAD SHARED SETTINGS 
* ==============================================================
local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"
do "`localpath'/scripts/stata/common/bnrcvd_globals.do"

** ==============================================================
** EDIT BLOCK A: BRIEFING SETTINGS
** ==============================================================
* For a new briefing, start here.
* Change these local macros before changing the standard release machinery.
local target_year       2023
local baseline_start    2018
local baseline_end      2022
local briefing_id       "cvd_cases_2023_v1"
local briefing_name     "cvd_cases_2023"
local output1           "cvd_cases_weekly"
local output2           "cvd_cases_age_group"


* Private log file
cap log close
log using "$BNR_PRIVATE_LOGS/`briefing_name'", replace


* ==============================================================
* DO NOT TOUCH: STANDARD OUTPUT FOLDER SETUP
* ==============================================================
* The staging folder is the build area.
* The public folder is the approved release copy created at the end (see section 10 below)

* STAGING OUTPUT bundle locations
* Ensure locations exist
local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures "`stagingbriefing'/figures"
local stagingworkbook "`stagingbriefing'/workbook"
local stagingmetadata "`stagingbriefing'/metadata"
cap mkdir "$BNR_STAGING/briefings"
cap mkdir "`stagingbriefing'"
cap mkdir "`stagingdatasets'"
cap mkdir "`stagingfigures'"
cap mkdir "`stagingworkbook'"
cap mkdir "`stagingmetadata'"

display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD case-count briefing build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:     `briefing_id'" _n ///
    as result "  Target year:     `target_year'" _n ///
    as result "  Baseline:        `baseline_start'-`baseline_end'" _n ///
    as result "  Staging bundle:  `stagingbriefing'" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================
* DO NOT TOUCH: PREPARE SHARED 2023 CVD ANALYSIS DATA
* ==============================================================
* ----- PREPARE SHARED 2023 CVD ANALYSIS DATA ----
* This creates the private prepared datasets used by the 2023 briefings.
qui do "scripts/stata/common/bnrcvd_prep_2023_v1.do"




** ==============================================================
** EDIT BLOCK B: BRIEFING-SPECIFIC DATA PREPARATION AND ANALYSIS
** ==============================================================
* For a new briefing, adapt Sections B1, B3, B4, B5, and B6 as needed.
* The standard release pattern is:
*   1. create final public dataset
*   2. label variables
*   3. add structured dataset notes using notes _dta:
*   4. export CSV and save DTA to stagingdatasets/
*   5. export related figure to stagingfigures/, if relevant

** ==============================================================
** (EDIT BLOCK - SECTION B1): LOAD PREPARED COUNT DATASET
** ==============================================================
use "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta", clear

* Broad restrictions
drop if dco == 1
drop dco
drop if yoe == 2009

* Keep only the years required for this static briefing
keep if inrange(yoe, `baseline_start', `target_year')

* Safety checks for the static briefing
count if yoe == `target_year'
if r(N) == 0 {
    display as error "No observations found for target year `target_year'."
    exit 2000
}

count if inrange(yoe, `baseline_start', `baseline_end')
if r(N) == 0 {
    display as error "No observations found for baseline period `baseline_start'-`baseline_end'."
    exit 2000
}


** =========================================================================
** (EDIT BLOCK - SECTION B2): 
**                      INTERNAL TABLE: 2023 CASES BY SEX AND EVENT TYPE
**                                      This table is not published for now.
** =========================================================================
    gen event = 1 

** Count by year / event type 
    #delimit ; 
    table (yoe) (etype), 
            nototals
            statistic(count event) 
            ;
    #delimit cr

** Count by year / event type and sex 
    #delimit ; 
    table (yoe) (etype sex), 
            nototals
            statistic(count event) 
            ;
    #delimit cr


** =============================================================================
** (EDIT BLOCK - SECTION B3): 
**                      INTERNAL TABLE: 2023 CASES BY AGE70, SEX, AND EVENT TYPE
**                                      This table is not published for now.
** =====================================+++++++++++++++=========================

    
    ** Percentage 70+ - by sex / event type
    #delimit ; 
    table (sex) (etype age70), 
            nototals
            statistic(percent, across(age70)) 
            ;
    #delimit cr 

** Percentage 70+ - by sex and year / event type
    #delimit ; 
    table (sex yoe) (etype age70), 
            nototals
            statistic(percent, across(age70)) 
            ;
    #delimit cr 


** ==============================================================
** (EDIT BLOCK - SECTION B4): 
**              RELEASED DATASET AND FIGURE 1:
**              CUMULATIVE WEEKLY COUNT, 2023 VS BASELINE
** ==============================================================
* EDITABLE FOR NEW BRIEFINGS.
* This section creates:
*   - datasets/cvd_cases_weekly.dta
*   - datasets/cvd_cases_weekly.csv
*   - figures/cvd_cases_weekly.png

preserve

    gen woe = week(doe)

    collapse (sum) event, by(yoe woe etype)

    sort etype yoe woe
    bysort etype yoe: gen cevent = sum(event)

    gen period = .
    replace period = 2 if inrange(yoe, `baseline_start', `baseline_end')
    replace period = 3 if yoe == `target_year'
    keep if inlist(period, 2, 3)

    collapse (sum) event, by(period woe etype)

    sort period etype woe
    bysort period etype: gen cevent = sum(event)

    replace event  = event  / 5 if period == 2
    replace cevent = cevent / 5 if period == 2

    reshape wide event cevent, i(etype woe) j(period)

    gen cases_diff_cum = cevent3 - cevent2

    rename event2 eventbase 
    rename cevent2 ceventbase 
    rename event3 event 
    rename cevent3 cevent 
    label var etype           "Event type"
    label var woe             "Week of year"
    label var eventbase       "Baseline average weekly cases, 2018-2022"
    label var ceventbase      "Baseline average cumulative cases, 2018-2022"
    label var event           "Weekly cases, 2023"
    label var cevent          "Cumulative cases, 2023"
    label var cases_diff_cum  "2023 cumulative cases minus baseline average"

    ** STANDARD RELEASE PATTERN FOR THIS DATASET
    ** The CSV is the open data file; the DTA carries labels and notes.
    ** For future templates, keep this save/export pattern unless the
    ** release standard changes.

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output1'.csv", replace

    ** DTA DATASET EXPORT
    notes drop _all

    label data "BNR-CVD Registry: weekly case-count data for 2023 CVD briefing"

    notes _dta: title: Weekly hospital CVD cases, Barbados, 2023
    notes _dta: version: v1
    notes _dta: created: 2026-05-04
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Weekly and cumulative aggregate case counts
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2018-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by week of year
    notes _dta: description: Weekly and cumulative hospital-ascertained stroke and heart attack case counts for 2023 compared with the 2018-2022 annual average.
    notes _dta: limitations: Counts describe hospital-ascertained cases and should not be interpreted as population incidence.
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: Barbados National Registry approved cardiovascular registry extract
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output1'.dta", replace 

    #delimit ;
        graph twoway
            (function y=0, range(1 52) lc(gs8%50) lp("_") lw(0.75))
            (line cases_diff_cum woe if etype==1, lw(1) color("${str_m}"))
            (line cases_diff_cum woe if etype==2, lw(1) color("${ami_m}"))
            ,
                plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))
                graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))
                ysize(4) xsize(16)

                xlab(none,
                valuelabel labc(gs0) labs(2.5) notick nogrid glc(gs16) angle(45) format(%9.0f))
                xscale(noline lw(vthin))
                xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1))

                ylab(,
                labc(gs0) labs(7) tlc(gs8) nogrid glc(gs16) angle(0) format(%9.0f))
                yscale(lw(vthin) lc(gs8) noextend range(-40(10)70))
                ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1))

                text(6.5 52 "5-year average", place(w) size(8) color(gs4))
                text(-40 26 "Cumulative CVD cases in 2023 compared to 5-year average (2018-2022)", place(c) size(8) color(gs4))

                legend(off)
                name(cases_2023_cum_week, replace)
                ;
    #delimit cr

    graph export "`stagingfigures'/`output1'.png", replace width(3000)

restore


** ==============================================================
** (EDIT BLOCK - SECTION B5): 
**                  RELEASED DATASET AND FIGURE 2:
**                  AGE70 DISTRIBUTION, 2023 VS BASELINE
** ==============================================================
* EDITABLE FOR NEW BRIEFINGS.
* This section creates:
*   - datasets/cvd_cases_age_group.dta
*   - datasets/cvd_cases_age_group.csv
*   - figures/cvd_cases_age_group.png

preserve

    gen period = .
    replace period = 2 if inrange(yoe, `baseline_start', `baseline_end')
    replace period = 3 if yoe == `target_year'
    keep if inlist(period, 2, 3)

    collapse (sum) event, by(period etype sex age70)

    sort etype sex period age70

    bysort etype sex period: egen denom = total(event)

    replace event = event / 5 if period == 2
    replace denom = denom / 5 if period == 2

    gen perc = (event / denom) * 100

    * Keep the under-70 proportion for plotting.
    * The graph displays this against the complementary 70+ proportion.
    keep if age70 == 0

    gen zero = 0
    gen p100 = 100

    * Visual offset for AMI panels
    replace perc = perc + 110 if etype == 2
    replace zero = zero + 110 if etype == 2
    replace p100 = p100 + 110 if etype == 2

    * Legend location
    local legend_square1 2 225    1.5 225    1.5 230     2 230    2 225
    local legend_square2 2 231    1.5 231    1.5 236     2 236    2 231
    local legend_circle1 1 227.5
    local legend_circle2 1 233.5

    #delimit ;
        graph twoway
            (rbar p100 perc sex if period==2 & etype==1 & sex==1, horizontal barwidth(.5) lc("${str_m70}") lw(0.05) fc("${str_m70}"))
            (rbar zero perc sex if period==2 & etype==1 & sex==1, horizontal barwidth(.5) lc("${str_m}") lw(0.05) fc("${str_m}"))

            (rbar p100 perc sex if period==2 & etype==1 & sex==2, horizontal barwidth(.5) lc("${str_m70}") lw(0.05) fc("${str_m70}"))
            (rbar zero perc sex if period==2 & etype==1 & sex==2, horizontal barwidth(.5) lc("${str_m}") lw(0.05) fc("${str_m}"))

            (scatter sex perc if period==3 & etype==1 & sex==1, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${str_m70}"))
            (scatter sex perc if period==3 & etype==1 & sex==2, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${str_m70}"))

            (rbar p100 perc sex if period==2 & etype==2 & sex==1, horizontal barwidth(.5) lc("${ami_m70}") lw(0.05) fc("${ami_m70}"))
            (rbar zero perc sex if period==2 & etype==2 & sex==1, horizontal barwidth(.5) lc("${ami_m}") lw(0.05) fc("${ami_m}"))

            (rbar p100 perc sex if period==2 & etype==2 & sex==2, horizontal barwidth(.5) lc("${ami_m70}") lw(0.05) fc("${ami_m70}"))
            (rbar zero perc sex if period==2 & etype==2 & sex==2, horizontal barwidth(.5) lc("${ami_m}") lw(0.05) fc("${ami_m}"))

            (scatter sex perc if period==3 & etype==2 & sex==1, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${ami_m70}"))
            (scatter sex perc if period==3 & etype==2 & sex==2, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${ami_m70}"))

            (function y=2.75, range(220 220) dropline(220) lc(gs4) lw(0.4))
            (scatteri `legend_square1', recast(area) lw(none) fc("${str_m70}"))
            (scatteri `legend_square2', recast(area) lw(none) fc("${ami_m70}"))
            (scatteri `legend_circle1', msize(7) lw(none) mc("${str_m70}"))
            (scatteri `legend_circle2', msize(7) lw(none) mc("${ami_m70}"))

            ,
            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin))
            graphregion(c(gs16) ic(gs16) ilw(thin) lw(thin))
            ysize(4) xsize(20)

            xlabel(none, labsize(10) notick nogrid labcolor(gs4))
            xscale(noline noextend range(0(10)275))
            xtitle(" ", margin(top) color(gs0) size(2.5))

            ylabel(
                    2 "Men"
                    1 "Women"
            , notick nogrid valuelabel angle(0) labsize(10) labcolor(gs4))
            ytitle(" ", axis(1))
            yscale(noline range(0(0.25)2.75))

            text(1.75 240 "2018-2022", place(e) size(10) color(gs4))
            text(1 240 "2023", place(e) size(10) color(gs4))
            text(-0.2 105 "Proportion 70 years and older with a hospitalised heart attack or stroke", place(c) size(10) color(gs4))
            text(2.75 5 "<70 yrs", place(e) size(10) color(${str_m}) margin(0 0 0 0))
            text(2.75 95 "70+ yrs", place(w) size(10) color(${str_m70}) margin(0 0 0 0))
            text(2.75 115 "<70 yrs", place(e) size(10) color(${ami_m}) margin(0 0 0 0))
            text(2.75 205 "70+ yrs", place(w) size(10) color(${ami_m70}) margin(0 0 0 0))

            text(0.45 50 "50", place(c) size(10) color(gs4) margin(0 0 0 0))
            text(0.45 100 "100", place(c) size(10) color(gs4) margin(0 0 0 0))
            text(0.45 160 "50", place(c) size(10) color(gs4) margin(0 0 0 0))
            text(0.45 210 "100", place(c) size(10) color(gs4) margin(0 0 0 0))

            legend(off)
            name(cases_2023_age70, replace)
            ;
    #delimit cr

    graph export "`stagingfigures'/`output2'.png", replace width(3000)

    * Remove graph-only offset before exporting figure-ready data
    replace perc = perc - 110 if etype == 2
    drop zero p100

    label define period_ 2 "5-year baseline, 2018-2022" 3 "2023", replace
    label values period period_

    label var period "Time period"
    label var etype  "Event type"
    label var sex    "Sex"
    label var age70  "Age group"
    label var event  "Event count. For baseline, annual average."
    label var denom  "Total event count. For baseline, annual average."
    label var perc   "Percentage under 70 years"

    ** STANDARD RELEASE PATTERN FOR THIS DATASET
    ** The CSV is the open data file; the DTA carries labels and notes.
    ** For future templates, keep this save/export pattern unless the
    ** release standard changes.

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output2'.csv", replace

    ** DTA DATASET EXPORT
    notes drop _all

    label data "BNR-CVD Registry: age-group case-count data for 2023 CVD briefing"

    notes _dta: title: Hospital CVD cases by broad age group, Barbados, 2023
    notes _dta: version: v1
    notes _dta: created: 2026-05-04
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Aggregate age-group distribution for hospital-ascertained CVD cases
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2018-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by sex and period
    notes _dta: description: Aggregated hospital-ascertained stroke and heart attack case counts by sex and broad age group, comparing 2023 with the 2018-2022 annual average.
    notes _dta: limitations: This dataset is prepared for the age-distribution figure. The percentage variable records the percentage under 70 years; the percentage aged 70 years and older is its complement.
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: Barbados National Registry approved cardiovascular registry extract
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output2'.dta", replace 

restore



** ==============================================================
** DO NOT TOUCH: STANDARD METADATA, WORKBOOK, AND PUBLISH STEPS
** ==============================================================
* Sections 7-10 create release metadata, workbook, public copy, and ZIP.
* Do not edit these sections for a new briefing unless the release
* package standard changes. Dataset-specific information should come
* from the DTA labels, DTA notes, and the briefing settings above.

** ==============================================================
** (EDIT BLOCK - SECTION B7): 
**              CREATE DATASET-LEVEL YAML METADATA FILES
** ==============================================================
* Need to edit filenames to match those created in analyses above 
bnr_yml, ///
    dtafile("`stagingdatasets'/`output1'.dta") ///
    ymlfile("`stagingmetadata'/`output1'.yml") ///
    datasetid("`output1'")

bnr_yml, ///
    dtafile("`stagingdatasets'/`output2'.dta") ///
    ymlfile("`stagingmetadata'/`output2'.yml") ///
    datasetid("`output2'")



** ==============================================================
** (EDIT BLOCK - SECTION B8): 
**          CREATE BRIEFING-LEVEL YAML METADATA FILE
** ==============================================================
* Need to edit metadata details
* Purpose:
*   Create one short metadata file for the briefing output bundle.
*
* Dataset-specific metadata are stored in:
*   metadata/cvd_cases_weekly.yml
*   metadata/cvd_cases_age_group.yml
*
* Output:
*   metadata/briefing.yml

tempname briefingyml

file open `briefingyml' using "`stagingmetadata'/briefing.yml", ///
    write replace text

file write `briefingyml' "schema: bnr_briefing_metadata_v1" _n
file write `briefingyml' "briefing_id: `briefing_id'" _n
file write `briefingyml' "" _n

file write `briefingyml' "title: |-" _n
file write `briefingyml' "  Hospital cardiovascular cases in Barbados, 2023" _n
file write `briefingyml' "" _n

file write `briefingyml' "description: |-" _n
file write `briefingyml' "  Public aggregate output package for the BNR CVD case-count briefing." _n
file write `briefingyml' "" _n

file write `briefingyml' "registry: BNR-CVD" _n
file write `briefingyml' "geography: Barbados" _n
file write `briefingyml' "target_year: `target_year'" _n
file write `briefingyml' "baseline_period: `baseline_start'-`baseline_end'" _n
file write `briefingyml' "" _n

file write `briefingyml' "limitations: |-" _n
file write `briefingyml' "  Counts describe hospital-ascertained cases and should not be interpreted as population incidence." _n
file write `briefingyml' "" _n

file write `briefingyml' "datasets:" _n
file write `briefingyml' "  - id: `output1'" _n
file write `briefingyml' "    dta: datasets/`output1'.dta" _n
file write `briefingyml' "    csv: datasets/`output1'.csv" _n
file write `briefingyml' "    yml: metadata/`output1'.yml" _n
file write `briefingyml' "  - id: `output2'" _n
file write `briefingyml' "    dta: datasets/`output2'.dta" _n
file write `briefingyml' "    csv: datasets/`output2'.csv" _n
file write `briefingyml' "    yml: metadata/`output2'.yml" _n
file write `briefingyml' "" _n

file write `briefingyml' "figures:" _n
file write `briefingyml' "  - id: `output1'" _n
file write `briefingyml' "    file: figures/`output1'.png" _n
file write `briefingyml' "    source_dataset: `output1'" _n
file write `briefingyml' "  - id: `output2'" _n
file write `briefingyml' "    file: figures/`output2'.png" _n
file write `briefingyml' "    source_dataset: `output2'" _n
file write `briefingyml' "" _n

file write `briefingyml' "rights: |-" _n
file write `briefingyml' "  Public release. Cite the Barbados National Registry when reusing." _n
file write `briefingyml' "" _n

file write `briefingyml' "contact: |-" _n
file write `briefingyml' "  Barbados National Registry." _n
file write `briefingyml' "" _n

file write `briefingyml' "build:" _n
file write `briefingyml' "  build_date: `c(current_date)'" _n
file write `briefingyml' "  analysis_script: scripts/stata/briefings/cvd_cases_2023/`briefing_name'.do" _n

file close `briefingyml'

display as result "Briefing-level YAML created:"
display as result "  `stagingmetadata'/briefing.yml"



** ==============================================================
** (SECTION 9) CREATE XLSX WORKBOOK BUNDLE
** ==============================================================
*
* Purpose:
*   Create a human-friendly Excel workbook from the released Stata
*   datasets already saved in the staging bundle.
*
* The workbook is a convenience copy only.
* The canonical public files remain:
*   - DTA files
*   - CSV files
*   - YML metadata files
*
* Workbook sheets:
*   readme
*   cvd_cases_weekly
*   meta_weekly
*   vars_weekly
*   cvd_cases_age_group
*   meta_age_group
*   vars_age_group

local workbook_file "`stagingworkbook'/bnr_`briefing_id'.xlsx"

cap erase "`workbook_file'"


** ==============================================================
** 9.0 Create simple README text file
** ==============================================================

tempname readme

file open `readme' using "`stagingbriefing'/readme.txt", ///
    write replace text

file write `readme' "BNR CVD case-count briefing output package" _n
file write `readme' "" _n
file write `readme' "Briefing ID: `briefing_id'" _n
file write `readme' "Target year: `target_year'" _n
file write `readme' "Baseline period: `baseline_start'-`baseline_end'" _n
file write `readme' "" _n
file write `readme' "This package contains public aggregate outputs for the BNR CVD case-count briefing." _n
file write `readme' "" _n
file write `readme' "Contents:" _n
file write `readme' "- datasets/: DTA, CSV, and YML files for each released dataset" _n
file write `readme' "- figures/: PNG figures used in the briefing" _n
file write `readme' "- workbook/: Excel workbook containing data and metadata sheets" _n
file write `readme' "- metadata/: briefing-level metadata" _n
file write `readme' "" _n
file write `readme' "The DTA files contain Stata labels, value labels, and dataset notes." _n
file write `readme' "The CSV files are open machine-readable versions of the released datasets." _n
file write `readme' "The YML files contain metadata exported from the Stata datasets." _n
file write `readme' "" _n
file write `readme' "These are aggregate hospital-ascertained case counts and should not be interpreted as population incidence." _n
file write `readme' "" _n
file write `readme' "Please cite the Barbados National Registry when reusing these outputs." _n

file close `readme'




** ==============================================================
** 9.1 Create workbook README sheet
** ==============================================================

clear
set obs 9

gen str40  field = ""
gen str200 value = ""

replace field = "Briefing ID" in 1
replace value = "`briefing_id'" in 1

replace field = "Title" in 2
replace value = "Hospital cardiovascular cases in Barbados, 2023" in 2

replace field = "Target year" in 3
replace value = "`target_year'" in 3

replace field = "Baseline period" in 4
replace value = "`baseline_start'-`baseline_end'" in 4

replace field = "Registry" in 5
replace value = "BNR-CVD" in 5

replace field = "Geography" in 6
replace value = "Barbados" in 6

replace field = "Contents" in 7
replace value = "Data sheets, dataset metadata sheets, and variable metadata sheets" in 7

replace field = "Data note" in 8
replace value = "Aggregate hospital-ascertained case counts" in 8

replace field = "Limitation" in 9
replace value = "Counts should not be interpreted as population incidence" in 9

export excel using "`workbook_file'", ///
    sheet("readme") firstrow(variables) replace


** ==============================================================
** 9.2 Add weekly cases dataset and metadata
** ==============================================================

bnr_workbook, ///
    dtafile("`stagingdatasets'/`output1'.dta") ///
    xlsxfile("`workbook_file'") ///
    datasetid("`output1'") ///
    datasheet("`output1'") ///
    metasheet("meta_weekly") ///
    varsheet("vars_weekly")


** ==============================================================
** 9.3 Add age-group cases dataset and metadata
** ==============================================================

bnr_workbook, ///
    dtafile("`stagingdatasets'/`output2'.dta") ///
    xlsxfile("`workbook_file'") ///
    datasetid("`output2'") ///
    datasheet("`output2'") ///
    metasheet("meta_age_group") ///
    varsheet("vars_age_group")


display as result "Workbook created:"
display as result "  `workbook_file'"





** ==============================================================
** (SECTION 10) PUBLISH STAGING BUNDLE TO PUBLIC RELEASE FOLDER
** ==============================================================
*
* Purpose:
*   Copy the completed staging bundle into the public release area
*   and create a ZIP package for public download.
*
* Source:
*   outputs/staging/briefings/{briefing_id}/
*
* Target:
*   outputs/public/briefings/{briefing_id}/
*
* ZIP:
*   outputs/public/briefings/{briefing_id}/bnr_{briefing_id}.zip
*
* This block does not create analytical outputs.
* It only copies files already created in staging.

** ==============================================================
** 10.1 Define public release folders and ZIP path
** ==============================================================

local publicbriefing "$BNR_PUBLIC/briefings/`briefing_id'"
local publicdatasets "`publicbriefing'/datasets"
local publicfigures  "`publicbriefing'/figures"
local publicworkbook "`publicbriefing'/workbook"
local publicmetadata "`publicbriefing'/metadata"

local publiczip "`publicbriefing'/bnr_`briefing_id'.zip"


** ==============================================================
** 10.2 Ensure public release folders exist
** ==============================================================

cap mkdir "$BNR_PUBLIC"
cap mkdir "$BNR_PUBLIC/briefings"

cap mkdir "`publicbriefing'"
cap mkdir "`publicdatasets'"
cap mkdir "`publicfigures'"
cap mkdir "`publicworkbook'"
cap mkdir "`publicmetadata'"


** ==============================================================
** 10.3 Remove old files from public release folders
** ==============================================================
*
* This prevents old files remaining in public/ after a filename change
* or after a file is removed from the staging bundle.

local oldfiles : dir "`publicbriefing'" files "*"
foreach file of local oldfiles {
    erase "`publicbriefing'/`file'"
}

foreach folder in datasets figures workbook metadata {

    local oldfiles : dir "`publicbriefing'/`folder'" files "*"

    foreach file of local oldfiles {
        erase "`publicbriefing'/`folder'/`file'"
    }
}

cap erase "`publiczip'"


** ==============================================================
** 10.4 Copy root-level files
** ==============================================================

copy "`stagingbriefing'/readme.txt" ///
     "`publicbriefing'/readme.txt", replace


** ==============================================================
** 10.5 Copy staged subfolder files
** ==============================================================

foreach folder in datasets figures workbook metadata {

    local files : dir "`stagingbriefing'/`folder'" files "*"

    foreach file of local files {

        copy "`stagingbriefing'/`folder'/`file'" ///
             "`publicbriefing'/`folder'/`file'", replace
    }
}


** ==============================================================
** 10.6 Create ZIP package from public release folder
** ==============================================================
*
* The ZIP contains the briefing folder itself, so extraction creates
* a clean top-level folder rather than scattering files.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -LiteralPath '`publicbriefing'' -DestinationPath '`publiczip'' -Force"


** ==============================================================
** 10.7 Confirm public release bundle
** ==============================================================

display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD case-count briefing public bundle prepared" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:       `briefing_id'" _n ///
    as result "  Staging folder:    `stagingbriefing'" _n ///
    as result "  Public folder:     `publicbriefing'" _n ///
    as result "  ZIP package:       `publiczip'" _n ///
    as text "------------------------------------------------------------" _n

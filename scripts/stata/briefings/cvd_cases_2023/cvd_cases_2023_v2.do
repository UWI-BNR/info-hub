/* 
* =====================================================================
 DO-FILE:     cvd_cases_2023_v2.do
 PROJECT:     BNR info-hub
 PURPOSE:     Build the re-engineered 2023 CVD case-count briefing

 AUTHOR:      Ian R Hambleton
 VERSION:     v2.0

 NOTES:
   This DO file is the analyst-owned build file for the 2023 CVD
   case-count briefing.

   The design principle is:

     One briefing or output package = one analyst-owned DO file.

   This file should contain all briefing-specific analytical work:
     - loading the prepared CVD analysis dataset;
     - deriving the released datasets;
     - applying variable labels and dataset notes;
     - exporting CSV/DTA files into the staging folder;
     - exporting PNG figures into the staging folder;
     - writing a small release-control file for the staging helper.

   The repeated release machinery is intentionally NOT written out in
   full here. The final section calls a shared helper DO file which will
   create package metadata, README, workbook, downloads.yml, public copy,
   ZIP package, and the website mirror.

   This keeps future briefing builds simpler: a future analyst should
   copy this file, edit the settings block and the analysis section, and
   leave the standard release blocks untouched.

 OUTPUT TYPE:
   output_type = briefing

   The physical release path still uses the historical briefings/ folder
   name. In this system, that folder should be understood as the standard
   pathway for versioned public output packages created by Stata jobs.
   Most are narrative briefings, but the same pathway may also hold
   supporting artefacts, tabulations, or monitoring outputs. The specific
   type is recorded in output_type.

 OUTPUT BUNDLE:
  STAGING: outputs/staging/briefings/cvd_cases_2023_v2/
  PUBLIC:  outputs/public/briefings/cvd_cases_2023_v2/
  SITE:    site/downloads/files/briefings/cvd_cases_2023_v2/

  Created directly by this DO file:

  datasets/
    cvd_cases_monthly.dta
    cvd_cases_monthly.csv
    cvd_cases_age_group.dta
    cvd_cases_age_group.csv

  figures/
    cvd_cases_monthly.png
    cvd_cases_age_group.png

  metadata/
    release_control.yml

  Created later by the private staging helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_cases_monthly.yml
    cvd_cases_age_group.yml
    briefing.yml

  workbook/
    bnr_cvd_cases_2023_v2.xlsx

  ZIP:
    bnr_cvd_cases_2023_v2.zip
    Stored inside the public briefing folder.
* =====================================================================
*/


* ==============================================================================
* DO NOT TOUCH: INITIALIZE DO FILE
* ==============================================================================
* Keep the top of every briefing DO file predictable. This improves
* handover, makes logs easier to interpret, and reduces accidental state
* carried over from an earlier Stata session.

clear all
set more off


* ==============================================================================
* DO NOT TOUCH: SET LOCAL PROJECT PATH AND LOAD SHARED SETTINGS
* ==============================================================================
* localpath is the only machine-specific path in this DO file.
* All other important folders are defined in the shared path/config files.
*
* bnr_paths_LOCAL.do:
*   Defines local repository/output paths such as BNR_STAGING,
*   BNR_PUBLIC, BNR_PRIVATE_LOGS, and BNR_PRIVATE_WORK.
*
* bnrcvd_globals.do:
*   Defines shared CVD display settings, including graph colours and
*   other CVD-specific constants.

local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"
do "`localpath'/scripts/stata/common/bnrcvd_globals.do"


* ==============================================================================
* EDIT BLOCK A: BRIEFING / OUTPUT PACKAGE SETTINGS
* ==============================================================================
* For a new briefing, start here.
*
* Future users should usually change this block and the analysis section only.
* The standard folder setup, release-control writer, and staging helper should
* remain unchanged unless the BNR release standard itself changes.
*
* output_type distinguishes different kinds of public output package while
* preserving the existing briefings/ physical pathway:
*
*   briefing              = narrative public analytical briefing
*   supporting_artefact   = supporting figure/table/file used by the site
*   tabulation            = routine table set
*   monitoring            = QC/process/performance output
*
* This case-count output is a narrative public briefing.

local target_year       2023
local display_start     2022
local baseline_start    2018
local baseline_end      2022

* Versioned Step 3 count input. This input includes records through January 2024,
* but the briefing analysis below deliberately retains only 2018-2023.
local input_year        2024
local input_month       1
local input_version     "01"
local input_yyyymm      "202401"
local input_release     "2024-01"
local input_coverage    "2024-01-31"
local input_dataset_id  "bnr_cvd_input_count_202401_v01"
local input_file        "$BNR_DATA_DERIVED/cvd/y2024/m01/metric_inputs/bnr_cvd_input_count_202401_v01.dta"
local input_yml         "$BNR_DATA_DERIVED/cvd/y2024/m01/metric_inputs/bnr_cvd_input_count_202401_v01.yml"

local briefing_id       "cvd_cases_2023_v2"
local briefing_name     "cvd_cases_2023_v2"
local output_type       "briefing"

local briefing_title    "CVD cases in Barbados, 2023"
local briefing_short    "Cases in Barbados"
local briefing_page     "surveillance/cvd/briefings/case-counts.qmd"

local surveillance_area "CVD"
local domain            "cvd"
local registry          "BNR-CVD"
local geography         "Barbados"
local period            "`target_year'"

local briefing_description ///
    "Public aggregate output package for the BNR CVD case-count briefing."

local briefing_limitations ///
    "Counts describe hospital-ascertained cases and should not be interpreted as population incidence."

local data_note ///
    "Aggregate hospital-ascertained case counts."

local rights_note ///
    "Public release. Cite the Barbados National Registry when reusing."

local contact_note ///
    "Barbados National Registry."


* ------------------------------------------------------------------------------
* Released artefact names
* ------------------------------------------------------------------------------
* PUBLIC OUTPUT REGISTER
* The following are the only analytical datasets and figures intended for
* publication from this briefing.
*
* Dataset and figure 1: monthly AMI and stroke cases, 2022-2023, with each
*                       event type's departure from its 2018-2022 same-
*                       calendar-month average accumulated continuously over
*                       time.
* Dataset and figure 2: 2023 age-group distribution by event type and sex.
*
* No weekly dataset, cumulative weekly series, or weekly figure is public.
*
* output1 and output2 are retained because they are used in the analytical
* sections below.
*
* Each released dataset should be saved as:
*   datasets/{output}.dta
*   datasets/{output}.csv
*
* Each released figure should be saved as:
*   figures/{output}.png

local output1           "cvd_cases_monthly"
local output2           "cvd_cases_age_group"

local released_datasets "`output1' `output2'"
local released_figures  "`output1' `output2'"


* ------------------------------------------------------------------------------
* Workbook and download settings
* ------------------------------------------------------------------------------
* These settings tell the standard staging helper what convenience artefacts
* to create after the analysis has finished.
*
* create_workbook = 1 creates an XLSX workbook from released DTA datasets.
* create_zip      = 1 creates bnr_{briefing_id}.zip in public/.
* list_zip        = 1 lists the ZIP package on the central downloads page.
*
* For a supporting artefact with no public ZIP listing, use:
*   local create_workbook 0
*   local create_zip      0
*   local list_zip        0

local create_workbook   1
local create_zip        1
local list_zip          1

local workbook_file     "bnr_`briefing_id'.xlsx"

local workbook_dataset1 "`output1'"
local workbook_data1    "monthly_cases"
local workbook_meta1    "meta_monthly"
local workbook_vars1    "vars_monthly"

local workbook_dataset2 "`output2'"
local workbook_data2    "`output2'"
local workbook_meta2    "meta_age_group"
local workbook_vars2    "vars_age_group"

local zip_title ///
    "Full public output package"

local zip_description ///
    "Complete public download package containing datasets, figures, metadata, workbook, and README file."


* ==============================================================================
* DO NOT TOUCH: OPEN PRIVATE LOG
* ==============================================================================
* Logs are written outside the public release bundle. They are part of the
* private audit trail for the build and should not be published.

cap log close
log using "$BNR_PRIVATE_LOGS/`briefing_name'.log", text replace


* ==============================================================================
* DO NOT TOUCH: STANDARD STAGING FOLDER SETUP
* ==============================================================================
* The staging folder is the build area for this briefing/output package.
*
* The public folder is NOT created here. Public release and website mirroring
* are handled only after human review by a separate approval/publish helper.
*
* The physical folder name remains briefings/ for continuity with the current
* BNR publication pathway. The specific kind of output is recorded using the
* output_type local above.

local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures  "`stagingbriefing'/figures"
local stagingworkbook "`stagingbriefing'/workbook"
local stagingmetadata "`stagingbriefing'/metadata"
local stagingreview   "`stagingbriefing'/review"

cap mkdir "$BNR_STAGING/briefings"
cap mkdir "`stagingbriefing'"
cap mkdir "`stagingdatasets'"
cap mkdir "`stagingfigures'"
cap mkdir "`stagingworkbook'"
cap mkdir "`stagingmetadata'"
cap mkdir "`stagingreview'"


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD case-count briefing build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:     `briefing_id'" _n ///
    as result "  Output type:     `output_type'" _n ///
    as result "  Target year:     `target_year'" _n ///
    as result "  Baseline:        `baseline_start'-`baseline_end'" _n ///
    as result "  Staging bundle:  `stagingbriefing'" _n ///
    as text "------------------------------------------------------------" _n



* ==============================================================================
* DO NOT TOUCH: CONFIRM THE VERSIONED STEP 3 INPUT
* ==============================================================================
* The briefing reads the narrow deidentified count dataset created by Step 3.
* The old frozen-data preparation DO file is no longer part of this pathway.

capture confirm file "`input_file'"
if _rc {
    display as error "Step 3 count input not found:"
    display as error "  `input_file'"
    exit 601
}

capture confirm file "`input_yml'"
if _rc {
    display as error "Step 3 count metadata not found:"
    display as error "  `input_yml'"
    exit 601
}


** EDIT BLOCK B: BRIEFING-SPECIFIC DATA PREPARATION AND ANALYSIS
** ==============================================================
* For a new briefing, adapt the analytical sections below as needed.
* Keep the release-control and staging sections at the end unchanged unless
* the standard BNR release process itself changes.
*
* The standard dataset/figure pattern is:
*   1. create a final public aggregate dataset;
*   2. label all variables clearly;
*   3. add structured dataset notes using notes _dta:;
*   4. export CSV and save DTA to stagingdatasets/;
*   5. export related figures to stagingfigures/, if relevant.
*
* The invariant helper called later converts DTA labels and notes into
* YAML metadata and completes the private staging folder.
** ==============================================================
** (EDIT BLOCK - SECTION B1): LOAD THE STEP 3 COUNT DATASET
** ==============================================================================
use "`input_file'", clear

foreach required_variable in eid dco etype doe yoe moe sex age70 {
    capture confirm variable `required_variable'
    if _rc {
        display as error "Required variable is missing from the Step 3 count input:"
        display as error "  `required_variable'"
        exit 111
    }
}

* Death-certificate-only records are excluded from this hospital case briefing.
drop if dco == 1

* Keep only the six calendar years needed for this briefing.
keep if inrange(yoe, `baseline_start', `target_year')

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

* One explicit event counter is used throughout the briefing.
gen event = 1

** (EDIT BLOCK - SECTION B2): 
**                      INTERNAL TABLE: 2023 CASES BY SEX AND EVENT TYPE
**                                      This table is not published for now.
** =========================================================================
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
**              EVENT-SPECIFIC CUMULATIVE MONTHLY DEPARTURE FROM THE
**              FIVE-YEAR AVERAGE,
**              2022-2023
** ==============================================================================
* This section retains separate stroke and AMI series, but does not stratify
* either series by age, sex, parish, or another characteristic.
*
* It creates:
*   - datasets/cvd_cases_monthly.dta
*   - datasets/cvd_cases_monthly.csv
*   - figures/cvd_cases_monthly.png
*
* The five-year comparator is the mean count for each calendar month during
* 2018-2022. The observed monthly departure from the event-specific comparator
* is then accumulated continuously from January 2022 to December 2023. This
* produces one 24-month series per event type, each centred on zero:
*
*   above zero = cumulatively more cases than the five-year average;
*   below zero = cumulatively fewer cases than the five-year average.
*
* There is deliberately no reset at January 2023. Weekly values are not
* released.

preserve

    keep yoe moe etype event

    tempfile monthly_source
    tempfile monthly_baseline

    save "`monthly_source'", replace

    * Calculate the 2018-2022 average for each calendar month.
    keep if inrange(yoe, `baseline_start', `baseline_end')
    collapse (sum) cases=event, by(yoe moe etype)
    collapse (mean) baseline_average=cases, by(moe etype)
    save "`monthly_baseline'", replace

    * Calculate observed monthly cases for each event type in 2022 and 2023.
    use "`monthly_source'", clear
    keep if inrange(yoe, `display_start', `target_year')
    collapse (sum) cases=event, by(yoe moe etype)

    merge m:1 moe etype using "`monthly_baseline'", assert(match) nogen

    gen period_month = ym(yoe, moe)
    format period_month %tmMon_CCYY
    gen difference = cases - baseline_average
    bysort etype (period_month): gen cumulative_difference = sum(difference)

    isid period_month etype
    sort etype period_month
    order period_month yoe moe etype cases baseline_average difference cumulative_difference

    label var period_month      "Calendar month"
    label var yoe               "Calendar year"
    label var moe               "Calendar month number"
    label var etype             "CVD event type"
    label var cases             "Monthly cases for this event type"
    label var baseline_average  "2018-2022 average for this event type and calendar month"
    label var difference        "Observed cases minus event-specific 2018-2022 monthly average"
    label var cumulative_difference ///
        "Cumulative observed cases above or below event-specific 2018-2022 average"

    notes drop _all
    label data "BNR-CVD Registry: monthly CVD cases by event type for 2023 briefing"

    notes _dta: title: Cumulative difference in registered CVD cases by event type, Barbados, 2022-2023
    notes _dta: version: v2
    notes _dta: created: 2026-07-31
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Monthly stroke and AMI counts with event-specific cumulative departure from the five-year monthly comparator
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2022-2023
    notes _dta: baseline_period: 2018-2022
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Calendar month
    notes _dta: description: Hospital-ascertained stroke and heart attack counts for each month during 2022 and 2023. The cumulative_difference variable is accumulated separately for each event type from January 2022 as observed monthly counts minus the 2018-2022 average for the same calendar month and event type.
    notes _dta: limitations: Counts describe hospital-ascertained cases and should not be interpreted as population incidence.
    notes _dta: disclosure: Weekly data are not released. Public monthly counts are separated by event type but unstratified by age, sex and geography.
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: `input_dataset_id'
    notes _dta: contact: Barbados National Registry

    save "`stagingdatasets'/`output1'.dta", replace
    export delimited using "`stagingdatasets'/`output1'.csv", replace

    local chart_start = ym(`display_start', 1)
    local chart_end   = ym(`target_year', 12)

    * The chart plots one cumulative departure line for each event type. The
    * light zero line is the expected cumulative count under the event-specific
    * 2018-2022 monthly pattern.
    * The compact, flat layout deliberately matches the companion age/sex
    * infographic: clean white plotting area, restrained line weights, no
    * enclosing axes, and a simple legend below the data.
    #delimit ;
        graph twoway
            (line cumulative_difference period_month if etype == 1,
                lw(1.4)
                color("${str_m}"))
            (line cumulative_difference period_month if etype == 2,
                lw(1.4)
                color("${ami_m}"))
            ,
                plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=4 r=4 b=1 t=2))
                graphregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=1 t=1))
                ysize(4)
                xsize(20)

                xlabel(`chart_start'(3)`chart_end',
                    format(%tmMon_CCYY)
                    angle(45)
                    labsize(3.2)
                    labcolor(gs4)
                    notick
                    nogrid)
                xscale(noline noextend range(`chart_start' `chart_end'))
                xtitle(" ", margin(top) color(gs0) size(2.5))

                ylabel(, angle(0) labsize(3.2) labcolor(gs4) notick nogrid)
                yscale(noline noextend range(0))
                yline(0, lcolor(gs8) lwidth(thin))
                ytitle("Cumulative cases above / below the 2018-2022 average", size(3.2) color(gs4))

                legend(
                    order(
                        1 "Stroke"
                        2 "Heart attack"
                    )
                    rows(1)
                    size(3.2)
                    region(lstyle(none))
                    position(6)
                    ring(1)
                )
                name(cases_2023_monthly, replace)
                ;
    #delimit cr

    graph export "`stagingfigures'/`output1'.png", replace width(3000)

restore


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
            /// text(-0.2 105 "Proportion 70 years and older with a hospitalised heart attack or stroke", place(c) size(10) color(gs4))
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
    notes _dta: version: v2
    notes _dta: created: 2026-07-31
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



** ==============================================================================
** ==============================================================================
** DO NOT TOUCH: CREATE THE AUTOMATIC DISCLOSURE-REVIEW WORKLIST
** ==============================================================================
* This worklist prompts human review; it does not suppress values automatically.
* It flags positive released counts or denominators below six.

tempfile flag_monthly_cases
tempfile flag_monthly_baseline
tempfile flag_age_event
tempfile flag_age_denom

preserve

    use "`stagingdatasets'/`output1'.dta", clear
    keep if cases > 0 & cases < 6
    gen str40 public_file = "`output1'.csv"
    decode etype, gen(event_type)
    /// tostring period_month, gen(period_label) format(%tmMon_CCYY) force
    gen str9 period_label = string(period_month, "%tmMon_CCYY")
    gen str80 output_section = "Monthly " + event_type + " cases"
    gen str80 row_reference = event_type + ", " + period_label
    gen str30 measure = "cases"
    gen double value = cases
    gen str100 reason = "Positive released count below 6"
    gen str80 related_output = "`output1'.png"
    keep public_file output_section row_reference measure value reason related_output
    save "`flag_monthly_cases'", replace

    use "`stagingdatasets'/`output1'.dta", clear
    keep if baseline_average > 0 & baseline_average < 6
    gen str40 public_file = "`output1'.csv"
    decode etype, gen(event_type)
    tostring period_month, gen(period_label) format(%tmMon_CCYY) force
    gen str80 output_section = "Five-year monthly " + event_type + " comparator"
    gen str80 row_reference = event_type + ", " + period_label
    gen str30 measure = "baseline_average"
    gen double value = baseline_average
    gen str100 reason = "Positive displayed average below 6"
    gen str80 related_output = "`output1'.png"
    keep public_file output_section row_reference measure value reason related_output
    save "`flag_monthly_baseline'", replace

    use "`stagingdatasets'/`output2'.dta", clear
    keep if event > 0 & event < 6
    gen str40 public_file = "`output2'.csv"
    gen str40 output_section = "Age-group distribution"
    gen str80 row_reference = "etype=" + string(etype) + "; sex=" + string(sex) + "; period=" + string(period) + "; age70=" + string(age70)
    gen str30 measure = "event"
    gen double value = event
    gen str100 reason = "Positive released count or annual average below 6"
    gen str80 related_output = "`output2'.png"
    keep public_file output_section row_reference measure value reason related_output
    save "`flag_age_event'", replace

    use "`stagingdatasets'/`output2'.dta", clear
    keep if denom > 0 & denom < 6
    gen str40 public_file = "`output2'.csv"
    gen str40 output_section = "Age-group distribution"
    gen str80 row_reference = "etype=" + string(etype) + "; sex=" + string(sex) + "; period=" + string(period) + "; age70=" + string(age70)
    gen str30 measure = "denom"
    gen double value = denom
    gen str100 reason = "Positive released denominator or annual average below 6"
    gen str80 related_output = "`output2'.png"
    keep public_file output_section row_reference measure value reason related_output
    save "`flag_age_denom'", replace

    use "`flag_monthly_cases'", clear
    append using "`flag_monthly_baseline'"
    append using "`flag_age_event'"
    append using "`flag_age_denom'"

    count
    if r(N) == 0 {
        set obs 1
        replace public_file = "ALL DECLARED OUTPUTS" in 1
        replace output_section = "Whole briefing" in 1
        replace row_reference = "Not applicable" in 1
        replace measure = "none" in 1
        replace value = . in 1
        replace reason = "No automatic positive-value flags below 6" in 1
        replace related_output = "Human whole-output review still required" in 1
    }

    gen flag_id = _n
    order flag_id public_file output_section row_reference measure value reason related_output
    export delimited using "`stagingreview'/disclosure_flags.csv", replace

restore



** DO NOT TOUCH: STANDARD RELEASE CONTROL AND PRIVATE STAGING STEP
** ==============================================================================
* The analytics section above has created all briefing-specific public artefacts
* in the staging folder.
*
* This final section deliberately stays short. It writes one small control file
* that describes the release package, then calls the standard invariant helper.
*
* The private staging helper will handle:
*   - dataset-level YAML metadata using bnr_yml;
*   - briefing-level metadata;
*   - README creation;
*   - workbook creation, when requested;
*   - simplified downloads.yml creation;
*   - creation of a fresh, incomplete disclosure-review template.
*
* It will not copy anything to public/ or to the website.
*
* This keeps all briefing-specific work in one DO file while avoiding repeated
* copy/paste release machinery at the end of every briefing.


** ==============================================================================
** DO NOT TOUCH: WRITE RELEASE CONTROL FILE
** ==============================================================================
* Purpose:
*   Create metadata/release_control.yml.
*
* This is the contract between the analyst-owned DO file and the invariant
* staging helper. Future analysts should edit the locals in EDIT BLOCK A, not
* the file-writing code below.
*
* Why a control file?
*   A called helper DO file should not depend on locals that happen to exist in
*   the calling DO file. Writing a small control file makes the handover between
*   the analysis layer and release layer explicit and auditable.

local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local analysis_script "scripts/stata/briefings/cvd_cases_2023/cvd_cases_2023_v2.do"
local control_file "`stagingmetadata'/release_control.yml"

tempname release_control

file open `release_control' using "`control_file'", ///
    write replace text

file write `release_control' "schema: bnr_release_control_v1" _n
file write `release_control' "briefing_id: `briefing_id'" _n
file write `release_control' "briefing_name: `briefing_name'" _n
file write `release_control' "output_type: `output_type'" _n
file write `release_control' "domain: `domain'" _n
file write `release_control' "surveillance_area: `surveillance_area'" _n
file write `release_control' "registry: `registry'" _n
file write `release_control' "geography: `geography'" _n
file write `release_control' "period: `period'" _n
file write `release_control' "target_year: `target_year'" _n
file write `release_control' "baseline_start: `baseline_start'" _n
file write `release_control' "baseline_end: `baseline_end'" _n
file write `release_control' "release_date: `release_date'" _n
file write `release_control' "analysis_script: `analysis_script'" _n
file write `release_control' "source_dataset_id: `input_dataset_id'" _n
file write `release_control' "source_dataset_release: `input_release'" _n
file write `release_control' "source_coverage_end: `input_coverage'" _n
file write `release_control' "source_dataset_file: `input_dataset_id'.dta" _n
file write `release_control' "" _n

file write `release_control' "title: |-" _n
file write `release_control' "  `briefing_title'" _n
file write `release_control' "" _n

file write `release_control' "short_title: |-" _n
file write `release_control' "  `briefing_short'" _n
file write `release_control' "" _n

file write `release_control' "description: |-" _n
file write `release_control' "  `briefing_description'" _n
file write `release_control' "" _n

file write `release_control' "limitations: |-" _n
file write `release_control' "  `briefing_limitations'" _n
file write `release_control' "" _n

file write `release_control' "data_note: |-" _n
file write `release_control' "  `data_note'" _n
file write `release_control' "" _n

file write `release_control' "rights: |-" _n
file write `release_control' "  `rights_note'" _n
file write `release_control' "" _n

file write `release_control' "contact: |-" _n
file write `release_control' "  `contact_note'" _n
file write `release_control' "" _n

file write `release_control' "briefing_page: `briefing_page'" _n
file write `release_control' "released_datasets: `released_datasets'" _n
file write `release_control' "released_figures: `released_figures'" _n
file write `release_control' "" _n

file write `release_control' "create_workbook: `create_workbook'" _n
file write `release_control' "create_zip: `create_zip'" _n
file write `release_control' "list_zip: `list_zip'" _n
file write `release_control' "workbook_file: `workbook_file'" _n
file write `release_control' "" _n

file write `release_control' "workbook_sheets:" _n
file write `release_control' "  - dataset_id: `workbook_dataset1'" _n
file write `release_control' "    data_sheet: `workbook_data1'" _n
file write `release_control' "    metadata_sheet: `workbook_meta1'" _n
file write `release_control' "    variable_sheet: `workbook_vars1'" _n
file write `release_control' "  - dataset_id: `workbook_dataset2'" _n
file write `release_control' "    data_sheet: `workbook_data2'" _n
file write `release_control' "    metadata_sheet: `workbook_meta2'" _n
file write `release_control' "    variable_sheet: `workbook_vars2'" _n
file write `release_control' "" _n

file write `release_control' "zip_title: |-" _n
file write `release_control' "  `zip_title'" _n
file write `release_control' "" _n

file write `release_control' "zip_description: |-" _n
file write `release_control' "  `zip_description'" _n

file close `release_control'

display as result "Release control file created:"
display as result "  `control_file'"


** ==============================================================================
** DO NOT TOUCH: COMPLETE THE PRIVATE STAGING PACKAGE
** ==============================================================================
* This helper performs only routine private packaging. It does not approve or
* publish the briefing.

do "`localpath'/scripts/stata/common/bnr_stage_briefing.do" ///
    "`briefing_id'"

cap log close

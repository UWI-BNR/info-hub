/* 
* =====================================================================
 DO-FILE:     cvd_cases_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD case-count briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.1

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
     - writing a small release-control file for the standard publisher.

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
  STAGING: outputs/staging/briefings/cvd_cases_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_cases_2023_v1/
  SITE:    site/downloads/files/briefings/cvd_cases_2023_v1/

  Created directly by this DO file:

  datasets/
    cvd_cases_weekly.dta
    cvd_cases_weekly.csv
    cvd_cases_age_group.dta
    cvd_cases_age_group.csv

  figures/
    cvd_cases_weekly.png
    cvd_cases_age_group.png

  metadata/
    release_control.yml

  Created later by the standard publish helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_cases_weekly.yml
    cvd_cases_age_group.yml
    briefing.yml

  workbook/
    bnr_cvd_cases_2023_v1.xlsx

  ZIP:
    bnr_cvd_cases_2023_v1.zip
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
* The standard folder setup, release-control writer, and publish helper should
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
local baseline_start    2018
local baseline_end      2022

local briefing_id       "cvd_cases_2023_v1"
local briefing_name     "cvd_cases_2023"
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
* output1 and output2 are retained because they are used in the analytical
* sections below. For future briefings, replace these with clear, stable,
* lowercase file stems.
*
* Each released dataset should be saved as:
*   datasets/{output}.dta
*   datasets/{output}.csv
*
* Each released figure should be saved as:
*   figures/{output}.png

local output1           "cvd_cases_weekly"
local output2           "cvd_cases_age_group"

local released_datasets "`output1' `output2'"
local released_figures  "`output1' `output2'"


* ------------------------------------------------------------------------------
* Workbook and download settings
* ------------------------------------------------------------------------------
* These settings tell the standard publish helper what convenience artefacts
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
local workbook_data1    "`output1'"
local workbook_meta1    "meta_weekly"
local workbook_vars1    "vars_weekly"

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
log using "$BNR_PRIVATE_LOGS/`briefing_name'", replace


* ==============================================================================
* DO NOT TOUCH: STANDARD STAGING FOLDER SETUP
* ==============================================================================
* The staging folder is the build area for this briefing/output package.
*
* The public folder is NOT created here. Public release and website mirroring
* are handled by the shared publish helper at the end of the DO file.
*
* The physical folder name remains briefings/ for continuity with the current
* BNR publication pathway. The specific kind of output is recorded using the
* output_type local above.

local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures  "`stagingbriefing'/figures"
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
    as result "  Output type:     `output_type'" _n ///
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
* For a new briefing, adapt the analytical sections below as needed.
* Keep the release-control and publish sections at the end unchanged unless
* the standard BNR release process itself changes.
*
* The standard dataset/figure pattern is:
*   1. create a final public aggregate dataset;
*   2. label all variables clearly;
*   3. add structured dataset notes using notes _dta:;
*   4. export CSV and save DTA to stagingdatasets/;
*   5. export related figures to stagingfigures/, if relevant.
*
* The invariant helper called later will convert DTA labels and notes into
* YAML metadata and will publish the completed staging folder.
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
                /// text(-40 26 "Cumulative CVD cases in 2023 compared to 5-year average (2018-2022)", place(c) size(8) color(gs4))

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



** ==============================================================================
** DO NOT TOUCH: STANDARD RELEASE CONTROL AND PUBLISH STEP
** ==============================================================================
* The analytics section above has created all briefing-specific public artefacts
* in the staging folder.
*
* This final section deliberately stays short. It writes one small control file
* that describes the release package, then calls the standard invariant helper.
*
* The helper, which is shared across briefing/output packages, will handle:
*   - dataset-level YAML metadata using bnr_yml;
*   - briefing-level metadata;
*   - README creation;
*   - workbook creation, when requested;
*   - simplified downloads.yml creation;
*   - staging/ to public/ copy;
*   - ZIP creation, when requested;
*   - public/ to site/downloads/ mirror.
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
* publish helper. Future analysts should edit the locals in EDIT BLOCK A, not
* the file-writing code below.
*
* Why a control file?
*   A called helper DO file should not depend on locals that happen to exist in
*   the calling DO file. Writing a small control file makes the handover between
*   the analysis layer and release layer explicit and auditable.

local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local analysis_script "scripts/stata/briefings/cvd_cases_2023/`briefing_name'.do"
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
** DO NOT TOUCH: PUBLISH BRIEFING OUTPUT PACKAGE
** ==============================================================================
* This helper will be created as the next step in the refactor.
*
* Expected behaviour:
*   Source:
*     outputs/staging/briefings/{briefing_id}/
*
*   Public target:
*     outputs/public/briefings/{briefing_id}/
*
*   Website mirror:
*     site/downloads/files/briefings/{briefing_id}/
*
* The helper should be tolerant of partial packages, so that the same pathway
* can be used for both full briefings and smaller supporting artefacts.

do "`localpath'/scripts/stata/common/bnr_publish_briefing.do" ///
    "`briefing_id'"
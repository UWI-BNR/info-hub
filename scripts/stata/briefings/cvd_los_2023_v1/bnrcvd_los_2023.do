/* 
* =====================================================================
 DO-FILE:     bnrcvd_los_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD length-of-stay briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.1

 NOTES:
   This DO file is the analyst-owned build file for the 2023 CVD
   length-of-stay briefing.

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
  STAGING: outputs/staging/briefings/cvd_los_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_los_2023_v1/
  SITE:    site/downloads/files/briefings/cvd_los_2023_v1/

  Created directly by this DO file:

  datasets/
    cvd_los_median.dta
    cvd_los_median.csv
    cvd_los_bed_demand.dta
    cvd_los_bed_demand.csv

  figures/
    cvd_los_median.png
    cvd_los_bed_demand.png

  metadata/
    release_control.yml

  Created later by the standard publish helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_los_median.yml
    cvd_los_bed_demand.yml
    briefing.yml

  workbook/
    bnr_cvd_los_2023_v1.xlsx

  ZIP:
    bnr_cvd_los_2023_v1.zip
    Stored inside the public briefing folder.
* =====================================================================
*/


* ============================================================================
* DO NOT TOUCH: INITIALIZE DO FILE
* ============================================================================
* Keep the top of every briefing DO file predictable. This improves
* handover, makes logs easier to interpret, and reduces accidental state
* carried over from an earlier Stata session.

clear all
set more off


* ============================================================================
* DO NOT TOUCH: SET LOCAL PROJECT PATH AND LOAD SHARED SETTINGS
* ============================================================================
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


* ============================================================================
* EDIT BLOCK A: BRIEFING / OUTPUT PACKAGE SETTINGS
* ============================================================================
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
* This output is a narrative public briefing.

local target_year       2023
local baseline_start    2010
local baseline_end      2021

local briefing_id       "cvd_los_2023_v1"
local briefing_name     "cvd_los_2023"
local output_type       "briefing"

local briefing_title    "Barbados CVD length of stay, 2010-2023"
local briefing_short    "Length of stay in Barbados"
local briefing_page     "surveillance/cvd/briefings/hospital-los.qmd"

local surveillance_area "CVD"
local domain            "cvd"
local registry          "BNR-CVD"
local geography         "Barbados"
local period            "`target_year'"

local briefing_description ///
    "Public aggregate output package for the BNR CVD length-of-stay briefing."

local briefing_limitations ///
    "Length of stay is based on hospital-ascertained CVD events only."

local data_note ///
    "Aggregate hospital-ascertained length-of-stay and bed-day demand outputs."

local rights_note ///
    "Public release. Cite the Barbados National Registry when reusing."

local contact_note ///
    "Barbados National Registry."


* ----------------------------------------------------------------------------
* Released artefact names
* ----------------------------------------------------------------------------
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

local output1           "cvd_los_median"
local output2           "cvd_los_bed_demand"

local released_datasets "cvd_los_median cvd_los_bed_demand"
local released_figures  "cvd_los_median cvd_los_bed_demand"


* ----------------------------------------------------------------------------
* Workbook and download settings
* ----------------------------------------------------------------------------
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

local workbook_dataset1 "cvd_los_median"
local workbook_data1    "cvd_los_median"
local workbook_meta1    "meta_cvd_los_median"
local workbook_vars1    "vars_cvd_los_median"

local workbook_dataset2 "cvd_los_bed_demand"
local workbook_data2    "cvd_los_bed_demand"
local workbook_meta2    "meta_cvd_los_bed_demand"
local workbook_vars2    "vars_cvd_los_bed_demand"

local zip_title ///
    "Full public output package"

local zip_description ///
    "Complete public download package containing datasets, figures, metadata, workbook, and README file."


* ============================================================================
* DO NOT TOUCH: OPEN PRIVATE LOG
* ============================================================================
* Logs are written outside the public release bundle. They are part of the
* private audit trail for the build and should not be published.

cap log close
log using "$BNR_PRIVATE_LOGS/`briefing_name'", replace


* ============================================================================
* DO NOT TOUCH: STANDARD STAGING FOLDER SETUP
* ============================================================================
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
    "BNR CVD length-of-stay briefing build" _n ///
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
** (EDIT BLOCK - SECTION B1): LOAD PREPARED COUNT DATASET
** ==============================================================
    use "${tempdata}\bnrcvd_los_2023_v1.dta", clear 

** BROAD RESTRICTIONS
** HOSPIPTAL EVENTS ONLY - drop DCOs 
    drop if dco==1 
    drop dco 
    drop if yoe==2009  /// Setup year - don't report

* IRH 13-NOV-2025 
* Very obvious date errors - simply convert to missing for this 2023 briefing exercise
    replace dod = . if dod>1000000 
    replace dodi = . if dodi>1000000 

** 2-year intervals 
gen yoa = year(doa) 
gen year2 = .
replace year2 = 1 if yoa==2010 | yoa==2011
replace year2 = 2 if yoa==2012 | yoa==2013
replace year2 = 3 if yoa==2014 | yoa==2015
replace year2 = 4 if yoa==2016 | yoa==2017
replace year2 = 5 if yoa==2018 | yoa==2019
replace year2 = 6 if yoa==2020 | yoa==2021
replace year2 = 7 if yoa==2022 | yoa==2023
label define year2_ 1 "2010-2011" 2 "2012-2013" 3 "2014-2015" 4 "2016-2017" 5 "2018-2019" 6 "2020-2021" 7 "2022-2023"
label values year2 year2_ 
order year2, after(yoe)

** Vital Status At Discarge (sadi, 1=alive, 2=dead) 
**      Incomplete variable
**      Can improve by exploring date of death cf. date of discharge 
* Difference between date of event and date of death (days)
    gen doe_dod_diff = dod - doe
* Case-Fatality Rate (with uncertainty as follows): 
*   1 = CONFIRMED alive at discharge
*   2 = POSSIBLE alive at discharge (death, but after 28 days of event)
*   3 = CONFIRMED death within hospital
*   4 = PROBABLE death within hospital (death, within 7 days of event)
*   5 = POSSIBLE death within hospital (death, between 7 and 28 days of event)
    gen cf = sadi
    recode cf (2=3)
    replace cf = 2 if sadi==. & dod<. & doe_dod_diff>28
    replace cf = 4 if sadi==. & dod<. & doe_dod_diff<=7 
    replace cf = 5 if sadi==. & dod<. & doe_dod_diff>7 & doe_dod_diff<=28
    replace cf = .a if cf==. 
    label define cf_ 1 "Conf.Alive" 2 "Undoc Alive" 3 "Conf.CF" 4 "Prob.CF" 5 "Poss.CF" .a "No dates"
    label values cf cf_ 

** Length of stay (Using only CONFIRMED alive, CONFIRMED hospital death, AND PROBABLE hospital death )
    gen los_primary = dodi - doa 
    order cf los_primary , after(sadi) 
    label var cf "Vital status at discharge/death (with uncertainty)"
    label var los_primary "Length of hospital stay (days)"

* IRH 13-NOV-2025 
    * A number of -dodi- that seem too long for an in-hospital stay
    * Possibly linked to dodi change of meaning in 2023
    * JC notes (email to IRH 7-NOV-2023): 
    *       "...dlc used to mean date of last known contact 
    *       then BNR changed it to discharge date in the 2023 REDCap database. 
    *       I had to copy the previous discharge date variable into dlc."
    * IRH 13-NOV-2025 
    * After some exploration. These longs stay are:
    *           (A) spread evenly through time
    *           (B) mostly among strokes
    * So this may well be a real effect - with hospital acting as longer-term post-care facility
    gen los_poss_error = 0 
    replace los_poss_error = 1 if los_primary>=60 & los_primary<. 
    order cf los_poss_error , after(los_primary) 

** Median regression - trend in median los for stroke and heart separately 
qreg los_primary i.etype
qreg los_primary i.sex
qreg los_primary i.etype i.sex
qreg los_primary i.etype i.sex year
qreg los_primary i.sex year if etype==1
qreg los_primary i.sex year if etype==2

** Temporary save of PID dataset 
tempfile pid_los 
save `pid_los', replace 
* Save for tabulations 
save "${tempdata}/bnrcvd-length-of-stay.dta", replace 

** Hospital days by Event Type and 2-year period 
tempfile nevent1 nevent2 nevent3 nevent4 nevent5 
    preserve
        collapse (count) nevent=los_primary if cf==1 , by(etype)
        save `nevent1', replace 
    restore 
    preserve
        collapse (count) nevent=los_primary if cf==1 , by(sex)
        save `nevent2', replace 
    restore 
    preserve
        collapse (count) nevent=los_primary if cf==1 , by(etype sex)
        save `nevent3', replace 
    restore 
    preserve
        collapse (count) nevent=los_primary if cf==1 , by(etype year2)
        save `nevent4', replace 
    restore 
    preserve 
        use `nevent2', clear 
        append using `nevent1'
        * append using `tlos3'
        append using `nevent4'
        drop if nevent==0
        gen yaxis = _n
        order yaxis sex etype year2
        ** Annual count 
        gen nevent_1yr = nevent/14 if yaxis<=4 
        replace nevent_1yr = nevent/2 if yaxis>=5 
        save `nevent5', replace 
    restore

* LoS Summary Metrics for graphic 
* Graphic restricted to those alive at discharge 
* Create aggregrated dataset as a combination of several collapsed datasets 
    tempfile los1 los2 los3 los4 los5 los6
    preserve
        collapse (p50) los50=los_primary (p25) los25=los_primary     ///
                 (p75) los75=los_primary (p5) los05=los_primary     /// 
                 (p95) los95=los_primary if cf==1 , by(etype)
        save `los1', replace 
    restore 
    preserve
        collapse (p50) los50=los_primary (p25) los25=los_primary     ///
                 (p75) los75=los_primary (p5) los05=los_primary     /// 
                 (p95) los95=los_primary if cf==1  , by(sex)
        save `los2', replace 
    restore 
    preserve
        collapse (p50) los50=los_primary (p25) los25=los_primary     ///
                 (p75) los75=los_primary (p5) los05=los_primary     /// 
                 (p95) los95=los_primary if cf==1  , by(etype sex)
        save `los3', replace 
    restore 
    preserve
        collapse (p50) los50=los_primary (p25) los25=los_primary     ///
                 (p75) los75=los_primary (p5) los05=los_primary     /// 
                 (p95) los95=los_primary if cf==1  , by(etype year2)
        save `los4', replace 
    restore 

use `los2', clear 
append using `los1'
* append using `los3'
append using `los4'
drop if los50==.
gen yaxis = _n
merge 1:1 yaxis using `nevent5'
drop _merge 
order yaxis sex etype year2
* Spacing between yaxis blocks (4 blocks : ETYPE / SEX / STROKE years / AMI years) 
replace yaxis = yaxis + 1 if yaxis >=3 
replace yaxis = yaxis + 1 if yaxis >=6 
replace yaxis = yaxis + 1 if yaxis >=14 


** ---------------------------------------------
** (8) ANALYTICS 1 - 
** LENGTH of STAY MEDIAN VALUES
** ---------------------------------------------
        #delimit ;
            gr twoway 
                /// Graph Furniture 
                /// X-Axis
                (scatteri 22 2 22 4.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 22 5.5 22 9.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 22 10.5 22 14.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 22 15.5 22 19.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                /// Equality line (rate ratio = 1)
                (scatteri 0.75 0  2.0 0 , recast(line) lw(0.2) lc("gs0") lp("-"))
                (scatteri  3.5 0  5.5 0 , recast(line) lw(0.2) lc("gs0") lp("-"))
                (scatteri  6.5 0 13.5 0 , recast(line) lw(0.2) lc("${str_m70}%75") lp("-"))
                (scatteri 14.5 0 22.0 0 , recast(line) lw(0.2) lc("${ami_m70}%75") lp("-"))

                /// The Data (lines and points) 

                (rspike los25 los75 yaxis if yaxis>=1 & yaxis<=2 , horizontal lw(0.55) color("gs0"))
                (sc yaxis los50           if yaxis>=1 & yaxis<=2 , msize(1.5) mc("gs16"))
                (sc yaxis los50           if yaxis>=1 & yaxis<=2 , msize(1) mc("gs0"))
                (rspike los25 los75 yaxis if yaxis>=4            , horizontal lw(0.55) color("${str_m70}"))
                (sc yaxis los50           if yaxis>=4            , msize(1.5) mc("gs16"))
                (sc yaxis los50           if yaxis>=4            , msize(1) mc("${str_m}"))
                (rspike los25 los75 yaxis if yaxis>=5            , horizontal lw(0.55) color("${ami_m70}"))
                (sc yaxis los50           if yaxis>=5            , msize(1.5) mc("gs16"))
                (sc yaxis los50           if yaxis>=5            , msize(1) mc("${ami_m}"))

                (rspike los25 los75 yaxis if yaxis>=7 & yaxis<=13 , horizontal lw(0.55) color("${str_m70}"))
                (sc yaxis los50           if yaxis>=7 & yaxis<=13 , msize(1.5) mc("gs16"))
                (sc yaxis los50           if yaxis>=7 & yaxis<=13 , msize(1) mc("${str_m}"))
                (rspike los25 los75 yaxis if yaxis>=14            , horizontal lw(0.55) color("${ami_m70}"))
                (sc yaxis los50           if yaxis>=14            , msize(1.5) mc("gs16"))
                (sc yaxis los50           if yaxis>=14            , msize(1) mc("${ami_m}"))

                ,
                    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
                    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 
                    ysize(14) xsize(15)

                    xlab(none, 
                    labc(gs0) labs(2.5) notick nogrid angle(45) format(%9.0f))
                    xscale(noextend lw(vthin) range(-10(1)22)) 
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(none,
                    valuelabel labc(gs0) labs(3) tlc(gs8) notick nogrid angle(0) format(%9.0f))
                    yscale( reverse noline noextend range(0(0.5)22.5) ) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// Title 
                    text(23.25 5 "Median Length of Stay (Days), 2010–2023",  place(c) size(2.5) color(gs4))

                    // X-axis legend
                    text(22 1 "One",  place(c) size(2) color(gs4))
                    text(22 5 "5",  place(c) size(2) color(gs4))
                    text(22 10 "10",  place(c) size(2) color(gs4))
                    text(22 15 "15",  place(c) size(2) color(gs4))
                    text(22 20 "20",  place(c) size(2) color(gs4))

                    /// (Right hand side) Hospital Rates by Sex and Event type 
                    text(1   -1 "Women"          ,  place(w) size(2.5) color("gs0"))
                    text(2   -1 "Men"          ,  place(w) size(2.5) color("gs0"))
                    text(4   -1 "Stroke "                ,  place(w) size(2.5) color("${str_m}%75"))
                    text(5   -1 "Heart Attack"          ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(7   -7 "Stroke"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(7   -2 "2010-2011"                       ,  place(w) size(2.25) color("${str_m}%75"))
                    text(8   -2 "2012-2013"                       ,  place(w) size(2.25) color("${str_m}%75"))
                    text(9   -2 "2014-2015"                       ,  place(w) size(2.25) color("${str_m}%75"))
                    text(10  -2 "2016-2017"                       ,  place(w) size(2.25) color("${str_m}%75"))
                    text(11  -2 "2018-2019"                       ,  place(w) size(2.25) color("${str_m}%75"))
                    text(12  -2 "2020-2021"                       ,  place(w) size(2.25) color("${str_m}%75"))
                    text(13  -2 "2022-2023"                       ,  place(w) size(2.25) color("${str_m}%75"))

                    text(15 -7 "Heart Attack "   ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(15 -2 "2010-2011"                       ,  place(w) size(2.25) color("${ami_m}%75"))
                    text(16 -2 "2012-2013"                       ,  place(w) size(2.25) color("${ami_m}%75"))
                    text(17 -2 "2014-2015"                       ,  place(w) size(2.25) color("${ami_m}%75"))
                    text(18 -2 "2016-2017"                       ,  place(w) size(2.25) color("${ami_m}%75"))
                    text(19 -2 "2018-2019"                       ,  place(w) size(2.25) color("${ami_m}%75"))
                    text(20 -2 "2020-2021"                       ,  place(w) size(2.25) color("${ami_m}%75"))
                    text(21 -2 "2022-2023"                       ,  place(w) size(2.25) color("${ami_m}%75"))

                    legend(off)
                    name(length_of_stay_figure1, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output1'.png", replace width(3000)

    ** ---------------------------------------------------------
    ** Export acompanying dataset (XLSX and DTA)
    ** With associated dataset-level and variable-level metadata 
    ** ---------------------------------------------------------
    * Label stata variables
    drop nevent_1yr 
    rename yaxis indicator 
    label var indicator "unique summary measure indicator"
    label var etype "CVD event type (stroke=1, AMI=2, Both=3)"
    label var year2 "CVD event year (2-year intervals)"
    label var sex "female=1, male=2, both=3"
    label var etype "CVD event type (stroke=1, AMI=2)"
    label var year "CVD event year (yyyy)"
    label var sex "female=1, male=2, both=3"
    label var los50 "Length of hospital stay: 50th percentile"
    label var los25 "Length of hospital stay: 25th percentile"
    label var los75 "Length of hospital stay: 75th percentile"
    label var los05 "Length of hospital stay: 5th percentile"
    label var los95 "Length of hospital stay: 95th percentile"
    label var nevent "Number of events"
    replace sex = 3 if sex==. 
    replace etype = 3 if etype==. 
    replace year2 = 0 if year2==. 
    label define sex_ 3 "Both", modify 
    label define etype_ 3 "Both", modify 
    label define year2_ 0 "All years", modify 

    * STATA dataset export 
    notes drop _all 
    label data "BNR-CVD Registry: dataset associated with CVD length-of-stay briefing" 
    note _dta: title: BNR-CVD Length of In-Hospital Stay (Aggregated)
    notes _dta: version: v1
    notes _dta: created: 2026-05-06
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual median length of stay 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2010-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by period
    notes _dta: description: Annual median length of stay in days.
    notes _dta: limitations: Based on hospital CVD events
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: Barbados National Registry approved cardiovascular registry extract (Jan 2010-Dec 2023)
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output1'.dta", replace 

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output1'.csv", replace

    ** Dataset-level YAML metadata is created later by bnr_publish_briefing.do
    ** from the released DTA labels and notes.

** FIGURE 2 
use `pid_los', clear
keep if yoe>=2014 

** Hospital days by Event Type and 2-year period 
tempfile nevent1 nevent2
    preserve
        collapse (count) nevent=los_primary if cf==1 , by(etype yoe)
        save `nevent1', replace 
        gen yaxis = _n
        order yaxis etype yoe
        save `nevent1', replace 
    restore

* LoS Summary Metrics for graphic 
* Graphic restricted to those alive at discharge 
* Create aggregrated dataset as a combination of several collapsed datasets 
    tempfile los1
    preserve
        collapse (p50) los50=los_primary (p25) los25=los_primary     ///
                 (p75) los75=los_primary (p5) los05=los_primary     /// 
                 (p95) los95=los_primary if cf==1  , by(etype yoe)
        save `los1', replace 
    restore 

use `los1', clear 
gen yaxis = _n
merge 1:1 yaxis using `nevent1'
drop _merge 
order yaxis etype yoe

** Now calculate the median difference across years for each event type 
** We use 2015 as the baseline comparator  
gen t1 = los50 if yoe==2014
bysort etype : egen median2015 = min(t1) 
drop t1 
sort yaxis
gen exdays = (los50 - median2015) * nevent
gen exday_week = exdays/52
gen zero = 0

** Shift AMI to Lower Axis 
replace exday_week = exday_week - 30 if etype==2 
gen zero_ami = -30

** For reporting on graph  
gen ex50 = round(exdays/52, 0.1)
format ex50 %4.2f
local ex50_str = ex50[10]
global ex50_str : display %4.1f `ex50_str'
local ex50_ami = ex50[20]
global ex50_ami : display %4.1f `ex50_ami'


** FIGURE 2 - CHANGE IN BED DAYS OVER TIME
        #delimit ;
            gr twoway 
                /// Graph Furniture 
                /// 2014 POINT  - STROKE 
                (scatteri 0 2014.6 0 2023.5 , recast(line) lw(0.4) lc("gs0") lp("l"))
                (scatteri 0 2014 , msize(3) mlc("gs0") mlw(0.1) mfc("${str_m}%75") lp("l"))
                /// 2014 POINT  - AMI 
                (scatteri -30 2014.6 -30 2023.5 , recast(line) lw(0.4) lc("gs0") lp("l"))
                (scatteri -30 2014 , msize(3) mlc("gs0") mlw(0.1) mfc("${ami_m}%75") lp("l"))
                /// X-Axis
                (scatteri -15 2014.7 -15 2015.3 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri -15 2016.7 -15 2017.3 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri -15 2018.7 -15 2019.3 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri -15 2020.7 -15 2021.3 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri -15 2022.7 -15 2023.3 , recast(line) lw(0.2) lc("gs6") lp("l"))
                /// X AXIS LINE
                (scatteri 30 2013.25 -10 2013.25 , recast(line) lw(0.3) lc("${str_m70}") lp("l"))
                (scatteri -20 2013.25 -32 2013.25 , recast(line) lw(0.3) lc("${ami_m70}") lp(""))
                /// RHS SEPARATOR
                (scatteri -28 2024.5 26 2024.5 , recast(line) lw(0.3) lc("gs6") lp("l"))

                /// Stroke LOS Bed Days Change 
                (rbar zero exday_week yoe if etype==1, barw(0.5) lw(none) color("${str_m70}%75"))
                /// AMI LOS Bed Days Change 
                (rbar zero_ami exday_week yoe if etype==2, barw(0.5) lw(none) color("${ami_m70}%75"))
                ,
                    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
                    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 
                    ysize(9) xsize(19)

                    xlab(none, 
                    valuelabel labc(gs0) labs(2.5) notick nogrid angle(45) format(%9.0f))
                    xscale(noline lw(vthin) range(2012.5(0.5)2028)) 
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(none,
                    labc(gs0) labs(7) tlc(gs8) nogrid angle(0) format(%9.0f))
                    yscale(noline noextend range(-40(1)35)) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// X-AXIS TEXT
                    text(-15 2014 `"{fontface "Montserrat Light": 2014}"' ,  place(c) size(5) color(gs6))
                    text(-15 2016 `"{fontface "Montserrat Light": 2016}"' ,  place(c) size(5) color(gs6))
                    text(-15 2018 `"{fontface "Montserrat Light": 2018}"' ,  place(c) size(5) color(gs6))
                    text(-15 2020 `"{fontface "Montserrat Light": 2020}"' ,  place(c) size(5) color(gs6))
                    text(-15 2022 `"{fontface "Montserrat Light": 2022}"' ,  place(c) size(5) color(gs6))
                    /// Y-AXIS TEXT
                    text( 30 2012.75 `"{fontface "Montserrat Light": 30}"' ,  place(c) size(5) color("${str_m70}"))
                    text( 20 2012.75 `"{fontface "Montserrat Light": 20}"' ,  place(c) size(5) color("${str_m70}"))
                    text( 10 2012.75 `"{fontface "Montserrat Light": 10}"' ,  place(c) size(5) color("${str_m70}"))
                    text( 0 2012.75  `"{fontface "Montserrat Light": 0}"'  ,  place(c) size(5) color("${str_m70}"))
                    text(-20 2012.75 `"{fontface "Montserrat Light": 10}"' ,  place(c) size(5) color("${ami_m70}"))
                    text(-30 2012.75 `"{fontface "Montserrat Light": 0}"'  ,  place(c) size(5) color("${ami_m70}"))

                    /// Title 
                    text(-40 2020 "Extra typical bed-days, Barbados 2014–2023",  place(c) size(4.75) color(gs4))

                    /// (Right hand side) Hospital ETBD/week
                    text(30 2026.5 "Extra Bed Days" ,  place(c) size(5) color("gs4"))
                    text(25 2026.5 "(2023 vs. 2014)"      ,  place(c) size(5) color("gs4"))
                    text(13 2026.5 "${ex50_str}" ,  place(c) size(7) color("${str_m}%75"))
                    text(6 2026.5 "per week" ,  place(c) size(7) color("${str_m}%75"))
                    text(-17 2026.5 "${ex50_ami}" ,  place(c) size(7) color("${ami_m}%75"))
                    text(-24 2026.5 "per week" ,  place(c) size(7) color("${ami_m}%75"))

                    legend(off)

                    name(length_of_stay_figure2, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output2'.png", replace width(3000)

    ** ---------------------------------------------------------
    ** Export acompanying dataset (XLSX and DTA)
    ** With associated dataset-level and variable-level metadata 
    ** ---------------------------------------------------------
    * Label stata variables
    drop median2015 exday_week zero zero_ami ex50 
    rename yaxis indicator 
    label var indicator "unique summary measure indicator"
    label var yoe "CVD event year (yyyy)"
    label var etype "CVD event type (stroke=1, AMI=2)"
    label var los50 "Length of hospital stay: 50th percentile"
    label var los25 "Length of hospital stay: 25th percentile"
    label var los75 "Length of hospital stay: 75th percentile"
    label var los05 "Length of hospital stay: 5th percentile"
    label var los95 "Length of hospital stay: 95th percentile"
    label var nevent "Number of events"
    label var exdays "Extra typical bed-days per year compared to 2014"

    * STATA dataset export 
    notes drop _all 
    label data "BNR-CVD Registry: dataset associated with CVD length-of-stay briefing" 
    note _dta: title: BNR-CVD Extra typical bed days (Aggregated)
    notes _dta: version: v1
    notes _dta: created: 2026-05-06
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual typical bed-days (based on median stay in days) 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2010-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by period
    notes _dta: description: Annual typical bed days, based on median length of stay in days.
    notes _dta: limitations: Based on hospital CVD events
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: Barbados National Registry approved cardiovascular registry extract (Jan 2010-Dec 2023)
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output2'.dta", replace 

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output2'.csv", replace

    ** Dataset-level YAML metadata is created later by bnr_publish_briefing.do
    ** from the released DTA labels and notes.



** ============================================================================
** DO NOT TOUCH: STANDARD RELEASE CONTROL AND PUBLISH STEP
** ============================================================================
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


** ============================================================================
** DO NOT TOUCH: WRITE RELEASE CONTROL FILE
** ============================================================================
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
local analysis_script "scripts/stata/briefings/cvd_los_2023/`briefing_name'.do"
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


** ============================================================================
** DO NOT TOUCH: PUBLISH BRIEFING OUTPUT PACKAGE
** ============================================================================
* The shared helper owns the invariant release machinery. It should be kept
* common across BNR briefing/output package DO files.
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

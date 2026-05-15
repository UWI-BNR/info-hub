/* 
* =====================================================================
 DO-FILE:     cvd_incidence_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD incidence briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.1

 NOTES:
   This DO file is the analyst-owned build file for the 2023 CVD
   incidence briefing.

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
  STAGING: outputs/staging/briefings/cvd_incidence_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_incidence_2023_v1/
  SITE:    site/downloads/files/briefings/cvd_incidence_2023_v1/

  Created directly by this DO file:

  datasets/
    cvd_incidence_annual.dta
    cvd_incidence_annual.csv
    cvd_incidence_rate_ratios.dta
    cvd_incidence_rate_ratios.csv

  figures/
    cvd_incidence_annual.png
    cvd_incidence_rate_ratios.png

  metadata/
    release_control.yml

  Created later by the standard publish helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_incidence_annual.yml
    cvd_incidence_rate_ratios.yml
    briefing.yml

  workbook/
    bnr_cvd_incidence_2023_v1.xlsx

  ZIP:
    bnr_cvd_incidence_2023_v1.zip
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
local baseline_end      2022

local briefing_id       "cvd_incidence_2023_v1"
local briefing_name     "cvd_incidence_2023"
local output_type       "briefing"

local briefing_title    "Barbados CVD incidence rates, 2010-2023"
local briefing_short    "Incidence in Barbados"
local briefing_page     "surveillance/cvd/briefings/case-incidence.qmd"

local surveillance_area "CVD"
local domain            "cvd"
local registry          "BNR-CVD"
local geography         "Barbados"
local period            "`target_year'"

local briefing_description ///
    "Public aggregate output package for the BNR CVD incidence briefing."

local briefing_limitations ///
    "Counts describe hospital-ascertained cases and death-certified cases only."

local data_note ///
    "Aggregate annual age-standardised CVD incidence rates and incidence rate ratios."

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

local output1           "cvd_incidence_annual"
local output2           "cvd_incidence_rate_ratios"

local released_datasets "cvd_incidence_annual cvd_incidence_rate_ratios"
local released_figures  "cvd_incidence_annual cvd_incidence_rate_ratios"


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

local workbook_dataset1 "cvd_incidence_annual"
local workbook_data1    "cvd_incidence_annual"
local workbook_meta1    "meta_cvd_incidence_annual"
local workbook_vars1    "vars_cvd_incidence_annual"

local workbook_dataset2 "cvd_incidence_rate_ratios"
local workbook_data2    "cvd_incidence_rate_ratios"
local workbook_meta2    "meta_cvd_incidence_rate_ratios"
local workbook_vars2    "vars_cvd_incidence_rate_ratios"

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
    "BNR CVD incidence briefing build" _n ///
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
** ------------------------------------------
** (1) PREPARATION - STANDARD WORLD POPULATION
** ------------------------------------------
** Load and save the WHO standard population
** SOURCE: https://seer.cancer.gov/stdpopulations/world.who.html?utm_source=chatgpt.com
** DOWNLOADED: 4-NOV-2025
** ------------------------------------------
    drop _all 
    #delimit ; 
    input str5 atext spop;
        "0-4"	88569; "5-9" 86870; "10-14"	85970; "15-19"	84670; "20-24"	82171; "25-29"	79272;
        "30-34"	76073; "35-39"	71475; "40-44"	65877; "45-49"	60379; "50-54"	53681; "55-59"	45484;
        "60-64"	37187; "65-69"	29590; "70-74"	22092; "75-79"	15195; "80-84"	9097; "85-89"	4398;
        "90-94"	1500; "95-99"	400; "100+"	50;
    end;
    #delimit cr 
    ** Collapse to 18 age groups in 5 year bands, and 85+
    #delimit ;
        gen age21 = 1 if atext=="0-4"; replace age21 = 2 if atext=="5-9"; replace age21 = 3 if atext=="10-14";
        replace age21 = 4 if atext=="15-19"; replace age21 = 5 if atext=="20-24"; replace age21 = 6 if atext=="25-29";
        replace age21 = 7 if atext=="30-34"; replace age21 = 8 if atext=="35-39"; replace age21 = 9 if atext=="40-44"; 
        replace age21 = 10 if atext=="45-49"; replace age21 = 11 if atext=="50-54"; replace age21 = 12 if atext=="55-59";
        replace age21 = 13 if atext=="60-64"; replace age21 = 14 if atext=="65-69"; replace age21 = 15 if atext=="70-74"; 
        replace age21 = 16 if atext=="75-79"; replace age21 = 17 if atext=="80-84"; replace age21 = 18 if atext=="85-89";
        replace age21 = 19 if atext=="90-94"; replace age21 = 20 if atext=="95-99"; replace age21 = 21 if atext=="100+";
    #delimit cr 
    gen age18 = age21
    recode age18 (18 19 20 21 = 18) 
    collapse (sum) spop , by(age18) 
    rename spop rpop 
    tempfile who_std
    save `who_std', replace
    save "$BNR_PRIVATE_WORK/who_std", replace


** ------------------------------------------
** (2) PREPARATION - UN-WPP (2024) BARBADOS DATA
**     GATHERED USING: -bnrcvd-unwpp.do-
** ------------------------------------------
** Load and save the UN-WPP population data for BRB
** Have hard-coded an auto-download into the do file on next line
** INFO
**      Bearer token required for API access (much the same as for our REDCap API)
*       token received by IanHambleton from UN WPP (3-NOV-2025) 
*       process involved sending email to: population@un.org
*       Short email: just request access
*       Unknown - but possible that token may lapse after a time 
*       Would then need replacing
* do "${dofiles}\bnrcvd-unwpp.do"
** ------------------------------------------
    use "${data}\unwpp_brb_2020_2025.dta", clear 
    keep if variantid == "4" 
    keep iso3 timelabel sex sexid agelabel value 
    * population year 
    gen year = real(timelabel) 
    drop timelabel
    * sex 
    rename sex sexlabel 
    gen sex = real(sexid)
    recode sex (2=1) (1=2)
    label define sex_ 1 "female" 2 "male" 3 "both"
    label values sex sex_
    drop sexid sexlabel 
    * value 
    gen bpop = real(value)
    drop value
    * age 
    ** Collapse to 18 age groups in 5 year bands, and 85+
    #delimit ;
        gen age18 = 1 if agelabel=="0-4"; replace age18 = 2 if agelabel=="5-9"; replace age18 = 3 if agelabel=="10-14";
        replace age18 = 4 if agelabel=="15-19"; replace age18 = 5 if agelabel=="20-24"; replace age18 = 6 if agelabel=="25-29";
        replace age18 = 7 if agelabel=="30-34"; replace age18 = 8 if agelabel=="35-39"; replace age18 = 9 if agelabel=="40-44"; 
        replace age18 = 10 if agelabel=="45-49"; replace age18 = 11 if agelabel=="50-54"; replace age18 = 12 if agelabel=="55-59";
        replace age18 = 13 if agelabel=="60-64"; replace age18 = 14 if agelabel=="65-69"; replace age18 = 15 if agelabel=="70-74"; 
        replace age18 = 16 if agelabel=="75-79"; replace age18 = 17 if agelabel=="80-84"; replace age18 = 18 if agelabel=="85-89";
        replace age18 = 19 if agelabel=="90-94"; replace age18 = 20 if agelabel=="95-99"; replace age18 = 21 if agelabel=="100+";
    #delimit cr 
    recode age18 (18 19 20 21 = 18) 
    collapse (sum) bpop , by(iso3 year sex age18) 
    order year sex age bpop, after(iso3)
    * Manual examination of barbados populations as verification 
    drop if year>=2024
    table (year) (sex) , statistic(sum bpop)
    tempfile brb_pop
    save `brb_pop', replace
    save "$BNR_PRIVATE_WORK/brb_pop", replace

** ------------------------------------------
** (3) PREPARATION - DATASET JOINS
**     WITH and WITHOUT DCO EVENTS
**     THIS ALLOWS (minimal) SENSITIVITY WORK
** ------------------------------------------

** NO DCO (x=1) then WITH DCO (x=0)
forval x = 1(-1)0 {
    if "`x'" == "1" {
        ** ------------------------------------------
        ** (i) BNR CASE DATA and UN-WPP BARBADOS POPULATION
        ** ------------------------------------------
        use "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta", clear 
        drop if dco == `x'
        ** ------------------------------------------
        drop if yoe==2009 
        rename age5 age18 
        rename yoe year
        drop moe agey 
        gen event = 1 
        collapse (sum) event, by(etype year sex age18) 
        fillin etype year sex age18
        sort etype year sex age18
        replace event = 0 if event == . & _fillin == 1 
        drop _fillin 
        tempfile event1_no_dco event2_no_dco event3_no_dco
        save `event1_no_dco', replace 
        * Append a collapsed (m+f) grouping for "both" (sex=3) 
        collapse (sum) event , by(etype year age18)
        gen sex = 3 
        append using `event1_no_dco'
        merge m:1 year sex age18 using `brb_pop'
        drop _merge 
        save `event2_no_dco', replace 
        ** ------------------------------------------
        ** (ii) JOIN RESULT with WHO STD POPULATION
        ** ------------------------------------------
        merge m:1 age18 using `who_std'
        drop _merge 
        gen dco = 0
        save `event3_no_dco', replace 
    }
    else {
        ** ------------------------------------------
        ** (i) BNR CASE DATA and UN-WPP BARBADOS POPULATION
        ** ------------------------------------------
        use "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta", clear 
        drop if yoe==2009 
        rename age5 age18 
        rename yoe year
        drop moe agey 
        gen event = 1 
        collapse (sum) event, by(etype year sex age18) 
        fillin etype year sex age18
        sort etype year sex age18
        replace event = 0 if event == . & _fillin == 1 
        drop _fillin 
        tempfile event1_with_dco event2_with_dco event3_with_dco
        save `event1_with_dco', replace 
        * Append a collapsed (m+f) grouping for "both" (sex=3) 
        collapse (sum) event , by(etype year age18)
        gen sex = 3 
        append using `event1_with_dco'
        merge m:1 year sex age18 using `brb_pop'
        drop _merge 
        save `event2_with_dco', replace 
        ** ------------------------------------------
        ** (ii) JOIN RESULT with WHO STD POPULATION
        ** ------------------------------------------
        merge m:1 age18 using `who_std'
        drop _merge 
        gen dco = 1 
        save `event3_with_dco', replace 
        }
}

** ------------------------------------------
** (4) PREPARATION - DATASET JOINS
**     JOIN DCO and non DCO counts together
** ------------------------------------------
use  `event3_no_dco', replace 
append using `event3_with_dco'
label define dco_ 0 "without dco" 1 "dco added"
label values dco dco_ 
order dco, first 
tempfile figure2_dataset
save `figure2_dataset', replace

** ------------------------------------------
** (5) CREATE INCIDENCE RATE DATASET
** ------------------------------------------
tempfile bnr_incidence bnri_dco bnri_sex bnri_year bnri_etype
qui {
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(etype year sex dco) mult(100000) format(%8.2f) saving(`bnri_dco')
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(etype year dco sex) mult(100000) format(%8.2f) saving(`bnri_sex')
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(etype dco sex year) mult(100000) format(%8.2f) saving(`bnri_year')
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(dco sex year etype ) mult(100000) format(%8.2f) saving(`bnri_etype')
}
** Join the 4 incidence datasets
use `bnri_dco', clear 
    rename srr srr_dco 
    rename lb_srr lbsrr_dco
    rename ub_srr ubsrr_dco
    save `bnri_dco', replace 
use `bnri_sex', clear 
    keep etype year dco sex srr lb_srr ub_srr
    rename srr srr_sex
    rename lb_srr lbsrr_sex
    rename ub_srr ubsrr_sex
    save `bnri_sex', replace 
use `bnri_year', clear 
    keep etype year dco sex srr lb_srr ub_srr
    rename srr srr_year
    rename lb_srr lbsrr_year
    rename ub_srr ubsrr_year
    save `bnri_year', replace 
use `bnri_etype', clear 
    keep etype year dco sex srr lb_srr ub_srr
    rename srr srr_etype
    rename lb_srr lbsrr_etype
    rename ub_srr ubsrr_etype
    save `bnri_etype', replace 
use `bnri_dco'
    qui {
        merge 1:1 etype year dco sex using `bnri_sex', gen(sexmerge)
        merge 1:1 etype year dco sex using `bnri_year', gen(yearmerge)
        merge 1:1 etype year dco sex using `bnri_etype', gen(etypemerge)
    }
    drop *merge 

sort etype dco year sex 
order etype dco year sex event N crude rateadj lb_gam ub_gam se_gam  
label define sex_ 1 "female" 2 "male" 3 "both"
label values sex sex_

** Variable Labelling
label var etype "CVD event type (stroke=1, AMI=2)"
label var year "CVD event year (yyyy)"
label var sex "female=1, male=2, both=3"
label var dco "Death certification only (1=yes, 0=no)"
label var event "Event count"
label var N "Barbados population, from UN-WPP (2024)"
label var crude "Crude rate"
label var rateadj "Adjusted rate"
label var srr_dco "Ratio of adjusted rate - by DCO"
label var lbsrr_dco "Lower bound of ratio of adjusted rate - by DCO"
label var ubsrr_dco "Upper bound of ratio of adjusted rate - by DCO"
label var srr_sex "Ratio of adjusted rate - by sex"
label var lbsrr_sex "Lower bound of ratio of adjusted rate - by sex"
label var ubsrr_sex "Upper bound of ratio of adjusted rate - by sex"
label var srr_year "Ratio of adjusted rate - by year"
label var lbsrr_year "Lower bound of ratio of adjusted rate - by year"
label var ubsrr_year "Upper bound of ratio of adjusted rate - by year"
label var srr_etype "Ratio of adjusted rate - by CVD event type"
label var lbsrr_etype "Lower bound of ratio of adjusted rate - by CVD event type"
label var ubsrr_etype "Upper bound of ratio of adjusted rate - by CVD event type"

save `bnr_incidence', replace
save "${data}/bnrcvd-incidence.dta", replace 

** ---------------------------------------------
** (7) ANALYTICS 1 - EVENT to DCO GAP OVER TIME
** ---------------------------------------------
preserve
    keep rateadj etype sex year dco
    replace rateadj = rateadj - 120 if etype==2
    reshape wide rateadj , i(etype sex year) j(dco)
    label var rateadj0 "Age Standardized rates - hospital events"
    label var rateadj1 "Age Standardized rates - Hospital + Death Certificate Only (DCO) events"

    ** Stroke    
        forval y = 1(1)2 {
            tempvar ta1_`y' tb1_`y' da1_`y' db1_`y'

            gen `ta1_`y'' = rateadj0 if etype==1 & sex==`y' & year==2023
            egen `tb1_`y'' = min(`ta1_`y'')
            global lo1_`y' : display  %5.0f `tb1_`y''    

            gen `da1_`y'' = rateadj1 if etype==1 & sex==`y' & year==2023
            egen `db1_`y'' = min(`da1_`y'')
            global hi1_`y' : display  %5.0f `db1_`y'' 
            drop `ta1_`y'' `tb1_`y'' `da1_`y'' `db1_`y''       
        }
        forval y = 1(1)2 {
            tempvar ta2_`y' tb2_`y' da2_`y' db2_`y'

            gen `ta2_`y'' = rateadj0 + 120 if etype==2 & sex==`y' & year==2023
            egen `tb2_`y'' = min(`ta2_`y'')
            global lo2_`y' : display  %5.0f `tb2_`y''    

            gen `da2_`y'' = rateadj1 + 120 if etype==2 & sex==`y' & year==2023
            egen `db2_`y'' = min(`da2_`y'')
            global hi2_`y' : display  %4.0f `db2_`y''  
            drop `ta2_`y'' `tb2_`y'' `da2_`y'' `db2_`y'' 
        }

        #delimit ;
            gr twoway 
                /// Graph Furniture 
                /// Two Vertical Lines
                (scatteri 200 2023.4 70 2023.4 , recast(line) lw(0.4) lc("${str_f70}%75") lp("l"))
                (scatteri 55 2023.4 -100 2023.4 , recast(line) lw(0.4) lc("${ami_f70}%75") lp("l"))
                /// X-Axis
                (scatteri 62 2010.7 62 2014.4 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 62 2015.7 62 2019.4 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 62 2020.7 62 2023 , recast(line) lw(0.2) lc("gs8") lp("l"))



                /// Graph Data Grids 
                (function y=200, range(2010 2023) lp("-") lc("${str_f70}%50") lw(0.2))
                (function y=150, range(2010 2023) lp("-") lc("${str_f70}%50") lw(0.2))
                (function y=100, range(2010 2023) lp("-") lc("${str_f70}%50") lw(0.2))
                (function y=0,   range(2010 2023) lp("-") lc("${ami_f70}%50") lw(0.2))
                (function y=-50, range(2010 2023) lp("-") lc("${ami_f70}%50") lw(0.2))
                (function y=-100,range(2010 2023) lp("-") lc("${ami_f70}%50") lw(0.2))
                /// Stroke among Men, no DCO (lower line) and DCO (upper line) 
                (rarea rateadj0 rateadj1 year   if year>=2010 & sex==2 & etype==1, lw(none) color("${str_m70}%75"))
                (line rateadj0 year             if year>=2010 & sex==2 & etype==1 , lw(0.3) lc("${str_m}"))
                (line rateadj1 year             if year>=2010 & sex==2 & etype==1 , lw(0.3) lc("${str_m}") lp("-"))
                /// Stroke among Women, no DCO (lower line) and DCO (upper line) 
                (rarea rateadj0 rateadj1 year   if year>=2010 & sex==1 & etype==1, lw(none) color("${str_f70}%75"))
                (line rateadj0 year             if year>=2010 & sex==1 & etype==1 , lw(0.3) lc("${str_f}"))
                (line rateadj1 year             if year>=2010 & sex==1 & etype==1 , lw(0.3) lc("${str_f}") lp("-"))
                /// AMI among Men, no DCO (lower line) and DCO (upper line) 
                (rarea rateadj0 rateadj1 year   if year>=2010 & sex==2 & etype==2, lw(none) color("${ami_m70}%75"))
                (line rateadj0 year             if year>=2010 & sex==2 & etype==2 , lw(0.3) lc("${ami_m}"))
                (line rateadj1 year             if year>=2010 & sex==2 & etype==2 , lw(0.3) lc("${ami_m}") lp("-"))
                /// AMI among Women, no DCO (lower line) and DCO (upper line) 
                (rarea rateadj0 rateadj1 year   if year>=2010 & sex==1 & etype==2, lw(none) color("${ami_f70}%75"))
                (line rateadj0 year             if year>=2010 & sex==1 & etype==2 , lw(0.3) lc("${ami_f}"))
                (line rateadj1 year             if year>=2010 & sex==1 & etype==2 , lw(0.3) lc("${ami_f}") lp("-"))

                ,
                    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
                    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 
                    ysize(9) xsize(19)

                    xlab(none, 
                    valuelabel labc(gs0) labs(2.5) notick nogrid angle(45) format(%9.0f))
                    xscale(noline lw(vthin) range(2010(1)2028)) 
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(none,
                    labc(gs0) labs(7) tlc(gs8) nogrid angle(0) format(%9.0f))
                    yscale(noline noextend range(-120(5)225)) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// Graphic Text
                    text(62 2025.75 `"{fontface "Montserrat Light": 2023 Rates}"' ,  place(c) size(5) color(gs8))
                    /// X-Axis text
                    text(62 2010 `"{fontface "Montserrat Light": 2010}"' ,  place(c) size(5) color(gs8))
                    text(62 2015 `"{fontface "Montserrat Light": 2015}"' ,  place(c) size(5) color(gs8))
                    text(62 2020 `"{fontface "Montserrat Light": 2020}"' ,  place(c) size(5) color(gs8))

                    /// Title 
                    text(-130 2009 "Heart Attacks Claim More Lives Before Hospital Care: Age-Adjusted Rates in Barbados, 2010–2023",  place(e) size(4) color(gs4))

                    /// (Right hand side) Hospital Rates by Sex and Event type 
                    text(180 2025.51 "Men"               ,  place(w) size(5) color("${str_m}%75"))
                    text(180 2028 "${lo1_2} ${endash}${hi1_2}" ,  place(w) size(5) color("${str_m}%75"))
                    text(130 2025.51 "Women"             ,  place(w) size(5) color("${str_f}"))
                    text(130 2028 "${lo1_1} ${endash}${hi1_1}" ,  place(w) size(5) color("${str_f}"))

                    text(0 2025.51 "Men"               ,  place(w) size(5) color("${ami_m}%75"))
                    text(0 2028 "${lo2_2} ${endash}${hi2_2}" ,  place(w) size(5) color("${ami_m}%75"))
                    text(-50 2025.51 "Women"             ,  place(w) size(5) color("${ami_f}%75"))
                    text(-50 2028 "${lo2_1} ${endash}${hi2_1}" ,  place(w) size(5) color("${ami_f}%75"))

                    legend(off)

                    name(incidence_figure1, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output1'.png", replace width(3000)

    ** Statistics to accompany figure 1
    * (A) Difference between Lo and Hi in 2023
    replace rateadj0 = rateadj0 + 120 if etype==2
    replace rateadj1 = rateadj1 + 120 if etype==2
    gen diff = rateadj1 - rateadj0 
    * Put the 2023 differences into globals

    forval x = 1(1)2 {
        forval y = 1(1)2 {
            tempvar t1 t2 t3 t4
            gen `t1' = diff if etype==`x' & sex==`y' & year==2023
            egen `t2' = min(`t1')
            global d_`x'`y' : display  %5.0f `t2'    
            dis "${d_`x'`y'}"
        }
    }

    ** DTA DATASET EXPORT
    notes drop _all
    label data "BNR-CVD Registry: age-group case-count data for 2023 CVD briefing"
    notes _dta: title: BNR-CVD annual incidence (Aggregated) (2010-2023)
    notes _dta: version: v1
    notes _dta: created: 2026-05-05
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual incidence rates 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2010-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by sex and period
    notes _dta: description: Annual age-standardized incidence (2010-2023), for hospital events and DCO events. We looked at all heart attack and stroke events that were treated in hospital or recorded as the main cause of death.
    notes _dta: limitations: Based on hospital CVD event and DCO events only
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: Barbados National Registry approved cardiovascular registry extract (Jan 2010-Dec 2023)
    notes _dta: contact: Barbados National Registry
    drop diff __*
    save "`stagingdatasets'/`output1'.dta", replace 

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output1'.csv", replace

    ** Dataset-level YAML metadata is created later by bnr_publish_briefing.do
    ** from the released DTA labels and notes.
restore


** ---------------------------------------------
** (8) ANALYTICS 2 - 
** DIRECTLY STANDARDIZED RATE RATIOS
use `figure2_dataset', clear
** ---------------------------------------------
* Rates for hospital event rates ONLY
drop if dco==1 
tempfile bnr_incidence2 bnri_etype bnri_sex bnri_year
** Dataset preparation (we want rate ratio to be >1 for ghraphic ease of interpretation) 
gen etype_reverse = etype 
recode etype_reverse (1=2) (2=1) 
label define etype_reverse_ 1 "AMI" 2 "Stroke" 
label values etype_reverse etype_reverse_ 
gen year2 = .
replace year2 = 1 if year==2010 | year==2011
replace year2 = 2 if year==2012 | year==2013
replace year2 = 3 if year==2014 | year==2015
replace year2 = 4 if year==2016 | year==2017
replace year2 = 5 if year==2018 | year==2019
replace year2 = 6 if year==2020 | year==2021
replace year2 = 7 if year==2022 | year==2023
label define year2_ 1 "2010-2011" 2 "2012-2013" 3 "2014-2015" 4 "2016-2017" 5 "2018-2019" 6 "2020-2021" 7 "2022-2023"
label values year2 year2_ 
noi {
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(etype_reverse) mult(100000) format(%8.2f) saving(`bnri_etype')
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(sex) mult(100000) format(%8.2f) saving(`bnri_sex')
    distrate event bpop using "`who_std'" , stand(age18) popstand(rpop) by(etype_reverse year2) mult(100000) format(%8.2f) saving(`bnri_year')
}
** Join the incidence2 datasets
use `bnri_etype', clear 
    keep etype_reverse srr lb_srr ub_srr
    save `bnri_etype', replace 
use `bnri_sex', clear 
    keep sex srr lb_srr ub_srr
    save `bnri_sex', replace 
use `bnri_year', clear 
    keep etype_reverse year2 srr lb_srr ub_srr
    save `bnri_year', replace 
use `bnri_etype'
append using `bnri_sex', gen(sexmerge)
append using `bnri_year', gen(yearmerge)
** Create final indicator to y-axis 
drop if srr==1 & lb_srr==. & ub_srr==.
drop if sex==3 
gen yaxis = _n 
decode year2, gen(yearlabel)
replace yearlabel = "Stroke (vs. AMI)" if _n==1 
replace yearlabel = "CVD in Men" if _n==2 
labmask yaxis, values(yearlabel)
drop yearlabel
order yaxis srr lb_srr ub_srr 
keep yaxis srr lb_srr ub_srr 
save `bnr_incidence2', replace

replace yaxis = yaxis+2 if yaxis>=9 & yaxis<=14 
replace yaxis = yaxis+1 if yaxis>=3 & yaxis<=8 
label define yaxis_ 1 "Stroke (vs. AMI)" 2 "CVD in Men (vs. Women)"      ///
            4 "Stroke<br>2012-2013 (vs. 2010-11)" 5 "Stroke<br>2014-2015" 6 "Stroke<br>2016-2017" 7 "Stroke<br>2018-2019" 8 "Stroke<br>2020-2021" 9 "Stroke<br>2022-2023"     ///
            11 "AMI<br>2012-2013" 12 "AMI<br>2014-2015" 13 "AMI<br>2016-2017" 14 "AMI<br>2018-2019" 15 "AMI<br>2020-2021" 16 "AMI<br>2022-2023"
label values yaxis yaxis_ 

** Save dataset for use in:
** bnrcvd-2023-tabulations.do
label var yaxis "y-axis categories from incidence briefing: rate ratio figure"
label var srr "Age-standardised rate ratios"
label var lb_srr "Lower bound of SRR"
label var ub_srr "Upper bound of SRR"
format srr lb_srr ub_srr %5.3f 

** Save dataset for use in:
** bnrcvd-2023-tabulations.do
    save "${tempdata}/bnrcvd-incidence-rate-ratios.dta", replace 

** Visual CI tweaks (inaccurate but improve the visual and do not affect the story)
replace lb_srr = lb_srr - 0.05 if yaxis==1
replace ub_srr = ub_srr + 0.05 if yaxis==1
replace lb_srr = lb_srr - 0.05 if yaxis==2
replace ub_srr = ub_srr + 0.05 if yaxis==2

        #delimit ;
            gr twoway 
                /// Graph Furniture 
                /// X-Axis
                (scatteri 17 0.79 17 0.94 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 17 1.06 17 1.44 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 17 1.56 17 1.94 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri 17 2.06 17 2.4 , recast(line) lw(0.2) lc("gs8") lp("l"))
                /// Equality line (rate ratio = 1)
                (scatteri 0.75 1 2 1 , recast(line) lw(0.2) lc("gs0") lp("-"))
                (scatteri 3.5 1 9.5 1 , recast(line) lw(0.2) lc("${str_m70}%75") lp("-"))
                (scatteri 10.5 1 16.5 1 , recast(line) lw(0.2) lc("${ami_m70}%75") lp("-"))

                /// The Data (lines and points) 
                (rspike lb_srr ub_srr yaxis if yaxis==1 , horizontal lw(0.55) color("gs0"))
                (sc yaxis srr               if yaxis==1, msize(1.5) mc("gs16"))
                (sc yaxis srr               if yaxis==1, msize(1) mc("gs0"))
                (rspike lb_srr ub_srr yaxis if yaxis==2 , horizontal lw(0.55) color("gs0"))
                (sc yaxis srr               if yaxis==2, msize(1.5) mc("gs16"))
                (sc yaxis srr               if yaxis==2, msize(1) mc("gs0"))
                (rspike lb_srr ub_srr yaxis if yaxis>=3 & yaxis<=9 , horizontal lw(0.55) color("${str_m70}"))
                (sc yaxis srr               if yaxis>=3 & yaxis<=9, msize(1.5) mc("gs16"))
                (sc yaxis srr               if yaxis>=3 & yaxis<=9, msize(1) mc("${str_m70}"))
                (rspike lb_srr ub_srr yaxis if yaxis>=11 & yaxis<=16 , horizontal lw(0.55) color("${ami_m70}"))
                (sc yaxis srr               if yaxis>=11 & yaxis<=16, msize(1.5) mc("gs16"))
                (sc yaxis srr               if yaxis>=11 & yaxis<=16, msize(1) mc("${ami_m}"))



                ,
                    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
                    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 
                    ysize(14) xsize(14)

                    xlab(none, 
                    labc(gs0) labs(2.5) notick nogrid angle(45) format(%9.0f))
                    xscale(log noline lw(vthin) range(0.5(0.1)2.5)) 
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(none,
                    valuelabel labc(gs0) labs(3) tlc(gs8) notick nogrid angle(0) format(%9.0f))
                    yscale(reverse noline noextend range(0(1)18.5)) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// Title 
                    text(18.5 1 "Strokes outpace Heart Attacks: Incidence Rate Ratios, 2010–2023",  place(c) size(2.5) color(gs4))

                    // X-axis legend
                    text(17 0.75 "0.75",  place(c) size(2) color(gs4))
                    text(17 1 "One",  place(c) size(2) color(gs4))
                    text(17 1.5 "1.5",  place(c) size(2) color(gs4))
                    text(17 2 "2",  place(c) size(2) color(gs4))
                    text(17 2.5 "2.5",  place(c) size(2) color(gs4))

                    /// (Right hand side) Hospital Rates by Sex and Event type 
                    text(1  0.8 "Stroke (vs. AMI)"                ,  place(w) size(2.5) color("gs0"))
                    text(2  0.8 "CVD in Men (vs. Women)"          ,  place(w) size(2.5) color("gs0"))
                    text(3  0.8 "Strokes (vs. 2010-2011)"          ,  place(w) size(2.5) color("${str_m}%75"))
                    text(4  0.8 "2012-2013"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(5  0.8 "2014-2015"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(6  0.8 "2016-2017"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(7  0.8 "2018-2019"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(8  0.8 "2020-2021"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(9  0.8 "2022-2023"                       ,  place(w) size(2.5) color("${str_m}%75"))
                    text(10 0.8 "Heart Attacks (vs. 2010-2011)"   ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(11 0.8 "2012-2013"                       ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(12 0.8 "2014-2015"                       ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(13 0.8 "2016-2017"                       ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(14 0.8 "2018-2019"                       ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(15 0.8 "2020-2021"                       ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(16 0.8 "2022-2023"                       ,  place(w) size(2.5) color("${ami_m}%75"))

                    legend(off)
                    name(incidence_figure2, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output2'.png", replace width(3000)

    ** DTA DATASET EXPORT
    notes drop _all
    label data "BNR-CVD Registry: age-group case-count data for 2023 CVD briefing"
    notes _dta: title: BNR-CVD incidence rate ratios (Aggregated, 2012-2023)
    notes _dta: version: v1
    notes _dta: created: 2026-05-05
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual incidence rate ratios (Men vs Women) 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2010-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by sex and period
    notes _dta: description: Incidence rate ratios (2010-2023) by event type, sex, year. Hospital events only. 
    notes _dta: limitations: Based on hospital CVD event only
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: Barbados National Registry approved cardiovascular registry extract (Jan 2010-Dec 2023)
    notes _dta: contact: Barbados National Registry

    label var yaxis "y-axis categories from incidence briefing: rate ratio figure"
    label var srr "Age-standardised rate ratios"
    label var lb_srr "Lower bound of SRR"
    label var ub_srr "Upper bound of SRR"
    format srr lb_srr ub_srr %5.3f 
    replace srr = round(srr, 0.001)   // 3 decimal places
    replace lb_srr = round(lb_srr, 0.001)   // 3 decimal places
    replace ub_srr = round(ub_srr, 0.001)   // 3 decimal places

    ** Remove visual tweaks for accurate dataset release 
    replace lb_srr = lb_srr + 0.05 if yaxis==1
    replace ub_srr = ub_srr - 0.05 if yaxis==1
    replace lb_srr = lb_srr + 0.05 if yaxis==2
    replace ub_srr = ub_srr - 0.05 if yaxis==2
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
local analysis_script "scripts/stata/briefings/cvd_incidence_2023/`briefing_name'.do"
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

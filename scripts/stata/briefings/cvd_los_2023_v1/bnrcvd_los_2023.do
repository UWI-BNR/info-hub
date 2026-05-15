/* 
* =====================================================================
 DO-FILE:     cvd_los_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD length of stay briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.0

 NOTES:
   This DO file creates the approved output bundle for the static
   2023 CVD length of stay briefing.

   It does not create the final PDF briefing.
   Publication layout is handled by Quarto.

 OUTPUT BUNDLE:
  STAGING: outputs/staging/briefings/cvd_los_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_los_2023_v1/

  readme.txt

  datasets/
    XXX

  figures/
    XXX

  workbook/
    bnr_cvd_los_2023_v1.xlsx

  metadata/
    briefing.yml

  ZIP:
    bnr_cvd_los_2023_v1.zip
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
local baseline_start    2010
local baseline_end      2021
local briefing_id       "cvd_los_2023_v1"
local briefing_name     "cvd_los_2023"
local output1           "cvd_los_median"
local output2           "cvd_los_bed_demand"

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
    "BNR CVD length-of-stay briefing build" _n ///
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
* For a new briefing, adapt Section B as needed.

** ==============================================================
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

    ** YML file export: create YML metadata file associated with dataset
    bnr_yml, ///
        dtafile("`stagingdatasets'/`output1'.dta") ///
        ymlfile("`stagingmetadata'/`output1'.yml") ///
        datasetid("`output1'")

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

    ** YML file export: create YML metadata file associated with dataset
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
*   metadata/cvd_incidence_annual.yml
*   metadata/cvd_incidence_rate_ratios.yml
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
file write `briefingyml' "  Barbados CVD length of stay, 2010-2023" _n
file write `briefingyml' "" _n

file write `briefingyml' "description: |-" _n
file write `briefingyml' "  Public aggregate output package for the BNR CVD length of stay briefing." _n
file write `briefingyml' "" _n

file write `briefingyml' "registry: BNR-CVD" _n
file write `briefingyml' "geography: Barbados" _n
file write `briefingyml' "target_year: `target_year'" _n
file write `briefingyml' "baseline_period: `baseline_start'-`baseline_end'" _n
file write `briefingyml' "" _n

file write `briefingyml' "limitations: |-" _n
file write `briefingyml' "  Counts describe hospital-ascertained cases only." _n
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
file write `briefingyml' "  analysis_script: scripts/stata/briefings/cvd_los_2023/`briefing_name'.do" _n

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

file write `readme' "BNR CVD length of stay briefing output package" _n
file write `readme' "" _n
file write `readme' "Briefing ID: `briefing_id'" _n
file write `readme' "Target year: `target_year'" _n
file write `readme' "Baseline period: `baseline_start'-`baseline_end'" _n
file write `readme' "" _n
file write `readme' "This package contains public aggregate outputs for the BNR CVD length of stay briefing." _n
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
file write `readme' "These length of stay data are based on aggregate hospital-ascertained case counts." _n
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
replace value = "Hospital cardiovascular length of stay in Barbados, 2023" in 2

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
replace value = "Aggregate hospital-ascertained length of stay" in 8

replace field = "Limitation" in 9
replace value = "length of stay based on hospital cases" in 9

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
    metasheet("meta_`output1'") ///
    varsheet("vars_`output1'")


** ==============================================================
** 9.3 Add age-group cases dataset and metadata
** ==============================================================

bnr_workbook, ///
    dtafile("`stagingdatasets'/`output2'.dta") ///
    xlsxfile("`workbook_file'") ///
    datasetid("`output2'") ///
    datasheet("`output2'") ///
    metasheet("meta_`output2'") ///
    varsheet("vars_`output2'")

display as result "Workbook created:"
display as result "  `workbook_file'"


** ==============================================================
** 9.4 CREATE BRIEFING DOWNLOAD MANIFEST
** ==============================================================
*
* Purpose:
*   Create a briefing-level downloads.yml file.
*
* This file describes the public downloadable artefacts in this
* briefing bundle. It is not the final site-wide downloads catalogue.
*
* The Quarto publication layer will later collect downloads.yml files
* from all briefing folders and build the sortable/filterable downloads
* page.
*
* Output:
*   outputs/staging/briefings/{briefing_id}/downloads.yml

local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local site_base    "files/briefings/`briefing_id'"

tempname downloads_yml

file open `downloads_yml' using "`stagingbriefing'/downloads.yml", ///
    write replace text

file write `downloads_yml' "schema: bnr_download_manifest_v1" _n
file write `downloads_yml' "briefing_id: `briefing_id'" _n
file write `downloads_yml' "domain: cvd" _n
file write `downloads_yml' "surveillance_area: CVD" _n
file write `downloads_yml' "period: 2010-2023" _n
file write `downloads_yml' "release_date: `release_date'" _n
file write `downloads_yml' "" _n
file write `downloads_yml' "title: |-" _n
file write `downloads_yml' "  Hospital length of stay in Barbados, 2010-2023" _n
file write `downloads_yml' "" _n
file write `downloads_yml' "description: |-" _n
file write `downloads_yml' "  Public aggregate output package for the BNR CVD length of stay briefing." _n
file write `downloads_yml' "" _n
file write `downloads_yml' "briefing_page: surveillance/cvd/briefings/hospital-los.qmd" _n
file write `downloads_yml' "" _n
file write `downloads_yml' "downloads:" _n

* Full ZIP package
file write `downloads_yml' "  - id: `briefing_id'_zip" _n
file write `downloads_yml' "    title: Full public output package" _n
file write `downloads_yml' "    artefact_type: ZIP package" _n
file write `downloads_yml' "    format: ZIP" _n
file write `downloads_yml' "    file: bnr_`briefing_id'.zip" _n
file write `downloads_yml' "    href: `site_base'/bnr_`briefing_id'.zip" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Complete public download package containing datasets, figures, metadata, workbook, and README file." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 10" _n

* README
file write `downloads_yml' "  - id: `briefing_id'_readme" _n
file write `downloads_yml' "    title: README file" _n
file write `downloads_yml' "    artefact_type: Documentation" _n
file write `downloads_yml' "    format: TXT" _n
file write `downloads_yml' "    file: readme.txt" _n
file write `downloads_yml' "    href: `site_base'/readme.txt" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Plain-text guide to the contents of the public output package." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 20" _n

* Workbook
file write `downloads_yml' "  - id: `briefing_id'_workbook" _n
file write `downloads_yml' "    title: Excel workbook" _n
file write `downloads_yml' "    artefact_type: Workbook" _n
file write `downloads_yml' "    format: XLSX" _n
file write `downloads_yml' "    file: workbook/bnr_`briefing_id'.xlsx" _n
file write `downloads_yml' "    href: `site_base'/workbook/bnr_`briefing_id'.xlsx" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Spreadsheet version of the released datasets, with metadata and variable information sheets." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 30" _n

* Annual incidence CSV
file write `downloads_yml' "  - id: `output1'_csv" _n
file write `downloads_yml' "    title: Annual length of stay dataset" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: CSV" _n
file write `downloads_yml' "    file: datasets/`output1'.csv" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output1'.csv" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Open machine-readable dataset of median annual CVD length of stay for Barbados, 2010-2023." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 40" _n

* Annual incidence DTA
file write `downloads_yml' "  - id: `output1'_dta" _n
file write `downloads_yml' "    title: Annual length of stay dataset, Stata format" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: DTA" _n
file write `downloads_yml' "    file: datasets/`output1'.dta" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output1'.dta" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Stata dataset version of the median annual CVD length of stay data, including labels and dataset notes." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 50" _n

* Annual incidence metadata
file write `downloads_yml' "  - id: `output1'_metadata" _n
file write `downloads_yml' "    title: Annual length of stay metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/`output1'.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/`output1'.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Dataset-level metadata for the median annual CVD length of stay dataset." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 60" _n

* Incidence rate-ratio CSV
file write `downloads_yml' "  - id: `output2'_csv" _n
file write `downloads_yml' "    title: Bed day demand dataset" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: CSV" _n
file write `downloads_yml' "    file: datasets/`output2'.csv" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output2'.csv" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Open machine-readable dataset of CVD bed day demand ." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 70" _n

* Incidence rate-ratio DTA
file write `downloads_yml' "  - id: `output2'_dta" _n
file write `downloads_yml' "    title: Bed day demand dataset, Stata format" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: DTA" _n
file write `downloads_yml' "    file: datasets/`output2'.dta" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output2'.dta" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Stata dataset version of CVD bed day demand, including labels and dataset notes." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 80" _n

* Incidence rate-ratio metadata
file write `downloads_yml' "  - id: `output2'_metadata" _n
file write `downloads_yml' "    title: Bed day demand metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/`output2'.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/`output2'.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Dataset-level metadata for CVD bed day demand." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 90" _n

* Annual incidence figure
file write `downloads_yml' "  - id: `output1'_figure" _n
file write `downloads_yml' "    title: Annual length of stay figure" _n
file write `downloads_yml' "    artefact_type: Figure" _n
file write `downloads_yml' "    format: PNG" _n
file write `downloads_yml' "    file: figures/`output1'.png" _n
file write `downloads_yml' "    href: `site_base'/figures/`output1'.png" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Figure showing median annual CVD length of stay data." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 100" _n

* Incidence rate-ratio figure
file write `downloads_yml' "  - id: `output2'_figure" _n
file write `downloads_yml' "    title: Bed day demand figure" _n
file write `downloads_yml' "    artefact_type: Figure" _n
file write `downloads_yml' "    format: PNG" _n
file write `downloads_yml' "    file: figures/`output2'.png" _n
file write `downloads_yml' "    href: `site_base'/figures/`output2'.png" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Figure showing age-standardised CVD bed day demand." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 110" _n

* Briefing-level metadata
file write `downloads_yml' "  - id: `briefing_id'_briefing_metadata" _n
file write `downloads_yml' "    title: Briefing-level metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/briefing.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/briefing.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Briefing-level metadata describing the public CVD length of stay output package." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 120" _n

file close `downloads_yml'

display as result "Download manifest created:"
display as result "  `stagingbriefing'/downloads.yml"


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

copy "`stagingbriefing'/downloads.yml" ///
     "`publicbriefing'/downloads.yml", replace

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





** ==============================================================
** 11 MIRROR public release bundle --> Site bundle
** ==============================================================
do "scripts/stata/common/mirror_public_to_site.do" "`briefing_id'"

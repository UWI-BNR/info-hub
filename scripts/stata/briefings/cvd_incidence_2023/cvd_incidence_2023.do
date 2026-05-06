/* 
* =====================================================================
 DO-FILE:     cvd_cases_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD case-incidence briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.0

 NOTES:
   This DO file creates the approved output bundle for the static
   2023 CVD case-incidence briefing.

   It does not create the final PDF briefing.
   Publication layout is handled by Quarto.

 OUTPUT BUNDLE:
  STAGING: outputs/staging/briefings/cvd_incidence_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_incidence_2023_v1/

  readme.txt

  datasets/
    cvd_incidence_weekly.dta
    cvd_incidence_weekly.csv
    cvd_incidence_weekly.yml
    cvd_incidence_age_group.dta
    cvd_incidence_age_group.csv
    cvd_incidence_age_group.yml

  figures/
    cvd_incidence_weekly.png
    cvd_incidence_age_group.png

  workbook/
    bnr_cvd_incidence_2023_v1.xlsx

  metadata/
    briefing.yml

  ZIP:
    bnr_cvd_incidence_2023_v1.zip
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
local baseline_end      2022
local briefing_id       "cvd_incidence_2023_v1"
local briefing_name     "cvd_incidence_2023"
local output1           "cvd_incidence_annual"
local output2           "cvd_incidence_rate_ratios"


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
* For a new briefing, adapt Section B as needed.
* The standard release pattern is:
*   1. create final public dataset
*   2. label variables
*   3. add structured dataset notes using notes _dta:
*   4. export CSV and save DTA to stagingdatasets/
*   5. export related figure to stagingfigures/, if relevant

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

    ** YML file export: create YML metadata file associated with dataset
    bnr_yml, ///
        dtafile("`stagingdatasets'/`output1'.dta") ///
        ymlfile("`stagingmetadata'/`output1'.yml") ///
        datasetid("`output1'")
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
            4 "2012-2013 (vs. 2010-11)" 5 "2014-2015" 6 "2016-2017" 7 "2018-2019" 8 "2020-2021" 9 "2022-2023"     ///
            11 "2012-2013" 12 "2014-2015" 13 "2016-2017" 14 "2018-2019" 15 "2020-2021" 16 "2022-2023"
label values yaxis yaxis_ 

** Save dataset for use in:
** bnrcvd-2023-tabulations.do
label var yaxis "y-axis categories from incidence briefing: rate ratio figure"
label var srr "Age-standardised rate ratios"
label var lb_srr "Lower bound of SRR"
label var ub_srr "Upper bound of SRR"
format srr lb_srr ub_srr %5.3f 
**save "${tempdata}/bnrcvd-incidence-rate-ratios.dta", replace 

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
file write `briefingyml' "  Barbados CVD incidence rates, 2010-2023" _n
file write `briefingyml' "" _n

file write `briefingyml' "description: |-" _n
file write `briefingyml' "  Public aggregate output package for the BNR CVD case-incidence briefing." _n
file write `briefingyml' "" _n

file write `briefingyml' "registry: BNR-CVD" _n
file write `briefingyml' "geography: Barbados" _n
file write `briefingyml' "target_year: `target_year'" _n
file write `briefingyml' "baseline_period: `baseline_start'-`baseline_end'" _n
file write `briefingyml' "" _n

file write `briefingyml' "limitations: |-" _n
file write `briefingyml' "  Counts describe hospital-ascertained cases and Death-certified cases only." _n
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

file write `readme' "BNR CVD case-incidence briefing output package" _n
file write `readme' "" _n
file write `readme' "Briefing ID: `briefing_id'" _n
file write `readme' "Target year: `target_year'" _n
file write `readme' "Baseline period: `baseline_start'-`baseline_end'" _n
file write `readme' "" _n
file write `readme' "This package contains public aggregate outputs for the BNR CVD case-incidence briefing." _n
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
file write `readme' "These incidence rates are based on aggregate hospital-ascertained case counts and death-certificate confirmed cases." _n
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
replace value = "Hospital cardiovascular incidence in Barbados, 2023" in 2

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
replace value = "Aggregate hospital-ascertained incidence rates" in 8

replace field = "Limitation" in 9
replace value = "incidence based on hospital cases and death-certificate only cases" in 9

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
file write `downloads_yml' "  Incidence in Barbados, 2010-2023" _n
file write `downloads_yml' "" _n

file write `downloads_yml' "description: |-" _n
file write `downloads_yml' "  Public aggregate output package for the BNR CVD incidence briefing." _n
file write `downloads_yml' "" _n

file write `downloads_yml' "briefing_page: surveillance/cvd/briefings/case-incidence.qmd" _n
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
file write `downloads_yml' "    title: Annual incidence dataset" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: CSV" _n
file write `downloads_yml' "    file: datasets/`output1'.csv" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output1'.csv" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Open machine-readable dataset of annual age-standardised CVD incidence rates for Barbados, 2010-2023." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 40" _n

* Annual incidence DTA
file write `downloads_yml' "  - id: `output1'_dta" _n
file write `downloads_yml' "    title: Annual incidence dataset, Stata format" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: DTA" _n
file write `downloads_yml' "    file: datasets/`output1'.dta" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output1'.dta" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Stata dataset version of the annual CVD incidence data, including labels and dataset notes." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 50" _n

* Annual incidence metadata
file write `downloads_yml' "  - id: `output1'_metadata" _n
file write `downloads_yml' "    title: Annual incidence metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/`output1'.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/`output1'.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Dataset-level metadata for the annual CVD incidence dataset." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 60" _n

* Incidence rate-ratio CSV
file write `downloads_yml' "  - id: `output2'_csv" _n
file write `downloads_yml' "    title: Incidence rate-ratio dataset" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: CSV" _n
file write `downloads_yml' "    file: datasets/`output2'.csv" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output2'.csv" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Open machine-readable dataset of age-standardised CVD incidence rate ratios by event type, sex, and period." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 70" _n

* Incidence rate-ratio DTA
file write `downloads_yml' "  - id: `output2'_dta" _n
file write `downloads_yml' "    title: Incidence rate-ratio dataset, Stata format" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: DTA" _n
file write `downloads_yml' "    file: datasets/`output2'.dta" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output2'.dta" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Stata dataset version of the CVD incidence rate-ratio data, including labels and dataset notes." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 80" _n

* Incidence rate-ratio metadata
file write `downloads_yml' "  - id: `output2'_metadata" _n
file write `downloads_yml' "    title: Incidence rate-ratio metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/`output2'.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/`output2'.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Dataset-level metadata for the CVD incidence rate-ratio dataset." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 90" _n

* Annual incidence figure
file write `downloads_yml' "  - id: `output1'_figure" _n
file write `downloads_yml' "    title: Annual incidence figure" _n
file write `downloads_yml' "    artefact_type: Figure" _n
file write `downloads_yml' "    format: PNG" _n
file write `downloads_yml' "    file: figures/`output1'.png" _n
file write `downloads_yml' "    href: `site_base'/figures/`output1'.png" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Figure showing annual age-standardised CVD incidence rates in Barbados, 2010-2023." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 100" _n

* Incidence rate-ratio figure
file write `downloads_yml' "  - id: `output2'_figure" _n
file write `downloads_yml' "    title: Incidence rate-ratio figure" _n
file write `downloads_yml' "    artefact_type: Figure" _n
file write `downloads_yml' "    format: PNG" _n
file write `downloads_yml' "    file: figures/`output2'.png" _n
file write `downloads_yml' "    href: `site_base'/figures/`output2'.png" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Figure showing age-standardised CVD incidence rate ratios by event type, sex, and period." _n
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
file write `downloads_yml' "      Briefing-level metadata describing the public CVD incidence output package." _n
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

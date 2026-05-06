/* 
* =====================================================================
 DO-FILE:     cvd_case_fatality_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD case-fatality briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.0

 NOTES:
   This DO file creates the approved output bundle for the static
   2023 CVD case-fatality briefing.

   It does not create the final PDF briefing.
   Publication layout is handled by Quarto.

 OUTPUT BUNDLE:
  STAGING: outputs/staging/briefings/cvd_case_fatality_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_case_fatality_2023_v1/

  readme.txt

  datasets/
    cvd_case_fatality_2023.dta
    cvd_case_fatality_2023.csv
    cvd_case_fatality_2023.yml
    cvd_case_fatality_age_group.dta
    cvd_case_fatality_age_group.csv
    cvd_case_fatality_age_group.yml

  figures/
    cvd_case_fatality_2023.png
    cvd_case_fatality_age_group.png

  workbook/
    bnr_cvd_case_fatality_2023_v1.xlsx

  metadata/
    briefing.yml

  ZIP:
    bnr_cvd_case_fatality_2023_v1.zip
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
local briefing_id       "cvd_case_fatality_2023_v1"
local briefing_name     "cvd_case_fatality_2023"
local output1           "cvd_case_fatality_2023"
local output2           "cvd_case_fatality_age_group"


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
    "BNR CVD case-fatality briefing build" _n ///
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
use "$BNR_PRIVATE_WORK\bnrcvd_case_fatality_2023_v1.dta", clear 

** BROAD RESTRICTIONS
** LOOK AT HOSPIPTAL EVENTS FOR NOW - drop DCOs 
drop if dco==1 
drop dco 
drop if yoe==2009  /// This was a setup year - don't report

** INITIAL LOOK AT DATA - ensure numbers linkage with CASE COUNT briefing
** Vital Status At Discarge (sadi, 1=alive, 2=dead) 
**      Incomplete variable
**      Can improve by exploring date of death cf. date of discharge 

* A few date errors in 2010 
replace dod = . if dod>1000000 
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
gen los = dodi - doe 
replace los = (dod - doe) if cf == 3 | cf == 4
drop  doe_dod_diff 
order cf los , after(sadi) 
label var cf "Vital status at discharge/death (with uncertainty)"
label var los "Length of hospital stay (days)"

** Macros for GRAPHIC - FIGURE 2
preserve
    collapse (p50) ap50=agey, by(etype sex) 
    forval x = 1(1)4 {
        local str_`x' = ap50[`x']
    }
restore
preserve 
    collapse (p50) ap50=agey if cf==3, by(etype sex) 
    forval x = 1(1)4 {
        local ami_`x' = ap50[`x']
    }
restore 

tempfile cf_temp1 
save `cf_temp1', replace 

** --------------------------------------------------------------
** (1)  MODELLED PROBABILITY OF DEATH
**      Without then with Age Adjustment
**      For Stroke and AMI separated models
**      Calculate and Add to aggregated dataset 
** --------------------------------------------------------------
preserve
    tempfile str1 str2 str ami1 ami2 ami estimates
    ** Age Adjusted (Poisson)
    tabulate cf, gen(cf) 
    gen event = 1 
    sort yoe etype sex 
    order yoe etype sex 

    ** 2-year intervals 
    gen year2 = .
    replace year2 = 1 if yoe==2010 | yoe==2011
    replace year2 = 2 if yoe==2012 | yoe==2013
    replace year2 = 3 if yoe==2014 | yoe==2015
    replace year2 = 4 if yoe==2016 | yoe==2017
    replace year2 = 5 if yoe==2018 | yoe==2019
    replace year2 = 6 if yoe==2020 | yoe==2021
    replace year2 = 7 if yoe==2022 | yoe==2023

    gen case = cf3 + cf4 

    ** Stroke alone
    logistic case i.sex i.year2 if etype==1
    margins sex#year2, saving(`str1') 
    logistic case agey i.sex i.year2 if etype==1 
    margins sex#year2, saving(`str2')

    ** AMI alone
    logistic case i.sex i.year2 if etype==2
    margins sex#year2, saving(`ami1')
    logistic case agey i.sex i.year2 if etype==2 
    margins sex#year2, saving(`ami2')

    use `str1', clear
        rename _margin est 
        rename _ci_lb est_lb
        rename _ci_ub est_ub
        rename _m1 sex 
        rename _m2 year2
        gen etype = 1
        keep etype sex year2 est*  
        order etype sex year2 est*  
    save `str1', replace
    use `str2', clear
        rename _margin adj 
        rename _ci_lb adj_lb
        rename _ci_ub adj_ub
        rename _m1 sex 
        rename _m2 year2
        gen etype = 1
        keep etype sex year2 adj*  
        order etype sex year2 adj*  
    save `str2', replace
    use `ami1', clear
        rename _margin est 
        rename _ci_lb est_lb
        rename _ci_ub est_ub
        rename _m1 sex 
        rename _m2 year2
        gen etype = 2
        keep etype sex year2 est*  
        order etype sex year2 est*  
    save `ami1', replace
    use `ami2', clear
        rename _margin adj 
        rename _ci_lb adj_lb
        rename _ci_ub adj_ub
        rename _m1 sex 
        rename _m2 year2
        gen etype = 2
        keep etype sex year2 adj*  
        order etype sex year2 adj*  
    save `ami2', replace

    use `str1', clear 
    merge 1:1 etype sex year2 using `str2'
    save `str', replace 
    use `ami1', clear 
    merge 1:1 etype sex year2 using `ami2'
    save `ami', replace 
    
    use `str', clear 
    append using `ami'
    drop _merge
    save `estimates', replace
restore



** FIGURE 2 (AGE DIFFERENCES BY SEX)
        #delimit ;
            gr twoway 
                /// Graph Furniture Placeholder (need 1 graphic even though this is effectively a Table)
                (scatteri 30 1 30 1.5 , recast(line) lw(none) lc("gs16") lp("l"))
                ,
                    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=0 r=0 b=0 t=0)) 		
                    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=0 r=0 b=0 t=0)) 
                    ysize(2) xsize(16)

                    xlab(none, 
                    valuelabel labc(gs16) labs(2.5) notick nogrid angle(45) format(%9.0f))
                    xscale(noline lw(vthin) range(0.8(0.2)13.2) ) 
                    xtitle(" ", size(3) color(gs16) margin(l=0 r=0 t=0 b=0)) 
                    
                    ylab(20(1)40,
                    labgap(5) labc(gs16) labs(6) tlc(gs16) notick nogrid angle(0) format(%9.0f))
                    yscale(off noextend) 
                    ytitle(" ", color(gs16) size(4.5) margin(l=0 r=0 t=0 b=0)) 

                    /// Legend text 
                    text(37 6 `"{fontface "Montserrat Light": Admitted}"' ,  place(c) size(15) color("gs0"))

                    text(30 4.7 `"{fontface "Montserrat Light": Women (Age in yrs)}"' ,  place(w) size(15) color("gs0"))
                    text(30 5.8 `"{fontface "Montserrat Light": `str_1'}"'    ,  place(w) size(25) color("${str_f}"))
                    text(30 6.2 `"{fontface "Montserrat Light": |}"'     ,  place(w) size(25) color("gs0"))
                    text(30 7 `"{fontface "Montserrat Light": `ami_1'}"'      ,  place(w) size(25) color("${ami_f}"))

                    text(22 4.7 `"{fontface "Montserrat Light": Men (Age in yrs)}"' ,  place(w) size(15) color("gs0"))
                    text(22 5.8 `"{fontface "Montserrat Light": `str_2'}"'    ,  place(w) size(25) color("${str_m}"))
                    text(22 6.2 `"{fontface "Montserrat Light": |}"'     ,  place(w) size(25) color("gs0"))
                    text(22 7 `"{fontface "Montserrat Light": `ami_2'}"'      ,  place(w) size(25) color("${ami_m}"))

                    text(37 9 `"{fontface "Montserrat Light": Case Fatality}"' ,  place(c) size(15) color("gs0"))

                    text(30 8.8 `"{fontface "Montserrat Light": `str_3'}"'    ,  place(w) size(25) color("${str_f}"))
                    text(30 9.2 `"{fontface "Montserrat Light": |}"'     ,  place(w) size(25) color("gs0"))
                    text(30 10 `"{fontface "Montserrat Light": `ami_3'}"'      ,  place(w) size(25) color("${ami_f}"))

                    text(22 8.8 `"{fontface "Montserrat Light": `str_4'}"'    ,  place(w) size(25) color("${str_m}"))
                    text(22 9.2 `"{fontface "Montserrat Light": |}"'     ,  place(w) size(25) color("gs0"))
                    text(22 10 `"{fontface "Montserrat Light": `ami_4'}"'      ,  place(w) size(25) color("${ami_m}"))

                    legend(off)

                    name(case_fatality_figure2, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output2'.png", replace width(3000)

** Case-Fatality (2-year intervals for dataset + graphic)
**preserve
    tabulate cf, gen(cf) 
    gen event = 1 

    ** 2-year intervals 
    gen year2 = .
    replace year2 = 1 if yoe==2010 | yoe==2011
    replace year2 = 2 if yoe==2012 | yoe==2013
    replace year2 = 3 if yoe==2014 | yoe==2015
    replace year2 = 4 if yoe==2016 | yoe==2017
    replace year2 = 5 if yoe==2018 | yoe==2019
    replace year2 = 6 if yoe==2020 | yoe==2021
    replace year2 = 7 if yoe==2022 | yoe==2023

    sort yoe etype sex 
    order yoe etype sex 
    collapse (sum) event cf1 cf2 cf3 cf4 cf5 , by(year2 etype sex)
    gen ccase = (cf3 / event) * 100 
    gen pcase = ((cf3 + cf4) / event) * 100 
    ** Merge with estimates
    merge 1:1 etype sex year2 using `estimates'

    drop _merge
    format %4.1f ccase pcase 
    format %9.3f est* adj*
    label define year2_ 1 "2010-2011" 2 "2012-2013" 3 "2014-2015" /// 
                        4 "2016-2017" 5 "2018-2019" 6 "2020-2021" 7 "2022-2023"
    label values year2 year2_ 
    label var event "Number of events"
    label var year2 "Two year intervals between 2010 and 2023"
    label var ccase "Confirmed hospital deaths (percentage)"
    label var pcase "Confirmed + Probable hospital deaths (percentage)"
    label var cf1 "Case-fatality, Confirmed Alive at discharge"
    label var cf2 "Case-fatality, Probably Alive at discharge (death>28 days after event)"
    label var cf3 "Case-fatality, Confirmed CF"
    label var cf4 "Case-fatality, Probably CF (death within 7 days of event)"
    label var cf5 "Case-fatality, Possibly CF (death 7-28 days of event)"
    label var est "CF probability (modelled, unadjusted)"
    label var est_lb "CF probability Lower Bound (modelled, unadjusted)"
    label var est_ub "CF probability Upper Bound (modelled, unadjusted)"
    label var adj "CF probability (modelled, age adjusted)"
    label var adj_lb "CF probability Lower Bound (modelled, age adjusted)"
    label var adj_ub "CF probability Upper Bound (modelled, age adjusted)"

** Dataset for Tabulations
    save "${tempdata}/bnrcvd-case-fatality.dta", replace 

** Recoding x-axis for visual clarity (graph separation)
* x-axis shift
local shift = 6
replace year2 = year2 + `shift' if etype==2 
label define year2_ 1 "2010-2011" 2 "2012-2013" 3 "2014-2015" /// 
                    4 "2016-2017" 5 "2018-2019" 6 "2020-2021" 7 "2022-2023" ///
                    8 "2010-2011" 9 "2012-2013" 10 "2014-2015" /// 
                    11 "2016-2017" 12 "2018-2019" 13 "2020-2021" 14 "2022-2023", modify
label values year2 year2_ 

* Line width / dot size
local dot_out = 7
local dot_in = 5
local lw = 0.75
local lw2 = 0.5
* Strokes 
local start1 = 1
local prob1 = 4
local dots1 = 6
* Heart Attacks 
local start2 = 1 + `shift'
local prob2 = 4 + `shift'
local dots2 = 5 + `shift'

local year "year2"

** Legend location - square (y, x)
local legend_circle1 17.5 1.5
local legend_circle3 17.5 2.6
local legend_circle2 37.5 8
local legend_circle4 37.5 9.1

        #delimit ;
            gr twoway 
                /// Graph Furniture 
                ///  X-Axis
                (scatteri 42 1 42 1.5 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri 42 2.5 42 3.5 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri 42 4.5 42 5.5 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri 42 6.5 42 7 , recast(line) lw(0.2) lc("gs6") lp("l"))

                ///  X-Axis
                (scatteri `legend_circle1' , msize(4) lw(none) mc("${str_m}")  )
                (scatteri `legend_circle3' , msize(4) lw(none) mc("${str_f}")  )
                (scatteri `legend_circle2' , msize(4) lw(none) mc("${ami_m}")  )
                (scatteri `legend_circle4' , msize(4) lw(none) mc("${ami_f}")  )
                
                /// Stroke among Men, no DCO (lower line) and DCO (upper line) 
                (rarea ccase pcase `year'       if `year'>=`prob1' & sex==2 & etype==1, lw(none) color("${str_m70}%75"))
                (line ccase `year'              if `year'>=`start1' & sex==2 & etype==1 , lw(`lw') lc("${str_m}"))
                (line pcase `year'              if `year'>=`prob1' & sex==2 & etype==1 , lw(`lw2') lc("${str_m}") lp("-"))
                (sc ccase `year'                if `year'>=`start1' & `year'<=`dots1' & sex==2 & etype==1 , msymbol(o) msize(`dot_out') mc("gs16"))
                (sc ccase `year'                if `year'>=`start1' & `year'<=`dots1' & sex==2 & etype==1 , msymbol(o) msize(`dot_in') mc("${str_m}"))
                /// Stroke among Women, no DCO (lower line) and DCO (upper line) 
                (rarea ccase pcase `year'       if `year'>=`prob1' & sex==1 & etype==1, lw(none) color("${str_f70}%75"))
                (line ccase `year'              if `year'>=`start1' & sex==1 & etype==1 , lw(`lw') lc("${str_f}"))
                (line pcase `year'              if `year'>=`prob1' & sex==1 & etype==1 , lw(`lw2') lc("${str_f}") lp("-"))
                (sc ccase `year'                if `year'>=`start1' & `year'<=`dots1' & sex==1 & etype==1 , msymbol(o) msize(`dot_out') mc("gs16"))
                (sc ccase `year'                if `year'>=`start1' & `year'<=`dots1' & sex==1 & etype==1 , msymbol(o) msize(`dot_in') mc("${str_f}"))
                /// AMI among Men, no DCO (lower line) and DCO (upper line) 
                (rarea ccase pcase `year'       if `year'>=`prob2' & sex==2 & etype==2, lw(none) color("${ami_m70}%75"))
                (line ccase `year'              if `year'>=`start2' & sex==2 & etype==2 , lw(`lw') lc("${ami_m}"))
                (line pcase `year'              if `year'>=`prob2' & sex==2 & etype==2 , lw(`lw2') lc("${ami_m}") lp("-"))
                (sc ccase `year'                if `year'>=`start2' & `year'<=`dots2' & sex==2 & etype==2 , msymbol(o) msize(`dot_out') mc("gs16"))
                (sc ccase `year'                if `year'>=`start2' & `year'<=`dots2' & sex==2 & etype==2 , msymbol(o) msize(`dot_in') mc("${ami_m}"))
                /// AMI among Women, no DCO (lower line) and DCO (upper line) 
                (rarea ccase pcase `year'       if `year'>=`prob2' & sex==1 & etype==2, lw(none) color("${ami_f70}%75"))
                (line ccase `year'              if `year'>=`start2' & sex==1 & etype==2 , lw(`lw') lc("${ami_f}"))
                (line pcase `year'              if `year'>=`prob2' & sex==1 & etype==2 , lw(`lw2') lc("${ami_f}") lp("-"))
                (sc ccase `year'                if `year'>=`start2' & `year'<=`dots2' & sex==1 & etype==2 , msymbol(o) msize(`dot_out') mc("gs16"))
                (sc ccase `year'                if `year'>=`start2' & `year'<=`dots2' & sex==1 & etype==2 , msymbol(o) msize(`dot_in') mc("${ami_f}"))

                ,
                    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
                    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 
                    ysize(4.25) xsize(16)

                    xlab(none, 
                    valuelabel labc(gs0) labs(2.5) notick nogrid angle(45) format(%9.0f))
                    xscale(noline lw(vthin) range(0.8(0.2)13.2) ) 
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(10(10)40,
                    labgap(5) labc(gs0) labs(6) tlc(gs8) notick nogrid angle(0) format(%9.0f))
                    yscale(noextend range(3(1)45)) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// X-Axis text (LHS)
                    text(42 2 `"{fontface "Montserrat Light": 2012-13}"' ,  place(c) size(6) color(gs6))
                    text(42 4 `"{fontface "Montserrat Light": 2016-17}"' ,  place(c) size(6) color(gs6))
                    text(42 6 `"{fontface "Montserrat Light": 2020-21}"' ,  place(c) size(6) color(gs6))

                    /// Legend text 
                    text(17.5 1.6 `"{fontface "Montserrat Light": Men}"' ,  place(e) size(6) color(gs6))
                    text(17.5 2.7 `"{fontface "Montserrat Light": Women}"' ,  place(e) size(6) color(gs6))
                    text(37.5 8.1 `"{fontface "Montserrat Light": Men}"' ,  place(e) size(6) color(gs6))
                    text(37.5 9.2 `"{fontface "Montserrat Light": Women}"' ,  place(e) size(6) color(gs6))


                    /// Title 
                    text(4 6 "Case-Fatality in Barbados, 2010–2023",  place(c) size(6) color(gs4))

                    legend(off)

                    name(incidence_figure1, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output1'.png", replace width(3000)


    ** DTA DATASET EXPORT
    notes drop _all
    label data "BNR-CVD Registry: annual case-fatality in Barbados, 2023"
    notes _dta: title: BNR-CVD annual case-fatality (Aggregated) (2012-2023)
    notes _dta: version: v1
    notes _dta: created: 2026-05-06
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual case-fatality rates 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2012-2023
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by sex and period
    notes _dta: description: Annual age-standardized case-fatality (2012-2023), for hospital events.
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
file write `briefingyml' "  CVD cases in Barbados, 2023" _n
file write `briefingyml' "" _n

file write `briefingyml' "description: |-" _n
file write `briefingyml' "  Public aggregate output package for the BNR CVD case-fatality briefing." _n
file write `briefingyml' "" _n

file write `briefingyml' "registry: BNR-CVD" _n
file write `briefingyml' "geography: Barbados" _n
file write `briefingyml' "target_year: `target_year'" _n
file write `briefingyml' "baseline_period: `baseline_start'-`baseline_end'" _n
file write `briefingyml' "" _n

file write `briefingyml' "limitations: |-" _n
file write `briefingyml' "  Case-fatality based on hospital-ascertained cases only." _n
file write `briefingyml' "" _n

file write `briefingyml' "datasets:" _n
file write `briefingyml' "  - id: `output1'" _n
file write `briefingyml' "    dta: datasets/`output1'.dta" _n
file write `briefingyml' "    csv: datasets/`output1'.csv" _n
file write `briefingyml' "    yml: metadata/`output1'.yml" _n
file write `briefingyml' "" _n

file write `briefingyml' "figures:" _n
file write `briefingyml' "  - id: `output1'" _n
file write `briefingyml' "    file: figures/`output1'.png" _n
file write `briefingyml' "    source_dataset: `output1'" _n
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

file write `readme' "BNR CVD case-fatality briefing output package" _n
file write `readme' "" _n
file write `readme' "Briefing ID: `briefing_id'" _n
file write `readme' "Target year: `target_year'" _n
file write `readme' "Baseline period: `baseline_start'-`baseline_end'" _n
file write `readme' "" _n
file write `readme' "This package contains public aggregate outputs for the BNR CVD case-fatality briefing." _n
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
file write `readme' "Based on aggregate hospital-ascertained case counts." _n
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
replace value = "Hospital cardiovascular case-fatality in Barbados, 2023" in 2

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
replace value = "Case-fatality based on hospital cases" in 9

export excel using "`workbook_file'", ///
    sheet("readme") firstrow(variables) replace


** ==============================================================
** 9.2 Add 2023 case-fatality dataset and metadata
** ==============================================================
bnr_workbook, ///
    dtafile("`stagingdatasets'/`output1'.dta") ///
    xlsxfile("`workbook_file'") ///
    datasetid("`output1'") ///
    datasheet("`output1'") ///
    metasheet("meta_case_fatality") ///
    varsheet("vars_case_fatality")

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
file write `downloads_yml' "period: `target_year'" _n
file write `downloads_yml' "release_date: `release_date'" _n
file write `downloads_yml' "" _n

file write `downloads_yml' "title: |-" _n
file write `downloads_yml' "  Case-fatality in Barbados" _n
file write `downloads_yml' "" _n

file write `downloads_yml' "description: |-" _n
file write `downloads_yml' "  Public aggregate output package for the BNR CVD case-fatality briefing." _n
file write `downloads_yml' "" _n

file write `downloads_yml' "briefing_page: surveillance/cvd/briefings/case-fatality.qmd" _n
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

* Weekly cases CSV
file write `downloads_yml' "  - id: `output1'_csv" _n
file write `downloads_yml' "    title: Annual case-fatality dataset" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: CSV" _n
file write `downloads_yml' "    file: datasets/`output1'.csv" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output1'.csv" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Open machine-readable dataset of weekly and cumulative hospital CVD case counts for 2023 compared with the 2018-2022 baseline average." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 40" _n

* Weekly cases DTA
file write `downloads_yml' "  - id: `output1'_dta" _n
file write `downloads_yml' "    title: Annual case-fatality dataset, Stata format" _n
file write `downloads_yml' "    artefact_type: Dataset" _n
file write `downloads_yml' "    format: DTA" _n
file write `downloads_yml' "    file: datasets/`output1'.dta" _n
file write `downloads_yml' "    href: `site_base'/datasets/`output1'.dta" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Stata dataset version of the weekly CVD case-fatality data, including labels and dataset notes." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 50" _n

* Weekly cases metadata
file write `downloads_yml' "  - id: `output1'_metadata" _n
file write `downloads_yml' "    title: Weekly case-fatality metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/`output1'.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/`output1'.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Dataset-level metadata for the weekly CVD case-fatality dataset." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 60" _n

* Weekly cases figure
file write `downloads_yml' "  - id: `output1'_figure" _n
file write `downloads_yml' "    title: Weekly case-fatality figure" _n
file write `downloads_yml' "    artefact_type: Figure" _n
file write `downloads_yml' "    format: PNG" _n
file write `downloads_yml' "    file: figures/`output1'.png" _n
file write `downloads_yml' "    href: `site_base'/figures/`output1'.png" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Figure showing annual case-fatality." _n
file write `downloads_yml' "    include_in_listing: true" _n
file write `downloads_yml' "    sort_order: 100" _n

* Briefing-level metadata
file write `downloads_yml' "  - id: `briefing_id'_briefing_metadata" _n
file write `downloads_yml' "    title: Briefing-level metadata" _n
file write `downloads_yml' "    artefact_type: Metadata" _n
file write `downloads_yml' "    format: YML" _n
file write `downloads_yml' "    file: metadata/briefing.yml" _n
file write `downloads_yml' "    href: `site_base'/metadata/briefing.yml" _n
file write `downloads_yml' "    description: |-" _n
file write `downloads_yml' "      Briefing-level metadata describing the public CVD case-fatality output package." _n
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
    "BNR CVD case-fatality briefing public bundle prepared" _n ///
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

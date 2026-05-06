/**************************************************************************
 DO-FILE:     bnrcvd-2023-case-fatality.do
 PROJECT:     BNR Refit Consultancy
 PURPOSE:     - Initial look at BNR in-hospital mortality in 2023
              - Case-fatality 
 
 AUTHOR:      Ian R Hambleton
 DATE:        [2025-11-07]
 VERSION:     [v1.0]

 METADATA:    bnrcvd-2023-mortality.yml (same dirpath/name as dataset)

 NOTES:       BNR case-fatality 
                - by type (AMI, stroke)
                - by year
                - by sex 
                - age-stratified
                - crude and age-standardized to WHO Std Pop (2000)
**************************************************************************/

cap log close 
log using ${logs}\bnrcvd-2023-case-fatality, replace 


** GLOBALS 
do "C:\yasuki\Sync\BNR-sandbox\006-dev\do\bnrcvd-2023-prep1"
do "C:\yasuki\Sync\BNR-sandbox\006-dev\do\bnrcvd-globals"

** --------------------------------------------------------------
** (1) Load the interim dataset - CASE-FATALITY
**     Dataset prepared in: bnrcvd-2023-prep1.do
** --------------------------------------------------------------
use "${tempdata}\bnr-cvd-case-fatality-${today}-prep1.dta", clear 

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

                    name(incidence_figure2, replace)
                    ;
        #delimit cr	
        graph export "${graphs}/bnrcvd-case-fatality-figure2.png", replace width(3000)

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
        graph export "${graphs}/bnrcvd-case-fatality-figure1.png", replace width(3000)


    ** ---------------------------------------------------------
    ** Export acompanying dataset (XLSX and DTA)
    ** With associated dataset-level and variable-level metadata 
    ** ---------------------------------------------------------
    drop cf1 cf2 cf3 cf4 cf5
    * STATA dataset export 
    notes drop _all 
    label data "BNR-CVD Registry: dataset associated with CVD In-Hospital Deaths briefing" 
    note : title("BNR-CVD in-hospital deaths (Case-Fatality, Aggregated)") 
    note : version("1.0") 
    note : created("${todayiso}") 
    note : creator("Ian Hambleton, Analyst") 
    note : registry("CVD") 
    note : content("AGGR") 
    note : tier("ANON") 
    note : temporal("2010-01 to 2023-12") 
    note : spatial("Barbados") 
    note : description("In-hospital deaths (2010-2023) by event type, sex, 2-year time intervals. We analysed hospital admissions for stroke and heart attack in Barbados from 2010 to 2023. For each two-year period, we calculated the proportion of patients who died before discharge — the in-hospital case-fatality rate — by sex. To account for incomplete follow-up in recent years, we showed both confirmed hospital deaths (solid lines) and confirmed + probable deaths (dotted lines), where “probable” refers to patients who died within seven days of their event but whose discharge date has not yet been verified. The figure shows these actual rates; we used separate modelling to estimate uncertainty and adjust for age.") 
    note : language("en") 
    note : format("Stata 19") 
    note : rights("CC BY 4.0 (Attribution)") 
    note : source("Hospital admissions (QEH)") 
    note : contact("ian.hambleton@gmail.com") 
    note : outfile("./bnrcvd-case-fatality-figure1.yml")
    save "${graphs}/bnrcvd-case-fatality-figure1.dta", replace 

    ** Dataset-level metadata using YAML file
    bnryaml using "${graphs}/bnrcvd-case-fatality-figure1.dta", ///
        title("BNR-CVD in-hospital deaths (Case-Fatality, Aggregated)") ///
        version("1.0") ///
        created("${todayiso}") ///
        creator("Ian Hambleton, Analyst") ///
        registry("CVD") ///
        content("AGGR") ///
        tier("ANON") ///
        temporal("2010-01 to 2023-12") ///
        spatial("Barbados") ///
        description("In-hospital deaths (2010-2023) by event type, sex, 2-year time intervals. We analysed hospital admissions for stroke and heart attack in Barbados from 2010 to 2023. For each two-year period, we calculated the proportion of patients who died before discharge — the in-hospital case-fatality rate — by sex. To account for incomplete follow-up in recent years, we showed both confirmed hospital deaths (solid lines) and confirmed + probable deaths (dotted lines), where “probable” refers to patients who died within seven days of their event but whose discharge date has not yet been verified. The figure shows these actual rates; we used separate modelling to estimate uncertainty and adjust for age.") ///
        language("en") ///
        format("Stata 19") ///
        rights("CC BY 4.0 (Attribution)") ///
        source("Hospital admissions (QEH)") ///
        contact("ian.hambleton@gmail.com") /// 
        outfile("./bnrcvd-case-fatality-figure1.yml")

        ** XLS dataset export 
        export excel using "${graphs}/bnrcvd-case-fatality-figure1.xlsx", sheet("data") first(var) replace 
        ** Attach meta-data to Excel spreadsheet. Inputs for DO file below
        global meta_xlsx "${graphs}/bnrcvd-case-fatality-figure1.xlsx"
        global meta_yaml "${graphs}/bnrcvd-case-fatality-figure1.yml"
        * Do file that adds metadata to excel spreadsheet - python code 
        do "C:\yasuki\Sync\BNR-sandbox\006-dev\do\bnrcvd-meta-xlsx.do"


** --------------------------------------------------------------
** REPORT: INITIALIAZE
** --------------------------------------------------------------
putpdf clear 
putpdf begin, pagesize(letter)      ///
    font("Montserrat", 9)       ///
    margin(top,0.5cm)               /// 
    margin(bottom,0.25cm)           ///
    margin(left,0.5cm)              ///
    margin(right,0.25cm)            

** REPORT: PAGE 1 
** TITLE, ATTRIBUTION, DATE of CREATION
** --------------------------------------------------------------
    putpdf table intro = (2,12), width(100%) halign(left)    
    putpdf table intro(.,.), border(all, nil)
    putpdf table intro(1,.), font("Montserrat", 8, 000000)  
    putpdf table intro(1,1)
    putpdf table intro(1,2), colspan(11)
    putpdf table intro(2,1), colspan(12)
    putpdf table intro(1,1)=image("${graphs}/uwi_crest_small.jpg")
    putpdf table intro(1,2)=("In-Hospital Cardiovascular Deaths in Barbados"), /// 
                            halign(left) linebreak font("Montserrat Medium", 12, 000000)
    putpdf table intro(1,2)=("Briefing created by the Barbados National Chronic Disease Registry, "), /// 
                            append halign(left) font("Montserrat", 9, 6d6d6d)
    putpdf table intro(1,2)=("The University of the West Indies. "), halign(left) append font("Montserrat", 9, 6d6d6d) linebreak 
    putpdf table intro(1,2)=("Group Contacts"), /// 
                            halign(left) append italic font("Montserrat", 9, 6d6d6d) 
    putpdf table intro(1,2)=(" ${fisheye} "), /// 
                            halign(left) append font("Montserrat", 9, 6d6d6d) 
    putpdf table intro(1,2)=("Christina Howitt (BNR lead)"), /// 
                            halign(left) append italic font("Montserrat", 9, 6d6d6d) 
    putpdf table intro(1,2)=(" ${fisheye} "), /// 
                            halign(left) append font("Montserrat", 9, 6d6d6d) 
    putpdf table intro(1,2)=("Ian Hambleton (analytics) "), /// 
                            halign(left) append italic font("Montserrat", 9, 6d6d6d) 
    putpdf table intro(1,2)=("${fisheye} Updated on $S_DATE at $S_TIME "), font("Montserrat Medium", 9, 6d6d6d) halign(left) italic append linebreak
    putpdf table intro(2,1)=("${fisheye} For all our surveillance outputs "), /// 
                            halign(left) append font("Montserrat", 10, 434343) 
    putpdf table intro(2,1)=("${fisheye} https://uwi-bnr.github.io/resource-hub/5Downloads/ ${fisheye}"), /// 
                            halign(center) font("Montserrat", 10, 434343) append
                         

** REPORT: PAGE 1 
** WHY THIS MATTERS
** --------------------------------------------------------------
putpdf paragraph ,  font("Montserrat", 1)
#delimit; 
putpdf text ("Why This Matters") , font("Montserrat Medium", 11, 000000) linebreak;
putpdf text ("
Case fatality shows the proportion of patients admitted with a heart attack or stroke who die before leaving hospital. It is one of the clearest indicators of healthcare performance, reflecting how quickly patients reach care and how effectively that care is delivered. Falling rates suggest improvements in detection, treatment, or recovery support, while rising rates may point to delayed presentation, older or more complex patients, or hospital strain. Tracking these trends helps reveal whether hospital outcomes are improving over time.
"), font("Montserrat", 9, 000000) linebreak;
#delimit cr

** REPORT: PAGE 1
** WHAT WE DID
** --------------------------------------------------------------
#delimit ; 
putpdf text ("What We Did") , font("Montserrat Medium", 11, 000000) linebreak;
putpdf text ("
We analysed hospital admissions for stroke and heart attack in Barbados from 2010 to 2023. For each two-year period, we calculated the proportion of patients who died before discharge — the in-hospital case-fatality rate — by sex. To account for incomplete follow-up in recent years, we showed both confirmed hospital deaths (solid lines) and confirmed + probable deaths (dotted lines), where “probable” refers to patients who died within seven days of their event but whose discharge date has not yet been verified. The figure shows these actual rates; we used separate modelling to estimate uncertainty and adjust for age.
"), font("Montserrat", 9, 000000) linebreak;
#delimit cr


** REPORT: PAGE 1
** KEY MESSAGE 1
** CASE FATALITY IS HIGHER IN WOMEN FOR HEART ATTACKS AND STROKES
** --------------------------------------------------------------
#delimit ; 
putpdf paragraph ,  font("Montserrat", 1);
putpdf text ("Case Fatality is Higher in Women for ") , font("Montserrat Medium", 11, 000000) ;
putpdf text ("Heart Attacks ") , font("Montserrat Medium", 11, ${ami_m});
putpdf text ("and ") , font("Montserrat Medium", 11, 000000) ;
putpdf text ("Strokes ") , font("Montserrat Medium", 11, ${str_m70}) linebreak;

** FIGURE 1;
putpdf table f1 = (1,1), width(100%) border(all,nil) halign(center);
putpdf table f1(1,1)=image("${graphs}/bnrcvd-case-fatality-figure1.png");
putpdf paragraph ,  font("Montserrat", 1);
putpdf text ("
Between 2010 and 2023, in-hospital deaths after stroke changed little, while heart attack deaths fluctuated but trended upward. In both conditions, women consistently had higher case-fatality than men. In 2023, 27% of men and 34% of women admitted with cardiovascular disease died before discharge. After adjusting for age, the female rate fell to 30%, showing that age explains about half of this gap. Women admitted with heart attack or stroke were, on average, seven years older than men, and those who died in hospital were similarly older. Seven in ten women, compared with just over half of men, were aged 70 years or older at the time of their event. Even so, women remained more likely to die in hospital than men.
"), font("Montserrat", 9, 000000);
#delimit cr

** FIGURE 2
putpdf table f1 = (1,1), width(100%) border(all,nil) halign(center)
putpdf table f1(1,1)=image("${graphs}/bnrcvd-case-fatality-figure2.png")

** REPORT: PAGE 2
** WHAT THIS MEANS
** --------------------------------------------------------------
#delimit ; 
putpdf paragraph ,  font("Montserrat", 1);
putpdf text ("What This Means") , font("Montserrat Medium", 11, 000000) linebreak ;
putpdf text ("
Case-fatality rates show how outcomes differ once patients reach hospital care. The persistence of higher rates among women—only partly explained by age—highlights the need to understand potential differences in presentation, treatment, or recovery that may affect survival.
"), font("Montserrat", 9, 000000);
#delimit cr

** PDF SAVE
** --------------------------------------------------------------
    putpdf save "${outputs}/bnr-cvd-case-fatality-2023", replace


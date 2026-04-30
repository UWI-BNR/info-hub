/**************************************************************************
 DO-FILE:     bnrcvd-2023-count.do
 PROJECT:     BNR Refit Consultancy
 PURPOSE:     Basic count data for 2023, with comparisons across years
              tabular and visualized 
 
 AUTHOR:      Ian R Hambleton
 DATE:        [2025-11-02]
 VERSION:     [v1.0]

 METADATA:    bnrcvd-2023-count.yml (same dirpath/name as dataset)

 NOTES:       BNR simple CVD counts:
                - by type (AMI, stroke)
                - by year
                - by sex 
                - by age groups

This DO file produces core descriptive counts of cardiovascular events
(stroke and acute myocardial infarction) for 2010–2023, with a focus
on the latest year (2023).

It:
  - Loads the prepared BNR-CVD events dataset and restricts to strokes
    and MIs with valid dates in the analysis period.
  - Generates annual and weekly counts of events by disease type and sex.
  - Compares 2023 cumulative weekly counts with the average of the
    previous five years, and visualises these patterns in a “worm plot”.
  - Calculates the proportion of events occurring before age 70 (premature
    CVD) for men and women, and compares 2023 with the recent 5-year average.
  - Exports figures (PNG) and a short PDF narrative summary for use in
    BNR reporting (e.g. annual report and slide decks).

**************************************************************************/

** ------------------------------------------------
** ----- INITIALIZE DO FILE -----------------------
   * Set path 
   * (EDIT bnrpath.ado 
   *  to change to your LOCAL PATH) 
   bnrpath 

   * GLOBALS. This is a relative FILEPATH
   * Do not need to change 
   do "do/bnrcvd-globals.do"

    ** DATASET PREPARATION 
    do "${do}\bnrcvd-2023-prep1"

   * Log file. This is a relative FILEPATH
   * Do not need to change 
   cap log close 
   log using ${logs}\bnrcvd-2023-count, replace 

   * Initialize 
   version 19 
   clear all
   set more off
** ----- END INITIALIZE DO FILE -------------------
** ------------------------------------------------



** --------------------------------------------------------------
** (1) Load the interim dataset - COUNT
**     Dataset prepared in: bnrcvd-2023-prep1.do
** --------------------------------------------------------------
use "${tempdata}\bnr-cvd-count-${today}-prep1.dta", clear 

** BROAD RESTRICTIONS
** LOOK AT HOSPIPTAL EVENTS FOR NOW - drop DCOs 
drop if dco==1 
drop dco 
drop if yoe==2009  /// This was a setup year - don't report

** --------------------------------------------------------------
** (2) THE ANALYSIS
**      TABLE 1: Total count by year
**      TABLE 2: Percentage of events among ages <70 yrs (overall, by year)
**      FIGURE 1: 'Worm plot' of cumulative 2023 count vs. 5 year av. 
**      FIGURE 2: Heatmap of counts by Year (14 rows) and Day/Week?  
** --------------------------------------------------------------

** --------------------------------------------------------------
** TABLE 1: Total by year
** --------------------------------------------------------------
** Count by year / event type 
    gen event = 1 
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

** --------------------------------------------------------------
** TABLE 2: Counts by sex and broad age group (<70, 70+) 
** --------------------------------------------------------------
    
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


** --------------------------------------------------------------
** FIGURE 1: 'Worm plot' of cumulative count (latest year) vs. 5 year av. 
** --------------------------------------------------------------
preserve
    ** This gives cumulative counts in 2023 vs average of prior 5 years
        gen woe = week(doe) 
        collapse (sum) event , by(yoe woe etype)
        sort etype yoe woe
        ** Cumulative by year/event type
        sort etype yoe woe 
        bysort etype yoe: gen cevent = sum(event) 

    /// --- UPDATE 5-YEAR AVERAGE AS NEEDED --- ///

    ** 5-year average count (women and men combined)
        global thisyr = real(substr("${today}", 1, 4))
        tempvar latestyr time5
        egen `latestyr' = max(yoe) 
        gen time5 = 1
        replace time5 = 2 if `latestyr' != yoe & `latestyr' - yoe < 6 
        replace time5 = 3 if `latestyr' == yoe 

        collapse (sum) event , by(time5 woe etype)
        sort time5 etype woe 
        bysort time5 etype : gen cevent = sum(event)
        keep if time5>1 
        replace cevent = cevent/5 if time5==2
        reshape wide event cevent, i(etype woe) j(time5)

        gen evdiff = cevent3 - cevent2

    #delimit ;
        gr twoway 
            (function y=0, range(1 52) lc(gs8%50) lp("_") lw(0.75))
            (line evdiff woe if etype==1, lw(1) color("${str_m}"))
            (line evdiff woe if etype==2, lw(1) color("${ami_m}"))
            ,
                plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
                graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 
                ysize(4) xsize(16)

                xlab(none, 
                valuelabel labc(gs0) labs(2.5) notick nogrid glc(gs16) angle(45) format(%9.0f))
                xscale(noline lw(vthin)) 
                xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                
                /// --- UPDATE RANGE AS NEEDED --- ///

                ylab(,
                labc(gs0) labs(7) tlc(gs8) nogrid glc(gs16) angle(0) format(%9.0f))
                yscale(lw(vthin) lc(gs8) noextend range(-40(10)70)) 
                ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                /// 5-year average
                text(6.5 52 "5-year average",  place(w) size(8) color(gs4))
                text(-40 26 "Cumulative CVD cases in 2023 compared to 5-year average (2018-2022)",  place(c) size(8) color(gs4))

                legend(off size(2.5) position(9) nobox ring(0) bm(t=1 b=4 l=5 r=0) colf cols(1)
                region(fcolor(gs16)  lw(none) margin(zero)) 
                order(2 1) 
                lab(1 "xx") 
                lab(2 "xx") 		
                )
                name(count_figure1, replace)
                ;
    #delimit cr	

    /// --- UPDATE GRAPH NAME AS NEEDED --- ///

    ** Export figure for briefings (PDF and online) 
    graph export "${graphs}/bnrcvd-count-figure1.png", replace width(3000)

    ** ---------------------------------------------------------
    ** Export acompanying dataset (XLSX and DTA)
    ** With associated dataset-level and variable-level metadata 
    ** ---------------------------------------------------------
    * Label stata variables
    label var etype "stroke=1, AMI=2"
    label var woe "Week of year, 1-52"
    label var event2 "5-year average events in week, 2018-2022"
    label var cevent2 "5-year average cumulative events in week, 2018-2022"
    label var event3 "Events in week, 2023"
    label var cevent3 "Cumulative events in week, 2023"
    label var evdiff "2023 cum - 5-year average events"

    /// --- UPDATE GRAPH METADATA FILE AS NEEDED --- ///

    * STATA dataset export 
    notes drop _all 
    label data "BNR-CVD Registry: dataset associated with CVD cases briefing" 
    note : title("BNR-CVD Cumulative counts (Aggregated)") 
    note : version("1.0") 
    note : created("${todayiso}") 
    note : creator("Ian Hambleton, Analyst") 
    note : registry("CVD") 
    note : content("AGGR") 
    note : tier("ANON") 
    note : temporal("2018-01 to 2023-12") 
    note : spatial("Barbados") 
    note : description("We reviewed all hospital-registered strokes and heart attacks for 2023 and compared them with the previous five years. We examined who was affected—men and women under 70 and those 70 and older—and tracked how cases built up week by week. By comparing 2023 counts with the five-year average, we could see when numbers rose above or fell below what would normally be expected.") 
    note : language("en") 
    note : format("Stata 19") 
    note : rights("CC BY 4.0 (Attribution)") 
    note : source("Hospital admissions (QEH)") 
    note : contact("ian.hambleton@gmail.com") 
    note : outfile("${graphs}/bnrcvd-count-figure1.yml")
    save "${graphs}/bnrcvd-count-figure1.dta", replace 

    /// --- UPDATE GRAPH METADATA FILE AS NEEDED --- ///

    ** Dataset-level metadata using YAML file
    bnryaml using "${graphs}/bnrcvd-count-figure1.dta", ///
        title("BNR-CVD Cumulative counts (Aggregated)") ///
        version("1.0") ///
        created("${todayiso}") ///
        creator("Ian Hambleton, Analyst") ///
        registry("CVD") ///
        content("AGGR") ///
        tier("ANON") ///
        temporal("2018-01 to 2023-12") ///
        spatial("Barbados") ///
        description("We reviewed all hospital-registered strokes and heart attacks for 2023 and compared them with the previous five years. We examined who was affected—men and women under 70 and those 70 and older—and tracked how cases built up week by week. By comparing 2023 counts with the five-year average, we could see when numbers rose above or fell below what would normally be expected.") ///
        language("en") ///
        format("Stata 19") ///
        rights("CC BY 4.0 (Attribution)") ///
        source("Hospital admissions (QEH)") ///
        contact("ian.hambleton@gmail.com") /// 
        outfile("${Pygraphs}/bnrcvd-count-figure1.yml")

    ** XLS dataset export 
    export excel using "${graphs}/bnrcvd-count-figure1.xlsx", sheet("data") first(var) replace 
    ** Attach meta-data to Excel spreadsheet. Inputs for DO file below
    global meta_xlsx "${Pygraphs}/bnrcvd-count-figure1.xlsx"
    global meta_yaml "${Pygraphs}/bnrcvd-count-figure1.yml"
    * Do file that adds metadata to excel spreadsheet - python code 
    do "${do}\bnrcvd-meta-xlsx.do"
restore


** --------------------------------------------------------------
** FIGURE 2: 
**      Stacked bar of event proportion (<70, +70)
**      Comparing 2023 event numbers to 5-year average  
** --------------------------------------------------------------
preserve

    /// --- UPDATE 5-YEAR AVERAGE AS NEEDED --- ///

    ** 5-year average count (women and men separately)
        global thisyr = real(substr("${today}", 1, 4))
        tempvar latestyr time5
        egen `latestyr' = max(yoe) 
        gen time5 = 1
        replace time5 = 2 if `latestyr' != yoe & `latestyr' - yoe < 6 
        replace time5 = 3 if `latestyr' == yoe 

        collapse (sum) event , by(time5 etype sex age70)
        drop if time5==1 
        sort etype sex time5 age70
        bysort etype sex time5 : egen denom = sum(event)
        replace event = event/5 if time5==2
        replace denom = denom/5 if time5==2
        gen perc = (event/denom) * 100
        drop if age70==1

        gen zero = 0 
        gen p100= 100

        ** Only for visuals, we add 120 to AMI events (etype==2)
        ** This pushes AMI chart panels to the RHS of a single figure
        replace perc = perc+110 if etype==2 
        replace zero = zero+110 if etype==2 
        replace p100 = p100+110 if etype==2 

        ** Legend location - square (y, x)
        local legend_square1 2 225    1.5 225    1.5 230     2 230    2 225
        local legend_square2 2 231    1.5 231    1.5 236     2 236    2 231
        local legend_circle1 1 227.5
        local legend_circle2 1 233.5

#delimit ;
	graph twoway 
		/// Stroke among women (5-year average)
		(rbar p100 perc sex if time5==2 & etype==1 & sex==1, horizontal barwidth(.5)  lc("${str_m70}") lw(0.05) fc("${str_m70}")) 
	    (rbar zero perc sex if time5==2 & etype==1 & sex==1, horizontal barwidth(.5)  lc("${str_m}") lw(0.05) fc("${str_m}")) 
		/// Stroke among men
		(rbar p100 perc sex if time5==2 & etype==1 & sex==2, horizontal barwidth(.5)  lc("${str_m70}") lw(0.05) fc("${str_m70}")) 
	    (rbar zero perc sex if time5==2 & etype==1 & sex==2, horizontal barwidth(.5)  lc("${str_m}") lw(0.05) fc("${str_m}")) 
		/// 2023 points for women and men 
        (scatter sex perc if time5==3 & etype==1 & sex==1, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${str_m70}"))
        (scatter sex perc if time5==3 & etype==1 & sex==2, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${str_m70}"))
		/// AMI among women (5-year average)
		(rbar p100 perc sex if time5==2 & etype==2 & sex==1, horizontal barwidth(.5)  lc("${ami_m70}") lw(0.05) fc("${ami_m70}")) 
	    (rbar zero perc sex if time5==2 & etype==2 & sex==1, horizontal barwidth(.5)  lc("${ami_m}") lw(0.05) fc("${ami_m}")) 
		/// AMI among women (5-year average)
		(rbar p100 perc sex if time5==2 & etype==2 & sex==2, horizontal barwidth(.5)  lc("${ami_m70}") lw(0.05) fc("${ami_m70}")) 
	    (rbar zero perc sex if time5==2 & etype==2 & sex==2, horizontal barwidth(.5)  lc("${ami_m}") lw(0.05) fc("${ami_m}")) 
		/// 2023 points for women and men 
        (scatter sex perc if time5==3 & etype==2 & sex==1, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${ami_m70}"))
        (scatter sex perc if time5==3 & etype==2 & sex==2, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${ami_m70}"))
        (function y=2.75, range(220 220) dropline(220) lc(gs4) lw(0.4))
        (scatteri `legend_square1' , recast(area) lw(none) fc("${str_m70}")  )
        (scatteri `legend_square2' , recast(area) lw(none) fc("${ami_m70}")  )
        (scatteri `legend_circle1' , msize(7) lw(none) mc("${str_m70}")  )
        (scatteri `legend_circle2' , msize(7) lw(none) mc("${ami_m70}")  )

		,
		plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin)) 
		graphregion(c(gs16) ic(gs16) ilw(thin) lw(thin))    
		ysize(4) xsize(20)
	
		xlabel(none , labsize(10) notick nogrid labcolor(gs4))
		xscale(noline noextend range(0(10)275)) 
		xtitle(" ", margin(top) color(gs0) size(2.5)) 

		ylabel(
				2	"Men"
				1	"Women"
		, notick nogrid valuelabel angle(0) labsize(10) labcolor(gs4)) 
		ytitle(" ", axis(1)) 
		yscale(noline range(0(0.25)2.75))

        text(1.75 240 "2018-2022",  place(e) size(10) color(gs4))
        text(1 240    "2023",  place(e) size(10) color(gs4))
        text(-0.2 105 "Proportion 70 years and older with a hospitalised heart attack or stroke",  place(c) size(10) color(gs4))
		text(2.75 5 "<70 yrs", place(e) size(10) color(${str_m}) margin(0 0 0 0))
		text(2.75 95 "70+ yrs", place(w) size(10) color(${str_m70}) margin(0 0 0 0))
		text(2.75 115 "<70 yrs", place(e) size(10) color(${ami_m}) margin(0 0 0 0))
		text(2.75 205 "70+ yrs", place(w) size(10) color(${ami_m70}) margin(0 0 0 0))
		/// text(0.45 25 "25", place(c`') size(10) color(gs4) margin(0 0 0 0))
		text(0.45 50 "50", place(c) size(10) color(gs4) margin(0 0 0 0))
		/// text(0.45 75 "75", place(c) size(10) color(gs4) margin(0 0 0 0))
		text(0.45 100 "100", place(c) size(10) color(gs4) margin(0 0 0 0))
		/// text(0.45 135 "25", place(c`') size(10) color(gs4) margin(0 0 0 0))
		text(0.45 160 "50", place(c) size(10) color(gs4) margin(0 0 0 0))
		/// text(0.45 185 "75", place(c) size(10) color(gs4) margin(0 0 0 0))
		text(0.45 210 "100", place(c) size(10) color(gs4) margin(0 0 0 0))


		legend(off order(3 2 1 7 8) keygap(2) rowgap(2) linegap(0.75)
		cols(1) position(3) size(10) symysize(10) color(gs4)
		label(1 "Never")  
		label(2 "Ever") 
		label(3 "Current") 
		label(7 "UK Current")
		label(8 "UK Ever")
		) 
		name(count_figure2, replace)
	;
    #delimit cr

    /// --- UPDATE GRAPH NAME AS NEEDED --- ///

    graph export "${graphs}/bnrcvd-count-figure2.png", replace width(3000)

    ** ---------------------------------------------------------
    ** Export acompanying dataset (XLSX and DTA)
    ** With associated dataset-level and variable-level metadata 
    ** ---------------------------------------------------------
    replace perc = perc - 110 if etype==2 
    * Label variables
    drop zero p100 
    label define time5_ 2 "5-year baseline (2018-2022)" 3 "2023"
    label values time5 time5_  
    label var etype "stroke=1, AMI=2"
    label var sex "Patient sex (1=female, 2=male)"
    label var age70 "Patient age group (<70 years)"
    label var time5 "Time period (2=2018-2022 baseline, 3=2023)"
    label var event "Event number in people <70 yrs"
    label var denom "Total events in subgroup. For 5-yr baseline = annual average"
    label var perc "Event percentage in people <70 yrs"

    /// --- UPDATE GRAPH METADATA FILE AS NEEDED --- ///

    * STATA dataset export 
    notes drop _all 
    label data "BNR-CVD Registry: dataset associated with CVD cases briefing" 
    note : title("BNR-CVD Cumulative counts (Aggregated)") 
    note : version("1.0") 
    note : created("${todayiso}") 
    note : creator("Ian Hambleton, Analyst") 
    note : registry("CVD") 
    note : content("AGGR") 
    note : tier("ANON") 
    note : temporal("2018-01 to 2023-12") 
    note : spatial("Barbados") ///
    note : description("CVD cases by broad age group (<70., 70+ yrs) in 2023, compared to 5-year average. We reviewed all hospital-registered strokes and heart attacks for 2023 and compared them with the previous five years. We examined who was affected—men and women under 70 and those 70 and older—and tracked how cases built up week by week. By comparing 2023 counts with the five-year average, we could see when numbers rose above or fell below what would normally be expected.") ///
    note : language("en") 
    note : format("Stata 19") 
    note : rights("CC BY 4.0 (Attribution)") 
    note : source("Hospital admissions (QEH)") 
    note : contact("ian.hambleton@gmail.com") 
    note : outfile("${graphs}/bnrcvd-count-figure2.yml")
    save "${graphs}/bnrcvd-count-figure2.dta", replace 

    /// --- UPDATE GRAPH METADATA FILE AS NEEDED --- ///

    ** Dataset-level metadata using YAML file
    bnryaml using "${graphs}/bnrcvd-count-figure2.dta", ///
        title("BNR-CVD Cumulative counts (Aggregated)") ///
        version("1.0") ///
        created("${todayiso}") ///
        creator("Ian Hambleton, Analyst") ///
        registry("CVD") ///
        content("AGGR") ///
        tier("ANON") ///
        temporal("2018-01 to 2023-12") ///
        spatial("Barbados") ///
        description("CVD cases by broad age group (<70., 70+ yrs) in 2023, compared to 5-year average. We reviewed all hospital-registered strokes and heart attacks for 2023 and compared them with the previous five years. We examined who was affected—men and women under 70 and those 70 and older—and tracked how cases built up week by week. By comparing 2023 counts with the five-year average, we could see when numbers rose above or fell below what would normally be expected.") ///
        language("en") ///
        format("Stata 19") ///
        rights("CC BY 4.0 (Attribution)") ///
        source("Hospital admissions (QEH)") ///
        contact("ian.hambleton@gmail.com") /// 
        outfile("${Pygraphs}//bnrcvd-count-figure2.yml")
 
    ** XLS dataset export 
    export excel using "${graphs}/bnrcvd-count-figure2.xlsx", sheet("data") first(var) replace 
    ** Attach meta-data to Excel spreadsheet. Inputs for DO file below.
    global meta_xlsx "${Pygraphs}/bnrcvd-count-figure2.xlsx"
    global meta_yaml "${Pygraphs}/bnrcvd-count-figure2.yml"
    * Do file that adds metadata to excel spreadsheet - python code 
    do "${do}\bnrcvd-meta-xlsx.do"

restore


/// --- BRIEFING LAYOUT FROM HERE. UPDATE AS NEEDED --- ///

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
    putpdf table intro(1,2)=("Hospital Cardiovascular Cases in Barbados"), /// 
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

/// --- BRIEFING TEXT. UPDATE AS NEEDED --- ///

putpdf text ("
Counts are the simplest and most transparent way to show what is happening in our hospital. Each number represents a person who suffered a heart attack or stroke, and together they show the pressure on our health system. Before we can interpret trends or calculate rates, we must first be confident in these raw numbers—how many people were affected, and when. Presenting counts provides the foundation for our remaining surveillance results.
"), font("Montserrat", 9, 000000) linebreak;
#delimit cr

** REPORT: PAGE 1
** WHAT WE DID
** --------------------------------------------------------------
#delimit ; 
putpdf text ("What We Did") , font("Montserrat Medium", 11, 000000) linebreak;

/// --- BRIEFING TEXT. UPDATE AS NEEDED --- ///

putpdf text ("
We reviewed all hospital-registered strokes and heart attacks for 2023 and compared them with the previous five years. We examined who was affected—men and women under 70 and those 70 and older—and tracked how cases built up week by week. By comparing 2023 counts with the five-year average, we could see when numbers rose above or fell below what would normally be expected.
"), font("Montserrat", 9, 000000) linebreak;
#delimit cr


** REPORT: PAGE 1
** KEY MESSAGE 1
** MORE STROKES IN 2023, LESS HEART ATTACKS
** --------------------------------------------------------------
#delimit ; 
putpdf paragraph ,  font("Montserrat", 1);
putpdf text ("More ") , font("Montserrat Medium", 11, );
putpdf text ("Strokes ") , font("Montserrat Medium", 11, ${str_m70});
putpdf text ("in 2023, Less ") , font("Montserrat Medium", 11, 000000) ;
putpdf text ("Heart Attacks") , font("Montserrat Medium", 11, ${ami_m}) linebreak;
** FIGURE 1. ANNUAL CUMULATIVE COUNT vs 5-YEAR AVERAGE;
putpdf table f1 = (1,1), width(80%) border(all,nil) halign(center);
putpdf table f1(1,1)=image("${graphs}/bnrcvd-count-figure1.png");
putpdf paragraph ,  font("Montserrat", 1);

/// --- BRIEFING TEXT. UPDATE AS NEEDED --- ///

putpdf text ("
In 2023, the Barbados National Registry recorded 312 strokes in women and 312 in men, and 105 heart attacks in women compared with 141 in men. Strokes stayed consistently above the five-year average, ending the year about 60 cases higher than expected, while heart attacks remained below average for much of the year. The contrast may reflect how quickly each emergency is recognised and treated—stroke patients often reach hospital sooner through family or bystander action, whereas people with heart attack symptoms may delay seeking care. These differences, along with lingering post-COVID changes in health-seeking behaviour, suggest that hospital activity as much as disease burden may have shifted, underscoring the value of simple counts as an early warning for changes in care and system readiness.
"), font("Montserrat", 9, 000000) linebreak;
#delimit cr


** REPORT: PAGE 1
** KEY MESSAGE 2
** PREMATURE STROKES AND  HEART ATTACKS IN 2023
** --------------------------------------------------------------
#delimit ; 
putpdf paragraph ,  font("Montserrat", 1);
putpdf text ("Strokes ") , font("Montserrat Medium", 11, ${str_m70});
putpdf text ("and ") , font("Montserrat Medium", 11, 000000) ;
putpdf text ("Heart Attacks ") , font("Montserrat Medium", 11, ${ami_m});
putpdf text ("by Age ") , font("Montserrat Medium", 11, 000000) linebreak ;

** FIGURE 2. ANNUAL CUMULATIVE COUNT vs 5-YEAR AVERAGE;
putpdf table f1 = (1,1), width(90%) border(all,nil) halign(center);
putpdf table f1(1,1)=image("${graphs}/bnrcvd-count-figure2.png");
putpdf paragraph ,  font("Montserrat", 1);

/// --- BRIEFING TEXT. UPDATE AS NEEDED --- ///

putpdf text ("
Across both sexes, a large share of cardiovascular events continue to occur before age 70
— highlighting the ongoing burden of premature disease. Among men, over half of all strokes
(54–56%) and nearly two-thirds of heart attacks (63%) affected those under 70. Women fared
slightly better, but still saw around 40% of strokes and nearly half of heart attacks in this
younger age group. The persistence of such high proportions of early events shows that much
of Barbados’ cardiovascular disease remains preventable.
"), font("Montserrat", 9, 000000) linebreak;
#delimit cr


/// --- BRIEFING FILENAME. UPDATE AS NEEDED --- ///

** PDF SAVE
** --------------------------------------------------------------
    putpdf save "${outputs}/bnr-cvd-count-2023", replace


/* 
* =====================================================================
 DO-FILE:     cvd_case_fatality_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD case-fatality briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.1

 NOTES:
   This DO file is the analyst-owned build file for the 2023 CVD
   case-fatality briefing.

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
  STAGING: outputs/staging/briefings/cvd_case_fatality_2023_v1/
  PUBLIC:  outputs/public/briefings/cvd_case_fatality_2023_v1/
  SITE:    site/downloads/files/briefings/cvd_case_fatality_2023_v1/

  Created directly by this DO file:

  datasets/
    cvd_case_fatality_2023.dta
    cvd_case_fatality_2023.csv

  figures/
    cvd_case_fatality_2023.png
    cvd_case_fatality_age_group.png

  metadata/
    release_control.yml

  Created later by the standard publish helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_case_fatality_2023.yml
    briefing.yml

  workbook/
    bnr_cvd_case_fatality_2023_v1.xlsx

  ZIP:
    bnr_cvd_case_fatality_2023_v1.zip
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
local baseline_start    2018
local baseline_end      2022

local briefing_id       "cvd_case_fatality_2023_v1"
local briefing_name     "cvd_case_fatality_2023"
local output_type       "briefing"

local briefing_title    "CVD case-fatality in Barbados, 2012-2023"
local briefing_short    "Case-fatality in Barbados"
local briefing_page     "surveillance/cvd/briefings/case-fatality.qmd"

local surveillance_area "CVD"
local domain            "cvd"
local registry          "BNR-CVD"
local geography         "Barbados"
local period            "`target_year'"

local briefing_description ///
    "Public aggregate output package for the BNR CVD case-fatality briefing."

local briefing_limitations ///
    "Case-fatality based on hospital-ascertained cases only."

local data_note ///
    "Aggregate case-fatality estimates for hospital-ascertained CVD cases."

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

local output1           "cvd_case_fatality_2023"
local output2           "cvd_case_fatality_age_group"

local released_datasets "cvd_case_fatality_2023"
local released_figures  "cvd_case_fatality_2023 cvd_case_fatality_age_group"


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

local workbook_dataset1 "cvd_case_fatality_2023"
local workbook_data1    "cvd_case_fatality_2023"
local workbook_meta1    "meta_case_fatality"
local workbook_vars1    "vars_case_fatality"

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
    "BNR CVD case-fatality briefing build" _n ///
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
local analysis_script "scripts/stata/briefings/cvd_case_fatality_2023/`briefing_name'.do"
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

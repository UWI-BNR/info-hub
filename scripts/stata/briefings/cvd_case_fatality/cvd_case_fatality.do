/* 
* =====================================================================
 DO-FILE:     cvd_case_fatality.do
 PROJECT:     BNR info-hub
 PURPOSE:     Create the annual CVD case-fatality briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v2.0

 NOTES:
   This DO file is the analyst-owned build file for the annual CVD
   case-fatality briefing. The filename is deliberately not tied to one year.

   The design principle is:

     One briefing or output package = one analyst-owned DO file.

   This file should contain all briefing-specific analytical work:
   - loading the versioned Step 3 case-fatality input;
     - deriving the released datasets;
     - applying variable labels and dataset notes;
     - exporting CSV/DTA files into the staging folder;
     - exporting PNG figures into the staging folder;
   - writing a small release-control file for the standard staging helper.

   The repeated release machinery is intentionally NOT written out in
   full here. The final section calls a shared helper DO file which creates
   package metadata, README, workbook, downloads.yml, and review files.

   The analysis run stops at private staging. Approval, creation of the ZIP,
   copying to outputs/public, and website mirroring are separate later actions.

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
  STAGING: outputs/staging/briefings/cvd_case_fatality_{target_year}_v{version}/

  Created directly by this DO file:

  datasets/
    cvd_case_fatality_{target_year}.dta
    cvd_case_fatality_{target_year}.csv

  figures/
    cvd_case_fatality_{target_year}.png
    cvd_case_fatality_age_group.png

  metadata/
    release_control.yml

  Created later by the private staging helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_case_fatality_{target_year}.yml
    briefing.yml

  workbook/
    bnr_cvd_case_fatality_{target_year}_v{version}.xlsx

  review/
    disclosure_flags.csv
    disclosure_review.txt

  PUBLICATION PRODUCT (created only after approval):
    bnr_cvd_case_fatality_{target_year}_v{version}.zip
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
* DO NOT TOUCH: LOAD PROJECT PATHS AND SHARED SETTINGS
* ============================================================================
* Run from the repository root. All machine-specific paths are confined to the
* untracked bnr_paths_LOCAL.do file.
*
* bnr_paths_LOCAL.do:
*   Defines local repository/output paths such as BNR_STAGING,
*   BNR_PUBLIC, BNR_PRIVATE_LOGS, and BNR_PRIVATE_WORK.
*
* bnrcvd_globals.do:
*   Defines shared CVD display settings, including graph colours and
*   other CVD-specific constants.

do "scripts/stata/config/bnr_paths_LOCAL.do"
local localpath "$BNR_REPO"
do "$BNR_STATA/common/bnrcvd_globals.do"


* ============================================================================
* DO NOT TOUCH: READ AND CHECK DIALOG / COMMAND-LINE INPUTS
* ============================================================================
* Usage:
*
*   do cvd_case_fatality.do release_year release_month ///
*       briefing_version [replace]
*
* The briefing analyses complete calendar years through the end of the year
* before the selected Step 3 release. For example, a January 2025 release
* produces analysis through 31 December 2024.

args release_year release_month briefing_version replace_option

if "`release_year'" == "" | "`release_month'" == "" | ///
   "`briefing_version'" == "" {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: required briefing inputs were not supplied." _n ///
        as text "  Files created: No" _n ///
        as text "  Usage: do cvd_case_fatality.do release_year" _n ///
        as text "         release_month briefing_version [replace]" _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

foreach numeric_input in release_year release_month briefing_version {
    capture confirm integer number ``numeric_input''
    if _rc {
        qui {
            noi display as error _n ///
            "------------------------------------------------------------" _n ///
            "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
            "------------------------------------------------------------" _n ///
            as text "  Reason: `numeric_input' must be an integer." _n ///
            as text "  Files created: No" _n ///
            as text "  Next: correct the Briefing Step 1 inputs." _n ///
            as error "------------------------------------------------------------" _n
        }
        exit 198
    }
}

if !inrange(`release_month', 1, 12) {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: release_month must be between 1 and 12." _n ///
        as text "  Files created: No" _n ///
        as text "  Next: correct the Briefing Step 1 inputs." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

local target_year = `release_year' - 1

* The validated 2023 briefing is the earliest package supported by this
* workflow-owned file. Later releases are allowed and are handled below using
* target_year throughout the analysis, figure text and metadata.
if `target_year' < 2023 {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: the selected release would produce a briefing" _n ///
        as text "          for a year earlier than 2023." _n ///
        as result "  Earliest supported dataset release: 2024." _n ///
        as text "  Files created: No" _n ///
        as text "  Next: choose the required 2024 or later release." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

local replace_staging 0
if lower("`replace_option'") == "replace" local replace_staging 1
if "`replace_option'" != "" & lower("`replace_option'") != "replace" {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: the final optional argument must be replace." _n ///
        as text "  Files created: No" _n ///
        as text "  Next: correct the Briefing Step 1 inputs." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}


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

local baseline_start    2018
local baseline_end      2022

* Case-fatality results use fixed two-year periods anchored at 2010-2011.
* When target_year is the first year of a new pair (for example 2024), the
* final displayed period contains that one complete calendar year and is
* labelled "2024". The pair becomes "2024-2025" when the following year's
* data are available.
local analysis_start_year 2010
local number_periods = floor((`target_year' - `analysis_start_year') / 2) + 1

* The case-fatality library contains the deidentified clinical fields required
* for the established fatality derivation: discharge status and dates of event,
* discharge and death. It is deliberately not the count or incidence library.
local input_year `release_year'
local input_month `release_month'
local input_month2 : display %02.0f `input_month'
local input_version2 "01"
local input_yyyymm "`input_year'`input_month2'"
local input_release "`input_year'-`input_month2'"
local input_coverage_date = dofm(ym(`input_year', `input_month') + 1) - 1
local input_coverage : display %tdCCYY-NN-DD `input_coverage_date'
local input_dataset_id "bnr_cvd_input_case_fatality_`input_yyyymm'_v`input_version2'"
local input_file "$BNR_DATA_DERIVED/cvd/y`input_year'/m`input_month2'/metric_inputs/`input_dataset_id'.dta"
local input_yml  "$BNR_DATA_DERIVED/cvd/y`input_year'/m`input_month2'/metric_inputs/`input_dataset_id'.yml"

local briefing_id       "cvd_case_fatality_`target_year'_v`briefing_version'"
local briefing_name     "`briefing_id'"
local output_type       "briefing"

local briefing_title    "CVD case-fatality in Barbados, 2012-`target_year'"
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

* Used both in the public dataset notes and in the release-control contract.
local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")


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

local output1           "cvd_case_fatality_`target_year'"
local output2           "cvd_case_fatality_age_group"

local released_datasets "`output1'"
local released_figures  "`output1' `output2'"


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

local workbook_dataset1 "`output1'"
local workbook_data1    "`output1'"
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
log using "$BNR_PRIVATE_LOGS/`briefing_name'.log", text replace


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
local stagingreview   "`stagingbriefing'/review"

cap mkdir "$BNR_STAGING/briefings"

* An existing package is never replaced silently. The optional replace word is
* allowed only for re-building an unapproved private staging package.
local prior_working_directory "`c(pwd)'"
capture cd "`stagingbriefing'"
local staging_exists = !_rc
capture cd "`prior_working_directory'"

if `staging_exists' & `replace_staging' == 0 {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: the staging package already exists." _n ///
        as result "  Folder: `stagingbriefing'" _n ///
        as text "  Files created: No" _n ///
        as text "  Next: use a new briefing version, or explicitly" _n ///
        as text "        authorise replacement of unapproved staging." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 602
}

cap mkdir "`stagingbriefing'"
cap mkdir "`stagingdatasets'"
cap mkdir "`stagingfigures'"
cap mkdir "`stagingworkbook'"
cap mkdir "`stagingmetadata'"
cap mkdir "`stagingreview'"


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD case-fatality briefing build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:     `briefing_id'" _n ///
    as result "  Output type:     `output_type'" _n ///
    as result "  Dataset release: `input_release' (Step 3 version 01)" _n ///
    as result "  Analysis through: `target_year'" _n ///
    as result "  Baseline:        `baseline_start'-`baseline_end'" _n ///
    as result "  Staging bundle:  `stagingbriefing'" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================
* DO NOT TOUCH: CONFIRM THE VERSIONED STEP 3 INPUT
* ==============================================================
* The legacy prepared-data call has been retired. This briefing begins with
* the narrow deidentified Step 3 case-fatality dataset.

capture confirm file "`input_file'"
if _rc {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: Step 3 case-fatality input not found." _n ///
        as result "  Expected: `input_file'" _n ///
        as text "  Files created: No" _n ///
        as text "  Next: check the selected dataset release and run" _n ///
        as text "        monthly workflow Step 3 if required." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 601
}

capture confirm file "`input_yml'"
if _rc {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: Step 3 input metadata not found." _n ///
        as result "  Expected: `input_yml'" _n ///
        as text "  Files created: No" _n ///
        as text "  Next: check that the selected Step 3 release is complete." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 601
}

use "`input_file'", clear
foreach required_variable in eid dco etype doe yoe moe dodi sadi dod sex agey {
    capture confirm variable `required_variable'
    if _rc {
        qui {
            noi display as error _n ///
            "------------------------------------------------------------" _n ///
            "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
            "------------------------------------------------------------" _n ///
            as text "  Reason: required variable is missing from Step 3 input." _n ///
            as result "  Variable: `required_variable'" _n ///
            as text "  Files created: No" _n ///
            as text "  Next: do not continue; check the Step 3 dataset contract." _n ///
            as error "------------------------------------------------------------" _n
        }
        exit 111
    }
}




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
** (EDIT BLOCK - SECTION B1): LOAD VALIDATED STEP 3 CASE-FATALITY DATASET
** ==============================================================
* The input has already been opened and its contract checked above. Do not
* replace this with the former prepared private dataset.

** BROAD RESTRICTIONS
** LOOK AT HOSPIPTAL EVENTS FOR NOW - drop DCOs 
* Restrict the versioned input to this briefing's declared coverage.
* Later records may be present in the Step 3 source.
quietly count if yoe == `target_year'
if r(N) == 0 {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD CASE-FATALITY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: the Step 3 input contains no records for" _n ///
        as result "          target year `target_year'." _n ///
        as text "  Public files created: No" _n ///
        as text "  Next: check the selected dataset release and its" _n ///
        as text "        declared coverage before rerunning Step 1." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 2000
}

keep if inrange(yoe, `analysis_start_year', `target_year')

* Hospital-ascertained events only: exclude death-certificate-only cases.
drop if dco == 1
drop dco

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

    ** Two-year intervals anchored at 2010-2011.
    ** For the validated 2023 briefing this reproduces the original values
    ** 1 to 7 exactly. A 2024 target adds period 8 containing 2024 alone.
    gen year2 = floor((yoe - `analysis_start_year') / 2) + 1 ///
        if inrange(yoe, `analysis_start_year', `target_year')

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

    ** Use the same fixed periods as the models above.
    gen year2 = floor((yoe - `analysis_start_year') / 2) + 1 ///
        if inrange(yoe, `analysis_start_year', `target_year')

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
    * Create labels for every period present. If target_year is even, the final
    * label is a single year; the following annual release completes the pair.
    forvalues period_number = 1/`number_periods' {
        local period_start = `analysis_start_year' + (2 * (`period_number' - 1))
        local period_end = min(`period_start' + 1, `target_year')

        if `period_start' == `period_end' {
            local period_label "`period_start'"
        }
        else {
            local period_label "`period_start'-`period_end'"
        }

        if `period_number' == 1 {
            label define year2_ `period_number' "`period_label'", replace
        }
        else {
            label define year2_ `period_number' "`period_label'", add
        }
    }
    label values year2 year2_ 
    label var event "Number of events"
    label var year2 "Two-year intervals between 2010 and `target_year'"
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

** The former temporary save for legacy tabulations has been retired. The
** released briefing dataset is saved to the staging package below.

** Create a separate x-axis position for visual clarity.
* Keep year2 unchanged: it is the analytical period used in the public
* dataset, metadata, and disclosure-review worklist.
* The shift keeps the stroke and AMI series in their established side-by-side
* graph layout. With seven periods (the 2023 briefing), shift remains exactly 6.
local shift = `number_periods' - 1
gen int x_position = year2
replace x_position = x_position + `shift' if etype == 2

* Line width / dot size
local dot_out = 7
local dot_in = 5
local lw = 0.75
local lw2 = 0.5
* Strokes 
local start1 = 1
local prob1 = 4
local dots1 = `number_periods' - 1
* Heart Attacks 
local start2 = 1 + `shift'
local prob2 = 4 + `shift'
local dots2 = (`number_periods' - 2) + `shift'

local year "x_position"

** Legend location - square (y, x)
local legend_circle1 17.5 1.5
local legend_circle3 17.5 2.6
local legend_circle2_x = `shift' + 2
local legend_circle4_x = `shift' + 3.1
local legend_text2_x = `legend_circle2_x' + 0.1
local legend_text4_x = `legend_circle4_x' + 0.1
local legend_circle2 37.5 `legend_circle2_x'
local legend_circle4 37.5 `legend_circle4_x'

* Graph limits and the final x-axis segment advance with the number of periods.
* Their 2023 values remain 13.2 and 7, exactly matching the established graph.
local graph_x_max = (2 * `number_periods') - 0.8
local final_axis_segment_end = min(7.5, `number_periods')

* Add later alternate period labels only when they exist. The original three
* labels (2012-13, 2016-17 and 2020-21) remain written explicitly in the graph
* code below so their formatting is untouched.
local later_axis_text ""
if `number_periods' >= 8 {
    forvalues period_number = 8(2)`number_periods' {
        local period_start = `analysis_start_year' + (2 * (`period_number' - 1))
        local period_end = min(`period_start' + 1, `target_year')

        if `period_start' == `period_end' {
            local short_period_label "`period_start'"
        }
        else {
            local short_start = substr("`period_start'", 3, 2)
            local short_end = substr("`period_end'", 3, 2)
            local short_period_label "`short_start'-`short_end'"
        }

        local later_axis_text `"`later_axis_text' text(42 `period_number' "`short_period_label'", place(c) size(6) color(gs6))"'
    }
}

        #delimit ;
            gr twoway 
                /// Graph Furniture 
                ///  X-Axis
                (scatteri 42 1 42 1.5 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri 42 2.5 42 3.5 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri 42 4.5 42 5.5 , recast(line) lw(0.2) lc("gs6") lp("l"))
                (scatteri 42 6.5 42 `final_axis_segment_end' , recast(line) lw(0.2) lc("gs6") lp("l"))

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
                    xscale(noline lw(vthin) range(0.8(0.2)`graph_x_max') )
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(10(10)40,
                    labgap(5) labc(gs0) labs(6) tlc(gs8) notick nogrid angle(0) format(%9.0f))
                    yscale(noextend range(3(1)45)) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// X-Axis text (LHS)
                    text(42 2 `"{fontface "Montserrat Light": 2012-13}"' ,  place(c) size(6) color(gs6))
                    text(42 4 `"{fontface "Montserrat Light": 2016-17}"' ,  place(c) size(6) color(gs6))
                    text(42 6 `"{fontface "Montserrat Light": 2020-21}"' ,  place(c) size(6) color(gs6))
                    `later_axis_text'

                    /// Legend text 
                    text(17.5 1.6 `"{fontface "Montserrat Light": Men}"' ,  place(e) size(6) color(gs6))
                    text(17.5 2.7 `"{fontface "Montserrat Light": Women}"' ,  place(e) size(6) color(gs6))
                    text(37.5 `legend_text2_x' `"{fontface "Montserrat Light": Men}"' ,  place(e) size(6) color(gs6))
                    text(37.5 `legend_text4_x' `"{fontface "Montserrat Light": Women}"' ,  place(e) size(6) color(gs6))


                    /// Title 
                    text(4 `shift' "Case-Fatality in Barbados, 2010–`target_year'",  place(c) size(6) color(gs4))

                    legend(off)

                    name(incidence_figure1, replace)
                    ;
        #delimit cr	
        graph export "`stagingfigures'/`output1'.png", replace width(3000)

    * x_position was created only to lay out the graph.
    * Remove it before exporting the analytical case-fatality dataset.
    drop x_position

    ** DTA DATASET EXPORT
    notes drop _all
    label data "BNR-CVD Registry: annual case-fatality in Barbados, `target_year'"
    notes _dta: title: BNR-CVD annual case-fatality (Aggregated) (2012-`target_year')
    notes _dta: version: v`briefing_version'
    notes _dta: created: `release_date'
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual case-fatality rates 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2012-`target_year'
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by sex and period
    notes _dta: description: Annual age-standardized case-fatality (2012-`target_year'), for hospital events.
    notes _dta: limitations: Based on hospital CVD events
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: `input_dataset_id'
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output1'.dta", replace 

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output1'.csv", replace

    ** Dataset-level YAML metadata is created later by bnr_stage_briefing.do
    ** from the released DTA labels and notes.



** ============================================================================
** DO NOT TOUCH: CREATE THE AUTOMATIC DISCLOSURE-REVIEW WORKLIST
** ============================================================================
* This worklist prompts human review; it does not suppress or alter a value.
* It flags positive underlying event or fatality-category counts below six in
* the aggregate table that supports the released figure and dataset.

preserve
    keep year2 etype sex event cf1 cf2 cf3 cf4 cf5
    reshape long cf, i(year2 etype sex) j(fatality_category)
    keep if cf > 0 & cf < 6

    gen str80 public_file = "`output1'.csv"
    decode etype, gen(event_type)
    decode sex, gen(sex_label)
    decode year2, gen(period_label)
    gen str80 output_section = "Two-year case-fatality estimates"
    gen str100 row_reference = event_type + ", " + sex_label + ", " + period_label
    gen str30 measure = "event or fatality category"
    gen double value = cf
    gen str100 reason = "Positive underlying count below 6"
    gen str80 related_output = "`output1'.png; `output2'.png"

    keep public_file output_section row_reference measure value reason related_output
    count
    if r(N) == 0 {
        set obs 1
        replace public_file = "ALL DECLARED OUTPUTS" in 1
        replace output_section = "Whole briefing" in 1
        replace row_reference = "Not applicable" in 1
        replace measure = "none" in 1
        replace value = . in 1
        replace reason = "No automatic positive-count flags below 6" in 1
        replace related_output = "Human whole-output review still required" in 1
    }

    gen flag_id = _n
    order flag_id public_file output_section row_reference measure value reason related_output
    export delimited using "`stagingreview'/disclosure_flags.csv", replace
restore


** ============================================================================
** DO NOT TOUCH: STANDARD RELEASE CONTROL AND PRIVATE STAGING STEP
** ============================================================================
* The analytical work above is complete. The remaining standard machinery
* describes and packages it privately. It never approves, publishes, mirrors,
* renders Quarto, or creates a ZIP.

local analysis_script "scripts/stata/briefings/cvd_case_fatality/cvd_case_fatality.do"
local control_file "`stagingmetadata'/release_control.yml"
tempname release_control

file open `release_control' using "`control_file'", write replace text
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

do "`localpath'/scripts/stata/common/bnr_stage_briefing.do" "`briefing_id'"

cap log close

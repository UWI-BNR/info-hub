/* 
* =====================================================================
 DO-FILE:     cvd_length_of_stay.do
 PROJECT:     BNR info-hub
 PURPOSE:     Create the annual CVD hospital length-of-stay briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v2.0

 NOTES:
   This DO file is the analyst-owned build file for the CVD hospital
   length-of-stay briefing. The filename is deliberately not tied to one
   reporting year.

   The design principle is:

     One briefing or output package = one analyst-owned DO file.

   This file should contain all briefing-specific analytical work:
     - loading the deidentified Step 3 length-of-stay dataset;
     - deriving the released datasets;
     - applying variable labels and dataset notes;
     - exporting CSV/DTA files into the staging folder;
     - exporting PNG figures into the staging folder;
     - writing a small release-control file for the standard staging helper.

   The repeated release machinery is intentionally NOT written out in
   full here. The final section calls the shared staging helper, which creates
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
  STAGING: outputs/staging/briefings/cvd_los_{target_year}_v{version}/

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

  Created later by the standard staging helper:

  readme.txt
  downloads.yml

  metadata/
    cvd_los_median.yml
    cvd_los_bed_demand.yml
    briefing.yml

  workbook/
    bnr_cvd_los_{target_year}_v{version}.xlsx

  review/
    disclosure_flags.csv
    disclosure_review.txt

  PUBLICATION PRODUCT (created only after approval):
    bnr_cvd_los_{target_year}_v{version}.zip
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
* DO NOT TOUCH: READ AND CHECK DIALOG / COMMAND-LINE INPUTS
* ============================================================================
* Usage:
*
*   do cvd_length_of_stay.do release_year release_month ///
*       briefing_version [replace]
*
* The selected monthly data release determines the reporting period. The
* briefing analyses complete calendar years through the end of the previous
* year. For example, a January 2024 release produces the 2023 briefing.

args release_year release_month briefing_version replace_option

if "`release_year'" == "" | "`release_month'" == "" | ///
   "`briefing_version'" == "" {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: required briefing inputs were not supplied." _n ///
        as text "  Files created: No" _n ///
        as text "  Usage: do cvd_length_of_stay.do release_year" _n ///
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
            "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: release_month must be between 1 and 12." _n ///
        as text "  Files created: No" _n ///
        as text "  Next: correct the Briefing Step 1 inputs." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

local target_year = `release_year' - 1

* The validated legacy output begins with the 2023 briefing. Earlier annual
* packages remain legacy products and are not rebuilt through this workflow.
if `target_year' < 2023 {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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

local baseline_start    2014
local baseline_end      2014

* The first figure groups admissions into fixed two-year periods beginning
* with 2010-2011. If the target year is the first year of a new pair, the
* final displayed period contains that one complete year and is labelled with
* that year alone. It becomes a two-year label when the next year is added.
local analysis_start_year 2010
local number_periods = floor((`target_year' - `analysis_start_year') / 2) + 1

* The source is the narrow, deidentified Step 3 length-of-stay library for the
* selected monthly release. Version 01 is the current Step 3 input contract.
local input_year `release_year'
local input_month `release_month'
local input_month2 : display %02.0f `input_month'
local input_version2 "01"
local input_yyyymm "`input_year'`input_month2'"
local input_release "`input_year'-`input_month2'"
local input_coverage_date = dofm(ym(`input_year', `input_month') + 1) - 1
local input_coverage : display %tdCCYY-NN-DD `input_coverage_date'
local input_dataset_id "bnr_cvd_input_length_of_stay_`input_yyyymm'_v`input_version2'"
local input_file "$BNR_DATA_DERIVED/cvd/y`input_year'/m`input_month2'/metric_inputs/`input_dataset_id'.dta"
local input_yml  "$BNR_DATA_DERIVED/cvd/y`input_year'/m`input_month2'/metric_inputs/`input_dataset_id'.yml"

local briefing_id       "cvd_los_`target_year'_v`briefing_version'"
local briefing_name     "`briefing_id'"
local output_type       "briefing"

local briefing_title    "Barbados CVD length of stay, 2010-`target_year'"
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

* Used in dataset notes and in the release-control contract.
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

local output1           "cvd_los_median"
local output2           "cvd_los_bed_demand"

local released_datasets "cvd_los_median cvd_los_bed_demand"
local released_figures  "cvd_los_median cvd_los_bed_demand"


* ----------------------------------------------------------------------------
* Workbook and download settings
* ----------------------------------------------------------------------------
* These settings tell the standard staging helper what convenience artefacts
* to prepare after the analysis has finished.
*
* create_workbook = 1 creates an XLSX workbook from released DTA datasets.
* create_zip      = 1 requests bnr_{briefing_id}.zip at publication.
* list_zip        = 1 requests that ZIP on the central downloads page.
*
* No ZIP is created in private staging. It is created only by the later,
* explicit approval and publication workflow.
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
log using "$BNR_PRIVATE_LOGS/`briefing_name'.log", text replace


* ============================================================================
* DO NOT TOUCH: STANDARD STAGING FOLDER SETUP
* ============================================================================
* The staging folder is the build area for this briefing/output package.
*
* The public folder is NOT created here. Public release and website mirroring
* are handled only after human review by separate workflow steps.
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

quietly mata: st_local("staging_exists", strofreal(direxists("`stagingbriefing'")))
if "`staging_exists'" == "1" & `replace_staging' == 0 {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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
    "BNR CVD length-of-stay briefing build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:     `briefing_id'" _n ///
    as result "  Output type:     `output_type'" _n ///
    as result "  Dataset release: `input_release' (Step 3 version 01)" _n ///
    as result "  Analysis through: `target_year'" _n ///
    as result "  Bed-day baseline: `baseline_start'" _n ///
    as result "  Staging bundle:  `stagingbriefing'" _n ///
    as text "------------------------------------------------------------" _n


* ==============================================================
* DO NOT TOUCH: CONFIRM THE VERSIONED STEP 3 INPUT
* ==============================================================
* The old prepared-data helper is no longer used. This briefing starts from
* the narrow deidentified Step 3 length-of-stay dataset.

capture confirm file "`input_file'"
if _rc {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: Step 3 length-of-stay input not found." _n ///
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
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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
foreach required_variable in eid dco etype doe yoe doa dodi sadi dod sex {
    capture confirm variable `required_variable'
    if _rc {
        qui {
            noi display as error _n ///
            "------------------------------------------------------------" _n ///
            "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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

quietly count if yoe == `target_year'
if r(N) == 0 {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "CVD LENGTH-OF-STAY BRIEFING STOPPED" _n ///
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




** ==============================================================
** EDIT BLOCK B: BRIEFING-SPECIFIC DATA PREPARATION AND ANALYSIS
** ==============================================================
* For a new briefing, adapt the analytical sections below as needed.
* Keep the release-control and staging sections at the end unchanged unless
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
* YAML metadata and will complete the private staging folder.
** (EDIT BLOCK - SECTION B1): LOAD STEP 3 LENGTH-OF-STAY DATASET
** ==============================================================
    use "`input_file'", clear

** BROAD RESTRICTIONS
** HOSPITAL EVENTS ONLY - drop DCOs.
** Restrict the versioned source to the complete calendar years declared by
** this annual briefing. Later records can be present in the monthly release.
    keep if inrange(yoe, `analysis_start_year', `target_year')
    drop if dco == 1
    drop dco

* IRH 13-NOV-2025 
* Very obvious date errors are converted to missing. This is the established
* legacy briefing treatment and is retained unchanged.
    replace dod = . if dod > 1000000
    replace dodi = . if dodi > 1000000

** TWO-YEAR ADMISSION PERIODS
** The original periods began in 2010-2011. The loop below reproduces those
** exact periods while allowing later complete calendar years to be added.
** An even target year ends with a one-year period, for example "2024".
gen yoa = year(doa)
gen int year2 = .
label define year2_ 0 "All years", replace

forvalues period_number = 1/`number_periods' {
    local period_start = `analysis_start_year' + 2 * (`period_number' - 1)
    local period_end = min(`period_start' + 1, `target_year')

    replace year2 = `period_number' if ///
        inrange(yoa, `period_start', `period_end')

    if `period_start' == `period_end' {
        local period_label "`period_start'"
    }
    else {
        local period_label "`period_start'-`period_end'"
    }

    label define year2_ `period_number' "`period_label'", add
    local period_label_`period_number' "`period_label'"
}

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

** Length of stay is calculated for all records here. The released summaries
** and both figures retain the established restriction to people confirmed
** alive at discharge (cf == 1).
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

** Median regression - exploratory trend checks retained from the legacy file.
** yoe is written explicitly. The former abbreviation "year" could be read as
** year2 after conversion and therefore was unsafe for future maintenance.
qreg los_primary i.etype
qreg los_primary i.sex
qreg los_primary i.etype i.sex
qreg los_primary i.etype i.sex yoe
qreg los_primary i.sex yoe if etype == 1
qreg los_primary i.sex yoe if etype == 2

** Private temporary analysis dataset used by both figure sections.
tempfile pid_los 
save `pid_los', replace 

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
        * A missing year2 means that the admission date/year is missing.
        * Such records cannot belong to a defined two-year period.  They
        * must not be carried into the period-specific denominator, because
        * the later export labels missing year2 as "All years" for display.
        collapse (count) nevent=los_primary if cf==1 & year2 < . , by(etype year2)
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
        ** Annualised counts are retained from the legacy analytical dataset.
        ** They are not displayed, but the denominator now follows the selected
        ** target year rather than assuming exactly 14 years.
        local total_analysis_years = `target_year' - `analysis_start_year' + 1
        gen nevent_1yr = nevent / `total_analysis_years' if yaxis <= 4
        replace nevent_1yr = nevent / 2 if yaxis >= 5

        ** If the final period contains only one year, do not divide it by two.
        if mod(`target_year' - `analysis_start_year', 2) == 0 {
            replace nevent_1yr = nevent if year2 == `number_periods'
        }
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
        * A missing year2 means that the admission date/year is missing.
        * Such records cannot contribute to a defined two-year period.
        * Excluding them here prevents an artificial etype + "All years"
        * row from entering the released dataset and figure.
        collapse (p50) los50=los_primary (p25) los25=los_primary     ///
                 (p75) los75=los_primary (p5) los05=los_primary     /// 
                 (p95) los95=los_primary if cf==1 & year2 < . , by(etype year2)
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
* Spacing between the four y-axis blocks:
*   sex / event type / stroke periods / heart-attack periods.
* For the 2023 briefing these calculations reproduce positions 1-21 exactly.
local stroke_period_start 7
local stroke_period_end = 6 + `number_periods'
local ami_shift_boundary = 7 + `number_periods'
local ami_period_start = 8 + `number_periods'
local ami_period_end = 7 + 2 * `number_periods'
local figure1_axis_y = `ami_period_end' + 1
local figure1_title_y = `ami_period_end' + 2.25
local figure1_y_max = `ami_period_end' + 1.5

replace yaxis = yaxis + 1 if yaxis >=3 
replace yaxis = yaxis + 1 if yaxis >=6 
replace yaxis = yaxis + 1 if yaxis >= `ami_shift_boundary'

* Build the two sets of period labels used down the left side of Figure 1.
* Keeping the label creation here makes later annual extensions automatic
* without changing the established graph design.
local stroke_period_text ""
local ami_period_text ""

forvalues period_number = 1/`number_periods' {
    local stroke_y = `stroke_period_start' + `period_number' - 1
    local ami_y = `ami_period_start' + `period_number' - 1
    local this_period_label "`period_label_`period_number''"

    local stroke_period_text `"`stroke_period_text' text(`stroke_y' -2 "`this_period_label'", place(w) size(2.25) color("${str_m}%75"))"'
    local ami_period_text `"`ami_period_text' text(`ami_y' -2 "`this_period_label'", place(w) size(2.25) color("${ami_m}%75"))"'
}


** ---------------------------------------------
** (8) ANALYTICS 1 - 
** LENGTH of STAY MEDIAN VALUES
** ---------------------------------------------
        #delimit ;
            gr twoway 
                /// Graph Furniture 
                /// X-Axis
                (scatteri `figure1_axis_y' 2 `figure1_axis_y' 4.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri `figure1_axis_y' 5.5 `figure1_axis_y' 9.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri `figure1_axis_y' 10.5 `figure1_axis_y' 14.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                (scatteri `figure1_axis_y' 15.5 `figure1_axis_y' 19.5 , recast(line) lw(0.2) lc("gs8") lp("l"))
                /// Equality line (rate ratio = 1)
                (scatteri 0.75 0  2.0 0 , recast(line) lw(0.2) lc("gs0") lp("-"))
                (scatteri  3.5 0  5.5 0 , recast(line) lw(0.2) lc("gs0") lp("-"))
                (scatteri 6.5 0 `=`stroke_period_end' + 0.5' 0 , recast(line) lw(0.2) lc("${str_m70}%75") lp("-"))
                (scatteri `=`ami_period_start' - 0.5' 0 `figure1_axis_y' 0 , recast(line) lw(0.2) lc("${ami_m70}%75") lp("-"))

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

                (rspike los25 los75 yaxis if inrange(yaxis, `stroke_period_start', `stroke_period_end') , horizontal lw(0.55) color("${str_m70}"))
                (sc yaxis los50           if inrange(yaxis, `stroke_period_start', `stroke_period_end') , msize(1.5) mc("gs16"))
                (sc yaxis los50           if inrange(yaxis, `stroke_period_start', `stroke_period_end') , msize(1) mc("${str_m}"))
                (rspike los25 los75 yaxis if inrange(yaxis, `ami_period_start', `ami_period_end') , horizontal lw(0.55) color("${ami_m70}"))
                (sc yaxis los50           if inrange(yaxis, `ami_period_start', `ami_period_end') , msize(1.5) mc("gs16"))
                (sc yaxis los50           if inrange(yaxis, `ami_period_start', `ami_period_end') , msize(1) mc("${ami_m}"))

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
                    yscale(reverse noline noextend range(0(0.5)`figure1_y_max'))
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// Title 
                    text(`figure1_title_y' 5 "Median Length of Stay (Days), 2010–`target_year'", place(c) size(2.5) color(gs4))

                    // X-axis legend
                    text(`figure1_axis_y' 1 "One", place(c) size(2) color(gs4))
                    text(`figure1_axis_y' 5 "5", place(c) size(2) color(gs4))
                    text(`figure1_axis_y' 10 "10", place(c) size(2) color(gs4))
                    text(`figure1_axis_y' 15 "15", place(c) size(2) color(gs4))
                    text(`figure1_axis_y' 20 "20", place(c) size(2) color(gs4))

                    /// (Right hand side) Hospital Rates by Sex and Event type 
                    text(1   -1 "Women"          ,  place(w) size(2.5) color("gs0"))
                    text(2   -1 "Men"          ,  place(w) size(2.5) color("gs0"))
                    text(4   -1 "Stroke "                ,  place(w) size(2.5) color("${str_m}%75"))
                    text(5   -1 "Heart Attack"          ,  place(w) size(2.5) color("${ami_m}%75"))
                    text(`stroke_period_start' -7 "Stroke", place(w) size(2.5) color("${str_m}%75"))
                    `stroke_period_text'

                    text(`ami_period_start' -7 "Heart Attack ", place(w) size(2.5) color("${ami_m}%75"))
                    `ami_period_text'

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
    label var indicator "Unique summary measure indicator"
    label var etype "CVD event type (stroke=1, AMI=2, Both=3)"
    label var year2 "CVD event year (2-year intervals)"
    label var sex "Female=1, male=2, both=3"
    label var etype "CVD event type (stroke=1, AMI=2)"
    label var sex "Female=1, male=2, both=3"
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
    notes _dta: version: v`briefing_version'
    notes _dta: created: `release_date'
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual median length of stay 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2010-`target_year'
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by period
    notes _dta: description: Annual median length of stay in days.
    notes _dta: limitations: Based on hospital CVD events
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: `input_dataset_id'; complete calendar years 2010-`target_year'
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output1'.dta", replace 

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output1'.csv", replace

    ** Dataset-level YAML metadata is created later by bnr_stage_briefing.do
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

** Now calculate the median difference across years for each event type.
** The legacy analysis uses 2014 as the baseline comparator.
gen t1 = los50 if yoe==2014
bysort etype : egen median2014 = min(t1)
drop t1 
sort yaxis
gen exdays = (los50 - median2014) * nevent
gen exday_week = exdays/52
gen zero = 0

** Shift AMI to Lower Axis 
replace exday_week = exday_week - 30 if etype==2 
gen zero_ami = -30

** Values for the right-hand summary on the graph. The legacy file selected
** fixed observation numbers 10 and 20, which were correct only through 2023.
** Selecting the target-year row explicitly gives the same 2023 values and
** remains correct for later briefings.
gen ex50 = round(exdays/52, 0.1)
format ex50 %4.2f

quietly summarize ex50 if etype == 1 & yoe == `target_year', meanonly
local ex50_str_display : display %4.1f r(mean)

quietly summarize ex50 if etype == 2 & yoe == `target_year', meanonly
local ex50_ami_display : display %4.1f r(mean)

* Figure positions move with the latest complete year. For target year 2023,
* these reduce exactly to the original coordinates.
local figure2_reference_end = `target_year' + 0.5
local figure2_separator_x = `target_year' + 1.5
local figure2_rhs_x = `target_year' + 3.5
local figure2_x_max = `target_year' + 5
local figure2_title_x = `target_year' - 3

* Build the even-year x-axis markers and labels from 2014 onward.
local figure2_tick_segments ""
local figure2_tick_text ""
forvalues tick_year = 2014(2)`target_year' {
    local tick_left = `tick_year' + 0.7
    local tick_right = `tick_year' + 1.3
    local figure2_tick_segments `"`figure2_tick_segments' (scatteri -15 `tick_left' -15 `tick_right', recast(line) lw(0.2) lc("gs6") lp("l"))"'
    local figure2_tick_text `"`figure2_tick_text' text(-15 `tick_year' `"{fontface "Montserrat Light": `tick_year'}"', place(c) size(5) color(gs6))"'
}


** FIGURE 2 - CHANGE IN BED DAYS OVER TIME
        #delimit ;
            gr twoway 
                /// Graph Furniture 
                /// 2014 POINT  - STROKE 
                (scatteri 0 2014.6 0 `figure2_reference_end' , recast(line) lw(0.4) lc("gs0") lp("l"))
                (scatteri 0 2014 , msize(3) mlc("gs0") mlw(0.1) mfc("${str_m}%75") lp("l"))
                /// 2014 POINT  - AMI 
                (scatteri -30 2014.6 -30 `figure2_reference_end' , recast(line) lw(0.4) lc("gs0") lp("l"))
                (scatteri -30 2014 , msize(3) mlc("gs0") mlw(0.1) mfc("${ami_m}%75") lp("l"))
                /// X-Axis
                `figure2_tick_segments'
                /// X AXIS LINE
                (scatteri 30 2013.25 -10 2013.25 , recast(line) lw(0.3) lc("${str_m70}") lp("l"))
                (scatteri -20 2013.25 -32 2013.25 , recast(line) lw(0.3) lc("${ami_m70}") lp(""))
                /// RHS SEPARATOR
                (scatteri -28 `figure2_separator_x' 26 `figure2_separator_x' , recast(line) lw(0.3) lc("gs6") lp("l"))

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
                    xscale(noline lw(vthin) range(2012.5(0.5)`figure2_x_max'))
                    xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1)) 
                    
                    ylab(none,
                    labc(gs0) labs(7) tlc(gs8) nogrid angle(0) format(%9.0f))
                    yscale(noline noextend range(-40(1)35)) 
                    ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1)) 

                    /// X-AXIS TEXT
                    `figure2_tick_text'
                    /// Y-AXIS TEXT
                    text( 30 2012.75 `"{fontface "Montserrat Light": 30}"' ,  place(c) size(5) color("${str_m70}"))
                    text( 20 2012.75 `"{fontface "Montserrat Light": 20}"' ,  place(c) size(5) color("${str_m70}"))
                    text( 10 2012.75 `"{fontface "Montserrat Light": 10}"' ,  place(c) size(5) color("${str_m70}"))
                    text( 0 2012.75  `"{fontface "Montserrat Light": 0}"'  ,  place(c) size(5) color("${str_m70}"))
                    text(-20 2012.75 `"{fontface "Montserrat Light": 10}"' ,  place(c) size(5) color("${ami_m70}"))
                    text(-30 2012.75 `"{fontface "Montserrat Light": 0}"'  ,  place(c) size(5) color("${ami_m70}"))

                    /// Title 
                    text(-40 `figure2_title_x' "Extra typical bed-days, Barbados 2014–`target_year'", place(c) size(4.75) color(gs4))

                    /// (Right hand side) Hospital ETBD/week
                    text(30 `figure2_rhs_x' "Extra Bed Days" , place(c) size(5) color("gs4"))
                    text(25 `figure2_rhs_x' "(`target_year' vs. 2014)" , place(c) size(5) color("gs4"))
                    text(13 `figure2_rhs_x' "`ex50_str_display'" , place(c) size(7) color("${str_m}%75"))
                    text(6 `figure2_rhs_x' "per week" , place(c) size(7) color("${str_m}%75"))
                    text(-17 `figure2_rhs_x' "`ex50_ami_display'" , place(c) size(7) color("${ami_m}%75"))
                    text(-24 `figure2_rhs_x' "per week" , place(c) size(7) color("${ami_m}%75"))

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
    drop median2014 exday_week zero zero_ami ex50
    rename yaxis indicator 
    label var indicator "Unique summary measure indicator"
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
    notes _dta: version: v`briefing_version'
    notes _dta: created: `release_date'
    notes _dta: creator: Ian Hambleton, Analyst
    notes _dta: registry: BNR-CVD
    notes _dta: content: Annual typical bed-days (based on median stay in days) 
    notes _dta: tier: Public aggregate output
    notes _dta: temporal: 2014-`target_year'
    notes _dta: spatial: Barbados
    notes _dta: unit_of_analysis: Event type by period
    notes _dta: description: Annual typical bed days, based on median length of stay in days.
    notes _dta: limitations: Based on hospital CVD events
    notes _dta: language: en
    notes _dta: software: StataNow 19
    notes _dta: rights: CC BY 4.0 Attribution
    notes _dta: source: `input_dataset_id'; complete calendar years 2010-`target_year'
    notes _dta: contact: Barbados National Registry
    save "`stagingdatasets'/`output2'.dta", replace 

    ** CSV DATASET EXPORT
    export delimited using "`stagingdatasets'/`output2'.csv", replace

    ** Dataset-level YAML metadata is created later by bnr_stage_briefing.do
    ** from the released DTA labels and notes.
** ============================================================================
** DO NOT TOUCH: CREATE THE AUTOMATIC DISCLOSURE-REVIEW WORKLIST
** ============================================================================
* This worklist prompts human review; it does not suppress values automatically.
* It flags positive underlying event counts below six in either released
* length-of-stay dataset. The reviewer must still inspect both full datasets,
* both figures and the workbook for complementary or contextual disclosure.

tempfile median_flags

preserve
    use "`stagingdatasets'/`output1'.dta", clear
    keep if nevent > 0 & nevent < 6

    gen str80 public_file = "`output1'.csv"
    decode etype, gen(event_type)
    decode sex, gen(sex_label)
    decode year2, gen(period_label)
    gen str80 output_section = "Median length of stay"
    gen str120 row_reference = event_type + ", " + sex_label + ", " + period_label
    gen str30 measure = "nevent"
    gen double value = nevent
    gen str100 reason = "Positive underlying event count below 6"
    gen str80 related_output = "`output1'.png"

    keep public_file output_section row_reference measure value reason related_output
    save `median_flags', replace
restore

preserve
    use "`stagingdatasets'/`output2'.dta", clear
    keep if nevent > 0 & nevent < 6

    gen str80 public_file = "`output2'.csv"
    decode etype, gen(event_type)
    gen str80 output_section = "Extra typical bed-days"
    gen str120 row_reference = event_type + ", " + string(yoe)
    gen str30 measure = "nevent"
    gen double value = nevent
    gen str100 reason = "Positive underlying event count below 6"
    gen str80 related_output = "`output2'.png"

    keep public_file output_section row_reference measure value reason related_output
    append using `median_flags'

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
* The analytics section above has created all briefing-specific public artefacts
* in the private staging folder.
*
* This final section writes the release contract and calls the shared staging
* helper. The helper creates dataset metadata, briefing metadata, README,
* workbook, downloads.yml and a fresh disclosure-review template.
*
* It does not approve the package, copy anything to outputs/public, create the
* publication ZIP, or refresh the website mirror. Those remain separate Steps
* 2 and 3 of the common briefing workflow.


** ============================================================================
** DO NOT TOUCH: WRITE RELEASE CONTROL FILE
** ============================================================================
* Purpose:
*   Create metadata/release_control.yml.
*
* This is the contract between the analyst-owned DO file and the invariant
* staging helper. Future analysts should edit the locals in EDIT BLOCK A, not
* the file-writing code below.
*
* Why a control file?
*   A called helper DO file should not depend on locals that happen to exist in
*   the calling DO file. Writing a small control file makes the handover between
*   the analysis layer and release layer explicit and auditable.

local analysis_script "scripts/stata/briefings/cvd_length_of_stay/cvd_length_of_stay.do"
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
** DO NOT TOUCH: COMPLETE THE PRIVATE STAGING PACKAGE
** ============================================================================
* This helper performs only routine private packaging. It does not approve or
* publish the briefing.

do "`localpath'/scripts/stata/common/bnr_stage_briefing.do" ///
    "`briefing_id'"

cap log close

/**************************************************************************
 DO-FILE:     bnrcvd-2023-tabulations.do
 PROJECT:     BNR Refit Consultancy
 PURPOSE:     Online report tabulations 2023, with comparisons across years
              as appropriate
 
 AUTHOR:      Ian R Hambleton
 DATE:        [2025-11-18]
 VERSION:     [v1.0]

 METADATA:    

 NOTES:       Tabulations created listed below:
              General stratifiers
                - by type (AMI, stroke)
                - by year
                - by sex 
                - by age groups
**************************************************************************/

** --------------------------------------------------------------
** Annual tabulations output contract
** --------------------------------------------------------------
local domain        "cvd"
local release_year  "2023"

local annual_root   "C:/yoshimi-hot/output/analyse-bnr/info-hub/site/downloads/annual/`domain'"
local archive_dir   "`annual_root'/`release_year'"
local latest_dir    "`annual_root'/latest"

local table_dir     "`archive_dir'/tables"
local workbook_dir  "`archive_dir'/workbook"
local metadata_dir  "`archive_dir'/metadata"

local workbook      "`workbook_dir'/workbook_`domain'_annual_tabulations.xlsx"
local metadata      "`metadata_dir'/metadata_`domain'_annual_tabulations.yml"

cap mkdir "`annual_root'"
cap mkdir "`archive_dir'"
cap mkdir "`table_dir'"
cap mkdir "`workbook_dir'"
cap mkdir "`metadata_dir'"

* ==============================================================
* DO NOT TOUCH: PREPARE SHARED 2023 CVD ANALYSIS DATA
* ==============================================================
* ----- PREPARE SHARED 2023 CVD ANALYSIS DATA ----
* This creates the private prepared datasets used by the 2023 briefings.
* ==============================================================
* DO NOT TOUCH:    SET LOCAL PATH LOCATION
*                  AND LOAD SHARED SETTINGS 
* ==============================================================
local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"
do "`localpath'/scripts/stata/common/bnrcvd_globals.do"
qui do "scripts/stata/common/bnrcvd_prep_2023_v1.do"

* Log File 
cap log close 
log using ${logs}\bnrcvd-2023-tabulations, replace 

** --------------------------------------------------------------
** (1) Load the interim dataset - COUNT
**     Dataset prepared in: bnrcvd-2023-prep1.do
** --------------------------------------------------------------
** use "${tempdata}\bnr-cvd-count-${today}-prep1.dta", clear 
use "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta", clear
gen event = 1 
local outputfile = "md xlsx" 
gen woe = week(doe) 
tempfile input 
save `input', replace 



** --------------------------------------------------------------
** NEW TABLE 1: Event count by:
**          - Event Type
**          - Year
**          - Sex
**
** Website output:
**   - Stata collect export to Markdown
**   - flat one-row header for Quarto compatibility
** --------------------------------------------------------------
preserve

    drop if yoe == 2009
    keep if inrange(yoe, 2010, 2023)
    keep if !missing(event)

    label var sex   "Patient Sex"
    label var etype "CVD Event Type"

    ** Create year ordering:
    ** 2023 first, 2010 last
    capture drop year
    gen byte year = 2024 - yoe if inrange(yoe, 2010, 2023)
    labmask year, values(yoe)
    label var year "Year"

    ** Safety checks for the assumed coding
    count if !inlist(etype, 1, 2)
    if r(N) > 0 {
        di as error "Table 1 error: unexpected etype values found."
        tab etype, missing
        error 459
    }

    count if !inlist(sex, 1, 2)
    if r(N) > 0 {
        di as error "Table 1 error: unexpected sex values found."
        tab sex, missing
        error 459
    }

    ** ----------------------------------------------------------
    ** Create one flat display column dimension.
    **
    ** copy 1 = event type by sex
    ** copy 2 = event type total
    ** copy 3 = all CVD by sex
    ** copy 4 = all CVD total
    ** ----------------------------------------------------------

    gen long _table1_id = _n
    expand 4
    bysort _table1_id: gen byte _table1_copy = _n

    gen byte event_col = .

    ** Event type by sex
    replace event_col = 1 if _table1_copy == 1 & etype == 1 & sex == 1
    replace event_col = 2 if _table1_copy == 1 & etype == 1 & sex == 2
    replace event_col = 4 if _table1_copy == 1 & etype == 2 & sex == 1
    replace event_col = 5 if _table1_copy == 1 & etype == 2 & sex == 2

    ** Event type totals
    replace event_col = 3 if _table1_copy == 2 & etype == 1
    replace event_col = 6 if _table1_copy == 2 & etype == 2

    ** All CVD by sex
    replace event_col = 7 if _table1_copy == 3 & sex == 1
    replace event_col = 8 if _table1_copy == 3 & sex == 2

    ** All CVD total
    replace event_col = 9 if _table1_copy == 4

    drop if missing(event_col)

    label define event_col_lab ///
        1 "Stroke<br>female" ///
        2 "Stroke<br>male" ///
        3 "Stroke<br>total" ///
        4 "AMI<br>female" ///
        5 "AMI<br>male" ///
        6 "AMI<br>total" ///
        7 "All CVD<br>female" ///
        8 "All CVD<br>male" ///
        9 "All CVD<br>total", replace

    label values event_col event_col_lab
    label var event_col ""

    ** ----------------------------------------------------------
    ** Create the Stata table collection.
    **
    ** Important:
    **   - totals(year) gives the final total row.
    **   - Do NOT use totals(event_col), because event_col is already
    **     built from expanded display copies.
    ** ----------------------------------------------------------

    collect clear

    table (year) (event_col), ///
        statistic(count event) ///
        totals(event_col)

    ** ----------------------------------------------------------
    ** Make the collection Markdown-friendly.
    ** ----------------------------------------------------------

    collect style header, title(hide) level(label)
    collect style header result, level(hide)

    ** Number formatting
    collect style cell, nformat(%12.0fc)

    ** Try centering through collect.
    ** This may or may not be reflected as :---: in Markdown export,
    ** depending on how Stata writes the md file.
    collect style cell, halign(center)
    collect style cell cell_type[column-header], halign(center)
    collect style cell cell_type[row-header], halign(center)

    ** Export to Markdown for Quarto include.
    collect export ///
        "`table_dir'/table_cvd_annual_01_event_counts.md", ///
        replace as(md)

    ** Workbook export retained in XLSX.
    ** XLSX can cope with the original Stata table structure.
    table (year) (etype sex), ///
        statistic(count event) ///
        export("`workbook'", replace as(xlsx) sheet("Table1", replace)) ///
        note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
        title(Table 1. Annual Event Count by Year)

restore




** --------------------------------------------------------------
** TABLE 2: Weekly event count by year
**          - Week of year
**          - Event type
**
** Website output:
**   - Quarto-readable Markdown
**   - One table per year
**
** Design:
**   - Flat columns: Stroke, AMI, All CVD
**   - No extra Stata total column
**   - 52 week rows retained using a simple skeleton
** --------------------------------------------------------------

label var woe "Week of year"

forval yr = 2010(1)2023 {

    preserve

        keep if yoe == `yr'
        keep if inrange(woe, 1, 52)
        keep if !missing(event)

        ** Create one flat display-column variable.
        ** copy 1 = event type
        ** copy 2 = all CVD total
        gen long _table2_id = _n
        expand 2
        bysort _table2_id: gen byte _table2_copy = _n

        gen byte event_col = .
        replace event_col = 1 if _table2_copy == 1 & etype == 1
        replace event_col = 2 if _table2_copy == 1 & etype == 2
        replace event_col = 3 if _table2_copy == 2

        keep woe event_col event

        tempfile table2_observed
        save `table2_observed', replace

        ** Add a skeleton so that all 52 weeks and all 3 columns appear,
        ** even where a week has zero observed events.
        clear
        set obs 52
        gen byte woe = _n

        expand 3
        bysort woe: gen byte event_col = _n

        gen byte event = .

        append using `table2_observed'

        label define event_col_lab ///
            1 "Stroke" ///
            2 "AMI" ///
            3 "All CVD", replace

        label values event_col event_col_lab
        label var event_col "Hello"
        label var woe "Week"

        collect clear

        table (woe) (event_col), ///
            statistic(count event) ///
            nototals

        ** Show the row-dimension title as the first column header
        collect style header woe, title(label) level(label)
        ** Hide the column-dimension title, but keep its level labels
        collect style header event_col, title(hide) level(label)
        ** Hide the result/statistic header because there is only one statistic
        collect style header result, level(hide)
        collect style cell, nformat(%12.0fc)
        collect style cell, halign(center)
        collect style cell cell_type[column-header], halign(center)
        collect style cell cell_type[row-header], halign(center)

        collect export ///
            "`table_dir'/table_cvd_annual_02_weekly_counts_`yr'.md", ///
            replace as(md)

    restore

    ** Workbook export retained in XLSX.
    ** XLSX can cope with the original Stata table structure.
    table (woe) (etype) if yoe == `yr', ///
        statistic(count event) ///
        export("`workbook'", modify as(xlsx) sheet("Table2_`yr'", replace)) ///
        note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
        title(Table 2. Weekly Event Count for `yr')
}


** --------------------------------------------------------------
** TABLE 3: Proportion of strokes / AMIs by age
**          - Younger adults: <70 years
**          - Older adults: 70+ years
**          - Event type
**          - Time period
**          - Sex
**
** Website output:
**   - Quarto-readable Markdown
**
** Design:
**   - Flat row dimension: time period + age group
**   - Flat column dimension: event type + sex
** --------------------------------------------------------------

preserve

    tempvar latestyr

    egen `latestyr' = max(yoe)

    gen byte time5 = .
    replace time5 = 2 if yoe == `latestyr'
    replace time5 = 3 if yoe != `latestyr' & `latestyr' - yoe < 6

    keep if inlist(time5, 2, 3)

    collapse (sum) event, by(time5 etype sex age70)

    ** Ensure zero cells are retained where possible.
    fillin time5 etype sex age70
    replace event = 0 if missing(event)
    drop _fillin

    bysort etype sex time5: egen denom = sum(event)

    ** The division by 5 is not required for the percentage itself,
    ** because both numerator and denominator are divided by the same value.
    ** It is kept conceptually explicit for the five-year average period.
    replace event = event / 5 if time5 == 3
    replace denom = denom / 5 if time5 == 3

    gen perc = (event / denom) * 100 if denom > 0

    label define time5_ ///
        2 "(2023)<br>" ///
        3 "(2018-2022)<br>", replace

    label values time5 time5_
    label var time5 "Time period"

    ** Flatten row and column structures for Markdown.
    egen row_age70 = group(time5 age70), label
    label var row_age70 "Time period and age group"

    egen event_sex = group(etype sex), label
    label var event_sex ""

    collect clear

    table (row_age70) (event_sex), ///
        statistic(mean perc) ///
        nototals

    collect style header, title(hide) level(label)
    collect style header result, level(hide)
    collect style cell, nformat(%5.1f)
    collect style cell, halign(center)
    collect style cell cell_type[column-header], halign(center)
    collect style cell cell_type[row-header], halign(center)

    collect export ///
        "`table_dir'/table_cvd_annual_03_age70_percent.md", ///
        replace as(md)

    ** Workbook export retained in XLSX.
    ** XLSX can cope with the original Stata table structure.
    table (time5 age70) (etype sex), ///
        statistic(mean perc) ///
        nototals ///
        nformat(%5.1f) ///
        export("`workbook'", modify as(xlsx) sheet("Table3", replace)) ///
        note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
        title(Table 3. Event Percentage among Younger Adults (<70 years) and Older Adults (70+ years))

restore


** --------------------------------------------------------------
** TABLE 4: Proportion of strokes / AMIs by age
**          - 10-year age bands
**          - Event type
**          - Time period
**          - Sex
**
** Website output:
**   - Quarto-readable Markdown
**
** Design:
**   - Flat row dimension: time period + 10-year age group
**   - Flat column dimension: event type + sex
** --------------------------------------------------------------

preserve

    tempfile interim1 both1 strat1

    use `input', clear

    tempvar latestyr

    egen `latestyr' = max(yoe)

    gen byte time5 = .
    replace time5 = 2 if yoe != `latestyr' & `latestyr' - yoe < 6
    replace time5 = 3 if yoe == `latestyr'

    gen byte age10 = age5

    recode age10 ///
        (1 2 3 4 5 6 7 8 = 1) ///
        (9 10 = 2) ///
        (11 12 = 3) ///
        (13 14 = 4) ///
        (15 16 = 5) ///
        (17 18 = 6)

    label define age10_ ///
        1 "<40" ///
        2 "40-49" ///
        3 "50-59" ///
        4 "60-69" ///
        5 "70-79" ///
        6 "80+", replace

    label values age10 age10_

    save `interim1', replace

    ** All-sex totals
    collapse (sum) event, by(time5 etype age10)
    gen byte sex = 3
    save `both1', replace

    ** Sex-specific totals
    use `interim1', clear
    collapse (sum) event, by(time5 etype sex age10)
    save `strat1', replace

    append using `both1'

    keep if inlist(time5, 2, 3)

    label define sex_ 3 "All", modify
    label values sex sex_

    ** Ensure zero cells are retained where possible.
    fillin time5 etype sex age10
    replace event = 0 if missing(event)
    drop _fillin

    bysort etype sex time5: egen denom = sum(event)

    ** The division by 5 is not required for the percentage itself,
    ** because both numerator and denominator are divided by the same value.
    ** It is kept conceptually explicit for the five-year average period.
    replace event = event / 5 if time5 == 2
    replace denom = denom / 5 if time5 == 2

    gen perc = (event / denom) * 100 if denom > 0

    label define time5_ ///
        2 "(2018-2022)<br>" ///
        3 "(2023)<br>", replace

    label values time5 time5_
    label var time5 "Time period"

    label var etype "CVD Event Type"
    label var sex   "Patient Sex"

    ** Flatten row and column structures for Markdown.
    egen row_age10 = group(time5 age10), label
    label var row_age10 "Time period and age group"

    egen event_sex = group(etype sex), label
    label var event_sex ""

    collect clear

    table (row_age10) (event_sex), ///
        statistic(mean perc) ///
        nototals

    collect style header, title(hide) level(label)
    collect style header result, level(hide)
    collect style cell, nformat(%5.1f)
    collect style cell, halign(center)
    collect style cell cell_type[column-header], halign(center)
    collect style cell cell_type[row-header], halign(center)

    collect export ///
        "`table_dir'/table_cvd_annual_04_age10_percent.md", ///
        replace as(md)

    ** Workbook export retained in XLSX.
    ** XLSX can cope with the original Stata table structure.
    table (time5 age10) (etype sex), ///
        statistic(mean perc) ///
        nototals ///
        nformat(%5.1f) ///
        export("`workbook'", modify as(xlsx) sheet("Table4", replace)) ///
        note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
        title(Table 4. Event Percentage by 10-Year Age Groups)

restore



** --------------------------------------------------------------
** TABLE 5: Incidence rates for hospital events
**          - With and without DCOs
**          - Event type
**          - Year
**          - Sex
**
** Website output:
**   - Quarto-readable Markdown
**
** Design:
**   - One table per year
**   - Flat row dimension: DCO status + rate measure
**   - Flat column dimension: event type + sex
** --------------------------------------------------------------

use "${data}/bnrcvd-incidence.dta", clear

rename year yoe

capture drop year
gen byte year = 2024 - yoe if inrange(yoe, 2010, 2023)
labmask year, values(yoe)

label var year   "Year"
label var sex    "Patient sex"
label var dco    "Does event rate include DCOs?"
label var lb_gam "Lower 95% limit"
label var ub_gam "Upper 95% limit"

label define dco_ ///
    0 "Without DCO" ///
    1 "DCO added", modify

label values dco dco_

forval yr = 2010(1)2023 {

    preserve

        keep if yoe == `yr'

        ** ------------------------------------------------------
        ** Workbook export
        **
        ** XLSX can retain the original richer Stata table layout.
        ** ------------------------------------------------------

        table (year dco) (etype sex), ///
            statistic(mean crude) ///
            statistic(mean rateadj) ///
            statistic(mean lb_gam) ///
            statistic(mean ub_gam) ///
            nototals ///
            nformat(%5.1f) ///
            export("`workbook'", modify as(xlsx) sheet("Table5_`yr'", replace)) ///
            note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
            note(Adjusted rate confidence limits (95%) - Tiwari, Clegg and Zhou bounds) ///
            note(Adjusted rates use the WHO (2000) World Standard Population) ///
            note(DCO = Death Certificate Only events) ///
            title(Table 5. CVD Incidence Rates for `yr')

        ** ------------------------------------------------------
        ** Markdown export
        **
        ** Flatten the multiple statistics into rows:
        **   Without DCO: crude rate
        **   Without DCO: age-adjusted rate
        **   Without DCO: lower 95% limit
        **   Without DCO: upper 95% limit
        **   DCO added: crude rate
        **   etc.
        ** ------------------------------------------------------

        keep year yoe dco etype sex crude rateadj lb_gam ub_gam

        gen long _table5_id = _n
        expand 4
        bysort _table5_id: gen byte rate_measure = _n

        gen double rate_value = .
        replace rate_value = crude   if rate_measure == 1
        replace rate_value = rateadj if rate_measure == 2
        replace rate_value = lb_gam  if rate_measure == 3
        replace rate_value = ub_gam  if rate_measure == 4

        gen byte dco_measure = .
        replace dco_measure = 1 if dco == 0 & rate_measure == 1
        replace dco_measure = 2 if dco == 0 & rate_measure == 2
        replace dco_measure = 3 if dco == 0 & rate_measure == 3
        replace dco_measure = 4 if dco == 0 & rate_measure == 4
        replace dco_measure = 5 if dco == 1 & rate_measure == 1
        replace dco_measure = 6 if dco == 1 & rate_measure == 2
        replace dco_measure = 7 if dco == 1 & rate_measure == 3
        replace dco_measure = 8 if dco == 1 & rate_measure == 4

        label define dco_measure_lab ///
            1 "Without DCO<br>crude rate" ///
            2 "Without DCO<br>age-adjusted rate" ///
            3 "Without DCO<br>lower 95% limit" ///
            4 "Without DCO<br>upper 95% limit" ///
            5 "DCO added<br>crude rate" ///
            6 "DCO added<br>age-adjusted rate" ///
            7 "DCO added<br>lower 95% limit" ///
            8 "DCO added<br>upper 95% limit", replace

        label values dco_measure dco_measure_lab
        label var dco_measure ""

        ** Flat column dimension for Markdown.
        ** This uses existing event type and sex value labels.
        egen event_sex = group(etype sex), label
        label var event_sex ""

        keep if !missing(dco_measure)
        keep if !missing(event_sex)
        keep if !missing(rate_value)

        collect clear

        table (dco_measure) (event_sex), ///
            statistic(mean rate_value) ///
            nototals

        collect style header, title(hide) level(label)
        collect style header result, level(hide)

        collect style cell, nformat(%5.1f)
        collect style cell, halign(center)
        collect style cell cell_type[column-header], halign(center)
        collect style cell cell_type[row-header], halign(center)

        collect export ///
            "`table_dir'/table_cvd_annual_05_incidence_rates_`yr'.md", ///
            replace as(md)

    restore
}



** --------------------------------------------------------------
** TABLE 6: Incidence rate ratios for hospital events
**          - 2-year time-period comparisons
**
** Website output:
**   - Quarto-readable Markdown
**
** Workbook output:
**   - XLSX sheet with title and notes
** --------------------------------------------------------------

use "${tempdata}/bnrcvd-incidence-rate-ratios.dta", clear

rename srr    srr1
rename lb_srr srr2
rename ub_srr srr3

reshape long srr, i(yaxis) j(type)

label var yaxis "Incidence rate comparison"
label var srr   "Incidence rate ratio"
label var type  "Incidence rate ratio"

label define type_ ///
    1 "IRR" ///
    2 "Lower 95% limit" ///
    3 "Upper 95% limit", replace

label values type type_

** --------------------------------------------------------------
** Markdown export
**
** The table already has a Quarto-friendly structure:
**   row dimension    = comparison
**   column dimension = IRR measure
** --------------------------------------------------------------

collect clear

table (yaxis) (type), ///
    statistic(mean srr) ///
    nototals ///
    nformat(%5.2f)

collect style header, title(hide) level(label)
collect style header result, level(hide)

collect style cell, nformat(%5.2f)
collect style cell, halign(center)
collect style cell cell_type[column-header], halign(center)
collect style cell cell_type[row-header], halign(center)

collect export ///
    "`table_dir'/table_cvd_annual_06_incidence_rate_ratios.md", ///
    replace as(md)


** --------------------------------------------------------------
** Workbook export
**
** XLSX keeps the formal title and notes.
** --------------------------------------------------------------

table (yaxis) (type), ///
    statistic(mean srr) ///
    nototals ///
    nformat(%5.2f) ///
    export("`workbook'", modify as(xlsx) sheet("Table6", replace)) ///
    note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
    note(${dagger} IRR = Incidence Rate Ratio with 95% Confidence Limits) ///
    note(${ddagger} Each 2-year time period compared to 2010-2011) ///
    title(Table 6. CVD Incidence Rate Ratios, 2010 to 2023, for Hospital Events)




** --------------------------------------------------------------
** TABLE 7: Case fatality among hospital events
**          - Event type
**          - 2-year time period
**          - Sex
**
** Website output:
**   - Quarto-readable Markdown
**
** Workbook output:
**   - XLSX sheet with original richer Stata table structure
** --------------------------------------------------------------

use "${tempdata}/bnrcvd-case-fatality.dta", clear

recode year2 ///
    (7 = 1) ///
    (6 = 2) ///
    (5 = 3) ///
    (4 = 4) ///
    (3 = 5) ///
    (2 = 6) ///
    (1 = 7)

label define year2_ ///
    1 "2022-2023" ///
    2 "2020-2021" ///
    3 "2018-2019" ///
    4 "2016-2017" ///
    5 "2014-2015" ///
    6 "2012-2013" ///
    7 "2010-2011", modify

label values year2 year2_

label var year2 "Time period"
label var ccase "Case fatality percentage"

** --------------------------------------------------------------
** Markdown export
**
** Flatten the nested etype sex column structure for Markdown.
** --------------------------------------------------------------

preserve

    egen event_sex = group(etype sex), label
    label var event_sex ""

    collect clear

    table (year2) (event_sex), ///
        statistic(mean ccase) ///
        nototals ///
        nformat(%5.1f)

    collect style header, title(hide) level(label)
    collect style header result, level(hide)

    collect style cell, nformat(%5.1f)
    collect style cell, halign(center)
    collect style cell cell_type[column-header], halign(center)
    collect style cell cell_type[row-header], halign(center)

    collect export ///
        "`table_dir'/table_cvd_annual_07_case_fatality.md", ///
        replace as(md)

restore


** --------------------------------------------------------------
** Workbook export
**
** XLSX can retain the original nested Stata table structure.
** --------------------------------------------------------------

table (year2) (etype sex), ///
    statistic(mean ccase) ///
    nformat(%5.1f) ///
    export("`workbook'", modify as(xlsx) sheet("Table7", replace)) ///
    note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry) ///
    title(Table 7. CVD In-Hospital Fatality Percentage, 2010 to 2023)




/*


** --------------------------------------------------------------
** TABLE 8: Median Length of Stay
**          - Event Type
**          - Event Type & Year
**          - Broad age groups (<70 yrs, 70 yrs and older)
** --------------------------------------------------------------
use "${tempdata}/bnrcvd-length-of-stay.dta", clear 
keep if cf==1 
        #delimit ; 
        gen year = 1 if yoe == 2023;  replace year = 2 if yoe == 2022;  replace year = 3 if yoe == 2021;
        replace year = 4 if yoe == 2020;  replace year = 5 if yoe == 2019;  replace year = 6 if yoe == 2018;
        replace year = 7 if yoe == 2017;  replace year = 8 if yoe == 2016;  replace year = 9 if yoe == 2015;
        replace year = 10 if yoe == 2014; replace year = 11 if yoe == 2013; replace year = 12 if yoe == 2012;
        replace year = 13 if yoe == 2011; replace year = 14 if yoe == 2010;
        #delimit cr 
        labmask year, values(yoe)
        label var year "CVD Event Year"
        label var sex "Patient sex" 
        label var etype "CVD Event Type"

        #delimit ; 
        table (year) (etype sex) , 
                statistic(median los_primary)  
                statistic(p25 los_primary)  
                statistic(p75 los_primary)  
                nformat(%5.0f)
                export("`table_dir'/table_cvd_annual_08_length_of_stay.md", replace as(md))
                note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry)            
                title(Table 8. CVD Typical (Median) In-Hospital Length of Stay (2010 to 2023))
                ;
        table (year) (etype sex) , 
                statistic(median los_primary)  
                statistic(p25 los_primary)  
                statistic(p75 los_primary)  
                nformat(%5.0f)
                export("`workbook'", modify as(xlsx) sheet("Table8", replace))
                note(Prepared by Ian Hambleton on ${todayiso}, for the Barbados National Registry)            
                title(Table 8. CVD Typical (Median) In-Hospital Length of Stay (2010 to 2023))
                ;
        #delimit cr 

*/
** --------------------------------------------------------------
** Write annual tabulations metadata
** --------------------------------------------------------------

file open meta using "`metadata'", write replace text

file write meta "product_id: cvd_annual_tabulations" _n
file write meta "product_type: annual_tabulation" _n
file write meta "domain: cvd" _n
file write meta "release_year: `release_year'" _n
file write meta `"generated_on: "${todayiso}""' _n
file write meta `"stata_job: "build_cvd_annual_tabulations.do""' _n
file write meta `"workbook: "workbook/workbook_cvd_annual_tabulations.xlsx""' _n
file write meta "tables:" _n
file write meta `"  - id: table_01"' _n
file write meta `"    title: "Annual event count by year""' _n
file write meta `"    file: "tables/table_cvd_annual_01_event_counts.md""' _n
file write meta `"  - id: table_02"' _n
file write meta `"    title: "Weekly event count by year""' _n
file write meta `"    files: "tables/table_cvd_annual_02_weekly_counts_[year].md""' _n
file write meta `"  - id: table_03"' _n
file write meta `"    title: "Event percentage among younger and older adults""' _n
file write meta `"    file: "tables/table_cvd_annual_03_age70_percent.md""' _n
file write meta `"  - id: table_04"' _n
file write meta `"    title: "Event percentage by 10-year age group""' _n
file write meta `"    file: "tables/table_cvd_annual_04_age10_percent.md""' _n
file write meta `"  - id: table_05"' _n
file write meta `"    title: "CVD incidence rates by year""' _n
file write meta `"    files: "tables/table_cvd_annual_05_incidence_rates_[year].md""' _n
file write meta `"  - id: table_06"' _n
file write meta `"    title: "CVD incidence rate ratios""' _n
file write meta `"    file: "tables/table_cvd_annual_06_incidence_rate_ratios.md""' _n
file write meta `"  - id: table_07"' _n
file write meta `"    title: "CVD in-hospital fatality percentage""' _n
file write meta `"    file: "tables/table_cvd_annual_07_case_fatality.md""' _n
file write meta `"  - id: table_08"' _n
file write meta `"    title: "Median in-hospital length of stay""' _n
file write meta `"    file: "tables/table_cvd_annual_08_length_of_stay.md""' _n
file write meta "notes:" _n
file write meta `"  public_note: "Annual tabulations generated from approved BNR cardiovascular disease surveillance outputs.""' _n

file close meta


** --------------------------------------------------------------
** Refresh latest annual tabulations folder
** --------------------------------------------------------------

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "if (Test-Path '`latest_dir'') { Remove-Item '`latest_dir'' -Recurse -Force }; Copy-Item '`archive_dir'' '`latest_dir'' -Recurse -Force"


/**************************************************************************
 DO-FILE:     cvd_cases_2023.do
 PROJECT:     BNR info-hub
 PURPOSE:     Recreate the static 2023 CVD case-count briefing outputs

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.0

 NOTES:
   This DO file creates the approved output bundle for the static
   2023 CVD case-count briefing.

   It does not create the final PDF briefing.
   Publication layout is handled by Quarto.

 OUTPUT BUNDLE:
   outputs/public/briefings/cvd_cases_2023_v1/

   tables/
     cases_2023_sex_event.csv
     age70_2023_sex_event.csv

   figures/
     cases_2023_cum_week.png
     cases_2023_age70.png

   data/
     cases_2023_cum_week.csv
     cases_2023_age70.csv

   meta.yml
   build.yml
**************************************************************************/


** ------------------------------------------------
** ----- INITIALIZE DO FILE -----------------------
** ------------------------------------------------

version 19
clear all
set more off

* Load local paths and shared settings
do "scripts/stata/config/bnr_paths_LOCAL.do"
do "scripts/stata/common/bnrcvd_globals.do"

* Fixed static briefing parameters
local target_year     2023
local baseline_start  2018
local baseline_end    2022
local briefing_id     "cvd_cases_2023_v1"

* Output bundle locations
local bundle "$BNR_PUBLIC/briefings/`briefing_id'"
local tables "`bundle'/tables"
local figures "`bundle'/figures"
local dataout "`bundle'/data"

* Private log file
cap log close
log using "$BNR_PRIVATE_LOGS/cvd_cases_2023", replace

display as text "BNR CVD case-count briefing build"
display as result "  Briefing ID:   `briefing_id'"
display as result "  Target year:   `target_year'"
display as result "  Baseline:      `baseline_start'-`baseline_end'"
display as result "  Output bundle: `bundle'"


** ------------------------------------------------
** ----- PREPARE SHARED 2023 CVD ANALYSIS DATA ----
** ------------------------------------------------

* This creates the private prepared datasets used by the 2023 briefings.
do "scripts/stata/common/bnrcvd_prep_2023_v1.do"


** --------------------------------------------------------------
** (1) LOAD PREPARED COUNT DATASET
** --------------------------------------------------------------

use "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta", clear

* Broad restrictions
drop if dco == 1
drop dco
drop if yoe == 2009

* Keep only the years required for this static briefing
keep if inrange(yoe, `baseline_start', `target_year')

* Safety checks for the static briefing
count if yoe == `target_year'
if r(N) == 0 {
    display as error "No observations found for target year `target_year'."
    exit 2000
}

count if inrange(yoe, `baseline_start', `baseline_end')
if r(N) == 0 {
    display as error "No observations found for baseline period `baseline_start'-`baseline_end'."
    exit 2000
}

gen event = 1


** --------------------------------------------------------------
** (2) PUBLIC TABLE: 2023 CASES BY SEX AND EVENT TYPE
** --------------------------------------------------------------

preserve

    keep if yoe == `target_year'

    collapse (sum) cases = event, by(etype sex)

    label var etype "Event type"
    label var sex   "Sex"
    label var cases "Number of hospital-registered CVD cases"

    export delimited using "`tables'/cases_2023_sex_event.csv", replace

restore


** --------------------------------------------------------------
** (3) PUBLIC TABLE: 2023 CASES BY AGE70, SEX, AND EVENT TYPE
** --------------------------------------------------------------

preserve

    keep if yoe == `target_year'

    collapse (sum) cases = event, by(etype sex age70)

    bysort etype sex: egen total_cases = total(cases)
    gen percent = 100 * cases / total_cases

    label var etype       "Event type"
    label var sex         "Sex"
    label var age70       "Age group"
    label var cases       "Number of hospital-registered CVD cases"
    label var total_cases "Total cases in event type and sex group"
    label var percent     "Percentage of cases in age group"

    export delimited using "`tables'/age70_2023_sex_event.csv", replace

restore


** --------------------------------------------------------------
** (4) FIGURE 1: CUMULATIVE WEEKLY COUNT, 2023 VS BASELINE
** --------------------------------------------------------------

preserve

    gen woe = week(doe)

    collapse (sum) event, by(yoe woe etype)

    sort etype yoe woe
    bysort etype yoe: gen cevent = sum(event)

    gen period = .
    replace period = 2 if inrange(yoe, `baseline_start', `baseline_end')
    replace period = 3 if yoe == `target_year'
    keep if inlist(period, 2, 3)

    collapse (sum) event, by(period woe etype)

    sort period etype woe
    bysort period etype: gen cevent = sum(event)

    replace event  = event  / 5 if period == 2
    replace cevent = cevent / 5 if period == 2

    reshape wide event cevent, i(etype woe) j(period)

    gen cases_diff_cum = cevent3 - cevent2

    label var etype          "Event type"
    label var woe            "Week of year"
    label var event2         "Baseline average weekly cases, 2018-2022"
    label var cevent2        "Baseline average cumulative cases, 2018-2022"
    label var event3         "Weekly cases, 2023"
    label var cevent3        "Cumulative cases, 2023"
    label var cases_diff_cum "2023 cumulative cases minus baseline average"

    export delimited using "`dataout'/cases_2023_cum_week.csv", replace

    #delimit ;
        graph twoway
            (function y=0, range(1 52) lc(gs8%50) lp("_") lw(0.75))
            (line cases_diff_cum woe if etype==1, lw(1) color("${str_m}"))
            (line cases_diff_cum woe if etype==2, lw(1) color("${ami_m}"))
            ,
                plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))
                graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))
                ysize(4) xsize(16)

                xlab(none,
                valuelabel labc(gs0) labs(2.5) notick nogrid glc(gs16) angle(45) format(%9.0f))
                xscale(noline lw(vthin))
                xtitle(" ", size(3) color(gs0) margin(l=1 r=1 t=1 b=1))

                ylab(,
                labc(gs0) labs(7) tlc(gs8) nogrid glc(gs16) angle(0) format(%9.0f))
                yscale(lw(vthin) lc(gs8) noextend range(-40(10)70))
                ytitle(" ", color(gs8) size(4.5) margin(l=1 r=1 t=1 b=1))

                text(6.5 52 "5-year average", place(w) size(8) color(gs4))
                text(-40 26 "Cumulative CVD cases in 2023 compared to 5-year average (2018-2022)", place(c) size(8) color(gs4))

                legend(off)
                name(cases_2023_cum_week, replace)
                ;
    #delimit cr

    graph export "`figures'/cases_2023_cum_week.png", replace width(3000)

restore


** --------------------------------------------------------------
** (5) FIGURE 2: AGE70 DISTRIBUTION, 2023 VS BASELINE
** --------------------------------------------------------------

preserve

    gen period = .
    replace period = 2 if inrange(yoe, `baseline_start', `baseline_end')
    replace period = 3 if yoe == `target_year'
    keep if inlist(period, 2, 3)

    collapse (sum) event, by(period etype sex age70)

    sort etype sex period age70

    bysort etype sex period: egen denom = total(event)

    replace event = event / 5 if period == 2
    replace denom = denom / 5 if period == 2

    gen perc = (event / denom) * 100

    * Keep the under-70 proportion for plotting.
    * The graph displays this against the complementary 70+ proportion.
    keep if age70 == 0

    gen zero = 0
    gen p100 = 100

    * Visual offset for AMI panels
    replace perc = perc + 110 if etype == 2
    replace zero = zero + 110 if etype == 2
    replace p100 = p100 + 110 if etype == 2

    * Legend location
    local legend_square1 2 225    1.5 225    1.5 230     2 230    2 225
    local legend_square2 2 231    1.5 231    1.5 236     2 236    2 231
    local legend_circle1 1 227.5
    local legend_circle2 1 233.5

    #delimit ;
        graph twoway
            (rbar p100 perc sex if period==2 & etype==1 & sex==1, horizontal barwidth(.5) lc("${str_m70}") lw(0.05) fc("${str_m70}"))
            (rbar zero perc sex if period==2 & etype==1 & sex==1, horizontal barwidth(.5) lc("${str_m}") lw(0.05) fc("${str_m}"))

            (rbar p100 perc sex if period==2 & etype==1 & sex==2, horizontal barwidth(.5) lc("${str_m70}") lw(0.05) fc("${str_m70}"))
            (rbar zero perc sex if period==2 & etype==1 & sex==2, horizontal barwidth(.5) lc("${str_m}") lw(0.05) fc("${str_m}"))

            (scatter sex perc if period==3 & etype==1 & sex==1, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${str_m70}"))
            (scatter sex perc if period==3 & etype==1 & sex==2, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${str_m70}"))

            (rbar p100 perc sex if period==2 & etype==2 & sex==1, horizontal barwidth(.5) lc("${ami_m70}") lw(0.05) fc("${ami_m70}"))
            (rbar zero perc sex if period==2 & etype==2 & sex==1, horizontal barwidth(.5) lc("${ami_m}") lw(0.05) fc("${ami_m}"))

            (rbar p100 perc sex if period==2 & etype==2 & sex==2, horizontal barwidth(.5) lc("${ami_m70}") lw(0.05) fc("${ami_m70}"))
            (rbar zero perc sex if period==2 & etype==2 & sex==2, horizontal barwidth(.5) lc("${ami_m}") lw(0.05) fc("${ami_m}"))

            (scatter sex perc if period==3 & etype==2 & sex==1, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${ami_m70}"))
            (scatter sex perc if period==3 & etype==2 & sex==2, msymbol(O) msize(7) mlw(0.4) mlcolor("gs16") mfcolor("${ami_m70}"))

            (function y=2.75, range(220 220) dropline(220) lc(gs4) lw(0.4))
            (scatteri `legend_square1', recast(area) lw(none) fc("${str_m70}"))
            (scatteri `legend_square2', recast(area) lw(none) fc("${ami_m70}"))
            (scatteri `legend_circle1', msize(7) lw(none) mc("${str_m70}"))
            (scatteri `legend_circle2', msize(7) lw(none) mc("${ami_m70}"))

            ,
            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin))
            graphregion(c(gs16) ic(gs16) ilw(thin) lw(thin))
            ysize(4) xsize(20)

            xlabel(none, labsize(10) notick nogrid labcolor(gs4))
            xscale(noline noextend range(0(10)275))
            xtitle(" ", margin(top) color(gs0) size(2.5))

            ylabel(
                    2 "Men"
                    1 "Women"
            , notick nogrid valuelabel angle(0) labsize(10) labcolor(gs4))
            ytitle(" ", axis(1))
            yscale(noline range(0(0.25)2.75))

            text(1.75 240 "2018-2022", place(e) size(10) color(gs4))
            text(1 240 "2023", place(e) size(10) color(gs4))
            text(-0.2 105 "Proportion 70 years and older with a hospitalised heart attack or stroke", place(c) size(10) color(gs4))
            text(2.75 5 "<70 yrs", place(e) size(10) color(${str_m}) margin(0 0 0 0))
            text(2.75 95 "70+ yrs", place(w) size(10) color(${str_m70}) margin(0 0 0 0))
            text(2.75 115 "<70 yrs", place(e) size(10) color(${ami_m}) margin(0 0 0 0))
            text(2.75 205 "70+ yrs", place(w) size(10) color(${ami_m70}) margin(0 0 0 0))

            text(0.45 50 "50", place(c) size(10) color(gs4) margin(0 0 0 0))
            text(0.45 100 "100", place(c) size(10) color(gs4) margin(0 0 0 0))
            text(0.45 160 "50", place(c) size(10) color(gs4) margin(0 0 0 0))
            text(0.45 210 "100", place(c) size(10) color(gs4) margin(0 0 0 0))

            legend(off)
            name(cases_2023_age70, replace)
            ;
    #delimit cr

    graph export "`figures'/cases_2023_age70.png", replace width(3000)

    * Remove graph-only offset before exporting figure-ready data
    replace perc = perc - 110 if etype == 2
    drop zero p100

    label define period_ 2 "5-year baseline, 2018-2022" 3 "2023", replace
    label values period period_

    label var period "Time period"
    label var etype  "Event type"
    label var sex    "Sex"
    label var age70  "Age group"
    label var event  "Event count. For baseline, annual average."
    label var denom  "Total event count. For baseline, annual average."
    label var perc   "Percentage under 70 years"

    export delimited using "`dataout'/cases_2023_age70.csv", replace

restore


** --------------------------------------------------------------
** (6) PUBLIC RELEASE METADATA
** --------------------------------------------------------------

file open meta using "`bundle'/meta.yml", write replace text

file write meta "briefing_id: cvd_cases_2023_v1" _n
file write meta "title: Hospital Cardiovascular Cases in Barbados, 2023" _n
file write meta "product_type: static_briefing_output_bundle" _n
file write meta "registry: BNR-CVD" _n
file write meta "geography: Barbados" _n
file write meta "time_period: 2018-2023" _n
file write meta "target_year: 2023" _n
file write meta "baseline_period: 2018-2022" _n
file write meta "unit_of_analysis: hospital-registered cardiovascular event" _n
file write meta "included_events: stroke and acute myocardial infarction" _n
file write meta "source_summary: hospital admissions recorded by the Barbados National Registry" _n
file write meta "description: public aggregate outputs for the 2023 CVD case-count briefing" _n
file write meta "disclosure_status: aggregate public output" _n
file write meta "license: CC BY 4.0" _n
file write meta "contact: Barbados National Registry" _n
file write meta "outputs:" _n
file write meta "  tables:" _n
file write meta "    - tables/cases_2023_sex_event.csv" _n
file write meta "    - tables/age70_2023_sex_event.csv" _n
file write meta "  figures:" _n
file write meta "    - figures/cases_2023_cum_week.png" _n
file write meta "    - figures/cases_2023_age70.png" _n
file write meta "  data:" _n
file write meta "    - data/cases_2023_cum_week.csv" _n
file write meta "    - data/cases_2023_age70.csv" _n

file close meta


** --------------------------------------------------------------
** (7) BUILD RECORD
** --------------------------------------------------------------

file open build using "`bundle'/build.yml", write replace text

file write build "briefing_id: cvd_cases_2023_v1" _n
file write build "build_date: ${todayiso}" _n
file write build "stata_version: ${stata_v}" _n
file write build "analyst: ${analyst}" _n
file write build "analysis_script: scripts/stata/briefings/cvd_cases_2023/cvd_cases_2023.do" _n
file write build "prep_script: scripts/stata/common/bnrcvd_prep_2023_v1.do" _n
file write build "source_data_freeze: releases/y2023/m12/bnr-cvd-indiv-full-202312-v01.dta" _n
file write build "prepared_private_dataset: info-hub-private/work/bnrcvd_count_2023_v1.dta" _n
file write build "public_output_bundle: outputs/public/briefings/cvd_cases_2023_v1" _n
file write build "publication_status: draft_pending_review" _n

file close build


** --------------------------------------------------------------
** (8) FINAL CHECK
** --------------------------------------------------------------

display as text "Created public output bundle:"
display as result "`bundle'"

display as text "Expected public files:"
display as result "`tables'/cases_2023_sex_event.csv"
display as result "`tables'/age70_2023_sex_event.csv"
display as result "`figures'/cases_2023_cum_week.png"
display as result "`figures'/cases_2023_age70.png"
display as result "`dataout'/cases_2023_cum_week.csv"
display as result "`dataout'/cases_2023_age70.csv"
display as result "`bundle'/meta.yml"
display as result "`bundle'/build.yml"

cap log close

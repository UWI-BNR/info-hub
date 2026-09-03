/*******************************************************************************
DO-FILE: bnr_report_annual_standard.do
VERSION: 1.0.1 (3 September 2026)
PURPOSE: Reusable putpdf composition for the standard annual CVD surveillance
         section.

CALLER:
  bnr_report_annual_s1_build.do only.

SOURCE BOUNDARY:
  This file reads only the two declared approved public release CSVs selected
  and checksum-validated by Step 1. It never reads confidential source data and
  it does not recalculate published surveillance measures.

DESIGN CONTRACT:
  - A4 portrait, Arial, generous white space and restrained BNR colours.
  - Figures use minimal axes and no decorative grid where it is not needed.
  - Tables present the already-published values, confidence limits and linkage
    bounds. Suppressed values remain protected and are never reconstructed.
  - The visual palette is also available to the year-specific Special chapter.
*******************************************************************************/

* -----------------------------------------------------------------------------
* 1. Shared visual contract
* -----------------------------------------------------------------------------

local bnr_ink         "44 62 80"
local bnr_teal        "4 81 116"
local bnr_primary     "111 90 168"
local bnr_primary_fill "225 220 238"
local bnr_inclusive   "176 100 115"
local bnr_inclusive_fill "239 222 226"
local bnr_heart       "212 106 106"
local bnr_stroke      "110 143 179"
local bnr_women       "192 122 142"
local bnr_men         "94 135 145"
local bnr_under70     "216 156 96"
local bnr_older70     "122 135 148"
local bnr_pale        "248 249 250"
local bnr_rule        "222 226 230"
local bnr_muted       "102 102 102"

local annual_figure_dir "`candidate_dir'/figures"
capture mkdir "`annual_figure_dir'"

* Analyst-owned locals are intentionally simple. If one is absent, retain a
* visible editorial prompt rather than silently inventing interpretation.
if "`annual_summary_message_1'" == "" local annual_summary_message_1 ///
    "[Analyst: add first annual summary message.]"
if "`annual_summary_message_2'" == "" local annual_summary_message_2 ///
    "[Analyst: add second annual summary message.]"
if "`annual_summary_message_3'" == "" local annual_summary_message_3 ///
    "[Analyst: add third annual summary message.]"
if "`annual_events_interpretation'" == "" local annual_events_interpretation ///
    "[Analyst: add annual CVD-event interpretation.]"
if "`annual_mortality_interpretation'" == "" local annual_mortality_interpretation ///
    "[Analyst: add annual mortality interpretation.]"
if "`annual_methods_note'" == "" local annual_methods_note ///
    "The standard section uses only the declared approved public releases."

* -----------------------------------------------------------------------------
* 2. Freeze the two already-approved public datasets in temporary Stata files
* -----------------------------------------------------------------------------

tempfile annual_event_data annual_mortality_data

import delimited using "`event_csv'", varnames(1) clear

local event_required_variables ///
    metric_id release_id period_type period_year period_complete event_type ///
    sex age_group statistic ascertainment_scope mortality_definition ///
    value display_value unit suppression_status ///
    ci_lower_value ci_upper_value linkage_lower_value linkage_upper_value

foreach variable of local event_required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "Annual report standard section: required event variable is absent: `variable'"
        exit 111
    }
}

capture confirm string variable display_value
if _rc tostring display_value, replace force usedisplayformat

quietly count if release_id != "`event_release'"
if r(N) {
    display as error "Annual report standard section: event CSV contains the wrong release identifier."
    exit 459
}
quietly count if period_year == `report_year_num'
if r(N) == 0 {
    display as error "Annual report standard section: event release contains no rows for report year `report_year4'."
    exit 459
}
keep if period_year <= `report_year_num'
save "`annual_event_data'", replace

import delimited using "`mortality_csv'", varnames(1) clear

local mortality_required_variables ///
    metric_id release_id period_type period_year period_complete event_type ///
    sex age_group case_definition statistic value display_value unit ///
    suppression_status ci_lower_value ci_upper_value

foreach variable of local mortality_required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "Annual report standard section: required mortality variable is absent: `variable'"
        exit 111
    }
}

capture confirm string variable display_value
if _rc tostring display_value, replace force usedisplayformat

quietly count if release_id != "`mortality_release'"
if r(N) {
    display as error "Annual report standard section: mortality CSV contains the wrong release identifier."
    exit 459
}
quietly count if period_year == `report_year_num'
if r(N) == 0 {
    display as error "Annual report standard section: mortality release contains no rows for report year `report_year4'."
    exit 459
}
keep if period_year <= `report_year_num'
save "`annual_mortality_data'", replace

* -----------------------------------------------------------------------------
* 3. Report-year headline values
* -----------------------------------------------------------------------------

local kpi_event_hospital "Not available"
local kpi_event_national "Not available"
local kpi_mortality_count "Not available"
local kpi_mortality_rate "Not available"

use "`annual_event_data'", clear
preserve
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & statistic == "annual_count" & ///
        event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
        ascertainment_scope == "hospital_only" & ///
        mortality_definition == "not_applicable"
    quietly count
    if r(N) == 1 local kpi_event_hospital = display_value[1]
restore

preserve
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & statistic == "annual_count" & ///
        event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
        ascertainment_scope == "hospital_plus_dco" & ///
        mortality_definition == "primary"
    quietly count
    if r(N) == 1 local kpi_event_national = display_value[1]
restore

use "`annual_mortality_data'", clear
preserve
    keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & statistic == "annual_count" & ///
        event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
        case_definition == "primary_clear_likely"
    quietly count
    if r(N) == 1 local kpi_mortality_count = display_value[1]
restore

preserve
    keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
        period_year == `report_year_num' & ///
        statistic == "annual_age_standardised_rate" & ///
        event_type == "all_cvd" & sex == "all" & ///
        age_group == "age_standardised" & ///
        case_definition == "primary_clear_likely"
    quietly count
    if r(N) == 1 local kpi_mortality_rate = display_value[1]
restore

* -----------------------------------------------------------------------------
* 4. Cover
* -----------------------------------------------------------------------------

putpdf paragraph
putpdf text ("BARBADOS NATIONAL REGISTRY"), bold font("Arial", 10, "`bnr_teal'")

putpdf paragraph
putpdf text ("Annual cardiovascular disease report"), bold font("Arial", 25, "`bnr_ink'")
putpdf paragraph
putpdf text ("Barbados | `report_year4'"), bold font("Arial", 18, "`bnr_teal'")

putpdf paragraph
putpdf text ("CVD events and mortality"), font("Arial", 13, "`bnr_muted'")

putpdf paragraph
putpdf text ("This annual report combines the standard BNR surveillance view of cardiovascular disease events and mortality with one year-specific Special chapter. All standard surveillance measures are taken from approved public releases."), font("Arial", 10)

putpdf paragraph
putpdf text ("Report version v`version_num'"), italic font("Arial", 9, "`bnr_muted'")

putpdf table cover_sources = (2,2), width(78%) border(all, nil)
putpdf table cover_sources(1,1) = ("CVD-event release")
putpdf table cover_sources(1,2) = ("`event_release'")
putpdf table cover_sources(2,1) = ("Mortality release")
putpdf table cover_sources(2,2) = ("`mortality_release'")
putpdf table cover_sources(.,.), font("Arial", 8)
putpdf table cover_sources(.,1), bold font("Arial", 8, "`bnr_ink'")
putpdf table cover_sources(.,2), font("Arial", 8, "`bnr_teal'")

putpdf paragraph
putpdf text ("Candidate for review. Step 1 does not approve or publish this report."), italic font("Arial", 7.5, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 5. At a glance
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("STANDARD SURVEILLANCE"), bold font("Arial", 9, "`bnr_teal'")
putpdf paragraph
putpdf text ("`report_year4' in brief"), bold font("Arial", 20, "`bnr_ink'")

putpdf table annual_brief = (2,4), width(100%) border(all, single)
putpdf table annual_brief(1,1) = ("`kpi_event_hospital'")
putpdf table annual_brief(1,2) = ("`kpi_event_national'")
putpdf table annual_brief(1,3) = ("`kpi_mortality_count'")
putpdf table annual_brief(1,4) = ("`kpi_mortality_rate'")
putpdf table annual_brief(2,1) = ("Hospital-recorded CVD events")
putpdf table annual_brief(2,2) = ("Estimated national CVD events | Primary")
putpdf table annual_brief(2,3) = ("CVD deaths | Primary")
putpdf table annual_brief(2,4) = ("CVD mortality rate | Primary ASR per 100,000")
putpdf table annual_brief(1,.), bold font("Arial", 16, "`bnr_teal'") halign(center)
putpdf table annual_brief(2,.), font("Arial", 7, "`bnr_ink'") halign(center)
putpdf table annual_brief(1,.), bgcolor("`bnr_pale'")

putpdf paragraph
putpdf text ("Key messages"), bold font("Arial", 12, "`bnr_ink'")
putpdf paragraph
putpdf text ("1. `annual_summary_message_1'"), font("Arial", 9)
putpdf paragraph
putpdf text ("2. `annual_summary_message_2'"), font("Arial", 9)
putpdf paragraph
putpdf text ("3. `annual_summary_message_3'"), font("Arial", 9)

putpdf paragraph
putpdf text ("How to read the headline values"), bold font("Arial", 10, "`bnr_ink'")
putpdf paragraph
putpdf text ("Hospital-recorded events are observed registry events. The Primary national event estimate adds the published DCO component using the Primary mortality definition. Mortality values use the BNR Primary clear + likely definition. ASR means age-standardised rate."), font("Arial", 8)

* -----------------------------------------------------------------------------
* 6. CVD events - figure 1: Heart and Stroke hospital ASR by sex
* -----------------------------------------------------------------------------

local event_fig1 "`annual_figure_dir'/annual_event_rates_by_type_sex.png"
local have_event_fig1 0

use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
    statistic == "annual_age_standardised_rate" & ///
    age_group == "age_standardised" & ///
    ascertainment_scope == "hospital_only" & ///
    mortality_definition == "not_applicable" & ///
    inlist(event_type, "heart", "stroke") & ///
    inlist(sex, "female", "male") & ///
    period_complete == 1 & suppression_status == "none" & !missing(value)
quietly count
if r(N) >= 4 {
    twoway ///
        (connected value period_year if event_type == "heart" & sex == "male", ///
            sort lcolor("`bnr_heart'") mcolor("`bnr_heart'") ///
            lwidth(medthick) msymbol(O) msize(small)) ///
        (connected value period_year if event_type == "heart" & sex == "female", ///
            sort lcolor("`bnr_heart'") mcolor("`bnr_heart'") ///
            lpattern(dash) lwidth(medthick) msymbol(Oh) msize(small)) ///
        (connected value period_year if event_type == "stroke" & sex == "male", ///
            sort lcolor("`bnr_stroke'") mcolor("`bnr_stroke'") ///
            lwidth(medthick) msymbol(S) msize(small)) ///
        (connected value period_year if event_type == "stroke" & sex == "female", ///
            sort lcolor("`bnr_stroke'") mcolor("`bnr_stroke'") ///
            lpattern(dash) lwidth(medthick) msymbol(Sh) msize(small)), ///
        graphregion(color(white) margin(small)) ///
        plotregion(color(white) margin(small)) ///
        xlabel(#4, format(%4.0f) labsize(small) noticks nogrid) ///
        ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        xtitle("") ytitle("") ///
        legend(order(1 "Heart - Men" 2 "Heart - Women" ///
                     3 "Stroke - Men" 4 "Stroke - Women") ///
               cols(2) size(small) region(lcolor(none))) ///
        title("") subtitle("") ///
        xsize(7.2) ysize(3.6)
    graph export "`event_fig1'", replace width(2400)
    local have_event_fig1 1
}

putpdf pagebreak
putpdf paragraph
putpdf text ("1 | CVD events"), bold font("Arial", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("Hospital-recorded Heart and Stroke event rates"), bold font("Arial", 12, "`bnr_ink'")
putpdf paragraph
putpdf text ("Age-standardised annual rates per 100,000. Solid lines show men; dashed lines show women."), font("Arial", 8, "`bnr_muted'")
if `have_event_fig1' {
    putpdf image "`event_fig1'", width(6.8)
}
else {
    putpdf paragraph
    putpdf text ("Figure not produced: fewer than four unrestricted published rate rows were available."), italic font("Arial", 8, "`bnr_muted'")
}
putpdf paragraph
putpdf text ("Figure 1. Hospital-recorded Heart and Stroke age-standardised event rates by sex, through `report_year4'."), font("Arial", 7.5)
putpdf paragraph
putpdf text ("Source: BNR public CVD-event release `event_release'. Rates are displayed as published; the annual report does not calculate them."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 7. CVD events - figure 2: all-CVD ASR by ascertainment
* -----------------------------------------------------------------------------

local event_fig2 "`annual_figure_dir'/annual_event_rates_ascertainment.png"
local have_event_fig2 0

use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
    statistic == "annual_age_standardised_rate" & ///
    age_group == "age_standardised" & event_type == "all_cvd" & ///
    sex == "all" & period_complete == 1 & suppression_status == "none" & ///
    !missing(value)

generate byte report_series = .
replace report_series = 1 if ascertainment_scope == "hospital_only" & ///
    mortality_definition == "not_applicable"
replace report_series = 2 if ascertainment_scope == "hospital_plus_dco" & ///
    mortality_definition == "primary"
replace report_series = 3 if ascertainment_scope == "hospital_plus_dco" & ///
    mortality_definition == "inclusive"
keep if inlist(report_series, 1, 2, 3)
quietly count
if r(N) >= 3 {
    twoway ///
        (rarea linkage_lower_value linkage_upper_value period_year if report_series == 2, ///
            sort color("`bnr_primary_fill'") lcolor(none)) ///
        (connected value period_year if report_series == 2, sort ///
            lcolor("`bnr_primary'") mcolor("`bnr_primary'") ///
            lwidth(medthick) msymbol(O) msize(small)) ///
        (rarea linkage_lower_value linkage_upper_value period_year if report_series == 3, ///
            sort color("`bnr_inclusive_fill'") lcolor(none)) ///
        (connected value period_year if report_series == 3, sort ///
            lcolor("`bnr_inclusive'") mcolor("`bnr_inclusive'") ///
            lwidth(medthick) msymbol(S) msize(small)) ///
        (connected value period_year if report_series == 1, sort ///
            lcolor("`bnr_teal'") mcolor("`bnr_teal'") ///
            lwidth(medthick) msymbol(D) msize(small)), ///
        graphregion(color(white) margin(small)) ///
        plotregion(color(white) margin(small)) ///
        xlabel(#4, format(%4.0f) labsize(small) noticks nogrid) ///
        ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        xtitle("") ytitle("") ///
        legend(order(5 "Hospital-recorded" 2 "Hospital + DCO Primary" ///
                     4 "Hospital + DCO Inclusive") ///
               cols(1) size(small) region(lcolor(none))) ///
        title("") subtitle("") ///
        xsize(7.2) ysize(3.6)
    graph export "`event_fig2'", replace width(2400)
    local have_event_fig2 1
}

putpdf pagebreak
putpdf paragraph
putpdf text ("Event ascertainment and national estimates"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The hospital series is observed. Primary and Inclusive Hospital + DCO series are published national estimates. Shaded areas are the released DCO linkage ranges, not statistical confidence intervals."), font("Arial", 8)
if `have_event_fig2' {
    putpdf image "`event_fig2'", width(6.8)
}
else {
    putpdf paragraph
    putpdf text ("Figure not produced: the required unrestricted published ascertainment series were not available."), italic font("Arial", 8, "`bnr_muted'")
}
putpdf paragraph
putpdf text ("Figure 2. All-CVD age-standardised event rates by event ascertainment, through `report_year4'."), font("Arial", 7.5)
putpdf paragraph
putpdf text ("Source: BNR public CVD-event release `event_release'."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 8. CVD events - report-year counts and rates
* -----------------------------------------------------------------------------

putpdf paragraph
putpdf text ("`report_year4' event counts"), bold font("Arial", 12, "`bnr_ink'")
putpdf table event_counts = (4,4), width(100%) border(all, single)
putpdf table event_counts(1,1) = ("CVD type")
putpdf table event_counts(1,2) = ("Hospital-recorded")
putpdf table event_counts(1,3) = ("National Primary")
putpdf table event_counts(1,4) = ("National Inclusive")

local event_row 1
foreach event_key in all_cvd heart stroke {
    local ++event_row
    local event_label "All CVD"
    if "`event_key'" == "heart"  local event_label "Heart"
    if "`event_key'" == "stroke" local event_label "Stroke"

    local hospital_cell "Not available"
    local primary_cell "Not available"
    local inclusive_cell "Not available"

    use "`annual_event_data'", clear
    preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "annual_count" & ///
            event_type == "`event_key'" & sex == "all" & age_group == "all" & ///
            ascertainment_scope == "hospital_only" & ///
            mortality_definition == "not_applicable"
        quietly count
        if r(N) == 1 local hospital_cell = display_value[1]
    restore

    preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "annual_count" & ///
            event_type == "`event_key'" & sex == "all" & age_group == "all" & ///
            ascertainment_scope == "hospital_plus_dco" & ///
            mortality_definition == "primary"
        quietly count
        if r(N) == 1 {
            local primary_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(linkage_lower_value[1], linkage_upper_value[1]) {
                local lower_txt : display %6.1f linkage_lower_value[1]
                local upper_txt : display %6.1f linkage_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local primary_cell "`primary_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "annual_count" & ///
            event_type == "`event_key'" & sex == "all" & age_group == "all" & ///
            ascertainment_scope == "hospital_plus_dco" & ///
            mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local inclusive_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(linkage_lower_value[1], linkage_upper_value[1]) {
                local lower_txt : display %6.1f linkage_lower_value[1]
                local upper_txt : display %6.1f linkage_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local inclusive_cell "`inclusive_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    putpdf table event_counts(`event_row',1) = ("`event_label'")
    putpdf table event_counts(`event_row',2) = ("`hospital_cell'")
    putpdf table event_counts(`event_row',3) = ("`primary_cell'")
    putpdf table event_counts(`event_row',4) = ("`inclusive_cell'")
}
putpdf table event_counts(.,.), font("Arial", 7.5)
putpdf table event_counts(1,.), bold bgcolor("`bnr_pale'")
putpdf table event_counts(.,1), bold

putpdf paragraph
putpdf text ("For national Primary and Inclusive estimates, parentheses show the released DCO linkage range where available. An asterisk is the published suppression marker."), font("Arial", 7, "`bnr_muted'")

putpdf paragraph
putpdf text ("`report_year4' age-standardised event rates"), bold font("Arial", 12, "`bnr_ink'")
putpdf table event_rates = (4,4), width(100%) border(all, single)
putpdf table event_rates(1,1) = ("CVD type")
putpdf table event_rates(1,2) = ("Hospital-recorded")
putpdf table event_rates(1,3) = ("National Primary")
putpdf table event_rates(1,4) = ("National Inclusive")

local event_row 1
foreach event_key in all_cvd heart stroke {
    local ++event_row
    local event_label "All CVD"
    if "`event_key'" == "heart"  local event_label "Heart"
    if "`event_key'" == "stroke" local event_label "Stroke"

    local hospital_cell "Not available"
    local primary_cell "Not available"
    local inclusive_cell "Not available"

    use "`annual_event_data'", clear
    preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
            period_year == `report_year_num' & ///
            statistic == "annual_age_standardised_rate" & ///
            event_type == "`event_key'" & sex == "all" & ///
            age_group == "age_standardised" & ///
            ascertainment_scope == "hospital_only" & ///
            mortality_definition == "not_applicable"
        quietly count
        if r(N) == 1 {
            local hospital_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(ci_lower_value[1], ci_upper_value[1]) {
                local lower_txt : display %6.1f ci_lower_value[1]
                local upper_txt : display %6.1f ci_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local hospital_cell "`hospital_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
            period_year == `report_year_num' & ///
            statistic == "annual_age_standardised_rate" & ///
            event_type == "`event_key'" & sex == "all" & ///
            age_group == "age_standardised" & ///
            ascertainment_scope == "hospital_plus_dco" & ///
            mortality_definition == "primary"
        quietly count
        if r(N) == 1 {
            local primary_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(ci_lower_value[1], ci_upper_value[1]) {
                local lower_txt : display %6.1f ci_lower_value[1]
                local upper_txt : display %6.1f ci_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local primary_cell "`primary_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
            period_year == `report_year_num' & ///
            statistic == "annual_age_standardised_rate" & ///
            event_type == "`event_key'" & sex == "all" & ///
            age_group == "age_standardised" & ///
            ascertainment_scope == "hospital_plus_dco" & ///
            mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local inclusive_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(ci_lower_value[1], ci_upper_value[1]) {
                local lower_txt : display %6.1f ci_lower_value[1]
                local upper_txt : display %6.1f ci_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local inclusive_cell "`inclusive_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    putpdf table event_rates(`event_row',1) = ("`event_label'")
    putpdf table event_rates(`event_row',2) = ("`hospital_cell'")
    putpdf table event_rates(`event_row',3) = ("`primary_cell'")
    putpdf table event_rates(`event_row',4) = ("`inclusive_cell'")
}
putpdf table event_rates(.,.), font("Arial", 7.5)
putpdf table event_rates(1,.), bold bgcolor("`bnr_pale'")
putpdf table event_rates(.,1), bold

putpdf paragraph
putpdf text ("Rates are per 100,000 and directly age-standardised. Parentheses show the published 95% statistical confidence interval. DCO linkage ranges are shown in Figure 2 rather than combined with statistical confidence intervals."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 9. CVD events - report-year profile
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("The `report_year4' event profile"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Published percentages describe the composition of hospital-recorded events. They are not population rates."), font("Arial", 8)

putpdf table event_profile = (7,3), width(82%) border(all, single)
putpdf table event_profile(1,1) = ("Dimension")
putpdf table event_profile(1,2) = ("Group")
putpdf table event_profile(1,3) = ("Percent")

local profile_row 1
foreach profile_item in heart stroke under_70 age_70_plus female male {
    local ++profile_row
    local dimension "CVD type"
    local group_label "Heart"
    local profile_stat "event_type_distribution"
    local profile_event "heart"
    local profile_sex "all"
    local profile_age "all"

    if "`profile_item'" == "stroke" {
        local group_label "Stroke"
        local profile_event "stroke"
    }
    if "`profile_item'" == "under_70" {
        local dimension "Age"
        local group_label "Under 70"
        local profile_stat "age_distribution"
        local profile_event "all_cvd"
        local profile_age "under_70"
    }
    if "`profile_item'" == "age_70_plus" {
        local dimension "Age"
        local group_label "70 and older"
        local profile_stat "age_distribution"
        local profile_event "all_cvd"
        local profile_age "age_70_plus"
    }
    if "`profile_item'" == "female" {
        local dimension "Sex"
        local group_label "Women"
        local profile_stat "sex_distribution"
        local profile_event "all_cvd"
        local profile_sex "female"
        local profile_age "all"
    }
    if "`profile_item'" == "male" {
        local dimension "Sex"
        local group_label "Men"
        local profile_stat "sex_distribution"
        local profile_event "all_cvd"
        local profile_sex "male"
        local profile_age "all"
    }

    local profile_value "Not available"
    use "`annual_event_data'", clear
    preserve
        keep if metric_id == "CVD-BURDEN-002" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "`profile_stat'" & ///
            event_type == "`profile_event'" & sex == "`profile_sex'" & ///
            age_group == "`profile_age'" & ///
            ascertainment_scope == "hospital_only"
        quietly count
        if r(N) == 1 local profile_value = display_value[1]
    restore

    putpdf table event_profile(`profile_row',1) = ("`dimension'")
    putpdf table event_profile(`profile_row',2) = ("`group_label'")
    putpdf table event_profile(`profile_row',3) = ("`profile_value'")
}
putpdf table event_profile(.,.), font("Arial", 8)
putpdf table event_profile(1,.), bold bgcolor("`bnr_pale'")
putpdf table event_profile(.,1), bold

putpdf paragraph
putpdf text ("Annual interpretation"), bold font("Arial", 12, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_events_interpretation'"), font("Arial", 9)

putpdf paragraph
putpdf text ("Source: BNR public CVD-event release `event_release'."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 10. Mortality - figure 3: Primary all-CVD ASMR by sex
* -----------------------------------------------------------------------------

local mortality_fig1 "`annual_figure_dir'/annual_mortality_rate_by_sex.png"
local have_mortality_fig1 0

use "`annual_mortality_data'", clear
keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
    statistic == "annual_age_standardised_rate" & ///
    age_group == "age_standardised" & event_type == "all_cvd" & ///
    case_definition == "primary_clear_likely" & ///
    inlist(sex, "female", "male") & period_complete == 1 & ///
    suppression_status == "none" & !missing(value)
quietly count
if r(N) >= 2 {
    twoway ///
        (connected value period_year if sex == "male", sort ///
            lcolor("`bnr_men'") mcolor("`bnr_men'") ///
            lwidth(medthick) msymbol(O) msize(small)) ///
        (connected value period_year if sex == "female", sort ///
            lcolor("`bnr_women'") mcolor("`bnr_women'") ///
            lwidth(medthick) msymbol(S) msize(small)), ///
        graphregion(color(white) margin(small)) ///
        plotregion(color(white) margin(small)) ///
        xlabel(#4, format(%4.0f) labsize(small) noticks nogrid) ///
        ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        xtitle("") ytitle("") ///
        legend(order(1 "Men" 2 "Women") cols(2) size(small) ///
               region(lcolor(none))) ///
        title("") subtitle("") ///
        xsize(7.2) ysize(3.5)
    graph export "`mortality_fig1'", replace width(2400)
    local have_mortality_fig1 1
}

putpdf pagebreak
putpdf paragraph
putpdf text ("2 | CVD mortality"), bold font("Arial", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("Age-standardised CVD mortality"), bold font("Arial", 12, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary mortality definition (clear + likely), annual age-standardised rates per 100,000."), font("Arial", 8, "`bnr_muted'")
if `have_mortality_fig1' {
    putpdf image "`mortality_fig1'", width(6.8)
}
else {
    putpdf paragraph
    putpdf text ("Figure not produced: unrestricted published sex-specific mortality rates were not available."), italic font("Arial", 8, "`bnr_muted'")
}
putpdf paragraph
putpdf text ("Figure 3. Primary all-CVD age-standardised mortality rates by sex, through `report_year4'."), font("Arial", 7.5)
putpdf paragraph
putpdf text ("Source: BNR public mortality release `mortality_release'."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 11. Mortality - figure 4: latest Primary and Inclusive ASMR with published CIs
* -----------------------------------------------------------------------------

local mortality_fig2 "`annual_figure_dir'/annual_mortality_definition_forest.png"
local have_mortality_fig2 0

use "`annual_mortality_data'", clear
keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
    period_year == `report_year_num' & ///
    statistic == "annual_age_standardised_rate" & ///
    age_group == "age_standardised" & sex == "all" & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & ///
    inlist(case_definition, "primary_clear_likely", ///
        "upper_clear_likely_possible") & ///
    period_complete == 1 & suppression_status == "none" & ///
    !missing(value, ci_lower_value, ci_upper_value)

generate double y_plot = .
replace y_plot = 3 if event_type == "all_cvd"
replace y_plot = 2 if event_type == "heart"
replace y_plot = 1 if event_type == "stroke"
replace y_plot = y_plot + 0.09 if case_definition == "primary_clear_likely"
replace y_plot = y_plot - 0.09 if case_definition == "upper_clear_likely_possible"
quietly count
if r(N) >= 2 {
    twoway ///
        (rcap ci_lower_value ci_upper_value y_plot if ///
            case_definition == "primary_clear_likely", horizontal ///
            lcolor("`bnr_teal'") lwidth(medthick)) ///
        (scatter y_plot value if case_definition == "primary_clear_likely", ///
            mcolor("`bnr_teal'") msymbol(O) msize(medsmall)) ///
        (rcap ci_lower_value ci_upper_value y_plot if ///
            case_definition == "upper_clear_likely_possible", horizontal ///
            lcolor("`bnr_primary'") lwidth(medthick)) ///
        (scatter y_plot value if ///
            case_definition == "upper_clear_likely_possible", ///
            mcolor("`bnr_primary'") msymbol(S) msize(medsmall)), ///
        graphregion(color(white) margin(small)) ///
        plotregion(color(white) margin(small)) ///
        ylabel(1 "Stroke" 2 "Heart" 3 "All CVD", angle(horizontal) ///
            labsize(small) noticks nogrid) ///
        xlabel(, labsize(small) noticks nogrid) ///
        xtitle("Rate per 100,000", size(small)) ytitle("") ///
        legend(order(2 "Primary" 4 "Inclusive") cols(2) size(small) ///
               region(lcolor(none))) ///
        title("") subtitle("") ///
        xsize(7.2) ysize(3.3)
    graph export "`mortality_fig2'", replace width(2400)
    local have_mortality_fig2 1
}

putpdf pagebreak
putpdf paragraph
putpdf text ("Primary and Inclusive mortality definitions"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The two definitions are alternative BNR mortality classifications. Points are the published `report_year4' age-standardised rates; horizontal lines are the published 95% statistical confidence intervals."), font("Arial", 8)
if `have_mortality_fig2' {
    putpdf image "`mortality_fig2'", width(6.8)
}
else {
    putpdf paragraph
    putpdf text ("Figure not produced: the required unrestricted published mortality-rate rows were not available."), italic font("Arial", 8, "`bnr_muted'")
}
putpdf paragraph
putpdf text ("Figure 4. Primary and Inclusive age-standardised mortality rates for All CVD, Heart and Stroke, `report_year4'."), font("Arial", 7.5)

* -----------------------------------------------------------------------------
* 12. Mortality - report-year counts and rates
* -----------------------------------------------------------------------------

putpdf paragraph
putpdf text ("`report_year4' mortality counts"), bold font("Arial", 12, "`bnr_ink'")
putpdf table mortality_counts = (4,3), width(82%) border(all, single)
putpdf table mortality_counts(1,1) = ("CVD type")
putpdf table mortality_counts(1,2) = ("Primary")
putpdf table mortality_counts(1,3) = ("Inclusive")

local mortality_row 1
foreach event_key in all_cvd heart stroke {
    local ++mortality_row
    local event_label "All CVD"
    if "`event_key'" == "heart"  local event_label "Heart"
    if "`event_key'" == "stroke" local event_label "Stroke"

    local primary_cell "Not available"
    local inclusive_cell "Not available"

    use "`annual_mortality_data'", clear
    preserve
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "annual_count" & ///
            event_type == "`event_key'" & sex == "all" & age_group == "all" & ///
            case_definition == "primary_clear_likely"
        quietly count
        if r(N) == 1 local primary_cell = display_value[1]
    restore

    preserve
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "annual_count" & ///
            event_type == "`event_key'" & sex == "all" & age_group == "all" & ///
            case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 local inclusive_cell = display_value[1]
    restore

    putpdf table mortality_counts(`mortality_row',1) = ("`event_label'")
    putpdf table mortality_counts(`mortality_row',2) = ("`primary_cell'")
    putpdf table mortality_counts(`mortality_row',3) = ("`inclusive_cell'")
}
putpdf table mortality_counts(.,.), font("Arial", 8)
putpdf table mortality_counts(1,.), bold bgcolor("`bnr_pale'")
putpdf table mortality_counts(.,1), bold

putpdf paragraph
putpdf text ("`report_year4' age-standardised mortality rates"), bold font("Arial", 12, "`bnr_ink'")
putpdf table mortality_rates = (4,3), width(82%) border(all, single)
putpdf table mortality_rates(1,1) = ("CVD type")
putpdf table mortality_rates(1,2) = ("Primary")
putpdf table mortality_rates(1,3) = ("Inclusive")

local mortality_row 1
foreach event_key in all_cvd heart stroke {
    local ++mortality_row
    local event_label "All CVD"
    if "`event_key'" == "heart"  local event_label "Heart"
    if "`event_key'" == "stroke" local event_label "Stroke"

    local primary_cell "Not available"
    local inclusive_cell "Not available"

    use "`annual_mortality_data'", clear
    preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
            period_year == `report_year_num' & ///
            statistic == "annual_age_standardised_rate" & ///
            event_type == "`event_key'" & sex == "all" & ///
            age_group == "age_standardised" & ///
            case_definition == "primary_clear_likely"
        quietly count
        if r(N) == 1 {
            local primary_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(ci_lower_value[1], ci_upper_value[1]) {
                local lower_txt : display %6.1f ci_lower_value[1]
                local upper_txt : display %6.1f ci_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local primary_cell "`primary_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
            period_year == `report_year_num' & ///
            statistic == "annual_age_standardised_rate" & ///
            event_type == "`event_key'" & sex == "all" & ///
            age_group == "age_standardised" & ///
            case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 {
            local inclusive_cell = display_value[1]
            if suppression_status[1] == "none" & ///
                    !missing(ci_lower_value[1], ci_upper_value[1]) {
                local lower_txt : display %6.1f ci_lower_value[1]
                local upper_txt : display %6.1f ci_upper_value[1]
                local lower_txt = strtrim("`lower_txt'")
                local upper_txt = strtrim("`upper_txt'")
                local inclusive_cell "`inclusive_cell' (`lower_txt'-`upper_txt')"
            }
        }
    restore

    putpdf table mortality_rates(`mortality_row',1) = ("`event_label'")
    putpdf table mortality_rates(`mortality_row',2) = ("`primary_cell'")
    putpdf table mortality_rates(`mortality_row',3) = ("`inclusive_cell'")
}
putpdf table mortality_rates(.,.), font("Arial", 8)
putpdf table mortality_rates(1,.), bold bgcolor("`bnr_pale'")
putpdf table mortality_rates(.,1), bold

putpdf paragraph
putpdf text ("Rates are per 100,000 and directly age-standardised. Parentheses show the published 95% statistical confidence interval."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 13. Mortality - report-year profile for both definitions
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("The `report_year4' mortality profile"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The table compares published distribution percentages under the Primary and Inclusive definitions."), font("Arial", 8)

putpdf table mortality_profile = (7,4), width(100%) border(all, single)
putpdf table mortality_profile(1,1) = ("Dimension")
putpdf table mortality_profile(1,2) = ("Group")
putpdf table mortality_profile(1,3) = ("Primary")
putpdf table mortality_profile(1,4) = ("Inclusive")

local profile_row 1
foreach profile_item in heart stroke under_70 age_70_plus female male {
    local ++profile_row
    local dimension "CVD type"
    local group_label "Heart"
    local profile_stat "event_type_distribution"
    local profile_event "heart"
    local profile_sex "all"
    local profile_age "all"

    if "`profile_item'" == "stroke" {
        local group_label "Stroke"
        local profile_event "stroke"
    }
    if "`profile_item'" == "under_70" {
        local dimension "Age"
        local group_label "Under 70"
        local profile_stat "age_distribution"
        local profile_event "all_cvd"
        local profile_age "under_70"
    }
    if "`profile_item'" == "age_70_plus" {
        local dimension "Age"
        local group_label "70 and older"
        local profile_stat "age_distribution"
        local profile_event "all_cvd"
        local profile_age "age_70_plus"
    }
    if "`profile_item'" == "female" {
        local dimension "Sex"
        local group_label "Women"
        local profile_stat "sex_distribution"
        local profile_event "all_cvd"
        local profile_sex "female"
        local profile_age "all"
    }
    if "`profile_item'" == "male" {
        local dimension "Sex"
        local group_label "Men"
        local profile_stat "sex_distribution"
        local profile_event "all_cvd"
        local profile_sex "male"
        local profile_age "all"
    }

    local primary_value "Not available"
    local inclusive_value "Not available"
    use "`annual_mortality_data'", clear

    preserve
        keep if metric_id == "MORT-BURDEN-002" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "`profile_stat'" & ///
            event_type == "`profile_event'" & sex == "`profile_sex'" & ///
            age_group == "`profile_age'" & ///
            case_definition == "primary_clear_likely"
        quietly count
        if r(N) == 1 local primary_value = display_value[1]
    restore

    preserve
        keep if metric_id == "MORT-BURDEN-002" & period_type == "annual" & ///
            period_year == `report_year_num' & statistic == "`profile_stat'" & ///
            event_type == "`profile_event'" & sex == "`profile_sex'" & ///
            age_group == "`profile_age'" & ///
            case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 local inclusive_value = display_value[1]
    restore

    putpdf table mortality_profile(`profile_row',1) = ("`dimension'")
    putpdf table mortality_profile(`profile_row',2) = ("`group_label'")
    putpdf table mortality_profile(`profile_row',3) = ("`primary_value'")
    putpdf table mortality_profile(`profile_row',4) = ("`inclusive_value'")
}
putpdf table mortality_profile(.,.), font("Arial", 8)
putpdf table mortality_profile(1,.), bold bgcolor("`bnr_pale'")
putpdf table mortality_profile(.,1), bold

putpdf paragraph
putpdf text ("Annual interpretation"), bold font("Arial", 12, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_mortality_interpretation'"), font("Arial", 9)

putpdf paragraph
putpdf text ("Source: BNR public mortality release `mortality_release'."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 14. How to read the standard surveillance section
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("3 | How to read the surveillance estimates"), bold font("Arial", 18, "`bnr_ink'")

putpdf table reading_notes = (6,2), width(100%) border(all, single)
putpdf table reading_notes(1,1) = ("Term")
putpdf table reading_notes(1,2) = ("Meaning in this report")
putpdf table reading_notes(2,1) = ("Hospital-recorded")
putpdf table reading_notes(2,2) = ("Eligible CVD events recorded through the hospital-based registry pathway.")
putpdf table reading_notes(3,1) = ("Hospital + DCO")
putpdf table reading_notes(3,2) = ("Published national event estimate that adds the DCO component to hospital-recorded events.")
putpdf table reading_notes(4,1) = ("Primary / Inclusive")
putpdf table reading_notes(4,2) = ("Alternative published mortality definitions. Primary uses clear + likely; Inclusive adds possible deaths.")
putpdf table reading_notes(5,1) = ("95% statistical CI")
putpdf table reading_notes(5,2) = ("Published statistical confidence interval around a rate. It is distinct from DCO linkage uncertainty.")
putpdf table reading_notes(6,1) = ("*")
putpdf table reading_notes(6,2) = ("Published suppression marker. Protected values are not reconstructed in this report.")
putpdf table reading_notes(.,.), font("Arial", 8)
putpdf table reading_notes(1,.), bold bgcolor("`bnr_pale'")
putpdf table reading_notes(.,1), bold

putpdf paragraph
putpdf text ("Population rates"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Published event and mortality rates use the approved Barbados population denominator from UN World Population Prospects 2024. Age-standardised rates use the fixed WHO World Standard Population 2000-2025. These calculations are completed upstream in the approved event and mortality workflows."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Source boundary"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_methods_note'"), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Declared CVD-event release: `event_release'"), font("Arial", 8, "`bnr_teal'")
putpdf paragraph
putpdf text ("Declared mortality release: `mortality_release'"), font("Arial", 8, "`bnr_teal'")

putpdf paragraph
putpdf text ("The annual report concentrates on annual counts, distributions and rates. Monthly and quarterly detail remains available through the approved public datasets and Information Hub dashboards."), font("Arial", 8, "`bnr_muted'")

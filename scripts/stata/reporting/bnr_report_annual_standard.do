/*******************************************************************************
DO-FILE: bnr_report_annual_standard.do
VERSION: 2.2.0 (3 September 2026)
PURPOSE: Reusable putpdf composition for the standard annual CVD surveillance
         section.

CALLER:
  bnr_report_annual_s1_build.do only.

SOURCE BOUNDARY:
  This file reads only the two declared approved public release CSVs selected
  and checksum-validated by Step 1. It never reads confidential source data and
  it does not recalculate published surveillance rates.

DESIGN CONTRACT:
  - A4 portrait annual-report publication, not a printed dashboard.
  - Montserrat Medium is used for titling and Montserrat for body copy.
  - The UWI crest, restrained BNR palette and briefing-style white space provide
    the visual identity.
  - The cover and Year in Brief use fixed invisible-table layout grids so the
    page is composed deliberately rather than allowed to flow unpredictably.
  - Results graphics show the complete approved annual time series.
  - Exact result tables show the latest five complete years in wide form.
  - Public-facing headings use counts/events/deaths rather than "burden".
  - Graph furniture is deliberately sparse.
  - DCO/linkage uncertainty is shown as a pale band; published statistical
    confidence intervals are shown as whiskers.
  - Published five-year count comparators are used where they exist.
  - Interpretation remains analyst-owned in the year-specific interpretation
    file; this composition file does not generate editorial conclusions.
  - Special chapter composition remains outside this file.

DESIGN PASS 2.2.0:
  - Keep summary-card backgrounds continuous behind labels and values.
  - Simplify interpretation callouts to one continuous pale panel.
  - Widen annual graphics, move legends to 12 o'clock, remove axis lines and
    add same-colour observed-value markers to line charts.
  - Increase use of published uncertainty without combining distinct sources:
    DCO linkage ranges are shaded; statistical 95% confidence intervals use
    whiskers.
  - Add a concise quarterly hospital-recorded "How the year unfolded" view.
  - Rebuild completeness graphics as labelled five-year tile matrices.
  - Expand Methods into a publication-grade technical section covering
    ascertainment, definitions, equations, uncertainty, disclosure and release
    governance.
  - Keep analytical definitions, release selection and workflow boundaries
    unchanged.
*******************************************************************************/

version 19.0

* -----------------------------------------------------------------------------
* 1. Required context and visual language
* -----------------------------------------------------------------------------

if "`report_year4'" == "" {
    display as error "Annual standard composition requires local report_year4."
    exit 198
}
if "`event_release'" == "" | "`mortality_release'" == "" {
    display as error "Annual standard composition requires declared public release IDs."
    exit 198
}

local uwi_crest "$BNR_REPO/site/assets/images/uwi-crestonly-20p.png"
capture confirm file "`uwi_crest'"
if _rc {
    display as error "Required UWI crest not found: `uwi_crest'"
    exit 601
}

* RGB strings are retained as locals so the 2025 Special chapter can reuse them.
local bnr_ink       "44 62 80"
local bnr_teal      "4 81 116"
local bnr_primary   "43 115 136"
local bnr_secondary "91 139 151"
local bnr_women     "122 85 134"
local bnr_men       "45 103 141"
local bnr_stroke    "42 127 142"
local bnr_heart     "178 95 82"
local bnr_under70   "216 156 96"
local bnr_70plus    "122 135 148"
local bnr_pale      "240 246 248"
local bnr_pale2     "248 249 250"
local bnr_rule      "222 226 230"
local bnr_muted     "102 102 102"
local bnr_green     "214 237 223"
local bnr_amber     "255 231 168"
local bnr_red       "243 198 204"

* Publication typography. These fonts are part of the intended analytics
* environment. A separate report style sheet will be produced once the visual
* system has stabilised.
local font_title      "Montserrat Medium"
local font_body       "Montserrat"
local font_body_med   "Montserrat Medium"
local font_body_light "Montserrat Light"

local first_table_year = `report_year_num' - 4

capture mkdir "`candidate_dir'/figures"
local annual_figure_dir "`candidate_dir'/figures"

* -----------------------------------------------------------------------------
* 2. Read the two approved public releases once
* -----------------------------------------------------------------------------

tempfile annual_event_data annual_mortality_data

import delimited using "`event_csv'", clear varnames(1) stringcols(_all)
foreach v in period_year period_month period_quarter period_complete value numerator denominator ///
        linkage_lower_value linkage_upper_value ci_lower_value ci_upper_value ///
        comparison_n {
    capture destring `v', replace force
}
save "`annual_event_data'", replace

import delimited using "`mortality_csv'", clear varnames(1) stringcols(_all)
foreach v in period_year period_complete value numerator denominator ///
        ci_lower_value ci_upper_value comparison_n {
    capture destring `v', replace force
}
save "`annual_mortality_data'", replace

* -----------------------------------------------------------------------------
* 3. Latest-year values used on cover-summary cards
* -----------------------------------------------------------------------------

local yib_event_count "Not available"
local yib_event_rate "Not available"
local yib_event_rate_ci ""
local yib_death_count "Not available"
local yib_death_rate "Not available"
local yib_death_rate_ci ""
local yib_event_dco_share "Not available"
local yib_possible_share "Not available"

use "`annual_event_data'", clear
preserve
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "all" & ///
        ascertainment_scope == "hospital_plus_dco" & ///
        mortality_definition == "primary" & statistic == "annual_count"
    quietly count
    if r(N) == 1 {
        local tmp : display %9.1fc value[1]
        local yib_event_count = strtrim("`tmp'")
    }
restore
preserve
    keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "age_standardised" & ///
        ascertainment_scope == "hospital_plus_dco" & ///
        mortality_definition == "primary" & ///
        statistic == "annual_age_standardised_rate"
    quietly count
    if r(N) == 1 {
        local tmp : display %6.1f value[1]
        local yib_event_rate = strtrim("`tmp'")
        if !missing(ci_lower_value[1], ci_upper_value[1]) {
            local lo : display %6.1f ci_lower_value[1]
            local hi : display %6.1f ci_upper_value[1]
            local yib_event_rate_ci = "95% CI " + strtrim("`lo'") + "-" + strtrim("`hi'")
        }
    }
restore
preserve
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "all" & mortality_definition == "primary" & ///
        inlist(ascertainment_scope, "additional_dco", "hospital_plus_dco") & ///
        statistic == "annual_count"
    quietly summarize value if ascertainment_scope == "additional_dco", meanonly
    local dco_n = r(mean)
    quietly summarize value if ascertainment_scope == "hospital_plus_dco", meanonly
    local national_n = r(mean)
    if !missing(`dco_n', `national_n') & `national_n' > 0 {
        local tmp : display %4.1f (100 * `dco_n' / `national_n')
        local yib_event_dco_share = strtrim("`tmp'") + "%"
    }
restore

use "`annual_mortality_data'", clear
preserve
    keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "all" & ///
        case_definition == "primary_clear_likely" & statistic == "annual_count"
    quietly count
    if r(N) == 1 {
        local tmp : display %9.0fc value[1]
        local yib_death_count = strtrim("`tmp'")
    }
restore
preserve
    keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "age_standardised" & ///
        case_definition == "primary_clear_likely" & ///
        statistic == "annual_age_standardised_rate"
    quietly count
    if r(N) == 1 {
        local tmp : display %6.1f value[1]
        local yib_death_rate = strtrim("`tmp'")
        if !missing(ci_lower_value[1], ci_upper_value[1]) {
            local lo : display %6.1f ci_lower_value[1]
            local hi : display %6.1f ci_upper_value[1]
            local yib_death_rate_ci = "95% CI " + strtrim("`lo'") + "-" + strtrim("`hi'")
        }
    }
restore
preserve
    keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "all" & statistic == "annual_count" & ///
        inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
    quietly summarize value if case_definition == "primary_clear_likely", meanonly
    local mort_primary = r(mean)
    quietly summarize value if case_definition == "upper_clear_likely_possible", meanonly
    local mort_inclusive = r(mean)
    if !missing(`mort_primary', `mort_inclusive') & `mort_inclusive' > 0 {
        local tmp : display %4.1f (100 * (`mort_inclusive' - `mort_primary') / `mort_inclusive')
        local yib_possible_share = strtrim("`tmp'") + "%"
    }
restore

* -----------------------------------------------------------------------------
* 4. Plain cover
* -----------------------------------------------------------------------------

* The cover is held in one invisible layout grid. This avoids the page-flow
* behaviour of the first prototype, where each cover element could land on a
* separate page.
putpdf table cover = (9,12), width(88%) border(all, nil) halign(center)
putpdf table cover(1,1), colspan(12)
putpdf table cover(2,1), colspan(12)
putpdf table cover(3,1), colspan(12)
putpdf table cover(4,1), colspan(12)
putpdf table cover(5,1), colspan(12)
putpdf table cover(6,1), colspan(12)
putpdf table cover(7,1), colspan(12)
putpdf table cover(8,1), colspan(12)
putpdf table cover(9,1), colspan(12)

putpdf table cover(1,1) = (" ")
putpdf table cover(2,1) = image("`uwi_crest'"), halign(center)
putpdf table cover(3,1) = (" ")
putpdf table cover(4,1) = ("BARBADOS NATIONAL REGISTRY"), ///
    halign(center) font("`font_title'", 10, "`bnr_teal'")
putpdf table cover(5,1) = ("Annual cardiovascular disease report"), ///
    halign(center) bold font("`font_title'", 24, "`bnr_ink'")
putpdf table cover(6,1) = ("`report_year4'"), ///
    halign(center) bold font("`font_title'", 30, "`bnr_ink'")
putpdf table cover(7,1) = ("Cardiovascular disease events and mortality in Barbados"), ///
    halign(center) font("`font_body'", 11, "`bnr_muted'")
putpdf table cover(8,1) = (" ")
putpdf table cover(9,1) = ("The University of the West Indies | Cave Hill Campus"), ///
    halign(center) font("`font_body'", 8, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 5. Year in brief - one-page visual summary
* -----------------------------------------------------------------------------

* Four five-year mini-trends. They deliberately carry almost no graph furniture:
* the statistic card supplies the label and value; the sparkline supplies shape.
local yib_event_count_fig "`annual_figure_dir'/yib_event_count.png"
local yib_event_rate_fig  "`annual_figure_dir'/yib_event_rate.png"
local yib_death_count_fig "`annual_figure_dir'/yib_death_count.png"
local yib_death_rate_fig  "`annual_figure_dir'/yib_death_rate.png"

use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & ///
    event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
    ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & ///
    statistic == "annual_count" & period_complete == 1
quietly count
if r(N) >= 2 {
    twoway connected value period_year, sort ///
        lcolor("`bnr_teal'") mcolor("`bnr_teal'") ///
        lwidth(medthick) msymbol(O) msize(tiny) ///
        graphregion(color("`bnr_pale2'") margin(zero)) ///
        plotregion(color("`bnr_pale2'") margin(vsmall)) ///
        xlabel(`first_table_year' `report_year_num', labsize(tiny) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) ///
        xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(off) ///
        xsize(3.0) ysize(1.0)
    graph export "`yib_event_count_fig'", replace width(1200)
}

use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & ///
    event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & ///
    ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & ///
    statistic == "annual_age_standardised_rate" & period_complete == 1
quietly count
if r(N) >= 2 {
    twoway connected value period_year, sort ///
        lcolor("`bnr_primary'") mcolor("`bnr_primary'") ///
        lwidth(medthick) msymbol(O) msize(tiny) ///
        graphregion(color("`bnr_pale2'") margin(zero)) ///
        plotregion(color("`bnr_pale2'") margin(vsmall)) ///
        xlabel(`first_table_year' `report_year_num', labsize(tiny) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) ///
        xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(off) ///
        xsize(3.0) ysize(1.0)
    graph export "`yib_event_rate_fig'", replace width(1200)
}

use "`annual_mortality_data'", clear
keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & ///
    event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
    case_definition == "primary_clear_likely" & statistic == "annual_count" & ///
    period_complete == 1
quietly count
if r(N) >= 2 {
    twoway connected value period_year, sort ///
        lcolor("`bnr_heart'") mcolor("`bnr_heart'") ///
        lwidth(medthick) msymbol(O) msize(tiny) ///
        graphregion(color("`bnr_pale2'") margin(zero)) ///
        plotregion(color("`bnr_pale2'") margin(vsmall)) ///
        xlabel(`first_table_year' `report_year_num', labsize(tiny) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) ///
        xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(off) ///
        xsize(3.0) ysize(1.0)
    graph export "`yib_death_count_fig'", replace width(1200)
}

use "`annual_mortality_data'", clear
keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & ///
    event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & ///
    case_definition == "primary_clear_likely" & statistic == "annual_age_standardised_rate" & ///
    period_complete == 1
quietly count
if r(N) >= 2 {
    twoway connected value period_year, sort ///
        lcolor("`bnr_secondary'") mcolor("`bnr_secondary'") ///
        lwidth(medthick) msymbol(O) msize(tiny) ///
        graphregion(color("`bnr_pale2'") margin(zero)) ///
        plotregion(color("`bnr_pale2'") margin(vsmall)) ///
        xlabel(`first_table_year' `report_year_num', labsize(tiny) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) ///
        xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(off) ///
        xsize(3.0) ysize(1.0)
    graph export "`yib_death_rate_fig'", replace width(1200)
}

putpdf pagebreak
putpdf paragraph, font("`font_body'", 1)
putpdf text ("`report_year4' in brief"), bold font("`font_title'", 20, "`bnr_ink'") linebreak
putpdf text ("The latest complete year at a glance"), ///
    font("`font_body'", 9, "`bnr_muted'")

* Each statistic occupies a small briefing-style card with its own five-year
* sparkline. The table is a layout grid, not a data table.
putpdf table yib_cards = (8,2), width(100%) border(all, nil)
putpdf table yib_cards(.,.), bgcolor("`bnr_pale2'")

putpdf table yib_cards(1,1) = ("CVD EVENTS"), ///
    bold font("`font_title'", 7.5, "`bnr_teal'")
putpdf table yib_cards(1,2) = ("CVD EVENT RATE"), ///
    bold font("`font_title'", 7.5, "`bnr_teal'")
putpdf table yib_cards(2,1) = ("`yib_event_count'"), ///
    bold font("`font_title'", 18, "`bnr_ink'")
putpdf table yib_cards(2,2) = ("`yib_event_rate' per 100,000"), ///
    bold font("`font_title'", 18, "`bnr_ink'")
putpdf table yib_cards(3,1) = ("Primary national estimate"), ///
    font("`font_body'", 7.5, "`bnr_muted'")
putpdf table yib_cards(3,2) = ("Primary age-standardised | `yib_event_rate_ci'"), ///
    font("`font_body'", 7.5, "`bnr_muted'")

capture confirm file "`yib_event_count_fig'"
if !_rc {
    putpdf table yib_cards(4,1) = image("`yib_event_count_fig'")
}
else {
    putpdf table yib_cards(4,1) = ("Trend unavailable"), ///
        font("`font_body'", 7, "`bnr_muted'")
}
capture confirm file "`yib_event_rate_fig'"
if !_rc {
    putpdf table yib_cards(4,2) = image("`yib_event_rate_fig'")
}
else {
    putpdf table yib_cards(4,2) = ("Trend unavailable"), ///
        font("`font_body'", 7, "`bnr_muted'")
}

putpdf table yib_cards(5,1) = ("CVD DEATHS"), ///
    bold font("`font_title'", 7.5, "`bnr_heart'")
putpdf table yib_cards(5,2) = ("CVD MORTALITY RATE"), ///
    bold font("`font_title'", 7.5, "`bnr_secondary'")
putpdf table yib_cards(6,1) = ("`yib_death_count'"), ///
    bold font("`font_title'", 18, "`bnr_ink'")
putpdf table yib_cards(6,2) = ("`yib_death_rate' per 100,000"), ///
    bold font("`font_title'", 18, "`bnr_ink'")
putpdf table yib_cards(7,1) = ("Primary definition"), ///
    font("`font_body'", 7.5, "`bnr_muted'")
putpdf table yib_cards(7,2) = ("Primary age-standardised | `yib_death_rate_ci'"), ///
    font("`font_body'", 7.5, "`bnr_muted'")

capture confirm file "`yib_death_count_fig'"
if !_rc {
    putpdf table yib_cards(8,1) = image("`yib_death_count_fig'")
}
else {
    putpdf table yib_cards(8,1) = ("Trend unavailable"), ///
        font("`font_body'", 7, "`bnr_muted'")
}
capture confirm file "`yib_death_rate_fig'"
if !_rc {
    putpdf table yib_cards(8,2) = image("`yib_death_rate_fig'")
}
else {
    putpdf table yib_cards(8,2) = ("Trend unavailable"), ///
        font("`font_body'", 7, "`bnr_muted'")
}

* Reapply the intended card background after all cell content has been written.
* This prevents putpdf cell assignments from leaving white strips behind text.
putpdf table yib_cards(1/3,.), bgcolor("`bnr_pale2'")
putpdf table yib_cards(5/7,.), bgcolor("`bnr_pale2'")

putpdf paragraph, font("`font_body'", 1)
putpdf text ("How complete is the picture?"), ///
    bold font("`font_title'", 10.5, "`bnr_ink'")

putpdf table yib_quality = (3,2), width(100%) border(all, nil)
putpdf table yib_quality(.,.), bgcolor("`bnr_pale'")
putpdf table yib_quality(1,1) = ("Events identified through death records"), ///
    bold font("`font_title'", 7.5, "`bnr_teal'")
putpdf table yib_quality(1,2) = ("Possible CVD deaths"), ///
    bold font("`font_title'", 7.5, "`bnr_primary'")
putpdf table yib_quality(2,1) = ("`yib_event_dco_share'"), ///
    bold font("`font_title'", 15, "`bnr_ink'")
putpdf table yib_quality(2,2) = ("`yib_possible_share'"), ///
    bold font("`font_title'", 15, "`bnr_ink'")
putpdf table yib_quality(3,1) = ("of the Primary national event estimate"), ///
    font("`font_body'", 7.2, "`bnr_muted'")
putpdf table yib_quality(3,2) = ("of the Inclusive mortality estimate"), ///
    font("`font_body'", 7.2, "`bnr_muted'")
putpdf table yib_quality(.,.), bgcolor("`bnr_pale'")

putpdf paragraph, font("`font_body'", 1)
putpdf text ("What stood out in `report_year4'?"), ///
    bold font("`font_title'", 10.5, "`bnr_ink'")

putpdf table yib_messages = (3,12), width(100%) border(all, nil)
forvalues rr = 1/3 {
    putpdf table yib_messages(`rr',1)
    putpdf table yib_messages(`rr',2), colspan(11)
    putpdf table yib_messages(`rr',1) = ("0`rr'"), ///
        halign(center) bold font("`font_title'", 9, "`bnr_teal'") ///
        bgcolor("`bnr_pale2'")
}
putpdf table yib_messages(1,2) = ("`annual_summary_message_1'"), ///
    font("`font_body'", 7.5, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table yib_messages(2,2) = ("`annual_summary_message_2'"), ///
    font("`font_body'", 7.5, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table yib_messages(3,2) = ("`annual_summary_message_3'"), ///
    font("`font_body'", 7.5, "`bnr_ink'") bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 6. CVD events - C1 How many CVD events?
* -----------------------------------------------------------------------------

local fig_c1 "`annual_figure_dir'/event_count_trends.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
    event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
    period_complete == 1 & ///
    ((ascertainment_scope == "hospital_only" & statistic == "annual_count") | ///
     (ascertainment_scope == "hospital_only" & statistic == "annual_previous_5yr_mean") | ///
     (ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_count") | ///
     (ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive" & statistic == "annual_count"))
quietly count
if r(N) > 0 {
    twoway ///
      (rarea linkage_lower_value linkage_upper_value period_year if ///
          ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", ///
          sort color("`bnr_primary'%08") lcolor(none)) ///
      (rarea linkage_lower_value linkage_upper_value period_year if ///
          ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          sort color("`bnr_teal'%18") lcolor(none)) ///
      (connected value period_year if ascertainment_scope == "hospital_only" & statistic == "annual_count", ///
          sort lcolor("`bnr_muted'%75") mcolor("`bnr_muted'%75") msymbol(O) msize(vsmall) lwidth(medium)) ///
      (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          sort lcolor("`bnr_teal'") mcolor("`bnr_teal'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", ///
          sort lcolor("`bnr_primary'%85") mcolor("`bnr_primary'%85") msymbol(O) msize(vsmall) lpattern(dash) lwidth(medthick)) ///
      (line value period_year if ascertainment_scope == "hospital_only" & statistic == "annual_previous_5yr_mean", ///
          sort lcolor("`bnr_secondary'%70") lpattern(shortdash) lwidth(thin)), ///
      graphregion(color(white) margin(vsmall)) ///
      plotregion(color(white) margin(vsmall)) ///
      xlabel(#4, format(%4.0f) labsize(small) noticks nogrid) ///
      ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") ///
      legend(order(3 "Hospital-recorded" 4 "Primary national" ///
          5 "Inclusive national" 6 "Previous 5-year mean") ///
          cols(4) size(vsmall) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.35)
    graph export "`fig_c1'", replace width(2800)
}

* Latest headline values.
local c1_hospital "-"
local c1_primary "-"
local c1_inclusive "-"
use "`annual_event_data'", clear
foreach spec in hospital primary inclusive {
    preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & event_type == "all_cvd" & ///
            sex == "all" & age_group == "all" & statistic == "annual_count"
        if "`spec'" == "hospital" ///
            keep if ascertainment_scope == "hospital_only"
        if "`spec'" == "primary" ///
            keep if ascertainment_scope == "hospital_plus_dco" & ///
                mortality_definition == "primary"
        if "`spec'" == "inclusive" ///
            keep if ascertainment_scope == "hospital_plus_dco" & ///
                mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local tmp : display %9.1fc value[1]
            local c1_`spec' = strtrim("`tmp'")
        }
    restore
}

putpdf pagebreak
putpdf paragraph, font("`font_body'", 1)
putpdf text ("01  CVD EVENTS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'") linebreak
putpdf text ("How many CVD events?"), ///
    bold font("`font_title'", 18, "`bnr_ink'") linebreak
putpdf text ("Hospital-recorded events and national estimates across the full published annual series."), ///
    font("`font_body'", 8.5, "`bnr_muted'")

putpdf paragraph, font("`font_body'", 1)
putpdf table c1_cards = (2,3), width(100%) border(all, nil)
putpdf table c1_cards(1,1) = ("Hospital-recorded")
putpdf table c1_cards(1,2) = ("Primary national estimate")
putpdf table c1_cards(1,3) = ("Inclusive national estimate")
putpdf table c1_cards(2,1) = ("`c1_hospital'")
putpdf table c1_cards(2,2) = ("`c1_primary'")
putpdf table c1_cards(2,3) = ("`c1_inclusive'")
putpdf table c1_cards(1,.), ///
    bold font("`font_title'", 7.4, "`bnr_muted'") bgcolor("`bnr_pale2'")
putpdf table c1_cards(2,.), ///
    bold font("`font_title'", 15, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table c1_cards(.,.), bgcolor("`bnr_pale'")

putpdf paragraph, font("`font_body'", 1)
putpdf text ("CVD event counts over time"), ///
    bold font("`font_title'", 10.5, "`bnr_ink'")

capture confirm file "`fig_c1'"
if !_rc {
    putpdf table c1_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table c1_fig(1,1) = image("`fig_c1'")
}
putpdf paragraph, font("`font_body'", 1)
putpdf text ("The pale region is the published DCO linkage range around the Primary national estimate. The previous-five-year mean is a descriptive reference, not a control limit."), ///
    font("`font_body_light'", 7, "`bnr_muted'")

putpdf paragraph, font("`font_body'", 1)
putpdf text ("Latest five complete years"), ///
    bold font("`font_title'", 9.5, "`bnr_ink'")

putpdf table c1_tab = (5,6), width(100%) border(all, nil)
putpdf table c1_tab(1,1) = ("Measure")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table c1_tab(1,`cc') = ("`yy'")
}
local c1row = 1
foreach spec in hospital primary inclusive comparator {
    local ++c1row
    local label "Hospital-recorded"
    if "`spec'" == "primary" local label "Primary national estimate"
    if "`spec'" == "inclusive" local label "Inclusive national estimate"
    if "`spec'" == "comparator" local label "Previous 5-year mean"
    putpdf table c1_tab(`c1row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_event_data'", clear
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
            period_year == `yy' & event_type == "all_cvd" & ///
            sex == "all" & age_group == "all"
        if "`spec'" == "hospital" ///
            keep if ascertainment_scope == "hospital_only" & ///
                statistic == "annual_count"
        if "`spec'" == "primary" ///
            keep if ascertainment_scope == "hospital_plus_dco" & ///
                mortality_definition == "primary" & statistic == "annual_count"
        if "`spec'" == "inclusive" ///
            keep if ascertainment_scope == "hospital_plus_dco" & ///
                mortality_definition == "inclusive" & statistic == "annual_count"
        if "`spec'" == "comparator" ///
            keep if ascertainment_scope == "hospital_only" & ///
                statistic == "annual_previous_5yr_mean"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.1fc value[1]
            local cell = strtrim("`tmp'")
        }
        putpdf table c1_tab(`c1row',`cc') = ("`cell'")
    }
}
putpdf table c1_tab(.,.), font("`font_body'", 7.3)
putpdf table c1_tab(1,.), bold font("`font_title'", 7.2, "`bnr_ink'") ///
    bgcolor("`bnr_pale'")
putpdf table c1_tab(.,1), bold
putpdf table c1_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table c1_tab(2/5,6), bold

putpdf paragraph, font("`font_body'", 1)
putpdf table c1_note = (2,1), width(100%) border(all, nil)
putpdf table c1_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table c1_note(2,1) = ("`ann_evt_counts_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table c1_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 7. CVD events - C1b How the year unfolded
* -----------------------------------------------------------------------------

local fig_c1q "`annual_figure_dir'/event_quarterly_2025.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "quarterly" & ///
    period_year == `report_year_num' & event_type == "all_cvd" & sex == "all" & ///
    age_group == "all" & ascertainment_scope == "hospital_only" & ///
    inlist(statistic, "quarterly_count", "quarterly_same_quarter_previous_5yr_mean")
quietly count
if r(N) > 0 {
    twoway ///
      (connected value period_quarter if statistic == "quarterly_count" & period_complete == 1, ///
          sort lcolor("`bnr_teal'") mcolor("`bnr_teal'") msymbol(O) msize(small) lwidth(thick)) ///
      (line value period_quarter if statistic == "quarterly_same_quarter_previous_5yr_mean", ///
          sort lcolor("`bnr_secondary'%80") lpattern(shortdash) lwidth(medium)), ///
      graphregion(color(white) margin(vsmall)) plotregion(color(white) margin(vsmall)) ///
      xlabel(1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4", labsize(small) noticks nogrid) ///
      ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) xtitle("") ytitle("") ///
      legend(order(1 "`report_year4'" 2 "Previous 5-year same-quarter mean") ///
          cols(2) size(vsmall) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.0)
    graph export "`fig_c1q'", replace width(2800)
}

putpdf pagebreak
putpdf paragraph
putpdf text ("How the year unfolded"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Quarterly hospital-recorded All-CVD event counts in `report_year4', compared with the published mean for the same quarter in the previous five years."), ///
    font("`font_body'", 8, "`bnr_muted'")
capture confirm file "`fig_c1q'"
if !_rc {
    putpdf table c1q_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table c1q_fig(1,1) = image("`fig_c1q'")
}
putpdf table c1q_tab = (3,5), width(100%) border(all, nil)
putpdf table c1q_tab(1,1) = ("Measure")
forvalues q = 1/4 {
    local cc = `q' + 1
    putpdf table c1q_tab(1,`cc') = ("Q`q'")
}
putpdf table c1q_tab(2,1) = ("`report_year4' hospital-recorded")
putpdf table c1q_tab(3,1) = ("Previous 5-year same-quarter mean")
forvalues q = 1/4 {
    local cc = `q' + 1
    local obs "-"
    local cmp "-"
    use "`annual_event_data'", clear
    keep if metric_id == "CVD-BURDEN-001" & period_type == "quarterly" & ///
        period_year == `report_year_num' & period_quarter == `q' & event_type == "all_cvd" & ///
        sex == "all" & age_group == "all" & ascertainment_scope == "hospital_only"
    quietly summarize value if statistic == "quarterly_count" & period_complete == 1, meanonly
    if r(N) == 1 {
        local tmp : display %8.0fc r(mean)
        local obs = strtrim("`tmp'")
    }
    quietly summarize value if statistic == "quarterly_same_quarter_previous_5yr_mean", meanonly
    if r(N) == 1 {
        local tmp : display %8.1fc r(mean)
        local cmp = strtrim("`tmp'")
    }
    putpdf table c1q_tab(2,`cc') = ("`obs'")
    putpdf table c1q_tab(3,`cc') = ("`cmp'")
}
putpdf table c1q_tab(.,.), font("`font_body'", 7.6)
putpdf table c1q_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c1q_tab(.,1), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table c1q_note = (2,1), width(100%) border(all, nil)
putpdf table c1q_note(1,1) = ("HOW TO READ THIS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table c1q_note(2,1) = ("This view adds within-year timing to the annual result. It uses hospital-recorded events because DCO-enhanced national event estimates are annual only; it should therefore be read alongside, not substituted for, the annual national estimate."), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table c1q_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 8. CVD events - C2 Event rates
* -----------------------------------------------------------------------------

local fig_c2 "`annual_figure_dir'/event_rate_trends.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
    statistic == "annual_age_standardised_rate" & event_type == "all_cvd" & ///
    sex == "all" & age_group == "age_standardised" & period_complete == 1 & ///
    ((ascertainment_scope == "hospital_only") | ///
     (ascertainment_scope == "hospital_plus_dco" & inlist(mortality_definition, "primary", "inclusive")))
quietly count
if r(N) > 0 {
    twoway ///
      (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", ///
          sort color("`bnr_primary'%07") lcolor(none)) ///
      (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          sort color("`bnr_teal'%13") lcolor(none)) ///
      (rcap ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_only", ///
          lcolor("`bnr_muted'%35") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          lcolor("`bnr_teal'%45") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", ///
          lcolor("`bnr_primary'%35") lwidth(vthin)) ///
      (connected value period_year if ascertainment_scope == "hospital_only", sort lcolor("`bnr_muted'") mcolor("`bnr_muted'") msymbol(O) msize(vsmall) lwidth(medthick)) ///
      (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", sort lcolor("`bnr_teal'") mcolor("`bnr_teal'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", sort lcolor("`bnr_primary'") mcolor("`bnr_primary'") msymbol(O) msize(vsmall) lpattern(dash) lwidth(medthick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") ///
      legend(order(6 "Hospital-recorded" 7 "Primary national" 8 "Inclusive national") cols(3) size(vsmall) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.25)
    graph export "`fig_c2'", replace width(2400)
}

putpdf pagebreak
putpdf paragraph
putpdf text ("CVD event rates"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Age-standardised rates per 100,000. National series show published DCO linkage uncertainty; all rate series show their published 95% statistical confidence intervals."), font("`font_body'", 8, "`bnr_muted'")

local c2_hospital "-"
local c2_primary "-"
local c2_inclusive "-"
use "`annual_event_data'", clear
foreach spec in hospital primary inclusive {
    preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
        if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
        if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
        if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local c2_`spec' = strtrim("`tmp'")
        }
    restore
}
putpdf table c2_cards = (2,3), width(100%) border(all, nil)
putpdf table c2_cards(1,1) = ("Hospital-recorded ASR")
putpdf table c2_cards(1,2) = ("Primary national ASR")
putpdf table c2_cards(1,3) = ("Inclusive national ASR")
putpdf table c2_cards(2,1) = ("`c2_hospital'")
putpdf table c2_cards(2,2) = ("`c2_primary'")
putpdf table c2_cards(2,3) = ("`c2_inclusive'")
putpdf table c2_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c2_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table c2_cards(.,.), bgcolor("`bnr_pale'")

capture confirm file "`fig_c2'"
if !_rc {
    putpdf table c2_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table c2_fig(1,1) = image("`fig_c2'")
}
putpdf paragraph
putpdf text ("Figure 2. Annual age-standardised CVD event rates. Pale shaded regions show published DCO linkage uncertainty for the national series; thin whiskers show published 95% statistical confidence intervals."), font("`font_body'", 7, "`bnr_muted'")

putpdf table c2_tab = (4,6), width(100%) border(all, nil)
putpdf table c2_tab(1,1) = ("Rate (95% CI)")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table c2_tab(1,`cc') = ("`yy'")
}
local c2row = 1
foreach spec in hospital primary inclusive {
    local ++c2row
    local label "Hospital-recorded"
    if "`spec'" == "primary" local label "Primary national"
    if "`spec'" == "inclusive" local label "Inclusive national"
    putpdf table c2_tab(`c2row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_event_data'", clear
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `yy' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
        if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
        if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
        if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local est : display %6.1f value[1]
            local est = strtrim("`est'")
            local cell "`est'"
            if !missing(ci_lower_value[1], ci_upper_value[1]) {
                local lo : display %6.1f ci_lower_value[1]
                local hi : display %6.1f ci_upper_value[1]
                local cell "`est' (`=strtrim("`lo'")'-`=strtrim("`hi'")')"
            }
        }
        putpdf table c2_tab(`c2row',`cc') = ("`cell'")
    }
}
putpdf table c2_tab(.,.), font("`font_body'", 6.9)
putpdf table c2_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c2_tab(.,1), bold
putpdf table c2_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table c2_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table c2_note = (2,1), width(100%) border(all, nil)
putpdf table c2_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table c2_note(2,1) = ("`ann_evt_rates_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table c2_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 8. CVD events - C3 Heart and Stroke
* -----------------------------------------------------------------------------

local fig_c3 "`annual_figure_dir'/event_rate_heart_stroke.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & ///
    inlist(event_type, "heart", "stroke") & sex == "all" & age_group == "age_standardised" & ///
    ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & period_complete == 1
quietly count
if r(N) > 0 {
    twoway ///
      (rarea linkage_lower_value linkage_upper_value period_year if event_type == "heart", sort color("`bnr_heart'%10") lcolor(none)) ///
      (rarea linkage_lower_value linkage_upper_value period_year if event_type == "stroke", sort color("`bnr_stroke'%10") lcolor(none)) ///
      (rcap ci_lower_value ci_upper_value period_year if event_type == "heart", lcolor("`bnr_heart'%45") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if event_type == "stroke", lcolor("`bnr_stroke'%45") lwidth(vthin)) ///
      (connected value period_year if event_type == "heart", sort lcolor("`bnr_heart'") mcolor("`bnr_heart'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if event_type == "stroke", sort lcolor("`bnr_stroke'") mcolor("`bnr_stroke'") msymbol(O) msize(vsmall) lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(order(5 "Heart" 6 "Stroke") cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.25)
    graph export "`fig_c3'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Heart and Stroke"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary national age-standardised event rates per 100,000."), font("`font_body'", 8, "`bnr_muted'")

local c3_all "`c2_primary'"
local c3_heart "-"
local c3_stroke "-"
use "`annual_event_data'", clear
foreach event in heart stroke {
    preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "`event'" & sex == "all" & age_group == "age_standardised" & ///
            ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local c3_`event' = strtrim("`tmp'")
        }
    restore
}
putpdf table c3_cards = (2,3), width(100%) border(all, nil)
putpdf table c3_cards(1,1) = ("All CVD")
putpdf table c3_cards(1,2) = ("Heart")
putpdf table c3_cards(1,3) = ("Stroke")
putpdf table c3_cards(2,1) = ("`c3_all'")
putpdf table c3_cards(2,2) = ("`c3_heart'")
putpdf table c3_cards(2,3) = ("`c3_stroke'")
putpdf table c3_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c3_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table c3_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_c3'"
if !_rc {
    putpdf table c3_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table c3_fig(1,1) = image("`fig_c3'")
}

putpdf table c3_tab = (4,6), width(100%) border(all, nil)
putpdf table c3_tab(1,1) = ("Primary ASR (95% CI)")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table c3_tab(1,`cc') = ("`yy'")
}
local c3row = 1
foreach event in all_cvd heart stroke {
    local ++c3row
    local label "All CVD"
    if "`event'" == "heart" local label "Heart"
    if "`event'" == "stroke" local label "Stroke"
    putpdf table c3_tab(`c3row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_event_data'", clear
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & ///
            sex == "all" & age_group == "age_standardised" & ascertainment_scope == "hospital_plus_dco" & ///
            mortality_definition == "primary" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local est : display %5.1f value[1]
            local lo : display %5.1f ci_lower_value[1]
            local hi : display %5.1f ci_upper_value[1]
            local cell "`=strtrim("`est'")' (`=strtrim("`lo'")'-`=strtrim("`hi'")')"
        }
        putpdf table c3_tab(`c3row',`cc') = ("`cell'")
    }
}
putpdf table c3_tab(.,.), font("`font_body'", 6.9)
putpdf table c3_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c3_tab(.,1), bold
putpdf table c3_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table c3_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table c3_note = (2,1), width(100%) border(all, nil)
putpdf table c3_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table c3_note(2,1) = ("`ann_evt_type_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table c3_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 9. CVD events - C4 Women and men
* -----------------------------------------------------------------------------

local fig_c4 "`annual_figure_dir'/event_rate_by_sex.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & ///
    event_type == "all_cvd" & inlist(sex, "female", "male") & age_group == "age_standardised" & ///
    ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & period_complete == 1
quietly count
if r(N) > 0 {
    twoway ///
      (rarea linkage_lower_value linkage_upper_value period_year if sex == "female", sort color("`bnr_women'%10") lcolor(none)) ///
      (rarea linkage_lower_value linkage_upper_value period_year if sex == "male", sort color("`bnr_men'%10") lcolor(none)) ///
      (rcap ci_lower_value ci_upper_value period_year if sex == "female", lcolor("`bnr_women'%45") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if sex == "male", lcolor("`bnr_men'%45") lwidth(vthin)) ///
      (connected value period_year if sex == "female", sort lcolor("`bnr_women'") mcolor("`bnr_women'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if sex == "male", sort lcolor("`bnr_men'") mcolor("`bnr_men'") msymbol(O) msize(vsmall) lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(order(5 "Women" 6 "Men") cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.25)
    graph export "`fig_c4'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Women and men"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary national age-standardised event rates per 100,000."), font("`font_body'", 8, "`bnr_muted'")
local c4_all "`c2_primary'"
local c4_female "-"
local c4_male "-"
use "`annual_event_data'", clear
foreach sex in female male {
    preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "`sex'" & age_group == "age_standardised" & ///
            ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local c4_`sex' = strtrim("`tmp'")
        }
    restore
}
putpdf table c4_cards = (2,3), width(100%) border(all, nil)
putpdf table c4_cards(1,1) = ("Both sexes")
putpdf table c4_cards(1,2) = ("Women")
putpdf table c4_cards(1,3) = ("Men")
putpdf table c4_cards(2,1) = ("`c4_all'")
putpdf table c4_cards(2,2) = ("`c4_female'")
putpdf table c4_cards(2,3) = ("`c4_male'")
putpdf table c4_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c4_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table c4_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_c4'"
if !_rc {
    putpdf table c4_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table c4_fig(1,1) = image("`fig_c4'")
}

putpdf table c4_tab = (4,6), width(100%) border(all, nil)
putpdf table c4_tab(1,1) = ("Primary ASR (95% CI)")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table c4_tab(1,`cc') = ("`yy'")
}
local c4row = 1
foreach sex in all female male {
    local ++c4row
    local label "Both sexes"
    if "`sex'" == "female" local label "Women"
    if "`sex'" == "male" local label "Men"
    putpdf table c4_tab(`c4row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_event_data'", clear
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `yy' & event_type == "all_cvd" & ///
            sex == "`sex'" & age_group == "age_standardised" & ascertainment_scope == "hospital_plus_dco" & ///
            mortality_definition == "primary" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local est : display %5.1f value[1]
            local lo : display %5.1f ci_lower_value[1]
            local hi : display %5.1f ci_upper_value[1]
            local cell "`=strtrim("`est'")' (`=strtrim("`lo'")'-`=strtrim("`hi'")')"
        }
        putpdf table c4_tab(`c4row',`cc') = ("`cell'")
    }
}
putpdf table c4_tab(.,.), font("`font_body'", 6.9)
putpdf table c4_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c4_tab(.,1), bold
putpdf table c4_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table c4_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table c4_note = (2,1), width(100%) border(all, nil)
putpdf table c4_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table c4_note(2,1) = ("`ann_evt_sex_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table c4_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 10. CVD events - C5 Age patterns
* -----------------------------------------------------------------------------

local fig_c5 "`annual_figure_dir'/event_age_counts.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & statistic == "annual_count" & ///
    event_type == "all_cvd" & sex == "all" & inlist(age_group, "under_70", "age_70_plus") & ///
    ascertainment_scope == "hospital_only" & period_complete == 1
quietly count
if r(N) > 0 {
    keep period_year age_group value
    reshape wide value, i(period_year) j(age_group) string
    label variable valueunder_70 "Under 70"
    label variable valueage_70_plus "70 and older"
    graph bar valueunder_70 valueage_70_plus, ///
        over(period_year, label(angle(45) labsize(tiny))) stack ///
        bar(1, color("`bnr_under70'%82")) ///
        bar(2, color("`bnr_70plus'%82")) ///
        graphregion(color(white) margin(vsmall)) ///
        plotregion(color(white) margin(vsmall)) ///
        ytitle("") ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        yscale(noline) ///
        legend(cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
        xsize(8.0) ysize(3.15)
    graph export "`fig_c5'", replace width(2800)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Age patterns"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Hospital-recorded annual event counts by broad age group. These are composition counts, not age-specific rates."), font("`font_body'", 8, "`bnr_muted'")
local c5_all "-"
local c5_under "-"
local c5_old "-"
use "`annual_event_data'", clear
foreach age in all under_70 age_70_plus {
    preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "`age'" & ascertainment_scope == "hospital_only" & statistic == "annual_count"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            if "`age'" == "all" local c5_all = strtrim("`tmp'")
            if "`age'" == "under_70" local c5_under = strtrim("`tmp'")
            if "`age'" == "age_70_plus" local c5_old = strtrim("`tmp'")
        }
    restore
}
putpdf table c5_cards = (2,3), width(100%) border(all, nil)
putpdf table c5_cards(1,1) = ("All ages")
putpdf table c5_cards(1,2) = ("Under 70")
putpdf table c5_cards(1,3) = ("70 and older")
putpdf table c5_cards(2,1) = ("`c5_all'")
putpdf table c5_cards(2,2) = ("`c5_under'")
putpdf table c5_cards(2,3) = ("`c5_old'")
putpdf table c5_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c5_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table c5_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_c5'"
if !_rc {
    putpdf table c5_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table c5_fig(1,1) = image("`fig_c5'")
}

putpdf table c5_tab = (4,6), width(100%) border(all, nil)
putpdf table c5_tab(1,1) = ("Hospital-recorded events")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table c5_tab(1,`cc') = ("`yy'")
}
local c5row = 1
foreach age in all under_70 age_70_plus {
    local ++c5row
    local label "All ages"
    if "`age'" == "under_70" local label "Under 70"
    if "`age'" == "age_70_plus" local label "70 and older"
    putpdf table c5_tab(`c5row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_event_data'", clear
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & period_year == `yy' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "`age'" & ascertainment_scope == "hospital_only" & statistic == "annual_count"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            local cell = strtrim("`tmp'")
        }
        putpdf table c5_tab(`c5row',`cc') = ("`cell'")
    }
}
putpdf table c5_tab(.,.), font("`font_body'", 7.4)
putpdf table c5_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c5_tab(.,1), bold
putpdf table c5_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table c5_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table c5_note = (2,1), width(100%) border(all, nil)
putpdf table c5_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table c5_note(2,1) = ("`ann_evt_age_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table c5_note(.,.), bgcolor("`bnr_pale2'")
putpdf paragraph
putpdf text ("Source: BNR public CVD-event release `event_release'."), font("`font_body'", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 11. Mortality - D1 How many CVD deaths?
* -----------------------------------------------------------------------------

local fig_d1 "`annual_figure_dir'/mortality_count_trends.png"
use "`annual_mortality_data'", clear
keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & event_type == "all_cvd" & ///
    sex == "all" & age_group == "all" & period_complete == 1 & ///
    inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible") & ///
    inlist(statistic, "annual_count", "annual_previous_5yr_mean")
quietly count
if r(N) > 0 {
    twoway ///
      (connected value period_year if case_definition == "primary_clear_likely" & statistic == "annual_count", sort lcolor("`bnr_teal'") mcolor("`bnr_teal'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if case_definition == "upper_clear_likely_possible" & statistic == "annual_count", sort lcolor("`bnr_primary'") mcolor("`bnr_primary'") msymbol(O) msize(vsmall) lpattern(dash) lwidth(medthick)) ///
      (line value period_year if case_definition == "primary_clear_likely" & statistic == "annual_previous_5yr_mean", sort lcolor("`bnr_secondary'") lpattern(shortdash) lwidth(thin)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(order(1 "Primary" 2 "Inclusive" 3 "Primary previous 5-year mean") cols(3) size(vsmall) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.3)
    graph export "`fig_d1'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("2 | CVD mortality"), bold font("`font_title'", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("How many CVD deaths?"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary = Clear + Likely CVD deaths. Inclusive = Clear + Likely + Possible CVD deaths."), font("`font_body'", 8, "`bnr_muted'")
local d1_primary "-"
local d1_inclusive "-"
local d1_avg "-"
use "`annual_mortality_data'", clear
foreach spec in primary inclusive avg {
    preserve
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "all"
        if "`spec'" == "primary" keep if case_definition == "primary_clear_likely" & statistic == "annual_count"
        if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible" & statistic == "annual_count"
        if "`spec'" == "avg" keep if case_definition == "primary_clear_likely" & statistic == "annual_previous_5yr_mean"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.1fc value[1]
            local d1_`spec' = strtrim("`tmp'")
        }
    restore
}
putpdf table d1_cards = (2,3), width(100%) border(all, nil)
putpdf table d1_cards(1,1) = ("Primary deaths")
putpdf table d1_cards(1,2) = ("Inclusive deaths")
putpdf table d1_cards(1,3) = ("Primary previous 5-year mean")
putpdf table d1_cards(2,1) = ("`d1_primary'")
putpdf table d1_cards(2,2) = ("`d1_inclusive'")
putpdf table d1_cards(2,3) = ("`d1_avg'")
putpdf table d1_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d1_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table d1_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_d1'"
if !_rc {
    putpdf table d1_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table d1_fig(1,1) = image("`fig_d1'")
}

putpdf table d1_tab = (4,6), width(100%) border(all, nil)
putpdf table d1_tab(1,1) = ("Measure")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table d1_tab(1,`cc') = ("`yy'")
}
local d1row = 1
foreach spec in primary inclusive comparator {
    local ++d1row
    local label "Primary"
    if "`spec'" == "inclusive" local label "Inclusive"
    if "`spec'" == "comparator" local label "Primary previous 5-year mean"
    putpdf table d1_tab(`d1row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_mortality_data'", clear
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `yy' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "all"
        if "`spec'" == "primary" keep if case_definition == "primary_clear_likely" & statistic == "annual_count"
        if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible" & statistic == "annual_count"
        if "`spec'" == "comparator" keep if case_definition == "primary_clear_likely" & statistic == "annual_previous_5yr_mean"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.1fc value[1]
            local cell = strtrim("`tmp'")
        }
        putpdf table d1_tab(`d1row',`cc') = ("`cell'")
    }
}
putpdf table d1_tab(.,.), font("`font_body'", 7.3)
putpdf table d1_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d1_tab(.,1), bold
putpdf table d1_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table d1_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table d1_note = (2,1), width(100%) border(all, nil)
putpdf table d1_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table d1_note(2,1) = ("`ann_mort_counts_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table d1_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 12. Mortality - D2 Mortality rates
* -----------------------------------------------------------------------------

local fig_d2 "`annual_figure_dir'/mortality_rate_definitions.png"
use "`annual_mortality_data'", clear
keep if metric_id == "MORT-RATE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & ///
    event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & period_complete == 1 & ///
    inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
quietly count
if r(N) > 0 {
    twoway ///
      (rcap ci_lower_value ci_upper_value period_year if case_definition == "primary_clear_likely", lcolor("`bnr_teal'%45") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if case_definition == "upper_clear_likely_possible", lcolor("`bnr_primary'%35") lwidth(vthin)) ///
      (connected value period_year if case_definition == "primary_clear_likely", sort lcolor("`bnr_teal'") mcolor("`bnr_teal'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if case_definition == "upper_clear_likely_possible", sort lcolor("`bnr_primary'") mcolor("`bnr_primary'") msymbol(O) msize(vsmall) lpattern(dash) lwidth(medthick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(order(3 "Primary" 4 "Inclusive") cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.25)
    graph export "`fig_d2'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("CVD mortality rates"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Age-standardised mortality rates per 100,000; whiskers are published 95% statistical confidence intervals."), font("`font_body'", 8, "`bnr_muted'")
local d2_primary "-"
local d2_inclusive "-"
use "`annual_mortality_data'", clear
foreach spec in primary inclusive {
    preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
        if "`spec'" == "primary" keep if case_definition == "primary_clear_likely"
        if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local d2_`spec' = strtrim("`tmp'")
        }
    restore
}
putpdf table d2_cards = (2,2), width(70%) border(all, nil)
putpdf table d2_cards(1,1) = ("Primary ASMR")
putpdf table d2_cards(1,2) = ("Inclusive ASMR")
putpdf table d2_cards(2,1) = ("`d2_primary'")
putpdf table d2_cards(2,2) = ("`d2_inclusive'")
putpdf table d2_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d2_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table d2_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_d2'"
if !_rc {
    putpdf table d2_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table d2_fig(1,1) = image("`fig_d2'")
}

putpdf table d2_tab = (3,6), width(100%) border(all, nil)
putpdf table d2_tab(1,1) = ("ASMR (95% CI)")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table d2_tab(1,`cc') = ("`yy'")
}
local d2row = 1
foreach spec in primary inclusive {
    local ++d2row
    local label "Primary"
    if "`spec'" == "inclusive" local label "Inclusive"
    putpdf table d2_tab(`d2row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_mortality_data'", clear
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `yy' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
        if "`spec'" == "primary" keep if case_definition == "primary_clear_likely"
        if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 {
            local est : display %5.1f value[1]
            local lo : display %5.1f ci_lower_value[1]
            local hi : display %5.1f ci_upper_value[1]
            local cell "`=strtrim("`est'")' (`=strtrim("`lo'")'-`=strtrim("`hi'")')"
        }
        putpdf table d2_tab(`d2row',`cc') = ("`cell'")
    }
}
putpdf table d2_tab(.,.), font("`font_body'", 6.9)
putpdf table d2_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d2_tab(.,1), bold
putpdf table d2_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table d2_tab(2/3,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table d2_note = (2,1), width(100%) border(all, nil)
putpdf table d2_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table d2_note(2,1) = ("`ann_mort_rates_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table d2_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 13. Mortality - D3 Heart and Stroke
* -----------------------------------------------------------------------------

local fig_d3 "`annual_figure_dir'/mortality_rate_heart_stroke.png"
use "`annual_mortality_data'", clear
keep if metric_id == "MORT-RATE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & ///
    inlist(event_type, "heart", "stroke") & sex == "all" & age_group == "age_standardised" & ///
    case_definition == "primary_clear_likely" & period_complete == 1
quietly count
if r(N) > 0 {
    twoway ///
      (rcap ci_lower_value ci_upper_value period_year if event_type == "heart", lcolor("`bnr_heart'%45") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if event_type == "stroke", lcolor("`bnr_stroke'%45") lwidth(vthin)) ///
      (connected value period_year if event_type == "heart", sort lcolor("`bnr_heart'") mcolor("`bnr_heart'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if event_type == "stroke", sort lcolor("`bnr_stroke'") mcolor("`bnr_stroke'") msymbol(O) msize(vsmall) lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(order(3 "Heart" 4 "Stroke") cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.25)
    graph export "`fig_d3'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Heart and Stroke deaths"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary-definition age-standardised mortality rates per 100,000."), font("`font_body'", 8, "`bnr_muted'")
local d3_all "`d2_primary'"
local d3_heart "-"
local d3_stroke "-"
use "`annual_mortality_data'", clear
foreach event in heart stroke {
    preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "`event'" & sex == "all" & age_group == "age_standardised" & case_definition == "primary_clear_likely" & ///
            statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local d3_`event' = strtrim("`tmp'")
        }
    restore
}
putpdf table d3_cards = (2,3), width(100%) border(all, nil)
putpdf table d3_cards(1,1) = ("All CVD")
putpdf table d3_cards(1,2) = ("Heart")
putpdf table d3_cards(1,3) = ("Stroke")
putpdf table d3_cards(2,1) = ("`d3_all'")
putpdf table d3_cards(2,2) = ("`d3_heart'")
putpdf table d3_cards(2,3) = ("`d3_stroke'")
putpdf table d3_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d3_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table d3_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_d3'"
if !_rc {
    putpdf table d3_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table d3_fig(1,1) = image("`fig_d3'")
}

putpdf table d3_tab = (4,6), width(100%) border(all, nil)
putpdf table d3_tab(1,1) = ("Primary ASMR (95% CI)")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table d3_tab(1,`cc') = ("`yy'")
}
local d3row = 1
foreach event in all_cvd heart stroke {
    local ++d3row
    local label "All CVD"
    if "`event'" == "heart" local label "Heart"
    if "`event'" == "stroke" local label "Stroke"
    putpdf table d3_tab(`d3row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_mortality_data'", clear
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & ///
            sex == "all" & age_group == "age_standardised" & case_definition == "primary_clear_likely" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local est : display %5.1f value[1]
            local lo : display %5.1f ci_lower_value[1]
            local hi : display %5.1f ci_upper_value[1]
            local cell "`=strtrim("`est'")' (`=strtrim("`lo'")'-`=strtrim("`hi'")')"
        }
        putpdf table d3_tab(`d3row',`cc') = ("`cell'")
    }
}
putpdf table d3_tab(.,.), font("`font_body'", 6.9)
putpdf table d3_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d3_tab(.,1), bold
putpdf table d3_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table d3_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table d3_note = (2,1), width(100%) border(all, nil)
putpdf table d3_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table d3_note(2,1) = ("`ann_mort_type_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table d3_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 14. Mortality - D4 Women and men
* -----------------------------------------------------------------------------

local fig_d4 "`annual_figure_dir'/mortality_rate_by_sex.png"
use "`annual_mortality_data'", clear
keep if metric_id == "MORT-RATE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & ///
    event_type == "all_cvd" & inlist(sex, "female", "male") & age_group == "age_standardised" & ///
    case_definition == "primary_clear_likely" & period_complete == 1
quietly count
if r(N) > 0 {
    twoway ///
      (rcap ci_lower_value ci_upper_value period_year if sex == "female", lcolor("`bnr_women'%45") lwidth(vthin)) ///
      (rcap ci_lower_value ci_upper_value period_year if sex == "male", lcolor("`bnr_men'%45") lwidth(vthin)) ///
      (connected value period_year if sex == "female", sort lcolor("`bnr_women'") mcolor("`bnr_women'") msymbol(O) msize(vsmall) lwidth(thick)) ///
      (connected value period_year if sex == "male", sort lcolor("`bnr_men'") mcolor("`bnr_men'") msymbol(O) msize(vsmall) lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) ///
      xtitle("") ytitle("") legend(order(3 "Women" 4 "Men") cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(3.25)
    graph export "`fig_d4'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Women and men"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary-definition age-standardised mortality rates per 100,000."), font("`font_body'", 8, "`bnr_muted'")
local d4_all "`d2_primary'"
local d4_female "-"
local d4_male "-"
use "`annual_mortality_data'", clear
foreach sex in female male {
    preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "`sex'" & age_group == "age_standardised" & ///
            case_definition == "primary_clear_likely" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local d4_`sex' = strtrim("`tmp'")
        }
    restore
}
putpdf table d4_cards = (2,3), width(100%) border(all, nil)
putpdf table d4_cards(1,1) = ("Both sexes")
putpdf table d4_cards(1,2) = ("Women")
putpdf table d4_cards(1,3) = ("Men")
putpdf table d4_cards(2,1) = ("`d4_all'")
putpdf table d4_cards(2,2) = ("`d4_female'")
putpdf table d4_cards(2,3) = ("`d4_male'")
putpdf table d4_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d4_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table d4_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_d4'"
if !_rc {
    putpdf table d4_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table d4_fig(1,1) = image("`fig_d4'")
}

putpdf table d4_tab = (4,6), width(100%) border(all, nil)
putpdf table d4_tab(1,1) = ("Primary ASMR (95% CI)")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table d4_tab(1,`cc') = ("`yy'")
}
local d4row = 1
foreach sex in all female male {
    local ++d4row
    local label "Both sexes"
    if "`sex'" == "female" local label "Women"
    if "`sex'" == "male" local label "Men"
    putpdf table d4_tab(`d4row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_mortality_data'", clear
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `yy' & event_type == "all_cvd" & ///
            sex == "`sex'" & age_group == "age_standardised" & case_definition == "primary_clear_likely" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local est : display %5.1f value[1]
            local lo : display %5.1f ci_lower_value[1]
            local hi : display %5.1f ci_upper_value[1]
            local cell "`=strtrim("`est'")' (`=strtrim("`lo'")'-`=strtrim("`hi'")')"
        }
        putpdf table d4_tab(`d4row',`cc') = ("`cell'")
    }
}
putpdf table d4_tab(.,.), font("`font_body'", 6.9)
putpdf table d4_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d4_tab(.,1), bold
putpdf table d4_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table d4_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table d4_note = (2,1), width(100%) border(all, nil)
putpdf table d4_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table d4_note(2,1) = ("`ann_mort_sex_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table d4_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 15. Mortality - D5 Age patterns
* -----------------------------------------------------------------------------

local fig_d5 "`annual_figure_dir'/mortality_age_counts.png"
use "`annual_mortality_data'", clear
keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & statistic == "annual_count" & ///
    event_type == "all_cvd" & sex == "all" & inlist(age_group, "under_70", "age_70_plus") & ///
    case_definition == "primary_clear_likely" & period_complete == 1
quietly count
if r(N) > 0 {
    keep period_year age_group value
    reshape wide value, i(period_year) j(age_group) string
    label variable valueunder_70 "Under 70"
    label variable valueage_70_plus "70 and older"
    graph bar valueunder_70 valueage_70_plus, ///
        over(period_year, label(angle(45) labsize(tiny))) stack ///
        bar(1, color("`bnr_under70'%82")) ///
        bar(2, color("`bnr_70plus'%82")) ///
        graphregion(color(white) margin(vsmall)) ///
        plotregion(color(white) margin(vsmall)) ///
        ytitle("") ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        yscale(noline) ///
        legend(cols(2) size(small) region(lcolor(none)) position(12) ring(1)) ///
        xsize(8.0) ysize(3.15)
    graph export "`fig_d5'", replace width(2800)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Age patterns"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary-definition CVD death counts by broad age group."), font("`font_body'", 8, "`bnr_muted'")
local d5_all "-"
local d5_under "-"
local d5_old "-"
use "`annual_mortality_data'", clear
foreach age in all under_70 age_70_plus {
    preserve
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "`age'" & case_definition == "primary_clear_likely" & statistic == "annual_count"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            if "`age'" == "all" local d5_all = strtrim("`tmp'")
            if "`age'" == "under_70" local d5_under = strtrim("`tmp'")
            if "`age'" == "age_70_plus" local d5_old = strtrim("`tmp'")
        }
    restore
}
putpdf table d5_cards = (2,3), width(100%) border(all, nil)
putpdf table d5_cards(1,1) = ("All ages")
putpdf table d5_cards(1,2) = ("Under 70")
putpdf table d5_cards(1,3) = ("70 and older")
putpdf table d5_cards(2,1) = ("`d5_all'")
putpdf table d5_cards(2,2) = ("`d5_under'")
putpdf table d5_cards(2,3) = ("`d5_old'")
putpdf table d5_cards(1,.), bold font("`font_title'", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d5_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table d5_cards(.,.), bgcolor("`bnr_pale'")
capture confirm file "`fig_d5'"
if !_rc {
    putpdf table d5_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table d5_fig(1,1) = image("`fig_d5'")
}

putpdf table d5_tab = (4,6), width(100%) border(all, nil)
putpdf table d5_tab(1,1) = ("Primary deaths")
forvalues j = 0/4 {
    local yy = `first_table_year' + `j'
    local cc = `j' + 2
    putpdf table d5_tab(1,`cc') = ("`yy'")
}
local d5row = 1
foreach age in all under_70 age_70_plus {
    local ++d5row
    local label "All ages"
    if "`age'" == "under_70" local label "Under 70"
    if "`age'" == "age_70_plus" local label "70 and older"
    putpdf table d5_tab(`d5row',1) = ("`label'")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        local cell "-"
        use "`annual_mortality_data'", clear
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `yy' & ///
            event_type == "all_cvd" & sex == "all" & age_group == "`age'" & case_definition == "primary_clear_likely" & statistic == "annual_count"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            local cell = strtrim("`tmp'")
        }
        putpdf table d5_tab(`d5row',`cc') = ("`cell'")
    }
}
putpdf table d5_tab(.,.), font("`font_body'", 7.4)
putpdf table d5_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d5_tab(.,1), bold
putpdf table d5_tab(.,6), bgcolor("`bnr_pale2'")
putpdf table d5_tab(2/4,6), bold
putpdf paragraph, font("`font_body'", 1)
putpdf table d5_note = (2,1), width(100%) border(all, nil)
putpdf table d5_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table d5_note(2,1) = ("`ann_mort_age_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table d5_note(.,.), bgcolor("`bnr_pale2'")
putpdf paragraph
putpdf text ("Source: BNR public mortality release `mortality_release'."), font("`font_body'", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 16. How complete is the picture? - E1/E2 quality matrices
* -----------------------------------------------------------------------------

local fig_e1 "`annual_figure_dir'/quality_event_dco.png"
local fig_e2 "`annual_figure_dir'/quality_possible_deaths.png"

use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & period_complete == 1 & sex == "all" & ///
    age_group == "all" & statistic == "annual_count" & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & ///
    ((ascertainment_scope == "additional_dco" & mortality_definition == "primary") | ///
     (ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"))
keep period_year event_type ascertainment_scope value
reshape wide value, i(period_year event_type) j(ascertainment_scope) string
gen double quality_pct = 100 * valueadditional_dco / valuehospital_plus_dco
gen byte quality_band = cond(quality_pct < 10, 1, cond(quality_pct < 15, 2, 3))
gen byte y = cond(event_type == "all_cvd", 3, cond(event_type == "heart", 2, 1))
gen str8 tile_label = string(quality_pct, "%4.1f") + "%"
quietly count if !missing(quality_pct)
if r(N) > 0 {
    twoway ///
      (scatter y period_year if quality_band == 1, msymbol(square) msize(11) mcolor("`bnr_green'") ///
          mlabel(tile_label) mlabposition(0) mlabsize(vsmall) mlabcolor("`bnr_ink'")) ///
      (scatter y period_year if quality_band == 2, msymbol(square) msize(11) mcolor("`bnr_amber'") ///
          mlabel(tile_label) mlabposition(0) mlabsize(vsmall) mlabcolor("`bnr_ink'")) ///
      (scatter y period_year if quality_band == 3, msymbol(square) msize(11) mcolor("`bnr_red'") ///
          mlabel(tile_label) mlabposition(0) mlabsize(vsmall) mlabcolor("`bnr_ink'")), ///
      graphregion(color(white) margin(vsmall)) plotregion(color(white) margin(vsmall)) ///
      xlabel(`first_table_year'(1)`report_year_num', format(%4.0f) labsize(small) noticks nogrid) ///
      ylabel(1 "Stroke" 2 "Heart" 3 "All CVD", angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) xtitle("") ytitle("") ///
      legend(order(1 "Lower: <10%" 2 "Moderate: 10-14%" 3 "Higher: 15%+") ///
          cols(3) size(vsmall) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(2.7)
    graph export "`fig_e1'", replace width(2800)
}

use "`annual_mortality_data'", clear
keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & period_complete == 1 & sex == "all" & ///
    age_group == "all" & statistic == "annual_count" & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & ///
    inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
keep period_year event_type case_definition value
reshape wide value, i(period_year event_type) j(case_definition) string
gen double quality_pct = 100 * ///
    (valueupper_clear_likely_possible - valueprimary_clear_likely) / ///
    valueupper_clear_likely_possible
gen byte quality_band = cond(quality_pct < 20, 1, cond(quality_pct < 30, 2, 3))
gen byte y = cond(event_type == "all_cvd", 3, cond(event_type == "heart", 2, 1))
gen str8 tile_label = string(quality_pct, "%4.1f") + "%"
quietly count if !missing(quality_pct)
if r(N) > 0 {
    twoway ///
      (scatter y period_year if quality_band == 1, msymbol(square) msize(11) mcolor("`bnr_green'") ///
          mlabel(tile_label) mlabposition(0) mlabsize(vsmall) mlabcolor("`bnr_ink'")) ///
      (scatter y period_year if quality_band == 2, msymbol(square) msize(11) mcolor("`bnr_amber'") ///
          mlabel(tile_label) mlabposition(0) mlabsize(vsmall) mlabcolor("`bnr_ink'")) ///
      (scatter y period_year if quality_band == 3, msymbol(square) msize(11) mcolor("`bnr_red'") ///
          mlabel(tile_label) mlabposition(0) mlabsize(vsmall) mlabcolor("`bnr_ink'")), ///
      graphregion(color(white) margin(vsmall)) plotregion(color(white) margin(vsmall)) ///
      xlabel(`first_table_year'(1)`report_year_num', format(%4.0f) labsize(small) noticks nogrid) ///
      ylabel(1 "Stroke" 2 "Heart" 3 "All CVD", angle(horizontal) labsize(small) noticks nogrid) ///
      xscale(noline) yscale(noline) xtitle("") ytitle("") ///
      legend(order(1 "Lower: <20%" 2 "Moderate: 20-29%" 3 "Higher: 30%+") ///
          cols(3) size(vsmall) region(lcolor(none)) position(12) ring(1)) ///
      xsize(8.0) ysize(2.7)
    graph export "`fig_e2'", replace width(2800)
}

putpdf pagebreak
putpdf paragraph
putpdf text ("3 | How complete is the picture?"), bold font("`font_title'", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("Events identified through death records"), bold font("`font_title'", 13, "`bnr_ink'")
putpdf paragraph
putpdf text ("Each tile gives the estimated additional DCO contribution as a percentage of the Primary national event estimate. The latest five complete years are shown; colours use the same pragmatic reliance bands as the CVD events dashboard."), font("`font_body'", 8, "`bnr_muted'")
capture confirm file "`fig_e1'"
if !_rc {
    putpdf table e1_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table e1_fig(1,1) = image("`fig_e1'")
}
putpdf paragraph, font("`font_body'", 1)
putpdf table e1_note = (2,1), width(100%) border(all, nil)
putpdf table e1_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table e1_note(2,1) = ("`ann_evt_quality_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table e1_note(.,.), bgcolor("`bnr_pale2'")

putpdf paragraph
putpdf text ("Reliance on Possible deaths"), bold font("`font_title'", 13, "`bnr_ink'")
putpdf paragraph
putpdf text ("Possible-only deaths as a percentage of the Inclusive annual mortality count. The category thresholds match the mortality dashboard: Lower <20%, Moderate 20-29%, Higher 30%+."), font("`font_body'", 8, "`bnr_muted'")
capture confirm file "`fig_e2'"
if !_rc {
    putpdf table e2_fig = (1,1), width(100%) border(all, nil) halign(center)
    putpdf table e2_fig(1,1) = image("`fig_e2'")
}
putpdf paragraph, font("`font_body'", 1)
putpdf table e2_note = (2,1), width(100%) border(all, nil)
putpdf table e2_note(1,1) = ("WHAT THIS MEANS"), ///
    bold font("`font_title'", 8.5, "`bnr_teal'")
putpdf table e2_note(2,1) = ("`ann_mort_quality_text'"), ///
    font("`font_body'", 8.1, "`bnr_ink'")
putpdf table e2_note(.,.), bgcolor("`bnr_pale2'")

* -----------------------------------------------------------------------------
* 17. E3/E4 Data availability and understanding uncertainty
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("Data availability"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The standard annual report uses complete published annual observations only. The latest release can contain partial monthly or quarterly periods that are appropriate for dashboards and rolling updates but are not treated as complete annual results here."), font("`font_body'", 9)

local event_first "-"
local event_last "-"
local mort_first "-"
local mort_last "-"
use "`annual_event_data'", clear
quietly summarize period_year if period_type == "annual" & period_complete == 1 & metric_id == "CVD-BURDEN-001", meanonly
if r(N) > 0 {
    local event_first = string(r(min), "%4.0f")
    local event_last = string(r(max), "%4.0f")
}
use "`annual_mortality_data'", clear
quietly summarize period_year if period_type == "annual" & period_complete == 1 & metric_id == "MORT-BURDEN-001", meanonly
if r(N) > 0 {
    local mort_first = string(r(min), "%4.0f")
    local mort_last = string(r(max), "%4.0f")
}
putpdf table availability = (3,4), width(100%) border(all, nil)
putpdf table availability(1,1) = ("Series")
putpdf table availability(1,2) = ("First complete annual year")
putpdf table availability(1,3) = ("Latest complete annual year")
putpdf table availability(1,4) = ("Release used")
putpdf table availability(2,1) = ("CVD events")
putpdf table availability(2,2) = ("`event_first'")
putpdf table availability(2,3) = ("`event_last'")
putpdf table availability(2,4) = ("`event_release'")
putpdf table availability(3,1) = ("CVD mortality")
putpdf table availability(3,2) = ("`mort_first'")
putpdf table availability(3,3) = ("`mort_last'")
putpdf table availability(3,4) = ("`mortality_release'")
putpdf table availability(.,.), font("`font_body'", 8)
putpdf table availability(1,.), bold bgcolor("`bnr_pale'")
putpdf table availability(.,1), bold

putpdf paragraph
putpdf text ("Understanding uncertainty"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf table uncertainty = (3,3), width(100%) border(all, nil)
putpdf table uncertainty(1,1) = ("What is shown")
putpdf table uncertainty(1,2) = ("Visual form")
putpdf table uncertainty(1,3) = ("What it means")
putpdf table uncertainty(2,1) = ("Statistical 95% confidence interval")
putpdf table uncertainty(2,2) = ("Thin whisker")
putpdf table uncertainty(2,3) = ("Statistical uncertainty around the published estimate under its stated method.")
putpdf table uncertainty(3,1) = ("DCO linkage range")
putpdf table uncertainty(3,2) = ("Pale shaded band")
putpdf table uncertainty(3,3) = ("Uncertainty in the national event estimate arising from incomplete deterministic linkage of death records to hospital events.")
putpdf table uncertainty(1,.), bold bgcolor("`bnr_pale'") font("`font_body'", 8)
putpdf table uncertainty(2/3,.), font("`font_body'", 8)
putpdf paragraph
putpdf text ("The two intervals answer different questions and should not be combined into a single range. The report therefore gives them different visual forms."), bold font("`font_title'", 8.5, "`bnr_teal'")

* -----------------------------------------------------------------------------
* 19. Methods - what we did and what the numbers mean
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("4 | Methods"), bold font("`font_title'", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("Scope, definitions and event ascertainment"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_methods_note'"), font("`font_body'", 8.5)

putpdf paragraph
putpdf text ("Surveillance population and unit of analysis"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("The CVD-event series counts eligible cardiovascular events among Barbados residents, not unique people. A person may contribute more than one eligible event when each event meets the approved event definition. The annual standard section reports All CVD and the two component families Heart and Stroke, together with sex and broad age summaries where those dimensions are present in the approved public release."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Event classification"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Records enter the event series only after the approved CVD-event, residence, reporting-period and duplicate-resolution rules have been applied. Hospital-recorded statistics use eligible events identified from hospital information. The Queen Elizabeth Hospital is Barbados's only tertiary hospital, so this series provides an important view of serious recognised CVD events, but it is not treated as complete national ascertainment."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Death-certificate-only ascertainment"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("A death-certificate-only (DCO) event is an eligible event identified from death information without a matching eligible hospital-recorded event. The controlled event workflow applies deterministic linkage and approved event-window rules before producing aggregate DCO-enhanced outputs. Hospital + DCO statistics are annual only. Where linkage remains unresolved, the public release carries a central aggregate estimate and separate lower and upper linkage values; this report displays those released quantities and does not reconstruct them."), font("`font_body'", 8.4)

putpdf table event_scope = (3,3), width(100%) border(all, nil)
putpdf table event_scope(1,1) = ("Published event series")
putpdf table event_scope(1,2) = ("Source coverage")
putpdf table event_scope(1,3) = ("Interpretation")
putpdf table event_scope(2,1) = ("Hospital-recorded")
putpdf table event_scope(2,2) = ("Eligible hospital events")
putpdf table event_scope(2,3) = ("Observed serious CVD events recorded through the hospital source")
putpdf table event_scope(3,1) = ("Hospital + DCO")
putpdf table event_scope(3,2) = ("Hospital events plus eligible DCO contribution")
putpdf table event_scope(3,3) = ("Broader annual national estimate, with linkage uncertainty reported separately")
putpdf table event_scope(.,.), font("`font_body'", 7.8)
putpdf table event_scope(1,.), bold bgcolor("`bnr_pale'")
putpdf table event_scope(.,1), bold

putpdf pagebreak
putpdf paragraph
putpdf text ("Mortality case ascertainment"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("BNR mortality surveillance uses death-certificate information to create a consistent practical cardiovascular classification when a formally assigned national underlying cause of death is not available to the Registry for routine surveillance. The method considers the wording on the certificate, whether information appears in Part I or Part II, the order of lines in Part I, documented mortality-coding principles and the strength of the available cardiovascular evidence."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Evidence classes"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table mort_classes = (6,2), width(100%) border(all, nil)
putpdf table mort_classes(1,1) = ("Class")
putpdf table mort_classes(1,2) = ("BNR interpretation")
putpdf table mort_classes(2,1) = ("Clear")
putpdf table mort_classes(2,2) = ("Strong evidence that the death belongs in the relevant BNR cardiovascular mortality group.")
putpdf table mort_classes(3,1) = ("Likely")
putpdf table mort_classes(3,2) = ("Good evidence, although some uncertainty remains.")
putpdf table mort_classes(4,1) = ("Possible")
putpdf table mort_classes(4,2) = ("Cardiovascular attribution is plausible, but uncertainty is material.")
putpdf table mort_classes(5,1) = ("Mention only")
putpdf table mort_classes(5,2) = ("Relevant wording is present but does not support approximate underlying-cause attribution.")
putpdf table mort_classes(6,1) = ("No evidence")
putpdf table mort_classes(6,2) = ("No qualifying cardiovascular evidence is identified by the approved rules.")
putpdf table mort_classes(.,.), font("`font_body'", 7.8)
putpdf table mort_classes(1,.), bold bgcolor("`bnr_pale'")
putpdf table mort_classes(.,1), bold

putpdf paragraph
putpdf text ("Primary and Inclusive mortality definitions"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary includes Clear + Likely classifications. Inclusive includes Clear + Likely + Possible. Inclusive therefore contains Primary. The two are alternative classification-sensitivity definitions and must not be added together. Their difference is not a statistical confidence interval."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Relation to official cause-of-death statistics"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("The BNR method is a structured surveillance classification. It is not full ICD-10 underlying-cause coding and should not be assumed to be directly equivalent to official national or international cause-of-death series that use formal underlying-cause selection and coding rules."), font("`font_body'", 8.4)

putpdf pagebreak
putpdf paragraph
putpdf text ("Measures, rates and uncertainty"), bold font("`font_title'", 14, "`bnr_ink'")

putpdf paragraph
putpdf text ("Counts and percentages"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Counts are registry enumerations of eligible events or classified deaths. Percentage distributions describe how a published total is divided across groups; they are not population risks. The DCO-reliance and Possible-death percentages used in this report are presentation summaries of already-published aggregate counts."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Crude rate"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table eq_crude = (1,1), width(86%) border(all, nil) halign(center)
putpdf table eq_crude(1,1) = ("Rate per 100,000 = eligible events or deaths / resident population x 100,000"), ///
    bold font("`font_body_med'", 9, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf paragraph
putpdf text ("The matching resident population denominator is taken from the approved UN World Population Prospects 2024 Barbados series carried by the public workflow."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Direct age standardisation"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table eq_asr = (1,1), width(86%) border(all, nil) halign(center)
putpdf table eq_asr(1,1) = ("Age-standardised rate = sum of age-specific rate x standard-population weight"), ///
    bold font("`font_body_med'", 9, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf paragraph
putpdf text ("BNR uses the WHO World Standard Population 2000-2025 where age-standardised rates are specified. Standardisation reduces differences caused only by differing age structures; it does not remove uncertainty from ascertainment, classification or small numbers."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Statistical confidence intervals"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Published crude-rate intervals use the exact Poisson (Garwood) method where specified. Published directly age-standardised mortality intervals use the Fay-Feuer gamma method. Event-rate outputs carry the interval method supplied by the approved release. The annual report reads the released limits rather than recalculating them."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("DCO linkage uncertainty"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Hospital + DCO annual event counts and event rates may carry separate lower and upper linkage values. These describe uncertainty from DCO ascertainment and linkage. They answer a different question from a statistical confidence interval, so the report shows linkage uncertainty as a pale band and statistical uncertainty as whiskers rather than combining them into one range."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Comparators"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Annual counts use the published mean for the same stratum over the previous five calendar years. Quarterly counts may use the published mean for the same quarter in the previous five years. The fixed 2015-2019 monthly historical reference used in dashboard and rolling-update products is a separate seasonal reference and is not a confidence interval or a rolling annual comparator."), font("`font_body'", 8.4)

putpdf pagebreak
putpdf paragraph
putpdf text ("Completeness, disclosure and publication governance"), bold font("`font_title'", 14, "`bnr_ink'")

putpdf paragraph
putpdf text ("Completeness and reporting period"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("The standard annual section uses complete annual observations. Public releases may also contain monthly or quarterly rows, including a current incomplete quarter or year for operational dashboards. Those rows are not treated as complete annual results. Release date and latest observation period are separate concepts and should not be interpreted as the same date."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Disclosure control"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("BNR publishes aggregate statistics rather than patient-level records. Positive counts below six are normally subject to primary suppression. Secondary suppression is then used when row, column or related totals could otherwise allow a protected value to be inferred. Overly detailed combinations are avoided, and every public release passes disclosure-control review before publication. A protected value is not zero and this annual report never reconstructs it from related cells."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("From source data to this report"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table workflow = (5,2), width(100%) border(all, nil)
putpdf table workflow(1,1) = ("1  PREPARE")
putpdf table workflow(1,2) = ("Versioned source releases and controlled analytical inputs are prepared.")
putpdf table workflow(2,1) = ("2  CALCULATE")
putpdf table workflow(2,2) = ("Readable Stata programs create the approved surveillance measures and structured outputs.")
putpdf table workflow(3,1) = ("3  REVIEW")
putpdf table workflow(3,2) = ("Automated QA and disclosure checks prepare a fixed candidate for human review.")
putpdf table workflow(4,1) = ("4  APPROVE")
putpdf table workflow(4,2) = ("Authorised reviewers assess analytical plausibility, disclosure safety and publication readiness.")
putpdf table workflow(5,1) = ("5  PUBLISH")
putpdf table workflow(5,2) = ("Only approved public products are promoted to the Information Hub; the annual report reads those declared public products.")
putpdf table workflow(.,1), bold font("`font_title'", 8, "`bnr_teal'")
putpdf table workflow(.,2), font("`font_body'", 8)

putpdf paragraph
putpdf text ("Reproducibility boundary"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("The standard section does not reopen confidential source data and does not calculate surveillance rates from patient-level records. Step 1 validates the declared public event and mortality releases and their website mirrors, then the report composes already-approved values, intervals and comparators into a fixed candidate. Changes are made in source data, controlled Stata code or analyst-owned interpretation and then rebuilt; public output files are not edited by hand."), font("`font_body'", 8.4)

putpdf paragraph
putpdf text ("Report information"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table report_info = (4,2), width(82%) border(all, nil)
putpdf table report_info(1,1) = ("Report year")
putpdf table report_info(1,2) = ("`report_year4'")
putpdf table report_info(2,1) = ("CVD-event release")
putpdf table report_info(2,2) = ("`event_release'")
putpdf table report_info(3,1) = ("Mortality release")
putpdf table report_info(3,2) = ("`mortality_release'")
putpdf table report_info(4,1) = ("Standard composition")
putpdf table report_info(4,2) = ("bnr_report_annual_standard.do v2.2.0")
putpdf table report_info(.,1), bold font("`font_title'", 8, "`bnr_muted'")
putpdf table report_info(.,2), font("`font_body'", 8)

/*******************************************************************************
DO-FILE: bnr_report_annual_standard.do
VERSION: 2.0.0 (3 September 2026)
PURPOSE: Reusable putpdf composition for the standard annual CVD surveillance
         section.

CALLER:
  bnr_report_annual_s1_build.do only.

SOURCE BOUNDARY:
  This file reads only the two declared approved public release CSVs selected
  and checksum-validated by Step 1. It never reads confidential source data and
  it does not recalculate published surveillance rates.

DESIGN CONTRACT:
  - Plain institutional cover using the UWI crest.
  - One-page latest-year visual summary.
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
local bnr_pale      "240 246 248"
local bnr_pale2     "248 249 250"
local bnr_rule      "222 226 230"
local bnr_muted     "102 102 102"
local bnr_green     "214 237 223"
local bnr_amber     "255 231 168"
local bnr_red       "243 198 204"

local first_table_year = `report_year_num' - 4

capture mkdir "`candidate_dir'/figures"
local annual_figure_dir "`candidate_dir'/figures"

* -----------------------------------------------------------------------------
* 2. Read the two approved public releases once
* -----------------------------------------------------------------------------

tempfile annual_event_data annual_mortality_data

import delimited using "`event_csv'", clear varnames(1) stringcols(_all)
foreach v in period_year period_complete value numerator denominator ///
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

putpdf paragraph, halign(center) spacing(before, 64)
putpdf image "`uwi_crest'", width(1.25)

putpdf paragraph, halign(center) spacing(before, 28)
putpdf text ("Barbados National Registry"), bold font("Arial", 14, "`bnr_teal'")
putpdf paragraph, halign(center) spacing(before, 18)
putpdf text ("Annual cardiovascular disease report"), bold font("Arial", 25, "`bnr_ink'")
putpdf paragraph, halign(center) spacing(before, 8)
putpdf text ("`report_year4'"), bold font("Arial", 30, "`bnr_ink'")
putpdf paragraph, halign(center) spacing(before, 20)
putpdf text ("Cardiovascular disease events and mortality in Barbados"), font("Arial", 12, "`bnr_muted'")

putpdf paragraph, halign(center) spacing(before, 105)
putpdf text ("The University of the West Indies | Cave Hill Campus"), font("Arial", 8, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 5. Year in brief - infographic page
* -----------------------------------------------------------------------------

* Four small five-year trend panels, intentionally stripped of graph furniture.
local yib_event_count_fig "`annual_figure_dir'/yib_event_count.png"
local yib_event_rate_fig  "`annual_figure_dir'/yib_event_rate.png"
local yib_death_count_fig "`annual_figure_dir'/yib_death_count.png"
local yib_death_rate_fig  "`annual_figure_dir'/yib_death_rate.png"
local yib_panel_fig       "`annual_figure_dir'/yib_panel.png"

use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
    inrange(period_year, `first_table_year', `report_year_num') & ///
    event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
    ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & ///
    statistic == "annual_count" & period_complete == 1
quietly count
if r(N) >= 2 {
    twoway connected value period_year, sort lcolor("`bnr_teal'") ///
        mcolor("`bnr_teal'") lwidth(medthick) msymbol(O) msize(vsmall) ///
        graphregion(color(white) margin(tiny)) plotregion(color(white) margin(tiny)) ///
        xlabel(`first_table_year' `report_year_num', labsize(vsmall) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) xtitle("") ytitle("") legend(off) ///
        title("CVD events", size(small) color("`bnr_ink'")) ///
        xsize(3.2) ysize(1.55) name(yib1, replace)
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
    twoway connected value period_year, sort lcolor("`bnr_primary'") ///
        mcolor("`bnr_primary'") lwidth(medthick) msymbol(O) msize(vsmall) ///
        graphregion(color(white) margin(tiny)) plotregion(color(white) margin(tiny)) ///
        xlabel(`first_table_year' `report_year_num', labsize(vsmall) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) xtitle("") ytitle("") legend(off) ///
        title("CVD event rate", size(small) color("`bnr_ink'")) ///
        xsize(3.2) ysize(1.55) name(yib2, replace)
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
    twoway connected value period_year, sort lcolor("`bnr_heart'") ///
        mcolor("`bnr_heart'") lwidth(medthick) msymbol(O) msize(vsmall) ///
        graphregion(color(white) margin(tiny)) plotregion(color(white) margin(tiny)) ///
        xlabel(`first_table_year' `report_year_num', labsize(vsmall) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) xtitle("") ytitle("") legend(off) ///
        title("CVD deaths", size(small) color("`bnr_ink'")) ///
        xsize(3.2) ysize(1.55) name(yib3, replace)
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
    twoway connected value period_year, sort lcolor("`bnr_secondary'") ///
        mcolor("`bnr_secondary'") lwidth(medthick) msymbol(O) msize(vsmall) ///
        graphregion(color(white) margin(tiny)) plotregion(color(white) margin(tiny)) ///
        xlabel(`first_table_year' `report_year_num', labsize(vsmall) noticks nogrid) ///
        ylabel(, nolabel noticks nogrid) xtitle("") ytitle("") legend(off) ///
        title("CVD mortality rate", size(small) color("`bnr_ink'")) ///
        xsize(3.2) ysize(1.55) name(yib4, replace)
    graph export "`yib_death_rate_fig'", replace width(1200)
}

capture graph combine yib1 yib2 yib3 yib4, cols(2) ///
    graphregion(color(white) margin(tiny)) xsize(6.8) ysize(3.3) name(yibpanel, replace)
if !_rc graph export "`yib_panel_fig'", replace width(2400)

putpdf pagebreak
putpdf paragraph
putpdf text ("`report_year4' in brief"), bold font("Arial", 22, "`bnr_ink'")
putpdf paragraph
putpdf text ("A one-page view of the latest complete year. The rest of the report places these values in the full published time series."), font("Arial", 9, "`bnr_muted'")

putpdf table yib_cards = (4,2), width(100%) border(all, nil)
putpdf table yib_cards(1,1) = ("CVD events | Primary national estimate")
putpdf table yib_cards(1,2) = ("CVD event rate | Primary age-standardised")
putpdf table yib_cards(2,1) = ("`yib_event_count'")
putpdf table yib_cards(2,2) = ("`yib_event_rate' per 100,000")
putpdf table yib_cards(3,1) = ("CVD deaths | Primary definition")
putpdf table yib_cards(3,2) = ("CVD mortality rate | Primary age-standardised")
putpdf table yib_cards(4,1) = ("`yib_death_count'")
putpdf table yib_cards(4,2) = ("`yib_death_rate' per 100,000")
putpdf table yib_cards(1,.), bold font("Arial", 8, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table yib_cards(3,.), bold font("Arial", 8, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table yib_cards(2,.), bold font("Arial", 17, "`bnr_ink'") bgcolor("`bnr_pale'")
putpdf table yib_cards(4,.), bold font("Arial", 17, "`bnr_ink'") bgcolor("`bnr_pale'")

capture confirm file "`yib_panel_fig'"
if !_rc {
    putpdf paragraph, spacing(before, 6)
    putpdf image "`yib_panel_fig'", width(6.65)
}

putpdf table yib_quality = (2,2), width(100%) border(all, nil)
putpdf table yib_quality(1,1) = ("Events identified through death records")
putpdf table yib_quality(1,2) = ("Possible CVD deaths")
putpdf table yib_quality(2,1) = ("`yib_event_dco_share' of the Primary national event estimate")
putpdf table yib_quality(2,2) = ("`yib_possible_share' of the Inclusive mortality estimate")
putpdf table yib_quality(1,.), bold font("Arial", 8, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf table yib_quality(2,.), font("Arial", 9, "`bnr_ink'") bgcolor("`bnr_pale2'")

putpdf paragraph
putpdf text ("What stood out in `report_year4'?"), bold font("Arial", 11, "`bnr_ink'")
foreach msg in annual_summary_message_1 annual_summary_message_2 annual_summary_message_3 {
    putpdf paragraph, indent(left, 0.15) spacing(before, 2)
    putpdf text ("• ``msg''"), font("Arial", 8.5)
}

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
          ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          sort color("`bnr_teal'%12") lcolor(none)) ///
      (line value period_year if ascertainment_scope == "hospital_only" & statistic == "annual_count", ///
          sort lcolor("`bnr_muted'") lwidth(medthick)) ///
      (line value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          sort lcolor("`bnr_teal'") lwidth(thick)) ///
      (line value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", ///
          sort lcolor("`bnr_primary'") lpattern(dash) lwidth(medthick)) ///
      (line value period_year if ascertainment_scope == "hospital_only" & statistic == "annual_previous_5yr_mean", ///
          sort lcolor("`bnr_secondary'") lpattern(shortdash) lwidth(thin)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ///
      ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") ///
      legend(order(2 "Hospital-recorded" 3 "Primary national" 4 "Inclusive national" 5 "Previous 5-year mean") ///
          cols(2) size(vsmall) region(lcolor(none))) ///
      xsize(7.1) ysize(3.35)
    graph export "`fig_c1'", replace width(2400)
}

putpdf pagebreak
putpdf paragraph
putpdf text ("1 | CVD events"), bold font("Arial", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("How many CVD events?"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The chart shows the complete published annual series. The table gives exact values for the latest five complete years."), font("Arial", 8, "`bnr_muted'")

* Latest headline cards.
local c1_hospital "-"
local c1_primary "-"
local c1_inclusive "-"
use "`annual_event_data'", clear
foreach spec in hospital primary inclusive {
    preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
            period_year == `report_year_num' & event_type == "all_cvd" & sex == "all" & age_group == "all" & statistic == "annual_count"
        if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
        if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
        if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local tmp : display %9.1fc value[1]
            local c1_`spec' = strtrim("`tmp'")
        }
    restore
}
putpdf table c1_cards = (2,3), width(100%) border(all, nil)
putpdf table c1_cards(1,1) = ("Hospital-recorded")
putpdf table c1_cards(1,2) = ("Primary national estimate")
putpdf table c1_cards(1,3) = ("Inclusive national estimate")
putpdf table c1_cards(2,1) = ("`c1_hospital'")
putpdf table c1_cards(2,2) = ("`c1_primary'")
putpdf table c1_cards(2,3) = ("`c1_inclusive'")
putpdf table c1_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c1_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")

capture confirm file "`fig_c1'"
if !_rc putpdf image "`fig_c1'", width(6.75)
putpdf paragraph
putpdf text ("Figure 1. Annual CVD event counts. The pale band shows the published DCO linkage range around the Primary national estimate; the dashed comparator is the published hospital-recorded previous-five-year mean."), font("Arial", 7, "`bnr_muted'")

putpdf table c1_tab = (5,6), width(100%) border(all, single)
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
            period_year == `yy' & event_type == "all_cvd" & sex == "all" & age_group == "all"
        if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only" & statistic == "annual_count"
        if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_count"
        if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive" & statistic == "annual_count"
        if "`spec'" == "comparator" keep if ascertainment_scope == "hospital_only" & statistic == "annual_previous_5yr_mean"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.1fc value[1]
            local cell = strtrim("`tmp'")
        }
        putpdf table c1_tab(`c1row',`cc') = ("`cell'")
    }
}
putpdf table c1_tab(.,.), font("Arial", 7.4)
putpdf table c1_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c1_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_event_counts_interpretation'"), font("Arial", 8.5)

* -----------------------------------------------------------------------------
* 7. CVD events - C2 Event rates
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
      (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          sort color("`bnr_teal'%12") lcolor(none)) ///
      (rcap ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", ///
          lcolor("`bnr_teal'%45") lwidth(vthin)) ///
      (line value period_year if ascertainment_scope == "hospital_only", sort lcolor("`bnr_muted'") lwidth(medthick)) ///
      (line value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", sort lcolor("`bnr_teal'") lwidth(thick)) ///
      (line value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", sort lcolor("`bnr_primary'") lpattern(dash) lwidth(medthick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") ///
      legend(order(3 "Hospital-recorded" 4 "Primary national" 5 "Inclusive national") cols(3) size(vsmall) region(lcolor(none))) ///
      xsize(7.1) ysize(3.25)
    graph export "`fig_c2'", replace width(2400)
}

putpdf pagebreak
putpdf paragraph
putpdf text ("CVD event rates"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Age-standardised rates per 100,000. The Primary national series carries both the published DCO linkage range and the published 95% statistical confidence interval."), font("Arial", 8, "`bnr_muted'")

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
putpdf table c2_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c2_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")

capture confirm file "`fig_c2'"
if !_rc putpdf image "`fig_c2'", width(6.75)
putpdf paragraph
putpdf text ("Figure 2. Annual age-standardised CVD event rates. The shaded region is DCO linkage uncertainty; the thin vertical whiskers are statistical 95% confidence intervals for the Primary national series."), font("Arial", 7, "`bnr_muted'")

putpdf table c2_tab = (4,6), width(100%) border(all, single)
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
putpdf table c2_tab(.,.), font("Arial", 6.9)
putpdf table c2_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c2_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_event_rates_interpretation'"), font("Arial", 8.5)

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
      (line value period_year if event_type == "heart", sort lcolor("`bnr_heart'") lwidth(thick)) ///
      (line value period_year if event_type == "stroke", sort lcolor("`bnr_stroke'") lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") legend(order(5 "Heart" 6 "Stroke") cols(2) size(small) region(lcolor(none))) ///
      xsize(7.1) ysize(3.25)
    graph export "`fig_c3'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Heart and Stroke"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary national age-standardised event rates per 100,000."), font("Arial", 8, "`bnr_muted'")

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
putpdf table c3_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c3_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_c3'"
if !_rc putpdf image "`fig_c3'", width(6.75)

putpdf table c3_tab = (4,6), width(100%) border(all, single)
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
putpdf table c3_tab(.,.), font("Arial", 6.9)
putpdf table c3_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c3_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_event_type_interpretation'"), font("Arial", 8.5)

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
      (line value period_year if sex == "female", sort lcolor("`bnr_women'") lwidth(thick)) ///
      (line value period_year if sex == "male", sort lcolor("`bnr_men'") lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") legend(order(5 "Women" 6 "Men") cols(2) size(small) region(lcolor(none))) ///
      xsize(7.1) ysize(3.25)
    graph export "`fig_c4'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Women and men"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary national age-standardised event rates per 100,000."), font("Arial", 8, "`bnr_muted'")
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
putpdf table c4_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c4_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_c4'"
if !_rc putpdf image "`fig_c4'", width(6.75)

putpdf table c4_tab = (4,6), width(100%) border(all, single)
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
putpdf table c4_tab(.,.), font("Arial", 6.9)
putpdf table c4_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c4_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_event_sex_interpretation'"), font("Arial", 8.5)

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
    graph bar (sum) value, over(period_year, label(angle(45) labsize(vsmall))) over(age_group) ///
        stack asyvars graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
        ytitle("") ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        legend(order(1 "Under 70" 2 "70 and older") cols(2) size(small) region(lcolor(none))) ///
        xsize(7.1) ysize(3.25)
    graph export "`fig_c5'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Age patterns"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Hospital-recorded annual event counts by broad age group. These are composition counts, not age-specific rates."), font("Arial", 8, "`bnr_muted'")
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
putpdf table c5_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table c5_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_c5'"
if !_rc putpdf image "`fig_c5'", width(6.75)

putpdf table c5_tab = (4,6), width(100%) border(all, single)
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
putpdf table c5_tab(.,.), font("Arial", 7.4)
putpdf table c5_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table c5_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_event_age_interpretation'"), font("Arial", 8.5)
putpdf paragraph
putpdf text ("Source: BNR public CVD-event release `event_release'."), font("Arial", 7, "`bnr_muted'")

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
      (line value period_year if case_definition == "primary_clear_likely" & statistic == "annual_count", sort lcolor("`bnr_teal'") lwidth(thick)) ///
      (line value period_year if case_definition == "upper_clear_likely_possible" & statistic == "annual_count", sort lcolor("`bnr_primary'") lpattern(dash) lwidth(medthick)) ///
      (line value period_year if case_definition == "primary_clear_likely" & statistic == "annual_previous_5yr_mean", sort lcolor("`bnr_secondary'") lpattern(shortdash) lwidth(thin)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") legend(order(1 "Primary" 2 "Inclusive" 3 "Primary previous 5-year mean") cols(2) size(vsmall) region(lcolor(none))) ///
      xsize(7.1) ysize(3.3)
    graph export "`fig_d1'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("2 | CVD mortality"), bold font("Arial", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("How many CVD deaths?"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary = Clear + Likely CVD deaths. Inclusive = Clear + Likely + Possible CVD deaths."), font("Arial", 8, "`bnr_muted'")
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
putpdf table d1_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d1_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_d1'"
if !_rc putpdf image "`fig_d1'", width(6.75)

putpdf table d1_tab = (4,6), width(100%) border(all, single)
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
putpdf table d1_tab(.,.), font("Arial", 7.3)
putpdf table d1_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d1_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_mortality_counts_interpretation'"), font("Arial", 8.5)

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
      (line value period_year if case_definition == "primary_clear_likely", sort lcolor("`bnr_teal'") lwidth(thick)) ///
      (line value period_year if case_definition == "upper_clear_likely_possible", sort lcolor("`bnr_primary'") lpattern(dash) lwidth(medthick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") legend(order(3 "Primary" 4 "Inclusive") cols(2) size(small) region(lcolor(none))) ///
      xsize(7.1) ysize(3.25)
    graph export "`fig_d2'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("CVD mortality rates"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Age-standardised mortality rates per 100,000; whiskers are published 95% statistical confidence intervals."), font("Arial", 8, "`bnr_muted'")
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
putpdf table d2_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d2_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_d2'"
if !_rc putpdf image "`fig_d2'", width(6.75)

putpdf table d2_tab = (3,6), width(100%) border(all, single)
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
putpdf table d2_tab(.,.), font("Arial", 6.9)
putpdf table d2_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d2_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_mortality_rates_interpretation'"), font("Arial", 8.5)

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
      (line value period_year if event_type == "heart", sort lcolor("`bnr_heart'") lwidth(thick)) ///
      (line value period_year if event_type == "stroke", sort lcolor("`bnr_stroke'") lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") legend(order(3 "Heart" 4 "Stroke") cols(2) size(small) region(lcolor(none))) ///
      xsize(7.1) ysize(3.25)
    graph export "`fig_d3'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Heart and Stroke deaths"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary-definition age-standardised mortality rates per 100,000."), font("Arial", 8, "`bnr_muted'")
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
putpdf table d3_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d3_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_d3'"
if !_rc putpdf image "`fig_d3'", width(6.75)

putpdf table d3_tab = (4,6), width(100%) border(all, single)
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
putpdf table d3_tab(.,.), font("Arial", 6.9)
putpdf table d3_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d3_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_mortality_type_interpretation'"), font("Arial", 8.5)

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
      (line value period_year if sex == "female", sort lcolor("`bnr_women'") lwidth(thick)) ///
      (line value period_year if sex == "male", sort lcolor("`bnr_men'") lwidth(thick)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      xlabel(#6, format(%4.0f) labsize(small) noticks nogrid) ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
      xtitle("") ytitle("") legend(order(3 "Women" 4 "Men") cols(2) size(small) region(lcolor(none))) ///
      xsize(7.1) ysize(3.25)
    graph export "`fig_d4'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Women and men"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary-definition age-standardised mortality rates per 100,000."), font("Arial", 8, "`bnr_muted'")
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
putpdf table d4_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d4_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_d4'"
if !_rc putpdf image "`fig_d4'", width(6.75)

putpdf table d4_tab = (4,6), width(100%) border(all, single)
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
putpdf table d4_tab(.,.), font("Arial", 6.9)
putpdf table d4_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d4_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_mortality_sex_interpretation'"), font("Arial", 8.5)

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
    graph bar (sum) value, over(period_year, label(angle(45) labsize(vsmall))) over(age_group) ///
        stack asyvars graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
        ytitle("") ylabel(, angle(horizontal) labsize(small) noticks nogrid) ///
        legend(order(1 "Under 70" 2 "70 and older") cols(2) size(small) region(lcolor(none))) ///
        xsize(7.1) ysize(3.25)
    graph export "`fig_d5'", replace width(2400)
}
putpdf pagebreak
putpdf paragraph
putpdf text ("Age patterns"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Primary-definition CVD death counts by broad age group."), font("Arial", 8, "`bnr_muted'")
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
putpdf table d5_cards(1,.), bold font("Arial", 7.5, "`bnr_muted'") bgcolor("`bnr_pale'")
putpdf table d5_cards(2,.), bold font("Arial", 14, "`bnr_ink'") bgcolor("`bnr_pale'")
capture confirm file "`fig_d5'"
if !_rc putpdf image "`fig_d5'", width(6.75)

putpdf table d5_tab = (4,6), width(100%) border(all, single)
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
putpdf table d5_tab(.,.), font("Arial", 7.4)
putpdf table d5_tab(1,.), bold bgcolor("`bnr_pale'")
putpdf table d5_tab(.,1), bold
putpdf paragraph
putpdf text ("Interpretation"), bold font("Arial", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_mortality_age_interpretation'"), font("Arial", 8.5)
putpdf paragraph
putpdf text ("Source: BNR public mortality release `mortality_release'."), font("Arial", 7, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 16. How complete is the picture? - E1/E2 quality matrices
* -----------------------------------------------------------------------------

local fig_e1 "`annual_figure_dir'/quality_event_dco.png"
local fig_e2 "`annual_figure_dir'/quality_possible_deaths.png"

tempfile event_quality mortality_quality
use "`annual_event_data'", clear
keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & sex == "all" & age_group == "all" & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & mortality_definition == "primary" & ///
    inlist(ascertainment_scope, "additional_dco", "hospital_plus_dco") & statistic == "annual_count" & period_complete == 1
keep period_year event_type ascertainment_scope value
reshape wide value, i(period_year event_type) j(ascertainment_scope) string
generate double quality_pct = 100 * valueadditional_dco / valuehospital_plus_dco if valuehospital_plus_dco > 0
generate byte y = 3 if event_type == "all_cvd"
replace y = 2 if event_type == "heart"
replace y = 1 if event_type == "stroke"
save "`event_quality'", replace
quietly count if !missing(quality_pct)
if r(N) > 0 {
    twoway scatter y period_year [aw=quality_pct], msymbol(square) mcolor("`bnr_teal'%65") msize(large) ///
        graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
        ylabel(1 "Stroke" 2 "Heart" 3 "All CVD", angle(horizontal) labsize(small) noticks nogrid) ///
        xlabel(#8, format(%4.0f) labsize(vsmall) noticks nogrid) xtitle("") ytitle("") legend(off) ///
        xsize(7.1) ysize(2.35)
    graph export "`fig_e1'", replace width(2400)
}

use "`annual_mortality_data'", clear
keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & sex == "all" & age_group == "all" & ///
    inlist(event_type, "all_cvd", "heart", "stroke") & statistic == "annual_count" & ///
    inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible") & period_complete == 1
keep period_year event_type case_definition value
reshape wide value, i(period_year event_type) j(case_definition) string
generate double quality_pct = 100 * (valueupper_clear_likely_possible - valueprimary_clear_likely) / valueupper_clear_likely_possible if valueupper_clear_likely_possible > 0
generate byte quality_band = 1 if quality_pct < 20
replace quality_band = 2 if inrange(quality_pct,20,29.999999)
replace quality_band = 3 if quality_pct >= 30 & !missing(quality_pct)
generate byte y = 3 if event_type == "all_cvd"
replace y = 2 if event_type == "heart"
replace y = 1 if event_type == "stroke"
save "`mortality_quality'", replace
quietly count if !missing(quality_pct)
if r(N) > 0 {
    twoway ///
      (scatter y period_year if quality_band == 1, msymbol(square) mcolor("`bnr_green'") msize(large)) ///
      (scatter y period_year if quality_band == 2, msymbol(square) mcolor("`bnr_amber'") msize(large)) ///
      (scatter y period_year if quality_band == 3, msymbol(square) mcolor("`bnr_red'") msize(large)), ///
      graphregion(color(white) margin(small)) plotregion(color(white) margin(small)) ///
      ylabel(1 "Stroke" 2 "Heart" 3 "All CVD", angle(horizontal) labsize(small) noticks nogrid) ///
      xlabel(#8, format(%4.0f) labsize(vsmall) noticks nogrid) xtitle("") ytitle("") ///
      legend(order(1 "Lower: <20%" 2 "Moderate: 20-29%" 3 "Higher: 30%+") cols(3) size(vsmall) region(lcolor(none))) ///
      xsize(7.1) ysize(2.5)
    graph export "`fig_e2'", replace width(2400)
}

putpdf pagebreak
putpdf paragraph
putpdf text ("3 | How complete is the picture?"), bold font("Arial", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("Events identified through death records"), bold font("Arial", 13, "`bnr_ink'")
putpdf paragraph
putpdf text ("Each square represents the estimated additional DCO contribution as a percentage of the Primary national event estimate. Larger/darker visual weight means greater reliance on death-record ascertainment."), font("Arial", 8, "`bnr_muted'")
capture confirm file "`fig_e1'"
if !_rc putpdf image "`fig_e1'", width(6.75)
putpdf paragraph
putpdf text ("`annual_event_quality_interpretation'"), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Reliance on Possible deaths"), bold font("Arial", 13, "`bnr_ink'")
putpdf paragraph
putpdf text ("Possible-only deaths as a percentage of the Inclusive annual mortality count. The category thresholds match the mortality dashboard: Lower <20%, Moderate 20-29%, Higher 30%+."), font("Arial", 8, "`bnr_muted'")
capture confirm file "`fig_e2'"
if !_rc putpdf image "`fig_e2'", width(6.75)
putpdf paragraph
putpdf text ("`annual_mortality_quality_interpretation'"), font("Arial", 8.5)

* -----------------------------------------------------------------------------
* 17. E3/E4 Data availability and understanding uncertainty
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("Data availability"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The standard annual report uses complete published annual observations only. The latest release can contain partial monthly or quarterly periods that are appropriate for dashboards and rolling updates but are not treated as complete annual results here."), font("Arial", 9)

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
putpdf table availability = (3,4), width(100%) border(all, single)
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
putpdf table availability(.,.), font("Arial", 8)
putpdf table availability(1,.), bold bgcolor("`bnr_pale'")
putpdf table availability(.,1), bold

putpdf paragraph
putpdf text ("Understanding uncertainty"), bold font("Arial", 14, "`bnr_ink'")
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
putpdf table uncertainty(1,.), bold bgcolor("`bnr_pale'") font("Arial", 8)
putpdf table uncertainty(2..3,.), font("Arial", 8)
putpdf paragraph
putpdf text ("The two intervals answer different questions and should not be combined into a single range. The report therefore gives them different visual forms."), bold font("Arial", 8.5, "`bnr_teal'")

* -----------------------------------------------------------------------------
* 18. Methods - what we did and what the numbers mean
* -----------------------------------------------------------------------------

putpdf pagebreak
putpdf paragraph
putpdf text ("4 | Methods"), bold font("Arial", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("What we did and what the numbers mean"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("`annual_methods_note'"), font("Arial", 8.5)

putpdf paragraph
putpdf text ("What the BNR measures"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("The standard annual section reports All CVD, Heart and Stroke measures already present in the approved public CVD-event and mortality releases. Results are presented for both sexes combined and, where published, for women and men and broad age groups."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Counting CVD events"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Hospital-recorded events are eligible events identified from the hospital registry source. National event estimates add eligible events identified from death information that are not linked to an eligible hospital event. Primary and Inclusive national event estimates differ in the mortality definition used when identifying the death-record contribution."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Counting CVD deaths"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("The Primary mortality definition includes deaths classified as Clear or Likely CVD. The Inclusive definition additionally includes Possible CVD deaths. Presenting both definitions makes sensitivity to cause-of-death classification visible rather than burying it in a technical note."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Rates"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Crude rates describe the observed number of events or deaths relative to the population. Age-standardised rates apply the published age-specific rates to the WHO World Standard Population 2000-2025, allowing annual patterns to be compared with less influence from changes in population age structure. This report reads the published rates; it does not calculate them again."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Statistical uncertainty"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Published crude-rate confidence intervals use the method recorded in the release, including exact Poisson (Garwood) intervals where applicable. Published directly age-standardised intervals use the stated gamma-based method. The exact method is retained in the public data metadata."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Events identified through death records"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("A death-certificate-only (DCO) event is an eligible event identified from death information without a matching eligible hospital-recorded event. Deterministic linkage and the approved event-window rules are applied upstream in the controlled event workflow. Where linkage is unresolved, the public release supplies an aggregate estimate and its linkage bounds. The annual report displays those published quantities only."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Comparators"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Annual count comparators are the published previous-five-year means supplied by the event and mortality releases. They are descriptive reference values, not statistical control limits. The fixed 2015-2019 monthly seasonal reference used elsewhere in the Information Hub is a separate product and is not substituted for the annual rolling comparator."), font("Arial", 8.5)

putpdf pagebreak
putpdf paragraph
putpdf text ("Methods continued"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("Population and age standardisation"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Published event rates use the population denominator and standardisation metadata carried in the approved release, including UN World Population Prospects 2024 Barbados denominators and the WHO World Standard Population 2000-2025 where specified. The annual report preserves those released estimates rather than rebuilding denominator inputs."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("Protecting confidentiality"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Public datasets have already passed the BNR disclosure-control process before they reach this report. Suppressed values are not reconstructed from related cells. The annual report therefore inherits the public release as its disclosure boundary."), font("Arial", 8.5)

putpdf paragraph
putpdf text ("From data to published statistics"), bold font("Arial", 11, "`bnr_ink'")
putpdf table workflow = (5,2), width(100%) border(all, nil)
putpdf table workflow(1,1) = ("1  PREPARE")
putpdf table workflow(1,2) = ("Versioned source releases and controlled analytical inputs are prepared.")
putpdf table workflow(2,1) = ("2  CALCULATE")
putpdf table workflow(2,2) = ("Stata produces the surveillance measures and structured outputs.")
putpdf table workflow(3,1) = ("3  REVIEW")
putpdf table workflow(3,2) = ("Automated QA and disclosure checks prepare a fixed candidate for human inspection.")
putpdf table workflow(4,1) = ("4  APPROVE")
putpdf table workflow(4,2) = ("Authorised reviewers assess analytical plausibility, disclosure safety and publication readiness.")
putpdf table workflow(5,1) = ("5  PUBLISH")
putpdf table workflow(5,2) = ("Only approved public products are promoted to the Information Hub; this annual report reads those public products.")
putpdf table workflow(.,1), bold font("Arial", 8, "`bnr_teal'")
putpdf table workflow(.,2), font("Arial", 8)

putpdf paragraph
putpdf text ("Report information"), bold font("Arial", 11, "`bnr_ink'")
putpdf table report_info = (4,2), width(82%) border(all, nil)
putpdf table report_info(1,1) = ("Report year")
putpdf table report_info(1,2) = ("`report_year4'")
putpdf table report_info(2,1) = ("CVD-event release")
putpdf table report_info(2,2) = ("`event_release'")
putpdf table report_info(3,1) = ("Mortality release")
putpdf table report_info(3,2) = ("`mortality_release'")
putpdf table report_info(4,1) = ("Standard composition")
putpdf table report_info(4,2) = ("bnr_report_annual_standard.do v2.0.0")
putpdf table report_info(.,1), bold font("Arial", 8, "`bnr_muted'")
putpdf table report_info(.,2), font("Arial", 8)

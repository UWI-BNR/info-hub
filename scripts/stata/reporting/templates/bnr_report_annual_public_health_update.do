/*******************************************************************************
DO-FILE: bnr_report_annual_public_health_update.do
VERSION: 0.1.0 (10 September 2026)
PURPOSE: Compose the one-page public-health update appended to the annual CVD
         report and later extracted as an approved companion PDF.

CALLER:
  bnr_report_annual_s1_build.do only, after the year-specific Special chapter.

BOUNDARY:
  This maintained template selects only values from the two approved public
  release snapshots already validated and cached by the annual report. It does
  not calculate surveillance metrics, inspect confidential data, write a PDF,
  approve a result or publish a product.

ANALYST EDITING:
  Do not edit metric IDs, filters or page structure during routine production.
  Edit the three year-specific Key messages in:
    annual/YYYY/bnr_report_annual_YYYY_interpretation.do
*******************************************************************************/

version 19.0

* -----------------------------------------------------------------------------
* 1. Required report context
* -----------------------------------------------------------------------------

foreach required_local in report_year4 report_year_num event_release mortality_release annual_event_data annual_mortality_data annual_figure_dir {
    if "``required_local''" == "" {
        display as error "Public-health update requires local `required_local'."
        exit 198
    }
}

foreach required_message in annual_phu_message_1 annual_phu_message_2 annual_phu_message_3 {
    if `"``required_message''"' == "" {
        display as error "Public-health update requires year-specific local `required_message'."
        exit 198
    }
}

* Color swatch for CVD profile graphics 
local event_label "CVD"
local event_colour "`bnr_teal'"
if "`event'" == "heart" {
    local event_label "Heart"
    local event_colour "`bnr_heart'"
}
if "`event'" == "stroke" {
    local event_label "Stroke"
    local event_colour "`bnr_stroke'"
}

* -----------------------------------------------------------------------------
* 2. Latest approved headline values
* -----------------------------------------------------------------------------
* INVARIANT METRIC SELECTION - DO NOT EDIT ROUTINELY.
* Each disease card uses the Primary national annual event count and its
* age-standardised event rate, followed by the Primary annual death count and
* age-standardised mortality rate. Published 95% confidence intervals are
* displayed beneath rates. Every selector must resolve to exactly one row.

local phu_selection_error 0

foreach event in all_cvd heart stroke {
    local phu_evt_count_`event' "-"
    local phu_evt_rate_`event' "-"
    local phu_evt_ci_`event' "95% CI not available"
    local phu_death_count_`event' "-"
    local phu_death_rate_`event' "-"
    local phu_death_ci_`event' "95% CI not available"

    use "`annual_event_data'", clear
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "`event'" & ///
        sex == "all" & age_group == "all" & period_complete == 1 & ///
        ascertainment_scope == "hospital_plus_dco" & ///
        mortality_definition == "primary" & statistic == "annual_count"
    quietly count
    if r(N) != 1 {
        display as error "Expected one Primary event-count row for `event' in `report_year4'; found " r(N) "."
        local phu_selection_error 1
    }
    else {
        local phu_tmp : display %9.0fc value[1]
        local phu_evt_count_`event' = strtrim("`phu_tmp'")
    }

    use "`annual_event_data'", clear
    keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "`event'" & ///
        sex == "all" & age_group == "age_standardised" & ///
        period_complete == 1 & ascertainment_scope == "hospital_plus_dco" & ///
        mortality_definition == "primary" & ///
        statistic == "annual_age_standardised_rate"
    quietly count
    if r(N) != 1 {
        display as error "Expected one Primary event-rate row for `event' in `report_year4'; found " r(N) "."
        local phu_selection_error 1
    }
    else {
        local phu_tmp : display %6.0f value[1]
        local phu_evt_rate_`event' = strtrim("`phu_tmp'")
        if !missing(ci_lower_value[1], ci_upper_value[1]) {
            local phu_lo : display %6.0f ci_lower_value[1]
            local phu_hi : display %6.0f ci_upper_value[1]
            local phu_evt_ci_`event' = "95% CI " + strtrim("`phu_lo'") + "-" + strtrim("`phu_hi'")
        }
    }

    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "`event'" & ///
        sex == "all" & age_group == "all" & period_complete == 1 & ///
        case_definition == "primary_clear_likely" & statistic == "annual_count"
    quietly count
    if r(N) != 1 {
        display as error "Expected one Primary death-count row for `event' in `report_year4'; found " r(N) "."
        local phu_selection_error 1
    }
    else {
        local phu_tmp : display %9.0fc value[1]
        local phu_death_count_`event' = strtrim("`phu_tmp'")
    }

    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-RATE-001" & period_type == "annual" & ///
        period_year == `report_year_num' & event_type == "`event'" & ///
        sex == "all" & age_group == "age_standardised" & ///
        period_complete == 1 & case_definition == "primary_clear_likely" & ///
        statistic == "annual_age_standardised_rate"
    quietly count
    if r(N) != 1 {
        display as error "Expected one Primary mortality-rate row for `event' in `report_year4'; found " r(N) "."
        local phu_selection_error 1
    }
    else {
        local phu_tmp : display %6.0f value[1]
        local phu_death_rate_`event' = strtrim("`phu_tmp'")
        if !missing(ci_lower_value[1], ci_upper_value[1]) {
            local phu_lo : display %6.0f ci_lower_value[1]
            local phu_hi : display %6.0f ci_upper_value[1]
            local phu_death_ci_`event' = "95% CI " + strtrim("`phu_lo'") + "-" + strtrim("`phu_hi'")
        }
    }
}

if `phu_selection_error' {
    display as error "Public-health update stopped: one or more required published headline values were missing or duplicated."
    exit 459
}

* -----------------------------------------------------------------------------
* 3A. Compact national event rate trend
* -----------------------------------------------------------------------------
* INVARIANT GRAPH CONTENT. The graph shows the complete published Primary
* national All-CVD event-count series. It is presentation of an approved series,
* not a recalculation. The report year is highlighted automatically.
local phu_trend_fig "`annual_figure_dir'/public_health_update_event_trend.png"
use "`annual_event_data'", clear
keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & ///
    event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & ///
    period_complete == 1 & ascertainment_scope == "hospital_plus_dco" & ///
    mortality_definition == "primary" & statistic == "annual_age_standardised_rate"

* keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & period_complete == 1 & ///
*    ((ascertainment_scope == "hospital_only") | (ascertainment_scope == "hospital_plus_dco" & inlist(mortality_definition, "primary", "inclusive")))


quietly count
if r(N) < 2 {
    display as error "Public-health update requires at least two complete annual Primary CVD event estimates."
    exit 459
}

    #delimit ; 
    twoway 
        (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
        sort color("`event_colour'%15") lw(none))

        (rspike ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
        sort color("`event_colour'") lw(0.4))

        (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
        sort lcolor("`event_colour'") mcolor("`event_colour'") msymbol(O) msize(3) lwidth(1)) 
        ,

    plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
    graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

    xlabel(#6, format(%4.0f) labsize(6.5) noticks nogrid) 
    ylabel(#4, angle(horizontal) labsize(6.5) noticks nogrid) 
    xscale(noline range(2009(1)2026)) 
    yscale(noline) xtitle("") ytitle("") 

    legend(order(3 "National (primary)" 2 "Rate 95% CI" 1 "DCO uncertainty") 
    cols(5) size(6.5) region(lcolor(none)) position(12) ring(1)) 
    xsize(10.0) ysize(3.2)
    name(ph_event_cvd);
    ;
    #delimit cr 
graph export "`phu_trend_fig'", replace width(2600)



* -----------------------------------------------------------------------------
* 3B. Compact national mortality rate trend
* -----------------------------------------------------------------------------
* INVARIANT GRAPH CONTENT. The graph shows the complete published Primary
* national All-CVD event-count series. It is presentation of an approved series,
* not a recalculation. The report year is highlighted automatically.
    local phu_trend_fig2 "`annual_figure_dir'/public_health_update_mort_trend.png"
    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-RATE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & event_type == "all_cvd" & sex == "all" & age_group == "age_standardised" & period_complete == 1 & inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
    quietly count
    if r(N) > 0 {
    
    replace period_year = period_year + 0.05 if case_definition == "upper_clear_likely_possible"
        #delimit ; 
        twoway 
          (rspike ci_lower_value ci_upper_value period_year if case_definition == "primary_clear_likely", 
          sort color("`event_colour'") lw(0.4))

          (rspike ci_lower_value ci_upper_value period_year if case_definition == "upper_clear_likely_possible", 
          sort color("`event_colour'%50") lw(0.4))

          (line value period_year if case_definition == "upper_clear_likely_possible", 
          sort lcolor("`event_colour'%50") lpattern(dash) 
          mcolor("`event_colour'%50") msymbol(O) msize(3) lwidth(0.75))

          (connected value period_year if case_definition == "primary_clear_likely", 
          sort lcolor("`event_colour'") mcolor("`event_colour'") msymbol(O) msize(3) lwidth(1)) 
          ,

		plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
		graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

        xlabel(#6, format(%4.0f) labsize(6.5) noticks nogrid) 
        ylabel(#4, angle(horizontal) labsize(6.5) noticks nogrid) 
        xscale(noline range(2009(1)2026)) 
        yscale(noline) xtitle("") ytitle("") 

        legend(order(4 "National (primary)" 3 "National (inclusive)" 1 "Rate 95% CI") 
        cols(5) size(6.5) region(lcolor(none)) position(12) ring(1)) 
        xsize(10.0) ysize(3.2)
        name(ph_mort_cvd)
        ;
        #delimit cr 
        graph export "`phu_trend_fig2'", replace width(2600)
    }
    

* -----------------------------------------------------------------------------
* 4. Final one-page appendix
* -----------------------------------------------------------------------------
* MAINTAINED PRESENTATION. Keep the exact title text: the finishing helper uses
* it as the controlled extraction anchor. Every occurrence of the year derives
* from report_year4 so a future annual build updates the page automatically.

putpdf pagebreak
putpdf paragraph, font("`font_body'", 1)
putpdf text ("Public health update | CVD in `report_year4'"), ///
    bold font("`font_title'", 16, "`bnr_ink'") linebreak
putpdf text ("Primary national estimates from the latest complete annual results"), ///
    font("`font_body'", 8.6, "`bnr_muted'")

putpdf paragraph, font("`font_body'", 2)
matrix phu_card_widths = (30, 5, 30, 5, 30)
putpdf table phu_cards = (9,5), width(100%) width(phu_card_widths) border(all, nil) halign(center)

forvalues rr = 1/9 {
    putpdf table phu_cards(`rr',2) = ("")
    putpdf table phu_cards(`rr',4) = ("")
}

local phu_col 1
foreach event in all_cvd heart stroke {
    local phu_label "CVD"
    local phu_colour "`bnr_teal'"
    if "`event'" == "heart" {
        local phu_label "Heart"
        local phu_colour "`bnr_heart'"
    }
    if "`event'" == "stroke" {
        local phu_label "Stroke"
        local phu_colour "`bnr_stroke'"
    }

    putpdf table phu_cards(1,`phu_col') = ("`phu_label' EVENTS"), ///
        bold font("`font_title'", 7.2, "`phu_colour'") border(top, single, "`phu_colour'")
    putpdf table phu_cards(2,`phu_col') = ("`phu_evt_count_`event'' events"), ///
        bold font("`font_title'", 13.5, "`bnr_ink'")
    putpdf table phu_cards(3,`phu_col') = ("`phu_evt_rate_`event'' per 100,000"), ///
        bold font("`font_title'", 8.6, "`bnr_ink'")
    putpdf table phu_cards(4,`phu_col') = ("Age-standardised | `phu_evt_ci_`event''"), ///
        font("`font_body'", 6.4, "`bnr_muted'")

    putpdf table phu_cards(6,`phu_col') = ("`phu_label' DEATHS"), ///
        bold font("`font_title'", 7.2, "`phu_colour'") border(top, single, "`phu_colour'")
    putpdf table phu_cards(7,`phu_col') = ("`phu_death_count_`event'' deaths"), ///
        bold font("`font_title'", 13.5, "`bnr_ink'")
    putpdf table phu_cards(8,`phu_col') = ("`phu_death_rate_`event'' per 100,000"), ///
        bold font("`font_title'", 8.6, "`bnr_ink'")
    putpdf table phu_cards(9,`phu_col') = ("Age-standardised | `phu_death_ci_`event''"), ///
        font("`font_body'", 6.4, "`bnr_muted'")

    local phu_col = `phu_col' + 2
}

putpdf table phu_cards(.,.), bgcolor("`bnr_white'")
putpdf table phu_cards(5,.), font("`font_body'", 2)

putpdf paragraph, font("`font_body'", 1)
putpdf text ("National CVD event and mortality rate trends"), ///
    bold font("`font_title'", 9.6, "`bnr_ink'") linebreak
putpdf text ("Age-standardised national rates between 2010 and `report_year4'. The event rate shading represents uncertainty linked to the identification of death certificate only (DCO) events. The inclusive mortality estimate includes deaths for which cardiovascular disease was a possible, but less certain, cause."), ///
    font("`font_body'", 6.8, "`bnr_muted'")

matrix graph_width = (15, 85)
putpdf table phu_trend = (1,2), width(85%) border(all, nil) halign(center) width(graph_width)
putpdf table phu_trend(1,1) = ("Event"), font("`font_body'", 8.6, "`bnr_ink'") linebreak
putpdf table phu_trend(1,1) = ("Rate"), font("`font_body'", 8.6, "`bnr_ink'") append
putpdf table phu_trend(1,2) = image("`phu_trend_fig'")

putpdf table phu_trend_mort = (1,2), width(85%) border(all, nil) halign(center) width(graph_width)
putpdf table phu_trend_mort(1,1) = ("Mortality"), font("`font_body'", 8.6, "`bnr_ink'") linebreak
putpdf table phu_trend_mort(1,1) = ("Rate"), font("`font_body'", 8.6, "`bnr_ink'") append
putpdf table phu_trend_mort(1,2) = image("`phu_trend_fig2'")

putpdf paragraph, font("`font_body'", 1)
putpdf text ("Key messages"), bold font("`font_title'", 9.8, "`bnr_ink'")
matrix phu_message_widths = (8, 92)
putpdf table phu_messages = (3,2), width(100%) width(phu_message_widths) border(all, nil)
forvalues rr = 1/3 {
    putpdf table phu_messages(`rr',1) = ("0`rr'"), ///
        halign(center) bold font("`font_title'", 8.2, "`bnr_teal'")
}
putpdf table phu_messages(1,2) = ("`annual_phu_message_1'"), font("`font_body'", 7.0, "`bnr_ink'")
putpdf table phu_messages(2,2) = ("`annual_phu_message_2'"), font("`font_body'", 7.0, "`bnr_ink'")
putpdf table phu_messages(3,2) = ("`annual_phu_message_3'"), font("`font_body'", 7.0, "`bnr_ink'")

putpdf paragraph, font("`font_body'", 1)
putpdf text ("Source: BNR approved CVD-event release `event_release' and mortality release `mortality_release'. Rates are age-standardised and presented per 100,000. Methods: https://uwi-bnr.github.io/info-hub/methods/"), ///
    font("`font_body'", 6.0, "`bnr_muted'")

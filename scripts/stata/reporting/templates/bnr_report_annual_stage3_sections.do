/*******************************************************************************
DO-FILE: bnr_report_annual_stage3_sections.do
VERSION: 1.0.1 (4 September 2026)
PURPOSE: Disease-specific annual event and mortality sections for the CVD
         annual report. Included only by bnr_report_annual_standard.do.

BOUNDARY:
  Reads only the two approved public release snapshots prepared by Step 1.
  It selects published counts, rates and confidence limits; it does not
  reconstruct All-CVD, calculate rates or inspect confidential components.
*******************************************************************************/

*******************************************************************************
* BNR ANALYST GUIDE - LIVE CHAPTERS 1 AND 2
*
* BNR ANALYST: DO NOT EDIT metric IDs, filters, definitions or loop structure
* during routine annual production. This maintained template creates the live
* Events and Mortality pages for All CVD, Heart and Stroke. Each page follows
* the same order: heading/deck, latest-year cards, full-series graphic,
* latest-five-year table and year-specific "WHAT THIS MEANS" narrative.
*
* Narrative is deliberately not authored here. Edit the corresponding locals
* in annual/YYYY/bnr_report_annual_YYYY_interpretation.do.
*
* Graph-format refinements are template-development changes. If undertaken,
* preserve the existing data filters and uncertainty-layer order, then inspect
* every repeated All-CVD/Heart/Stroke page in a newly versioned candidate.
*******************************************************************************

* -----------------------------------------------------------------------------
* 1. Events: All-CVD, Heart and Stroke
* -----------------------------------------------------------------------------

* CHAPTER 1 REPEATING STRUCTURE - DO NOT CHANGE THE LOOP ROUTINELY.
* The event token controls the public event_type filter, reader-facing label
* and accent colour. The loop prevents the three disease sections drifting into
* different definitions or layouts.

foreach event in all_cvd heart stroke {

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

    * EVENTS / COUNT PAGE -----------------------------------------------------
    * INVARIANT DATA SELECTION: published annual CVD-BURDEN-001 rows for the
    * current event type, all sexes and all ages. The graphic compares the
    * hospital-recorded, Primary national and Inclusive national series and the
    * published previous-five-year mean. The cards show the report year; the
    * table shows the latest five complete years. Do not add subtype rows.
    local fig "`annual_figure_dir'/stage3_event_`event'_counts.png"
    use "`annual_event_data'", clear
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & ///
        event_type == "`event'" & sex == "all" & age_group == "all" & ///
        period_complete == 1 & ///
        ((ascertainment_scope == "hospital_only" & inlist(statistic, "annual_count", "annual_previous_5yr_mean")) | ///
         (ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_count") | ///
         (ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive" & statistic == "annual_count"))
    quietly count
    if r(N) > 0 {
        #delimit ;
        twoway
	      (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_count" , 
          sort lw(none) color("`event_colour'%15"))

          (line value period_year if ascertainment_scope == "hospital_only" & statistic == "annual_count", 
          sort lcolor("`bnr_muted'") mcolor("`bnr_muted'") lwidth(0.75)) 

          (line value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", 
          sort lcolor("`event_colour'%50") mcolor("`event_colour'%50") lwidth(0.75)) 

          (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
          sort lcolor("`event_colour'") mcolor("`event_colour'") msymbol(O) msize(3) lwidth(1)) 
          
          /// (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", 
          /// sort lcolor("`event_colour'%70") mcolor("`event_colour'%70") msymbol(O) msize(vsmall) lpattern(dash) lwidth(medthick)) 
          
          /// (line value period_year if ascertainment_scope == "hospital_only" & statistic == "annual_previous_5yr_mean",
          /// sort lcolor("`bnr_secondary'%70") lpattern(shortdash) lwidth(thin))
          , 
		plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
		graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))

        xlabel(#6, format(%4.0f) labsize(6) noticks nogrid) 
        ylabel(#4, angle(horizontal) labsize(6) noticks nogrid) 
        xscale(noline range(2009(1)2026)) 
        yscale(noline) xtitle("") ytitle("") 
        
        legend(order(4 "National (primary)" 3 "National (inclusive)" 2 "Hospital" 1 "DCO uncertainty") 
        cols(4) size(5) region(lcolor(none)) position(12) ring(1)) 
        
        xsize(10.0) ysize(3.2)
        name(count_`event')
        ;
        #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    local primary "-"
    local inclusive "-"
    local hospital "-"
    use "`annual_event_data'", clear
    foreach spec in hospital primary inclusive {
        preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & ///
            event_type == "`event'" & sex == "all" & age_group == "all" & statistic == "annual_count"
        if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
        if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
        if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            local `spec' = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    if "`event'" == "all_cvd" {
        putpdf text ("1 | CVD events"), bold font("`font_title'", `size_chapter', "`bnr_ink'") linebreak
    }
    putpdf text ("`event_label' event counts"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Hospital-recorded events and published national estimates across the complete annual series."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table evt_`event'_count_cards = (2,3), width(100%) border(all, nil)
    putpdf table evt_`event'_count_cards(1,1) = ("Hospital-recorded")
    putpdf table evt_`event'_count_cards(1,2) = ("Primary national")
    putpdf table evt_`event'_count_cards(1,3) = ("Inclusive national")
    putpdf table evt_`event'_count_cards(2,1) = ("`hospital'")
    putpdf table evt_`event'_count_cards(2,2) = ("`primary'")
    putpdf table evt_`event'_count_cards(2,3) = ("`inclusive'")
    putpdf table evt_`event'_count_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table evt_`event'_count_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table evt_`event'_count_cards(.,.), bgcolor("`bnr_white'")
    putpdf table evt_`event'_count_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table evt_`event'_count_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table evt_`event'_count_fig(1,1) = image("`fig'")
    }
    putpdf table evt_`event'_count_tab = (4,6), width(100%) border(all, nil)
    putpdf table evt_`event'_count_tab(1,1) = ("Measure")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table evt_`event'_count_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach spec in hospital primary inclusive {
        local ++row
        local label "Hospital-recorded"
        if "`spec'" == "primary" local label "Primary national"
        if "`spec'" == "inclusive" local label "Inclusive national"
        putpdf table evt_`event'_count_tab(`row',1) = ("`label'")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local cell "-"
            use "`annual_event_data'", clear
            keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "all" & age_group == "all" & statistic == "annual_count"
            if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
            if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
            if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
            quietly count
            if r(N) == 1 {
                local tmp : display %8.0fc value[1]
                local cell = strtrim("`tmp'")
            }
            putpdf table evt_`event'_count_tab(`row',`cc') = ("`cell'")
        }
    }
    putpdf table evt_`event'_count_tab(.,.), font("`font_body'", 7.2)
    putpdf table evt_`event'_count_tab(1,.), bold font("`font_title'", 7.2, "`bnr_ink'") border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table evt_`event'_count_tab(.,1), bold
    putpdf paragraph, font("`font_body'", 1)
    local table_note "`ann_evt_counts_text'"
    if "`event'" == "heart" local table_note "`ann_evt_heart_counts_text'"
    if "`event'" == "stroke" local table_note "`ann_evt_stroke_counts_text'"
    putpdf table evt_`event'_count_note = (2,1), width(100%) border(all, nil)
    putpdf table evt_`event'_count_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table evt_`event'_count_note(2,1) = ("`table_note'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table evt_`event'_count_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")




    * EVENTS / AGE-STANDARDISED RATE PAGE ------------------------------------
    * INVARIANT DATA SELECTION: published annual CVD-INCIDENCE-001 ASRs for all
    * sexes. Transparent rarea confidence bands are deliberately plotted before
    * their connected estimate lines so uncertainty remains behind the data.
    * Do not recalculate rates or confidence limits in this report template.
    local fig "`annual_figure_dir'/stage3_event_`event'_rates.png"
    use "`annual_event_data'", clear
    keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & period_complete == 1 & ///
        ((ascertainment_scope == "hospital_only") | (ascertainment_scope == "hospital_plus_dco" & inlist(mortality_definition, "primary", "inclusive")))
    quietly count
    if r(N) > 0 {
        #delimit ; 
        twoway 
          (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
          sort color("`event_colour'%15") lw(none))

          (rspike ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
          sort color("`event_colour'") lw(0.4))

          (line value period_year if ascertainment_scope == "hospital_only", 
          sort lcolor("`bnr_muted'") mcolor("`bnr_muted'") msymbol(O) msize(3) lwidth(0.75)) 

          (line value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive", 
          sort lcolor("`event_colour'%70") mcolor("`event_colour'%70") msymbol(O) msize(3) lpattern(dash) lwidth(0.75))

          (connected value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary", 
          sort lcolor("`event_colour'") mcolor("`event_colour'") msymbol(O) msize(3) lwidth(1)) 
          ,

		plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
		graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

        xlabel(#6, format(%4.0f) labsize(6) noticks nogrid) 
        ylabel(#4, angle(horizontal) labsize(6) noticks nogrid) 
        xscale(noline range(2009(1)2026)) 
        yscale(noline) xtitle("") ytitle("") 

        legend(order(5 "National (primary)" 4 "National (inclusive)" 3 "Hospital" 2 "Rate 95% CI" 1 "DCO uncertainty") 
        cols(5) size(5) region(lcolor(none)) position(12) ring(1)) 
        xsize(10.0) ysize(3.2)
        name(rate_`event');
        ;
        #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    local primary "-"
    local inclusive "-"
    local hospital "-"
    use "`annual_event_data'", clear
    foreach spec in hospital primary inclusive {
        preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
        if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
        if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
        if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local `spec' = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    putpdf text ("`event_label' event rates"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Age-standardised rates per 100,000. Whiskers are published 95% statistical confidence intervals."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table evt_`event'_rate_cards = (2,3), width(100%) border(all, nil)
    putpdf table evt_`event'_rate_cards(1,1) = ("Hospital-recorded ASR")
    putpdf table evt_`event'_rate_cards(1,2) = ("Primary national ASR")
    putpdf table evt_`event'_rate_cards(1,3) = ("Inclusive national ASR")
    putpdf table evt_`event'_rate_cards(2,1) = ("`hospital'")
    putpdf table evt_`event'_rate_cards(2,2) = ("`primary'")
    putpdf table evt_`event'_rate_cards(2,3) = ("`inclusive'")
    putpdf table evt_`event'_rate_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table evt_`event'_rate_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table evt_`event'_rate_cards(.,.), bgcolor("`bnr_white'")
    putpdf table evt_`event'_rate_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table evt_`event'_rate_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table evt_`event'_rate_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table evt_`event'_rate_tab = (7,6), width(100%) border(all, nil)
    putpdf table evt_`event'_rate_tab(1,1) = ("ASR per 100,000")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table evt_`event'_rate_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach spec in hospital primary inclusive {
        local ++row
        local label "Hospital-recorded"
        if "`spec'" == "primary" local label "Primary national"
        if "`spec'" == "inclusive" local label "Inclusive national"
        putpdf table evt_`event'_rate_tab(`row',1) = ("`label' estimate")
        local cirow = `row' + 1
        putpdf table evt_`event'_rate_tab(`cirow',1) = ("`label' 95% CI")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local estimate "-"
            local interval "-"
            use "`annual_event_data'", clear
            keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
            if "`spec'" == "hospital" keep if ascertainment_scope == "hospital_only"
            if "`spec'" == "primary" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary"
            if "`spec'" == "inclusive" keep if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "inclusive"
            quietly count
            if r(N) == 1 {
                local est : display %5.1f value[1]
                local lo : display %5.1f ci_lower_value[1]
                local hi : display %5.1f ci_upper_value[1]
                local estimate = strtrim("`est'")
                local interval = strtrim("`lo'") + " - " + strtrim("`hi'")
            }
            putpdf table evt_`event'_rate_tab(`row',`cc') = ("`estimate'")
            putpdf table evt_`event'_rate_tab(`cirow',`cc') = ("`interval'")
        }
        local row = `cirow'
    }
    putpdf table evt_`event'_rate_tab(.,.), font("`font_body'", 6.7)
    putpdf table evt_`event'_rate_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table evt_`event'_rate_tab(.,2/6), halign(center)
    putpdf table evt_`event'_rate_tab(.,1), bold
    local table_note "`ann_evt_rates_text'"
    if "`event'" == "heart" local table_note "`ann_evt_heart_rates_text'"
    if "`event'" == "stroke" local table_note "`ann_evt_stroke_rates_text'"
    putpdf paragraph, font("`font_body'", 1)
    putpdf table evt_`event'_rate_note = (2,1), width(100%) border(all, nil)
    putpdf table evt_`event'_rate_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table evt_`event'_rate_note(2,1) = ("`table_note'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table evt_`event'_rate_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")




    * EVENTS / WOMEN AND MEN PAGE --------------------------------------------
    * INVARIANT DATA SELECTION: Primary national age-standardised event rates
    * for All sexes, Women and Men. The graphic shows Women and Men; cards and
    * table retain All sexes for context. Confidence bands precede estimate
    * lines. Narrative comes from the year-specific interpretation local.
    local fig "`annual_figure_dir'/stage3_event_`event'_sex.png"
    use "`annual_event_data'", clear
    keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & event_type == "`event'" & inlist(sex, "female", "male") & age_group == "age_standardised" & ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & period_complete == 1
    quietly count
    if r(N) > 0 {

    #delimit ; 
        twoway ///
          (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & sex=="female", 
          sort color("`bnr_women_`event''%15") lw(none))

          (rarea linkage_lower_value linkage_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & sex=="male", 
          sort color("`bnr_men_`event''%15") lw(none))

          (rspike ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & sex=="female", 
          sort color("`bnr_women_`event''") lw(0.4))

          (rspike ci_lower_value ci_upper_value period_year if ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & sex=="male", 
          sort color("`bnr_men_`event''") lw(0.4))

          (connected value period_year if sex == "female", 
          sort lcolor("`bnr_women_`event''") mcolor("`bnr_women_`event''") msymbol(O) msize(3) lwidth(1))

          (connected value period_year if sex == "male", 
          sort lcolor("`bnr_men_`event''") mcolor("`bnr_men_`event''") msymbol(O) msize(3) lwidth(1))
          ,

  		  plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
		  graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

          xlabel(#6, format(%4.0f) labsize(6) noticks nogrid) 
          ylabel(#4, angle(horizontal) labsize(6) noticks nogrid) 
          xscale(noline range(2009(1)2026)) 
          yscale(noline) xtitle("") ytitle("") 

          legend(order(5 "Women" 6 "Men" 4 "Rate 95% CI" 2 "DCO uncertainty") cols(4) size(5) region(lcolor(none)) position(12) ring(1)) 

          xsize(10.0) ysize(3.2)
          name(sex_`event')
          ;
    #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    local all "-"
    local female "-"
    local male "-"
    use "`annual_event_data'", clear
    foreach sex in all female male {
        preserve
        keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "`sex'" & age_group == "age_standardised" & ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local `sex' = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    putpdf text ("`event_label' events: women and men"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Primary national age-standardised event rates per 100,000."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table evt_`event'_sex_cards = (2,3), width(100%) border(all, nil)
    putpdf table evt_`event'_sex_cards(1,1) = ("All sexes")
    putpdf table evt_`event'_sex_cards(1,2) = ("Women")
    putpdf table evt_`event'_sex_cards(1,3) = ("Men")
    putpdf table evt_`event'_sex_cards(2,1) = ("`all'")
    putpdf table evt_`event'_sex_cards(2,2) = ("`female'")
    putpdf table evt_`event'_sex_cards(2,3) = ("`male'")
    putpdf table evt_`event'_sex_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table evt_`event'_sex_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table evt_`event'_sex_cards(.,.), bgcolor("`bnr_white'")
    putpdf table evt_`event'_sex_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table evt_`event'_sex_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table evt_`event'_sex_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table evt_`event'_sex_tab = (7,6), width(100%) border(all, nil)
    putpdf table evt_`event'_sex_tab(1,1) = ("Primary ASR per 100,000")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table evt_`event'_sex_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach sex in all female male {
        local ++row
        local label "All sexes"
        if "`sex'" == "female" local label "Women"
        if "`sex'" == "male" local label "Men"
        putpdf table evt_`event'_sex_tab(`row',1) = ("`label' estimate")
        local cirow = `row' + 1
        putpdf table evt_`event'_sex_tab(`cirow',1) = ("`label' 95% CI")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local estimate "-"
            local interval "-"
            use "`annual_event_data'", clear
            keep if metric_id == "CVD-INCIDENCE-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "`sex'" & age_group == "age_standardised" & ascertainment_scope == "hospital_plus_dco" & mortality_definition == "primary" & statistic == "annual_age_standardised_rate"
            quietly count
            if r(N) == 1 {
                local est : display %5.1f value[1]
                local lo : display %5.1f ci_lower_value[1]
                local hi : display %5.1f ci_upper_value[1]
                local estimate = strtrim("`est'")
                local interval = strtrim("`lo'") + " - " + strtrim("`hi'")
            }
            putpdf table evt_`event'_sex_tab(`row',`cc') = ("`estimate'")
            putpdf table evt_`event'_sex_tab(`cirow',`cc') = ("`interval'")
        }
        local row = `cirow'
    }
    putpdf table evt_`event'_sex_tab(.,.), font("`font_body'", 7)
    putpdf table evt_`event'_sex_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table evt_`event'_sex_tab(.,2/6), halign(center)
    putpdf table evt_`event'_sex_tab(.,1), bold
    local table_note "`ann_evt_sex_text'"
    if "`event'" == "heart" local table_note "`ann_evt_heart_sex_text'"
    if "`event'" == "stroke" local table_note "`ann_evt_stroke_sex_text'"
    putpdf paragraph, font("`font_body'", 1)
    putpdf table evt_`event'_sex_note = (2,1), width(100%) border(all, nil)
    putpdf table evt_`event'_sex_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table evt_`event'_sex_note(2,1) = ("`table_note'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table evt_`event'_sex_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")





    if "`event'" == "all_cvd" {
    * EVENTS / AGE-PATTERN PAGE ----------------------------------------------
    * INVARIANT DATA SELECTION: hospital-recorded counts for All ages, Under 70
    * and 70 and older. These are composition counts, not age-specific rates.
    * This page exists only for All CVD because approved Heart/Stroke age rows
    * are not available; do not remove the enclosing All-CVD condition.
    local fig "`annual_figure_dir'/stage3_event_`event'_age.png"
    use "`annual_event_data'", clear
    keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & statistic == "annual_count" & event_type == "`event'" ///
    & sex == "all" & inlist(age_group, "under_70", "age_70_plus") & ascertainment_scope == "hospital_only" & period_complete == 1

    quietly count
    if r(N) > 0 {
        keep period_year age_group value
        reshape wide value, i(period_year) j(age_group) string
        capture confirm variable valueunder_70
        if !_rc label variable valueunder_70 "Under 70"
        capture confirm variable valueage_70_plus
        if !_rc label variable valueage_70_plus "70 and older"

        #delimit ; 
            graph bar valueunder_70 valueage_70_plus, over(period_year, 
            label(angle(35) labsize(6) labgap(3)) 
            relabel(2 " " 4 " " 6 " " 8 " " 10 " " 12 " " 14 " " 16 " ")) stack 

            bar(1, color("`bnr_under70'%82")) 
            bar(2, color("`bnr_70plus'%82")) 

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

            ytitle("") 
            ylabel(#3, angle(horizontal) labsize(6) noticks nogrid) 
            yscale(noline) 
            
            legend(order(1 "Under 70" 2 "70 and older")
                cols(2) size(5) region(lcolor(none)) position(12) ring(1)) 
            
            xsize(10.0) ysize(3.15)
            name(age_`event')
        ;
        #delimit cr 
        graph export "`fig'", replace width(2600)
    }

    local all "-"
    local under "-"
    local older "-"
    use "`annual_event_data'", clear
    foreach age in all under_70 age_70_plus {
        preserve
        keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "all" & age_group == "`age'" & ascertainment_scope == "hospital_only" & statistic == "annual_count"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            if "`age'" == "all" local all = strtrim("`tmp'")
            if "`age'" == "under_70" local under = strtrim("`tmp'")
            if "`age'" == "age_70_plus" local older = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    putpdf text ("`event_label' events: age patterns"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Hospital-recorded annual event counts by broad age group. These are composition counts, not age-specific rates."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table evt_`event'_age_cards = (2,3), width(100%) border(all, nil)
    putpdf table evt_`event'_age_cards(1,1) = ("All ages")
    putpdf table evt_`event'_age_cards(1,2) = ("Under 70")
    putpdf table evt_`event'_age_cards(1,3) = ("70 and older")
    putpdf table evt_`event'_age_cards(2,1) = ("`all'")
    putpdf table evt_`event'_age_cards(2,2) = ("`under'")
    putpdf table evt_`event'_age_cards(2,3) = ("`older'")
    putpdf table evt_`event'_age_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table evt_`event'_age_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table evt_`event'_age_cards(.,.), bgcolor("`bnr_white'")
    putpdf table evt_`event'_age_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table evt_`event'_age_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table evt_`event'_age_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table evt_`event'_age_tab = (4,6), width(100%) border(all, nil)
    putpdf table evt_`event'_age_tab(1,1) = ("Hospital-recorded events")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table evt_`event'_age_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach age in all under_70 age_70_plus {
        local ++row
        local label "All ages"
        if "`age'" == "under_70" local label "Under 70"
        if "`age'" == "age_70_plus" local label "70 and older"
        putpdf table evt_`event'_age_tab(`row',1) = ("`label'")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local cell "-"
            use "`annual_event_data'", clear
            keep if metric_id == "CVD-BURDEN-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "all" & age_group == "`age'" & ascertainment_scope == "hospital_only" & statistic == "annual_count"
            quietly count
            if r(N) == 1 {
                local tmp : display %8.0fc value[1]
                local cell = strtrim("`tmp'")
            }
            putpdf table evt_`event'_age_tab(`row',`cc') = ("`cell'")
        }
    }
    putpdf table evt_`event'_age_tab(.,.), font("`font_body'", 7.2)
    putpdf table evt_`event'_age_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table evt_`event'_age_tab(.,2/6), halign(center)
    putpdf table evt_`event'_age_tab(.,1), bold
    putpdf paragraph, font("`font_body'", 1)
    putpdf table evt_`event'_age_note = (2,1), width(100%) border(all, nil)
    putpdf table evt_`event'_age_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table evt_`event'_age_note(2,1) = ("`ann_evt_age_text'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table evt_`event'_age_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")
    }
}


* -----------------------------------------------------------------------------
* 2. Mortality: All-CVD, Heart and Stroke
* -----------------------------------------------------------------------------

* CHAPTER 2 REPEATING STRUCTURE - DO NOT CHANGE THE LOOP ROUTINELY.
* The same event tokens are applied to the approved mortality release. Primary
* and Inclusive are alternative nested definitions and must never be added.

foreach event in all_cvd heart stroke {
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



    * MORTALITY / DEATH-COUNT PAGE -------------------------------------------
    * INVARIANT DATA SELECTION: published MORT-BURDEN-001 annual counts for all
    * sexes and all ages. Primary means Clear + Likely; Inclusive additionally
    * includes Possible deaths. The chart and five-year table show both.
    local fig "`annual_figure_dir'/stage3_death_`event'_counts.png"
    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & event_type == "`event'" & sex == "all" & age_group == "all" & ///
            period_complete == 1 & inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible") & /// 
            inlist(statistic, "annual_count", "annual_previous_5yr_mean")
    quietly count
    gen value_lower = value if case_definition == "primary_clear_likely" & statistic == "annual_count"
    gen value_upper = value if case_definition == "upper_clear_likely_possible" & statistic == "annual_count"

    * Align the two boundaries onto every row for the same year.
    bysort period_year: egen rarea_lower = max(value_lower)
    bysort period_year: egen rarea_upper = max(value_upper)

    if r(N) > 0 {
        #delimit ;
        twoway
        (rarea rarea_lower rarea_upper period_year if case_definition == "primary_clear_likely" & statistic == "annual_count" 
        & !missing(rarea_lower, rarea_upper), sort lw(none) color("`event_colour'%15"))

          (line value period_year if case_definition == "upper_clear_likely_possible" & statistic == "annual_count", 
          sort lcolor("`event_colour'%50") mcolor("`event_colour'%50") lwidth(0.75)) 

          (connected value period_year if case_definition == "primary_clear_likely" & statistic == "annual_count", 
          sort lcolor("`event_colour'") mcolor("`event_colour'") msymbol(O) msize(3) lwidth(1)) 
          , 
		plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
		graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))

        xlabel(#6, format(%4.0f) labsize(6) noticks nogrid) 
        ylabel(#4, angle(horizontal) labsize(6) noticks nogrid) 
        xscale(noline range(2009(1)2026)) 
        yscale(noline) xtitle("") ytitle("") 
        
        legend(order(3 "Deaths (primary)" 2 "Deaths (inclusive)" 1 "Difference between primary & inclusive") 
        cols(4) size(5) region(lcolor(none)) position(12) ring(1)) 
        
        xsize(10.0) ysize(3.2)
        name(count_mort_`event')
        ;
        #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    local primary "-"
    local inclusive "-"
    use "`annual_mortality_data'", clear
    foreach spec in primary inclusive {
        preserve
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "all" & age_group == "all" & statistic == "annual_count"
        if "`spec'" == "primary" keep if case_definition == "primary_clear_likely"
        if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            local `spec' = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    if "`event'" == "all_cvd" {
        putpdf text ("2 | CVD mortality"), bold font("`font_title'", `size_chapter', "`bnr_ink'") linebreak
    }
    putpdf text ("`event_label' deaths"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Primary = Clear + Likely CVD deaths. Inclusive = Clear + Likely + Possible CVD deaths."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table mort_`event'_count_cards = (2,2), width(70%) border(all, nil)
    putpdf table mort_`event'_count_cards(1,1) = ("Primary deaths")
    putpdf table mort_`event'_count_cards(1,2) = ("Inclusive deaths")
    putpdf table mort_`event'_count_cards(2,1) = ("`primary'")
    putpdf table mort_`event'_count_cards(2,2) = ("`inclusive'")
    putpdf table mort_`event'_count_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table mort_`event'_count_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table mort_`event'_count_cards(.,.), bgcolor("`bnr_white'")
    putpdf table mort_`event'_count_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table mort_`event'_count_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table mort_`event'_count_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table mort_`event'_count_tab = (3,6), width(100%) border(all, nil)
    putpdf table mort_`event'_count_tab(1,1) = ("Deaths")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table mort_`event'_count_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach spec in primary inclusive {
        local ++row
        local label "Primary"
        if "`spec'" == "inclusive" local label "Inclusive"
        putpdf table mort_`event'_count_tab(`row',1) = ("`label'")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local cell "-"
            use "`annual_mortality_data'", clear
            keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "all" & age_group == "all" & statistic == "annual_count"
            if "`spec'" == "primary" keep if case_definition == "primary_clear_likely"
            if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible"
            quietly count
            if r(N) == 1 {
                local tmp : display %8.0fc value[1]
                local cell = strtrim("`tmp'")
            }
            putpdf table mort_`event'_count_tab(`row',`cc') = ("`cell'")
        }
    }
    putpdf table mort_`event'_count_tab(.,.), font("`font_body'", 7.2)
    putpdf table mort_`event'_count_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table mort_`event'_count_tab(.,2/6), halign(center)
    putpdf table mort_`event'_count_tab(.,1), bold
    local table_note "`ann_mort_counts_text'"
    if "`event'" == "heart" local table_note "`ann_mort_heart_counts_text'"
    if "`event'" == "stroke" local table_note "`ann_mort_stroke_counts_text'"
    putpdf paragraph, font("`font_body'", 1)
    putpdf table mort_`event'_count_note = (2,1), width(100%) border(all, nil)
    putpdf table mort_`event'_count_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table mort_`event'_count_note(2,1) = ("`table_note'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table mort_`event'_count_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")



    * MORTALITY / AGE-STANDARDISED RATE PAGE ---------------------------------
    * INVARIANT DATA SELECTION: published MORT-RATE-001 ASMRs for all sexes.
    * Primary and Inclusive confidence bands are drawn first and their estimate
    * lines second. Definition differences are not confidence intervals.
    local fig "`annual_figure_dir'/stage3_death_`event'_rates.png"
    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-RATE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & period_complete == 1 & inlist(case_definition, "primary_clear_likely", "upper_clear_likely_possible")
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

        xlabel(#6, format(%4.0f) labsize(6) noticks nogrid) 
        ylabel(#4, angle(horizontal) labsize(6) noticks nogrid) 
        xscale(noline range(2009(1)2026)) 
        yscale(noline) xtitle("") ytitle("") 

        legend(order(4 "National (primary)" 3 "National (inclusive)" 1 "Rate 95% CI") 
        cols(5) size(5) region(lcolor(none)) position(12) ring(1)) 
        xsize(10.0) ysize(3.2)
        name(rate_mort_`event');
        ;
        #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    
    local primary "-"
    local inclusive "-"
    use "`annual_mortality_data'", clear
    foreach spec in primary inclusive {
        preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
        if "`spec'" == "primary" keep if case_definition == "primary_clear_likely"
        if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local `spec' = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    putpdf text ("`event_label' mortality rates"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Primary and Inclusive age-standardised mortality rates per 100,000. Whiskers are published 95% statistical confidence intervals."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table mort_`event'_rate_cards = (2,2), width(70%) border(all, nil)
    putpdf table mort_`event'_rate_cards(1,1) = ("Primary ASMR")
    putpdf table mort_`event'_rate_cards(1,2) = ("Inclusive ASMR")
    putpdf table mort_`event'_rate_cards(2,1) = ("`primary'")
    putpdf table mort_`event'_rate_cards(2,2) = ("`inclusive'")
    putpdf table mort_`event'_rate_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table mort_`event'_rate_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table mort_`event'_rate_cards(.,.), bgcolor("`bnr_white'")
    putpdf table mort_`event'_rate_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table mort_`event'_rate_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table mort_`event'_rate_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table mort_`event'_rate_tab = (5,6), width(100%) border(all, nil)
    putpdf table mort_`event'_rate_tab(1,1) = ("ASMR per 100,000")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table mort_`event'_rate_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach spec in primary inclusive {
        local ++row
        local label "Primary"
        if "`spec'" == "inclusive" local label "Inclusive"
        putpdf table mort_`event'_rate_tab(`row',1) = ("`label' estimate")
        local cirow = `row' + 1
        putpdf table mort_`event'_rate_tab(`cirow',1) = ("`label' 95% CI")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local estimate "-"
            local interval "-"
            use "`annual_mortality_data'", clear
            keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "all" & age_group == "age_standardised" & statistic == "annual_age_standardised_rate"
            if "`spec'" == "primary" keep if case_definition == "primary_clear_likely"
            if "`spec'" == "inclusive" keep if case_definition == "upper_clear_likely_possible"
            quietly count
            if r(N) == 1 {
                local est : display %5.1f value[1]
                local lo : display %5.1f ci_lower_value[1]
                local hi : display %5.1f ci_upper_value[1]
                local estimate = strtrim("`est'")
                local interval = strtrim("`lo'") + " - " + strtrim("`hi'")
            }
            putpdf table mort_`event'_rate_tab(`row',`cc') = ("`estimate'")
            putpdf table mort_`event'_rate_tab(`cirow',`cc') = ("`interval'")
        }
        local row = `cirow'
    }
    putpdf table mort_`event'_rate_tab(.,.), font("`font_body'", 6.7)
    putpdf table mort_`event'_rate_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table mort_`event'_rate_tab(.,2/6), halign(center)
    putpdf table mort_`event'_rate_tab(.,1), bold
    local table_note "`ann_mort_rates_text'"
    if "`event'" == "heart" local table_note "`ann_mort_heart_rates_text'"
    if "`event'" == "stroke" local table_note "`ann_mort_stroke_rates_text'"
    putpdf paragraph, font("`font_body'", 1)
    putpdf table mort_`event'_rate_note = (2,1), width(100%) border(all, nil)
    putpdf table mort_`event'_rate_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table mort_`event'_rate_note(2,1) = ("`table_note'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table mort_`event'_rate_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")




    * MORTALITY / WOMEN AND MEN PAGE -----------------------------------------
    * INVARIANT DATA SELECTION: Primary-definition MORT-RATE-001 ASMRs only.
    * All sexes provides context in cards/table; the graphic compares Women and
    * Men. Do not substitute Inclusive values without an approved redesign.
    local fig "`annual_figure_dir'/stage3_death_`event'_sex.png"
    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-RATE-001" & period_type == "annual" & statistic == "annual_age_standardised_rate" & event_type == "`event'" & inlist(sex, "female", "male") & age_group == "age_standardised" & case_definition == "primary_clear_likely" & period_complete == 1
    replace period_year = period_year + 0.05 if sex == "male"
    quietly count
    if r(N) > 0 {
    #delimit ; 
        twoway ///
          (rspike ci_lower_value ci_upper_value period_year if sex=="female", 
          sort color("`bnr_women_`event''") lw(0.4))

          (rspike ci_lower_value ci_upper_value period_year if sex=="male", 
          sort color("`bnr_men_`event''") lw(0.4))

          (connected value period_year if sex == "female", 
          sort lcolor("`bnr_women_`event''") mcolor("`bnr_women_`event''") msymbol(O) msize(3) lwidth(1))

          (connected value period_year if sex == "male", 
          sort lcolor("`bnr_men_`event''") mcolor("`bnr_men_`event''") msymbol(O) msize(3) lwidth(1))
          ,

  		  plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
		  graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

          xlabel(#6, format(%4.0f) labsize(6) noticks nogrid) 
          ylabel(#4, angle(horizontal) labsize(6) noticks nogrid) 
          xscale(noline range(2009(1)2026)) 
          yscale(noline) xtitle("") ytitle("") 

          legend(order(5 "Women" 6 "Men" 4 "Rate 95% CI" 2 "DCO uncertainty") cols(4) size(5) region(lcolor(none)) position(12) ring(1)) 

          xsize(10.0) ysize(3.2)
          name(sex_mort_`event')
          ;
    #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    local all "-"
    local female "-"
    local male "-"
    use "`annual_mortality_data'", clear
    foreach sex in all female male {
        preserve
        keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "`sex'" & age_group == "age_standardised" & case_definition == "primary_clear_likely" & statistic == "annual_age_standardised_rate"
        quietly count
        if r(N) == 1 {
            local tmp : display %6.1f value[1]
            local `sex' = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    putpdf text ("`event_label' deaths: women and men"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Primary age-standardised mortality rates per 100,000."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table mort_`event'_sex_cards = (2,3), width(100%) border(all, nil)
    putpdf table mort_`event'_sex_cards(1,1) = ("All sexes")
    putpdf table mort_`event'_sex_cards(1,2) = ("Women")
    putpdf table mort_`event'_sex_cards(1,3) = ("Men")
    putpdf table mort_`event'_sex_cards(2,1) = ("`all'")
    putpdf table mort_`event'_sex_cards(2,2) = ("`female'")
    putpdf table mort_`event'_sex_cards(2,3) = ("`male'")
    putpdf table mort_`event'_sex_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table mort_`event'_sex_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table mort_`event'_sex_cards(.,.), bgcolor("`bnr_white'")
    putpdf table mort_`event'_sex_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table mort_`event'_sex_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table mort_`event'_sex_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table mort_`event'_sex_tab = (7,6), width(100%) border(all, nil)
    putpdf table mort_`event'_sex_tab(1,1) = ("Primary ASMR per 100,000")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table mort_`event'_sex_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach sex in all female male {
        local ++row
        local label "All sexes"
        if "`sex'" == "female" local label "Women"
        if "`sex'" == "male" local label "Men"
        putpdf table mort_`event'_sex_tab(`row',1) = ("`label' estimate")
        local cirow = `row' + 1
        putpdf table mort_`event'_sex_tab(`cirow',1) = ("`label' 95% CI")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local estimate "-"
            local interval "-"
            use "`annual_mortality_data'", clear
            keep if metric_id == "MORT-RATE-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "`sex'" & age_group == "age_standardised" & case_definition == "primary_clear_likely" & statistic == "annual_age_standardised_rate"
            quietly count
            if r(N) == 1 {
                local est : display %5.1f value[1]
                local lo : display %5.1f ci_lower_value[1]
                local hi : display %5.1f ci_upper_value[1]
                local estimate = strtrim("`est'")
                local interval = strtrim("`lo'") + " - " + strtrim("`hi'")
            }
            putpdf table mort_`event'_sex_tab(`row',`cc') = ("`estimate'")
            putpdf table mort_`event'_sex_tab(`cirow',`cc') = ("`interval'")
        }
        local row = `cirow'
    }
    putpdf table mort_`event'_sex_tab(.,.), font("`font_body'", 6.7)
    putpdf table mort_`event'_sex_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table mort_`event'_sex_tab(.,2/6), halign(center)
    putpdf table mort_`event'_sex_tab(.,1), bold
    local table_note "`ann_mort_sex_text'"
    if "`event'" == "heart" local table_note "`ann_mort_heart_sex_text'"
    if "`event'" == "stroke" local table_note "`ann_mort_stroke_sex_text'"
    putpdf paragraph, font("`font_body'", 1)
    putpdf table mort_`event'_sex_note = (2,1), width(100%) border(all, nil)
    putpdf table mort_`event'_sex_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table mort_`event'_sex_note(2,1) = ("`table_note'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table mort_`event'_sex_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")




    if "`event'" == "all_cvd" {
    * MORTALITY / AGE-PATTERN PAGE -------------------------------------------
    * INVARIANT DATA SELECTION: Primary-definition death counts for All ages,
    * Under 70 and 70 and older. This is an age composition, not population
    * risk. Only the All-CVD page is supported by the approved data structure;
    * retain the enclosing condition that suppresses Heart/Stroke age pages.
    local fig "`annual_figure_dir'/stage3_death_`event'_age.png"
    use "`annual_mortality_data'", clear
    keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & statistic == "annual_count" & event_type == "`event'" & sex == "all" & inlist(age_group, "under_70", "age_70_plus") & case_definition == "primary_clear_likely" & period_complete == 1
    quietly count
    if r(N) > 0 {
        keep period_year age_group value
        reshape wide value, i(period_year) j(age_group) string
        capture confirm variable valueunder_70
        if !_rc label variable valueunder_70 "Under 70"
        capture confirm variable valueage_70_plus
        if !_rc label variable valueage_70_plus "70 and older"

        #delimit ; 
            graph bar valueunder_70 valueage_70_plus, over(period_year, 
            label(angle(35) labsize(6) labgap(3)) 
            relabel(2 " " 4 " " 6 " " 8 " " 10 " " 12 " " 14 " " 16 " ")) stack 

            bar(1, color("`bnr_under70'%82")) 
            bar(2, color("`bnr_70plus'%82")) 

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0))          

            ytitle("") 
            ylabel(#3, angle(horizontal) labsize(6) noticks nogrid) 
            yscale(noline) 
            
            legend(order(1 "Under 70" 2 "70 and older")
                cols(2) size(5) region(lcolor(none)) position(12) ring(1)) 
            
            xsize(10.0) ysize(3.15)
            name(age_mort_`event')
        ;
        #delimit cr 
        graph export "`fig'", replace width(2600)
    }
    local all "-"
    local under "-"
    local older "-"
    use "`annual_mortality_data'", clear
    foreach age in all under_70 age_70_plus {
        preserve
        keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `report_year_num' & event_type == "`event'" & sex == "all" & age_group == "`age'" & case_definition == "primary_clear_likely" & statistic == "annual_count"
        quietly count
        if r(N) == 1 {
            local tmp : display %8.0fc value[1]
            if "`age'" == "all" local all = strtrim("`tmp'")
            if "`age'" == "under_70" local under = strtrim("`tmp'")
            if "`age'" == "age_70_plus" local older = strtrim("`tmp'")
        }
        restore
    }
    putpdf pagebreak
    putpdf paragraph
    putpdf text ("`event_label' deaths: age patterns"), bold font("`font_title'", `size_page', "`bnr_ink'") linebreak
    putpdf text ("Primary-definition annual death counts by broad age group. These are composition counts, not age-specific rates."), font("`font_body'", 8, "`bnr_muted'")
    putpdf table mort_`event'_age_cards = (2,3), width(100%) border(all, nil)
    putpdf table mort_`event'_age_cards(1,1) = ("All ages")
    putpdf table mort_`event'_age_cards(1,2) = ("Under 70")
    putpdf table mort_`event'_age_cards(1,3) = ("70 and older")
    putpdf table mort_`event'_age_cards(2,1) = ("`all'")
    putpdf table mort_`event'_age_cards(2,2) = ("`under'")
    putpdf table mort_`event'_age_cards(2,3) = ("`older'")
    putpdf table mort_`event'_age_cards(1,.), bold font("`font_title'", 7.4, "`bnr_muted'")
    putpdf table mort_`event'_age_cards(2,.), bold font("`font_title'", 14, "`bnr_ink'")
    putpdf table mort_`event'_age_cards(.,.), bgcolor("`bnr_white'")
    putpdf table mort_`event'_age_cards(1,.), border(top, single, "`event_colour'")
    capture confirm file "`fig'"
    if !_rc {
        putpdf table mort_`event'_age_fig = (1,1), width(100%) border(all, nil) halign(center)
        putpdf table mort_`event'_age_fig(1,1) = image("`fig'")
    }
    putpdf paragraph, font("`font_body'", 1)
    putpdf text ("Latest five complete years"), bold font("`font_title'", 9, "`bnr_ink'")
    putpdf table mort_`event'_age_tab = (4,6), width(100%) border(all, nil)
    putpdf table mort_`event'_age_tab(1,1) = ("Primary deaths")
    forvalues j = 0/4 {
        local yy = `first_table_year' + `j'
        local cc = `j' + 2
        putpdf table mort_`event'_age_tab(1,`cc') = ("`yy'")
    }
    local row = 1
    foreach age in all under_70 age_70_plus {
        local ++row
        local label "All ages"
        if "`age'" == "under_70" local label "Under 70"
        if "`age'" == "age_70_plus" local label "70 and older"
        putpdf table mort_`event'_age_tab(`row',1) = ("`label'")
        forvalues j = 0/4 {
            local yy = `first_table_year' + `j'
            local cc = `j' + 2
            local cell "-"
            use "`annual_mortality_data'", clear
            keep if metric_id == "MORT-BURDEN-001" & period_type == "annual" & period_year == `yy' & event_type == "`event'" & sex == "all" & age_group == "`age'" & case_definition == "primary_clear_likely" & statistic == "annual_count"
            quietly count
            if r(N) == 1 {
                local tmp : display %8.0fc value[1]
                local cell = strtrim("`tmp'")
            }
            putpdf table mort_`event'_age_tab(`row',`cc') = ("`cell'")
        }
    }
    putpdf table mort_`event'_age_tab(.,.), font("`font_body'", 7.2)
    putpdf table mort_`event'_age_tab(1,.), bold border(top, single, "`event_colour'") border(bottom, single, "`bnr_rule'")
    putpdf table mort_`event'_age_tab(.,2/6), halign(center)
    putpdf table mort_`event'_age_tab(.,1), bold
    putpdf paragraph, font("`font_body'", 1)
    putpdf table mort_`event'_age_note = (2,1), width(100%) border(all, nil)
    putpdf table mort_`event'_age_note(1,1) = ("WHAT THIS MEANS"), bold font("`font_title'", 8.2, "`event_colour'")
    putpdf table mort_`event'_age_note(2,1) = ("`ann_mort_age_text'"), font("`font_body'", 7.8, "`bnr_ink'")
    putpdf table mort_`event'_age_note(.,.), bgcolor("`bnr_white'") border(top, single, "`event_colour'")
    }
}

* INVARIANT CHAPTER SOURCE LINE.
* Record both release IDs after the live Events and Mortality pages so readers
* can trace every value to the declared public inputs.
putpdf paragraph
putpdf text ("Sources: BNR public CVD-event release `event_release'; BNR public mortality release `mortality_release'."), font("`font_body'", 7, "`bnr_muted'")

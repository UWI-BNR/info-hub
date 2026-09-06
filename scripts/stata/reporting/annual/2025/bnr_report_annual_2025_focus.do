/*******************************************************************************
DO-FILE: bnr_report_annual_2025_focus.do
VERSION: 1.2.0 (6 September 2026)
PURPOSE: Compose the 2025 year-specific Special chapter.

SPECIAL CHAPTER:
  The BNR Refit - strengthening cardiovascular surveillance from data capture
  to public reporting.

PUBLICATION BOUNDARY:
  This is a public-facing account of the refit. It reports the broad audit
  context, improvements delivered, current programme position and remaining
  methodological limitations. It deliberately excludes forensic file-system
  details, security arrangements, staff-specific observations, speculative
  findings and unverified claims about earlier publications.

  If a verified historical issue materially changes a published statistic, it
  belongs in the formal correction or revision process. It must not be handled
  by silently changing the narrative in this chapter.

WORKFLOW BOUNDARY:
  This file is included by the controlled annual report build. It does not open
  confidential data, calculate metrics, alter public releases, save the PDF or
  bypass review. The complete chapter remains subject to annual Step 2 approval
  and Step 3 publication.
*******************************************************************************/

*******************************************************************************
* BNR ANALYST GUIDE - EDITABLE SPECIAL CHAPTER
*
* BNR ANALYST: THIS FILE IS EDITABLE because the annual Special chapter changes
* topic from year to year. It must nevertheless be treated as controlled public
* report content. Check every statement, date, status and source before approval.
*
* SAFE ROUTINE EDITS:
*   - reader-facing text and captions;
*   - programme-status wording after evidence-based review;
*   - source citations;
*   - replacement of the two image files with approved later versions carrying
*     the same filenames and aspect ratios.
*
* DO NOT EDIT ROUTINELY:
*   - putpdf page and section breaks;
*   - portrait/landscape transitions;
*   - table dimensions or cell references;
*   - asset paths;
*   - document lifecycle or publication commands (none belong in this file).
*
* Never manually edit the generated PDF. Correct source text, code or approved
* assets and rebuild a newly versioned candidate.
*******************************************************************************/

* -----------------------------------------------------------------------------
* 0. Maintained support and asset validation
* -----------------------------------------------------------------------------
* DO NOT EDIT ROUTINELY. The standard annual template supplies these locals.
* Fallbacks make the chapter easier to inspect during template development.

if "`bnr_ink'" == ""       local bnr_ink       "44 62 80"
if "`bnr_teal'" == ""      local bnr_teal      "4 81 116"
if "`bnr_primary'" == ""   local bnr_primary   "43 115 136"
if "`bnr_secondary'" == "" local bnr_secondary "91 139 151"
if "`bnr_pale'" == ""      local bnr_pale      "240 246 248"
if "`bnr_pale2'" == ""     local bnr_pale2     "248 249 250"
if "`bnr_rule'" == ""      local bnr_rule      "222 226 230"
if "`bnr_muted'" == ""     local bnr_muted     "102 102 102"
if "`bnr_white'" == ""     local bnr_white     "255 255 255"
if "`bnr_green'" == ""     local bnr_green     "214 237 223"
if "`bnr_amber'" == ""     local bnr_amber     "255 231 168"
if "`bnr_red'" == ""       local bnr_red       "243 198 204"
* Status colours are text-only by design. Do not substitute filled cells here:
* some putpdf renderers retain a white text-run rectangle inside a shaded cell.
if "`bnr_status_implemented'" == "" local bnr_status_implemented "39 117 91"
if "`bnr_status_embedded'" == ""   local bnr_status_embedded   "169 111 0"
if "`bnr_status_later'" == ""      local bnr_status_later      "91 139 151"
if "`font_title'" == ""    local font_title    "Montserrat Medium"
if "`font_body'" == ""     local font_body     "Montserrat"

* These are public, static report assets. They contain no confidential data.
* Replace the files only after confirming their dates and status labels.
local refit_timeline "$BNR_REPO/scripts/stata/reporting/assets/bnr_refit_timeline_2026-08-31.png"
local refit_system "$BNR_REPO/scripts/stata/reporting/assets/bnr_reporting_system_2026-08-31.png"

foreach required_asset in "`refit_timeline'" "`refit_system'" {
    capture confirm file "`required_asset'"
    if _rc {
        display as error "Required Special chapter asset not found: `required_asset'"
        exit 601
    }
}

* -----------------------------------------------------------------------------
* 1. Opening page - why the refit matters
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC NARRATIVE. This page establishes a constructive tone: BNR has
* a valuable surveillance history, while modernisation improves reproducibility,
* timeliness and clarity. It must not read as an institutional incident report.

putpdf pagebreak
putpdf paragraph
putpdf text ("Special chapter | 2025"), bold font("`font_title'", 9, "`bnr_teal'")
putpdf paragraph
putpdf text ("The BNR Refit"), bold font("`font_title'", 18, "`bnr_ink'")
putpdf paragraph
putpdf text ("Strengthening cardiovascular surveillance from data capture to public reporting"), font("`font_body'", 10, "`bnr_muted'")

putpdf paragraph
putpdf text ("Building on a strong national resource"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
#delimit ; 
  putpdf text ("For many years, the Barbados National Registry has provided an important record of cardiovascular disease in Barbados. 
                The BNR Refit builds on that foundation. It is modernising how information is prepared, checked, analysed, approved and 
                shared so that the Registry can provide more timely and reproducible evidence for government, hospitals, clinics and
                public-health partners."), font("`font_body'", 8.7, "`bnr_ink'");
#delimit cr 
putpdf paragraph
#delimit ; 
  putpdf text ("The work began as a review of the use of Registry analytics and reporting processes. 
                The work was expanded when the review highlighted that meaningful improvement also required alteration to earlier registry stages: 
                consistent case definitions, data-entry checks, historical dataset identity, mortality ascertainment 
                and clear approval responsibilities. The result is a coordinated programme rather than a collection of 
                isolated technical fixes."), font("`font_body'", 8.7, "`bnr_ink'");
#delimit cr

putpdf paragraph
putpdf text ("Four connected areas"), bold font("`font_title'", 12, "`bnr_ink'")
putpdf table refit_scope = (4,7), width(100%) border(all, nil)
putpdf table refit_scope(1,1), colspan(3)
putpdf table refit_scope(1,5), colspan(3)
putpdf table refit_scope(2,1), colspan(3)
putpdf table refit_scope(2,5), colspan(3)
putpdf table refit_scope(3,1), colspan(3)
putpdf table refit_scope(3,5), colspan(3)
putpdf table refit_scope(4,1), colspan(3)
putpdf table refit_scope(4,5), colspan(3)
putpdf table refit_scope(1,1) = ("DATA"), bold font("`font_title'", 8, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(2,1) = ("A definitive, traceable analytical record"), font("`font_body'", 8, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(3,1) = ("GOVERNANCE"), bold font("`font_title'", 8, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(4,1) = ("Named releases, visible review and recorded approval"), font("`font_body'", 8, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(1,5) = ("METHODS"), bold font("`font_title'", 8, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(2,5) = ("Consistent event, mortality and uncertainty definitions"), font("`font_body'", 8, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(3,5) = ("REPORTING"), bold font("`font_title'", 8, "`bnr_teal'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(4,5) = ("Clearer, repeatable products for different audiences"), font("`font_body'", 8, "`bnr_ink'") bgcolor("`bnr_pale2'")
putpdf table refit_scope(.,1/3), bgcolor("`bnr_pale2'")
putpdf table refit_scope(.,5/7), bgcolor("`bnr_pale2'")
putpdf table refit_scope(.,4), bgcolor("`bnr_white'")
putpdf table refit_scope(1,1)  = ("DATA"), bold font("`font_title'", 8, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table refit_scope(1,5)  = ("METHODS"), bold font("`font_title'", 8, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table refit_scope(3,1)  = ("GOVERNANCE"), bold font("`font_title'", 8, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table refit_scope(3,5)  = ("REPORTING"), bold font("`font_title'", 8, "`bnr_teal'") border(top, single, "`bnr_teal'")

putpdf paragraph
putpdf table refit_opening_note = (2,1), width(100%) border(all, nil)
putpdf table refit_opening_note(1,1) = ("THE PURPOSE OF THE REFIT"), bold font("`font_title'", 8.2, "`bnr_teal'")
putpdf table refit_opening_note(2,1) = ("Preserve what BNR does well while making every published result easier to reproduce, review and explain."), bold font("`font_title'", 9, "`bnr_ink'")
putpdf table refit_opening_note(.,.), bgcolor("`bnr_white'") border(top, single, "`bnr_teal'")

putpdf paragraph
#delimit ;
  putpdf text ("The Special chapter describes programme development. 
                The statistics elsewhere in this report remain governed by the definitions, 
                uncertainty information and public-release boundaries described in Chapter 4."), font("`font_body'", 7.8, "`bnr_muted'");
#delimit cr


* -----------------------------------------------------------------------------
* 2. Audit context and areas selected for early action
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC SUMMARY. Status replaces the audit's red/amber/green urgency
* scale. The historical priority scale remains in the full audit record; using
* it here could be mistaken for a current warning about report reliability.

putpdf pagebreak
putpdf paragraph
putpdf text ("What the review examined"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph

#delimit ;
  putpdf text ("The review considered the pathway from case capture to public reporting. 
                It examined documented processes, datasets, Stata programs, data definitions, quality controls and reporting products. 
                The work identified a manageable set of connected improvements 
                across case preparation, REDCap, analysis and governance."), font("`font_body'", 8.5, "`bnr_ink'");
#delimit cr

putpdf paragraph
putpdf text ("How to read the status labels"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table status_key = (2,5), width(100%) border(all, nil)
putpdf table status_key(1,1) = ("Implemented"), bold font("`font_title'", 8.6, "`bnr_status_implemented'") halign(center) border(top, single, "`bnr_status_implemented'")
putpdf table status_key(1,3) = ("Being embedded"), bold font("`font_title'", 8.6, "`bnr_status_embedded'") halign(center) border(top, single, "`bnr_status_embedded'")
putpdf table status_key(1,5) = ("Later phase"), bold font("`font_title'", 8.6, "`bnr_status_later'") halign(center) border(top, single, "`bnr_status_later'")
putpdf table status_key(2,1) = ("Control introduced and operating"), font("`font_body'", 7.3, "`bnr_muted'") halign(center)
putpdf table status_key(2,3) = ("Operating with refinement or routine-use review"), font("`font_body'", 7.3, "`bnr_muted'") halign(center)
putpdf table status_key(2,5) = ("Approved later development"), font("`font_body'", 7.3, "`bnr_muted'") halign(center)

putpdf paragraph
putpdf text ("Areas strengthened through the refit"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table audit_public = (9,4), width(100%) border(all, nil)
putpdf table audit_public(1,1) = ("Status")
putpdf table audit_public(1,2) = ("Area")
putpdf table audit_public(1,3) = ("Position identified")
putpdf table audit_public(1,4) = ("Refit response")
putpdf table audit_public(2,1) = ("Implemented")
putpdf table audit_public(2,2) = ("Dataset identity")
putpdf table audit_public(2,3) = ("Historical working datasets required reconciliation")
putpdf table audit_public(2,4) = ("A controlled cumulative base and named releases now define each cycle")
putpdf table audit_public(3,1) = ("Implemented")
putpdf table audit_public(3,2) = ("Analytical workflow")
putpdf table audit_public(3,3) = ("Preparation and reporting had developed within shared scripts")
putpdf table audit_public(3,4) = ("Preparation, calculation, review and publication are separated")
putpdf table audit_public(4,1) = ("Implemented")
putpdf table audit_public(4,2) = ("Release decisions")
putpdf table audit_public(4,3) = ("Dataset approval was not represented by one consistent release gate")
putpdf table audit_public(4,4) = ("Named candidates receive documented human approval before publication")
putpdf table audit_public(5,1) = ("Implemented")
putpdf table audit_public(5,2) = ("Duplicate resolution")
putpdf table audit_public(5,3) = ("Event duplication controls needed greater consistency")
putpdf table audit_public(5,4) = ("Maintained event rules and duplicate-resolution checks are applied before counting")
putpdf table audit_public(6,1) = ("Being embedded")
putpdf table audit_public(6,2) = ("REDCap quality")
putpdf table audit_public(6,3) = ("Validation and metadata controls needed strengthening")
putpdf table audit_public(6,4) = ("Core definitions, checks and documentation are being standardised")
putpdf table audit_public(7,1) = ("Being embedded")
putpdf table audit_public(7,2) = ("Historical linkage")
putpdf table audit_public(7,3) = ("Some older records contain fewer linkage identifiers")
putpdf table audit_public(7,4) = ("Historical lineage has been reconstructed; remaining uncertainty is retained")
putpdf table audit_public(8,1) = ("Implemented")
putpdf table audit_public(8,2) = ("Mortality evidence")
putpdf table audit_public(8,3) = ("Routine national underlying-cause coding is not available to this workflow")
putpdf table audit_public(8,4) = ("A transparent BNR classification provides Primary and Inclusive estimates")
putpdf table audit_public(9,1) = ("Next phase")
putpdf table audit_public(9,2) = ("Extended analysis")
putpdf table audit_public(9,3) = ("Survival and hospital-performance measures need dedicated development")
putpdf table audit_public(9,4) = ("These remain separate from the stable routine reporting core")
putpdf table audit_public(.,.), font("`font_body'", 6.9, "`bnr_ink'")
putpdf table audit_public(1,.), bold font("`font_title'", 7.1, "`bnr_ink'") border(top, single, "`bnr_teal'") border(bottom, single, "`bnr_rule'")
putpdf table audit_public(2/5,1), bold font("`font_title'", 7.2, "`bnr_status_implemented'") halign(center)
putpdf table audit_public(6/7,1), bold font("`font_title'", 7.2, "`bnr_status_embedded'") halign(center)
putpdf table audit_public(8,1), bold font("`font_title'", 7.2, "`bnr_status_implemented'") halign(center)
putpdf table audit_public(9,1), bold font("`font_title'", 7.2, "`bnr_status_later'") halign(center)
putpdf table audit_public(2/9,2), bold

putpdf paragraph
putpdf text ("These labels describe the programme position used for this chapter. They are not ratings of the validity of individual statistics in the report."), italic font("`font_body'", 7.6, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 3. From findings to practical improvements
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC SUMMARY. Every historical position is paired with a delivered
* control and reader-facing benefit. Do not add unresolved forensic findings to
* this table without governance and editorial review.

putpdf pagebreak
putpdf paragraph
putpdf text ("From review to controlled reporting"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The refit response is architectural. Instead of correcting each report independently, it establishes one controlled route from an identified source release to an approved public product."), font("`font_body'", 8.5, "`bnr_ink'")

putpdf table improvements = (9,3), width(100%) border(all, nil)
putpdf table improvements(1,1) = ("What needed strengthening")
putpdf table improvements(1,2) = ("What the refit introduced")
putpdf table improvements(1,3) = ("Practical benefit")
putpdf table improvements(2,1) = ("Dataset identity")
putpdf table improvements(2,2) = ("Named, versioned releases and controlled promotion")
putpdf table improvements(2,3) = ("The authoritative input is explicit")
putpdf table improvements(3,1) = ("Historical processing")
putpdf table improvements(3,2) = ("A reconciled cumulative foundation with recorded lineage")
putpdf table improvements(3,3) = ("Historical trends are easier to trace")
putpdf table improvements(4,1) = ("Data preparation")
putpdf table improvements(4,2) = ("Modular and extensively annotated Stata programs")
putpdf table improvements(4,3) = ("Fewer manual changes between cycles")
putpdf table improvements(5,1) = ("Metric production")
putpdf table improvements(5,2) = ("Reusable calculation and validation workflows")
putpdf table improvements(5,3) = ("Definitions remain consistent across products")
putpdf table improvements(6,1) = ("Quality assurance")
putpdf table improvements(6,2) = ("Automated checks followed by visible human review")
putpdf table improvements(6,3) = ("Problems can be identified before release")
putpdf table improvements(7,1) = ("Disclosure control")
putpdf table improvements(7,2) = ("Repeatable suppression plus whole-output review")
putpdf table improvements(7,3) = ("Public products receive consistent protection")
putpdf table improvements(8,1) = ("Documentation")
putpdf table improvements(8,2) = ("Linked Operations, Technical and Methods manuals")
putpdf table improvements(8,3) = ("Knowledge is easier to maintain and hand over")
putpdf table improvements(9,1) = ("Reporting")
putpdf table improvements(9,2) = ("Approved datasets feed dashboards, updates and annual reports")
putpdf table improvements(9,3) = ("The same statistic retains the same meaning")
putpdf table improvements(.,.), font("`font_body'", 7.2, "`bnr_ink'")
putpdf table improvements(1,.), bold font("`font_title'", 7.4, "`bnr_ink'") border(top, single, "`bnr_teal'") border(bottom, single, "`bnr_rule'")
putpdf table improvements(2/9,1), bold

putpdf paragraph
putpdf text ("A five-stage publication model"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table refit_flow = (5,2), width(100%) border(all, nil)
putpdf table refit_flow(1,1) = ("1  DATA FREEZE")
putpdf table refit_flow(1,2) = ("A named source release defines the analytical cycle.")
putpdf table refit_flow(2,1) = ("2  COMPUTE")
putpdf table refit_flow(2,2) = ("Readable Stata programs create the approved measures and structured outputs.")
putpdf table refit_flow(3,1) = ("3  REVIEW")
putpdf table refit_flow(3,2) = ("Automated checks prepare a fixed candidate for human inspection.")
putpdf table refit_flow(4,1) = ("4  APPROVE")
putpdf table refit_flow(4,2) = ("An authorised reviewer confirms plausibility, disclosure safety and readiness.")
putpdf table refit_flow(5,1) = ("5  PUBLISH")
putpdf table refit_flow(5,2) = ("Only the approved payload moves to the public release and website mirror.")
putpdf table refit_flow(.,.), font("`font_body'", 7.6, "`bnr_ink'")
putpdf table refit_flow(.,1), bold font("`font_title'", 7.6, "`bnr_teal'")
putpdf table refit_flow(1,.), border(top, single, "`bnr_teal'")

putpdf paragraph
putpdf text ("Professional judgement remains central"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph

#delimit ;
  putpdf text ("Automation performs repeatable calculation and checking. 
                BNR staff still decide whether the declared inputs are appropriate, whether results are plausible, 
                whether disclosure protection is sufficient, whether interpretation is suitable and whether the candidate should be released. 
                Corrections are made in source data or version-controlled code and then rebuilt - 
                never by manually changing a public file."), font("`font_body'", 8.3, "`bnr_ink'");
#delimit cr




* -----------------------------------------------------------------------------
* 4. A historical foundation within the wider refit
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC CASE STUDY. This page summarises the reconstruction without
* exposing internal storage locations, security arrangements, staff actions or
* dramatic file-volume counts that do not help readers interpret the report.

putpdf pagebreak
putpdf paragraph
putpdf text ("A foundation within the refit: the historical CVD record"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph

#delimit ; 
  putpdf text ("The refit strengthens data, methods, governance and reporting together. 
                One foundation for that wider programme was reconstruction of the 2009-2023 CVD record from the available historical sources. 
                This work established what each source contained, how successive datasets had been created and which information 
                could be carried safely into a controlled cumulative foundation."), font("`font_body'", 8.5, "`bnr_ink'");
#delimit cr

putpdf paragraph
putpdf text ("Four stages of reconstruction"), bold font("`font_title'", 11, "`bnr_ink'")
* This deliberately uses text-only numbered cells. The prior shaded version was
* not reliable across putpdf PDF renderers and produced white text rectangles.
putpdf table rebuild_steps = (4,7), width(100%) border(all, nil)
forvalues rr = 1/4 {
    putpdf table rebuild_steps(`rr',2), colspan(2)
    putpdf table rebuild_steps(`rr',4), colspan(4)
}
putpdf table rebuild_steps(1,1) = ("01")
putpdf table rebuild_steps(1,2) = ("Locate and catalogue")
putpdf table rebuild_steps(1,4) = ("Bring together the available historical sources and establish their coverage.")
putpdf table rebuild_steps(2,1) = ("02")
putpdf table rebuild_steps(2,2) = ("Trace lineage")
putpdf table rebuild_steps(2,4) = ("Use documentation and Stata programs to understand how cumulative files developed.")
putpdf table rebuild_steps(3,1) = ("03")
putpdf table rebuild_steps(3,2) = ("Reconstruct and reconcile")
putpdf table rebuild_steps(3,4) = ("Standardise structures, resolve duplicate representations and recover information where reliable sources remained.")
putpdf table rebuild_steps(4,1) = ("04")
putpdf table rebuild_steps(4,2) = ("Establish the controlled base")
putpdf table rebuild_steps(4,4) = ("Document a known foundation for subsequent cumulative releases and analytical cycles.")
putpdf table rebuild_steps(.,.), font("`font_body'", 7.8, "`bnr_ink'") border(bottom, single, "`bnr_rule'")
putpdf table rebuild_steps(.,1), bold font("`font_title'", 10.5, "`bnr_teal'") halign(center)
putpdf table rebuild_steps(.,2/3), bold font("`font_title'", 8.0, "`bnr_ink'")

putpdf paragraph
putpdf text ("A practical example: recovering historical linkage information"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph

#delimit ; 
  putpdf text ("During reconstruction, the team found that an anonymised historical file had been used as the base for 
                several later cumulative analytical datasets. This propagated missing identifiers into subsequent files. 
                Source tracing and code review clarified the lineage and allowed identifiers to be 
                restored where suitable source information remained available."), font("`font_body'", 8.4, "`bnr_ink'");
#delimit cr 

putpdf paragraph
#delimit ; 
  putpdf text ("The remaining limitation is retained rather than hidden: some older records still contain 
                fewer identifiers than recent records, so historical person-level linkage can be less certain. 
                This does not mean that every historic event is uncertain; it means that analyses requiring linkage 
                must respect the information available for each period."), font("`font_body'", 8.4, "`bnr_ink'");
#delimit cr

putpdf table rebuild_note = (2,1), width(100%) border(all, nil)
putpdf table rebuild_note(1,1) = ("WHAT THIS ENABLES"), bold font("`font_title'", 8.2, "`bnr_teal'")
putpdf table rebuild_note(2,1) = ("A known historical baseline, clearer lineage, improved linkage and an auditable starting point for each new analytical cycle."), bold font("`font_title'", 8.8, "`bnr_ink'")
putpdf table rebuild_note(.,.), bgcolor("`bnr_white'") border(top, single, "`bnr_teal'")

putpdf paragraph
putpdf text ("The reconstruction is a historical foundation. Routine updates now use the maintained data and release workflows rather than repeating the forensic exercise each year."), italic font("`font_body'", 7.8, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 5. Landscape figure - implementation timeline
* -----------------------------------------------------------------------------
* DO NOT EDIT THE SECTION BREAKS ROUTINELY. This begins a new A4 landscape
* section using the annual report's standard margins. The image is a dated
* programme view and must be replaced when its status labels become obsolete.

putpdf sectionbreak, pagesize(A4) landscape margin(top, 0.55) margin(bottom, 0.55) margin(left, 0.65) margin(right, 0.65)
putpdf paragraph
putpdf text ("Special chapter | The BNR Refit"), bold font("`font_title'", 8, "`bnr_teal'")
putpdf paragraph, font("`font_body'", 1)
putpdf table timeline_guide = (2,3), width(100%) border(all, nil)
putpdf table timeline_guide(1,1) = ("WHAT HAS CHANGED")
putpdf table timeline_guide(1,2) = ("WHAT IS OPERATING")
putpdf table timeline_guide(1,3) = ("WHAT COMES NEXT")
putpdf table timeline_guide(2,1) = ("Work is organised as named, documented workflows.")
putpdf table timeline_guide(2,2) = ("Core data, metric, tabulation, briefing and reporting workflows.")
putpdf table timeline_guide(2,3) = ("Documentation maturation, national event estimation and later analytical modules.")
putpdf table timeline_guide(1,.), bold font("`font_title'", 6.5, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table timeline_guide(2,.), font("`font_body'", 6.2, "`bnr_muted'")
putpdf table refit_timeline_fig = (1,1), width(80%) border(all, nil) halign(center)
putpdf table refit_timeline_fig(1,1) = image("`refit_timeline'"), halign(center)
putpdf paragraph
putpdf text ("Programme view dated 31 August 2026. The graphic records the planning position at that date; individual workstreams may advance through later approved implementation cycles."), italic font("`font_body'", 7.2, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 6. Landscape figure - the reporting system
* -----------------------------------------------------------------------------
* Start a second explicit landscape section. Do not replace this with pagebreak:
* pagebreak can reopen the default portrait section after a mixed-orientation
* page and was the source of the blank/spill pages in the first rendering.

putpdf sectionbreak, pagesize(A4) landscape margin(top, 0.55) margin(bottom, 0.55) margin(left, 0.65) margin(right, 0.65)
putpdf paragraph
putpdf text ("Special chapter | The BNR Refit"), bold font("`font_title'", 8, "`bnr_teal'")
putpdf paragraph, font("`font_body'", 1)
putpdf table system_guide = (2,3), width(100%) border(all, nil)
putpdf table system_guide(1,1) = ("DATA FOUNDATION")
putpdf table system_guide(1,2) = ("CONTROLLED PRODUCTION")
putpdf table system_guide(1,3) = ("PUBLIC PRODUCTS")
putpdf table system_guide(2,1) = ("Case capture, managed registry data and maintained historical records.")
putpdf table system_guide(2,2) = ("Definitions, checks, human review, approval and disclosure control.")
putpdf table system_guide(2,3) = ("Separate tabulations, briefings, dashboards, Information Hub outputs and annual reports.")
putpdf table system_guide(1,.), bold font("`font_title'", 6.5, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table system_guide(2,.), font("`font_body'", 6.2, "`bnr_muted'")
putpdf table refit_system_fig = (1,1), width(66%) border(all, nil) halign(center)
putpdf table refit_system_fig(1,1) = image("`refit_system'"), halign(center)
putpdf paragraph
putpdf text ("The reporting system connects case capture, data management, controlled metric production and public reporting. Each component has a defined role, while review and approval remain explicit human decisions."), italic font("`font_body'", 7.2, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 7. Closing page - current position and public value
* -----------------------------------------------------------------------------
* DO NOT EDIT THE SECTION BREAK ROUTINELY. It returns the report to A4 portrait.
* EDIT the dated status content only after confirming it against the maintained
* workflows and documentation. Avoid promises that are not approved work.

putpdf sectionbreak, pagesize(A4) margin(top, 0.55) margin(bottom, 0.55) margin(left, 0.65) margin(right, 0.65)
putpdf paragraph
putpdf text ("Where the refit stands"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The central reporting architecture is now operating. Further work is being managed as defined refinements and later analytical phases rather than being allowed to destabilise the routine reporting core."), font("`font_body'", 8.5, "`bnr_ink'")

putpdf table current_position = (4,3), width(100%) border(all, nil)
putpdf table current_position(1,1) = ("DELIVERED AND OPERATIONAL")
putpdf table current_position(1,2) = ("BEING EMBEDDED")
putpdf table current_position(1,3) = ("LATER PHASES")
putpdf table current_position(2,1) = ("Event and mortality release workflows")
putpdf table current_position(2,2) = ("DCO linkage and national event-estimation refinements")
putpdf table current_position(2,3) = ("Survival and case-fatality analysis")
putpdf table current_position(3,1) = ("Metric calculation, disclosure review and publication")
putpdf table current_position(3,2) = ("Routine use, documentation review and staff handover")
putpdf table current_position(3,3) = ("Hospital performance measures")
putpdf table current_position(4,1) = ("Tabulations, briefings, dashboards and annual reporting")
putpdf table current_position(4,2) = ("Continued improvement of the Information Hub")
putpdf table current_position(4,3) = ("Periodic research analyses and carefully assessed new modules")
putpdf table current_position(.,.), font("`font_body'", 7.5, "`bnr_ink'")
putpdf table current_position(1,1), bold font("`font_title'", 8.0, "`bnr_status_implemented'") border(top, single, "`bnr_status_implemented'")
putpdf table current_position(1,2), bold font("`font_title'", 8.0, "`bnr_status_embedded'") border(top, single, "`bnr_status_embedded'")
putpdf table current_position(1,3), bold font("`font_title'", 8.0, "`bnr_status_later'") border(top, single, "`bnr_status_later'")

putpdf paragraph
putpdf text ("What this means for Barbados"), bold font("`font_title'", 12, "`bnr_ink'")
putpdf table national_value = (6,2), width(100%) border(all, nil)
putpdf table national_value(1,1) = ("1")
putpdf table national_value(1,2) = ("Clearer and more timely evidence for government, hospitals, clinics and public-health teams")
putpdf table national_value(2,1) = ("2")
putpdf table national_value(2,2) = ("A more dependable analytical foundation with explicit dataset lineage")
putpdf table national_value(3,1) = ("3")
putpdf table national_value(3,2) = ("Consistent statistics across public datasets, dashboards, updates and annual reports")
putpdf table national_value(4,1) = ("4")
putpdf table national_value(4,2) = ("Transparent presentation of statistical, linkage and classification uncertainty")
putpdf table national_value(5,1) = ("5")
putpdf table national_value(5,2) = ("Repeatable disclosure protection and visible human approval before publication")
putpdf table national_value(6,1) = ("6")
putpdf table national_value(6,2) = ("A documented system designed for sustainable operation by a small BNR team")
putpdf table national_value(.,.), font("`font_body'", 7.8, "`bnr_ink'")
putpdf table national_value(.,1), bold font("`font_title'", 8.5, "`bnr_teal'") halign(center)

putpdf paragraph
putpdf table closing_note = (2,1), width(100%) border(all, nil)
putpdf table closing_note(1,1) = ("THE PRACTICAL OBJECTIVE"), bold font("`font_title'", 8.2, "`bnr_teal'")
putpdf table closing_note(2,1) = ("The same published statistic should mean the same thing wherever it is encountered - in a dataset, dashboard, rolling update or annual report."), bold font("`font_title'", 8.8, "`bnr_ink'")
putpdf table closing_note(.,.), bgcolor("`bnr_white'") border(top, single, "`bnr_teal'")

putpdf paragraph
putpdf text ("Sources"), bold font("`font_title'", 9, "`bnr_ink'")
putpdf paragraph
putpdf text ("BNR Process Audit: Findings and Executive Summary; CVD Dataset Rebuild 2025; BNR Surveillance Automation and Integrated Digital Reporting, Terms of Reference v1.0 (26 February 2026); current BNR Operations, Technical and public Methods documentation."), font("`font_body'", 7.1, "`bnr_muted'")

putpdf paragraph
putpdf text ("This chapter describes the implementation position used for the 2025 annual report. Later public documentation may record subsequent programme development."), italic font("`font_body'", 7.1, "`bnr_muted'")

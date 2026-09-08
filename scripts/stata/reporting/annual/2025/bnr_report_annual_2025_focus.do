/*******************************************************************************
DO-FILE: bnr_report_annual_2025_focus.do
VERSION: 1.4.0 (6 September 2026)
PURPOSE: Compose the 2025 year-specific Special chapter.

CHANGE 1.3.0:
  - Align the chapter and both landscape graphics to four connected areas.
  - Record the April 2026 to March 2027 programme period and December position.
  - Treat the seven core workflows as operating by December 2026; reserve work
    after December for final testing, manuals, handover and later modules.
  - Replace internal-sounding status wording with public-facing labels.

CHANGE 1.4.0:
  - Rebuild pages 11-14 as one traceable audit-to-response-to-benefit story.
  - Reconcile the public register against the original audit themes and retain
    stable D/M/G/R references across the findings and response tables.
  - Emphasise separation of data management, analytics and publication, rapid
    digital reporting, reproducibility and plain-language disclosure protection.
  - Align delivery wording with the December 2026 timeline position.

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
* Special-chapter area colours are semantic navigation aids. Use them for rules,
* reference codes and headings only; disease colours elsewhere are unchanged.
if "`bnr_area_data'" == ""         local bnr_area_data         "4 81 116"
if "`bnr_area_methods'" == ""      local bnr_area_methods      "110 75 143"
if "`bnr_area_governance'" == ""   local bnr_area_governance   "169 111 0"
if "`bnr_area_reporting'" == ""    local bnr_area_reporting    "47 126 96"
if "`font_title'" == ""    local font_title    "Montserrat Medium"
if "`font_body'" == ""     local font_body     "Montserrat"

* These are public, static report assets. They contain no confidential data.
* Replace the files only after confirming their dates and status labels.
local refit_timeline "$BNR_REPO/scripts/stata/reporting/assets/bnr_refit_timeline_2026-12.png"
local refit_system "$BNR_REPO/scripts/stata/reporting/assets/bnr_reporting_system_2026-12.png"

foreach required_asset in "`refit_timeline'" "`refit_system'" {
    capture confirm file "`required_asset'"
    if _rc {
        display as error "Required Special chapter asset not found: `required_asset'"
        exit 601
    }
}

* -----------------------------------------------------------------------------
* 1. Opening page - why the refit was undertaken
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
putpdf text ("Building a faster, safer and more transparent cardiovascular reporting system"), font("`font_body'", 10, "`bnr_muted'")

putpdf paragraph
putpdf text ("Building on a strong national resource"), bold font("`font_title'", 13, "`bnr_ink'")
putpdf paragraph
putpdf text ("For many years, the Barbados National Registry has provided an important national record of cardiovascular disease. The BNR Refit strengthens that foundation by connecting case capture, analysis and public reporting through one clearly governed route. Its purpose is to provide government, hospitals, clinics and public-health partners with evidence that is more timely, reproducible and easier to understand."), font("`font_body'", 8.5, "`bnr_ink'")
putpdf paragraph
putpdf text ("The refit brings together three established software platforms, each with a clear and distinct role. REDCap supports the structured management of registry data. Maintained Stata workflows apply agreed definitions, carry out analytical checks and produce the statistics. Quarto provides the publishing framework for the BNR Information Hub, where approved results are presented through webpages, dashboards and reports. Keeping these roles separate reduces unnecessary copying and reworking, lowers the risk of inconsistencies, and makes it easier to trace every published result back to its source data, method and approval."), font("`font_body'", 8.5, "`bnr_ink'")

putpdf paragraph
putpdf text ("Three questions guided the review"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("We first conducted a full review of the original BNR processes. The review was shaped by three practical questions. Together, they tested whether published results could be traced to an approved source, produced consistently wherever they appear, and made available promptly without compromising confidentiality. Review findings are presented on the next page."), font("`font_body'", 8.5, "`bnr_ink'")
putpdf paragraph
putpdf table review_questions = (2,3), width(100%) border(all, nil)
putpdf table review_questions(1,1) = ("TRACEABILITY")
putpdf table review_questions(1,2) = ("CONSISTENCY")
putpdf table review_questions(1,3) = ("TIMELINESS AND SAFETY")
putpdf table review_questions(2,1) = ("Can every published result be traced to an approved data release?")
putpdf table review_questions(2,2) = ("Are the same definitions and calculations used wherever a result appears?")
putpdf table review_questions(2,3) = ("Can checked information be published quickly while protecting individuals?")
putpdf table review_questions(1,1), bold font("`font_title'", 7.4, "`bnr_area_data'") border(top, single, "`bnr_area_data'")
putpdf table review_questions(1,2), bold font("`font_title'", 7.4, "`bnr_area_methods'") border(top, single, "`bnr_area_methods'")
putpdf table review_questions(1,3), bold font("`font_title'", 7.4, "`bnr_area_governance'") border(top, single, "`bnr_area_governance'")
putpdf table review_questions(2,1), font("`font_body'", 7.1, "`bnr_ink'")
putpdf table review_questions(2,2), font("`font_body'", 7.1, "`bnr_ink'")
putpdf table review_questions(2,3), font("`font_body'", 7.1, "`bnr_ink'")

putpdf paragraph
putpdf text ("Four connected areas"), bold font("`font_title'", 12, "`bnr_ink'")
putpdf paragraph
putpdf text ("The subsequent BNR refit has been guided by the findings of this review. Work has been organised across four connected areas, covering the full route from managed data to public information. Each area supports the others: dependable reporting relies on sound data, consistent methods, clear governance and an effective way to share approved results."),  font("`font_body'", 8.5, "`bnr_ink'")
putpdf paragraph
putpdf table refit_scope = (4,7), width(100%) border(all, nil)
putpdf table refit_scope(1,1), colspan(3)
putpdf table refit_scope(1,5), colspan(3)
putpdf table refit_scope(2,1), colspan(3)
putpdf table refit_scope(2,5), colspan(3)
putpdf table refit_scope(3,1), colspan(3)
putpdf table refit_scope(3,5), colspan(3)
putpdf table refit_scope(4,1), colspan(3)
putpdf table refit_scope(4,5), colspan(3)
putpdf table refit_scope(1,1) = ("DATA FOUNDATION"), bold font("`font_title'", 7.8, "`bnr_area_data'") border(top, single, "`bnr_area_data'")
putpdf table refit_scope(2,1) = ("Managed REDCap data, a controlled historical data record and named source releases"), font("`font_body'", 7.1, "`bnr_ink'")
putpdf table refit_scope(3,1) = ("ASSURANCE AND GOVERNANCE"), bold font("`font_title'", 7.8, "`bnr_area_governance'") border(top, single, "`bnr_area_governance'")
putpdf table refit_scope(4,1) = ("Automated data quality checks, human approval, disclosure protection and versioned publication"), font("`font_body'", 7.1, "`bnr_ink'")
putpdf table refit_scope(1,5) = ("DEFINITIONS AND METHODS"), bold font("`font_title'", 7.8, "`bnr_area_methods'") border(top, single, "`bnr_area_methods'")
putpdf table refit_scope(2,5) = ("Consistent event, mortality, DCO, statistical and uncertainty methods"), font("`font_body'", 7.1, "`bnr_ink'")
putpdf table refit_scope(3,5) = ("PUBLIC REPORTING"), bold font("`font_title'", 7.8, "`bnr_area_reporting'") border(top, single, "`bnr_area_reporting'")
putpdf table refit_scope(4,5) = ("Connected dashboards, monthly updates, annual reports and one-off reports"), font("`font_body'", 7.1, "`bnr_ink'")

putpdf paragraph
putpdf table refit_period = (2,1), width(100%) border(all, nil)
putpdf table refit_period(1,1) = ("THE REFIT PERIOD"), bold font("`font_title'", 8.2, "`bnr_teal'")
putpdf table refit_period(2,1) = ("The main refit programme runs from April 2026 to March 2027. As of December 2026, core data, event, mortality and dashboard workflows are operating. Report workflows, final testing, manuals and handover continue into early 2027; later analytical modules remain future work."), font("`font_body'", 7.4, "`bnr_ink'")
putpdf table refit_period(.,.), bgcolor("`bnr_white'") border(top, single, "`bnr_teal'")


* -----------------------------------------------------------------------------
* 2. What the review identified
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC SUMMARY. This is the public transformation register. It
* reconciles the original audit themes without reproducing forensic detail,
* historical priority ratings, internal storage facts or unverified claims.

putpdf pagebreak
putpdf paragraph
putpdf text ("What the review identified"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The BNR process review followed the complete pathway from case capture through data preparation, analysis and reporting. Ten connected findings summarise the issues that shaped this BNR refit. In the table below, we use a short reference code for our 10 issues, so that every finding can be matched directly to the subsequent improvements, detailed on the next page."), font("`font_body'", 8.3, "`bnr_ink'")

putpdf paragraph
putpdf table audit_findings = (11,10), width(100%) border(all, nil)
forvalues rr = 1/11 {
    putpdf table audit_findings(`rr',2), colspan(2)
    putpdf table audit_findings(`rr',4), colspan(3)
    putpdf table audit_findings(`rr',7), colspan(4)
}
putpdf table audit_findings(1,1) = ("Ref.")
putpdf table audit_findings(1,2) = ("Area")
putpdf table audit_findings(1,4) = ("What the review identified")
putpdf table audit_findings(1,7) = ("Why it mattered")
putpdf table audit_findings(2,1) = ("D1")
putpdf table audit_findings(2,2) = ("Data foundation")
putpdf table audit_findings(2,4) = ("Historical datasets, identifiers and analytical records required reconciliation")
putpdf table audit_findings(2,7) = ("The authoritative record and the source behind a result needed to be easier to establish")
putpdf table audit_findings(3,1) = ("D2")
putpdf table audit_findings(3,2) = ("Data foundation")
putpdf table audit_findings(3,4) = ("Database validation, core-variable protection, cleaning and metadata needed greater standardisation")
putpdf table audit_findings(3,7) = ("Missing or inconsistent information could otherwise travel into later stages and delay reporting")
putpdf table audit_findings(4,1) = ("M1")
putpdf table audit_findings(4,2) = ("Definitions and methods")
putpdf table audit_findings(4,4) = ("Eligibility, case-finding and event-inclusion rules had varied over time")
putpdf table audit_findings(4,7) = ("Changing rules reduce the comparability of trends")
putpdf table audit_findings(5,1) = ("M2")
putpdf table audit_findings(5,2) = ("Definitions and methods")
putpdf table audit_findings(5,4) = ("Duplicate and repeat-event controls needed consistent application")
putpdf table audit_findings(5,7) = ("Duplicate records can inflate counts and obscure genuine repeat events")
putpdf table audit_findings(6,1) = ("M3")
putpdf table audit_findings(6,2) = ("Definitions and methods")
putpdf table audit_findings(6,4) = ("Mortality and DCO evidence required a structured, reproducible classification and linkage method")
putpdf table audit_findings(6,7) = ("National estimates and their uncertainty needed to be transparent")
putpdf table audit_findings(7,1) = ("M4")
putpdf table audit_findings(7,2) = ("Definitions and methods")
putpdf table audit_findings(7,4) = ("Data preparation, analysis and report production had developed within overlapping processes")
putpdf table audit_findings(7,7) = ("Each cycle required avoidable manual handling and was harder to reproduce")
putpdf table audit_findings(8,1) = ("G1")
putpdf table audit_findings(8,2) = ("Assurance and governance")
putpdf table audit_findings(8,4) = ("Dataset sign-off, release decisions, roles and version control needed one visible route")
putpdf table audit_findings(8,7) = ("Unclear responsibility makes approval and recovery harder to audit")
putpdf table audit_findings(9,1) = ("G2")
putpdf table audit_findings(9,2) = ("Assurance and governance")
putpdf table audit_findings(9,4) = ("Quality monitoring and protection of small public figures needed to be systematic")
putpdf table audit_findings(9,7) = ("Problems and disclosure risks should be identified before publication")
putpdf table audit_findings(10,1) = ("R1")
putpdf table audit_findings(10,2) = ("Public reporting")
putpdf table audit_findings(10,4) = ("Reporting products were produced through separate, relatively slow processes")
putpdf table audit_findings(10,7) = ("Useful information could remain unavailable after data had been collected and checked")
putpdf table audit_findings(11,1) = ("R2")
putpdf table audit_findings(11,2) = ("Public reporting")
putpdf table audit_findings(11,4) = ("Methods, operating knowledge and variable definitions needed sustainable open documentation")
putpdf table audit_findings(11,7) = ("The system should be transparent and maintainable by a small BNR team")
putpdf table audit_findings(.,.), font("`font_body'", 6.6, "`bnr_ink'")
putpdf table audit_findings(1,.), bold font("`font_title'", 6.9, "`bnr_ink'") border(top, single, "`bnr_teal'") border(bottom, single, "`bnr_rule'")
putpdf table audit_findings(2/11,2), bold
putpdf table audit_findings(2/3,1), bold font("`font_title'", 7.1, "`bnr_area_data'") halign(center)
putpdf table audit_findings(4/7,1), bold font("`font_title'", 7.1, "`bnr_area_methods'") halign(center)
putpdf table audit_findings(8/9,1), bold font("`font_title'", 7.1, "`bnr_area_governance'") halign(center)
putpdf table audit_findings(10/11,1), bold font("`font_title'", 7.1, "`bnr_area_reporting'") halign(center)

putpdf paragraph
putpdf text ("The original audit also identified longer-term opportunities including abstraction automation, additional condition modules, research analytics, wider technical governance and periodic independent review. These remain future options and are not presented here as completed parts of the core refit."), italic font("`font_body'", 7.3, "`bnr_muted'")

* -----------------------------------------------------------------------------
* 3. How each finding became an improvement
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC SUMMARY. Every historical position is paired with a delivered
* control and reader-facing benefit. Do not add unresolved forensic findings to
* this table without governance and editorial review.

putpdf pagebreak
putpdf paragraph
putpdf text ("How each finding became an improvement"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The references and ordering below match the findings table on the previous page. The delivery progress is presented in greater detail on the next page."), font("`font_body'", 8.3, "`bnr_ink'")

putpdf paragraph
putpdf table refit_response = (11,12), width(100%) border(all, nil)
forvalues rr = 1/11 {
    putpdf table refit_response(`rr',2), colspan(2)
    putpdf table refit_response(`rr',4), colspan(4)
    putpdf table refit_response(`rr',8), colspan(3)
    putpdf table refit_response(`rr',11), colspan(2)
}
putpdf table refit_response(1,1) = ("Ref.")
putpdf table refit_response(1,2) = ("Issue identified")
putpdf table refit_response(1,4) = ("What the refit introduced")
putpdf table refit_response(1,8) = ("Direct benefit")
putpdf table refit_response(1,11) = ("Delivery progress")
putpdf table refit_response(2,1) = ("D1")
putpdf table refit_response(2,2) = ("Records required reconciliation")
putpdf table refit_response(2,4) = ("A reconciled historical foundation, documented lineage and named source releases")
putpdf table refit_response(2,8) = ("Every reporting cycle starts from an identifiable approved source")
putpdf table refit_response(2,11) = ("Operating by Dec 2026")
putpdf table refit_response(3,1) = ("D2")
putpdf table refit_response(3,2) = ("Data controls needed standardisation")
putpdf table refit_response(3,4) = ("Managed REDCap database structures, validation checks, a protected core variable set and maintained metadata")
putpdf table refit_response(3,8) = ("Quality issues can be found earlier, before analytical production")
putpdf table refit_response(3,11) = ("Operating by Dec 2026")
putpdf table refit_response(4,1) = ("M1")
putpdf table refit_response(4,2) = ("Inclusion rules varied over time")
putpdf table refit_response(4,4) = ("Maintained eligibility, event-definition and case-inclusion rules")
putpdf table refit_response(4,8) = ("Trends and products use consistent definitions")
putpdf table refit_response(4,11) = ("Operating by Dec 2026")
putpdf table refit_response(5,1) = ("M2")
putpdf table refit_response(5,2) = ("Duplicate controls were inconsistent")
putpdf table refit_response(5,4) = ("Standard duplicate checks and explicit repeat-event rules before counting")
putpdf table refit_response(5,8) = ("Counts are less vulnerable to duplicate representations")
putpdf table refit_response(5,11) = ("Operating by Dec 2026")
putpdf table refit_response(6,1) = ("M3")
putpdf table refit_response(6,2) = ("Mortality methods needed structure")
putpdf table refit_response(6,4) = ("Reproducible mortality classification, DCO identification, linkage and uncertainty methods")
putpdf table refit_response(6,8) = ("Primary and Inclusive national estimates can be interpreted transparently")
putpdf table refit_response(6,11) = ("Operating by Dec 2026")
putpdf table refit_response(7,1) = ("M4")
putpdf table refit_response(7,2) = ("Analytical processes overlapped")
putpdf table refit_response(7,4) = ("Separate, modular Stata workflows for preparation, calculation, review and publication")
putpdf table refit_response(7,8) = ("Fewer manual changes and a more reproducible analytical cycle")
putpdf table refit_response(7,11) = ("Operating; testing to Mar 2027")
putpdf table refit_response(8,1) = ("G1")
putpdf table refit_response(8,2) = ("Approval routes needed clarification")
putpdf table refit_response(8,4) = ("Fixed monthly data releases, full versioning, recorded human approval and controlled publication")
putpdf table refit_response(8,8) = ("Release decisions and recovery are visible and auditable")
putpdf table refit_response(8,11) = ("Operating by Dec 2026")
putpdf table refit_response(9,1) = ("G2")
putpdf table refit_response(9,2) = ("Quality and disclosure checks needed consistency")
putpdf table refit_response(9,4) = ("Automated quality checks, small-number suppression and whole-output disclosure review")
putpdf table refit_response(9,8) = ("Public information is checked and protected consistently")
putpdf table refit_response(9,11) = ("Operating; testing to Mar 2027")
putpdf table refit_response(10,1) = ("R1")
putpdf table refit_response(10,2) = ("Reporting was slow and separate")
putpdf table refit_response(10,4) = ("Approved data releases feeding dashboards, monthly updates, annual reports and one-off reports")
putpdf table refit_response(10,8) = ("New information reaches users without rebuilding every product independently")
putpdf table refit_response(10,11) = ("Dashboards operating; annual Jan and one-off Feb 2027")
putpdf table refit_response(11,1) = ("R2")
putpdf table refit_response(11,2) = ("Documentation needed strengthening")
putpdf table refit_response(11,4) = ("Linked Technical, Operations and public Methods manuals in open formats")
putpdf table refit_response(11,8) = ("Methods are transparent and the system is easier to maintain and hand over")
putpdf table refit_response(11,11) = ("Completion by Mar 2027")
putpdf table refit_response(.,.), font("`font_body'", 6.6, "`bnr_ink'")
putpdf table refit_response(1,.), bold font("`font_title'", 6.9, "`bnr_ink'") border(top, single, "`bnr_teal'") border(bottom, single, "`bnr_rule'")
putpdf table refit_response(2/11,2), bold
* putpdf table refit_response(2/11,11), bold
putpdf table refit_response(2/3,1), bold font("`font_title'", 7.1, "`bnr_area_data'") halign(center)
putpdf table refit_response(4/7,1), bold font("`font_title'", 7.1, "`bnr_area_methods'") halign(center)
putpdf table refit_response(8/9,1), bold font("`font_title'", 7.1, "`bnr_area_governance'") halign(center)
putpdf table refit_response(10/11,1), bold font("`font_title'", 7.1, "`bnr_area_reporting'") halign(center)

putpdf paragraph
putpdf text ("The overall redesign is structural, from the ground-up. The new system replaces the repeated manual preparation of  separate (hard-copy only) reports with one controlled route from managed data to approved public information."), font("`font_title'", 8.2, "`bnr_ink'")




* -----------------------------------------------------------------------------
* 4. What the new system makes possible
* -----------------------------------------------------------------------------
* EDITABLE PUBLIC SUMMARY. This page translates the technical architecture into
* reader-facing gains. Keep the wording accurate: publication follows checking
* and approval; it is not an uncontrolled live feed from confidential data.

putpdf pagebreak
putpdf paragraph
putpdf text ("From approved data to public information"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The refit replaces a sequence of largely separate analytical and reporting tasks with a controlled digital route. Once data have been managed, checked and approved, the same data release can supply public dashboards and linked outputs without waiting for each product to be rebuilt independently."), font("`font_body'", 8.5, "`bnr_ink'")

putpdf paragraph
putpdf text ("A controlled publication route"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table digital_flow = (6,2), width(100%) border(all, nil)
putpdf table digital_flow(1,1) = ("1  MANAGE")
putpdf table digital_flow(1,2) = ("REDCap holds managed registry data, supported by defined checks and metadata.")
putpdf table digital_flow(2,1) = ("2  RELEASE")
putpdf table digital_flow(2,2) = ("A monthly named data release defines the approved source for the reporting cycle.")
putpdf table digital_flow(3,1) = ("3  COMPUTE")
putpdf table digital_flow(3,2) = ("Readable, modular Stata workflows create the agreed measures and outputs.")
putpdf table digital_flow(4,1) = ("4  CHECK AND PROTECT")
putpdf table digital_flow(4,2) = ("Automated validation checks results and withholds very small public figures; the complete output is then reviewed for disclosure risk.")
putpdf table digital_flow(5,1) = ("5  APPROVE")
putpdf table digital_flow(5,2) = ("An authorised reviewer confirms analytical accuracy, provides interpretation and approves readiness.")
putpdf table digital_flow(6,1) = ("6  PUBLISH")
putpdf table digital_flow(6,2) = ("Only approved, versioned data releases and associated publications move to the public-access Information Hub.")
putpdf table digital_flow(.,.), font("`font_body'", 7.2, "`bnr_ink'")
putpdf table digital_flow(.,1), bold font("`font_title'", 7.2, "`bnr_teal'")
putpdf table digital_flow(1,.), border(top, single, "`bnr_teal'")

putpdf paragraph
putpdf text ("What digital transformation changes"), bold font("`font_title'", 11, "`bnr_ink'")
putpdf table digital_benefits = (4,7), width(100%) border(all, nil)
putpdf table digital_benefits(1,1), colspan(3)
putpdf table digital_benefits(1,5), colspan(3)
putpdf table digital_benefits(2,1), colspan(3)
putpdf table digital_benefits(2,5), colspan(3)
putpdf table digital_benefits(3,1), colspan(3)
putpdf table digital_benefits(3,5), colspan(3)
putpdf table digital_benefits(4,1), colspan(3)
putpdf table digital_benefits(4,5), colspan(3)
putpdf table digital_benefits(1,1) = ("FASTER"), bold font("`font_title'", 7.8, "`bnr_area_reporting'") border(top, single, "`bnr_area_reporting'")
putpdf table digital_benefits(2,1) = ("Approved information can move rapidly into connected public products."), font("`font_body'", 7.2, "`bnr_ink'")
putpdf table digital_benefits(1,5) = ("CONSISTENT"), bold font("`font_title'", 7.8, "`bnr_area_methods'") border(top, single, "`bnr_area_methods'")
putpdf table digital_benefits(2,5) = ("Dashboards, tables and reports use the same definitions and data releases."), font("`font_body'", 7.2, "`bnr_ink'")
putpdf table digital_benefits(3,1) = ("SAFER"), bold font("`font_title'", 7.8, "`bnr_area_governance'") border(top, single, "`bnr_area_governance'")
putpdf table digital_benefits(4,1) = ("Disclosure protection and human review are built into publication."), font("`font_body'", 7.2, "`bnr_ink'")
putpdf table digital_benefits(3,5) = ("TRACEABLE"), bold font("`font_title'", 7.8, "`bnr_area_data'") border(top, single, "`bnr_area_data'")
putpdf table digital_benefits(4,5) = ("Each result is linked to a named data release, maintained code and documented method."), font("`font_body'", 7.2, "`bnr_ink'")

putpdf paragraph
putpdf table historical_foundation = (2,1), width(100%) border(all, nil)
putpdf table historical_foundation(1,1) = ("A RELIABLE HISTORICAL FOUNDATION"), bold font("`font_title'", 8.0, "`bnr_area_data'") border(top, single, "`bnr_area_data'")
putpdf table historical_foundation(2,1) = ("The 2009-2023 record was carefully reconstructed and reconciled to provide a documented, traceable historical foundation for the new system. This preserves the value of more than a decade of surveillance while making the origins and limitations of the data clearer. Some older records contain fewer identifiers for matching information across data sources than more recent records. Where this limits linkage, the resulting uncertainty is reported rather than hidden."), font("`font_body'", 7.3, "`bnr_ink'")

putpdf table methods_final_note(1,1) = ///
    ("AUTOMATION WITH HUMAN CONTROL"), ///
    bold font("`font_title'", 8.3, "`bnr_teal'")
putpdf table methods_final_note(2,1) = ///
    ("Automation completes routine, repeatable work more quickly and consistently, allowing staff to focus their attention where professional judgement is essential. BNR staff remain responsible for event identification, analytical development, disclosure safety, interpretation and publication approval. Automated processes support these decisions; they do not replace human oversight or accountability."), ///
    font("`font_body'", 8.3, "`bnr_teal'")





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
putpdf table timeline_guide(2,1) = ("Managed data now feed separate, controlled analytics and publication workflows.")
putpdf table timeline_guide(2,2) = ("Core event, mortality, DCO and dashboard outputs were operating by December 2026.")
putpdf table timeline_guide(2,3) = ("Annual and one-off reporting, testing and manuals complete in early 2027; later analytics remain future work.")
putpdf table timeline_guide(1,.), bold font("`font_title'", 6.5, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table timeline_guide(2,.), font("`font_body'", 6.2, "`bnr_muted'")
putpdf table refit_timeline_fig = (1,1), width(80%) border(all, nil) halign(center)
putpdf table refit_timeline_fig(1,1) = image("`refit_timeline'"), halign(center)
putpdf paragraph
putpdf text ("Programme view at December 2026. The annual report workflow is scheduled for January 2027 and the one-off report workflow for February 2027. Testing, manuals and handover continue to March."), italic font("`font_body'", 7.2, "`bnr_muted'")

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
putpdf table system_guide = (2,4), width(100%) border(all, nil)
putpdf table system_guide(1,1) = ("DATA FOUNDATION")
putpdf table system_guide(1,2) = ("DEFINITIONS AND METHODS")
putpdf table system_guide(1,3) = ("ASSURANCE AND GOVERNANCE")
putpdf table system_guide(1,4) = ("PUBLIC REPORTING")
putpdf table system_guide(2,1) = ("Managed REDCap data, historical records and named monthly releases.")
putpdf table system_guide(2,2) = ("Event, mortality, DCO, metric and uncertainty methods.")
putpdf table system_guide(2,3) = ("Automated checks, human approval, disclosure protection and versioning.")
putpdf table system_guide(2,4) = ("Dashboards, monthly updates, reports and transparent online methods.")

* putpdf table system_guide(1,.), bold font("`font_title'", 6.5, "`bnr_teal'") border(top, single, "`bnr_teal'")
putpdf table system_guide(1,1), bold font("`font_title'", 6.5, "`bnr_area_data'") border(top, single, "`bnr_area_data'")
putpdf table system_guide(1,2), bold font("`font_title'", 6.5, "`bnr_area_methods'") border(top, single, "`bnr_area_methods'")
putpdf table system_guide(1,3), bold font("`font_title'", 6.5, "`bnr_area_governance'") border(top, single, "`bnr_area_governance'")
putpdf table system_guide(1,4), bold font("`font_title'", 6.5, "`bnr_area_reporting'") border(top, single, "`bnr_area_reporting'")
putpdf table system_guide(2,.), font("`font_body'", 6.2, "`bnr_muted'")


putpdf table refit_system_fig = (1,1), width(80%) border(all, nil) halign(center)
putpdf table refit_system_fig(1,1) = image("`refit_system'"), halign(center)
putpdf paragraph
putpdf text ("The four connected areas form the BNR Information Hub. Managed data use common definitions and methods, pass through explicit assurance and governance controls, and support several public products without duplicating the analytical process."), italic font("`font_body'", 7.2, "`bnr_muted'")



* -----------------------------------------------------------------------------
* 7. Closing page - current position and public value
* -----------------------------------------------------------------------------
* DO NOT EDIT THE SECTION BREAK ROUTINELY. It returns the report to A4 portrait.
* EDIT the dated status content only after confirming it against the maintained
* workflows and documentation. Avoid promises that are not approved work.

putpdf sectionbreak, pagesize(A4) margin(top, 0.55) margin(bottom, 0.55) margin(left, 0.65) margin(right, 0.65)
putpdf paragraph
putpdf text ("The BNR refit: current progress"), bold font("`font_title'", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The core data, event, mortality, DCO and dashboard architecture is operating. The annual and one-off report workflows will be completedin early 2027, and testing, manuals and handover continue to March. Later analytical modules remain ongoing work  outside this delivery timetable."), font("`font_body'", 8.5, "`bnr_ink'")



putpdf table current_position = (4,3), width(100%) border(all, nil)
putpdf table current_position(1,1) = ("DELIVERED AND OPERATIONAL")
putpdf table current_position(1,2) = ("SCHEDULED EARLY 2027")
putpdf table current_position(1,3) = ("FUTURE WORK")
putpdf table current_position(2,1) = ("CVD event, mortality and DCO identification and release workflows")
putpdf table current_position(2,2) = ("Annual report workflow - January 2027")
putpdf table current_position(2,3) = ("Survival analysis")
putpdf table current_position(3,1) = ("Dashboards with linked tables and monthly update reports")
putpdf table current_position(3,2) = ("One-off report workflow - February 2027")
putpdf table current_position(3,3) = ("Hospital performance measures")
putpdf table current_position(4,1) = ("Controlled releases, approval and disclosure-protected publication")
putpdf table current_position(4,2) = ("Testing, manuals and staff handover - March 2027")
putpdf table current_position(4,3) = ("Carefully assessed new analytical modules")
putpdf table current_position(.,.), font("`font_body'", 7.5, "`bnr_ink'")
putpdf table current_position(1,1), bold font("`font_title'", 8.0, "`bnr_status_implemented'") border(top, single, "`bnr_status_implemented'")
putpdf table current_position(1,2), bold font("`font_title'", 8.0, "`bnr_status_embedded'") border(top, single, "`bnr_status_embedded'")
putpdf table current_position(1,3), bold font("`font_title'", 8.0, "`bnr_status_later'") border(top, single, "`bnr_status_later'")

putpdf paragraph
putpdf text ("What this means for Barbados"), bold font("`font_title'", 12, "`bnr_ink'")
matrix position_card_widths = (20, 80)
putpdf table national_value = (6,2), width(100%) border(all, nil) width(position_card_widths)
putpdf table national_value(1,1) = ("1")
putpdf table national_value(1,2) = ("Clearer and more timely evidence for government, hospitals, clinics and public-health teams")
putpdf table national_value(2,1) = ("2")
putpdf table national_value(2,2) = ("A more dependable analytical foundation with explicit dataset history")
putpdf table national_value(3,1) = ("3")
putpdf table national_value(3,2) = ("Consistent statistics across public datasets, dashboards, updates and annual reports")
putpdf table national_value(4,1) = ("4")
putpdf table national_value(4,2) = ("Transparent presentation of statistical, linkage and classification uncertainty")
putpdf table national_value(5,1) = ("5")
putpdf table national_value(5,2) = ("Repeatable disclosure protection and visible human approval before publication")
putpdf table national_value(6,1) = ("6")
putpdf table national_value(6,2) = ("A documented system designed for sustainable operation by a small BNR team")
putpdf table national_value(.,.), font("`font_body'", 7.8, "`bnr_ink'")
putpdf table national_value(.,1), bold font("`font_title'", 10.5, "`bnr_teal'") halign(center)

putpdf paragraph
putpdf table closing_note = (2,1), width(100%) border(all, nil)
putpdf table closing_note(1,1) = ("THE PRACTICAL OBJECTIVE"), bold font("`font_title'", 8.2, "`bnr_teal'")
putpdf table closing_note(2,1) = ("The same published statistic should mean the same thing wherever it is encountered - in a dataset, dashboard, monthly update, one-off report or annual report."), font("`font_body'", 8.8, "`bnr_teal'")
putpdf table closing_note(.,.), bgcolor("`bnr_white'") border(top, single, "`bnr_teal'")

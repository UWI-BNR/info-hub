/*******************************************************************************
DO-FILE: bnr_report_annual_2025_focus.do
VERSION: 1.0.1 (3 September 2026)
PURPOSE: Compose the 2025 year-specific Special chapter.

SPECIAL CHAPTER:
  The BNR Refit - from audit to controlled reporting.

This file is deliberately analyst-owned. Unlike the reusable standard section,
it may use reviewed bespoke analysis or external evidence where justified. The
2025 design-development chapter below uses no new analytical dataset. It draws
its narrative from the BNR Process Audit, the Refit Terms of Reference and the
current controlled reporting architecture.
*******************************************************************************/

* Fallback colours make this file readable if opened separately during editing.
if "`bnr_ink'" == ""       local bnr_ink       "44 62 80"
if "`bnr_teal'" == ""      local bnr_teal      "4 81 116"
if "`bnr_pale'" == ""      local bnr_pale      "248 249 250"
if "`bnr_rule'" == ""      local bnr_rule      "222 226 230"
if "`bnr_muted'" == ""     local bnr_muted     "102 102 102"

putpdf pagebreak
putpdf paragraph
putpdf text ("SPECIAL CHAPTER | 2025"), bold font("Arial", 9, "`bnr_teal'")
putpdf paragraph
putpdf text ("The BNR Refit"), bold font("Arial", 22, "`bnr_ink'")
putpdf paragraph
putpdf text ("From audit to controlled reporting"), font("Arial", 13, "`bnr_muted'")

putpdf paragraph
putpdf text ("Why the refit was needed"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The BNR process audit began as a review of the post-REDCap Stata and reporting workflow. It expanded when upstream data and governance problems were found to affect downstream analysis. The audit highlighted four recurring risks: no single definitive cumulative dataset, persistent missingness in important fields, legacy Stata code that mixed cleaning with analysis, and no consistent dataset release and sign-off process.")

putpdf table audit_findings = (5,2), width(100%) border(all, single)
putpdf table audit_findings(1,1) = ("Audit finding")
putpdf table audit_findings(1,2) = ("Why it mattered")
putpdf table audit_findings(2,1) = ("No definitive cumulative dataset")
putpdf table audit_findings(2,2) = ("Parallel copies made it difficult to know which dataset was authoritative.")
putpdf table audit_findings(3,1) = ("Persistent missingness")
putpdf table audit_findings(3,2) = ("Missing identifiers and event dates weakened linkage and downstream analysis.")
putpdf table audit_findings(4,1) = ("Legacy Stata code")
putpdf table audit_findings(4,2) = ("Cleaning and analysis were intertwined, increasing the need for manual editing between exports.")
putpdf table audit_findings(5,1) = ("No consistent release sign-off")
putpdf table audit_findings(5,2) = ("Unverified data could enter analysis or reporting without a formal release decision.")
putpdf table audit_findings(.,.), font("Arial", 8)
putpdf table audit_findings(1,.), bold bgcolor("`bnr_pale'")
putpdf table audit_findings(.,1), bold

putpdf paragraph
putpdf text ("A different operating model"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("The refit response is deliberately architectural rather than a collection of one-off fixes. Data releases are declared and versioned; Stata produces reproducible metric outputs; automated checks and disclosure control happen before human approval; and publication is separated from calculation. The result is a controlled path from source data to public reporting without removing the analyst from the decision process.")

putpdf table refit_flow = (5,2), width(100%) border(all, nil)
putpdf table refit_flow(1,1) = ("1  DATA FREEZE")
putpdf table refit_flow(1,2) = ("A named, versioned source release defines the analytical cycle.")
putpdf table refit_flow(2,1) = ("2  COMPUTE")
putpdf table refit_flow(2,2) = ("Readable Stata programs create the approved surveillance measures and structured outputs.")
putpdf table refit_flow(3,1) = ("3  REVIEW")
putpdf table refit_flow(3,2) = ("Automated QA and disclosure checks prepare a fixed candidate for human inspection.")
putpdf table refit_flow(4,1) = ("4  APPROVE")
putpdf table refit_flow(4,2) = ("An authorised BNR reviewer confirms analytical plausibility, disclosure safety and publication readiness.")
putpdf table refit_flow(5,1) = ("5  PUBLISH")
putpdf table refit_flow(5,2) = ("Only the approved payload is promoted to the public release and website mirror.")
putpdf table refit_flow(.,.), font("Arial", 8)
putpdf table refit_flow(.,1), bold font("Arial", 8, "`bnr_teal'")

putpdf paragraph
putpdf text ("The human role is retained"), bold font("Arial", 11, "`bnr_ink'")
putpdf paragraph
putpdf text ("Automation is used for repeatable calculation and validation, not to remove professional judgement. BNR staff still decide whether the declared source releases are appropriate, whether results are plausible, whether interpretation is suitable, and whether the candidate should be released. Generated datasets and reports are corrected by changing source data or version-controlled code and rerunning the workflow, not by editing public files by hand."), font("Arial", 9)

putpdf pagebreak
putpdf paragraph
putpdf text ("From legacy practice to controlled reporting"), bold font("Arial", 16, "`bnr_ink'")

putpdf table legacy_to_current = (6,3), width(100%) border(all, single)
putpdf table legacy_to_current(1,1) = ("Area")
putpdf table legacy_to_current(1,2) = ("Legacy risk identified by the audit")
putpdf table legacy_to_current(1,3) = ("Refit direction")
putpdf table legacy_to_current(2,1) = ("Dataset identity")
putpdf table legacy_to_current(2,2) = ("Multiple parallel copies with uncertain authority")
putpdf table legacy_to_current(2,3) = ("Declared release IDs, versioned files and controlled promotion")
putpdf table legacy_to_current(3,1) = ("Analytics")
putpdf table legacy_to_current(3,2) = ("Cleaning and analysis combined in evolving scripts")
putpdf table legacy_to_current(3,3) = ("Separated preparation, metric calculation and publication layers")
putpdf table legacy_to_current(4,1) = ("Quality control")
putpdf table legacy_to_current(4,2) = ("Problems often discovered late in analysis")
putpdf table legacy_to_current(4,3) = ("Automated QA plus visible human review before approval")
putpdf table legacy_to_current(5,1) = ("Disclosure")
putpdf table legacy_to_current(5,2) = ("No single repeatable publication gate")
putpdf table legacy_to_current(5,3) = ("Deterministic disclosure control bound to the reviewed candidate")
putpdf table legacy_to_current(6,1) = ("Reporting")
putpdf table legacy_to_current(6,2) = ("Manually assembled outputs with limited reproducibility")
putpdf table legacy_to_current(6,3) = ("Approved public datasets feed dashboards, updates and this annual report")
putpdf table legacy_to_current(.,.), font("Arial", 7.5)
putpdf table legacy_to_current(1,.), bold bgcolor("`bnr_pale'")
putpdf table legacy_to_current(.,1), bold

putpdf paragraph
putpdf text ("What this changes for annual surveillance"), bold font("Arial", 14, "`bnr_ink'")
putpdf paragraph
putpdf text ("This annual report is itself part of the refit. Its standard surveillance section does not reopen confidential source data or recalculate measures that already passed through the event and mortality workflows. It reads the declared approved public releases, combines them into a coherent annual narrative, and then enters its own review and publication gate. The Special chapter remains deliberately flexible so that each annual report can examine one topic in greater depth without weakening the repeatable surveillance core.")

putpdf paragraph
putpdf text ("The practical objective is modest but important: the same published statistic should mean the same thing whether it is encountered in a dataset, dashboard, rolling update or annual report."), bold font("Arial", 10, "`bnr_teal'")

putpdf paragraph
putpdf text ("Sources"), bold font("Arial", 10, "`bnr_ink'")
putpdf paragraph
putpdf text ("BNR Process Audit: Findings (Information Hub); BNR Surveillance Automation and Integrated Digital Reporting, Terms of Reference v1.0 (26 February 2026); current BNR Operations and Technical documentation."), font("Arial", 7, "`bnr_muted'")

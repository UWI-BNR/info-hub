/*******************************************************************************
Annual CVD report: standard section

This small shared section is included only by bnr_report_annual_s1_build.do.
It relies on that master DO file's local release identifiers. The first pass
deliberately establishes the PDF composition and immutable-source boundary
before tables, figures and final design are added.
*******************************************************************************/

putpdf paragraph
putpdf text ("Standard surveillance section"), bold font("Arial", 14)
putpdf paragraph
putpdf text ("This candidate report uses only the declared approved public CVD-event and mortality releases. The completed standard section will add reviewed tables, figures and annual interpretation without changing this source boundary.")
putpdf paragraph
putpdf text ("Declared CVD-event release: `event_release'")
putpdf paragraph
putpdf text ("Declared mortality release: `mortality_release'")

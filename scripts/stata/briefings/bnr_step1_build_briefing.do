/*
* =====================================================================
 DO-FILE:     bnr_step1_build_briefing.do
 PROJECT:     BNR info-hub
 PURPOSE:     Send one briefing build request to the correct analyst DO file

 VERSION:     v1.3

 This is deliberately a very small dispatcher. It contains no analytical
 decisions and creates no outputs itself. Each briefing retains its own
 readable analyst-owned DO file.
* =====================================================================
*/

version 19.0
set more off

args briefing_type release_year release_month briefing_version replace_option

if "`briefing_type'" == "" | "`release_year'" == "" | ///
   "`release_month'" == "" | "`briefing_version'" == "" {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "BNR BRIEFING STEP 1 STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Reason: Required briefing build inputs were not supplied." _n ///
        as text "  Files created: No" _n ///
        as text "  Next: use Briefing Step 1 or see" _n ///
        as text "        help bnr_step1_build_briefing." _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

local selected = lower(strtrim("`briefing_type'"))

if inlist("`selected'", "cvd incidence rates", "incidence") {
    do "$BNR_STATA/briefings/cvd_incidence/cvd_incidence.do" ///
        `release_year' `release_month' `briefing_version' `replace_option'
    exit
}

if inlist("`selected'", "cvd case-fatality", "case_fatality") {
    do "$BNR_STATA/briefings/cvd_case_fatality/cvd_case_fatality.do" ///
        `release_year' `release_month' `briefing_version' `replace_option'
    exit
}

if inlist("`selected'", "cvd length of stay", "length_of_stay") {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "BNR BRIEFING STEP 1 STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Briefing: CVD length of stay" _n ///
        as text "  Reason: this briefing has not yet been migrated." _n ///
        as text "  Files created: No" _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

if inlist("`selected'", "cvd mortality rates", "mortality") {
    qui {
        noi display as error _n ///
        "------------------------------------------------------------" _n ///
        "BNR BRIEFING STEP 1 STOPPED" _n ///
        "------------------------------------------------------------" _n ///
        as text "  Briefing: CVD mortality rates" _n ///
        as text "  Reason: this briefing has not yet been migrated." _n ///
        as text "  Files created: No" _n ///
        as error "------------------------------------------------------------" _n
    }
    exit 198
}

qui {
    noi display as error _n ///
    "------------------------------------------------------------" _n ///
    "BNR BRIEFING STEP 1 STOPPED" _n ///
    "------------------------------------------------------------" _n ///
    as text "  Reason: unknown briefing type." _n ///
    as result "  Value supplied: `briefing_type'" _n ///
    as text "  Files created: No" _n ///
    as error "------------------------------------------------------------" _n
}
exit 198

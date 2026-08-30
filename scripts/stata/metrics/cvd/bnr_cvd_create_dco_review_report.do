/*******************************************************************************
DO-FILE: bnr_cvd_create_dco_review_report.do
VERSION: 1.0.0 (29 August 2026)
PURPOSE: Create a private BNR worklist for uncertain or reviewable DCO linkage
         records after deterministic L01-L03 linkage.

This report is private operational review material. It may contain names, NRNs
and linkage diagnostics. It must never be copied to public staging or the site.

Corrections are NOT made in this workbook. BNR staff correct the authoritative
source record, then rerun the workflow. Remaining unresolved records continue
through the approved aggregate unresolved-link estimator.

USAGE:
  do "$BNR_STATA/metrics/cvd/bnr_cvd_create_dco_review_report.do" 2026 1 2026 7
  do "$BNR_STATA/metrics/cvd/bnr_cvd_create_dco_review_report.do" 2026 1 2026 7 replace
*******************************************************************************/

version 19
clear all
set more off

args cvd_year cvd_month mortality_year mortality_month option

foreach argument in cvd_year cvd_month mortality_year mortality_month {
    if "``argument''" == "" exit 198
}
if "`option'" != "" & lower("`option'") != "replace" exit 198
local replace_existing = (lower("`option'") == "replace")

foreach argument in cvd_year cvd_month mortality_year mortality_month {
    local `argument'_number = real("``argument''")
    if missing(``argument'_number') | ``argument'_number' != floor(``argument'_number') exit 198
}
if !inrange(`cvd_month_number', 1, 12) | !inrange(`mortality_month_number', 1, 12) exit 198

if "$BNR_PRIVATE" == "" | "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        exit `config_rc'
    }
}
foreach required_global in BNR_PRIVATE BNR_STATA BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" exit 198
}

local cy : display %04.0f `cvd_year_number'
local cm : display %02.0f `cvd_month_number'
local my : display %04.0f `mortality_year_number'
local mm : display %02.0f `mortality_month_number'

local linkage_release "cvd_`cy'_`cm'_mort_`my'_`mm'"
local linkage_dir "$BNR_PRIVATE/data/derived/cvd/y`cy'/m`cm'/linkage/mort_y`my'_m`mm'"
local linkage_input "`linkage_dir'/stage4_l01_l03_episode_diagnostic_`linkage_release'.dta"
local review_dir "`linkage_dir'/review"
local review_dta "`review_dir'/cvd_dco_linkage_review_`linkage_release'.dta"
local review_xlsx "`review_dir'/cvd_dco_linkage_review_`linkage_release'.xlsx"
local summary_csv "`review_dir'/cvd_dco_linkage_review_summary_`linkage_release'.csv"
local output_log "$BNR_PRIVATE_LOGS/bnr_cvd_dco_review_`cy'`cm'_mort_`my'`mm'.log"

capture confirm file "`linkage_input'"
if _rc {
    display as error "Required Stage 4C linkage diagnostic was not found: `linkage_input'"
    exit 601
}

foreach output_file in review_dta review_xlsx summary_csv {
    capture confirm file "``output_file''"
    if !_rc & !`replace_existing' {
        display as error "A private DCO review output already exists: ``output_file''"
        display as error "Review it or rerun with the explicit replace argument."
        exit 602
    }
}

capture mkdir "`review_dir'"
capture mkdir "$BNR_PRIVATE_LOGS"
capture log close dcoreview
log using "`output_log'", text replace name(dcoreview)

use "`linkage_input'", clear
isid record_id

local required_variables record_id dth_date dth_year pname nrn mortality_sex ///
    mortality_age mortality_agetxt cvd_prim cvd_incl cvd_sub_p cvd_sub_i ///
    final_person_match final_linkage_rule_id final_linkage_status ///
    final_episode_outcome
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "Private linkage review variable is absent: `variable'"
        log close dcoreview
        exit 111
    }
}

* Optional diagnostic fields are created as missing when an earlier linkage
* version did not retain them. This keeps the review report handover-friendly.
capture confirm variable l02_candidate_n
if _rc generate long l02_candidate_n = .
capture confirm variable l03_candidate_n
if _rc generate long l03_candidate_n = .
capture confirm variable l03_match_basis
if _rc generate str12 l03_match_basis = ""
capture confirm variable episode_event_count_0_27
if _rc generate long episode_event_count_0_27 = .
capture confirm variable episode_heart_count_0_27
if _rc generate long episode_heart_count_0_27 = .
capture confirm variable episode_stroke_count_0_27
if _rc generate long episode_stroke_count_0_27 = .
capture confirm variable nearest_prior_event_date
if _rc generate double nearest_prior_event_date = .
capture confirm variable nearest_prior_event_days
if _rc generate double nearest_prior_event_days = .
capture confirm variable remote_prior_event
if _rc generate byte remote_prior_event = .
format dth_date nearest_prior_event_date %td

generate str44 review_category = ""
replace review_category = "recorded_event_0_27_days" if ///
    final_episode_outcome == "recorded_event_0_27_days"
replace review_category = "deterministic_additional_dco" if ///
    final_episode_outcome == "provisional_additional_dco"
replace review_category = "remote_prior_event_over_27_days" if ///
    final_episode_outcome == "provisional_additional_dco" & ///
    remote_prior_event == 1
replace review_category = "unresolved_multiple_candidates" if ///
    final_person_match == 0 & ///
    ((!missing(l02_candidate_n) & l02_candidate_n > 1) | ///
     (!missing(l03_candidate_n) & l03_candidate_n > 1))
replace review_category = "unresolved_identifier_conflict" if ///
    final_person_match == 0 & ///
    (strpos(lower(final_linkage_status), "conflict") > 0 | ///
     strpos(lower(final_linkage_status), "duplicate") > 0)
replace review_category = "unresolved_insufficient_identifiers" if ///
    final_person_match == 0 & review_category == "" & ///
    strtrim(pname) == "" & strtrim(nrn) == ""
replace review_category = "unresolved_no_unique_match" if ///
    final_person_match == 0 & review_category == ""
replace review_category = "other_linkage_review" if review_category == ""

generate byte review_required = ///
    strpos(review_category, "unresolved_") == 1 | ///
    review_category == "remote_prior_event_over_27_days" | ///
    review_category == "other_linkage_review"

generate byte review_priority = 9
replace review_priority = 1 if inlist(review_category, ///
    "unresolved_multiple_candidates", "unresolved_identifier_conflict")
replace review_priority = 2 if review_category == "unresolved_insufficient_identifiers"
replace review_priority = 3 if review_category == "unresolved_no_unique_match"
replace review_priority = 4 if review_category == "remote_prior_event_over_27_days"
replace review_priority = 5 if review_category == "other_linkage_review"

generate str160 review_reason = "No manual review required by the linkage rule."
replace review_reason = ///
    "More than one plausible deterministic hospital-event person match remains." ///
    if review_category == "unresolved_multiple_candidates"
replace review_reason = ///
    "Identifiers conflict or duplicate identifier evidence prevents deterministic linkage." ///
    if review_category == "unresolved_identifier_conflict"
replace review_reason = ///
    "Both name and NRN are absent, leaving insufficient identity evidence for deterministic linkage." ///
    if review_category == "unresolved_insufficient_identifiers"
replace review_reason = ///
    "No unique deterministic person match was established after L01-L03." ///
    if review_category == "unresolved_no_unique_match"
replace review_reason = ///
    "A same-person hospital event exists more than 27 days before death; review may clarify whether the terminal event is separate." ///
    if review_category == "remote_prior_event_over_27_days"
replace review_reason = ///
    "Linkage outcome does not fit a standard review category and should be checked." ///
    if review_category == "other_linkage_review"

generate str24 review_decision = ""
generate str244 review_note = ""

order review_priority review_required review_category review_reason ///
    record_id pname nrn mortality_sex mortality_age mortality_agetxt ///
    dth_date dth_year cvd_prim cvd_incl cvd_sub_p cvd_sub_i ///
    final_person_match final_linkage_rule_id final_linkage_status ///
    final_episode_outcome l02_candidate_n l03_candidate_n l03_match_basis ///
    episode_event_count_0_27 episode_heart_count_0_27 ///
    episode_stroke_count_0_27 nearest_prior_event_date ///
    nearest_prior_event_days remote_prior_event review_decision review_note

sort review_priority dth_year record_id
label data "BNR private DCO linkage review worklist"
label variable review_required "1 = record may benefit from BNR human review"
label variable review_priority "1 highest review priority; 9 no manual review required"
label variable review_decision "Worklist note only; correct authoritative source and rerun"
label variable review_note "Worklist note only; not an authoritative correction"

save "`review_dta'", replace

tempfile summary_dta
preserve
    generate long candidate_n = 1
    generate long primary_candidate_n = cvd_prim
    generate long inclusive_candidate_n = cvd_incl
    collapse (sum) candidate_n primary_candidate_n inclusive_candidate_n, ///
        by(dth_year review_category review_required)
    sort dth_year review_required review_category
    save "`summary_dta'", replace
    export delimited using "`summary_csv'", replace
restore

* Workbook sheet 1: short operational guidance.
clear
set obs 8
generate str40 item = ""
generate str244 guidance = ""
replace item = "Purpose" in 1
replace guidance = "Private worklist for uncertain or reviewable CVD death-to-event linkage records." in 1
replace item = "Confidentiality" in 2
replace guidance = "This workbook may contain names, NRNs and private linkage evidence. Keep it inside the BNR private environment." in 2
replace item = "Correction rule" in 3
replace guidance = "Do not treat workbook edits as source corrections. Correct the authoritative source record and rerun the workflow." in 3
replace item = "Unresolved cases" in 4
replace guidance = "Cases that remain unresolved are handled only by the approved aggregate estimator; they are not relabelled individually." in 4
replace item = "Remote prior event" in 5
replace guidance = "An event more than 27 days before death does not automatically represent the terminal CVD event." in 5
replace item = "Primary" in 6
replace guidance = "Primary mortality definition uses the approved clear/likely classification." in 6
replace item = "Inclusive" in 7
replace guidance = "Inclusive adds the approved possible mortality classification to Primary." in 7
replace item = "Review fields" in 8
replace guidance = "review_decision and review_note are convenience fields only; retain final corrections in the authoritative source." in 8
export excel using "`review_xlsx'", sheet("Guidance") firstrow(variables) replace

use "`summary_dta'", clear
export excel using "`review_xlsx'", sheet("Summary") firstrow(variables) sheetreplace

use "`review_dta'", clear
keep if review_required == 1
quietly count
if r(N) == 0 {
    clear
    set obs 1
    generate str44 review_category = "none"
    generate str160 review_reason = "No records require manual linkage review."
}
export excel using "`review_xlsx'", sheet("Needs review") firstrow(variables) sheetreplace

use "`review_dta'", clear
keep if final_episode_outcome == "provisional_additional_dco"
quietly count
if r(N) == 0 {
    clear
    set obs 1
    generate str44 review_category = "none"
    generate str160 review_reason = "No deterministic additional-DCO candidates."
}
export excel using "`review_xlsx'", sheet("DCO candidates") firstrow(variables) sheetreplace

use "`review_dta'", clear
quietly count if review_required == 1
local review_n = r(N)
quietly count if review_category == "unresolved_multiple_candidates"
local multiple_n = r(N)
quietly count if review_category == "unresolved_identifier_conflict"
local conflict_n = r(N)
quietly count if review_category == "unresolved_insufficient_identifiers"
local insufficient_id_n = r(N)
quietly count if review_category == "unresolved_no_unique_match"
local unresolved_n = r(N)
quietly count if review_category == "remote_prior_event_over_27_days"
local remote_n = r(N)

display as result ""
display as result "PRIVATE DCO LINKAGE REVIEW PACKAGE CREATED"
display as result "  Records requiring review:      `review_n'"
display as result "  Multiple candidates:           `multiple_n'"
display as result "  Identifier conflicts:          `conflict_n'"
display as result "  Insufficient identifiers:      `insufficient_id_n'"
display as result "  Other unresolved/no unique:    `unresolved_n'"
display as result "  Remote prior events >27 days:  `remote_n'"
display as result "  Private workbook:              `review_xlsx'"
display as result "  Private review DTA:            `review_dta'"
display as result "  Aggregate summary:             `summary_csv'"

log close dcoreview

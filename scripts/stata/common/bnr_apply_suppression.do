/*******************************************************************************
DO-FILE:     bnr_apply_suppression.do
VERSION:     1.0.0 (23 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 5 - create a disclosure-controlled review candidate

PURPOSE:     Apply the public suppression contract to one exact private metric
             dataset for human review. This helper does not create the
             public_ready folder, approve, promote or publish files.

USAGE:       Called by bnr_cvd_review_controller.do.

ARGUMENTS:   private_dta public_dta disclosure_qa_dta release_id
*******************************************************************************/

version 19
set more off

args private_dta public_dta disclosure_qa_dta release_id

if `"`private_dta'"' == "" | `"`public_dta'"' == "" | ///
        `"`disclosure_qa_dta'"' == "" | `"`release_id'"' == "" {
    display as error "bnr_apply_suppression.do received an incomplete contract."
    exit 198
}

capture confirm file `"`private_dta'"'
if _rc {
    display as error "Private metric dataset not found:"
    display as error `"  `private_dta'"'
    exit 601
}

use `"`private_dta'"', clear

local required_variables metric_id release_id period_type period ///
    period_start period_year period_month period_quarter period_complete ///
    event_type sex source_status statistic value unit numerator denominator ///
    comparison_n status_flag sdc_policy primary_suppression_threshold ///
    primary_suppression related_primary_cells related_suppression_review ///
    suppression_review suppression_reason

foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc {
        display as error "Step 5 input variable is absent: `variable'"
        exit 111
    }
}

quietly count
local private_rows = r(N)
if `private_rows' == 0 {
    display as error "The private Step 4 metric dataset contains no rows."
    exit 2000
}

quietly count if release_id != "`release_id'"
if r(N) {
    display as error "The Step 4 dataset contains the wrong release_id."
    exit 459
}

foreach identifier in eid recid patid fname lname name dob address telephone ///
        phone email national_id {
    capture confirm variable `identifier'
    if !_rc {
        display as error "Potential individual identifier found: `identifier'"
        exit 459
    }
}

* Public rows are retained. Observable must distinguish suppression from absent
* data by reading suppression_status, never by inferring from a missing value.
generate str12 suppression_status = "none"
generate str80 suppression_note = ""

replace suppression_status = "primary" if primary_suppression == 1
replace suppression_status = "derived" ///
    if suppression_status == "none" & related_suppression_review == 1

* Incomplete disease-specific quarter/year values would reveal withheld monthly
* disease-specific counts by differencing successive public releases.
generate byte __temporal_risk = period_complete == 0 & ///
    inlist(period_type, "quarterly", "annual") & ///
    ((event_type != "all_cvd" & ///
        inlist(statistic, "quarterly_count", "annual_count")) | ///
      metric_id == "CVD-BURDEN-002")

replace suppression_status = "derived" ///
    if suppression_status == "none" & __temporal_risk

* A complete additive panel containing a primary or linked-risk cell is treated
* conservatively as one disclosure unit. This avoids fragile cell-by-cell
* complementary-suppression logic and prevents reconstruction from siblings or
* totals. Temporal-risk rows do not trigger this rule: all disease-specific
* incomplete rows are already suppressed together above.
generate byte __panel_trigger = ///
    primary_suppression == 1 | related_suppression_review == 1

bysort metric_id period_type period_year period_month period_quarter statistic: ///
    egen byte __panel_review = max(__panel_trigger)

replace suppression_status = "secondary" ///
    if suppression_status == "none" & __panel_review == 1

replace suppression_note = ///
    "Primary suppression under the BNR statistical disclosure-control policy." ///
    if suppression_status == "primary"
replace suppression_note = ///
    "Complementary suppression prevents reconstruction from related values." ///
    if suppression_status == "secondary"
replace suppression_note = ///
    "A derived value is linked to a disclosure risk." ///
    if suppression_status == "derived" & __temporal_risk == 0
replace suppression_note = ///
    "Suppressed to prevent reconstruction by differencing successive releases." ///
    if suppression_status == "derived" & __temporal_risk == 1

generate str24 display_value = ""
replace display_value = strtrim(string(value, "%18.8g")) ///
    if suppression_status == "none" & !missing(value)
replace display_value = "*" if suppression_status != "none"

quietly count if suppression_status == "primary"
local primary_rows = r(N)
quietly count if suppression_status == "secondary"
local secondary_rows = r(N)
quietly count if suppression_status == "derived"
local derived_rows = r(N)
quietly count if suppression_status != "none"
local suppressed_rows = r(N)

quietly count if primary_suppression == 1 & ///
    suppression_status != "primary"
local primary_misclassified = r(N)

quietly count if related_suppression_review == 1 & ///
    !inlist(suppression_status, "primary", "derived")
local linked_misclassified = r(N)

* Remove every exact numeric field from suppressed public rows.
replace value = .       if suppression_status != "none"
replace numerator = .   if suppression_status != "none"
replace denominator = . if suppression_status != "none"

drop primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

drop __panel_trigger __temporal_risk

order metric_id release_id period_type period period_start period_year ///
    period_month period_quarter period_complete event_type sex source_status ///
    statistic value display_value unit numerator denominator comparison_n ///
    status_flag sdc_policy suppression_status suppression_note

sort metric_id period_type period_year period_month event_type sex statistic

label data "BNR CVD burden metrics - Step 5 review candidate"
label variable display_value "Public display value; * means suppressed"
label variable suppression_status ///
    "Public suppression status: none, primary, secondary or derived"
label variable suppression_note "Public suppression explanation"

notes _dta: package_status: review_candidate
notes _dta: disclosure_policy: bnr_sdc_v1
notes _dta: suppressed_rows_retain_categories: true
notes _dta: suppressed_exact_numeric_fields_removed: true
notes _dta: observable_contract: use suppression_status; do not infer suppression from missing value

* ---------------------------------------------------------------------------
* Disclosure QA
* ---------------------------------------------------------------------------

tempname qa_handle
postfile `qa_handle' str45 check str8 result str244 detail ///
    using `"`disclosure_qa_dta'"', replace

quietly count
local public_rows = r(N)
local result = cond(`public_rows' == `private_rows', "PASS", "FAIL")
post `qa_handle' ("Rows retained") ("`result'") ///
    ("All aggregate rows remain present in the disclosure-controlled candidate")

quietly count if release_id != "`release_id'"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Release identity") ("`result'") ///
    ("Every row matches the requested release")

quietly count if !inlist(suppression_status, ///
    "none", "primary", "secondary", "derived")
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Suppression status contract") ("`result'") ///
    ("Only the four documented public statuses are present")

local result = cond(`primary_misclassified' == 0, "PASS", "FAIL")
post `qa_handle' ("Primary suppression applied") ("`result'") ///
    ("Every Step 4 primary row was classified primary before private flags were removed")

local result = cond(`linked_misclassified' == 0, "PASS", "FAIL")
post `qa_handle' ("Linked suppression applied") ("`result'") ///
    ("Every Step 4 linked-risk row was suppressed")

quietly count if suppression_status != "none" & ///
    (!missing(value) | !missing(numerator) | !missing(denominator))
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Suppressed numeric fields blank") ("`result'") ///
    ("No suppressed row retains value, numerator or denominator")

quietly count if suppression_status != "none" & display_value != "*"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Suppressed display values") ("`result'") ///
    ("Every suppressed row displays an asterisk")

quietly count if suppression_status == "none" & display_value == "*"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Unsuppressed display values") ("`result'") ///
    ("No unsuppressed row is labelled as suppressed")

quietly count if __panel_review == 1 & suppression_status == "none"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Complementary panel suppression") ("`result'") ///
    ("No complete additive panel linked to a primary risk remains partly exposed")

quietly count if period_complete == 0 & ///
    inlist(period_type, "quarterly", "annual") & ///
    ((event_type != "all_cvd" & ///
        inlist(statistic, "quarterly_count", "annual_count")) | ///
      metric_id == "CVD-BURDEN-002") & ///
    suppression_status == "none"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Temporal differencing protection") ("`result'") ///
    ("Incomplete disease-specific quarter/year outputs cannot reveal withheld monthly counts")

local private_flags primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason
local private_flag_found 0
foreach variable of local private_flags {
    capture confirm variable `variable'
    if !_rc local private_flag_found 1
}
local result = cond(`private_flag_found' == 0, "PASS", "FAIL")
post `qa_handle' ("Private review fields removed") ("`result'") ///
    ("Internal Step 4 suppression fields are absent from the review candidate")

local identifier_found 0
foreach identifier in eid recid patid fname lname name dob address telephone ///
        phone email national_id {
    capture confirm variable `identifier'
    if !_rc local identifier_found 1
}
local result = cond(`identifier_found' == 0, "PASS", "FAIL")
post `qa_handle' ("Individual identifiers absent") ("`result'") ///
    ("No named individual identifier is present")

postclose `qa_handle'

preserve
    use `"`disclosure_qa_dta'"', clear
    quietly count if result != "PASS"
    local failed_checks = r(N)
restore

if `failed_checks' {
    display as error "Public-ready disclosure QA contains a failed check."
    exit 459
}

drop __panel_review
save `"`public_dta'"', replace

display as result "Disclosure-controlled review candidate created."
display as result "  Primary rows:   `primary_rows'"
display as result "  Secondary rows: `secondary_rows'"
display as result "  Derived rows:   `derived_rows'"
display as result "  Total suppressed: `suppressed_rows'"

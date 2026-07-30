/*******************************************************************************
DO-FILE:     bnr_step5_suppress.do
VERSION:     2.4.1 (30 July 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    Step 5 - create a disclosure-controlled review candidate

PURPOSE:     Apply the BNR public disclosure-control contract to one exact
             private metric dataset and create a review candidate.

             The helper:
             1. retains every aggregate row;
             2. classifies rows as none, primary, secondary, temporal or derived;
             3. removes exact numeric content from every suppressed row;
             4. writes an asterisk to display_value for suppressed rows;
             5. removes internal Step 4 disclosure-review fields;
             6. creates a disclosure QA dataset;
             7. stops if any disclosure QA check fails.

             The helper does NOT create public_ready, approve, promote or
             publish files.

DISCLOSURE TERMS:
             Primary suppression
             A small cell identified directly by the agreed BNR SDC rule.

             Secondary suppression
             An additional related cell suppressed so the primary value cannot
             be reconstructed from totals or sibling categories.

             Derived suppression
             A percentage, total or incomplete-period value suppressed because
             it could reveal another protected value.

             Temporal differencing
             Reconstruction of a withheld monthly count by subtracting one
             cumulative quarterly or annual release from another.

PUBLIC CONTRACT:
             Suppressed rows are retained. Users must read suppression_status.
             They must not infer suppression from a missing value alone.
             For suppressed rows, value, numerator and denominator are blank
             and display_value is "*".

USAGE:       Called only by bnr_step5_review.do.

ARGUMENTS:   private_dta
             public_dta
             disclosure_qa_dta
             release_id
             previous_public_dta
             previous_private_dta
             previous_release_id

EDITING:     Change disclosure logic only after an agreed governance and
             statistical-disclosure-control decision. The comments below are
             intentionally detailed for mixed-skill handover.
*******************************************************************************/

version 19
set more off

* ---------------------------------------------------------------------------
* 1. RECEIVE AND CHECK THE FOUR-FILE CONTRACT FROM THE STEP 5 CONTROLLER
* ---------------------------------------------------------------------------
args private_dta public_dta disclosure_qa_dta release_id ///
    previous_public_dta previous_private_dta previous_release_id

if `"`private_dta'"' == "" | `"`public_dta'"' == "" | ///
        `"`disclosure_qa_dta'"' == "" | `"`release_id'"' == "" | ///
        `"`previous_public_dta'"' == "" | ///
        `"`previous_private_dta'"' == "" | `"`previous_release_id'"' == "" {
    display as error "bnr_step5_suppress.do received an incomplete contract."
    exit 198
}

capture confirm file `"`private_dta'"'
if _rc {
    display as error "Private metric dataset not found:"
    display as error `"  `private_dta'"'
    exit 601
}

use `"`private_dta'"', clear

* ---------------------------------------------------------------------------
* 2. CHECK THE PRIVATE STEP 4 METRIC DATASET
*
* These variables form the minimum interface between Step 4 and Step 5.
* Keeping the list here makes the hand-off contract visible in one place.
* ---------------------------------------------------------------------------
local required_variables metric_id release_id period_type period ///
    period_start period_year period_month period_quarter period_complete ///
    event_type sex age_group source_status statistic value unit numerator denominator ///
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

* AGE-DIMENSION CONTRACT
* Step 4 now supplies age-specific annual all-CVD counts, five-year means and
* age distributions.  These checks prevent a future calculation change from
* silently creating age-by-sex, age-by-event-type or subannual combinations.
quietly count if !inlist(age_group, "all", "under_70", "age_70_plus")
if r(N) {
    display as error "Step 5 found an unexpected age_group value."
    exit 459
}

quietly count if age_group != "all" & ///
    !(period_type == "annual" & event_type == "all_cvd" & sex == "all" & ///
      inlist(statistic, "annual_count", "annual_previous_5yr_mean", ///
        "age_distribution"))
if r(N) {
    display as error "An age-specific row falls outside the approved Step 4 contract."
    exit 459
}

quietly count if statistic == "age_distribution" & ///
    !(period_type == "annual" & event_type == "all_cvd" & sex == "all" & ///
      inlist(age_group, "under_70", "age_70_plus"))
if r(N) {
    display as error "An age-distribution row falls outside the approved contract."
    exit 459
}

* ---------------------------------------------------------------------------
* 3. CLASSIFY EVERY ROW UNDER THE PUBLIC DISCLOSURE CONTRACT
*
* No aggregate row is deleted. This preserves the shape of the metric dataset
* and allows dashboards to distinguish:
*   - a genuine missing value;
*   - an incomplete period;
*   - a value deliberately suppressed for disclosure control.
*
* Consumers must therefore use suppression_status and display_value.
* ---------------------------------------------------------------------------
generate byte step4_primary_flag = primary_suppression == 1
generate byte step4_related_flag = related_suppression_review == 1
generate byte step5_temporal_flag = 0
generate byte step5_complementary_flag = 0
generate byte step5_derived_flag = 0

* These audit fields explain the temporal comparison for every row.
* They remain in the private review candidate so the reviewer can see exactly
* why an incomplete-period count was published or withheld.
generate str11 previous_release_id = "`previous_release_id'"
generate byte previous_release_found = .
generate double previous_value = .
generate double temporal_increment = .
generate str40 temporal_check = "not_applicable"

generate str12 suppression_status = "none"
generate str244 disclosure_note = "No disclosure restriction identified."

* PRIMARY SUPPRESSION
* Step 4 has already identified a directly small numerator or denominator.
replace suppression_status = "primary" if step4_primary_flag == 1

* TEMPORAL DIFFERENCING OF COUNTS
*
* The public can compare successive cumulative releases. A current total may
* therefore be safe in isolation but still reveal a small monthly increment
* when the previous release is subtracted.
*
* Step 5 applies temporal suppression only when BOTH conditions are true:
*   1. the equivalent row in the previous approved release was public; and
*   2. the increase from the previous private count is between 1 and 5.
*
* If the previous row was suppressed, the public cannot calculate the change.
* The current row is therefore not suppressed merely because its private
* predecessor exists. This prevents suppression from carrying forward forever.
*
* A negative change indicates a data revision rather than a new-event count.
* It is conservatively withheld for review and clearly identified in the audit.
*
* Only incomplete AMI and stroke cumulative count rows are assessed here.
generate byte __temporal_candidate = period_complete == 0 & ///
    inlist(period_type, "quarterly", "annual") & ///
    event_type != "all_cvd" & ///
    inlist(statistic, "quarterly_count", "annual_count")

* Read the release month from release_id, for example cvd_2024_03 -> 3.
local release_month = real(substr("`release_id'", 10, 2))

* January starts a new annual accumulation. January, April, July and October
* start new quarterly accumulations. At those points Step 4 primary suppression
* already protects a current count of 1 to 5, so no temporal comparison is needed.
generate byte __period_start = 0
replace __period_start = 1 if __temporal_candidate == 1 & ///
    statistic == "annual_count" & `release_month' == 1
replace __period_start = 1 if __temporal_candidate == 1 & ///
    statistic == "quarterly_count" & ///
    inlist(`release_month', 1, 4, 7, 10)

replace previous_release_found = 1 if __period_start == 1
replace previous_value = 0 if __period_start == 1
replace temporal_increment = value if __period_start == 1
replace temporal_check = "period_start" if __period_start == 1

* For later releases, use the previous public_ready dataset only to establish
* whether the matching previous row was public. Use the previous private Step 4
* dataset to obtain the unblanked count needed for the protected comparison.
tempfile previous_public_rows previous_private_counts

capture confirm file `"`previous_public_dta'"'
local previous_approved = (_rc == 0)

capture confirm file `"`previous_private_dta'"'
local previous_private_found = (_rc == 0)

local previous_public_structure_ok 0
if `previous_approved' {
    preserve
        use `"`previous_public_dta'"', clear
        local previous_public_required metric_id period_type period_year ///
            period_quarter event_type sex age_group statistic suppression_status
        local previous_public_structure_ok 1
        foreach variable of local previous_public_required {
            capture confirm variable `variable'
            if _rc local previous_public_structure_ok 0
        }
        if `previous_public_structure_ok' {
            keep if inlist(statistic, "annual_count", "quarterly_count")
            keep metric_id period_type period_year period_quarter event_type ///
                sex age_group statistic suppression_status
            rename suppression_status previous_suppression_status
            duplicates drop metric_id period_type period_year period_quarter ///
                event_type sex age_group statistic, force
            save `"`previous_public_rows'"', replace
        }
    restore
}

local previous_private_structure_ok 0
if `previous_private_found' {
    preserve
        use `"`previous_private_dta'"', clear
        local previous_private_required metric_id period_type period_year ///
            period_quarter event_type sex age_group statistic value
        local previous_private_structure_ok 1
        foreach variable of local previous_private_required {
            capture confirm variable `variable'
            if _rc local previous_private_structure_ok 0
        }
        if `previous_private_structure_ok' {
            keep if inlist(statistic, "annual_count", "quarterly_count")
            keep metric_id period_type period_year period_quarter event_type ///
                sex age_group statistic value
            rename value __previous_value
            duplicates drop metric_id period_type period_year period_quarter ///
                event_type sex age_group statistic, force
            save `"`previous_private_counts'"', replace
        }
    restore
}

if `previous_public_structure_ok' & `previous_private_structure_ok' {
    merge m:1 metric_id period_type period_year period_quarter event_type ///
        sex age_group statistic using `"`previous_public_rows'"', ///
        keep(master match) nogen
    merge m:1 metric_id period_type period_year period_quarter event_type ///
        sex age_group statistic using `"`previous_private_counts'"', ///
        keep(master match) nogen

    replace previous_release_found = 1 if __temporal_candidate == 1 & ///
        __period_start == 0 & previous_suppression_status != ""
    replace previous_value = __previous_value if __temporal_candidate == 1 & ///
        __period_start == 0 & !missing(__previous_value)

    * A previous public value permits a genuine differencing check.
    replace temporal_check = "previous_public_value" if ///
        __temporal_candidate == 1 & __period_start == 0 & ///
        previous_suppression_status == "none" & !missing(previous_value)
    replace temporal_increment = value - previous_value if ///
        temporal_check == "previous_public_value"

    * A suppressed previous value cannot be subtracted by a public user.
    replace temporal_check = "previous_not_public" if ///
        __temporal_candidate == 1 & __period_start == 0 & ///
        previous_suppression_status != "" & ///
        previous_suppression_status != "none"

    replace temporal_check = "previous_public_row_missing" if ///
        __temporal_candidate == 1 & __period_start == 0 & ///
        previous_suppression_status == ""
    replace temporal_check = "previous_private_row_missing" if ///
        __temporal_candidate == 1 & __period_start == 0 & ///
        previous_suppression_status == "none" & missing(previous_value)

    drop __previous_value previous_suppression_status
}
else if !`previous_approved' {
    replace previous_release_found = 0 if __temporal_candidate == 1 & ///
        __period_start == 0
    replace temporal_check = "previous_release_unapproved" if ///
        __temporal_candidate == 1 & __period_start == 0
}
else if !`previous_public_structure_ok' {
    replace previous_release_found = 0 if __temporal_candidate == 1 & ///
        __period_start == 0
    replace temporal_check = "previous_public_structure_invalid" if ///
        __temporal_candidate == 1 & __period_start == 0
}
else if !`previous_private_found' {
    replace previous_release_found = 0 if __temporal_candidate == 1 & ///
        __period_start == 0
    replace temporal_check = "previous_private_missing" if ///
        __temporal_candidate == 1 & __period_start == 0
}
else {
    replace previous_release_found = 0 if __temporal_candidate == 1 & ///
        __period_start == 0
    replace temporal_check = "previous_private_structure_invalid" if ///
        __temporal_candidate == 1 & __period_start == 0
}

* Suppress only an observed positive increment of 1 to 5. Negative changes and
* unavailable comparisons are conservatively withheld for explicit review.
replace step5_temporal_flag = 1 if __temporal_candidate == 1 & ///
    inrange(temporal_increment, 1, 5)
replace step5_temporal_flag = 1 if __temporal_candidate == 1 & ///
    temporal_increment < 0 & !missing(temporal_increment)
replace step5_temporal_flag = 1 if __temporal_candidate == 1 & ///
    inlist(temporal_check, "previous_release_unapproved", ///
        "previous_public_structure_invalid", "previous_public_row_missing", ///
        "previous_private_missing", "previous_private_structure_invalid", ///
        "previous_private_row_missing")

replace suppression_status = "temporal" if ///
    suppression_status == "none" & step5_temporal_flag == 1

* SECONDARY / COMPLEMENTARY SUPPRESSION
*
* Annual and quarterly AMI/stroke counts form a two-by-two event-by-sex table:
*
*                      Female          Male
*                   -------------------------
*             AMI   |  interior cell   interior cell
*          Stroke   |  interior cell   interior cell
*
* The table is published together with row totals, sex totals and an all-CVD
* total. If any one interior cell is protected, suppressing only one or two
* neighbouring cells is not sufficient: the remaining margins can be combined
* to reconstruct the protected value indirectly.
*
* The simplest robust rule is therefore panel based:
*
*   If ANY AMI/stroke female/male count in an annual or quarterly panel is
*   primary- or temporal-suppressed, ALL FOUR interior cells in that same
*   panel are suppressed.
*
* This rule is deliberately narrow. It does not suppress:
*   - both-sex AMI or stroke totals;
*   - all-CVD sex totals;
*   - age-specific rows;
*   - monthly rows; or
*   - rows from another year or quarter.
*
* The rule is applied separately to each annual or quarterly count panel.
generate byte __protected_interior = ///
    inlist(statistic, "annual_count", "quarterly_count") & ///
    inlist(event_type, "ami", "stroke") & ///
    inlist(sex, "female", "male") & ///
    suppression_status != "none"

* Identify panels containing at least one protected interior cell.
bysort period_type period_year period_month period_quarter statistic: ///
    egen byte __protected_panel = max(__protected_interior)

* Within a protected panel, mark every other interior cell as complementary.
* The originally protected cell keeps its primary or temporal status.
replace step5_complementary_flag = 1 if suppression_status == "none" & ///
    __protected_panel == 1 & ///
    inlist(statistic, "annual_count", "quarterly_count") & ///
    inlist(event_type, "ami", "stroke") & ///
    inlist(sex, "female", "male")

replace suppression_status = "secondary" if step5_complementary_flag == 1

* DERIVED DISTRIBUTIONS
*
* A percentage is suppressed when one of the counts needed to interpret its
* complete distribution panel is protected. Both percentages in a two-category
* distribution are withheld together; publishing the sibling percentage would
* otherwise reveal the protected percentage because the pair sums to 100.
*
* The checks are deliberately separate for sex, event type and age so that a
* protected AMI-by-sex cell cannot spread into unrelated age distributions.
generate byte __protected_count = ///
    inlist(statistic, "annual_count", "quarterly_count") & ///
    suppression_status != "none"

* Sex distributions use annual female and male counts within one event type.
bysort period_year event_type: egen byte __sex_panel_protected = ///
    max(__protected_count & period_type == "annual" & ///
        inlist(sex, "female", "male") & age_group == "all")
replace step5_derived_flag = 1 if statistic == "sex_distribution" & ///
    __sex_panel_protected == 1

* Event-type distributions use annual AMI and stroke totals for both sexes.
bysort period_year: egen byte __event_panel_protected = ///
    max(__protected_count & period_type == "annual" & sex == "all" & ///
        age_group == "all" & inlist(event_type, "ami", "stroke"))
replace step5_derived_flag = 1 if statistic == "event_type_distribution" & ///
    __event_panel_protected == 1

* Age distributions use the two annual all-CVD age-specific counts.
bysort period_year: egen byte __age_panel_protected = ///
    max(__protected_count & period_type == "annual" & ///
        event_type == "all_cvd" & sex == "all" & age_group != "all")
replace step5_derived_flag = 1 if statistic == "age_distribution" & ///
    __age_panel_protected == 1

* Retain any linked distribution warning supplied directly by Step 4.
replace step5_derived_flag = 1 if step4_related_flag == 1

replace suppression_status = "derived" if ///
    suppression_status == "none" & step5_derived_flag == 1

* STANDARD DISCLOSURE NOTES
* Every row receives a note because the dashboard prints this field directly.
replace disclosure_note = ///
    "Suppressed: underlying count is between 1 and 5." ///
    if suppression_status == "primary"
replace disclosure_note = ///
    "Suppressed: complementary protection prevents calculation of another small count." ///
    if suppression_status == "secondary"
replace disclosure_note = ///
    "Suppressed: increase since the previous public release is between 1 and 5." ///
    if suppression_status == "temporal" & ///
    inrange(temporal_increment, 1, 5)
replace disclosure_note = ///
    "Suppressed: a negative change since the previous public release requires review." ///
    if suppression_status == "temporal" & temporal_increment < 0 & ///
    !missing(temporal_increment)
replace disclosure_note = ///
    "Suppressed: previous release is not approved for temporal disclosure check." ///
    if suppression_status == "temporal" & ///
    temporal_check == "previous_release_unapproved"
replace disclosure_note = ///
    "Suppressed: previous public dataset has an invalid structure for temporal disclosure check." ///
    if suppression_status == "temporal" & ///
    temporal_check == "previous_public_structure_invalid"
replace disclosure_note = ///
    "Suppressed: matching row is absent from the previous public dataset." ///
    if suppression_status == "temporal" & ///
    temporal_check == "previous_public_row_missing"
replace disclosure_note = ///
    "Suppressed: previous private Step 4 dataset is unavailable for temporal disclosure check." ///
    if suppression_status == "temporal" & ///
    temporal_check == "previous_private_missing"
replace disclosure_note = ///
    "Suppressed: previous private Step 4 dataset has an invalid structure for temporal disclosure check." ///
    if suppression_status == "temporal" & ///
    temporal_check == "previous_private_structure_invalid"
replace disclosure_note = ///
    "Suppressed: matching value is absent from the previous private Step 4 dataset." ///
    if suppression_status == "temporal" & ///
    temporal_check == "previous_private_row_missing"
replace disclosure_note = ///
    "Suppressed: this value is derived from one or more suppressed counts." ///
    if suppression_status == "derived" & step5_temporal_flag == 0

* Keep the former variable name as a compatibility alias during handover.
* New publication and dashboard code should use disclosure_note.
generate str244 suppression_note = disclosure_note

* ---------------------------------------------------------------------------
* 4. CREATE THE PUBLIC DISPLAY FIELD
*
* display_value is the safe presentation field for tables and dashboards.
* Exact values remain visible only for unsuppressed rows.
* ---------------------------------------------------------------------------
generate str24 display_value = ""
replace display_value = strtrim(string(value, "%18.8g")) ///
    if suppression_status == "none" & !missing(value)
replace display_value = "*" if suppression_status != "none"

quietly count if suppression_status == "primary"
local primary_rows = r(N)
quietly count if suppression_status == "secondary"
local secondary_rows = r(N)
quietly count if suppression_status == "temporal"
local temporal_rows = r(N)
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

* ---------------------------------------------------------------------------
* 5. REMOVE EXACT NUMERIC CONTENT FROM SUPPRESSED ROWS
*
* Blanking value alone is insufficient: numerator or denominator could reveal
* the same protected count. All three numeric fields are therefore removed.
* ---------------------------------------------------------------------------
replace value = .       if suppression_status != "none"
replace numerator = .   if suppression_status != "none"
replace denominator = . if suppression_status != "none"

* Internal Step 4 review fields must not travel into the public candidate.
* Their purpose has been converted into suppression_status and suppression_note.
drop primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

* Keep the internal helper variables until disclosure QA has finished.
* Several QA checks use them to confirm that complementary and derived
* suppression were applied to the intended panels. They are removed only
* after all checks have passed, immediately before the candidate is saved.

order metric_id release_id period_type period period_start period_year ///
    period_month period_quarter period_complete event_type sex age_group ///
    source_status statistic value display_value unit numerator denominator ///
    comparison_n status_flag sdc_policy step4_primary_flag step4_related_flag ///
    previous_release_id previous_release_found previous_value ///
    temporal_increment temporal_check step5_temporal_flag ///
    step5_complementary_flag step5_derived_flag suppression_status ///
    disclosure_note suppression_note

sort metric_id period_type period_year period_month event_type sex age_group statistic

label data "BNR CVD burden metrics - Step 5 review candidate"
label variable display_value "Public display value; * means suppressed"
label variable suppression_status ///
    "Public suppression status: none, primary, secondary, temporal or derived"
label variable disclosure_note "Disclosure Note"
label variable suppression_note "Compatibility copy of Disclosure Note"
label variable step4_primary_flag "Step 4 primary disclosure flag"
label variable step4_related_flag "Step 4 linked disclosure flag"
label variable previous_release_id "Previous release used for temporal check"
label variable previous_release_found "Previous approved release found"
label variable previous_value "Previous private cumulative value"
label variable temporal_increment "Increment since previous approved release"
label variable temporal_check "Temporal disclosure check result"
label variable step5_temporal_flag "Step 5 temporal disclosure flag"
label variable step5_complementary_flag "Step 5 complementary disclosure flag"
label variable step5_derived_flag "Step 5 derived-value disclosure flag"

notes _dta: package_status: review_candidate
notes _dta: disclosure_policy: bnr_sdc_v1
notes _dta: suppressed_rows_retain_categories: true
notes _dta: suppressed_exact_numeric_fields_removed: true
notes _dta: observable_contract: use suppression_status; do not infer suppression from missing value
notes _dta: disclosure_note_contract: every row contains a plain-language disclosure note
notes _dta: age_scope: age-specific rows are annual all-CVD only

* ---------------------------------------------------------------------------
* 6. DISCLOSURE QA
*
* Each check protects one specific part of the public contract. The QA dataset
* is retained for the human review workbook and checked again during approval.
* A single FAIL stops Step 5.
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
    "none", "primary", "secondary", "temporal", "derived")
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Suppression status contract") ("`result'") ///
    ("Only the five documented public statuses are present")

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

quietly count if __protected_interior == 1 & step5_complementary_flag == 1
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Complementary suppression separation") ("`result'") ///
    ("Primary or temporal cells are distinct from their complementary cells")

quietly count if __protected_panel == 1 & ///
    inlist(statistic, "annual_count", "quarterly_count") & ///
    inlist(event_type, "ami", "stroke") & ///
    inlist(sex, "female", "male") & suppression_status == "none"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Protected panels fully suppressed") ("`result'") ///
    ("All four AMI/stroke sex-specific cells are suppressed in every protected panel")

quietly count if step5_temporal_flag == 1 & suppression_status == "none"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Temporal differencing protection") ("`result'") ///
    ("Every incomplete disease-specific annual or quarterly count at temporal risk is suppressed")

quietly count if missing(disclosure_note) | strtrim(disclosure_note) == ""
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Disclosure note populated") ("`result'") ///
    ("Every row contains a plain-language disclosure note for dashboard display")

quietly count if statistic == "age_distribution" & ///
    !(period_type == "annual" & event_type == "all_cvd" & sex == "all" & ///
      inlist(age_group, "under_70", "age_70_plus"))
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Age distribution contract") ("`result'") ///
    ("Age-distribution rows are annual, all-CVD, both-sex rows only")

quietly count if age_group != "all" & ///
    !(period_type == "annual" & event_type == "all_cvd" & sex == "all" & ///
      inlist(statistic, "annual_count", "annual_previous_5yr_mean", ///
        "age_distribution"))
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Age-specific row scope") ("`result'") ///
    ("Age-specific rows occur only in the approved annual all-CVD statistics")

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

* The QA checks above have now finished using these internal helper variables.
* Remove them before the review candidate is saved so that they do not enter
* the handover dataset or any later publication output.
drop __protected_interior __protected_panel ///
    __temporal_candidate __period_start __protected_count ///
    __sex_panel_protected __event_panel_protected __age_panel_protected

* ---------------------------------------------------------------------------
* 7. SAVE THE REVIEW CANDIDATE ONLY AFTER ALL QA CHECKS PASS
* ---------------------------------------------------------------------------

save `"`public_dta'"', replace

display as result "Disclosure-controlled review candidate created."
display as result "  Primary rows:   `primary_rows'"
display as result "  Secondary rows: `secondary_rows'"
display as result "  Derived rows:   `derived_rows'"
display as result "  Total suppressed: `suppressed_rows'"

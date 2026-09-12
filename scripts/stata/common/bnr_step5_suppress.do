/*******************************************************************************
DO-FILE:     bnr_step5_suppress.do
VERSION:     2.5.5 (24 August 2026)
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
             6. creates disclosure QA, equation and private row-level audits;
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
             disclosure_equation_audit_dta
             disclosure_row_audit_dta
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
* 1. RECEIVE AND CHECK THE STEP 5 CONTROLLER CONTRACT
* ---------------------------------------------------------------------------
args private_dta public_dta disclosure_qa_dta disclosure_equation_audit_dta ///
    disclosure_row_audit_dta release_id ///
    previous_public_dta previous_private_dta previous_release_id

if `"`private_dta'"' == "" | `"`public_dta'"' == "" | ///
        `"`disclosure_qa_dta'"' == "" | ///
        `"`disclosure_equation_audit_dta'"' == "" | ///
        `"`disclosure_row_audit_dta'"' == "" | ///
        `"`release_id'"' == "" | ///
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

* This private-only row identifier is created before any disclosure sorting.
* It lets the reviewer workbook rejoin private values to their disclosure
* provenance without relying on structural time fields that are correctly
* blank for annual or quarterly rows.
generate long __private_row_id = _n
isid __private_row_id

* ---------------------------------------------------------------------------
* 2. CHECK THE PRIVATE STEP 4 METRIC DATASET
*
* These variables form the minimum interface between Step 4 and Step 5.
* Keeping the list here makes the hand-off contract visible in one place.
* ---------------------------------------------------------------------------
local required_variables schema_version metric_id release_id period_type period ///
    period_start period_year period_month period_quarter period_complete ///
    event_type sex age_group source_status ascertainment_scope ///
    mortality_definition estimate_basis statistic value unit numerator denominator ///
    linkage_lower_value linkage_upper_value ///
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

quietly count if schema_version != "bnr_cvd_public_metric_v2"
if r(N) {
    display as error "Step 5 requires the approved CVD public metric schema v2."
    exit 459
}

quietly count if ascertainment_scope != "hospital_only" | ///
    mortality_definition != "not_applicable" | estimate_basis != "observed"
if r(N) {
    display as error "Stage 2 accepts hospital-only observed CVD metrics only."
    exit 459
}

quietly count if !missing(linkage_lower_value) | !missing(linkage_upper_value)
if r(N) {
    display as error "Hospital-only Stage 2 rows must not contain linkage bounds."
    exit 459
}

quietly count if period_type == "monthly" & ///
    !(metric_id == "CVD-BURDEN-001" & statistic == "monthly_count" & ///
      event_type == "all_cvd" & sex == "all" & age_group == "all")
if r(N) {
    display as error "A monthly row falls outside the approved public lattice."
    exit 459
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
* Only incomplete Heart and Stroke cumulative count rows are assessed here.
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
            * Stage 2 renamed the legacy AMI grouping to Heart.  The
            * historical public payload remains valid, so bridge that label
            * only while matching the previous-release temporal lattice.
            replace event_type = "heart" if lower(strtrim(event_type)) == "ami"
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
            * Apply the identical bridge to the private Step 4 counterpart so
            * public approval evidence and its protected prior value use the
            * same historical event-type key.
            replace event_type = "heart" if lower(strtrim(event_type)) == "ami"
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
* Annual and quarterly Heart/Stroke counts form a two-by-two event-by-sex table:
*
*                      Female          Male
*                   -------------------------
*           Heart   |  interior cell   interior cell
*          Stroke   |  interior cell   interior cell
*
* The table is published together with row totals, sex totals and an all-CVD
* total. If any one interior cell is protected, suppressing only one or two
* neighbouring cells is not sufficient: the remaining margins can be combined
* to reconstruct the protected value indirectly.
*
* The simplest robust rule is therefore panel based:
*
*   If ANY Heart/Stroke female/male count in an annual or quarterly panel is
*   primary- or temporal-suppressed, ALL FOUR interior cells in that same
*   panel are suppressed.
*
* This rule is deliberately narrow. It does not suppress:
*   - both-sex Heart or Stroke totals;
*   - all-CVD sex totals;
*   - age-specific rows;
*   - monthly rows; or
*   - rows from another year or quarter.
*
* The rule is applied separately to each annual or quarterly count panel.
generate byte __protected_interior = ///
    inlist(statistic, "annual_count", "quarterly_count") & ///
    inlist(event_type, "heart", "stroke") & ///
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
    inlist(event_type, "heart", "stroke") & ///
    inlist(sex, "female", "male")

replace suppression_status = "secondary" if step5_complementary_flag == 1

* ITERATIVE CROSS-FREQUENCY EQUATION CLOSURE
*
* The public CVD lattice now contains monthly all-CVD combined-sex counts,
* quarterly all-CVD combined-sex counts and annual all-CVD combined-sex counts.
* A single protected component in any additive equation would reveal that
* component by subtraction.  The loop below deterministically chooses the
* earliest available component as complementary protection and repeats until
* the three applicable time equations are closed:
*
*   quarterly count = its three monthly counts
*   annual count = its four quarterly counts
*   annual count = its twelve monthly counts
*
* Heart/Stroke and sex equations are deliberately not asserted here.  The
* approved contract does not declare all-CVD to be a simple Heart + Stroke sum,
* and sex-specific rows are not published at monthly resolution.
generate byte __time_complementary_flag = 0
generate str32 __equation_id = ""
generate str120 __equation_description = ""
generate double __equation_source_period = .
generate double __time_period_code = period_year * 100 + ///
    cond(period_type == "monthly", period_month, ///
    cond(period_type == "quarterly", 50 + period_quarter, 99))

forvalues closure_iteration = 1/20 {
    local closure_changed 0

    * Quarterly all-CVD total and its three months.
    generate byte __mq_member = event_type == "all_cvd" & sex == "all" & ///
        age_group == "all" & ///
        ((period_type == "monthly" & statistic == "monthly_count") | ///
         (period_type == "quarterly" & statistic == "quarterly_count"))
    bysort period_year period_quarter: egen byte __mq_member_n = total(__mq_member)
    bysort period_year period_quarter: egen byte __mq_protected_n = ///
        total(__mq_member & suppression_status != "none")
    bysort period_year period_quarter: egen double __mq_source_period = ///
        max(cond(__mq_member & suppression_status != "none", __time_period_code, .))
    generate byte __mq_candidate = __mq_member == 1 & __mq_member_n == 4 & ///
        __mq_protected_n == 1 & suppression_status == "none" & ///
        period_type == "monthly" & statistic == "monthly_count"
    sort period_year period_quarter period
    by period_year period_quarter: generate byte __mq_choice = ///
        __mq_candidate == 1 & sum(__mq_candidate) == 1
    quietly count if __mq_choice == 1
    if r(N) {
        replace step5_complementary_flag = 1 if __mq_choice == 1
        replace __time_complementary_flag = 1 if __mq_choice == 1
        replace __equation_id = "MQ-" + string(period_year, "%04.0f") + ///
            "-Q" + string(period_quarter, "%01.0f") if __mq_choice == 1
        replace __equation_description = ///
            "Quarterly all-CVD count equals its three monthly counts." ///
            if __mq_choice == 1
        replace __equation_source_period = __mq_source_period if __mq_choice == 1
        replace suppression_status = "secondary" if __mq_choice == 1
        local closure_changed 1
    }
    drop __mq_member __mq_member_n __mq_protected_n __mq_source_period ///
        __mq_candidate __mq_choice

    * Annual all-CVD total and its four quarters.
    generate byte __qa_member = event_type == "all_cvd" & sex == "all" & ///
        age_group == "all" & ///
        ((period_type == "quarterly" & statistic == "quarterly_count") | ///
         (period_type == "annual" & statistic == "annual_count"))
    bysort period_year: egen byte __qa_member_n = total(__qa_member)
    bysort period_year: egen byte __qa_protected_n = ///
        total(__qa_member & suppression_status != "none")
    bysort period_year: egen double __qa_source_period = ///
        max(cond(__qa_member & suppression_status != "none", __time_period_code, .))
    generate byte __qa_candidate = __qa_member == 1 & __qa_member_n == 5 & ///
        __qa_protected_n == 1 & suppression_status == "none" & ///
        period_type == "quarterly" & statistic == "quarterly_count"
    sort period_year period_quarter period
    by period_year: generate byte __qa_choice = ///
        __qa_candidate == 1 & sum(__qa_candidate) == 1
    quietly count if __qa_choice == 1
    if r(N) {
        replace step5_complementary_flag = 1 if __qa_choice == 1
        replace __time_complementary_flag = 1 if __qa_choice == 1
        replace __equation_id = "QA-" + string(period_year, "%04.0f") if __qa_choice == 1
        replace __equation_description = ///
            "Annual all-CVD count equals its four quarterly counts." ///
            if __qa_choice == 1
        replace __equation_source_period = __qa_source_period if __qa_choice == 1
        replace suppression_status = "secondary" if __qa_choice == 1
        local closure_changed 1
    }
    drop __qa_member __qa_member_n __qa_protected_n __qa_source_period ///
        __qa_candidate __qa_choice

    * Annual all-CVD total and its twelve months.
    generate byte __ma_member = event_type == "all_cvd" & sex == "all" & ///
        age_group == "all" & ///
        ((period_type == "monthly" & statistic == "monthly_count") | ///
         (period_type == "annual" & statistic == "annual_count"))
    bysort period_year: egen byte __ma_member_n = total(__ma_member)
    bysort period_year: egen byte __ma_protected_n = ///
        total(__ma_member & suppression_status != "none")
    bysort period_year: egen double __ma_source_period = ///
        max(cond(__ma_member & suppression_status != "none", __time_period_code, .))
    generate byte __ma_candidate = __ma_member == 1 & __ma_member_n == 13 & ///
        __ma_protected_n == 1 & suppression_status == "none" & ///
        period_type == "monthly" & statistic == "monthly_count"
    sort period_year period_month period
    by period_year: generate byte __ma_choice = ///
        __ma_candidate == 1 & sum(__ma_candidate) == 1
    quietly count if __ma_choice == 1
    if r(N) {
        replace step5_complementary_flag = 1 if __ma_choice == 1
        replace __time_complementary_flag = 1 if __ma_choice == 1
        replace __equation_id = "MA-" + string(period_year, "%04.0f") if __ma_choice == 1
        replace __equation_description = ///
            "Annual all-CVD count equals its twelve monthly counts." ///
            if __ma_choice == 1
        replace __equation_source_period = __ma_source_period if __ma_choice == 1
        replace suppression_status = "secondary" if __ma_choice == 1
        local closure_changed 1
    }
    drop __ma_member __ma_member_n __ma_protected_n __ma_source_period ///
        __ma_candidate __ma_choice

    if `closure_changed' == 0 {
        continue, break
    }
}

* A rolling five-year mean remains public only when every contributing count is
* public.  This conservative rule closes direct and overlapping-comparator
* subtraction routes without attempting to reconstruct them one at a time.
tempfile comparator_risk
preserve
    keep if suppression_status != "none" & ///
        inlist(statistic, "annual_count", "quarterly_count")
    keep metric_id period_type period_year period_quarter event_type sex ///
        age_group statistic period_month
    quietly count
    if r(N) {
        generate double __comparator_source_period = period_year * 100 + ///
            cond(period_type == "quarterly", 50 + period_quarter, 99)
        generate long __source_row = _n
        expand 5
        bysort __source_row: generate byte __comparator_offset = _n
        replace period_year = period_year + __comparator_offset
        replace statistic = "annual_previous_5yr_mean" if statistic == "annual_count"
        replace statistic = "quarterly_same_quarter_previous_5yr_mean" ///
            if statistic == "quarterly_count"
        duplicates drop metric_id period_type period_year period_quarter ///
            event_type sex age_group statistic, force
    }
    else {
        * An empty risk set is valid: create the merge field without asking
        * Stata to generate an observation-level offset in a zero-row dataset.
        generate double __comparator_source_period = .
    }
    save `"`comparator_risk'"', replace
restore

merge m:1 metric_id period_type period_year period_quarter event_type sex ///
    age_group statistic using `"`comparator_risk'"', keep(master match) nogen
generate byte __comparator_derived_flag = !missing(__comparator_source_period) & ///
    suppression_status == "none" & ///
    inlist(statistic, "annual_previous_5yr_mean", ///
    "quarterly_same_quarter_previous_5yr_mean")
replace step5_derived_flag = 1 if __comparator_derived_flag == 1
replace __equation_id = "ROLLING-" + string(period_year, "%04.0f") if ///
    __comparator_derived_flag == 1
replace __equation_description = ///
    "Rolling five-year comparator includes a protected count." if ///
    __comparator_derived_flag == 1
replace __equation_source_period = __comparator_source_period if ///
    __comparator_derived_flag == 1
replace suppression_status = "derived" if __comparator_derived_flag == 1

* DERIVED DISTRIBUTIONS
*
* A percentage is suppressed when one of the counts needed to interpret its
* complete distribution panel is protected. Both percentages in a two-category
* distribution are withheld together; publishing the sibling percentage would
* otherwise reveal the protected percentage because the pair sums to 100.
*
* The checks are deliberately separate for sex, event type and age so that a
* protected Heart-by-sex cell cannot spread into unrelated age distributions.
generate byte __protected_count = ///
    inlist(statistic, "annual_count", "quarterly_count") & ///
    suppression_status != "none"

* Sex distributions use annual female and male counts within one event type.
bysort period_year event_type: egen byte __sex_panel_protected = ///
    max(__protected_count & period_type == "annual" & ///
        inlist(sex, "female", "male") & age_group == "all")
replace step5_derived_flag = 1 if statistic == "sex_distribution" & ///
    __sex_panel_protected == 1

* Event-type distributions use annual Heart and Stroke totals for both sexes.
bysort period_year: egen byte __event_panel_protected = ///
    max(__protected_count & period_type == "annual" & sex == "all" & ///
        age_group == "all" & inlist(event_type, "heart", "stroke"))
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
replace linkage_lower_value = . if suppression_status != "none"
replace linkage_upper_value = . if suppression_status != "none"

* Internal Step 4 review fields must not travel into the public candidate.
* Their purpose has been converted into suppression_status and suppression_note.
drop primary_suppression_threshold primary_suppression ///
    related_primary_cells related_suppression_review suppression_review ///
    suppression_reason

* Keep the internal helper variables until disclosure QA has finished.
* Several QA checks use them to confirm that complementary and derived
* suppression were applied to the intended panels. They are removed only
* after all checks have passed, immediately before the candidate is saved.

order schema_version metric_id release_id period_type period period_start period_year ///
    period_month period_quarter period_complete event_type sex age_group ///
    source_status ascertainment_scope mortality_definition estimate_basis ///
    statistic value display_value unit numerator denominator ///
    linkage_lower_value linkage_upper_value ///
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

* The audit contains only disclosure structure, not exact values.  It records
* each equation that required a deterministic complementary or comparator
* decision so a reviewer can trace the protection route without recreating it.
preserve
    keep if __equation_id != ""
    keep __equation_id __equation_description __equation_source_period ///
        metric_id release_id period_type period period_year period_month ///
        period_quarter event_type sex age_group statistic suppression_status
    rename __equation_id equation_id
    rename __equation_description equation_description
    rename __equation_source_period protected_source_period
    rename period complementary_period
    rename statistic complementary_statistic
    rename suppression_status final_public_status
    order equation_id equation_description protected_source_period ///
        metric_id release_id period_type complementary_period period_year ///
        period_month period_quarter event_type sex age_group ///
        complementary_statistic final_public_status
    sort equation_id complementary_period complementary_statistic
    save `"`disclosure_equation_audit_dta'"', replace
restore

* Keep a complete, private row-level audit separate from the public candidate.
* It contains disclosure provenance but no current exact metric values; the
* review controller joins it to the private Step 4 dataset by a stable private
* row identifier when building the reviewer workbook.
preserve
    keep __private_row_id metric_id release_id period_type period period_start period_year ///
        period_month period_quarter period_complete event_type ///
        sex age_group statistic step4_primary_flag step4_related_flag ///
        previous_release_id previous_release_found previous_value ///
        temporal_increment temporal_check step5_temporal_flag ///
        step5_complementary_flag step5_derived_flag suppression_status ///
        disclosure_note suppression_note
    isid __private_row_id
    sort __private_row_id
    save `"`disclosure_row_audit_dta'"', replace
restore

notes _dta: package_status: review_candidate
notes _dta: disclosure_policy: bnr_sdc_v1
notes _dta: suppressed_rows_retain_categories: true
notes _dta: suppressed_exact_numeric_fields_removed: true
notes _dta: observable_contract: use suppression_status; do not infer suppression from missing value
notes _dta: disclosure_note_contract: every row contains a plain-language disclosure note
notes _dta: age_scope: age-specific rows are annual all-CVD only

* Recheck the final candidate before writing QA.  Each populated equation must
* have either no protected term or at least two; exactly one is reconstructable.
generate byte __mq_member = event_type == "all_cvd" & sex == "all" & ///
    age_group == "all" & ///
    ((period_type == "monthly" & statistic == "monthly_count") | ///
     (period_type == "quarterly" & statistic == "quarterly_count"))
bysort period_year period_quarter: egen byte __mq_member_n = total(__mq_member)
bysort period_year period_quarter: egen byte __mq_protected_n = ///
    total(__mq_member & suppression_status != "none")
quietly count if __mq_member_n == 4 & __mq_protected_n == 1
local open_monthly_quarter_equations = r(N)

generate byte __qa_member = event_type == "all_cvd" & sex == "all" & ///
    age_group == "all" & ///
    ((period_type == "quarterly" & statistic == "quarterly_count") | ///
     (period_type == "annual" & statistic == "annual_count"))
bysort period_year: egen byte __qa_member_n = total(__qa_member)
bysort period_year: egen byte __qa_protected_n = ///
    total(__qa_member & suppression_status != "none")
quietly count if __qa_member_n == 5 & __qa_protected_n == 1
local open_quarterly_annual_equations = r(N)

generate byte __ma_member = event_type == "all_cvd" & sex == "all" & ///
    age_group == "all" & ///
    ((period_type == "monthly" & statistic == "monthly_count") | ///
     (period_type == "annual" & statistic == "annual_count"))
bysort period_year: egen byte __ma_member_n = total(__ma_member)
bysort period_year: egen byte __ma_protected_n = ///
    total(__ma_member & suppression_status != "none")
quietly count if __ma_member_n == 13 & __ma_protected_n == 1
local open_monthly_annual_equations = r(N)

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

local open_time_equations = `open_monthly_quarter_equations' + ///
    `open_quarterly_annual_equations' + `open_monthly_annual_equations'
local result = cond(`open_time_equations' == 0, "PASS", "FAIL")
post `qa_handle' ("Cross-frequency equation closure") ("`result'") ///
    ("No monthly-quarterly or annual equation has exactly one protected term")

quietly count if suppression_status != "none" & ///
    (!missing(value) | !missing(numerator) | !missing(denominator) | ///
    !missing(linkage_lower_value) | !missing(linkage_upper_value))
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Suppressed numeric fields blank") ("`result'") ///
    ("No suppressed row retains values, components or linkage bounds")

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
    inlist(event_type, "heart", "stroke") & ///
    inlist(sex, "female", "male") & suppression_status == "none"
local result = cond(r(N) == 0, "PASS", "FAIL")
post `qa_handle' ("Protected panels fully suppressed") ("`result'") ///
    ("All four Heart/Stroke sex-specific cells are suppressed in every protected panel")

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
post `qa_handle' ("Step 4 input fields removed") ("`result'") ///
    ("Raw Step 4 suppression inputs are absent before the public projection is saved")

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
capture drop __source_row __comparator_offset
drop __protected_interior __protected_panel ///
    __private_row_id __temporal_candidate __period_start __protected_count ///
    __sex_panel_protected __event_panel_protected __age_panel_protected ///
    __time_complementary_flag __equation_id __equation_description ///
    __equation_source_period __time_period_code __comparator_source_period ///
    __comparator_derived_flag ///
    __mq_member __mq_member_n __mq_protected_n ///
    __qa_member __qa_member_n __qa_protected_n ///
    __ma_member __ma_member_n __ma_protected_n

* Public candidate projection: the row-level disclosure provenance belongs in
* step5_row_audit.dta, never in a review candidate or public-ready payload.
drop step4_primary_flag step4_related_flag ///
    previous_release_id previous_release_found previous_value ///
    temporal_increment temporal_check step5_temporal_flag ///
    step5_complementary_flag step5_derived_flag

local nonpublic_candidate_fields step4_primary_flag step4_related_flag ///
    previous_release_id previous_release_found previous_value ///
    temporal_increment temporal_check step5_temporal_flag ///
    step5_complementary_flag step5_derived_flag __source_row ///
    __comparator_offset __private_row_id
foreach variable of local nonpublic_candidate_fields {
    capture confirm variable `variable'
    if !_rc {
        display as error "Internal disclosure field remains in public candidate: `variable'"
        exit 459
    }
}

preserve
    use `"`disclosure_qa_dta'"', clear
    local qa_rows = _N + 1
    set obs `qa_rows'
    replace check = "Public-candidate projection" in L
    replace result = "PASS" in L
    replace detail = ///
        "Internal disclosure provenance is retained only in the private row audit." in L
    save `"`disclosure_qa_dta'"', replace
restore

* ---------------------------------------------------------------------------
* 7. SAVE THE REVIEW CANDIDATE ONLY AFTER ALL QA CHECKS PASS
* ---------------------------------------------------------------------------

save `"`public_dta'"', replace

display as result "Disclosure-controlled review candidate created."
display as result "  Primary rows:   `primary_rows'"
display as result "  Secondary rows: `secondary_rows'"
display as result "  Derived rows:   `derived_rows'"
display as result "  Total suppressed: `suppressed_rows'"

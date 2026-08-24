/*******************************************************************************
DO-FILE:     bnr_step5_cvd_monthly_reference.do
VERSION:     1.0.2 (24 August 2026)
PROJECT:     BNR Refit Phase 2
WORKFLOW:    CVD hardening Stage 2 - fixed monthly seasonal reference

PURPOSE:     Prepare the checksum-bound 2015-2019 monthly CVD reference asset.

             On the first hardened release, this helper creates the asset from
             the approved Step 4 hospital-only dataset.  On later releases it
             copies the already-published asset into the private review package.
             It never recalculates an asset once a public version exists.

OUTPUT:      review DTA, CSV and YAML files.  The Step 5 controller fingerprints
             them, obtains human approval, and includes them in the manifest.
*******************************************************************************/

version 19
set more off

args private_dta review_dta review_csv review_yml ///
    public_dta public_csv public_yml

if `"`private_dta'"' == "" | `"`review_dta'"' == "" | ///
        `"`review_csv'"' == "" | `"`review_yml'"' == "" | ///
        `"`public_dta'"' == "" | `"`public_csv'"' == "" | ///
        `"`public_yml'"' == "" {
    noisily display as error "Monthly reference helper received an incomplete contract."
    exit 198
}

capture confirm file `"`private_dta'"'
if _rc {
    noisily display as error "Step 4 private CVD dataset not found: `private_dta'"
    exit 601
}

capture confirm file `"`public_dta'"'
local public_dta_exists = (_rc == 0)
capture confirm file `"`public_csv'"'
local public_csv_exists = (_rc == 0)
capture confirm file `"`public_yml'"'
local public_yml_exists = (_rc == 0)

local public_asset_files = `public_dta_exists' + `public_csv_exists' + ///
    `public_yml_exists'
if `public_asset_files' > 0 & `public_asset_files' < 3 {
    noisily display as error "The published CVD monthly reference asset is incomplete."
    noisily display as error "Expected all three files or none of them:"
    noisily display as error "  DTA: `public_dta_exists' (`public_dta')"
    noisily display as error "  CSV: `public_csv_exists' (`public_csv')"
    noisily display as error "  YAML: `public_yml_exists' (`public_yml')"
    exit 459
}

if `public_asset_files' == 3 {
    * A public asset is authoritative.  Routine releases copy and review it;
    * they must not silently regenerate historical reference values.
    copy `"`public_dta'"' `"`review_dta'"', replace
    copy `"`public_csv'"' `"`review_csv'"', replace
    copy `"`public_yml'"' `"`review_yml'"', replace
    local reference_source "approved_public_asset"
}
else {
    use `"`private_dta'"', clear
    keep if schema_version == "bnr_cvd_public_metric_v2" & ///
        metric_id == "CVD-BURDEN-001" & ///
        ascertainment_scope == "hospital_only" & ///
        mortality_definition == "not_applicable" & ///
        estimate_basis == "observed" & ///
        period_type == "monthly" & statistic == "monthly_count" & ///
        event_type == "all_cvd" & sex == "all" & age_group == "all" & ///
        inrange(period_year, 2015, 2019) & period_complete == 1 & ///
        status_flag == "final"

    quietly count
    if r(N) != 60 {
        local reference_source_rows = r(N)
        noisily display as error ///
            "The initial monthly reference requires exactly 60 source rows; found `reference_source_rows'."
        exit 459
    }
    isid period_year period_month
    bysort period_month: assert _N == 5

    collapse (min) reference_min = value (mean) reference_mean = value ///
        (max) reference_max = value, by(period_month)
    sort period_month
    assert _N == 12
    assert !missing(reference_min, reference_mean, reference_max)

    generate str28 schema_version = "bnr_cvd_monthly_reference_v1"
    generate str20 ascertainment_scope = "hospital_only"
    generate str20 event_type = "all_cvd"
    generate str8 sex = "all"
    generate str12 age_group = "all"
    generate int reference_start_year = 2015
    generate int reference_end_year = 2019
    generate str32 method = "calendar_month_min_mean_max"
    generate str24 reference_status = "first_hardened_release"
    order schema_version ascertainment_scope event_type sex age_group ///
        period_month reference_start_year reference_end_year ///
        reference_min reference_mean reference_max method reference_status

    save `"`review_dta'"', replace
    export delimited using `"`review_csv'"', replace

    tempname reference_meta
    file open `reference_meta' using `"`review_yml'"', write text replace
    file write `reference_meta' "schema: bnr_cvd_monthly_reference_v1" _n
    file write `reference_meta' "reference_period: 2015-2019" _n
    file write `reference_meta' "ascertainment_scope: hospital_only" _n
    file write `reference_meta' "event_type: all_cvd" _n
    file write `reference_meta' "sex: all" _n
    file write `reference_meta' "age_group: all" _n
    file write `reference_meta' "method: calendar_month_min_mean_max" _n
    file write `reference_meta' "routine_rule: checksum_verify_do_not_recalculate" _n
    file write `reference_meta' "reference_status: first_hardened_release" _n
    file close `reference_meta'
    local reference_source "first_hardened_release_calculation"
}

use `"`review_dta'"', clear
local required reference_min reference_mean reference_max period_month ///
    schema_version ascertainment_scope event_type sex age_group ///
    reference_start_year reference_end_year method
foreach variable of local required {
    capture confirm variable `variable'
    if _rc {
        noisily display as error ///
            "Monthly reference asset is missing required variable: `variable'"
        exit 111
    }
}
assert _N == 12
isid period_month
assert inrange(period_month, 1, 12)
assert schema_version == "bnr_cvd_monthly_reference_v1"
assert ascertainment_scope == "hospital_only"
assert event_type == "all_cvd"
assert sex == "all"
assert age_group == "all"
assert reference_start_year == 2015 & reference_end_year == 2019
assert !missing(reference_min, reference_mean, reference_max)
assert reference_min <= reference_mean & reference_mean <= reference_max

* The controller determines the reference source from the three authoritative
* public asset paths before calling this helper.  A plain do-file is not an
* rclass program, so it must not use return local here.

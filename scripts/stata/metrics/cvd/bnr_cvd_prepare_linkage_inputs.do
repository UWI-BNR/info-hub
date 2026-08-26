/*******************************************************************************

DO-FILE:     bnr_cvd_prepare_linkage_inputs.do

VERSION:     1.0.0 (24 August 2026)

PURPOSE:     Stage 3 private input assembly for the CVD mortality-linkage work.

              This file performs no person matching, episode classification,
              DCO estimation, metric calculation, approval or publication.
              It creates two minimum-necessary private input datasets:

              1. Inclusive CVD mortality candidates, with their Step 2
                 Primary/Inclusive classifications and Step 1 identifiers.
              2. Hospital-recorded CVD event candidates, excluding legacy
                 imported DCO records.

              The outputs are private linkage inputs for the later matching
              Stage. They must never be copied into metric staging, review,
              public-ready or website folders.

USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_prepare_linkage_inputs.do" ///
                 2024 04 2026 07

              Add replace only to replace an existing private Stage 3 package:

              do "$BNR_STATA/metrics/cvd/bnr_cvd_prepare_linkage_inputs.do" ///
                 2024 04 2026 07 replace

*******************************************************************************/

version 19

clear all

set more off

args cvd_year cvd_month mortality_year mortality_month option

if `"`cvd_year'"' == "" | `"`cvd_month'"' == "" | ///
        `"`mortality_year'"' == "" | `"`mortality_month'"' == "" {
    display as error "CVD year/month and mortality year/month are required."
    exit 198
}

if `"`option'"' != "" & lower(`"`option'"') != "replace" {
    display as error "The only optional argument is replace."
    exit 198
}

local replace_existing = (lower(`"`option'"') == "replace")

local cvd_year_num = real("`cvd_year'")
local cvd_month_num = real("`cvd_month'")
local mortality_year_num = real("`mortality_year'")
local mortality_month_num = real("`mortality_month'")

foreach numeric_argument in cvd_year_num cvd_month_num mortality_year_num mortality_month_num {
    if missing(``numeric_argument'') | ``numeric_argument'' != floor(``numeric_argument'') {
        display as error "Release arguments must be whole numbers."
        exit 198
    }
}

if !inrange(`cvd_month_num', 1, 12) | !inrange(`mortality_month_num', 1, 12) {
    display as error "Release months must be from 1 to 12."
    exit 198
}

if `cvd_year_num' < 2024 | `mortality_year_num' < 2024 {
    display as error "This Stage 3 implementation expects releases from 2024 onward."
    exit 198
}

if `"$BNR_PRIVATE"' == "" | `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

foreach required_global in BNR_PRIVATE BNR_STATA BNR_PRIVATE_LOGS {
    if `"$`required_global'"' == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

local cvd_year4 : display %04.0f `cvd_year_num'
local cvd_month2 : display %02.0f `cvd_month_num'
local mortality_year4 : display %04.0f `mortality_year_num'
local mortality_month2 : display %02.0f `mortality_month_num'

local cvd_release "cvd_`cvd_year4'_`cvd_month2'"
local mortality_release "mort_`mortality_year4'_`mortality_month2'"
local linkage_release "`cvd_release'_`mortality_release'"

* The CVD source is cumulative through the end of its selected calendar month.
* Mortality records after that date cannot be interpreted as missed CVD events.
local event_coverage_end = dofm(ym(`cvd_year_num', `cvd_month_num') + 1) - 1
local event_coverage_end_iso : display %tdCCYY-NN-DD `event_coverage_end'

local mortality_raw ///
    "$BNR_PRIVATE/data/raw/redcap/mortality/y`mortality_year4'/m`mortality_month2'/bnr_mort_s1_`mortality_year4'`mortality_month2'.dta"
local mortality_classified ///
    "$BNR_PRIVATE/data/derived/mortality/y`mortality_year4'/m`mortality_month2'/bnr_mort_s2_`mortality_year4'`mortality_month2'.dta"
local cvd_confidential ///
    "$BNR_PRIVATE/data/derived/cvd/y`cvd_year4'/m`cvd_month2'/bnr_cvd_confidential_`cvd_year4'`cvd_month2'_v01.dta"

local output_root "$BNR_PRIVATE/data/derived/cvd_linkage"
local output_year "`output_root'/y`cvd_year4'"
local output_month "`output_year'/m`cvd_month2'"
local output_dir "`output_month'/mort_y`mortality_year4'_m`mortality_month2'"

local deaths_output ///
    "`output_dir'/bnr_cvd_linkage_deaths_`linkage_release'.dta"
local events_output ///
    "`output_dir'/bnr_cvd_linkage_events_`linkage_release'.dta"
local qa_output ///
    "`output_dir'/bnr_cvd_linkage_input_qa_`linkage_release'.csv"
local metadata_output ///
    "`output_dir'/bnr_cvd_linkage_input_metadata_`linkage_release'.yml"
local output_log ///
    "$BNR_PRIVATE_LOGS/bnr_cvd_linkage_inputs_`cvd_year4'`cvd_month2'_mort_`mortality_year4'`mortality_month2'.log"

foreach required_file in mortality_raw mortality_classified cvd_confidential {
    capture confirm file ``required_file''
    if _rc {
        display as error "Required private source file was not found: ``required_file''"
        exit 601
    }
}

foreach output_file in deaths_output events_output qa_output metadata_output {
    capture confirm file ``output_file''
    if !_rc & !`replace_existing' {
        display as error "A Stage 3 private output already exists: ``output_file''"
        display as error "Review it or rerun with the explicit replace argument."
        exit 602
    }
}

capture mkdir "$BNR_PRIVATE/data/derived"
capture mkdir "`output_root'"
capture mkdir "`output_year'"
capture mkdir "`output_month'"
capture mkdir "`output_dir'"
capture mkdir "$BNR_PRIVATE_LOGS"

capture log close stage3
log using `"`output_log'"', text replace name(stage3)

display as text "BNR CVD STAGE 3: PRIVATE LINKAGE INPUT ASSEMBLY"
display as text "  CVD release:       `cvd_release'"
display as text "  Mortality release: `mortality_release'"
display as text "  CVD coverage end:  `event_coverage_end_iso'"

tempname qa_handle
tempfile qa_dta mortality_identity

postfile `qa_handle' str48 check long count str160 detail using `qa_dta', replace

* ---------------------------------------------------------------------------
* 1. Attach Step 1 mortality identity fields to Step 2 classifications.
* ---------------------------------------------------------------------------
use `"`mortality_raw'"', clear

keep record_id pname nrn sex age agetxt dth_date qa_dod qa_sex qa_age qa_any
isid record_id

quietly count
local mortality_raw_rows = r(N)
post `qa_handle' ("Raw mortality records") (`mortality_raw_rows') ///
    ("Unique Step 1 record IDs")

rename dth_date raw_dth_date
rename sex raw_sex
rename age raw_age
rename agetxt raw_agetxt
rename qa_dod raw_qa_dod
rename qa_sex raw_qa_sex
rename qa_age raw_qa_age
rename qa_any raw_qa_any

save `"`mortality_identity'"', replace

use `"`mortality_classified'"', clear

keep record_id dth_date dth_year dth_month dth_qtr sex age agetxt ///
    qa_dod qa_sex qa_age qa_any ///
    hrt_prim hrt_incl str_prim str_incl ///
    cvd_prim cvd_incl cvd_sub_p cvd_sub_i
isid record_id

quietly count
local mortality_classified_rows = r(N)
post `qa_handle' ("Classified mortality records") (`mortality_classified_rows') ///
    ("Unique Step 2 record IDs")

merge 1:1 record_id using `"`mortality_identity'"'

quietly count if _merge != 3
local mortality_unmatched = r(N)
post `qa_handle' ("Mortality Step 1/2 unmatched") (`mortality_unmatched') ///
    ("Must be zero before private linkage input is created")

if `mortality_unmatched' != 0 {
    postclose `qa_handle'
    use `"`qa_dta'"', clear
    export delimited using `"`qa_output'"', replace
    log close stage3
    display as error "Mortality Step 1 and Step 2 releases do not have an exact record-ID join."
    exit 459
}

generate byte __death_date_mismatch = !missing(dth_date, raw_dth_date) & ///
    dth_date != raw_dth_date
generate byte __sex_mismatch = strtrim(sex) != strtrim(raw_sex)
generate byte __age_mismatch = strtrim(age) != strtrim(raw_age)
generate byte __age_unit_mismatch = strtrim(agetxt) != strtrim(raw_agetxt)

foreach check in death_date sex age age_unit {
    quietly count if __`check'_mismatch == 1
    local mismatch_n = r(N)
    post `qa_handle' ("Mortality `check' mismatch") (`mismatch_n') ///
        ("Step 1 and Step 2 carried fields; must be zero")
    if `mismatch_n' != 0 {
        postclose `qa_handle'
        use `"`qa_dta'"', clear
        export delimited using `"`qa_output'"', replace
        log close stage3
        display as error "Mortality Step 1 and Step 2 have a carried-field mismatch."
        exit 459
    }
}

quietly count if cvd_prim == 1 & cvd_incl != 1
local primary_not_inclusive = r(N)
post `qa_handle' ("Primary outside Inclusive") (`primary_not_inclusive') ///
    ("Primary mortality candidates must be included in Inclusive")

if `primary_not_inclusive' != 0 {
    postclose `qa_handle'
    use `"`qa_dta'"', clear
    export delimited using `"`qa_output'"', replace
    log close stage3
    display as error "The Primary/Inclusive mortality invariant failed."
    exit 459
}

quietly count if cvd_incl == 1
local all_inclusive_deaths = r(N)
post `qa_handle' ("Inclusive mortality candidates") (`all_inclusive_deaths') ///
    ("All dates before CVD-coverage restriction")

generate byte __valid_death_date = qa_dod == 0 & !missing(dth_date)
generate byte __within_cvd_coverage = __valid_death_date == 1 & ///
    dth_date <= `event_coverage_end'
generate byte linkage_candidate_inclusive = cvd_incl == 1 & ///
    __within_cvd_coverage == 1

quietly count if cvd_incl == 1 & __valid_death_date == 0
local invalid_candidate_deaths = r(N)
post `qa_handle' ("Inclusive candidates: invalid death date") (`invalid_candidate_deaths') ///
    ("Excluded from linkage inputs")

quietly count if cvd_incl == 1 & __valid_death_date == 1 & ///
    dth_date > `event_coverage_end'
local post_coverage_deaths = r(N)
post `qa_handle' ("Inclusive candidates after CVD coverage") (`post_coverage_deaths') ///
    ("Excluded; CVD ascertainment ends `event_coverage_end_iso'")

keep if linkage_candidate_inclusive == 1

rename sex mortality_sex
rename age mortality_age
rename agetxt mortality_agetxt

generate byte mortality_has_name = strtrim(pname) != ""
generate byte mortality_has_nrn = strtrim(nrn) != ""

quietly count
local death_input_rows = r(N)
post `qa_handle' ("Private mortality linkage inputs") (`death_input_rows') ///
    ("Inclusive candidates within the CVD coverage window")

quietly count if mortality_has_name == 0
local death_input_missing_name = r(N)
post `qa_handle' ("Mortality linkage inputs: missing name") (`death_input_missing_name') ///
    ("Not eligible for name-based linkage rules")

quietly count if mortality_has_nrn == 0
local death_input_missing_nrn = r(N)
post `qa_handle' ("Mortality linkage inputs: missing NRN") (`death_input_missing_nrn') ///
    ("Not eligible for L01 exact-NRN linkage")

keep record_id dth_date dth_year dth_month dth_qtr ///
    pname nrn mortality_sex mortality_age mortality_agetxt ///
    qa_dod qa_sex qa_age qa_any ///
    hrt_prim hrt_incl str_prim str_incl ///
    cvd_prim cvd_incl cvd_sub_p cvd_sub_i ///
    mortality_has_name mortality_has_nrn

order record_id dth_date dth_year dth_month dth_qtr ///
    pname nrn mortality_sex mortality_age mortality_agetxt ///
    cvd_prim cvd_incl cvd_sub_p cvd_sub_i hrt_prim hrt_incl str_prim str_incl ///
    mortality_has_name mortality_has_nrn qa_dod qa_sex qa_age qa_any

label data "BNR private CVD linkage inputs - mortality candidates"
label variable pname "Full name as it appears on the death certificate"
label variable nrn "National Registration Number, source text"
label variable mortality_has_name "Nonblank death-certificate name available"
label variable mortality_has_nrn "Nonblank NRN available"

save `"`deaths_output'"', replace

* ---------------------------------------------------------------------------
* 2. Keep only hospital-recorded CVD events. Legacy imported DCOs remain
*    outside the new linkage pool, as required by the hardening contract.
* ---------------------------------------------------------------------------
use `"`cvd_confidential'"', clear

keep eid doe etype dco dob sex agey fname mname lname natregno ///
    source_era source_release
isid eid

quietly count
local all_cvd_rows = r(N)
post `qa_handle' ("CVD confidential rows") (`all_cvd_rows') ///
    ("All rows in the selected cumulative Step 2 dataset")

quietly count if !inlist(dco, 0, 1)
local invalid_dco_flag = r(N)
post `qa_handle' ("CVD rows: invalid or missing DCO flag") (`invalid_dco_flag') ///
    ("Must be zero; only 0=abstracted and 1=legacy DCO are permitted")

if `invalid_dco_flag' != 0 {
    postclose `qa_handle'
    use `"`qa_dta'"', clear
    export delimited using `"`qa_output'"', replace
    log close stage3
    display as error "The CVD DCO flag has an unexpected value."
    exit 459
}

quietly count if dco == 1
local legacy_dco_rows = r(N)
post `qa_handle' ("Legacy CVD DCO rows") (`legacy_dco_rows') ///
    ("Retained only for later private comparison; excluded from linkage pool")

quietly count if missing(doe) | missing(etype)
local incomplete_event_rows = r(N)
post `qa_handle' ("CVD rows: missing event date or type") (`incomplete_event_rows') ///
    ("Excluded from linkage inputs")

generate byte linkage_hospital_event = dco == 0 & !missing(doe, etype) & ///
    doe <= `event_coverage_end'

quietly count if dco == 0 & !missing(doe, etype) & doe > `event_coverage_end'
local post_coverage_events = r(N)
post `qa_handle' ("Hospital events after CVD coverage") (`post_coverage_events') ///
    ("Excluded; unexpected in selected cumulative release")

keep if linkage_hospital_event == 1

rename sex cvd_sex
decode etype, generate(cvd_event_type_source)
decode cvd_sex, generate(cvd_sex_source)

generate byte cvd_has_name = strtrim(fname) != "" & strtrim(lname) != ""
generate byte cvd_has_nrn = strtrim(natregno) != ""

quietly count
local event_input_rows = r(N)
post `qa_handle' ("Private CVD event linkage inputs") (`event_input_rows') ///
    ("Hospital-recorded events within the CVD coverage window")

quietly count if cvd_has_name == 0
local event_input_missing_name = r(N)
post `qa_handle' ("CVD linkage inputs: missing first or last name") (`event_input_missing_name') ///
    ("Not eligible for name-based linkage rules")

quietly count if cvd_has_nrn == 0
local event_input_missing_nrn = r(N)
post `qa_handle' ("CVD linkage inputs: missing NRN") (`event_input_missing_nrn') ///
    ("Not eligible for L01 exact-NRN linkage")

keep eid doe etype cvd_event_type_source dco dob cvd_sex cvd_sex_source ///
    agey fname mname lname natregno source_era source_release ///
    cvd_has_name cvd_has_nrn

order eid doe etype cvd_event_type_source dco dob cvd_sex cvd_sex_source ///
    agey fname mname lname natregno source_era source_release ///
    cvd_has_name cvd_has_nrn

label data "BNR private CVD linkage inputs - hospital-recorded events"
label variable cvd_event_type_source "Source CVD event-type value label"
label variable cvd_sex_source "Source CVD sex value label"
label variable cvd_has_name "Nonblank first and last names available"
label variable cvd_has_nrn "Nonblank NRN available"

save `"`events_output'"', replace

postclose `qa_handle'

use `"`qa_dta'"', clear
order check count detail
export delimited using `"`qa_output'"', replace

tempname linkage_metadata
file open `linkage_metadata' using `"`metadata_output'"', write text replace
file write `linkage_metadata' "schema: bnr_cvd_linkage_input_v1" _n
file write `linkage_metadata' "stage: 3" _n
file write `linkage_metadata' "cvd_release: `cvd_release'" _n
file write `linkage_metadata' "mortality_release: `mortality_release'" _n
file write `linkage_metadata' "cvd_coverage_end: `event_coverage_end_iso'" _n
file write `linkage_metadata' "mortality_raw_source: bnr_mort_s1_`mortality_year4'`mortality_month2'.dta" _n
file write `linkage_metadata' "mortality_classified_source: bnr_mort_s2_`mortality_year4'`mortality_month2'.dta" _n
file write `linkage_metadata' "cvd_confidential_source: bnr_cvd_confidential_`cvd_year4'`cvd_month2'_v01.dta" _n
file write `linkage_metadata' "mortality_record_id_join: exact_one_to_one" _n
file write `linkage_metadata' "mortality_candidate_definition: inclusive_cvd_with_valid_death_date_within_cvd_coverage" _n
file write `linkage_metadata' "cvd_event_definition: hospital_recorded_dco_zero_with_valid_event_date" _n
file write `linkage_metadata' "legacy_cvd_dco_policy: excluded_from_new_linkage_pool" _n
file write `linkage_metadata' "person_matching: not_run" _n
file write `linkage_metadata' "episode_linkage: not_run" _n
file write `linkage_metadata' "dco_estimation: not_run" _n
file write `linkage_metadata' "mortality_input_rows: `death_input_rows'" _n
file write `linkage_metadata' "cvd_event_input_rows: `event_input_rows'" _n
file close `linkage_metadata'

display as result ""
display as result "============================================================================="
display as result "STAGE 3: PRIVATE LINKAGE INPUT ASSEMBLY"
display as result "  Run status:                 COMPLETE"
display as result "  CVD coverage end:           `event_coverage_end_iso'"
display as result "  Mortality candidate inputs: `death_input_rows'"
display as result "  Hospital event inputs:      `event_input_rows'"
display as result "  Private output directory:   `output_dir'"
display as result "  Next stage:                 Deterministic matching only; no public output"
display as result "============================================================================="

log close stage3

/*******************************************************************************

DO-FILE:     bnr_cvd_profile_linkage_inputs.do

VERSION:     1.0.4 (27 August 2026)

PURPOSE:     Stage 4A private preflight for deterministic CVD mortality linkage.

              This profile checks the private Stage 3 linkage inputs before
              person matching begins. It creates aggregate QA, source-category
              and exact-NRN sex-crosswalk files only. It does not save names,
              NRNs, candidate-level matches, episode outcomes, DCO estimates,
              metric rows or public output.

              The outputs are used to freeze source transformations for the
              Stage 4 deterministic linkage engine:

              - mortality and CVD NRN format and duplicate checks;
              - source sex crosswalk using exact valid NRNs;
              - mortality age-unit distribution;
              - CVD source event-type distribution; and
              - aggregate certificate-name and CVD-name completeness checks.

USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_profile_linkage_inputs.do" ///
                 2024 04 2026 07

              Add replace only to replace existing aggregate profile files:

              do "$BNR_STATA/metrics/cvd/bnr_cvd_profile_linkage_inputs.do" ///
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

local input_dir ///
    "$BNR_PRIVATE/data/derived/cvd/y`cvd_year4'/m`cvd_month2'/linkage/mort_y`mortality_year4'_m`mortality_month2'"
local deaths_input ///
    "`input_dir'/bnr_cvd_linkage_deaths_`linkage_release'.dta"
local events_input ///
    "`input_dir'/bnr_cvd_linkage_events_`linkage_release'.dta"
local summary_output ///
    "`input_dir'/stage4_profile_summary_`linkage_release'.csv"
local categories_output ///
    "`input_dir'/stage4_profile_source_categories_`linkage_release'.csv"
local sex_crosswalk_output ///
    "`input_dir'/stage4_profile_nrn_sex_crosswalk_`linkage_release'.csv"
local output_log ///
    "$BNR_PRIVATE_LOGS/bnr_cvd_linkage_profile_`cvd_year4'`cvd_month2'_mort_`mortality_year4'`mortality_month2'.log"

foreach required_file in deaths_input events_input {
    capture confirm file ``required_file''
    if _rc {
        display as error "Required Stage 3 private input was not found: ``required_file''"
        exit 601
    }
}

foreach output_file in summary_output categories_output sex_crosswalk_output {
    capture confirm file ``output_file''
    if !_rc & !`replace_existing' {
        display as error "A Stage 4 profile output already exists: ``output_file''"
        display as error "Review it or rerun with the explicit replace argument."
        exit 602
    }
}

capture mkdir "$BNR_PRIVATE_LOGS"
capture log close stage4profile
log using `"`output_log'"', text replace name(stage4profile)

display as text "BNR CVD STAGE 4A: PRIVATE LINKAGE PROFILE"
display as text "  CVD release:       `cvd_release'"
display as text "  Mortality release: `mortality_release'"

tempname summary_handle
tempfile summary_dta category_rows event_nrn sex_crosswalk_dta

postfile `summary_handle' str52 check long count str160 detail using `summary_dta', replace

* An empty category shell makes the aggregate output robust even where a source
* category happens not to occur in a particular release.
clear
set obs 0
generate str24 domain = ""
generate str32 variable = ""
generate str24 source_value = ""
generate str80 source_label = ""
generate long count = .
save `"`category_rows'"', replace

* ---------------------------------------------------------------------------
* 1. Mortality candidate profile
* ---------------------------------------------------------------------------
use `"`deaths_input'"', clear

isid record_id

generate str32 nrn_clean = subinstr(strtrim(nrn), "-", "", .)
replace nrn_clean = subinstr(nrn_clean, " ", "", .)
generate byte nrn_format_valid = strlen(nrn_clean) == 10 & ///
    regexm(nrn_clean, "^[0-9]+$")
generate byte nrn_yymmdd_valid = nrn_format_valid == 1 & ///
    inrange(real(substr(nrn_clean, 3, 2)), 1, 12) & ///
    inrange(real(substr(nrn_clean, 5, 2)), 1, 31)
generate byte nrn_has_leading_zero = nrn_format_valid == 1 & ///
    substr(nrn_clean, 1, 1) == "0"

quietly count
local death_rows = r(N)
post `summary_handle' ("Mortality linkage inputs") (`death_rows') ///
    ("Inclusive mortality candidates within CVD coverage")

quietly count if nrn_format_valid == 1
local mortality_valid_nrn = r(N)
post `summary_handle' ("Mortality: valid NRN format") (`mortality_valid_nrn') ///
    ("Ten digits after permitted hyphen/space separator removal")

quietly count if nrn_format_valid == 1 & nrn_yymmdd_valid == 0
local mortality_invalid_nrn_dob = r(N)
post `summary_handle' ("Mortality: invalid NRN day/month prefix") (`mortality_invalid_nrn_dob') ///
    ("Valid format but impossible MM/DD component")

quietly count if nrn_has_leading_zero == 1
local mortality_leading_zero = r(N)
post `summary_handle' ("Mortality: valid NRN with leading zero") (`mortality_leading_zero') ///
    ("String preservation check; no numeric conversion permitted")

bysort nrn_clean: generate long __nrn_frequency = _N if nrn_format_valid == 1
quietly count if nrn_format_valid == 1 & __nrn_frequency > 1
local mortality_duplicate_nrn_rows = r(N)
post `summary_handle' ("Mortality: rows in duplicate-NRN groups") (`mortality_duplicate_nrn_rows') ///
    ("Requires private review; NRN cannot be assumed person-unique")

quietly count if strtrim(pname) == ""
local mortality_missing_name = r(N)
post `summary_handle' ("Mortality: blank certificate name") (`mortality_missing_name') ///
    ("Not eligible for L02/L03 name rules")

quietly count if strpos(pname, ",") > 0
local mortality_name_comma = r(N)
post `summary_handle' ("Mortality: certificate names containing comma") (`mortality_name_comma') ///
    ("Name normalisation must retain boundary-token information")

quietly count if regexm(pname, "[0-9]")
local mortality_name_digit = r(N)
post `summary_handle' ("Mortality: certificate names containing digit") (`mortality_name_digit') ///
    ("Name normalisation must not create a false exact match")

quietly count if mortality_agetxt == "6"
local mortality_age_years = r(N)
post `summary_handle' ("Mortality: age unit is Years") (`mortality_age_years') ///
    ("Only these records may use L03 age fallback")

preserve
    keep mortality_sex
    rename mortality_sex source_value
    replace source_value = "<blank>" if strtrim(source_value) == ""
    contract source_value, freq(count)
    generate str24 domain = "mortality"
    generate str32 variable = "mortality_sex"
    generate str80 source_label = ""
    order domain variable source_value source_label count
    append using `"`category_rows'"'
    save `"`category_rows'"', replace
restore

preserve
    keep mortality_agetxt
    rename mortality_agetxt source_value
    replace source_value = "<blank>" if strtrim(source_value) == ""
    generate str80 source_label = ""
    replace source_label = "Minutes" if source_value == "1"
    replace source_label = "Hours" if source_value == "2"
    replace source_label = "Days" if source_value == "3"
    replace source_label = "Weeks" if source_value == "4"
    replace source_label = "Months" if source_value == "5"
    replace source_label = "Years" if source_value == "6"
    replace source_label = "Not documented" if source_value == "99"
    contract source_value source_label, freq(count)
    generate str24 domain = "mortality"
    generate str32 variable = "mortality_agetxt"
    order domain variable source_value source_label count
    append using `"`category_rows'"'
    save `"`category_rows'"', replace
restore

keep if nrn_format_valid == 1 & !missing(mortality_sex)
keep nrn_clean mortality_sex
save `"`sex_crosswalk_dta'"', replace

* ---------------------------------------------------------------------------
* 2. CVD hospital-event profile and a valid-NRN sex crosswalk.
* ---------------------------------------------------------------------------
use `"`events_input'"', clear

isid eid

generate str32 nrn_clean = subinstr(strtrim(natregno), "-", "", .)
replace nrn_clean = subinstr(nrn_clean, " ", "", .)
generate byte nrn_format_valid = strlen(nrn_clean) == 10 & ///
    regexm(nrn_clean, "^[0-9]+$")
generate byte nrn_yymmdd_valid = nrn_format_valid == 1 & ///
    inrange(real(substr(nrn_clean, 3, 2)), 1, 12) & ///
    inrange(real(substr(nrn_clean, 5, 2)), 1, 31)
generate byte nrn_has_leading_zero = nrn_format_valid == 1 & ///
    substr(nrn_clean, 1, 1) == "0"

quietly count
local event_rows = r(N)
post `summary_handle' ("CVD hospital-event linkage inputs") (`event_rows') ///
    ("Hospital-recorded Heart/Stroke source events within CVD coverage")

quietly count if nrn_format_valid == 1
local cvd_valid_nrn = r(N)
post `summary_handle' ("CVD: valid NRN format") (`cvd_valid_nrn') ///
    ("Ten digits after permitted hyphen/space separator removal")

quietly count if nrn_format_valid == 1 & nrn_yymmdd_valid == 0
local cvd_invalid_nrn_dob = r(N)
post `summary_handle' ("CVD: invalid NRN day/month prefix") (`cvd_invalid_nrn_dob') ///
    ("Valid format but impossible MM/DD component")

quietly count if nrn_has_leading_zero == 1
local cvd_leading_zero = r(N)
post `summary_handle' ("CVD: valid NRN with leading zero") (`cvd_leading_zero') ///
    ("String preservation check; no numeric conversion permitted")

bysort nrn_clean: generate long __nrn_frequency = _N if nrn_format_valid == 1
quietly count if nrn_format_valid == 1 & __nrn_frequency > 1
local cvd_duplicate_nrn_rows = r(N)
post `summary_handle' ("CVD: rows in duplicate-NRN groups") (`cvd_duplicate_nrn_rows') ///
    ("Multiple events are expected; only demographic contradictions matter")

quietly count if missing(dob)
local cvd_missing_dob = r(N)
post `summary_handle' ("CVD: missing explicit DOB") (`cvd_missing_dob') ///
    ("Limits L02/L03 DOB confirmation")

quietly count if cvd_has_name == 0
local cvd_missing_name = r(N)
post `summary_handle' ("CVD: missing first or last name") (`cvd_missing_name') ///
    ("Not eligible for L02/L03 name rules")

quietly count if strtrim(mname) == ""
local cvd_missing_middle = r(N)
post `summary_handle' ("CVD: missing middle name") (`cvd_missing_middle') ///
    ("Full-name normalisation must support no-middle-name form")

preserve
    tostring cvd_sex, generate(source_value) force usedisplayformat
    generate str80 source_label = cvd_sex_source
    replace source_label = "<blank>" if strtrim(source_label) == ""
    contract source_value source_label, freq(count)
    generate str24 domain = "cvd"
    generate str32 variable = "cvd_sex"
    order domain variable source_value source_label count
    append using `"`category_rows'"'
    save `"`category_rows'"', replace
restore

preserve
    tostring etype, generate(source_value) force usedisplayformat
    generate str80 source_label = cvd_event_type_source
    replace source_label = "<blank>" if strtrim(source_label) == ""
    contract source_value source_label, freq(count)
    generate str24 domain = "cvd"
    generate str32 variable = "cvd_event_type"
    order domain variable source_value source_label count
    append using `"`category_rows'"'
    save `"`category_rows'"', replace
restore

keep if nrn_format_valid == 1 & !missing(cvd_sex)
keep nrn_clean cvd_sex cvd_sex_source
sort nrn_clean cvd_sex
by nrn_clean: generate byte __sex_change = _n > 1 & cvd_sex != cvd_sex[_n-1]
by nrn_clean: egen byte __cvd_nrn_sex_conflict = max(__sex_change)
by nrn_clean: generate byte __first_nrn = _n == 1

quietly count if __first_nrn == 1 & __cvd_nrn_sex_conflict == 1
local cvd_conflicting_nrn_sex = r(N)
post `summary_handle' ("CVD: distinct NRNs with sex contradiction") (`cvd_conflicting_nrn_sex') ///
    ("Cannot support a deterministic exact-NRN match")

keep if __first_nrn == 1
keep nrn_clean cvd_sex cvd_sex_source __cvd_nrn_sex_conflict
tempfile event_nrn
save `"`event_nrn'"', replace

use `"`sex_crosswalk_dta'"', clear
merge m:1 nrn_clean using `"`event_nrn'"'

quietly count if _merge == 3
local exact_nrn_crosswalk_rows = r(N)
post `summary_handle' ("Mortality rows with CVD valid-NRN counterpart") (`exact_nrn_crosswalk_rows') ///
    ("Aggregate profile only; no candidate linkage output created")

quietly count if _merge == 3 & __cvd_nrn_sex_conflict == 1
local crosswalk_conflicting_cvd_nrn = r(N)
post `summary_handle' ("Crosswalk rows: CVD NRN sex conflict") (`crosswalk_conflicting_cvd_nrn') ///
    ("Excluded when inferring source sex mapping")

preserve
    keep if _merge == 3 & __cvd_nrn_sex_conflict == 0
    keep mortality_sex cvd_sex cvd_sex_source
    tostring cvd_sex, generate(cvd_sex_code) force usedisplayformat
    contract mortality_sex cvd_sex_code cvd_sex_source, freq(count)
    order mortality_sex cvd_sex_code cvd_sex_source count
    export delimited using `"`sex_crosswalk_output'"', replace
restore

postclose `summary_handle'

use `"`summary_dta'"', clear
order check count detail
export delimited using `"`summary_output'"', replace

use `"`category_rows'"', clear
drop if domain == ""
sort domain variable source_value source_label
export delimited using `"`categories_output'"', replace

display as result ""
display as result "============================================================================="
display as result "STAGE 4A: PRIVATE LINKAGE PROFILE"
display as result "  Run status:                     COMPLETE"
display as result "  Mortality candidate inputs:     `death_rows'"
display as result "  CVD hospital-event inputs:      `event_rows'"
display as result "  Valid-NRN crosswalk rows:       `exact_nrn_crosswalk_rows'"
display as result "  Summary profile:                `summary_output'"
display as result "  Sex crosswalk:                  `sex_crosswalk_output'"
display as result "  Next action:                    Review aggregates before matching"
display as result "============================================================================="

log close stage4profile

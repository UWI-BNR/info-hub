/*******************************************************************************
DO-FILE:     bnr_cvd_prepare_rate_reference.do
VERSION:     1.0.7 (26 August 2026)
RELEASE:     Stage 3 rate-construction integrated release 1.0.7
PURPOSE:     Create the private Barbados population and WHO World Standard
             reference assets required by the CVD annual-rate estimator.

INPUT:       A private, pre-extracted WPP 2024 Barbados population DTA with:
                 year          integer calendar year
                 sex           all, female or male
                 age_group     age_0_4 ... age_95_99, age_100_plus
                 population    positive population estimate

             The source extraction is deliberately separate from this script.
             It makes the official WPP 2024 selection visible and reviewable,
             instead of burying source-column choices in the rate estimator.

OUTPUTS:     Validated population DTA, WHO standard-weight DTA, QA CSV.

USAGE:       do "$BNR_STATA/metrics/cvd/bnr_cvd_prepare_rate_reference.do" population_input population_output standard_output qa_output [replace]
*******************************************************************************/
version 19
clear all
set more off

args population_input population_output standard_output qa_output option
if `"`population_input'"' == "" | `"`population_output'"' == "" | ///
        `"`standard_output'"' == "" | `"`qa_output'"' == "" {
    display as error "Rate-reference preparation received an incomplete file contract."
    exit 198
}
if `"`option'"' != "" & lower(`"`option'"') != "replace" {
    display as error "The only optional argument is replace."
    exit 198
}

capture confirm file `"`population_input'"'
if _rc {
    display as error "WPP 2024 population input was not found: `population_input'"
    exit 601
}
foreach f in population_output standard_output qa_output {
    capture confirm file ``f''
    if !_rc & lower(`"`option'"') != "replace" {
        display as error "Private reference output already exists: ``f''"
        exit 602
    }
}

tempfile qa_dta standard_raw expected_age_groups standard_candidate ///
    population_candidate
tempname qa_handle standard_handle

* ---------------------------------------------------------------------------
* 1. Define the fixed WHO World Standard Population (2000--2025).
*    Values are published percentages. They are normalised after import because
*    the published rounded values sum very slightly above 100.
* ---------------------------------------------------------------------------
postfile `standard_handle' str16 age_group double published_percent using `"`standard_raw'"', replace
post `standard_handle' ("age_0_4")     (8.86)
post `standard_handle' ("age_5_9")     (8.69)
post `standard_handle' ("age_10_14")   (8.60)
post `standard_handle' ("age_15_19")   (8.47)
post `standard_handle' ("age_20_24")   (8.22)
post `standard_handle' ("age_25_29")   (7.93)
post `standard_handle' ("age_30_34")   (7.61)
post `standard_handle' ("age_35_39")   (7.15)
post `standard_handle' ("age_40_44")   (6.59)
post `standard_handle' ("age_45_49")   (6.04)
post `standard_handle' ("age_50_54")   (5.37)
post `standard_handle' ("age_55_59")   (4.55)
post `standard_handle' ("age_60_64")   (3.72)
post `standard_handle' ("age_65_69")   (2.96)
post `standard_handle' ("age_70_74")   (2.21)
post `standard_handle' ("age_75_79")   (1.52)
post `standard_handle' ("age_80_84")   (0.91)
post `standard_handle' ("age_85_89")   (0.44)
post `standard_handle' ("age_90_94")   (0.15)
post `standard_handle' ("age_95_99")   (0.04)
post `standard_handle' ("age_100_plus") (0.005)
postclose `standard_handle'

use `"`standard_raw'"', clear
quietly summarize published_percent, meanonly
generate double standard_weight = published_percent / r(sum)
generate str28 standard_id = "who_world_standard_2000_2025"
generate str80 standard_source = "WHO Age standardization of rates: a new WHO standard (2001)"
assert standard_weight > 0
quietly summarize standard_weight, meanonly
assert abs(r(sum) - 1) < 0.000000001
isid age_group
order age_group published_percent standard_weight standard_id standard_source
save `"`standard_candidate'"', replace

keep age_group
save `"`expected_age_groups'"', replace

* ---------------------------------------------------------------------------
* 2. Validate and save the pre-extracted WPP 2024 Barbados population input.
* ---------------------------------------------------------------------------
use `"`population_input'"', clear
foreach v in year sex age_group population {
    capture confirm variable `v'
    if _rc {
        display as error "WPP 2024 population input is missing variable: `v'"
        exit 111
    }
}

capture confirm numeric variable year
if _rc exit 109
capture confirm numeric variable population
if _rc exit 109
capture confirm string variable sex
if _rc exit 109
capture confirm string variable age_group
if _rc exit 109

replace sex = lower(strtrim(sex))
replace age_group = lower(strtrim(age_group))
assert inlist(sex, "all", "female", "male")
assert inrange(year, 2010, 2035)
assert population > 0 & !missing(population)

merge m:1 age_group using `"`expected_age_groups'"', gen(__age_group_merge)
assert __age_group_merge == 3
drop __age_group_merge
isid year sex age_group
bysort year sex: assert _N == 21
quietly summarize year, meanonly
assert r(min) == 2010
assert r(max) == 2035
quietly levelsof year, local(coverage_years)
local coverage_year_n : word count `coverage_years'
assert `coverage_year_n' == 26

preserve
    keep year sex age_group population
    reshape wide population, i(year age_group) j(sex) string
    assert !missing(populationall, populationfemale, populationmale)
    assert abs(populationall - populationfemale - populationmale) < 0.000001
restore

foreach v in population_source country_iso3 population_unit population_basis ///
        extraction_date asset_version population_source_note {
    capture drop `v'
}
generate str12 population_source = "UN_WPP_2024"
generate str3 country_iso3 = "BRB"
generate str10 population_unit = "persons"
generate str10 asset_version = "1.0.7"
generate str10 extraction_date = "2026-08-26"
generate str28 population_basis = "historical_estimate"
replace population_basis = "medium_variant_projection" if year >= 2024
generate str80 population_source_note = ///
    "United Nations World Population Prospects 2024, Barbados"
order year sex age_group population population_source country_iso3 population_unit ///
    population_basis extraction_date asset_version population_source_note
sort year sex age_group
save `"`population_candidate'"', replace

* ---------------------------------------------------------------------------
* 3. Compact aggregate QA only.
* ---------------------------------------------------------------------------
postfile `qa_handle' str80 check double value str180 detail using `"`qa_dta'"', replace
quietly count
local population_rows = r(N)
post `qa_handle' ("WPP 2024 Barbados population rows") (`population_rows') ///
    ("One row per year, sex and 5-year age group")

quietly levelsof year, local(years)
local year_n : word count `years'
post `qa_handle' ("WPP 2024 Barbados population years") (`year_n') ///
    ("Expected annual denominator coverage: 2010--2035 inclusive")

quietly count if sex == "all"
local all_rows = r(N)
post `qa_handle' ("All-sex population rows") (`all_rows') ///
    ("Required for all-sex crude and age-standardised rates")

use `"`standard_candidate'"', clear
quietly summarize standard_weight, meanonly
post `qa_handle' ("WHO standard-weight sum") (r(sum)) ///
    ("Must equal one after normalisation of published rounded percentages")

quietly count
post `qa_handle' ("WHO standard age groups") (r(N)) ///
    ("0-4 through 100+; 21 five-year groups")
postclose `qa_handle'

use `"`qa_dta'"', clear
order check value detail
export delimited using `"`qa_output'"', replace

use `"`population_candidate'"', clear
save `"`population_output'"', replace
use `"`standard_candidate'"', clear
save `"`standard_output'"', replace

display as result "Private rate-reference assets created."
display as result "  Population: `population_output'"
display as result "  Standard:   `standard_output'"
display as result "  QA:         `qa_output'"

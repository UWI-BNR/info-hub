/*******************************************************************************
DO-FILE:     bnr_mort_s2_classify.do
VERSION:     1.0.0 (19 August 2026)
PROJECT:     BNR Refit Phase 2
PURPOSE:     Frozen operational Step 2 of the BNR mortality workflow.

             The program reads the private Step 1 all-deaths dataset, applies
             the frozen v0.6.1 BNR-Heart / BNR-Stroke approximate-UCoD
             classifier, creates a smaller fully labelled classified DTA, and
             writes concise private review/metadata outputs.

CLASSIFIER DEFINITION:
             0.6.1 - FROZEN

             Version 1.0.0 changes dataset structure, labels, notes and
             documentation only. It does NOT change Heart/Stroke
             classification semantics from validated classifier v0.6.1.

USAGE:
                 do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 7

             To deliberately replace an existing Step 2 release:

                 do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 7 replace

INPUT:
             $BNR_DATA_RAW/redcap/mortality/yYYYY/mMM/
                 bnr_mort_s1_YYYYMM.dta

ROUTINE PRIVATE OUTPUTS:
             $BNR_DATA_DERIVED/mortality/yYYYY/mMM/
                 bnr_mort_s2_YYYYMM.dta
                 bnr_mort_s2_YYYYMM_summary.csv
                 bnr_mort_s2_YYYYMM_review.csv
                 bnr_mort_s2_YYYYMM_structure_summary.csv
                 bnr_mort_s2_YYYYMM_manifest.yml

             $BNR_PRIVATE_LOGS/
                 bnr_mort_s2_YYYYMM.log

COMPANION METADATA IN THE CODE FOLDER:
                 bnr_mort_s2_rule_dictionary.csv
                 bnr_mort_s2_nosology.csv
                 bnr_mort_s2_variable_dictionary.csv
                 bnr_mort_s2_methods.md

PLAIN-LANGUAGE METHOD BOUNDARY:
             This is a practical second-best surveillance method for use while
             Barbados does not have a formally assigned national underlying
             cause of death (UCoD) available to BNR.

             The method uses:
                 - the wording written on the death certificate;
                 - whether wording is in Part I or Part II;
                 - the order of the Part I lines;
                 - a small number of documented mortality-coding principles;
                 - explicit uncertainty classes.

             It is NOT full ICD-10 coding and does NOT attempt to reproduce
             formal UCoD software such as DORIS.

EVIDENCE CLASSES:
             1 Clear
                 Strongest evidence available to this practical method.

             2 Likely
                 Good evidence for approximate UCoD, but some uncertainty
                 remains. This is included in the Primary reporting scenario.

             3 Possible
                 Plausible approximate UCoD, but uncertainty is material.

             4 Mention only
                 Relevant disease wording is present but does not support
                 approximate-UCoD attribution.

             5 No evidence
                 No qualifying evidence was detected by the approved rules.

SENSITIVITY SCENARIOS:
             Conservative = Clear
             Primary      = Clear + Likely
             Inclusive    = Clear + Likely + Possible

             These are classification-sensitivity scenarios. They are not
             confidence intervals and should not be described as statistical
             lower/upper confidence bounds.

BNR-HEART:
             Fatal-event surveillance is not restricted to certificates that
             literally say acute myocardial infarction. It includes compatible
             ischaemic/coronary Heart evidence. Explicit AMI remains separately
             recorded as a diagnostic basis.

BNR-STROKE:
             Fatal-event surveillance follows the established BNR-Stroke
             disease family, including acute ischaemic Stroke and qualifying
             non-traumatic cerebral haemorrhage. Explicit traumatic and other
             excluded haemorrhage patterns remain outside the direct rules.

SOURCE STRUCTURE:
             Source-data structure is handled separately from disease
             classification. A known BNR-concatenated record or a record with
             uncertain source structure cannot remain Clear, because the
             original causal line order is not known reliably.

RESIDENCY ELIGIBILITY:
             Step 2 does not repeat a residency test. The operating assumption
             is that BNR staff establish Barbados residency eligibility during
             review of each death certificate before the record enters this
             post-REDCap analytical pathway.

DCO BOUNDARY:
             Future Death Certificate Only event processing is a separate
             workflow. It begins with the matching private Step 1 ALL-DEATHS
             dataset because Step 1 retains authorised linkage fields such as
             NRN. Selected Step 2 Heart/Stroke classification evidence is then
             merged back by record_id. Mortality attribution supports DCO
             assessment but must never, by itself, determine DCO eligibility.

CONFIDENTIALITY:
             All Step 2 outputs remain private. The classified DTA deliberately
             excludes direct identity/linkage fields such as name, address and
             NRN, but it still contains internal record_id and death-certificate
             text and must never enter the public repository.

ANALYST-EDITABLE INPUTS:
             Routine analysts change only:
                 - release year;
                 - release month;
                 - optional replace argument.

CHANGE CONTROL:
             The classifier definition is frozen at v0.6.1. A future change to
             disease terminology, evidence classes, causal rules or scenario
             membership requires a deliberate new classifier-definition
             version, review against real certificates, and documentation.

             Metadata-only corrections can increment the script/package
             version without silently changing the frozen classifier.
*******************************************************************************/

version 19
set more off


* =============================================================================
* SECTION 0 - DO NOT TOUCH THIS SECTION
* Standard failure message
* =============================================================================

capture program drop _bnr_mort_s2_fail
program define _bnr_mort_s2_fail
    version 19
    args return_code release_id log_path reason

    noisily display as error ""
    noisily display as error "============================================================================="
    noisily display as error "MORTALITY STEP 2 DID NOT COMPLETE"
    noisily display as error "  Release: `release_id'"
    noisily display as error `"  Reason:  `reason'"'
    noisily display as error `"  Log:     `log_path'"'
    noisily display as text  "Do not use files from this incomplete run."
    noisily display as error "============================================================================="
    capture log close mort_class
    exit `return_code'
end


* =============================================================================
* SECTION 1 - EDIT THIS SECTION
* Routine analyst inputs
* =============================================================================

args release_year release_month replace_existing

if "`release_year'" == "" | "`release_month'" == "" {
    display as error "Year and month are required."
    display as error ///
        `"Example: do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 7"'
    exit 198
}

* Load BNR workstation paths if they are not already available.
if `"$BNR_STATA"' == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    local config_rc = _rc
    if `config_rc' {
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}

if `"$BNR_STATA"' == "" | `"$BNR_DATA_RAW"' == "" | ///
        `"$BNR_DATA_DERIVED"' == "" | `"$BNR_PRIVATE_LOGS"' == "" {
    display as error "The BNR local path configuration is incomplete."
    exit 198
}


* =============================================================================
* SECTION 2 - DO NOT TOUCH THIS SECTION
* Validate release inputs
* =============================================================================

local year_num  = real("`release_year'")
local month_num = real("`release_month'")

if missing(`year_num') | `year_num' != floor(`year_num') | `year_num' < 2008 {
    display as error "Year must be an integer greater than or equal to 2008."
    exit 198
}

if missing(`month_num') | `month_num' != floor(`month_num') | ///
        !inrange(`month_num', 1, 12) {
    display as error "Month must be an integer from 1 to 12."
    exit 198
}

if "`replace_existing'" != "" & lower("`replace_existing'") != "replace" {
    display as error "The optional third argument must be replace."
    exit 198
}

local year4  : display %04.0f `year_num'
local month2 : display %02.0f `month_num'
local period "`year4'`month2'"


* =============================================================================
* SECTION 3 - DO NOT TOUCH THIS SECTION
* Define input and private output locations
* =============================================================================

local input ///
    "$BNR_DATA_RAW/redcap/mortality/y`year4'/m`month2'/bnr_mort_s1_`period'.dta"

local outdir ///
    "$BNR_DATA_DERIVED/mortality/y`year4'/m`month2'"

local outbase "`outdir'/bnr_mort_s2_`period'"

local outdta      "`outbase'.dta"
local outsummary  "`outbase'_summary.csv"
local outreview   "`outbase'_review.csv"
local outstructure "`outbase'_structure_summary.csv"

* Retired development diagnostics. These are erased on an authorised
* replacement run so stale development files cannot be mistaken for current
* Step 2 outputs.
local outaudit_old    "`outbase'_audit.csv"
local outpossible_old "`outbase'_possible_review.csv"
local outobsolete     "`outbase'_legacy_clear_audit.csv"
local outmanifest "`outbase'_manifest.yml"
local outlog      "$BNR_PRIVATE_LOGS/bnr_mort_s2_`period'.log"

capture mkdir "$BNR_DATA_DERIVED"
capture mkdir "$BNR_DATA_DERIVED/mortality"
capture mkdir "$BNR_DATA_DERIVED/mortality/y`year4'"
capture mkdir "`outdir'"

capture log close mort_class
log using "`outlog'", text replace name(mort_class)


quietly {

noisily display as text "BNR MORTALITY STEP 2: CLASSIFY BNR-HEART / BNR-STROKE APPROXIMATE UCoD"
noisily display as result "  Script version:   1.0.0"
noisily display as result "  Selected release: `year4'-`month2'"
noisily display as result "  Reference:        ICD-10 mortality principles"
noisily display as result "  Evidence classes: Clear / Likely / Possible / Mention / No evidence"
noisily display as result "  Private output:   `outdir'"


* =============================================================================
* SECTION 4 - DO NOT TOUCH THIS SECTION
* Confirm source and protect existing outputs
* =============================================================================

capture confirm file "`input'"
if _rc {
    _bnr_mort_s2_fail 601 "`year4'-`month2'" "`outlog'" ///
        "The matching Step 1 mortality dataset was not found."
}

local existing_output 0
foreach file in "`outdta'" "`outsummary'" "`outreview'" ///
        "`outstructure'" "`outmanifest'" {
    capture confirm file `"`file'"'
    if !_rc local existing_output 1
}

if `existing_output' & lower("`replace_existing'") != "replace" {
    _bnr_mort_s2_fail 602 "`year4'-`month2'" "`outlog'" ///
        "Step 2 outputs already exist. Rerun only with explicit replace authorisation."
}

* Remove retired development diagnostics when replacement is authorised.
* The frozen operational Step 2 package keeps one targeted review CSV rather
* than several overlapping development QA files.
if lower("`replace_existing'") == "replace" {
    capture erase "`outobsolete'"
    capture erase "`outaudit_old'"
    capture erase "`outpossible_old'"
}


* =============================================================================
* SECTION 5 - DO NOT TOUCH THIS SECTION
* Load and validate the Step 1 analytical dataset
* =============================================================================

use "`input'", clear

capture confirm variable ///
    record_id dth_date dth_year dth_month dth_qtr ///
    sex age agetxt parish ///
    qa_dod qa_pre08 qa_year qa_reg qa_dup qa_cert qa_sex qa_age qa_any ///
    cod1a cod1b cod1c cod1d cod2a cod2b ///
    c1a_cln c1b_cln c1c_cln c1d_cln c2a_cln c2b_cln

if _rc {
    _bnr_mort_s2_fail 111 "`year4'-`month2'" "`outlog'" ///
        "The Step 1 dataset is missing one or more required mortality variables."
}

local n_deaths = _N

quietly count if missing(dth_date)
local n_bad_date = r(N)


* =============================================================================
* SECTION 6 - DO NOT TOUCH THIS SECTION
* Create matching-only text copies
*
* Source variables and Step 1 cleaned variables remain unchanged.
* 99 and 999 are legacy cause-field placeholders and are analytically blank.
* Punctuation is normalized only in m1a-m2b for transparent matching.
* =============================================================================

foreach x in 1a 1b 1c 1d 2a 2b {

    generate strL t`x' = ustrlower(ustrtrim(c`x'_cln))

    replace t`x' = "" if ///
        inlist(strtrim(t`x'), "", "99", "999")

    replace t`x' = ustrregexra(t`x', "[\r\n\t]+", " ")
    replace t`x' = ustrregexra(t`x', " +", " ")

    generate strL m`x' = t`x'
    replace m`x' = ustrregexra(m`x', "[^a-z0-9]+", " ")
    replace m`x' = ustrregexra(m`x', " +", " ")
    replace m`x' = strtrim(m`x')
}


* =============================================================================
* SECTION 6A - DO NOT TOUCH THIS SECTION
* Cause-of-death source structure / provenance
*
* This is deliberately separate from the Heart/Stroke classifier. The classifier
* must respond to the information structure actually available, not to a
* calendar era.
*
* Preferred pathway:
*   Step 1 supplies numeric mort_source_structure:
*       1 = certificate line structure preserved
*       2 = known BNR-concatenated representation
*       3 = structure/provenance uncertain
*
* Temporary development bridge:
*   The current hardened Step 1 predates this field. Until Step 1 supplies it,
*   the code uses the confirmed historical BNR lineage: Part I(a)-only records
*   through 2017 are treated as known concatenated. This fallback is NOT a
*   nosology rule and is bypassed automatically once the explicit Step 1 field
*   exists.
* =============================================================================

local source_structure_mode "development_fallback"

capture confirm variable mort_source_structure
if !_rc {
    generate byte source_structure = mort_source_structure
    local source_structure_mode "step1_field"
}
else {
    generate byte source_structure = 1

    * Confirmed historical BNR process: the legacy pre-2018 electronic record
    * normally concatenated certificate causes into Part I(a). These records are
    * therefore known concatenated until REDCap is reconstructed from a verified
    * line-preserving source. The small number of pre-2018 records that do not
    * fit that expected flat pattern are marked provenance-uncertain rather than
    * assumed to preserve the original certificate structure.
    replace source_structure = 2 if ///
        dth_year <= 2017 & m1a != "" & m1b == "" & m1c == "" & m1d == ""
    replace source_structure = 3 if ///
        dth_year <= 2017 & source_structure != 2
    replace source_structure = 3 if missing(dth_year)
}

capture assert inlist(source_structure, 1, 2, 3) if !missing(source_structure)
if _rc {
    _bnr_mort_s2_fail 459 "`year4'-`month2'" "`outlog'" ///
        "mort_source_structure contains a value other than 1, 2 or 3."
}

replace source_structure = 3 if missing(source_structure)

label define mortstruct ///
    1 "Certificate lines preserved" ///
    2 "Known BNR-concatenated representation" ///
    3 "Structure/provenance uncertain", replace

label values source_structure mortstruct
label variable source_structure "Cause-of-death source structure/provenance"

generate byte cons_supported = source_structure == 1
label variable cons_supported ///
    "Source structure supports Clear/Conservative classification"


* =============================================================================
* SECTION 7 - DO NOT TOUCH THIS SECTION
* Apply the explicit version-controlled classification rules
* =============================================================================

capture quietly do "$BNR_STATA/mortality/bnr_mort_s2_rules.do"
local rules_rc = _rc

if `rules_rc' {
    _bnr_mort_s2_fail `rules_rc' "`year4'-`month2'" "`outlog'" ///
        "The mortality Step 2 rules file did not complete."
}



* =============================================================================
* SECTION 7A - DO NOT TOUCH THIS SECTION
* Add a plain-language explanation for the final rule ID
*
* These descriptions do not change classification. They make the row-level
* result understandable in the DTA and review CSV without requiring the reader
* to inspect regex code. The complete rule dictionary is also supplied as:
*     bnr_mort_s2_rule_dictionary.csv
* =============================================================================

generate str244 hrt_rule_desc = ""
generate str244 str_rule_desc = ""

replace hrt_rule_desc = "No qualifying BNR-Heart evidence was detected on the certificate." if hrt_rule == "HRT_N000"
replace hrt_rule_desc = "Heart-related context was detected, but it does not by itself support BNR-Heart as the approximate underlying cause." if hrt_rule == "HRT_M001"
replace hrt_rule_desc = "Current direct BNR-Heart wording appears only in Part II." if hrt_rule == "HRT_M002"
replace hrt_rule_desc = "Only historical BNR-Heart evidence is present outside a current Part I Heart sequence." if hrt_rule == "HRT_M003"
replace hrt_rule_desc = "Sudden cardiac death is written above another Part I cause on a certificate whose line order is preserved." if hrt_rule == "HRT_M004"
replace hrt_rule_desc = "Current direct BNR-Heart evidence appears somewhere in Part I, but a simple rule does not resolve it as the approximate underlying cause." if hrt_rule == "HRT_P001"
replace hrt_rule_desc = "The certificate explicitly gives Heart and Stroke as alternatives, for example 'heart attack or stroke'." if hrt_rule == "HRT_P002"
replace hrt_rule_desc = "Current BNR-Heart and BNR-Stroke evidence both appear in Part I." if hrt_rule == "HRT_P003"
replace hrt_rule_desc = "Sudden cardiac death appears alone or as the lowest Part I condition, or the original certificate line order is not preserved." if hrt_rule == "HRT_P005"
replace hrt_rule_desc = "Historical-only Heart evidence appears in Part I with no separate current Heart evidence." if hrt_rule == "HRT_P006"
replace hrt_rule_desc = "Current direct BNR-Heart evidence is on the lowest used Part I line of a reasonably formed multi-line certificate." if hrt_rule == "HRT_L001"
replace hrt_rule_desc = "Explicit AMI appears above a lowest Part I ischaemic/coronary Heart condition." if hrt_rule == "HRT_L010"
replace hrt_rule_desc = "Current BNR-Heart evidence appears above hypertension on the lowest used Part I line." if hrt_rule == "HRT_L011"
replace hrt_rule_desc = "Current BNR-Heart evidence appears above atherosclerosis on the lowest used Part I line." if hrt_rule == "HRT_L012"
replace hrt_rule_desc = "A record that would otherwise be Clear is capped at Likely because the original certificate line structure is concatenated or uncertain." if hrt_rule == "HRT_L020"
replace hrt_rule_desc = "One clean Part I line contains current direct BNR-Heart evidence, with no competing Heart/Stroke ambiguity." if hrt_rule == "HRT_C001"

replace str_rule_desc = "No qualifying BNR-Stroke evidence was detected on the certificate." if str_rule == "STR_N000"
replace str_rule_desc = "Stroke-related context was detected, but it does not by itself support BNR-Stroke as the approximate underlying cause." if str_rule == "STR_M001"
replace str_rule_desc = "Current direct BNR-Stroke wording appears only in Part II." if str_rule == "STR_M002"
replace str_rule_desc = "Only historical or post-stroke evidence is present, with no separate current Stroke evidence." if str_rule == "STR_M003"
replace str_rule_desc = "Current direct BNR-Stroke evidence appears somewhere in Part I, but a simple rule does not resolve it as the approximate underlying cause." if str_rule == "STR_P001"
replace str_rule_desc = "The certificate explicitly gives Heart and Stroke as alternatives, for example 'stroke or heart attack'." if str_rule == "STR_P002"
replace str_rule_desc = "Current BNR-Stroke and BNR-Heart evidence both appear in Part I." if str_rule == "STR_P003"
replace str_rule_desc = "Generic non-traumatic intracranial haemorrhage or bleed appears in Part I without a more specific direct Stroke expression." if str_rule == "STR_P010"
replace str_rule_desc = "Current Stroke is recorded in Part II while the only Part I condition is a simple aspiration pneumonia or pneumonitis." if str_rule == "STR_P011"
replace str_rule_desc = "Current direct BNR-Stroke evidence is on the lowest used Part I line of a reasonably formed multi-line certificate." if str_rule == "STR_L001"
replace str_rule_desc = "Current BNR-Stroke evidence appears above hypertension on the lowest used Part I line." if str_rule == "STR_L010"
replace str_rule_desc = "Current BNR-Stroke evidence appears above atherosclerosis on the lowest used Part I line." if str_rule == "STR_L011"
replace str_rule_desc = "Current Stroke appears immediately above a final simple aspiration pneumonia or pneumonitis line on a certificate with preserved line structure." if str_rule == "STR_L012"
replace str_rule_desc = "A record that would otherwise be Clear is capped at Likely because the original certificate line structure is concatenated or uncertain." if str_rule == "STR_L020"
replace str_rule_desc = "One clean Part I line contains current direct BNR-Stroke evidence, with no competing Heart/Stroke ambiguity." if str_rule == "STR_C001"

label variable hrt_rule_desc "Plain-language explanation of BNR-Heart rule"
label variable str_rule_desc "Plain-language explanation of BNR-Stroke rule"

capture assert hrt_rule_desc != "" if hrt_rule != ""
if _rc {
    _bnr_mort_s2_fail 459 "`year4'-`month2'" "`outlog'" ///
        "One or more BNR-Heart rule IDs do not have a plain-language description."
}

capture assert str_rule_desc != "" if str_rule != ""
if _rc {
    _bnr_mort_s2_fail 459 "`year4'-`month2'" "`outlog'" ///
        "One or more BNR-Stroke rule IDs do not have a plain-language description."
}


* =============================================================================
* SECTION 8 - DO NOT TOUCH THIS SECTION
* Create one focused operational review flag
*
* The development phase used several overlapping diagnostic files. The frozen
* workflow keeps one targeted review CSV. Records enter this queue when the
* certificate contains explicit Heart/Stroke alternatives, both disease
* families in Part I, or a structurally unusual target-bearing Part I sequence.
* =============================================================================

generate byte review_req = 0
generate str80 review_reason = ""

replace review_req = 1 if target_or == 1
replace review_reason = "Explicit BNR-Heart/Stroke alternative wording" ///
    if target_or == 1

replace review_req = 1 if both_dir_p1 == 1 & review_req == 0
replace review_reason = "Direct BNR-Heart and Stroke evidence in Part I" ///
    if both_dir_p1 == 1 & review_reason == ""

replace review_req = 1 if p1_gap == 1 & ///
    (hrt_dir_p1 | str_dir_p1 | hrt_ctx_p1 | str_ctx_p1) & review_req == 0
replace review_reason = "Target evidence with gapped Part I structure" ///
    if p1_gap == 1 & ///
    (hrt_dir_p1 | str_dir_p1 | hrt_ctx_p1 | str_ctx_p1) & ///
    review_reason == ""

replace review_req = 1 if i1a_long == 1 & ///
    (hrt_dir_p1 | str_dir_p1 | hrt_ctx_p1 | str_ctx_p1) & review_req == 0
replace review_reason = "Target evidence in long/concatenated Part I(a)" ///
    if i1a_long == 1 & ///
    (hrt_dir_p1 | str_dir_p1 | hrt_ctx_p1 | str_ctx_p1) & ///
    review_reason == ""

label variable review_req "High-priority Step 2 review flag"
label variable review_reason "Plain-language reason for Step 2 review"


* =============================================================================
* SECTION 9 - DO NOT TOUCH THIS SECTION
* Save the handover-ready private classified dataset
*
* The classifier needs many temporary detector flags while it runs. Those
* helper variables are deliberately NOT saved in the final DTA. The retained
* dataset keeps the source certificate evidence, core structure/provenance,
* final classifications, scenario flags, QA and review information.
*
* The private Step 1 all-deaths dataset remains the source of authorised
* identity/linkage variables for future DCO processing. Selected Step 2
* Heart/Stroke evidence can then be merged back by record_id. Step 2 mortality
* classification supports that assessment but is not itself a DCO eligibility
* gate.
* =============================================================================

local final_vars ///
        record_id ///
        dth_date ///
        dth_year ///
        dth_month ///
        dth_qtr ///
        sex ///
        age ///
        agetxt ///
        parish ///
        qa_dod ///
        qa_pre08 ///
        qa_year ///
        qa_reg ///
        qa_dup ///
        qa_cert ///
        qa_sex ///
        qa_age ///
        qa_any ///
        cod1a ///
        cod1b ///
        cod1c ///
        cod1d ///
        cod2a ///
        cod2b ///
        c1a_cln ///
        c1b_cln ///
        c1c_cln ///
        c1d_cln ///
        c2a_cln ///
        c2b_cln ///
        source_structure ///
        cons_supported ///
        p1_pattern ///
        p1_low ///
        p1_gap ///
        hrt_cls ///
        hrt_rule ///
        hrt_rule_desc ///
        hrt_nos ///
        hrt_basis ///
        hrt_scope ///
        hrt_structure_cap ///
        hrt_cons ///
        hrt_prim ///
        hrt_incl ///
        str_cls ///
        str_rule ///
        str_rule_desc ///
        str_nos ///
        str_basis ///
        str_scope ///
        str_structure_cap ///
        str_cons ///
        str_prim ///
        str_incl ///
        cvd_cls ///
        cvd_structure_cap ///
        cvd_cons ///
        cvd_prim ///
        cvd_incl ///
        cvd_sub_c ///
        cvd_sub_p ///
        cvd_sub_i ///
        review_req ///
        review_reason

capture confirm variable `final_vars'
if _rc {
    _bnr_mort_s2_fail 111 "`year4'-`month2'" "`outlog'" ///
        "A variable required for the final Step 2 classified dataset is missing."
}

preserve
    keep `final_vars'

    order ///
        record_id ///
        dth_date dth_year dth_month dth_qtr ///
        sex age agetxt parish ///
        qa_dod qa_pre08 qa_year qa_reg qa_dup qa_cert qa_sex qa_age qa_any ///
        cod1a cod1b cod1c cod1d cod2a cod2b ///
        c1a_cln c1b_cln c1c_cln c1d_cln c2a_cln c2b_cln ///
        source_structure cons_supported p1_pattern p1_low p1_gap ///
        hrt_cls hrt_rule hrt_rule_desc hrt_nos hrt_basis hrt_scope ///
        hrt_structure_cap hrt_cons hrt_prim hrt_incl ///
        str_cls str_rule str_rule_desc str_nos str_basis str_scope ///
        str_structure_cap str_cons str_prim str_incl ///
        cvd_cls cvd_structure_cap cvd_cons cvd_prim cvd_incl ///
        cvd_sub_c cvd_sub_p cvd_sub_i ///
        review_req review_reason

    label data "BNR private mortality Step 2 classified deaths"

    label define yesno 0 "No" 1 "Yes", replace
    label define mortmonth ///
        1 "January" 2 "February" 3 "March" 4 "April" ///
        5 "May" 6 "June" 7 "July" 8 "August" ///
        9 "September" 10 "October" 11 "November" 12 "December", replace
    label define mortqtr ///
        1 "Quarter 1" 2 "Quarter 2" 3 "Quarter 3" 4 "Quarter 4", replace

    label values ///
        qa_dod qa_pre08 qa_year qa_reg qa_dup qa_cert qa_sex qa_age qa_any ///
        cons_supported p1_gap ///
        hrt_structure_cap hrt_cons hrt_prim hrt_incl ///
        str_structure_cap str_cons str_prim str_incl ///
        cvd_structure_cap cvd_cons cvd_prim cvd_incl ///
        review_req yesno

    label values dth_month mortmonth
    label values dth_qtr mortqtr

label variable record_id "Internal REDCap mortality record ID"
label variable dth_date "Date of death"
label variable dth_year "Year of death"
label variable dth_month "Month of death"
label variable dth_qtr "Calendar quarter of death"
label variable sex "Sex code from source mortality record"
label variable age "Age value from source mortality record"
label variable agetxt "Age-unit code from source mortality record"
label variable parish "Residence parish code from source mortality record"
label variable qa_dod "QA: death date missing or invalid"
label variable qa_pre08 "QA: death date before expected 2008 start"
label variable qa_year "QA: source year disagrees with death date"
label variable qa_reg "QA: registration date missing or invalid"
label variable qa_dup "QA: source possible-duplicate flag"
label variable qa_cert "QA: all cause-of-death fields blank"
label variable qa_sex "QA: sex code outside expected values"
label variable qa_age "QA: age or age-unit missing/invalid"
label variable qa_any "QA: one or more Step 1 flags"
label variable cod1a "Original cause text: Part I(a)"
label variable cod1b "Original cause text: Part I(b)"
label variable cod1c "Original cause text: Part I(c)"
label variable cod1d "Original cause text: Part I(d)"
label variable cod2a "Original cause text: Part II(a)"
label variable cod2b "Original cause text: Part II(b)"
label variable c1a_cln "Cleaned analytical copy: Part I(a)"
label variable c1b_cln "Cleaned analytical copy: Part I(b)"
label variable c1c_cln "Cleaned analytical copy: Part I(c)"
label variable c1d_cln "Cleaned analytical copy: Part I(d)"
label variable c2a_cln "Cleaned analytical copy: Part II(a)"
label variable c2b_cln "Cleaned analytical copy: Part II(b)"
label variable source_structure "Cause-of-death source structure/provenance"
label variable cons_supported "Source structure permits Clear classification"
label variable p1_pattern "Pattern of populated Part I lines"
label variable p1_low "Lowest populated Part I line"
label variable p1_gap "Part I has a gapped/non-standard line pattern"
label variable hrt_cls "BNR-Heart approximate-UCoD evidence class"
label variable hrt_rule "BNR-Heart final rule ID"
label variable hrt_rule_desc "Plain-language explanation of BNR-Heart rule"
label variable hrt_nos "BNR-Heart primary provenance ID"
label variable hrt_basis "BNR-Heart diagnostic evidence basis"
label variable hrt_scope "BNR-Heart surveillance-scope provenance ID"
label variable hrt_structure_cap "Heart Clear reduced because source structure uncertain"
label variable hrt_cons "BNR-Heart Conservative scenario"
label variable hrt_prim "BNR-Heart Primary scenario"
label variable hrt_incl "BNR-Heart Inclusive scenario"
label variable str_cls "BNR-Stroke approximate-UCoD evidence class"
label variable str_rule "BNR-Stroke final rule ID"
label variable str_rule_desc "Plain-language explanation of BNR-Stroke rule"
label variable str_nos "BNR-Stroke primary provenance ID"
label variable str_basis "BNR-Stroke diagnostic evidence basis"
label variable str_scope "BNR-Stroke surveillance-scope provenance ID"
label variable str_structure_cap "Stroke Clear reduced because source structure uncertain"
label variable str_cons "BNR-Stroke Conservative scenario"
label variable str_prim "BNR-Stroke Primary scenario"
label variable str_incl "BNR-Stroke Inclusive scenario"
label variable cvd_cls "Combined BNR-Heart-or-Stroke evidence class"
label variable cvd_structure_cap "Combined Clear reduced because source structure uncertain"
label variable cvd_cons "Combined Conservative scenario"
label variable cvd_prim "Combined Primary scenario"
label variable cvd_incl "Combined Inclusive scenario"
label variable cvd_sub_c "Resolved family: Conservative scenario"
label variable cvd_sub_p "Resolved family: Primary scenario"
label variable cvd_sub_i "Resolved family: Inclusive scenario"
label variable review_req "High-priority Step 2 review flag"
label variable review_reason "Plain-language reason for Step 2 review"

    * Keep existing value labels produced by the classifier:
    *   mortcls    = evidence class
    *   mortstruct = source structure
    *   p1low      = lowest Part I line
    *   cvdsub     = resolved combined surveillance family

    notes drop _all
    notes _dta: title: BNR private mortality Step 2 classified deaths
    notes _dta: workflow: BNR mortality workflow
    notes _dta: step: 2 - classify BNR-Heart / BNR-Stroke approximate underlying cause
    notes _dta: release: `year4'-`month2'
    notes _dta: step2_script_version: 1.0.0
    notes _dta: classifier_definition_version: 0.6.1 - frozen
    notes _dta: source_dataset: `input'
    notes _dta: unit_of_analysis: one eligible death certificate / mortality record
    notes _dta: method_boundary: practical second-best surveillance approximation; NOT formal national ICD-coded UCoD
    notes _dta: evidence_classes: Clear; Likely; Possible; Mention only; No evidence
    notes _dta: scenario_conservative: Clear only
    notes _dta: scenario_primary: Clear + Likely
    notes _dta: scenario_inclusive: Clear + Likely + Possible
    notes _dta: scenario_warning: sensitivity scenarios are not statistical confidence intervals
    notes _dta: heart_scope: BNR-Heart fatal-event surveillance includes explicit AMI and compatible ischaemic/coronary Heart evidence; sudden cardiac death alone is uncertain evidence
    notes _dta: stroke_scope: BNR-Stroke follows the established acute Stroke surveillance family with explicit trauma and excluded haemorrhage safeguards
    notes _dta: source_structure: Clear requires preserved certificate line structure; concatenated/uncertain structure is capped at Likely
    notes _dta: source_structure_mode: `source_structure_mode'
    notes _dta: cause_text: cod1a-cod2b are original Step 1 source text; c1a_cln-c2b_cln are cleaned analytical copies; Step 2 does not overwrite either set
    notes _dta: residency: Barbados residency eligibility is assumed to have been checked by BNR staff during death-certificate review before this post-REDCap step
    notes _dta: confidentiality: private dataset; record_id and certificate text must not enter the public repository
    notes _dta: identity_fields: direct identity/linkage fields such as name, address and NRN are deliberately not retained here; authorised linkage fields remain in private Step 1
    notes _dta: dco_merge: future DCO processing starts with the matching private Step 1 all-deaths dataset and merges selected Step 2 Heart/Stroke evidence by record_id
    notes _dta: dco_boundary: mortality classification supports DCO assessment but does not itself determine whether an unmatched death is a registrable DCO event
    notes _dta: human_review: human adjudication belongs in REDCap; when adjudication fields are implemented, they should be re-extracted rather than maintained in a separate spreadsheet
    notes _dta: rule_dictionary: bnr_mort_s2_rule_dictionary.csv
    notes _dta: provenance_dictionary: bnr_mort_s2_nosology.csv
    notes _dta: variable_dictionary: bnr_mort_s2_variable_dictionary.csv
    notes _dta: methods_note: bnr_mort_s2_methods.md


notes record_id: Internal REDCap ID retained so BNR reviewers can return to the source record and so future private DCO processing can merge selected Step 2 evidence to the matching Step 1 death. Do not publish.
notes sex: Source REDCap code retained unchanged. Step 2 does not alter source sex coding.
notes age: Interpret together with agetxt. Step 2 does not convert age for publication.
notes agetxt: Source age-unit code retained unchanged from Step 1.
notes parish: Source residence-parish code retained for possible downstream stratification. Public use remains subject to disclosure control.
notes source_structure: 1 = original certificate lines preserved; 2 = known BNR-concatenated representation; 3 = structure/provenance uncertain.
notes cons_supported: Equals 1 only when source_structure = 1. This allows the record to retain Clear classification if disease rules also support Clear.
notes hrt_cls: Automated BNR-Heart approximate-UCoD evidence class. This is not formal national ICD-coded UCoD.
notes hrt_rule: Stable row-level analytical provenance. See hrt_rule_desc and bnr_mort_s2_rule_dictionary.csv.
notes hrt_rule_desc: Plain-language meaning of hrt_rule. It explains the final automated rule without requiring the analyst to read regex code.
notes hrt_nos: External/BNR provenance ID where a specific documented principle supports the rule. See bnr_mort_s2_nosology.csv.
notes hrt_basis: Describes the Heart wording that supported classification; it does not by itself determine the evidence class.
notes hrt_scope: NOS017 documents the BNR fatal-event Heart surveillance scope, which includes compatible IHD/coronary evidence beyond literal AMI wording.
notes str_cls: Automated BNR-Stroke approximate-UCoD evidence class. This is not formal national ICD-coded UCoD.
notes str_rule: Stable row-level analytical provenance. See str_rule_desc and bnr_mort_s2_rule_dictionary.csv.
notes str_rule_desc: Plain-language meaning of str_rule. It explains the final automated rule without requiring the analyst to read regex code.
notes str_nos: External/BNR provenance ID where a specific documented principle supports the rule. See bnr_mort_s2_nosology.csv.
notes str_basis: Describes the Stroke wording that supported classification; it does not by itself determine the evidence class.
notes str_scope: NOS018 documents the established BNR-Stroke surveillance-family definition.
notes cvd_cls: Combined endpoint means BNR-Heart OR BNR-Stroke only. It must not be described as all cardiovascular mortality.
notes hrt_cons: Conservative sensitivity scenario = Clear only.
notes hrt_prim: Primary sensitivity scenario = Clear + Likely. This is the default reporting scenario unless a product specification states otherwise.
notes hrt_incl: Inclusive sensitivity scenario = Clear + Likely + Possible.
notes str_cons: Conservative sensitivity scenario = Clear only.
notes str_prim: Primary sensitivity scenario = Clear + Likely. This is the default reporting scenario unless a product specification states otherwise.
notes str_incl: Inclusive sensitivity scenario = Clear + Likely + Possible.
notes p1_low: Numeric code with value label showing the lowest populated Part I certificate line.
notes review_req: Focused operational review flag. A value of 1 does not itself change classification.
notes review_reason: Plain-language reason the record entered the focused review queue.


    compress
    sort record_id

    quietly describe
    local final_var_count = r(k)

    save "`outdta'", replace
restore


* =============================================================================
* SECTION 10 - DO NOT TOUCH THIS SECTION
* Export concise annual evidence-class summary
* =============================================================================

tempfile heart_summary stroke_summary

preserve
    keep dth_year hrt_cls
    rename hrt_cls cls
    generate str12 disease = "BNR-Heart"
    contract dth_year disease cls, freq(n)
    decode cls, generate(evidence_class)
    order dth_year disease cls evidence_class n
    save "`heart_summary'", replace
restore

preserve
    keep dth_year str_cls
    rename str_cls cls
    generate str12 disease = "BNR-Stroke"
    contract dth_year disease cls, freq(n)
    decode cls, generate(evidence_class)
    order dth_year disease cls evidence_class n
    save "`stroke_summary'", replace
restore

preserve
    use "`heart_summary'", clear
    append using "`stroke_summary'"
    sort dth_year disease cls
    export delimited using "`outsummary'", replace
restore


* =============================================================================
* SECTION 11 - DO NOT TOUCH THIS SECTION
* Export the focused private human-review file
*
* The CSV intentionally includes plain-language class/rule descriptions. A BNR
* reviewer should not need to decode a rule ID before understanding why a
* certificate was selected.
* =============================================================================

preserve
    keep if review_req == 1

    keep ///
        record_id dth_date dth_year sex age agetxt ///
        cod1a cod1b cod1c cod1d cod2a cod2b ///
        p1_pattern p1_low p1_gap source_structure cons_supported ///
        hrt_cls hrt_rule hrt_rule_desc hrt_nos hrt_scope hrt_basis ///
        hrt_structure_cap ///
        str_cls str_rule str_rule_desc str_nos str_scope str_basis ///
        str_structure_cap ///
        cvd_cls cvd_sub_p ///
        review_req review_reason

    decode hrt_cls, generate(hrt_class)
    decode str_cls, generate(str_class)
    decode cvd_cls, generate(cvd_class)
    decode source_structure, generate(source_structure_desc)
    decode cvd_sub_p, generate(primary_family)

    order ///
        record_id dth_date dth_year sex age agetxt ///
        cod1a cod1b cod1c cod1d cod2a cod2b ///
        review_reason ///
        hrt_cls hrt_class hrt_rule hrt_rule_desc hrt_nos hrt_scope hrt_basis ///
        str_cls str_class str_rule str_rule_desc str_nos str_scope str_basis ///
        cvd_cls cvd_class cvd_sub_p primary_family ///
        p1_pattern p1_low p1_gap ///
        source_structure source_structure_desc cons_supported ///
        hrt_structure_cap str_structure_cap review_req

    format dth_date %tdCCYY-NN-DD
    sort dth_date record_id

    export delimited using "`outreview'", replace
restore


* =============================================================================
* SECTION 12 - DO NOT TOUCH THIS SECTION
* Export concise source-structure summary
*
* This QA table is retained because source structure directly controls whether
* a death is allowed to remain in the Clear/Conservative class.
* =============================================================================

preserve
    keep dth_year source_structure
    contract dth_year source_structure, freq(n)
    decode source_structure, generate(structure_label)
    order dth_year source_structure structure_label n
    sort dth_year source_structure
    export delimited using "`outstructure'", replace
restore


* =============================================================================
* SECTION 13 - DO NOT TOUCH THIS SECTION
* Calculate run counts and write the YAML receipt
* =============================================================================

quietly count if hrt_cls == 1
local hrt_clear = r(N)

quietly count if inlist(hrt_cls, 1, 2)
local hrt_primary = r(N)

quietly count if inrange(hrt_cls, 1, 3)
local hrt_inclusive = r(N)

quietly count if str_cls == 1
local str_clear = r(N)

quietly count if inlist(str_cls, 1, 2)
local str_primary = r(N)

quietly count if inrange(str_cls, 1, 3)
local str_inclusive = r(N)

quietly count if review_req == 1
local n_review = r(N)

quietly count if cvd_sub_p == 3
local n_unres_p = r(N)

quietly count if inlist(hrt_cls, 1, 2) & hrt_basis == "Explicit AMI"
local n_hrt_ami_basis = r(N)

quietly count if inlist(hrt_cls, 1, 2) & hrt_basis == "IHD/coronary"
local n_hrt_ihd_basis = r(N)

quietly count if inlist(hrt_cls, 1, 2) & hrt_basis == "AMI + IHD/coronary"
local n_hrt_mixed_basis = r(N)

quietly count if hrt_rule == "HRT_L011"
local n_hrt_hyp = r(N)

quietly count if hrt_rule == "HRT_L012"
local n_hrt_ath = r(N)

quietly count if str_rule == "STR_L010"
local n_str_hyp = r(N)

quietly count if str_rule == "STR_L011"
local n_str_ath = r(N)

* Definition-freeze diagnostics retained as regression aids.
quietly count if hrt_rule == "HRT_M004"
local n_hrt_scd_lower = r(N)

quietly count if hrt_rule == "HRT_P006"
local n_hrt_hist_p1 = r(N)

quietly count if str_rule == "STR_P010"
local n_str_intracranial = r(N)

quietly count if str_rule == "STR_P011"
local n_str_p2_asp = r(N)

quietly count if str_rule == "STR_L012"
local n_str_asp_likely = r(N)

quietly count if str_nos == "NOS019" & inrange(str_cls, 1, 3)
local n_str_spec_bleed = r(N)

quietly count if hrt_structure_cap == 1
local n_hrt_structure_cap = r(N)

quietly count if str_structure_cap == 1
local n_str_structure_cap = r(N)

quietly count if cvd_structure_cap == 1
local n_cvd_structure_cap = r(N)

quietly count if source_structure == 1
local n_structure_preserved = r(N)

quietly count if source_structure == 2
local n_structure_concat = r(N)

quietly count if source_structure == 3
local n_structure_uncertain = r(N)

tempname fh
file open `fh' using "`outmanifest'", write text replace

file write `fh' "workflow: mortality" _n
file write `fh' "step: 2" _n
file write `fh' "status: completed" _n
file write `fh' "step2_script_version: 1.0.0" _n
file write `fh' "classifier_definition_version: 0.6.1" _n
file write `fh' "classifier_status: frozen" _n
file write `fh' "release: `year4'-`month2'" _n
file write `fh' "classification_framework: BNR-Heart / BNR-Stroke approximate UCoD; ICD-10-informed practical surveillance approximation" _n
file write `fh' "formal_national_ucod: false" _n
file write `fh' "residency_eligibility: assumed verified by BNR team during death-certificate review before Step 2" _n
file write `fh' "heart_surveillance_scope_provenance: NOS017" _n
file write `fh' "stroke_surveillance_scope_provenance: NOS018" _n
file write `fh' "evidence_classes: [Clear, Likely, Possible, Mention only, No evidence]" _n
file write `fh' "scenario_conservative: Clear" _n
file write `fh' "scenario_primary: Clear + Likely" _n
file write `fh' "scenario_inclusive: Clear + Likely + Possible" _n
file write `fh' "scenario_interpretation: classification sensitivity; not statistical confidence intervals" _n
file write `fh' "dco_linkage: separate future workflow; authorised linkage fields come from matching Step 1 all-deaths data and selected Step 2 evidence is merged by record_id" _n
file write `fh' "input: `input'" _n
file write `fh' "classified_dta: `outdta'" _n
file write `fh' "summary_csv: `outsummary'" _n
file write `fh' "review_csv: `outreview'" _n
file write `fh' "structure_summary_csv: `outstructure'" _n
file write `fh' "rule_dictionary: $BNR_STATA/mortality/bnr_mort_s2_rule_dictionary.csv" _n
file write `fh' "provenance_dictionary: $BNR_STATA/mortality/bnr_mort_s2_nosology.csv" _n
file write `fh' "variable_dictionary: $BNR_STATA/mortality/bnr_mort_s2_variable_dictionary.csv" _n
file write `fh' "methods_note: $BNR_STATA/mortality/bnr_mort_s2_methods.md" _n
file write `fh' "source_structure_mode: `source_structure_mode'" _n
file write `fh' "records: `n_deaths'" _n
file write `fh' "retained_dta_variables: `final_var_count'" _n
file write `fh' "missing_or_bad_death_date: `n_bad_date'" _n
file write `fh' "high_priority_review: `n_review'" _n
file write `fh' "primary_unresolved_heart_stroke: `n_unres_p'" _n
file write `fh' "heart_primary_explicit_ami_basis: `n_hrt_ami_basis'" _n
file write `fh' "heart_primary_ihd_coronary_basis: `n_hrt_ihd_basis'" _n
file write `fh' "heart_primary_mixed_ami_ihd_basis: `n_hrt_mixed_basis'" _n
file write `fh' "heart_promoted_via_hypertension: `n_hrt_hyp'" _n
file write `fh' "heart_promoted_via_atherosclerosis: `n_hrt_ath'" _n
file write `fh' "stroke_promoted_via_hypertension: `n_str_hyp'" _n
file write `fh' "stroke_promoted_via_atherosclerosis: `n_str_ath'" _n
file write `fh' "heart_scd_above_lower_cause_to_mention: `n_hrt_scd_lower'" _n
file write `fh' "heart_historical_part1_possible: `n_hrt_hist_p1'" _n
file write `fh' "stroke_generic_intracranial_possible: `n_str_intracranial'" _n
file write `fh' "stroke_part2_with_aspiration_possible: `n_str_p2_asp'" _n
file write `fh' "stroke_aspiration_sequence_likely: `n_str_asp_likely'" _n
file write `fh' "stroke_specified_bleed_nos019: `n_str_spec_bleed'" _n
file write `fh' "source_structure_preserved: `n_structure_preserved'" _n
file write `fh' "source_structure_known_concatenated: `n_structure_concat'" _n
file write `fh' "source_structure_uncertain: `n_structure_uncertain'" _n
file write `fh' "heart_clear_to_likely_structure_cap: `n_hrt_structure_cap'" _n
file write `fh' "stroke_clear_to_likely_structure_cap: `n_str_structure_cap'" _n
file write `fh' "combined_clear_to_likely_structure_cap: `n_cvd_structure_cap'" _n
file write `fh' "retired_development_outputs: [negative audit CSV, residual Possible CSV]" _n

file close `fh'


* =============================================================================
* SECTION 14 - DO NOT TOUCH THIS SECTION
* Operational run summary
* =============================================================================

noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "MORTALITY STEP 2: OPERATIONAL RUN SUMMARY"
noisily display as result ""
noisily display as text   "  Run status:                 Completed successfully"
noisily display as text   "  Release:                    `year4'-`month2'"
noisily display as text   "  Step 2 script version:      1.0.0"
noisily display as text   "  Classifier definition:      0.6.1 (frozen)"
noisily display as text   "  Deaths classified:          " %12.0fc `n_deaths'
noisily display as text   "  Retained DTA variables:     " %12.0fc `final_var_count'
noisily display as text   "  Missing/bad death date:     " %12.0fc `n_bad_date'
noisily display as result ""
noisily display as text   "  BNR-Heart Conservative:     " %12.0fc `hrt_clear'
noisily display as text   "  BNR-Heart Primary:          " %12.0fc `hrt_primary'
noisily display as text   "  BNR-Heart Inclusive:        " %12.0fc `hrt_inclusive'
noisily display as text   "  BNR-Stroke Conservative:    " %12.0fc `str_clear'
noisily display as text   "  BNR-Stroke Primary:         " %12.0fc `str_primary'
noisily display as text   "  BNR-Stroke Inclusive:       " %12.0fc `str_inclusive'
noisily display as result ""
noisily display as text   "  Primary unresolved subtype: " %12.0fc `n_unres_p'
noisily display as text   "  High-priority review:       " %12.0fc `n_review'
noisily display as result ""
noisily display as text   "  BNR-Heart Primary diagnostic basis:"
noisily display as text   "    Explicit AMI only:        " %12.0fc `n_hrt_ami_basis'
noisily display as text   "    IHD/coronary only:        " %12.0fc `n_hrt_ihd_basis'
noisily display as text   "    AMI + IHD/coronary:       " %12.0fc `n_hrt_mixed_basis'
noisily display as text   "  Provenance-backed causal promotions:"
noisily display as text   "    Heart via hypertension:   " %12.0fc `n_hrt_hyp'
noisily display as text   "    Heart via atherosclerosis:" %12.0fc `n_hrt_ath'
noisily display as text   "    Stroke via hypertension:  " %12.0fc `n_str_hyp'
noisily display as text   "    Stroke via atherosclerosis:" %11.0fc `n_str_ath'
noisily display as result ""
noisily display as text   "  Frozen-definition diagnostics:"
noisily display as text   "    Heart SCD -> Mention:      " %12.0fc `n_hrt_scd_lower'
noisily display as text   "    Heart historical P1:      " %12.0fc `n_hrt_hist_p1'
noisily display as text   "    Stroke generic intracranial:" %10.0fc `n_str_intracranial'
noisily display as text   "    Stroke P2 + aspiration:   " %12.0fc `n_str_p2_asp'
noisily display as text   "    Stroke aspiration -> Likely:" %10.0fc `n_str_asp_likely'
noisily display as text   "    Stroke specified bleed:   " %12.0fc `n_str_spec_bleed'
noisily display as result ""
noisily display as text   "  Source-structure confidence:"
noisily display as text   "    Structure mode:            `source_structure_mode'"
noisily display as text   "    Lines preserved:          " %12.0fc `n_structure_preserved'
noisily display as text   "    Known concatenated:       " %12.0fc `n_structure_concat'
noisily display as text   "    Provenance uncertain:     " %12.0fc `n_structure_uncertain'
noisily display as text   "    Heart Clear -> Likely:    " %12.0fc `n_hrt_structure_cap'
noisily display as text   "    Stroke Clear -> Likely:   " %12.0fc `n_str_structure_cap'
noisily display as text   "    Combined Clear -> Likely: " %12.0fc `n_cvd_structure_cap'
noisily display as result ""
noisily display as text   "  Classified DTA:"
noisily display as text   "    `outdta'"
noisily display as text   "  Evidence summary:"
noisily display as text   "    `outsummary'"
noisily display as text   "  Targeted review:"
noisily display as text   "    `outreview'"
noisily display as text   "  Source-structure summary:"
noisily display as text   "    `outstructure'"
noisily display as text   "  YAML receipt:"
noisily display as text   "    `outmanifest'"
noisily display as result ""
noisily display as text ///
    "  NOTE: This is a practical approximate-UCoD classifier, not formal national coding."
noisily display as text ///
    "  NOTE: Primary = Clear + Likely; Inclusive additionally includes Possible."
noisily display as text ///
    "  NOTE: Combined CVD means BNR-Heart-or-Stroke, not all cardiovascular mortality."
noisily display as text ///
    "  NOTE: Residency eligibility is assumed to have been checked upstream by BNR."
noisily display as text ///
    "  NOTE: Future DCO processing uses Step 1 linkage fields plus selected Step 2 evidence merged by record_id."
noisily display as result "============================================================================="

}

quietly log close mort_class

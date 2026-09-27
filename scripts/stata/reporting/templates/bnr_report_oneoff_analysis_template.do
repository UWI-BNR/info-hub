/*******************************************************************************
DO-FILE: bnr_report_oneoff_analysis_template.do
VERSION: 1.0.0 (27 September 2026)
PURPOSE: Starting template for an analyst-owned BNR one-off CVD report.

COPY THIS FILE before developing a real report. Do not add substantive analysis
to the repository template itself. The report-specific copy creates finished
private inputs for the separate one-off publication workflow; it does not
approve or publish anything.

TEST THE UNCHANGED TEMPLATE:
  do "$BNR_STATA/reporting/templates/bnr_report_oneoff_analysis_template.do" ///
      template_test

REAL REPORT:
  1. Copy and rename this file into a report-specific subfolder.
  2. Complete every REPORT-SPECIFIC section.
  3. Set template_configured, analysis_complete and
     disclosure_review_complete to 1 only when they are genuinely true.
  4. Leave every CONTROLLED section unchanged.
*******************************************************************************/

version 19
clear all
set more off

args template_mode
local template_test = (lower("`template_mode'") == "template_test")
if "`template_mode'" != "" & !`template_test' {
    display as error "The only template argument is template_test."
    exit 198
}

/*******************************************************************************
CONTROLLED SECTION 1 — LOCAL CONFIGURATION
LEAVE UNCHANGED. The report remains private and outside Git.
*******************************************************************************/
if "$BNR_STATA" == "" {
    capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
    if _rc {
        local config_rc = _rc
        display as error "The BNR local path configuration could not be loaded."
        exit `config_rc'
    }
}
foreach required_global in BNR_REPO BNR_STATA BNR_STAGING BNR_PRIVATE_LOGS {
    if "$`required_global'" == "" {
        display as error "Required path is not configured: `required_global'"
        exit 198
    }
}

/*******************************************************************************
REPORT-SPECIFIC SECTION 1 — REPORT IDENTITY AND OUTPUT CONTRACT
EDIT THIS SECTION in the copied report file.

study_id must contain lowercase letters, numbers and underscores and must begin
with a letter. report_version is the publication version passed to Step 1.
analysis_code_version identifies this analytical DO file, not the publication
version. A dataset is optional, but when has_dataset=1 the template always
creates CSV, DTA, YAML and README files as one complete set.
*******************************************************************************/
if `template_test' {
    local template_configured 1
    local study_id "workflow_template_test"
    local report_version 1
    local analysis_code_version "template-test-1.0.0"
    local report_title "BNR one-off analysis template test"
    local report_description "Harmless engineering output used to test the one-off analysis template."
    local report_date "2026-09-27"
    local report_author "BNR workflow test"
    local coverage_text "Harmless engineering test records only."
    local has_dataset 1
    local add_pdf_furniture 0
    local dataset_title "BNR one-off analysis template test data"
    local protected_value_vars "events deaths estimate_pct"
    local extra_forbidden_vars ""
}
else {
    * Replace every placeholder, then change template_configured to 1.
    local template_configured 0
    local study_id "replace_me"
    local report_version 1
    local analysis_code_version "replace_me"
    local report_title "REPLACE WITH THE PUBLIC REPORT TITLE"
    local report_description "REPLACE WITH A SHORT PUBLIC DESCRIPTION"
    local report_date "YYYY-MM-DD"
    local report_author "REPLACE WITH THE REPORT AUTHOR"
    local coverage_text "REPLACE WITH THE DATA COVERAGE"
    local has_dataset 1
    local add_pdf_furniture 1
    local dataset_title "REPLACE WITH THE PUBLIC DATASET TITLE"

    * List every public value field that must be blank on a non-release row.
    local protected_value_vars "replace_me"

    * Add report-specific direct identifiers that must never enter public data.
    local extra_forbidden_vars ""
}

/*******************************************************************************
REPORT-SPECIFIC SECTION 2 — PUBLIC METHODS AND DATASET NOTES
EDIT THIS SECTION. Use plain English. These six fields are mandatory whenever
has_dataset=1. They are written to both the YAML and the labelled Stata file.
Do not use double quotation marks inside these strings.
*******************************************************************************/
if `template_test' {
    local method_inputs "Inputs: values are generated within the harmless engineering test."
    local method_population "Population: two fictional aggregate result rows."
    local method_measures "Measures: fictional event, death and percentage fields used only to test file production."
    local method_uncertainty "Uncertainty: no inferential statistics are produced by this engineering test."
    local method_disclosure "Disclosure control: the second fictional row demonstrates a protected blank result."
    local method_limitations "Limitations: these values are not surveillance data and must never be interpreted substantively."
}
else {
    local method_inputs "REPLACE: identify every frozen input and release."
    local method_population "REPLACE: define the eligible population or cohort."
    local method_measures "REPLACE: define every principal and secondary measure."
    local method_uncertainty "REPLACE: describe confidence intervals, models or other uncertainty."
    local method_disclosure "REPLACE: describe suppression and complementary protection."
    local method_limitations "REPLACE: state important data-quality and interpretive limitations."
}

/*******************************************************************************
CONTROLLED SECTION 2 — IDENTITY, VERSION AND FOLDER CHECKS
LEAVE UNCHANGED.
*******************************************************************************/
if !inlist(`template_configured',0,1) | !inlist(`has_dataset',0,1) | ///
        !inlist(`add_pdf_furniture',0,1) {
    display as error "Template control flags must be coded 0 or 1."
    exit 198
}
if !`template_configured' {
    display as error "This is an unconfigured one-off report template."
    display as error "Copy it, complete the report-specific sections, then set template_configured to 1."
    exit 459
}
if !regexm("`study_id'", "^[a-z][a-z0-9_]*$") {
    display as error "study_id must begin with a lowercase letter and use only lowercase letters, numbers and underscores."
    exit 198
}
local version_num = real("`report_version'")
if missing(`version_num') | `version_num' != floor(`version_num') | ///
        `version_num' < 1 {
    display as error "report_version must be a positive integer."
    exit 198
}
foreach required_text in analysis_code_version report_title report_description ///
        report_date report_author coverage_text {
    local required_value : copy local `required_text'
    if strtrim(`"`required_value'"') == "" | ///
            strpos(upper(`"`required_value'"'),"REPLACE") {
        display as error "Complete the report setting: `required_text'"
        exit 459
    }
    if strpos(`"`required_value'"',char(34)) {
        display as error "Do not use double quotation marks in: `required_text'"
        exit 198
    }
}
local report_date_num = daily("`report_date'","YMD")
if missing(`report_date_num') {
    display as error "report_date must use YYYY-MM-DD."
    exit 198
}
local canonical_date : display %tdCCYY-NN-DD `report_date_num'
if "`canonical_date'" != "`report_date'" {
    display as error "report_date must use YYYY-MM-DD."
    exit 198
}
local report_year = substr("`report_date'",1,4)

if `has_dataset' {
    if strtrim("`dataset_title'") == "" | ///
            strpos(upper("`dataset_title'"),"REPLACE") {
        display as error "Complete dataset_title."
        exit 459
    }
    if strtrim("`protected_value_vars'") == "" | ///
            strpos(upper("`protected_value_vars'"),"REPLACE") {
        display as error "List the public values protected by release_status."
        exit 459
    }
    foreach method_name in inputs population measures uncertainty disclosure limitations {
        local method_local "method_`method_name'"
        local method_text : copy local `method_local'
        if strtrim(`"`method_text'"') == "" | ///
                strpos(upper(`"`method_text'"'),"REPLACE") {
            display as error "Complete the public method text: `method_name'"
            exit 459
        }
        if strpos(`"`method_text'"',char(34)) {
            display as error "Do not use double quotation marks in method text: `method_name'"
            exit 198
        }
    }
}

local input_root "$BNR_STAGING/report_inputs"
local oneoff_root "`input_root'/one-off"
local output_root "`oneoff_root'/`study_id'"
capture mkdir "`input_root'"
capture mkdir "`oneoff_root'"
capture mkdir "`output_root'"
quietly mata: st_local("output_root_exists",strofreal(direxists("`output_root'")))
if "`output_root_exists'" != "1" {
    display as error "Could not create the private report-input folder: `output_root'"
    exit 603
}

local report_body_pdf "`output_root'/bnr_cvd_oneoff_`study_id'_body.pdf"
local report_pdf "`output_root'/bnr_cvd_oneoff_`study_id'.pdf"
local public_csv "`output_root'/`study_id'_metrics.csv"
local public_dta "`output_root'/`study_id'_metrics.dta"
local public_yml "`output_root'/`study_id'_metadata.yml"
local public_readme "`output_root'/`study_id'_readme.md"
local run_log "$BNR_PRIVATE_LOGS/bnr_report_oneoff_analysis_`study_id'.log"
local pdf_helper "$BNR_REPO/scripts/python/stamp_annual_report_pdf.py"
local pdf_python "$BNR_REPO/venv-info-hub/Scripts/python.exe"
local pdf_logo "$BNR_REPO/site/assets/images/uwi-crestonly-20p.png"
local info_hub_web "uwi-bnr.github.io/info-hub/"

capture log close bnr_oneoff_analysis
log using "`run_log'", name(bnr_oneoff_analysis) text replace

/*******************************************************************************
REPORT-SPECIFIC SECTION 3 — INPUT PREPARATION AND ANALYSIS
ADD THE REAL ANALYSIS HERE in the copied report file.

Requirements before this section ends:
  1. Create report_body_pdf with putpdf.
  2. When has_dataset=1, save the final disclosure-controlled public dataset
     to the tempfile public_work.
  3. Set analysis_complete=1 only after analytical review.
  4. Set disclosure_review_complete=1 only after review of the complete proposed
     public payload, including complementary and deductive disclosure.

The harmless branch below exists only for the repository contract test.
*******************************************************************************/
tempfile public_work
local analysis_complete 0
local disclosure_review_complete 0

if `template_test' {
    clear
    input str8 measure int year double events deaths estimate_pct ///
        str26 release_status str20 quality_flag
    "ExampleA" 2025 100 20 20.00 "release" "test_only"
    "ExampleB" 2025   .  .     . "suppress_small_count" ""
    end
    label data "BNR harmless one-off analysis template test data"
    label variable measure "Fictional test measure"
    label variable year "Fictional reporting year"
    label variable events "Fictional event denominator"
    label variable deaths "Fictional outcome numerator"
    label variable estimate_pct "Fictional percentage"
    label variable release_status "Public release decision"
    label variable quality_flag "Optional data-quality caution"
    save "`public_work'", replace

    putpdf clear
    putpdf begin, pagesize(A4) font("Arial",10)
    putpdf paragraph, halign(center)
    putpdf text ("Barbados National Registry"), bold font("Arial",18)
    putpdf paragraph, halign(center)
    putpdf text ("One-off analysis template test"), bold font("Arial",16)
    putpdf paragraph
    putpdf text ("This is a harmless engineering output. It contains no surveillance data.")
    putpdf save "`report_body_pdf'", replace

    local analysis_complete 1
    local disclosure_review_complete 1
}
else {
    /***************************************************************************
    ANALYST INSERTION POINT

    Replace this comment with readable report-specific Stata code. Keep the
    analytical method, quality checks and disclosure decisions visible here.
    Do not calculate bespoke measures in Python or in the publication workflow.

    Suggested internal order:
      A. Load and verify frozen inputs.
      B. Construct the analytical cohort.
      C. Calculate estimates and uncertainty.
      D. Create private aggregate review evidence.
      E. Apply disclosure control to the complete proposed public payload.
      F. Save the public dataset to public_work, when requested.
      G. Compose the report body with putpdf.
      H. Set both completion flags below only after review.
    ***************************************************************************/

    local analysis_complete 0
    local disclosure_review_complete 0
}

if !`analysis_complete' {
    capture log close bnr_oneoff_analysis
    display as error "The report-specific analysis has not been marked complete."
    exit 459
}
if !`disclosure_review_complete' {
    capture log close bnr_oneoff_analysis
    display as error "The complete proposed public payload has not passed disclosure review."
    exit 459
}
capture confirm file "`report_body_pdf'"
if _rc {
    capture log close bnr_oneoff_analysis
    display as error "The report-specific code did not create: `report_body_pdf'"
    exit 601
}

/*******************************************************************************
CONTROLLED SECTION 3 — FINAL PDF
LEAVE UNCHANGED. The helper adds presentation furniture only; it does not read
data or calculate report measures.
*******************************************************************************/
if `add_pdf_furniture' {
    foreach required_file in pdf_python pdf_helper pdf_logo {
        capture confirm file "``required_file''"
        if _rc {
            capture log close bnr_oneoff_analysis
            display as error "Required PDF furniture file is missing: ``required_file''"
            exit 601
        }
    }
    local furniture_command `""`pdf_python'" "`pdf_helper'" --input "`report_body_pdf'" --output "`report_pdf'" --report-title "`report_title'" --report-year "`report_year'" --logo "`pdf_logo'" --skip-first-pages 1 --footer-center "`info_hub_web'" --author "`report_author'""'
    capture noisily shell `furniture_command'
    local furniture_rc = _rc
    if `furniture_rc' {
        capture log close bnr_oneoff_analysis
        display as error "The PDF furniture helper did not complete."
        exit `furniture_rc'
    }
}
else {
    copy "`report_body_pdf'" "`report_pdf'", replace
}

capture confirm file "`report_pdf'"
if _rc {
    capture log close bnr_oneoff_analysis
    display as error "The finished report PDF was not created: `report_pdf'"
    exit 601
}

/*******************************************************************************
CONTROLLED SECTION 4 — PUBLIC CSV AND LABELLED STATA DATASET
LEAVE UNCHANGED. The report-specific code supplies the disclosure-controlled
dataset; this section checks the common release contract and writes both forms.
*******************************************************************************/
if `has_dataset' {
    capture confirm file "`public_work'"
    if _rc {
        capture log close bnr_oneoff_analysis
        display as error "The report-specific code did not save public_work."
        exit 601
    }
    use "`public_work'", clear
    quietly count
    if r(N) < 1 {
        capture log close bnr_oneoff_analysis
        display as error "The proposed public dataset contains no rows."
        exit 459
    }

    capture confirm string variable release_status
    if _rc {
        capture log close bnr_oneoff_analysis
        display as error "The public dataset requires a string release_status variable."
        exit 111
    }
    assert inlist(release_status,"release","suppress_small_count", ///
        "not_release_source_quality")

    local forbidden_vars "natregno national_id fname firstname mname surname lastname dob date_of_birth address phone phone_1 email patient_id person_id record_id redcap_record_id"
    local forbidden_vars = lower(strtrim("`forbidden_vars' `extra_forbidden_vars'"))
    ds
    foreach proposed_var of varlist `r(varlist)' {
        local proposed_var_lower = lower("`proposed_var'")
        if strpos(" `forbidden_vars' "," `proposed_var_lower' ") {
            capture log close bnr_oneoff_analysis
            display as error "Direct identifier found in proposed public data: `proposed_var'"
            exit 459
        }
    }

    foreach protected_var of local protected_value_vars {
        capture confirm variable `protected_var'
        if _rc {
            capture log close bnr_oneoff_analysis
            display as error "Protected public value variable not found: `protected_var'"
            exit 111
        }
        capture confirm numeric variable `protected_var'
        if !_rc {
            assert missing(`protected_var') if release_status != "release"
            assert !missing(`protected_var') if release_status == "release"
        }
        else {
            assert strtrim(`protected_var') == "" if release_status != "release"
            assert strtrim(`protected_var') != "" if release_status == "release"
        }
    }

    local public_data_label : data label
    if strtrim(`"`public_data_label'"') == "" {
        capture log close bnr_oneoff_analysis
        display as error "Give the public dataset a Stata dataset label."
        exit 459
    }
    ds
    local public_vars `r(varlist)'
    local public_var_count : word count `public_vars'
    local public_numeric_cols ""
    local public_string_cols ""
    forvalues variable_number = 1/`public_var_count' {
        local variable_name : word `variable_number' of `public_vars'
        if "`variable_name'" != lower("`variable_name'") {
            capture log close bnr_oneoff_analysis
            display as error "Public variable names must be lowercase: `variable_name'"
            exit 459
        }
        local variable_label : variable label `variable_name'
        local value_label_name : value label `variable_name'
        if strtrim("`value_label_name'") != "" {
            capture log close bnr_oneoff_analysis
            display as error "Public categorical fields must contain reader-facing strings: `variable_name'"
            display as error "Decode this labelled numeric field before saving public_work."
            exit 459
        }
        if strtrim(`"`variable_label'"') == "" {
            capture log close bnr_oneoff_analysis
            display as error "Public variable has no label: `variable_name'"
            exit 459
        }
        if strpos(`"`variable_label'"',char(34)) {
            capture log close bnr_oneoff_analysis
            display as error "Do not use double quotation marks in the label for: `variable_name'"
            exit 198
        }
        local public_name_`variable_number' "`variable_name'"
        local public_label_`variable_number' `"`variable_label'"'
        capture confirm numeric variable `variable_name'
        if !_rc {
            local public_numeric_cols "`public_numeric_cols' `variable_number'"
        }
        else {
            local public_string_cols "`public_string_cols' `variable_number'"
        }
    }
    local public_n = _N
    local public_k = c(k)

    * Export before adding public notes. The CSV round trip is a clean boundary
    * from every label, note and characteristic inherited from source data.
    capture notes drop _all
    export delimited using "`public_csv'", replace
    clear
    import delimited using "`public_csv'", varnames(1) asdouble ///
        numericcols(`public_numeric_cols') ///
        stringcols(`public_string_cols') clear
    assert _N == `public_n'
    assert c(k) == `public_k'
    ds
    assert "`r(varlist)'" == "`public_vars'"

    label data `"`public_data_label'"'
    forvalues variable_number = 1/`public_var_count' {
        local name_local "public_name_`variable_number'"
        local label_local "public_label_`variable_number'"
        local variable_name : copy local `name_local'
        local variable_label : copy local `label_local'
        label variable `variable_name' `"`variable_label'"'
        notes `variable_name': `variable_label'
    }
    notes _dta: `method_inputs'
    notes _dta: `method_population'
    notes _dta: `method_measures'
    notes _dta: `method_uncertainty'
    notes _dta: `method_disclosure'
    notes _dta: `method_limitations'
    save "`public_dta'", replace
}

/*******************************************************************************
CONTROLLED SECTION 5 — STRUCTURED YAML AND READER README
LEAVE UNCHANGED. New reports use YAML only; this template has no legacy TXT
metadata route.
*******************************************************************************/
if `has_dataset' {
    tempname data_yml
    file open `data_yml' using "`public_yml'", write text replace
    file write `data_yml' "schema: bnr_dataset_metadata_v1" _n
    file write `data_yml' "dataset_id: `study_id'" _n
    file write `data_yml' "release_id: bnr_cvd_oneoff_`study_id'_v`version_num'" _n
    file write `data_yml' "title: |-" _n
    file write `data_yml' "  `dataset_title'" _n
    file write `data_yml' "release_version: v`version_num'" _n
    file write `data_yml' "analysis_code_version: `analysis_code_version'" _n
    file write `data_yml' "publisher: Barbados National Registry" _n
    file write `data_yml' "coverage: |-" _n
    file write `data_yml' "  `coverage_text'" _n
    file write `data_yml' "formats:" _n
    file write `data_yml' "  - CSV" _n
    file write `data_yml' "  - Stata DTA" _n
    file write `data_yml' "files:" _n
    file write `data_yml' "  - path: data/`study_id'_metrics.csv" _n
    file write `data_yml' "    role: portable_tabular_data" _n
    file write `data_yml' "  - path: data/`study_id'_metrics.dta" _n
    file write `data_yml' "    role: labelled_stata_data" _n
    file write `data_yml' "  - path: metadata/`study_id'_metadata.yml" _n
    file write `data_yml' "    role: formal_dataset_metadata" _n
    file write `data_yml' "  - path: metadata/README.md" _n
    file write `data_yml' "    role: reader_guide" _n
    file write `data_yml' "methods:" _n
    foreach method_name in inputs population measures uncertainty disclosure limitations {
        local method_local "method_`method_name'"
        local method_text : copy local `method_local'
        file write `data_yml' "  `method_name': |-" _n
        file write `data_yml' "    `method_text'" _n
    }
    file write `data_yml' "variables:" _n
    forvalues variable_number = 1/`public_var_count' {
        local name_local "public_name_`variable_number'"
        local label_local "public_label_`variable_number'"
        local variable_name : copy local `name_local'
        local variable_label : copy local `label_local'
        capture confirm numeric variable `variable_name'
        local variable_type "string"
        if !_rc local variable_type "number"
        file write `data_yml' "  - name: `variable_name'" _n
        file write `data_yml' "    type: `variable_type'" _n
        file write `data_yml' "    description: |-" _n
        file write `data_yml' "      `variable_label'" _n
    }
    file close `data_yml'

    tempname data_readme
    file open `data_readme' using "`public_readme'", write text replace
    file write `data_readme' "# `dataset_title'" _n _n
    file write `data_readme' "This dataset accompanies the BNR report *`report_title'*." _n _n
    file write `data_readme' "## Files" _n _n
    file write `data_readme' "- data/`study_id'_metrics.csv: portable data file." _n
    file write `data_readme' "- data/`study_id'_metrics.dta: the same data with Stata labels and notes." _n
    file write `data_readme' "- metadata/`study_id'_metadata.yml: structured metadata and data dictionary." _n _n
    file write `data_readme' "## Coverage" _n _n
    file write `data_readme' "`coverage_text'" _n _n
    file write `data_readme' "## Reading protected values" _n _n
    file write `data_readme' "Rows may remain in the dataset when values cannot be shown. Use release_status to distinguish released results, small-count protection and source-quality exclusions. Protected blanks are not zero." _n _n
    file write `data_readme' "## Methods" _n _n
    file write `data_readme' "See the accompanying YAML metadata and the report methods section for the definitions, uncertainty, disclosure control and limitations specific to this analysis." _n
    file close `data_readme'
}

/*******************************************************************************
CONTROLLED SECTION 6 — FINAL FILE CHECKS AND STEP 1 HANDOFF
LEAVE UNCHANGED. This section verifies inputs for Step 1 but never runs Step 1.
*******************************************************************************/
local required_outputs "report_pdf"
if `has_dataset' {
    local required_outputs "`required_outputs' public_csv public_dta public_yml public_readme"
}
foreach required_output of local required_outputs {
    capture confirm file "``required_output''"
    if _rc {
        capture log close bnr_oneoff_analysis
        display as error "Required one-off report output is missing: ``required_output''"
        exit 601
    }
    quietly checksum "``required_output''"
    if r(filelen) < 1 {
        capture log close bnr_oneoff_analysis
        display as error "Required one-off report output is empty: ``required_output''"
        exit 459
    }
}

quietly {
noisily display as result ""
noisily display as result "============================================================================="
noisily display as result "ONE-OFF CVD REPORT ANALYSIS: FINISHED INPUT SUMMARY"
noisily display as text   "  Run status:              Finished private inputs created"
noisily display as text   "  Study ID:                `study_id'"
noisily display as text   "  Report version:          v`version_num'"
noisily display as text   "  Analysis code version:   `analysis_code_version'"
noisily display as text  `"  Finished PDF:             `report_pdf'"'
if `has_dataset' {
    noisily display as text `"  Public CSV:               `public_csv'"'
    noisily display as text `"  Public DTA:               `public_dta'"'
    noisily display as text `"  Dataset metadata:         `public_yml'"'
    noisily display as text `"  Dataset README:           `public_readme'"'
}
noisily display as text   "  Approval/publication:    Not performed"
noisily display as text   ""
noisily display as text   "Run Step 1 separately after reviewing these finished files:"
noisily display as text  `"do "$BNR_STATA/reporting/bnr_report_oneoff_s1_prepare.do" ///"'
noisily display as text  `"    `study_id' `version_num' "`report_pdf'" ///"'
noisily display as text  `"    "`report_title'" ///"'
if `has_dataset' {
    noisily display as text `"    "`report_description'" `report_date' "" ///"'
    noisily display as text `"    "`public_csv'" "`public_dta'" ///"'
    noisily display as text `"    "`public_yml'" "`public_readme'""'
}
else {
    noisily display as text `"    "`report_description'" `report_date'"'
}
noisily display as result "============================================================================="
}
capture log close bnr_oneoff_analysis

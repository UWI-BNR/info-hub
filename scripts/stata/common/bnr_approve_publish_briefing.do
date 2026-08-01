/*
* =====================================================================
 DO-FILE:     bnr_approve_publish_briefing.do
 PROJECT:     BNR info-hub
 PURPOSE:     Approve and publish one reviewed occasional briefing

 VERSION:     v1.0

 USAGE:
   Run only after the analyst has reviewed the complete private staging
   package and completed review/disclosure_review.txt.

   do "$BNR_STATA/common/bnr_approve_publish_briefing.do" ///
       "cvd_cases_2023_v2" ///
       "Full name" ///
       "Registry Statistician"

 IMPORTANT:
   This helper does not calculate results and does not make disclosure
   decisions. It checks that the required human review has been completed,
   records one combined approval, promotes approved files to outputs/public/,
   creates the ZIP, and rebuilds the website mirror.

   The review/ folder remains private and is not copied into the public package.
* =====================================================================
*/


* ==============================================================================
* DO NOT TOUCH: READ THE REQUIRED ARGUMENTS
* ==============================================================================

args briefing_id approved_by approved_role

if "`briefing_id'" == "" {
    display as error "No briefing_id supplied."
    exit 198
}

if "`approved_by'" == "" {
    display as error "No approver name supplied."
    exit 198
}

if "`approved_role'" == "" {
    display as error "No approver role supplied."
    exit 198
}


* ==============================================================================
* DO NOT TOUCH: CHECK REQUIRED PROJECT PATHS
* ==============================================================================

foreach required_global in BNR_STAGING BNR_PUBLIC BNR_STATA BNR_REPO {

    if "$`required_global'" == "" {
        display as error "Required global `required_global' is not defined."
        display as error "Run bnr_paths_LOCAL.do before this helper."
        exit 198
    }
}


* ==============================================================================
* DO NOT TOUCH: DEFINE STANDARD PATHS
* ==============================================================================

local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures  "`stagingbriefing'/figures"
local stagingmetadata "`stagingbriefing'/metadata"
local stagingworkbook "`stagingbriefing'/workbook"
local stagingreview   "`stagingbriefing'/review"

local control_file "`stagingmetadata'/release_control.yml"
local review_file  "`stagingreview'/disclosure_review.txt"
local flags_file   "`stagingreview'/disclosure_flags.csv"

local publicbriefings "$BNR_PUBLIC/briefings"
local publicbriefing  "`publicbriefings'/`briefing_id'"
local publiczip       "`publicbriefing'/bnr_`briefing_id'.zip"
local temporaryzip    "`publicbriefings'/bnr_`briefing_id'_building.zip"
local sitebriefings   "$BNR_REPO/site/downloads/files/briefings"
local sitebriefing    "`sitebriefings'/`briefing_id'"


* ==============================================================================
* DO NOT TOUCH: CONFIRM THE PRIVATE STAGING PACKAGE
* ==============================================================================

quietly mata: st_local("staging_exists", strofreal(direxists("`stagingbriefing'")))

if "`staging_exists'" != "1" {
    display as error "Private staging package not found:"
    display as error "  `stagingbriefing'"
    exit 601
}

foreach required_file in ///
    "`control_file'" ///
    "`review_file'" ///
    "`flags_file'" ///
    "`stagingbriefing'/downloads.yml" ///
    "`stagingbriefing'/readme.txt" {

    capture confirm file "`required_file'"

    if _rc {
        display as error "Required staging file not found:"
        display as error "  `required_file'"
        exit 601
    }
}


* ==============================================================================
* DO NOT TOUCH: READ THE SMALL RELEASE-CONTROL CONTRACT
* ==============================================================================
* Only the simple one-line fields required for publication are read here.

tempname control
file open `control' using "`control_file'", read text

local released_datasets ""
local released_figures  ""
local create_workbook   ""
local create_zip        ""
local workbook_file     ""
local control_briefing_id ""

file read `control' line

while r(eof) == 0 {

    local trimmed = strtrim(`"`line'"')
    local colon_pos = strpos(`"`trimmed'"', ":")

    if `colon_pos' > 0 {

        local key = strtrim(substr(`"`trimmed'"', 1, `colon_pos' - 1))
        local value = strtrim(substr(`"`trimmed'"', `colon_pos' + 1, .))

        if "`key'" == "briefing_id" {
            local control_briefing_id "`value'"
        }
        if "`key'" == "released_datasets" {
            local released_datasets "`value'"
        }
        if "`key'" == "released_figures" {
            local released_figures "`value'"
        }
        if "`key'" == "create_workbook" {
            local create_workbook "`value'"
        }
        if "`key'" == "create_zip" {
            local create_zip "`value'"
        }
        if "`key'" == "workbook_file" {
            local workbook_file "`value'"
        }
    }

    file read `control' line
}

file close `control'

if "`control_briefing_id'" != "`briefing_id'" {
    display as error "Package identity mismatch."
    display as error "Requested: `briefing_id'"
    display as error "Control:   `control_briefing_id'"
    exit 459
}

if "`released_datasets'" == "" {
    display as error "No released datasets are declared."
    exit 198
}

if "`released_figures'" == "" {
    display as error "No released figures are declared."
    exit 198
}

if !inlist("`create_workbook'", "0", "1") {
    display as error "Invalid create_workbook value: `create_workbook'"
    exit 198
}

if !inlist("`create_zip'", "0", "1") {
    display as error "Invalid create_zip value: `create_zip'"
    exit 198
}


* ==============================================================================
* DO NOT TOUCH: CONFIRM EVERY DECLARED PUBLIC ARTEFACT
* ==============================================================================

foreach dataset_id of local released_datasets {

    foreach extension in dta csv {

        capture confirm file "`stagingdatasets'/`dataset_id'.`extension'"

        if _rc {
            display as error "Declared dataset file is missing:"
            display as error "  `stagingdatasets'/`dataset_id'.`extension'"
            exit 601
        }
    }

    capture confirm file "`stagingmetadata'/`dataset_id'.yml"

    if _rc {
        display as error "Declared dataset metadata is missing:"
        display as error "  `stagingmetadata'/`dataset_id'.yml"
        exit 601
    }
}

foreach figure_id of local released_figures {

    capture confirm file "`stagingfigures'/`figure_id'.png"

    if _rc {
        display as error "Declared figure is missing:"
        display as error "  `stagingfigures'/`figure_id'.png"
        exit 601
    }
}

if "`create_workbook'" == "1" {

    capture confirm file "`stagingworkbook'/`workbook_file'"

    if _rc {
        display as error "Required workbook is missing:"
        display as error "  `stagingworkbook'/`workbook_file'"
        exit 601
    }
}


* ==============================================================================
* DO NOT TOUCH: STOP IF AN UNDECLARED DATASET OR FIGURE IS PRESENT
* ==============================================================================

local actual_dta : dir "`stagingdatasets'" files "*.dta"

foreach filename of local actual_dta {

    local stem = substr("`filename'", 1, length("`filename'") - 4)

    if strpos(" `released_datasets' ", " `stem' ") == 0 {
        display as error "Undeclared DTA file found in the staging package:"
        display as error "  `filename'"
        exit 459
    }
}

local actual_csv : dir "`stagingdatasets'" files "*.csv"

foreach filename of local actual_csv {

    local stem = substr("`filename'", 1, length("`filename'") - 4)

    if strpos(" `released_datasets' ", " `stem' ") == 0 {
        display as error "Undeclared CSV file found in the staging package:"
        display as error "  `filename'"
        exit 459
    }
}

local actual_png : dir "`stagingfigures'" files "*.png"

foreach filename of local actual_png {

    local stem = substr("`filename'", 1, length("`filename'") - 4)

    if strpos(" `released_figures' ", " `stem' ") == 0 {
        display as error "Undeclared PNG file found in the staging package:"
        display as error "  `filename'"
        exit 459
    }
}


* ==============================================================================
* DO NOT TOUCH: CHECK PUBLIC DATASETS FOR PROHIBITED VARIABLES
* ==============================================================================
* This is a final accidental-inclusion check. It does not replace the analyst's
* wider disclosure assessment.

preserve

foreach dataset_id of local released_datasets {

    use "`stagingdatasets'/`dataset_id'.dta", clear

    foreach prohibited_variable in ///
        eid rid pid name firstname surname dob address addr telephone phone email {

        capture confirm variable `prohibited_variable'

        if !_rc {
            display as error "Prohibited variable found in a public dataset:"
            display as error "  Dataset:  `dataset_id'"
            display as error "  Variable: `prohibited_variable'"
            restore
            exit 459
        }
    }
}

restore


* ==============================================================================
* DO NOT TOUCH: CONFIRM THE HUMAN DISCLOSURE REVIEW
* ==============================================================================

local package_matches 0
local datasets_reviewed 0
local figures_reviewed 0
local narrative_reviewed 0
local complementary_considered 0
local differencing_considered 0
local external_considered 0
local identifiers_checked 0
local flags_reviewed 0
local status_approved 0

local reviewed_by ""
local review_date ""
local flags_action ""
local review_comments ""

tempname review
file open `review' using "`review_file'", read text
file read `review' line

while r(eof) == 0 {

    local trimmed = strtrim(`"`line'"')

    if "`trimmed'" == "package_id: `briefing_id'" {
        local package_matches 1
    }
    if "`trimmed'" == "datasets_reviewed: YES" {
        local datasets_reviewed 1
    }
    if "`trimmed'" == "figures_reviewed: YES" {
        local figures_reviewed 1
    }
    if "`trimmed'" == "narrative_reviewed: YES" {
        local narrative_reviewed 1
    }
    if "`trimmed'" == "complementary_disclosure_considered: YES" {
        local complementary_considered 1
    }
    if "`trimmed'" == "differencing_considered: YES" {
        local differencing_considered 1
    }
    if "`trimmed'" == "external_information_considered: YES" {
        local external_considered 1
    }
    if "`trimmed'" == "identifiers_checked: YES" {
        local identifiers_checked 1
    }
    if "`trimmed'" == "automated_flags_reviewed: YES" {
        local flags_reviewed 1
    }
    if "`trimmed'" == "review_status: APPROVE FOR PUBLICATION" {
        local status_approved 1
    }

    local colon_pos = strpos(`"`trimmed'"', ":")

    if `colon_pos' > 0 {

        local key = strtrim(substr(`"`trimmed'"', 1, `colon_pos' - 1))
        local value = strtrim(substr(`"`trimmed'"', `colon_pos' + 1, .))

        if "`key'" == "reviewed_by" {
            local reviewed_by "`value'"
        }
        if "`key'" == "review_date" {
            local review_date "`value'"
        }
        if "`key'" == "automated_flags_action" {
            local flags_action "`value'"
        }
        if "`key'" == "review_comments" {
            local review_comments "`value'"
        }
    }

    file read `review' line
}

file close `review'

if `package_matches' == 0 {
    display as error "Disclosure review does not match package `briefing_id'."
    exit 459
}

foreach review_check in ///
    datasets_reviewed ///
    figures_reviewed ///
    narrative_reviewed ///
    complementary_considered ///
    differencing_considered ///
    external_considered ///
    identifiers_checked ///
    flags_reviewed ///
    status_approved {

    if ``review_check'' == 0 {
        display as error "Disclosure review is incomplete: `review_check'"
        display as error "Complete:"
        display as error "  `review_file'"
        exit 459
    }
}

foreach review_text in reviewed_by review_date flags_action review_comments {

    if "``review_text''" == "" {
        display as error "Disclosure review field is blank: `review_text'"
        exit 459
    }
}


* ==============================================================================
* DO NOT TOUCH: WRITE THE SINGLE COMBINED APPROVAL RECORD
* ==============================================================================

local approved_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local approval_file "`stagingbriefing'/approval.yml"

tempname approval
file open `approval' using "`approval_file'", write replace text

file write `approval' "status: approved" _n
file write `approval' "approved_by: `approved_by'" _n
file write `approval' "approved_role: `approved_role'" _n
file write `approval' "approved_date: `approved_date'" _n
file write `approval' "package_id: `briefing_id'" _n
file write `approval' "disclosure_reviewed_by: `reviewed_by'" _n
file write `approval' "disclosure_review_date: `review_date'" _n

file close `approval'


* ==============================================================================
* DO NOT TOUCH: COPY THE APPROVED PUBLIC ARTEFACTS
* ==============================================================================
* The private review folder is deliberately excluded.

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "New-Item -ItemType Directory -Path '`publicbriefings'' -Force | Out-Null; if (Test-Path -LiteralPath '`publicbriefing'') { Remove-Item -LiteralPath '`publicbriefing'' -Recurse -Force }; New-Item -ItemType Directory -Path '`publicbriefing'' -Force | Out-Null; Copy-Item -LiteralPath '`stagingdatasets'' -Destination '`publicbriefing'' -Recurse -Force; Copy-Item -LiteralPath '`stagingfigures'' -Destination '`publicbriefing'' -Recurse -Force; Copy-Item -LiteralPath '`stagingmetadata'' -Destination '`publicbriefing'' -Recurse -Force; if (Test-Path -LiteralPath '`stagingworkbook'') { Copy-Item -LiteralPath '`stagingworkbook'' -Destination '`publicbriefing'' -Recurse -Force }; Copy-Item -LiteralPath '`stagingbriefing'/downloads.yml' -Destination '`publicbriefing'' -Force; Copy-Item -LiteralPath '`stagingbriefing'/readme.txt' -Destination '`publicbriefing'' -Force; Copy-Item -LiteralPath '`approval_file'' -Destination '`publicbriefing'' -Force"

quietly mata: st_local("public_exists", strofreal(direxists("`publicbriefing'")))

if "`public_exists'" != "1" {
    display as error "Approved public package was not created:"
    display as error "  `publicbriefing'"
    exit 603
}


* ==============================================================================
* DO NOT TOUCH: CREATE THE PUBLIC ZIP PACKAGE
* ==============================================================================

if "`create_zip'" == "1" {

    cap erase "`temporaryzip'"
    cap erase "`publiczip'"

    shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
        "Compress-Archive -LiteralPath '`publicbriefing'' -DestinationPath '`temporaryzip'' -Force; Move-Item -LiteralPath '`temporaryzip'' -Destination '`publiczip'' -Force"

    capture confirm file "`publiczip'"

    if _rc {
        display as error "Approved ZIP package was not created:"
        display as error "  `publiczip'"
        exit 603
    }
}


* ==============================================================================
* DO NOT TOUCH: REBUILD THE DISPOSABLE WEBSITE MIRROR
* ==============================================================================

shell powershell -NoProfile -ExecutionPolicy Bypass -Command ///
    "New-Item -ItemType Directory -Path '`sitebriefings'' -Force | Out-Null; if (Test-Path -LiteralPath '`sitebriefing'') { Remove-Item -LiteralPath '`sitebriefing'' -Recurse -Force }; Copy-Item -LiteralPath '`publicbriefing'' -Destination '`sitebriefings'' -Recurse -Force"

quietly mata: st_local("site_exists", strofreal(direxists("`sitebriefing'")))

if "`site_exists'" != "1" {
    display as error "Website mirror was not created:"
    display as error "  `sitebriefing'"
    exit 603
}


* ==============================================================================
* DO NOT TOUCH: FINAL CONFIRMATION
* ==============================================================================

display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR OCCASIONAL BRIEFING APPROVED AND PUBLISHED" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:    `briefing_id'" _n ///
    as result "  Approved by:    `approved_by'" _n ///
    as result "  Approved role:  `approved_role'" _n ///
    as result "  Public package: `publicbriefing'" _n ///
    as result "  ZIP package:    `publiczip'" _n ///
    as text   "  Private review: retained in staging only" _n ///
    as text "------------------------------------------------------------" _n

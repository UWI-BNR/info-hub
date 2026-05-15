/*
* =====================================================================
 DO-FILE:     bnrcvd-2023-forensics2.do
 PROJECT:     BNR info-hub
 PURPOSE:     Create a supporting refit/process-audit figure showing
              the duplicated CVD dataset file structure

 AUTHOR:      Ian R Hambleton
 VERSION:     v1.1

 NOTES:
   This DO file is the analyst-owned build file for a single graphical
   supporting artefact.

   It follows the same release pattern as the four narrative CVD
   briefings, but its output_type is different:

     output_type = supporting_artefact

   The design principle is:

     One briefing or output package = one analyst-owned DO file.

   This file should contain all artefact-specific analytical work:
     - loading the file inventory used for the process audit;
     - deriving the graphical summary;
     - exporting the PNG figure into the staging folder;
     - writing a small release-control file for the standard publisher.

   The repeated release machinery is intentionally NOT written out in
   full here. The final section calls a shared helper DO file which will
   create package metadata, README, downloads.yml, public copy, and the
   website mirror.

   This supporting artefact does not create public datasets, an Excel
   workbook, or a ZIP package. It is served by the website from the same
   standard public artefact pathway used by briefings.

 OUTPUT TYPE:
   output_type = supporting_artefact

   The physical release path still uses the historical briefings/ folder
   name. In this system, that folder should be understood as the standard
   pathway for versioned public output packages created by Stata jobs.
   Most are narrative briefings, but the same pathway may also hold
   supporting artefacts, tabulations, or monitoring outputs. The specific
   type is recorded in output_type.

 DO FILE LOCATION:
   This file may remain in:

     scripts/stata/refit/

   That location reflects the purpose of the code: refit/process audit
   evidence. The output location is separate and remains the standard
   website-served output package pathway:

     outputs/staging/briefings/{briefing_id}/
     outputs/public/briefings/{briefing_id}/
     site/downloads/files/briefings/{briefing_id}/

 OUTPUT BUNDLE:
  STAGING: outputs/staging/briefings/cvd_forensics_2025_v1/
  PUBLIC:  outputs/public/briefings/cvd_forensics_2025_v1/
  SITE:    site/downloads/files/briefings/cvd_forensics_2025_v1/

  Created directly by this DO file:

  figures/
    cvd_file_instances.png

  metadata/
    release_control.yml

  Created later by the standard publish helper:

  readme.txt
  downloads.yml

  metadata/
    briefing.yml

  Not created for this supporting artefact:
    datasets/
    workbook/
    ZIP package
* =====================================================================
*/


* ==============================================================================
* DO NOT TOUCH: INITIALIZE DO FILE
* ==============================================================================
* Keep the top of every BNR output DO file predictable. This improves
* handover, makes logs easier to interpret, and reduces accidental state
* carried over from an earlier Stata session.

version 19
clear all
set more off


* ==============================================================================
* DO NOT TOUCH: SET LOCAL PROJECT PATH AND LOAD SHARED SETTINGS
* ==============================================================================
* localpath is the only machine-specific path in this DO file.
* All other important folders are defined in the shared path/config files.
*
* bnr_paths_LOCAL.do:
*   Defines local repository/output paths such as BNR_STAGING,
*   BNR_PUBLIC, BNR_PRIVATE_LOGS, and BNR_PRIVATE_WORK.
*
* bnrcvd_globals.do:
*   Defines shared CVD display settings and other CVD-specific constants.

local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"
do "`localpath'/scripts/stata/common/bnrcvd_globals.do"


* ==============================================================================
* EDIT BLOCK A: OUTPUT PACKAGE SETTINGS
* ==============================================================================
* For a new output package, start here.
*
* Future users should usually change this block and the analysis section only.
* The standard folder setup, release-control writer, and publish helper should
* remain unchanged unless the BNR release standard itself changes.
*
* output_type distinguishes different kinds of public output package while
* preserving the existing briefings/ physical pathway:
*
*   briefing              = narrative public analytical briefing
*   supporting_artefact   = supporting figure/table/file used by the site
*   tabulation            = routine table set
*   monitoring            = QC/process/performance output
*
* This forensics output is a supporting artefact, not a narrative briefing.

local target_year       2025
local baseline_start    .
local baseline_end      .

local briefing_id       "cvd_forensics_2025_v1"
local briefing_name     "cvd_forensics_2025"
local output_type       "supporting_artefact"

local briefing_title    "CVD dataset file-structure audit figure"
local briefing_short    "Dataset file-structure audit"

* This can be filled in later if the artefact is tied to one specific QMD page.
* Leaving it blank is allowed by the standard publisher.
local briefing_page     ""

local surveillance_area "CVD"
local domain            "cvd"
local registry          "BNR-CVD"
local geography         "Barbados"
local period            "2025"

local briefing_description ///
    "Supporting process artefact showing duplicate CVD dataset file instances identified during the BNR refit."

local briefing_limitations ///
    "This is a process-audit artefact, not a statistical surveillance output."

local data_note ///
    "Figure-only supporting artefact based on an inventory of Stata DTA files in the historical DM folder."

local rights_note ///
    "Public release. Cite the Barbados National Registry when reusing."

local contact_note ///
    "Barbados National Registry."

local analysis_script ///
    "scripts/stata/refit/bnrcvd-2023-forensics2.do"


* ------------------------------------------------------------------------------
* Released artefact names
* ------------------------------------------------------------------------------
* output1 is retained because it is used in the analytical section below.
*
* This supporting artefact creates one PNG figure and no public datasets.

local output1           "cvd_file_instances"

local released_datasets ""
local released_figures  "`output1'"


* ------------------------------------------------------------------------------
* Workbook and download settings
* ------------------------------------------------------------------------------
* This supporting artefact is served by direct page linkage and does not need
* its own Excel workbook or ZIP package.
*
* The standard publisher will still create:
*   - metadata/briefing.yml
*   - readme.txt
*   - downloads.yml with downloads: []
*   - public copy
*   - website mirror
*
* Because list_zip = 0, this artefact will not be added to the central
* downloads page.

local create_workbook   0
local create_zip        0
local list_zip          0

local zip_title ///
    "Supporting process artefact package"

local zip_description ///
    "Supporting process artefact created during the BNR refit."


* ==============================================================================
* DO NOT TOUCH: OPEN PRIVATE LOG
* ==============================================================================
* Logs are written outside the public release bundle. They are part of the
* private audit trail for the build and should not be published.

cap log close
log using "$BNR_PRIVATE_LOGS/`briefing_name'", replace


* ==============================================================================
* DO NOT TOUCH: STANDARD STAGING FOLDER SETUP
* ==============================================================================
* The staging folder is the build area for this briefing/output package.
*
* The public folder is NOT created here. Public release and website mirroring
* are handled by the shared publish helper at the end of the DO file.
*
* The physical folder name remains briefings/ for continuity with the current
* BNR publication pathway. The specific kind of output is recorded using the
* output_type local above.

local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures  "`stagingbriefing'/figures"
local stagingworkbook "`stagingbriefing'/workbook"
local stagingmetadata "`stagingbriefing'/metadata"

cap mkdir "$BNR_STAGING/briefings"
cap mkdir "`stagingbriefing'"
cap mkdir "`stagingdatasets'"
cap mkdir "`stagingfigures'"
cap mkdir "`stagingworkbook'"
cap mkdir "`stagingmetadata'"


display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD supporting artefact build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:     `briefing_id'" _n ///
    as result "  Output type:     `output_type'" _n ///
    as result "  Period:          `period'" _n ///
    as result "  Staging bundle:  `stagingbriefing'" _n ///
    as text "------------------------------------------------------------" _n



** ==============================================================================
** EDIT BLOCK B: SUPPORTING-ARTEFACT-SPECIFIC ANALYSIS
** ==============================================================================
* For a new supporting artefact, adapt the analytical section below as needed.
* Keep the release-control and publish sections at the end unchanged unless
* the standard BNR release process itself changes.
*
* This analysis creates a single PNG figure:
*
*   figures/cvd_file_instances.png
*
* It does not create public datasets. The release-control settings above tell
* the standard publisher to skip dataset-level YAML, workbook creation, ZIP
* creation, and central downloads listing.
** ==============================================================================

** Load dataset
** This represents the total *.dta files in the DM/ folder
** Listing created using "Eveything" software
** Search "*.dta" in "C:\yasuki\Sync\DM"
** Full pathnames then copied to Excel spreadsheet

** We now explore:
**      (a) How many files
**      (b) How many duplicates
**      (c) How many distinct dataset locations
import excel "${data}\dm-dta-filenames.xlsx", sheet("Sheet1") firstrow clear
rename CyasukiSyncDMStataStatado fullpath
** Strip path - just want filename for now 
generate filename = regexs(1) if regexm(fullpath, "([^/\\]+)$")
** And just the filepath - no filename
generate dirpath = regexs(1) if regexm(fullpath, "^(.*[\\/])[^\\/]+$")
drop fullpath 

** Filename uniqueness
preserve
	count
	sort filename
	gen file_dup = 0 
	replace file_dup = 1 if filename==filename[_n-1]
	** Number range of same file
	bysort filename : gen file_dup_num = _n 
	bysort filename : egen file_dup_tot = max(file_dup_num)
	gen unique = 0 
	replace unique = 1 if filename!=filename[_n-1]
	order unique file_dup file_dup_num file_dup_tot, after(filename)
	tab file_dup
	tab file_dup_num
	tab file_dup_tot
	keep if unique==1 
	tab file_dup_tot
	replace file_dup_tot = 10 if file_dup_tot>=10

	colorpalette #012169 #ffffff #c8102E #128BBF , nograph
	local list r(p) 
	** Primary
	local dblu `r(p1)'
	local whi `r(p2)'
	local red `r(p3)'
	local lblu `r(p4)'

	** Graphic of number of duplicate datasets
	#delimit ;
		histogram
			file_dup_tot
			,
				freq discrete barw(0.75) col(#596b6d)
				
				plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=0 t=0)) 		
				graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin) margin(l=2 r=2 b=3 t=5)) 
				ysize(8) xsize(16)

				xlab(1(1)10, notick labs(`size') tlc(gs0) labc(gs2) notick nogrid glc(gs16))
				/// xscale(fill log lw(vthin) lc(gs2) range(10(1000)15010)) 
				xtitle("How many instances of each file?", size(`size') color(gs2) margin(l=1 r=1 t=1 b=1)) 

				ylab(0(200)1000,
				labc(gs2) labs(4) tstyle(major_notick) nogrid glc(gs2) angle(0) format(%9.0f))
				/// yscale(fill log lw(vthin) lc(gs2) ) 
				ytitle("", size(`size') color(gs2) margin(l=1 r=1 t=1 b=1)) 

				legend(off)
				name(figure1, replace);
				/// graph export "`outputpath'/figure4_`x'.png", replace width(4000);
				;
	#delimit cr	
	graph export "`stagingfigures'/`output1'.png", replace width(3000)
restore 

** Filepaths containing datasets
sort dirpath 
	gen dir_dup = 0 
	replace dir_dup = 1 if dirpath==dirpath[_n-1]
	** Number range of same PATHS
	bysort dirpath : gen dir_dup_num = _n 
	bysort dirpath : egen dir_dup_tot = max(dir_dup_num)
	gen unique = 0 
	replace unique = 1 if dirpath!=dirpath[_n-1]
	order unique dir_dup dir_dup_num dir_dup_tot, after(dirpath)
	keep dirpath dir_dup dir_dup_tot
	keep if dir_dup==0
	count 
	tab dir_dup_tot
  
** ==============================================================================
** DO NOT TOUCH: STANDARD RELEASE CONTROL AND PUBLISH STEP
** ==============================================================================
* The analysis section above has created all artefact-specific public files
* in the staging folder.
*
* This final section deliberately stays short. It writes one small control file
* that describes the release package, then calls the standard invariant helper.
*
* The helper, which is shared across briefing/output packages, will handle:
*   - briefing-level metadata;
*   - README creation;
*   - simplified downloads.yml creation;
*   - staging/ to public/ copy;
*   - public/ to site/downloads/ mirror.
*
* Because this output has no released datasets, workbook, or ZIP package, the
* helper will skip:
*   - dataset-level YAML metadata;
*   - Excel workbook creation;
*   - ZIP creation;
*   - central downloads listing.
*
* This keeps all artefact-specific work in one DO file while avoiding repeated
* copy/paste release machinery at the end of every output package.


** ==============================================================================
** DO NOT TOUCH: WRITE RELEASE CONTROL FILE
** ==============================================================================
* Purpose:
*   Create metadata/release_control.yml.
*
* This is the contract between the analyst-owned DO file and the invariant
* publish helper. Future analysts should edit the locals in EDIT BLOCK A, not
* the file-writing code below.
*
* Why a control file?
*   A called helper DO file should not depend on locals that happen to exist in
*   the calling DO file. Writing a small control file makes the handover between
*   the analysis layer and release layer explicit and auditable.

local release_date = string(daily("`c(current_date)'", "DMY"), "%tdCCYY-NN-DD")
local control_file "`stagingmetadata'/release_control.yml"

tempname release_control

file open `release_control' using "`control_file'", ///
    write replace text

file write `release_control' "schema: bnr_release_control_v1" _n
file write `release_control' "briefing_id: `briefing_id'" _n
file write `release_control' "briefing_name: `briefing_name'" _n
file write `release_control' "output_type: `output_type'" _n
file write `release_control' "domain: `domain'" _n
file write `release_control' "surveillance_area: `surveillance_area'" _n
file write `release_control' "registry: `registry'" _n
file write `release_control' "geography: `geography'" _n
file write `release_control' "period: `period'" _n
file write `release_control' "target_year: `target_year'" _n
file write `release_control' "baseline_start: `baseline_start'" _n
file write `release_control' "baseline_end: `baseline_end'" _n
file write `release_control' "release_date: `release_date'" _n
file write `release_control' "analysis_script: `analysis_script'" _n
file write `release_control' "" _n

file write `release_control' "title: |-" _n
file write `release_control' "  `briefing_title'" _n
file write `release_control' "" _n

file write `release_control' "short_title: |-" _n
file write `release_control' "  `briefing_short'" _n
file write `release_control' "" _n

file write `release_control' "description: |-" _n
file write `release_control' "  `briefing_description'" _n
file write `release_control' "" _n

file write `release_control' "limitations: |-" _n
file write `release_control' "  `briefing_limitations'" _n
file write `release_control' "" _n

file write `release_control' "data_note: |-" _n
file write `release_control' "  `data_note'" _n
file write `release_control' "" _n

file write `release_control' "rights: |-" _n
file write `release_control' "  `rights_note'" _n
file write `release_control' "" _n

file write `release_control' "contact: |-" _n
file write `release_control' "  `contact_note'" _n
file write `release_control' "" _n

file write `release_control' "briefing_page: `briefing_page'" _n
file write `release_control' "released_datasets: `released_datasets'" _n
file write `release_control' "released_figures: `released_figures'" _n
file write `release_control' "" _n

file write `release_control' "create_workbook: `create_workbook'" _n
file write `release_control' "create_zip: `create_zip'" _n
file write `release_control' "list_zip: `list_zip'" _n
file write `release_control' "" _n

file write `release_control' "zip_title: |-" _n
file write `release_control' "  `zip_title'" _n
file write `release_control' "" _n

file write `release_control' "zip_description: |-" _n
file write `release_control' "  `zip_description'" _n

file close `release_control'

display as result "Release control file created:"
display as result "  `control_file'"


** ==============================================================================
** DO NOT TOUCH: PUBLISH SUPPORTING OUTPUT PACKAGE
** ==============================================================================
* The standard publisher is shared across narrative briefings and supporting
* artefacts. Behaviour is controlled by release_control.yml.
*
* For this supporting artefact:
*   create_workbook = 0
*   create_zip      = 0
*   list_zip        = 0
*
* The public package will therefore be mirrored to the website but will not
* appear on the central downloads listing.

do "`localpath'/scripts/stata/common/bnr_publish_briefing.do" ///
    "`briefing_id'"

*--------------------------------------------------------------------
*  Barbados National Registry (BNR) Refit Consultancy
*  Refit Process Audit - Case Example 2
*--------------------------------------------------------------------
*  PURPOSE:
*  To highlight the poor DM/ folder and file structure.
*
*  AUTHOR:  IAN HAMBLETON
*  PROJECT: BNR Refit Consultancy
*  CREATED: 31-OCT-2025
*--------------------------------------------------------------------

* ==============================================================
* DO NOT TOUCH: INITIALIZE DO FILE 
* ==============================================================
version 19
clear all
set more off

* ==============================================================
* DO NOT TOUCH:    SET LOCAL PATH LOCATION
*                  AND LOAD SHARED SETTINGS 
* ==============================================================
local localpath "C:/yoshimi-hot/output/analyse-bnr/info-hub"
do "`localpath'/scripts/stata/config/bnr_paths_LOCAL.do"
do "`localpath'/scripts/stata/common/bnrcvd_globals.do"

** ==============================================================
** EDIT BLOCK A: BRIEFING SETTINGS
** ==============================================================
* For a new briefing, start here.
* Change these local macros before changing the standard release machinery.
local target_year       2023
local baseline_start    2018
local baseline_end      2022
local briefing_id       "cvd_forensics_2025_v1"
local briefing_name     "cvd_forensics_2025"
local output1           "cvd_file_instances"

* Private log file
cap log close
log using "$BNR_PRIVATE_LOGS/`briefing_name'", replace


* ==============================================================
* DO NOT TOUCH: STANDARD OUTPUT FOLDER SETUP
* ==============================================================
* The staging folder is the build area.
* The public folder is the approved release copy created at the end (see section 10 below)

* STAGING OUTPUT bundle locations
* Ensure locations exist
local stagingbriefing "$BNR_STAGING/briefings/`briefing_id'"
local stagingdatasets "`stagingbriefing'/datasets"
local stagingfigures "`stagingbriefing'/figures"
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
    "BNR CVD case-fatality briefing build" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:     `briefing_id'" _n ///
    as result "  Target year:     `target_year'" _n ///
    as result "  Baseline:        `baseline_start'-`baseline_end'" _n ///
    as result "  Staging bundle:  `stagingbriefing'" _n ///
    as text "------------------------------------------------------------" _n


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


** ==============================================================
** ==============================================================
** POST-ANALYSIS COPY TO PUBLIC SITE: 
** ==============================================================
** ==============================================================


** ==============================================================
** A.1 Define public release folders and ZIP path
** ==============================================================
local publicbriefing "$BNR_PUBLIC/briefings/`briefing_id'"
local publicdatasets "`publicbriefing'/datasets"
local publicfigures  "`publicbriefing'/figures"
local publicworkbook "`publicbriefing'/workbook"
local publicmetadata "`publicbriefing'/metadata"
local publiczip "`publicbriefing'/bnr_`briefing_id'.zip"

** ==============================================================
** A.2 Ensure public release folders exist
** ==============================================================
cap mkdir "$BNR_PUBLIC"
cap mkdir "$BNR_PUBLIC/briefings"
cap mkdir "`publicbriefing'"
cap mkdir "`publicdatasets'"
cap mkdir "`publicfigures'"
cap mkdir "`publicworkbook'"
cap mkdir "`publicmetadata'"

** ==============================================================
** A.3 Remove old files from public release folders
** ==============================================================
* This prevents old files remaining in public/ after a filename change
* or after a file is removed from the staging bundle.
local oldfiles : dir "`publicbriefing'" files "*"
foreach file of local oldfiles {
    erase "`publicbriefing'/`file'"
}
foreach folder in datasets figures workbook metadata {
    local oldfiles : dir "`publicbriefing'/`folder'" files "*"
    foreach file of local oldfiles {
        erase "`publicbriefing'/`folder'/`file'"
    }
}
cap erase "`publiczip'"

** ==============================================================
** A.4 Copy root-level files
** ==============================================================
cap copy "`stagingbriefing'/readme.txt" ///
     "`publicbriefing'/readme.txt", replace

cap copy "`stagingbriefing'/downloads.yml" ///
     "`publicbriefing'/downloads.yml", replace

** ==============================================================
** A.5 Copy staged subfolder files
** ==============================================================
foreach folder in datasets figures workbook metadata {
    local files : dir "`stagingbriefing'/`folder'" files "*"
    foreach file of local files {
        copy "`stagingbriefing'/`folder'/`file'" ///
             "`publicbriefing'/`folder'/`file'", replace
    }
}

** ==============================================================
** A.6 Create ZIP package from public release folder
** ==============================================================
* The ZIP contains the briefing folder itself, so extraction creates
* a clean top-level folder rather than scattering files.
shell powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -LiteralPath '`publicbriefing'' -DestinationPath '`publiczip'' -Force"

** ==============================================================
** A.7 Confirm public release bundle
** ==============================================================
display as text _n ///
    "------------------------------------------------------------" _n ///
    "BNR CVD case-fatality briefing public bundle prepared" _n ///
    "------------------------------------------------------------" _n ///
    as result "  Briefing ID:       `briefing_id'" _n ///
    as result "  Staging folder:    `stagingbriefing'" _n ///
    as result "  Public folder:     `publicbriefing'" _n ///
    as result "  ZIP package:       `publiczip'" _n ///
    as text "------------------------------------------------------------" _n

** ==============================================================
** A.8 MIRROR public release bundle --> Site bundle
** ==============================================================
do "scripts/stata/common/mirror_public_to_site.do" "`briefing_id'"

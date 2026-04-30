*--------------------------------------------------------------------
* Barbados National Registry (BNR) info-hub
* Shared globals for Stata briefing workflows
*--------------------------------------------------------------------
*
* PURPOSE
*   Shared session values and visual constants.
*
* IMPORTANT
*   This file should not set project paths.
*   Load paths first with:
*
*       do "scripts/stata/config/bnr_paths_LOCAL.do"
*
*--------------------------------------------------------------------

version 19
set more off

*-------------------------------
* Date and run metadata
*-------------------------------
local today_iso: display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
global todayiso "`today_iso'"

global today : display %tdCYND date(c(current_date), "DMY")
global analyst "`c(username)'"
global stata_v "`c(version)'"
global project "BNR info-hub"

*-------------------------------
* Compatibility aliases for first migrated 2023 scripts
*-------------------------------
* These keep the first ported scripts readable while moving away from
* the old resource-analytics folder structure.

global data      "$BNR_DATA_FROZEN"
global tempdata  "$BNR_PRIVATE_WORK"
global logs      "$BNR_PRIVATE_LOGS"
global graphs    "$BNR_BRIEF_FIGS"
global outputs   "$BNR_BRIEF_CVD_CASES_2023"
global tables    "$BNR_BRIEF_TABLES"

*-------------------------------
* BNR report colour palette
*-------------------------------
* RGB triplets avoid a dependency on user-written colour utilities.

* AMI
global ami_m   "164 22 26"
global ami_m70 "212 106 106"
global ami_f   "239 83 80"
global ami_f70 "247 166 163"

* Stroke
global str_m   "71 45 117"
global str_m70 "139 111 180"
global str_f   "156 137 184"
global str_f70 "201 182 228"

* Others
global highlight  "255 186 8"
global baseline   "141 153 174"
global background "250 250 250"
global text       "46 46 46"
global darkframe  "29 53 87"

*-------------------------------
* Unicode markers
*-------------------------------
global dagger   = uchar(8224)
global ddagger  = uchar(8225)
global sbullet  = uchar(8226)
global mbullet  = uchar(9679)
global lbullet  = uchar(11044)
global tbullet  = uchar(9675)
global fisheye  = uchar(9673)
global section  = uchar(0167)
global teardrop = uchar(10045)
global flower   = uchar(8270)
global endash   = uchar(8211)
global emdash   = uchar(8212)

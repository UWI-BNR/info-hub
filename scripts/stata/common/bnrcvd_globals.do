*--------------------------------------------------------------------
* Barbados National Registry (BNR) info-hub
* Shared globals for Stata briefing workflows
*--------------------------------------------------------------------
*
* PURPOSE
*   Shared session values and visual constants. This file contains no
*   machine-specific paths or credentials.
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

if `"$BNR_REPO"' == "" | `"$BNR_STATA"' == "" {
    display as error "BNR path configuration has not been loaded."
    display as error ///
        "Run scripts/stata/config/bnr_paths_LOCAL.do before bnrcvd_globals.do."
    exit 198
}

*-------------------------------
* Date and run metadata
* Some values are retained for compatibility with analyst-authored reports.
*-------------------------------
local today_iso: display %tdCCYY-NN-DD daily("`c(current_date)'", "DMY")
global todayiso "`today_iso'"

global today : display %tdCYND date(c(current_date), "DMY")
global analyst "`c(username)'"
global stata_v "`c(version)'"
global project "BNR info-hub"

*-------------------------------
* BNR report colour palette
*-------------------------------
* RGB triplets avoid a dependency on user-written colour utilities.

* AMI
* ami_m: #A4161A
* ami_m70: #D46A6A
* ami_f: #EF5350
* ami_f70: #F7A6A3
* Stroke
* str_m: #472D75
* str_m70: #8B6FB4
* str_f: #9C89B8
* str_f70: #C9B6E4
* highlight: #FFBA08
* baseline: #8D99AE
* background: #FAFAFA
* text: #2E2E2E
* darkframe: #1D3557

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

* Additional retained palette colours
global highlight  "255 186 8"
global baseline   "141 153 174"
global background "250 250 250"
global text       "46 46 46"
global darkframe  "29 53 87"

*-------------------------------
* Unicode markers retained for report compatibility
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

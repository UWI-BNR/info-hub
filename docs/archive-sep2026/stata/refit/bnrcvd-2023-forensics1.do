*--------------------------------------------------------------------
*  Barbados National Registry (BNR) Refit Consultancy
*  Dataset search
*--------------------------------------------------------------------
*  PURPOSE:
*  Looking for the historical BNR dataset.
*  Find the map - find the treasure, OooArrrrrr...
*  AUTHOR:  IAN HAMBLETON
*  PROJECT: BNR Refit Consultancy
*  CREATED:  29-OCT-2025
*--------------------------------------------------------------------

*-------------------------------
* 1. DO file folder (edit once only)
*-------------------------------
    global root1 "C:\yasuki\Sync\BNR-sandbox\006-dev"
    global dofiles   "${root1}\do"
    global logs      "${root1}\log"
    global jcdata      "${root1}\data"


*-------------------------------
* 2. DATASET folder(s)
*-------------------------------
    global root2 "C:\yasuki\Sync\DM\Stata\Stata do files\Statistics"
    global data "${root2}\analysis\dataset_preperations\BNR_for_research_use\versions\version09\data"

*-------------------------------
* 3. DATE
*-------------------------------
* today's date in ISO format (e.g., 2025-10-28)
    local today: display %tdCCYY-NN-DD daily("`c(current_date)'","DMY")
    global today = "`today'"

*-------------------------------
** STROKE: Load JC cumulative dataset 
local n = 0
*-------------------------------
qui {
    local n = `n' + 1 
    use "${jcdata}\2009-2023_identifiable_restructured_cvd.dta", clear
    keep if rpt_redcap_event_name == "stroke_arm_1"
    order pid rpt_recid rpt_dob nrpt_cfage nrpt_fname nrpt_lname rpt_natregno 
    **keep if rpt_sd_eyear <=2019 
    count
    local count`n' = r(N)
    noi dis "EVENT COUNT = " `count`n''
    noi dis "VARIABLE COUNT = " c(k)
    gen dob_miss`n' = 0 
    replace dob_miss`n' = 1 if missing(rpt_dob)
    order dob_miss`n', after(rpt_dob) 
    noi tab dob_miss`n', miss
    noi tab rpt_sd_eyear dob_miss`n', miss
    gen lname`n' = 0 
    replace lname`n' = 1 if nrpt_lname==""
    order lname`n', after(dob) 
    noi tab lname`n', miss
}


*-------------------------------
** STROKE: Load alternative dataset candidate
dis "ALTERNATIVE = " `n'
*-------------------------------
qui {
    local n = `n' + 1 
    use "${data}\stroke_2009-2020_v9_names_clean.dta", clear
    order record_id unique_id dob cfage cfage_da fname lname natregno 
    keep if year<=2019 
    count
    local count`n' = r(N)
    noi dis "EVENT COUNT = " `count`n''
    noi dis "VARIABLE COUNT = " c(k)
    gen dob_miss`n' = 0 
    replace dob_miss`n' = 1 if missing(dob)
    order dob_miss`n', after(dob) 
    noi tab dob_miss`n', miss
    noi tab year dob_miss`n', miss
    gen lname`n' = 0 
    replace lname`n' = 1 if lname==""
    order lname`n', after(dob) 
    noi tab lname`n', miss
}

*-------------------------------
** STROKE: Load alternative dataset candidate
dis "ALTERNATIVE = " `n'
*-------------------------------
qui {
    local n = `n' + 1 
    use "${data}\stroke_2009-2020_v9_names_Stata_v16_clean.dta", clear
    order record_id unique_id dob cfage cfage_da fname lname natregno 
    keep if year<=2019 
    count
    local count`n' = r(N)
    noi dis "EVENT COUNT = " `count`n''
    noi dis "VARIABLE COUNT = " c(k)
    gen dob_miss`n' = 0 
    replace dob_miss`n' = 1 if missing(dob)
    order dob_miss`n', after(dob) 
    noi tab dob_miss`n', miss
    noi tab year dob_miss`n', miss
    gen lname`n' = 0 
    replace lname`n' = 1 if lname==""
    order lname`n', after(dob) 
    noi tab lname`n', miss
}

*-------------------------------
** STROKE: Load alternative dataset candidate
dis "ALTERNATIVE = " `n'
*-------------------------------
qui {
    local n = `n' + 1 
    use "${data}\stroke_2009-2019_v8_names_updated2_clean.dta", clear
    order pid dos dob age fname lname natregno 
    sort dos 
    count
    local count`n' = r(N)
    noi dis "EVENT COUNT = " `count`n''
    noi dis "VARIABLE COUNT = " c(k)
    gen dob_miss`n' = 0 
    replace dob_miss`n' = 1 if missing(dob)
    order dob_miss`n', after(dob) 
    noi tab dob_miss`n', miss
    noi tab year dob_miss`n', miss
    gen lname`n' = 0 
    replace lname`n' = 1 if lname==""
    order lname`n', after(dob) 
    noi tab lname`n', miss
}




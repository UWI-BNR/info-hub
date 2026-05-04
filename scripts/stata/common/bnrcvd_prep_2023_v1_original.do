/**************************************************************************
 DO-FILE:     bnrcvd-2023-prep1.do
 PROJECT:     BNR Refit Consultancy
 PURPOSE:     Imports a raw cumulative BNR CVD dataset prep-prepared 
              by JCampbell (October 2025). Further preparation to create
              analysis-ready files for entry to subsequent DO files.

 AUTHOR:      Ian R Hambleton
 DATE:        [2025-11-02]
 VERSION:     [v1.0]

 METADATA:    bnrcvd-2023-prep1.yml (same dirpath/name as dataset)

 NOTES:       DO files works on cumulative dataset provided by JC only

               This file moves us from
               (A) The official cumulative dataset (2009-2023), to 
               (B) The analytics dataset used by all 2023 analyses

               So, this DO file prepares the *intermediate analysis dataset* for the
               2023 BNR-CVD reporting cycle. It is the key staging step between
               the official cumulative dataset (2009-2023) release and 
               the raw REDCap export and the downstream analytic scripts.

               It:
                 - Loads the cleaned REDCap-derived dataset created earlier in the
                   pipeline and performs additional variable preparation needed for
                   event-level analysis (AMI and stroke).
                 - Applies core restrictions (e.g., valid dates, event types, age,
                   handling of death-certificate-only cases) and harmonises variable
                   names, formats, and coding conventions across years.
                 - Produces both a full record-level dataset and a simplified count
                   dataset, saving them to the temporary data directory for use by
                   all 2023 analytic DO files.

               This file is the central preparation step for all 2023 BNR-CVD outputs:
               it must run successfully before case-fatality, incidence, LOS, missing
               data, performance, and tabulation scripts are executed.

**************************************************************************/

** ------------------------------------------------
** ----- INITIALIZE DO FILE -----------------------
   version 19
   clear all
   set more off

   * Load local paths and shared settings
   do "scripts/stata/config/bnr_paths_LOCAL.do"
   do "scripts/stata/common/bnrcvd_globals.do"

   ** Log file: private/local only
   ** cap log close
   ** log using "$BNR_PRIVATE_LOGS/bnrcvd_prep_2023_v1", replace
** ----- END INITIALIZE DO FILE -------------------
** ------------------------------------------------



** --------------------------------------------------------------
** (1) Load the JC created dataset
** 
** TO ALTER YEAR AND MONTH OF DATA RELEASE
** 
** edit: bnrpath.ado
** Line to edit:  -->   global release "releases/y2023/m12" 
** 
** --------------------------------------------------------------

** For dataset details, see : https://uwi-bnr.github.io/bnr-refit/02_Data/structure/   
** use "${data}\2009-2023_identifiable_restructured_cvd_30Oct2025_v2.dta", clear 
** use "${data}/releases/y2023/m12/bnr-cvd-indiv-full-202312-v01.dta", clear 
   use "$BNR_DATA_FROZEN/releases/y2023/m12/bnr-cvd-indiv-full-202312-v01.dta", clear

** --------------------------------------------------------------
** (2) Drop variables we will NOT use in analytics
** --------------------------------------------------------------
   * Drop internal variables created by JCampbell during creation of cumulative dataset
   * These would not be in the REDCap dataset export 
   drop sd_db  sd_eyear /*sd_etype*/
   * Drop process variables and casefinding source - no longer used in current casefinding 
   drop cfdoat cfda cfsource__* /*cfdoa recid*/
   * Drop demographics 
   drop initialdx hstatus slc finaldx cfcods cstatus eligible ineligible /*cfage*/
   drop duplicate duprec dupcheck toabs
   drop mstatus resident citizen addr
   * Event
   drop dxtype dstroke 
   drop inhosp etimeampm  
   * Risk factors 
   drop rfany
   * Tests 
   drop bgunit bgmg
   * Exam 
   drop dieany_2 decg ecgtampm tropdone troptype 
   * Assessments 
   drop dieany dct 

   * Treatment Discharge 
   * drop reperf 
   * Medications 
   * drop asptimeampm_2 
   * Discharge Vital Signs 
   drop dissysbp disdiasbp disbgmmol carunit 

** --------------------------------------------------------------
** (3) Preparation and Labelling analysis variables
** --------------------------------------------------------------

** SECTION A. Patient DEMOGRAPHICS and EVENT characteristics
** --------------------------------------------------------------
* PID --> EID - Event ID - generated in Stata after REDCap export 
   rename pid eid 
   label var eid "CVD Event Unique Identifier"
   note eid : Internal unique ID created after dataset export from REDCap 

** Internal REDCap id 
   rename recid rid 
   label var rid "REDCap Record ID"
   note rid : Unique record identifier assigned by REDCap
   order rid, after(eid)

* Alternative DCO - Death certificate + Partial Abstraction 
   gen dco_alt = 0 
   replace dco_alt = 1 if sd_absstatus==3 
   replace dco_alt = 2 if sd_absstatus==2 
   label define dco_alt_ 0 "Abstracted"  1 "DCO" 2 "Partial Absytraction", modify 
   label values dco_alt dco_alt_ 
   label var dco_alt "Death Certificate Only (DCO) Case"
   note dco_alt : Indicates if case was identified via death certificate only (1=Yes; 0=No)
   order dco_alt, after(rid) 

* sd_abstracted --> DCO - Death Certification Only - generated after REDCap export 
   gen dco = 0 
   replace dco = 1 if sd_absstatus==3 
   label define dco_ 0 "Abstracted"  1 "DCO", modify 
   label values dco dco_ 
   label var dco "Death Certificate Only (DCO) Case"
   note dco : Indicates if case was identified via death certificate only (1=Yes; 0=No)
   order dco, after(dco_alt) 
   drop sd_absstatus

* Event name (AMI or STROKE)
   gen etype = 1 if inlist(redcap_event_name, "stroke_arm_1")
   replace etype = 2 if inlist(redcap_event_name, "heart_arm_2")
   label define etype_ 1 "Stroke" 2 "AMI", modify 
   label values etype etype_
   label var etype "CVD Event Type (AMI=2, Stroke=1)"
   order etype redcap_event_name, after(dco)
   **drop redcap_event_name

** ---------------------------------------------------------------
** DATES 
** ---------------------------------------------------------------
** Date of casefinding 
   rename cfdoa docf
   format docf %dD_m_CY
   label var docf "CVD casefinding date (dd-mon-yyyy)"
   order docf, after(etype)

** Date of birth
   format dob %dD_m_CY
   label var dob "Patient date of birth (dd-mon-yyyy)"
   order dob, after(docf)

** Date of event 
   rename edate doe
   format doe %dD_m_CY
   label var doe "CVD event date (dd-mon-yyyy)"
   order doe, after(dob)

** Year of event
   gen yoe = year(doe)
   label var yoe "CVD event year (yyyy)"
   order yoe, after(doe)
   ** drop sd_eyear

** Month of event
   gen moe = month(doe)
   label var moe "CVD event month (mm)"
   order moe, after(yoe)

** Time of event 
   gen htoe = real(substr(etime, 1, 2))
   gen mtoe = real(substr(etime, 4, 2))
   label var htoe "Patient hour of event (hh)"
   label var mtoe "Patient minute of event (mm)"
   order htoe mtoe, after(moe)
   drop etime

** Date of admission
   rename cfadmdate doa  
   format doa %dD_m_CY
   label var doa "Patient date of admission (dd-mon-yyyy)"
   order doa, after(mtoe)

** Time of admission
   gen htoa = real(substr(admtime, 1, 2))
   gen mtoa = real(substr(admtime, 4, 2))
   label var htoa "Patient hour of admission (hh)"
   label var mtoa "Patient minute of admission (mm)"
   order htoa mtoa, after(doa)
   drop admtime

** Discharge date
   rename dlc dodi 
   format dodi %dD_m_CY
   label var dodi "Patient date of discharge (dd-mon-yyyy)"
   order dodi, after(mtoa)

** Vital Status at discharge (sadi, 1=alive, 2=dead, 99=.a)
   rename vstatus sadi 
   label var sadi "Patient vital status at discharge (1=Alive; 2=Dead)"
   mvdecode sadi, mv(99=.a)
   order sadi, after(dodi)

** Date of death
   rename cfdod dod
   format dod %dD_m_CY
   label var dod "Patient date of death (dd-mon-yyyy)"
   order dod, after(sadi)

** ---------------------------------------------------------------
** OTHER DEMOGRAPHIC VARIABLES
** ---------------------------------------------------------------
** Sex
   label var sex "Patient sex (1=female, 2=male)"
   order sex, after(dod)

** Age 
** (For 2009-2023) derived variable created by JC from:
**    age, dd_age, cfage_da
** (For 2024 onwards) to be derived from dob and doe after REDCap export
** Derived age has a mix of exact ages (from dob) and truncated ages - floor() - presumably
** We round everythig down for comparability 
   gen agey = floor(cfage) 
   label var agey "Patient age at event (years as integer)"
   drop age dd_age cfage_da cfage
   order agey , after(sex)

** AGE in 5-YEAR BANDS (18 groups) 
   gen age5 = . 
   replace age5 = 1 if agey<=4
   replace age5 = 2 if inrange(agey, 5,9)
   replace age5 = 3 if inrange(agey, 10,14)
   replace age5 = 4 if inrange(agey, 15,19)
   replace age5 = 5 if inrange(agey, 20,24)
   replace age5 = 6 if inrange(agey, 25,29)
   replace age5 = 7 if inrange(agey, 30,34)
   replace age5 = 8 if inrange(agey, 35,39)
   replace age5 = 9 if inrange(agey, 40,44)
   replace age5 = 10 if inrange(agey, 45,49)
   replace age5 = 11 if inrange(agey, 50,54)
   replace age5 = 12 if inrange(agey, 55,59)
   replace age5 = 13 if inrange(agey, 60,64)
   replace age5 = 14 if inrange(agey, 65,69)
   replace age5 = 15 if inrange(agey, 70,74)
   replace age5 = 16 if inrange(agey, 75,79)
   replace age5 = 17 if inrange(agey, 80,84)
   replace age5 = 18 if agey>=85
   #delimit ; 
   label define age5_   1 "0-4"   2 "5-9"
                        3 "10-14" 4 "15-19"
                        5 "20-24" 6 "25-29"
                        7 "30-34" 8 "35-39"
                        9 "40-44" 10 "45-49"
                        11 "50-54" 12 "55-59"
                        13 "60-64" 14 "65-69"
                        15 "70-74" 16 "75-79"
                        17 "80-84" 18 "85+";
   #delimit cr 
   label values age5 age5_ 
   label var age5 "Patient age at event (5-year age groups)"
   order age5, after(agey) 

** AGE <70, 70 and older 
   gen age70 = 0 if agey<70 
   replace age70 = 1 if agey>=70
   label define age70_ 0 "<70 years" 1 "70 years and older", modify
   label values age70 age70_  
   label var age70 "Patient age group (<70 yrs; 70+ yrs)"
   order age70, after(age5)

** Parish of residence
   label var parish "Patient parish of residence"
   recode parish 99=. 
   order parish, after(age70)

** Treatment Locations
** 1 - ICU/HDU
** 2 - A&E
** 3 - Medical wards
** 4 = Stroke Unit
** 5 = Cardiac Unit 
rename ward___1 treatloc1
rename ward___2 treatloc2
rename ward___3 treatloc3
rename ward___4 treatloc4
rename ward___5 treatloc5
label var treatloc1 "Treated in ICU/HDU (1=Yes; 0=No)"
label var treatloc2 "Treated in A&E (1=Yes; 0=No)"
label var treatloc3 "Treated in Medical wards (1=Yes; 0=No)"
label var treatloc4 "Treated in Stroke Unit (1=Yes; 0=No)"
label var treatloc5 "Treated in Cardiac Unit (1=Yes; 0=No)"
label define yesno_ 0 "No" 1 "Yes", modify
label values treatloc1 yesno_
label values treatloc2 yesno_
label values treatloc3 yesno_
label values treatloc4 yesno_
label values treatloc5 yesno_
order treatloc1 treatloc2 treatloc3 treatloc4 treatloc5, after(parish)

** ---------------------------------------------------------------
** EVENT VARIABLES
** ---------------------------------------------------------------

** AMI subtype
   label var htype "AMI subtype (1=STEMI; 2=NSTEMI; other categories)"
   order htype, after(treatloc5)
** Stroke subtype
   label var stype "Stroke subtype (1=Ischemic; 2/3=Hemorrhagic; other categories)"
   order stype, after(htype)

** ---------------------------------------------------------------
** PREVIOUS EVENT VARIABLES
** ---------------------------------------------------------------
** Previous stroke event 
   label var pstroke "History of previous stroke (1=Yes; 2=No)"
   mvdecode pstroke, mv(99=.a)
   order pstroke, after(stype)
** Year of previous stroke event
   label var pstrokeyr "Year of previous stroke event (yyyy)"
   mvdecode pstrokeyr, mv(99=.a \ 9999=.b \ 1=.c \ 1908=.c)
   order pstrokeyr, after(pstroke)
** Previous AMI event
   label var pami "History of previous AMI (1=Yes; 2=No)"
   mvdecode pami, mv(99=.a)
   order pami, after(pstrokeyr)
** Year of previous AMI event
   label var pamiyr "Year of previous AMI event (yyyy)"
   mvdecode pamiyr, mv(99=.a \ 9999=.b)
   order pamiyr, after(pami)  

** ---------------------------------------------------------------
** RISK FACTORS
** ---------------------------------------------------------------
** Hypertension
   label var htn "History of hypertension (1=Yes; 2=No)"
   mvdecode htn, mv(99=.a)
   order htn, after(pamiyr)
** Diabetes Type II
   label var diab "History of diabetes mellitus (1=Yes; 2=No)"
   mvdecode diab, mv(99=.a)
   order diab, after(htn)

** ---------------------------------------------------------------
** TESTS
** ---------------------------------------------------------------
** systolic blood pressure on admission
   rename sysbp sbp 
   label var sbp "Systolic blood pressure on admission (mmHg)"
   mvdecode sbp, mv(999=.a \ 99999=.b )
   order sbp, after(diab)
** diastolic blood pressure on admission
   rename diasbp dbp 
   label var dbp "Diastolic blood pressure on admission (mmHg)"
   mvdecode dbp, mv(999=.a \ 99999=.b )
   order dbp, after(sbp)
** Blood glucose on admission 
   label var bgmmol "Blood glucose on admission (mmol/L)"
   order bgmmol, after(dbp)  

** ---------------------------------------------------------------
** EXAM
** ---------------------------------------------------------------
** ecg
   label var ecg "ECG performed during event admission (1=Yes; 2=No)"
   mvdecode ecg, mv(99=.a )
   order ecg, after(bgmmol)

** ECG date
   rename ecgd doecg 
   format doecg %dD_m_CY
   label var doecg "Date of ECG during event admission (dd-mon-yyyy)"
   order doecg, after(ecg)

** ECG time
   gen htecg = real(substr(ecgt, 1, 2))
   gen mtecg = real(substr(ecgt, 4, 2))
   label var htecg "Hour of ECG during event admission (hh)"
   label var mtecg "Minute of ECG during event admission (mm)"
   order htecg mtecg, after(doecg)
   drop ecgt   

** ---------------------------------------------------------------
** CARDIAC ENZYMES
** ---------------------------------------------------------------
** Number of troponin tests completed (1, 2, more than 2)
   label var tropres "Number of troponin tests completed"
   label define tropres_ 1 "one" 2 "two" 3 "more than two", modify
   label values tropres tropres_
   order tropres, after(mtecg)

** Result of test 1 (trop1res - continuous variable)
   label var trop1res "Result of troponin test 1 (ng/L)"
   mvdecode trop1res, mv(0=.a \ 9999.99=.b)
   order trop1res, after(tropres)

** Result of test 2 (trop2res - continuous variable)
   label var trop2res "Result of troponin test 2 (ng/L)" 
   mvdecode trop2res, mv(0=.a \ 9999.99=.b)
   order trop2res, after(trop1res)

** ---------------------------------------------------------------
** ASSESSMENTS
** ---------------------------------------------------------------
** Assessment by any of the 4 types below (assess, 1=yes, 2=no, 99=.a, 99999=.b)
   label var assess "Assessment by any therapist (1=Yes; 2=No)"
   mvdecode assess, mv(99=.a \ 99999=.b)
   order assess, after(trop2res)

** Evaluation by an occupational therapist (assess1, 1=yes 2=no, 3=referred for, 99=.a, 99999=.b)
   label var assess1 "Evaluated by occupational therapist (1=Yes; 2=No; 3=Referred)"
   mvdecode assess1, mv(99=.a \ 99999=.b)
   order assess1, after(assess)
** Evaluation by a physiotherapist (assess2, 1=yes 2=no, 3=referred for, 99=.a, 99999=.b)
   label var assess2 "Evaluated by physiotherapist (1=Yes; 2=No; 3=Referred)"
   mvdecode assess2, mv(99=.a \ 99999=.b)
   order assess2, after(assess1) 
** Evaluation by a speech therapist (assess3, 1=yes 2=no, 3=referred for, 99=.a, 99999=.b)
   label var assess3 "Evaluated by speech therapist (1=Yes; 2=No; 3=Referred)"
   mvdecode assess3, mv(99=.a \ 99999=.b) 
   order assess3, after(assess2)
** Evaluation by swallowing assessment (assess4, 1=yes 2=no, 3=referred for, 99=.a, 99999=.b)
   label var assess4 "Evaluated by swallowing assessment (1=Yes; 2=No; 3=Referred)"
   mvdecode assess4, mv(99=.a \ 99999=.b) 
   order assess4, after(assess3)
** Is CT report available (ct, yes=1, No=2, 99=.a, 99999=.b)
   label var ct "CT scan report available (1=Yes; 2=No)"
   mvdecode ct, mv(99=.a \ 99999=.b) 
   order ct, after(assess4)
** Date of CT report (doct)
   format doct %dD_m_CY
   label var doct "Date of CT scan report (dd-mon-yyyy)"
   order doct, after(ct)

** ---------------------------------------------------------------
** TREATMENT DISCHARGE
** ---------------------------------------------------------------
** Reperfusion attempted? 
   label var reperf "Reperfusion attempted (1=Yes; 02=No)"
   mvdecode reperf, mv(99=.a \ 99999=.b)
   order reperf, after(doct)
** Reperfusion type (repertype, 1=fibrinolytic. 2=PCI, 99=.a) 
   label var repertype "Type of reperfusion therapy (1=Fibrinolytic; 2=PCI)"
   mvdecode repertype, mv(99=.a)
   order repertype, after(reperf)
** Date of reperfusion (dore)
   rename reperfd dore
   format dore %dD_m_CY
   label var dore "Date of reperfusion therapy (dd-mon-yyyy)"
   order dore, after(repertype)
** Time of reperfusion (tore)
   rename reperft tore
   gen htore = real(substr(tore, 1, 2))
   gen mtore = real(substr(tore, 4, 2))
   label var htore "Hour of reperfusion therapy (hh)"
   label var mtore "Minute of reperfusion therapy (mm)"
   order htore mtore, after(dore)
   drop tore

** ---------------------------------------------------------------
** MEDICATIONS
** ---------------------------------------------------------------
** Acute aspirin use (asp1, 0=no, 1=yes)
   rename asp___1 asp1
   label var asp1 "Aspirin - acute use (1=Yes; 0=No)"
   order asp1, after(mtore)
** Chronic aspirin use (asp2, 0=no, 1=yes)
   rename asp___2 asp2
   label var asp2 "Aspirin chronic use (1=Yes; 0=No)"
   order asp2, after(asp1)
** Aspirin contraindicated (asp3, 0=no, 1=yes)
   rename asp___3 asp3
   label var asp3 "Aspirin contraindicated (1=Yes; 0=No)"
   order asp3, after(asp2)
** Aspirin dose (aspdose)
   label var aspdose "Aspirin dose (mg)"
   mvdecode aspdose, mv(999=.a)
   order aspdose, after(asp3)
** Aspirin date (doasp)
   rename aspd doasp
   format doasp %dD_m_CY
   label var doasp "Date aspirin prescribed (dd-mon-yyyy)"
   order doasp, after(aspdose)
** Time of aspirin (toasp)
   rename aspt toasp 
   gen htoasp = real(substr(toasp, 1, 2))
   gen mtoasp = real(substr(toasp, 4, 2))
   label var htoasp "Hour aspirin prescribed (hh)"
   label var mtoasp "Minute aspirin prescribed (mm)"
   order htoasp mtoasp, after(doasp)
   drop toasp
   * There are several 24-hour erros (entered as 12-hr, should be 24-hr) 
   * only find when calculating (date of aspirin - date of event) 
   gen secs = 0 
   gen asp_arr = dhms(doe, htoe, mtoe, secs)
   gen asp_giv = dhms(doasp, htoasp, mtoasp, secs)
   generate diff_hrs = clockdiff(asp_arr, asp_giv , "hour")
   ** What percentage of times are errors
   gen error = 0 if asp_giv<. & asp_arr<. 
   replace error = 1 if diff_hrs<0
   ** Several 24-hr clock corrections
   replace htoasp = htoasp+12 if error==1 
   drop asp_giv diff_hrs error
** Aspirin approximate time (AM / PM)
   rename asptimeampm_2 asp_ampm
   label var asp_ampm "Approprimate time aspirin prescribed"
   order asp_ampm, after(mtoasp)


** ---------------------------------------------------------------
** DISCHARGE MEDICATIONS
** ---------------------------------------------------------------
* 1-aspirin
* 2-warfarin
* 3-heparin 
* 4-antiplatelet
* 5-statin
* 6-ACE inhibitor 
* 7-ARBs
* 8-Beta-blockers
* 9-bivalrudin
* 10-anti-hypertensives
** ---------------------------------------------------------------
** Discharge medication 1-aspirin (dmed1, no=0, 1=yes)
   rename dismeds___1 dmed1
   label var dmed1 "Aspirin prescribed at discharge (1=Yes; 0=No)"
   order dmed1, after(asp_ampm)
** Discharge medication 2-warfarin (dmed2, no=0, 1=yes)
   rename dismeds___2 dmed2
   label var dmed2 "Warfarin prescribed at discharge (1=Yes; 0=No)"
   order dmed2, after(dmed1)
** Discharge medication 3-heparin (dmed3, no=0, 1=yes)
   rename dismeds___3 dmed3
   label var dmed3 "Heparin prescribed at discharge (1=Yes; 0=No)"
   order dmed3, after(dmed2)
** Discharge medication 4-antiplatelet (dmed4, no=0, 1=yes)
   rename dismeds___4 dmed4 
   label var dmed4 "Antiplatelet prescribed at discharge (1=Yes; 0=No)"
   order dmed4, after(dmed3)
** Discharge medication 5-statin (dmed5, no=0, 1=yes)
   rename dismeds___5 dmed5
   label var dmed5 "Statin prescribed at discharge (1=Yes; 0=No)"
   order dmed5, after(dmed4)
** Discharge medication 6-ACE inhibitor (dmed6, no=0, 1=yes)
   rename dismeds___6 dmed6
   label var dmed6 "ACE inhibitor prescribed at discharge (1=Yes; 0=No)"
   order dmed6, after(dmed5)
** Discharge medication 7-ARBs (dmed7, no=0, 1=yes)
   rename dismeds___7 dmed7
   label var dmed7 "ARB prescribed at discharge (1=Yes; 0=No)"
   order dmed7, after(dmed6)
** Discharge medication 8-Beta-blockers (dmed8, no=0, 1=yes)
   rename dismeds___8 dmed8
   label var dmed8 "Beta-blocker prescribed at discharge (1=Yes; 0=No)"
   order dmed8, after(dmed7)
** Discharge medication 9-bivalrudin (dmed9, no=0, 1=yes)
   rename dismeds___9 dmed9
   label var dmed9 "Bivalrudin prescribed at discharge (1=Yes; 0=No)"
   order dmed9, after(dmed8)
** Discharge medication 10-anti-hypertensives (dmed10, no=0, 1=yes)
   rename dismeds___10 dmed10
   label var dmed10 "Anti-hypertensive prescribed at discharge (1=Yes; 0=No)"
   order dmed10, after(dmed9) 

** Aspirin dose at discharge (aspdose_dis)
   rename aspdosedis aspdose_dis 
   label var aspdose_dis "Aspirin dose at discharge (mg)"
   mvdecode aspdose_dis, mv(99=.a \ 999=.b)
   order aspdose_dis, after(dmed10)

** ---------------------------------------------------------------
** STROKE UNIT
** ---------------------------------------------------------------
** Admitted to stroke unit (sunit 1=yes, 2=no, 99=.a)
   rename strunit sunit 
   label var sunit "Admitted to stroke unit (1=Yes; 2=No)"
   mvdecode sunit, mv(99=.a)
   order sunit, after(aspdose_dis)
** Date of stroke unit admission (doasu)
   rename astrunitd doasu
   format doasu %dD_m_CY
   label var doasu "Date of stroke unit admission (dd-mon-yyyy)"
   order doasu, after(sunit)
** Date of stroke unit discharge (dosdu)
   rename dstrunitd dodisu
   format dodisu %dD_m_CY
   label var dodisu "Date of stroke unit discharge (dd-mon-yyyy)"
   order dodisu, after(doasu)   
** Is stroke unit admission the same date as hospital admission? (doasu_same, 1=yes, 2=no)
   rename sunitadmsame doasu_same
   label var doasu_same "Stroke unit admission same date as hospital admission (1=Yes; 2=No)"
   mvdecode doasu_same, mv(99=.a)
   order doasu_same, after(dodisu)
** Is stroke unit discharge the same date as hospital discharge? (dosdu_same, 1=yes, 2=no)
   rename sunitdissame dodisu_same
   label var dodisu_same "Stroke unit discharge same date as hospital discharge (1=Yes; 2=No)"
   mvdecode dodisu_same, mv(99=.a)
   order dodisu_same, after(doasu_same)


** --------------------------------------------------------------
** Identifiable variables
** --------------------------------------------------------------
   rename natregno nid 
   label var nid "Patient national registration number"
   rename recnum hid 
   label var nid "Patient hospital number"

   local ident = "fname mname lname nid hid" 
   foreach var of local ident {
       rename `var' id_`var' 
      }
   order id_fname id_mname id_lname id_nid id_hid, last   
   note id_fname : Patient first name 
   note id_mname : Patient middle name 
   note id_lname : Patient surname
   note id_nid : Patient national registration number
   note id_hid : Patient hospital number

** --------------------------------------------------------------
** (4) FULL DATASET - interim dataset - save
** --------------------------------------------------------------
   label data "BNR-CVD: FULL dataset - prepared by Ian Hambleton, ${todayiso}"
   note : Input dataset = 2009-2023_identifiable_restructured_cvd.dta
   note : Prepared by Ian Hambleton, GA-CDRC, UWI
   note : Date created = ${todayiso}
   note : Input dataset created by J.Campbell, 25-Oct-2025 
   save "$BNR_PRIVATE_WORK/bnrcvd_full_2023_v1.dta", replace



** Associated YAML metadata file - create and save
   local dataset "$BNR_PRIVATE_WORK/bnrcvd_full_2023_v1.dta"
   * Generate YAML
   bnryaml using "`dataset'", ///
      title("BNR-CVD Full Dataset (Identifiable)") ///
      version("1.0") ///
      created("${todayiso}") ///
      creator("Ian Hambleton") ///
      tier("FULL") ///
      temporal("2009-01 to 2023-12") ///
      spatial("Barbados") ///
      description("Confirmed cardiovascular events; interim prep1 dataset.") ///
      registry("CVD") ///
      content("INDIV") ///
      language("en") ///
      format("Stata 19") ///
      rights("Restricted - internal analytical use only") ///
      source("Hospital admissions (QEH) and national death registration") ///
      contact("ian.hambleton@uwi.edu") /// 
      outfile("$BNR_PRIVATE_WORK/bnrcvd_full_2023_v1.yml")

** --------------------------------------------------------------
** (5) COUNT DATASET DATASET - interim dataset - save
** --------------------------------------------------------------
preserve
   keep eid dco dco_alt etype doe yoe moe agey age5 age70 sex
   label data "BNR-CVD COUNT dataset: prepared by Ian Hambleton, ${todayiso}"
   note : Input dataset = 2009-2023_identifiable_restructured_cvd.dta
   note : Prepared by Ian Hambleton, GA-CDRC, UWI
   note : Date created = ${todayiso}
   note : Input dataset created by J.Campbell, 25-Oct-2025 
   save "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta", replace
** Associated YAML metadata file - create and save
   local dataset "$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta"
   * Generate YAML
   bnryaml using "`dataset'", ///
      title("BNR-CVD COUNT Dataset (Identifiable)") ///
      version("1.0") ///
      created("${todayiso}") ///
      creator("Ian Hambleton") ///
      tier("DEID") ///
      temporal("2009-01 to 2023-12") ///
      spatial("Barbados") ///
      description("Deindentified event dataset for analysis of counts / incidence.") ///
      registry("CVD") ///
      content("INDIV") ///
      language("en") ///
      format("Stata 19") ///
      rights("Restricted - internal analytical use only") ///
      source("Hospital admissions (QEH) and national death registration") ///
      contact("ian.hambleton@uwi.edu") /// 
      outfile("$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.yml")
restore






** --------------------------------------------------------------
** (6) CASE FATALITY DATASET - interim dataset - save
** --------------------------------------------------------------
preserve
   keep eid dco dco_alt etype doe yoe moe agey age5 age70 sex parish dodi sadi dod
   label data "BNR-CVD CASE-FATALITY dataset: prepared by Ian Hambleton, ${todayiso}"
   note : Input dataset = 2009-2023_identifiable_restructured_cvd.dta
   note : Prepared by Ian Hambleton, GA-CDRC, UWI
   note : Date created = ${todayiso}
   note : Input dataset created by J.Campbell, 25-Oct-2025 
   save "$BNR_PRIVATE_WORK/bnrcvd_case_fatality_2023_v1.dta", replace
** Associated YAML metadata file - create and save
   local dataset "$BNR_PRIVATE_WORK/bnrcvd_case_fatality_2023_v1.dta"
   * Generate YAML
   bnryaml using "`dataset'", ///
      title("BNR-CVD CASE FATALITY Dataset (Identifiable)") ///
      version("1.0") ///
      created("${todayiso}") ///
      creator("Ian Hambleton") ///
      tier("DEID") ///
      temporal("2009-01 to 2023-12") ///
      spatial("Barbados") ///
      description("Deindentified event dataset with deaths joined for analysis of in-hospital deaths.") ///
      registry("CVD") ///
      content("INDIV") ///
      language("en") ///
      format("Stata 19") ///
      rights("Restricted - internal analytical use only") ///
      source("Hospital admissions (QEH) and national death registration") ///
      contact("ian.hambleton@uwi.edu") /// 
      outfile("$BNR_PRIVATE_WORK/bnrcvd_case_fatality_2023_v1.yml")
restore


** --------------------------------------------------------------
** (7) LENGTH OF STAY DATASET - interim dataset - save
** --------------------------------------------------------------
preserve
   keep eid dco dco_alt etype doe yoe moe doa htoa mtoa agey age5 age70 sex parish dodi sadi dod
   label data "BNR-CVD LENGTH of STAY dataset: prepared by Ian Hambleton, ${todayiso}"
   note : Input dataset = 2009-2023_identifiable_restructured_cvd.dta
   note : Prepared by Ian Hambleton, GA-CDRC, UWI
   note : Date created = ${todayiso}
   note : Input dataset created by J.Campbell, 25-Oct-2025 
   save "$BNR_PRIVATE_WORK/bnrcvd_los_2023_v1.dta", replace

** Associated YAML metadata file - create and save
   local dataset "$BNR_PRIVATE_WORK/bnrcvd_los_2023_v1.dta"
   * Generate YAML
   bnryaml using "`dataset'", ///
      title("BNR-CVD LENGTH OF STAY Dataset (Identifiable)") ///
      version("1.0") ///
      created("${todayiso}") ///
      creator("Ian Hambleton") ///
      tier("DEID") ///
      temporal("2009-01 to 2023-12") ///
      spatial("Barbados") ///
      description("Deindentified event dataset with deaths joined for analysis of in-hospital length of stay.") ///
      registry("CVD") ///
      content("INDIV") ///
      language("en") ///
      format("Stata 19") ///
      rights("Restricted - internal analytical use only") ///
      source("Hospital admissions (QEH) and national death registration") ///
      contact("ian.hambleton@uwi.edu") /// 
      outfile("$BNR_PRIVATE_WORK/bnrcvd_los_2023_v1.yml")
restore



** --------------------------------------------------------------
** (8) PERFORMANCE METRICS DATASET - interim dataset - save
** --------------------------------------------------------------
**
** QM1:  Proportion of patients with MI receiving aspirin within 24 hrs
**       doa htoa mtoa asp1 asp2 asp3 aspdose doasp htoasp mtoasp asptimeampm_2
**
** QM2:  Proportion of STEMI patients who received reperfusion via fibrinolysis
**       htype (for STEMI) repertype (any non-missing value)
**
** QM3:  Median time to reperfusion for STEMI cases
**       doa htoa mtoa ecg doecg htecg mtecg repertype dore htore mtore
**
** QM4:  Proportion of patients receiving an echocardiogram before discharge
**       ecg doecg htecg mtecg
**
** QM5:  Documented aspirin prescribed at discharge
**       dmed1 (consider also those on chronic use at admission: asp2)
**
** QM6:  Documented statins prescribed at discharge
**       dmed5
   keep  eid dco dco_alt etype doe yoe moe htoe mtoe agey age5 age70 sex ///
         doa htoa mtoa ///
         htecg mtecg ///
         doasp htoasp mtoasp asp_ampm /// 
         dore htore mtore /// 
         asp1 asp2 asp3 aspdose   /// 
         htype reperf repertype ///
         ecg doecg    ///
         dmed1 dmed5 
   label data "BNR-CVD PERFORMANCE-METRICS dataset: prepared by Ian Hambleton, ${todayiso}"
   note : Input dataset = 2009-2023_identifiable_restructured_cvd.dta
   note : Prepared by Ian Hambleton, GA-CDRC, UWI
   note : Date created = ${todayiso}
   note : Input dataset created by J.Campbell, 25-Oct-2025 
   save "$BNR_PRIVATE_WORK/bnrcvd_performance_2023_v1.dta", replace
** Associated YAML metadata file - create and save
   local dataset "$BNR_PRIVATE_WORK/bnrcvd_performance_2023_v1.dta"
   * Generate YAML
   bnryaml using "`dataset'", ///
      title("BNR-CVD COUNT Dataset (Identifiable)") ///
      version("1.0") ///
      created("${todayiso}") ///
      creator("Ian Hambleton") ///
      tier("DEID") ///
      temporal("2009-01 to 2023-12") ///
      spatial("Barbados") ///
      description("Deindentified event dataset for analysis of performance metrics.") ///
      registry("CVD") ///
      content("INDIV") ///
      language("en") ///
      format("Stata 19") ///
      rights("Restricted - internal analytical use only") ///
      source("Hospital admissions (QEH)") ///
      contact("ian.hambleton@uwi.edu") /// 
      outfile("$BNR_PRIVATE_WORK/bnrcvd_performance_2023_v1.yml")







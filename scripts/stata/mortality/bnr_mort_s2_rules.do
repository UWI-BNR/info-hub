/*******************************************************************************
DO-FILE:     bnr_mort_s2_rules.do
FILE VERSION: 1.0.0 (19 August 2026)
CLASSIFIER:   0.6.1 (FROZEN)
PROJECT:     BNR Refit Phase 2
PURPOSE:     Explicit mortality Step 2 terminology and evidence rules.

CALLER:      bnr_mort_s2_classify.do

IMPORTANT:
             This file is not designed to run standalone.

             Required matching variables:
                 m1a m1b m1c m1d m2a m2b

             Rules are deliberately conservative. They distinguish detection
             of disease wording from inference about approximate underlying
             cause.

             No rule in this file performs full formal ICD-10 coding.

             New causal promotions must have an entry in:
                 bnr_mort_s2_nosology.csv

EVIDENCE:
             1 Clear
             2 Likely
             3 Possible
             4 Mention only
             5 No evidence

SCENARIOS:
             Conservative = class 1
             Primary      = classes 1-2
             Inclusive    = classes 1-3

RULE-ID CONVENTION:
             HRT_C...  BNR-Heart Clear
             HRT_L...  BNR-Heart Likely
             HRT_P...  BNR-Heart Possible
             HRT_M...  BNR-Heart Mention only
             HRT_N...  BNR-Heart No evidence

             STR_...   equivalent BNR-Stroke rules

             Stable rule IDs are analytical provenance. Do not recycle an ID
             for a materially different rule after release.

             Routine operation must NOT edit this frozen rule file. Any future
             terminology or classification change is a new classifier version
             and requires deliberate review and documentation.
*******************************************************************************/

* =============================================================================
* PLAIN-LANGUAGE RULE MAP - READ THIS BEFORE THE CODE
*
* The short rule IDs below are stored in the classified DTA as row-level
* provenance. They answer: 'Which final plain rule led to this evidence class?'
*
* They are deliberately simple. A rule is not a diagnosis and it is not a
* complete ICD underlying-cause coding decision. If a certificate cannot be
* resolved with these few rules, the method leaves uncertainty visible.
*
* BNR-HEART RULES
* ----------------
*   HRT_N000 [No evidence]: No qualifying BNR-Heart evidence was detected on
*   the certificate.
*   HRT_M001 [Mention only]: Heart-related context was detected, but it does
*   not by itself support BNR-Heart as the approximate underlying cause.
*   HRT_M002 [Mention only]: Current direct BNR-Heart wording appears only
*   in Part II.
*   HRT_M003 [Mention only]: Only historical BNR-Heart evidence is present
*   outside a current Part I Heart sequence.
*   HRT_M004 [Mention only]: Sudden cardiac death is written above another
*   Part I cause on a certificate whose line order is preserved.
*   HRT_P001 [Possible]: Current direct BNR-Heart evidence appears somewhere
*   in Part I, but a simple rule does not resolve it as the approximate
*   underlying cause.
*   HRT_P002 [Possible]: The certificate explicitly gives Heart and Stroke
*   as alternatives, for example 'heart attack or stroke'.
*   HRT_P003 [Possible]: Current BNR-Heart and BNR-Stroke evidence both
*   appear in Part I.
*   HRT_P005 [Possible]: Sudden cardiac death appears alone or as the lowest
*   Part I condition, or the original certificate line order is not
*   preserved.
*   HRT_P006 [Possible]: Historical-only Heart evidence appears in Part I
*   with no separate current Heart evidence.
*   HRT_L001 [Likely]: Current direct BNR-Heart evidence is on the lowest
*   used Part I line of a reasonably formed multi-line certificate.
*   HRT_L010 [Likely]: Explicit AMI appears above a lowest Part I
*   ischaemic/coronary Heart condition.
*   HRT_L011 [Likely]: Current BNR-Heart evidence appears above hypertension
*   on the lowest used Part I line.
*   HRT_L012 [Likely]: Current BNR-Heart evidence appears above
*   atherosclerosis on the lowest used Part I line.
*   HRT_L020 [Likely]: A record that would otherwise be Clear is capped at
*   Likely because the original certificate line structure is concatenated
*   or uncertain.
*   HRT_C001 [Clear]: One clean Part I line contains current direct
*   BNR-Heart evidence, with no competing Heart/Stroke ambiguity.
*
* BNR-STROKE RULES
* -----------------
*   STR_N000 [No evidence]: No qualifying BNR-Stroke evidence was detected
*   on the certificate.
*   STR_M001 [Mention only]: Stroke-related context was detected, but it
*   does not by itself support BNR-Stroke as the approximate underlying
*   cause.
*   STR_M002 [Mention only]: Current direct BNR-Stroke wording appears only
*   in Part II.
*   STR_M003 [Mention only]: Only historical or post-stroke evidence is
*   present, with no separate current Stroke evidence.
*   STR_P001 [Possible]: Current direct BNR-Stroke evidence appears
*   somewhere in Part I, but a simple rule does not resolve it as the
*   approximate underlying cause.
*   STR_P002 [Possible]: The certificate explicitly gives Heart and Stroke
*   as alternatives, for example 'stroke or heart attack'.
*   STR_P003 [Possible]: Current BNR-Stroke and BNR-Heart evidence both
*   appear in Part I.
*   STR_P010 [Possible]: Generic non-traumatic intracranial haemorrhage or
*   bleed appears in Part I without a more specific direct Stroke
*   expression.
*   STR_P011 [Possible]: Current Stroke is recorded in Part II while the
*   only Part I condition is a simple aspiration pneumonia or pneumonitis.
*   STR_L001 [Likely]: Current direct BNR-Stroke evidence is on the lowest
*   used Part I line of a reasonably formed multi-line certificate.
*   STR_L010 [Likely]: Current BNR-Stroke evidence appears above
*   hypertension on the lowest used Part I line.
*   STR_L011 [Likely]: Current BNR-Stroke evidence appears above
*   atherosclerosis on the lowest used Part I line.
*   STR_L012 [Likely]: Current Stroke appears immediately above a final
*   simple aspiration pneumonia or pneumonitis line on a certificate with
*   preserved line structure.
*   STR_L020 [Likely]: A record that would otherwise be Clear is capped at
*   Likely because the original certificate line structure is concatenated
*   or uncertain.
*   STR_C001 [Clear]: One clean Part I line contains current direct
*   BNR-Stroke evidence, with no competing Heart/Stroke ambiguity.
*
* Reporting scenarios are derived from the evidence class, not from the rule ID:
*   Conservative = Clear
*   Primary      = Clear + Likely
*   Inclusive    = Clear + Likely + Possible
*
* For more explanation, including why each rule receives its class and which
* source supports it, see bnr_mort_s2_rule_dictionary.csv and
* bnr_mort_s2_nosology.csv.
* =============================================================================

version 19


* =============================================================================
* SECTION 1 - FROZEN CLASSIFIER TERMINOLOGY
* APPROVED TERMINOLOGY
*
* This section was analyst-editable during classifier development. It is now
* frozen at classifier definition v0.6.1. Routine analysts should not change
* these expressions. A future change must create a new classifier version and
* be reviewed against real BNR certificate text.
*
* The terminology is deliberately short and explicit. This classifier is a
* practical surveillance approximation, not a replacement for formal UCoD
* coding software.
*
* Causal/position logic below is NOT routine analyst-editable.
* =============================================================================


* =============================================================================
* SECTION 1A - EXPLICIT AMI WORDING
*
* AMI remains an important diagnostic basis within BNR-Heart. Requiring a
* myocardial-like expression plus infarction-like wording avoids the historical
* false-positive problem where "myocard" alone captured myocarditis/fibrosis.
*
* Pass 6 adds only observed high-specificity variants, including coronary artery
* thrombosis and "infartion" misspelling.
* =============================================================================

foreach x in 1a 1b 1c 1d 2a 2b {

    generate byte ami_inf_`x' = ///
        strpos(m`x', "infarct") > 0 | ///
        strpos(m`x', "infarc") > 0 | ///
        strpos(m`x', "infart") > 0 | ///
        strpos(m`x', "infraction") > 0 | ///
        strpos(m`x', "infacrt") > 0 | ///
        strpos(m`x', "infaraction") > 0 | ///
        strpos(m`x', "infac") > 0

    generate byte ami_myo_`x' = ///
        strpos(m`x', "myocard") > 0 | ///
        strpos(m`x', "myocad") > 0 | ///
        strpos(m`x', "mycoard") > 0 | ///
        strpos(m`x', "myoard") > 0 | ///
        strpos(m`x', "myocrad") > 0 | ///
        strpos(m`x', "myocarial") > 0 | ///
        strpos(m`x', "miocard") > 0 | ///
        strpos(m`x', "mycard") > 0 | ///
        strpos(m`x', "muocard") > 0 | ///
        strpos(m`x', "mypcard") > 0 | ///
        strpos(m`x', "myodard") > 0

    generate byte ami_cor_thromb_`x' = ///
        strpos(m`x', "coronary thromb") > 0 | ///
        strpos(m`x', "coronary artery thromb") > 0 | ///
        strpos(m`x', "coronary arterial thromb") > 0

    generate byte ami_dir_`x' = ///
        (ami_inf_`x' & ami_myo_`x') | ///
        ami_cor_thromb_`x' | ///
        strpos(m`x', "heart attack") > 0 | ///
        strpos(m`x', "heart infarct") > 0 | ///
        ustrregexm(m`x', "(^| )nstemi( |$)") | ///
        ustrregexm(m`x', "(^| )stemi( |$)")

    label variable ami_dir_`x' ///
        "Explicit AMI wording detected on certificate line `x'"
}


* =============================================================================
* SECTION 1B - BNR-HEART ISCHAEMIC / CORONARY WORDING
*
* BNR-Heart mortality surveillance is broader than literal AMI wording. The
* historical BNR fatal-event pathway used IHD/coronary evidence as a death-
* certificate ascertainment source. Explicit AMI remains separately visible.
*
* Pass 6 adds only high-specificity terms observed in the complete Pass 5 audit.
* Generic cardiac arrest and heart failure remain insufficient on their own.
* =============================================================================

foreach x in 1a 1b 1c 1d 2a 2b {

    generate byte hrt_ihd_`x' = ///
        strpos(m`x', "ischaemic heart disease") > 0 | ///
        strpos(m`x', "ischemic heart disease") > 0 | ///
        strpos(m`x', "ischaemic cardiac disease") > 0 | ///
        strpos(m`x', "ischemic cardiac disease") > 0 | ///
        strpos(m`x', "acute coronary syndrome") > 0 | ///
        strpos(m`x', "coronary artery disease") > 0 | ///
        strpos(m`x', "coronary arterial disease") > 0 | ///
        strpos(m`x', "coronary heart disease") > 0 | ///
        strpos(m`x', "atherosclerotic heart disease") > 0 | ///
        strpos(m`x', "coronary atherosclerosis") > 0 | ///
        strpos(m`x', "coronary sclerosis") > 0 | ///
        strpos(m`x', "myocardial ischaemia") > 0 | ///
        strpos(m`x', "myocardial ischemia") > 0 | ///
        strpos(m`x', "cardiac ischaemia") > 0 | ///
        strpos(m`x', "cardiac ischemia") > 0 | ///
        strpos(m`x', "ischaemic cardiomyopathy") > 0 | ///
        strpos(m`x', "ischemic cardiomyopathy") > 0 | ///
        strpos(m`x', "angina pectoris") > 0 | ///
        strpos(m`x', "unstable angina") > 0 | ///
        strpos(m`x', "stable angina") > 0 | ///
        strpos(m`x', "microvascular angina") > 0

    generate byte hrt_scd_`x' = ///
        strpos(m`x', "sudden cardiac death") > 0

    generate byte hrt_dir_`x' = ///
        ami_dir_`x' | hrt_ihd_`x'

    generate byte hrt_ctx_`x' = hrt_scd_`x'

    label variable hrt_ihd_`x' ///
        "BNR-Heart IHD/coronary wording on certificate line `x'"
    label variable hrt_scd_`x' ///
        "Sudden cardiac death wording on certificate line `x'"
    label variable hrt_dir_`x' ///
        "Direct BNR-Heart family wording on certificate line `x'"
}


* =============================================================================
* SECTION 1C - BNR-STROKE DIRECT WORDING
*
* Direct Stroke wording covers explicit stroke/CVA terminology, specified brain
* infarction/thrombosis and specified non-traumatic cerebral haemorrhage.
*
* Pass 6 adds only high-specificity expressions found in the full audit:
* - anatomically specified "bleed" wording;
* - cerebellar/pontine/brainstem/thalamic haemorrhage wording;
* - specified cerebral/basilar artery thrombosis;
* - acute/ischaemic/haemorrhagic cerebrovascular-event wording.
*
* Heat stroke and post-stroke wording are not treated as current acute Stroke.
* =============================================================================

foreach x in 1a 1b 1c 1d 2a 2b {

    generate byte str_heat_`x' = ///
        strpos(m`x', "heat stroke") > 0 | ///
        strpos(m`x', "heatstroke") > 0

    generate byte str_word_`x' = ///
        (ustrregexm(m`x', "(^| )strokes?( |$)") | ///
         ustrregexm(m`x', "(^| )stoke( |$)") | ///
         ustrregexm(m`x', "(^| )troke( |$)") | ///
         ustrregexm(m`x', "(^| )strke( |$)") | ///
         ustrregexm(m`x', "(^| )srtroke( |$)") | ///
         ustrregexm(m`x', "(^| )stroe( |$)") | ///
         ustrregexm(m`x', "(^| )strokje( |$)") | ///
         strpos(m`x', "strokewith") > 0) & ///
        !str_heat_`x'

    generate byte str_acc_`x' = ///
        ((strpos(m`x', "cerebro") > 0 | ///
          strpos(m`x', "cerbro") > 0 | ///
          strpos(m`x', "carebro") > 0) & ///
         strpos(m`x', "accid") > 0) | ///
        strpos(m`x', "cerebral vascular accident") > 0 | ///
        strpos(m`x', "cerebralvascular accident") > 0 | ///
        strpos(m`x', "cerebrovascular attack") > 0

    generate byte str_event_`x' = ///
        strpos(m`x', "ischaemic cerebrovascular event") > 0 | ///
        strpos(m`x', "ischemic cerebrovascular event") > 0 | ///
        strpos(m`x', "ischaemic cerebral vascular event") > 0 | ///
        strpos(m`x', "ischemic cerebral vascular event") > 0 | ///
        strpos(m`x', "haemorrhagic cerebrovascular event") > 0 | ///
        strpos(m`x', "hemorrhagic cerebrovascular event") > 0 | ///
        strpos(m`x', "acute cerebrovascular event") > 0

    generate byte str_inf_`x' = ///
        (strpos(m`x', "infarct") > 0 | ///
         strpos(m`x', "infarc") > 0 | ///
         strpos(m`x', "infaraction") > 0) & ///
        (strpos(m`x', "cerebral") > 0 | ///
         strpos(m`x', "cerebell") > 0 | ///
         strpos(m`x', "brainstem") > 0 | ///
         strpos(m`x', "brain stem") > 0 | ///
         strpos(m`x', "pontine") > 0 | ///
         strpos(m`x', "middle cerebral artery") > 0 | ///
         strpos(m`x', "basal ganglia") > 0 | ///
         strpos(m`x', "thalam") > 0)

    generate byte str_thromb_`x' = ///
        strpos(m`x', "cerebral thrombosis") > 0 | ///
        strpos(m`x', "cerebral artery thromb") > 0 | ///
        strpos(m`x', "cerebral arterial thromb") > 0 | ///
        strpos(m`x', "basilar artery thromb") > 0 | ///
        strpos(m`x', "basilar arterial thromb") > 0

    generate byte str_trauma_`x' = ///
        strpos(m`x', "trauma") > 0 | ///
        strpos(m`x', "traumatic") > 0 | ///
        strpos(m`x', "injury") > 0 | ///
        strpos(m`x', "gunshot") > 0 | ///
        strpos(m`x', "stab wound") > 0 | ///
        strpos(m`x', "blunt force") > 0 | ///
        strpos(m`x', "road traffic") > 0

    generate byte str_hem_new_`x' = ///
        (strpos(m`x', "bleed") > 0 & ///
         (strpos(m`x', "intracere") > 0 | ///
          strpos(m`x', "intraventric") > 0 | ///
          strpos(m`x', "intraparen") > 0 | ///
          strpos(m`x', "cerebral") > 0 | ///
          strpos(m`x', "cerebell") > 0 | ///
          strpos(m`x', "pontine") > 0 | ///
          strpos(m`x', "brainstem") > 0 | ///
          strpos(m`x', "brain stem") > 0 | ///
          strpos(m`x', "basal ganglia") > 0 | ///
          strpos(m`x', "thalam") > 0)) | ///
        ((strpos(m`x', "haemorr") > 0 | strpos(m`x', "hemorr") > 0 | ///
          strpos(m`x', "hemmor") > 0 | strpos(m`x', "heamorr") > 0) & ///
         (strpos(m`x', "cerebell") > 0 | ///
          strpos(m`x', "pontine") > 0 | ///
          strpos(m`x', "brainstem") > 0 | ///
          strpos(m`x', "brain stem") > 0 | ///
          strpos(m`x', "basal ganglia") > 0 | ///
          strpos(m`x', "thalam") > 0))

    generate byte str_hem_`x' = ///
        (((strpos(m`x', "haemorr") > 0 | ///
           strpos(m`x', "hemorr") > 0 | ///
           strpos(m`x', "hemmor") > 0 | ///
           strpos(m`x', "heamorr") > 0) & ///
          (strpos(m`x', "intracere") > 0 | ///
           strpos(m`x', "intracer") > 0 | ///
           strpos(m`x', "intrace") > 0 | ///
           strpos(m`x', "intra cerebral") > 0 | ///
           strpos(m`x', "intraventric") > 0 | ///
           strpos(m`x', "intraparen") > 0 | ///
           strpos(m`x', "cerebral haemorr") > 0 | ///
           strpos(m`x', "cerebral hemorr") > 0 | ///
           strpos(m`x', "subarach") > 0 | ///
           strpos(m`x', "subarch") > 0 | ///
           strpos(m`x', "subarac") > 0 | ///
           strpos(m`x', "sub arach") > 0 | ///
           strpos(m`x', "cerebell") > 0 | ///
           strpos(m`x', "pontine") > 0 | ///
           strpos(m`x', "brainstem") > 0 | ///
           strpos(m`x', "brain stem") > 0 | ///
           strpos(m`x', "basal ganglia") > 0 | ///
           strpos(m`x', "thalam") > 0)) | ///
         str_hem_new_`x') & ///
        !str_trauma_`x'

    generate byte str_dir_`x' = ///
        str_word_`x' | ///
        ustrregexm(m`x', "(^| )cva( |$)") | ///
        str_acc_`x' | ///
        str_event_`x' | ///
        str_inf_`x' | ///
        str_thromb_`x' | ///
        str_hem_`x'

    label variable str_dir_`x' ///
        "Direct BNR-Stroke wording detected on certificate line `x'"
}


* =============================================================================
* SECTION 1D - BNR-STROKE CONTEXT / UNCERTAIN WORDING
*
* Broad cerebrovascular expressions remain context rather than automatic direct
* Stroke evidence.
*
* Generic non-traumatic intracranial haemorrhage/bleed is retained separately.
* It is too broad for Primary because the BNR acute-Stroke definition excludes
* subdural and epidural haemorrhage, but it can support Possible/Inclusive when
* no excluded site or trauma is stated. See NOS020.
* =============================================================================

foreach x in 1a 1b 1c 1d 2a 2b {

    generate byte str_intracranial_`x' = ///
        strpos(m`x', "intracran") > 0 & ///
        (strpos(m`x', "haemorr") > 0 | ///
         strpos(m`x', "hemorr") > 0 | ///
         strpos(m`x', "bleed") > 0) & ///
        strpos(m`x', "subdural") == 0 & ///
        strpos(m`x', "sub dural") == 0 & ///
        strpos(m`x', "epidural") == 0 & ///
        strpos(m`x', "extra dural") == 0 & ///
        strpos(m`x', "extradural") == 0 & ///
        !str_trauma_`x'

    generate byte str_ctx_`x' = ///
        strpos(m`x', "cerebrovascular disease") > 0 | ///
        strpos(m`x', "cerebro vascular disease") > 0 | ///
        strpos(m`x', "cerebrovascular event") > 0 | ///
        strpos(m`x', "cerebral vascular event") > 0 | ///
        strpos(m`x', "cerebrovascular incident") > 0 | ///
        strpos(m`x', "cerebral ischaemia") > 0 | ///
        strpos(m`x', "cerebral ischemia") > 0 | ///
        str_intracranial_`x'

    generate byte str_asp_`x' = ///
        (strpos(m`x', "aspirat") > 0 | strpos(m`x', "appirat") > 0) & ///
        strpos(m`x', "pneum") > 0

    * For the narrow causal-sequence rule below, require the aspiration line
    * to be simple rather than a line carrying several conditions. This keeps
    * NOS021 deliberately conservative and easy to explain.
    generate byte str_asp_simple_`x' = str_asp_`x' & ///
        strpos(t`x', ",") == 0 & strpos(t`x', ";") == 0 & ///
        strpos(t`x', "/") == 0 & ///
        !regexm(m`x', "(^| )and( |$)|(^| )or( |$)")

    label variable str_ctx_`x' ///
        "BNR-Stroke context wording detected on certificate line `x'"
    label variable str_intracranial_`x' ///
        "Generic non-traumatic intracranial haemorrhage/bleed on line `x'"
    label variable str_asp_`x' ///
        "Aspiration pneumonia/pneumonitis wording on certificate line `x'"
    label variable str_asp_simple_`x' ///
        "Simple aspiration pneumonia/pneumonitis line for NOS021"
}


* =============================================================================
* SECTION 2 - DO NOT TOUCH THIS SECTION
* Certificate structure
*
* Provenance:
*   NOS001 - international certificate structure
*   NOS002 - WHO Step SP3
* =============================================================================

generate str5 p1_pattern = ""

replace p1_pattern = p1_pattern + "a" if m1a != ""
replace p1_pattern = p1_pattern + "b" if m1b != ""
replace p1_pattern = p1_pattern + "c" if m1c != ""
replace p1_pattern = p1_pattern + "d" if m1d != ""

replace p1_pattern = "blank" if p1_pattern == ""

generate byte p1_low = 0
replace p1_low = 1 if m1a != ""
replace p1_low = 2 if m1b != ""
replace p1_low = 3 if m1c != ""
replace p1_low = 4 if m1d != ""

label define p1low ///
    0 "No Part I cause" ///
    1 "I(a)" ///
    2 "I(b)" ///
    3 "I(c)" ///
    4 "I(d)", replace

label values p1_low p1low
label variable p1_low "Lowest used Part I line"

generate byte p1_gap = ///
    !inlist(p1_pattern, "a", "ab", "abc", "abcd", "blank")

generate byte i1a_long = ///
    ustrlen(t1a) >= 120 & t1a != ""

generate byte i1a_multi = ///
    strpos(m1a, " and ") > 0 | ///
    strpos(m1a, " or ") > 0 | ///
    strpos(t1a, ";") > 0 | ///
    strpos(t1a, "/") > 0

label variable p1_gap "Gapped/non-standard Part I line pattern"
label variable i1a_long "Part I(a) at least 120 characters"
label variable i1a_multi "Part I(a) contains simple multi-condition separator"


* =============================================================================
* SECTION 3 - DO NOT TOUCH THIS SECTION
* Disease-specific historical wording
*
* Historical wording is applied to the specific certificate line, not to the
* whole record. This prevents a separate "prior stroke/MI" statement from
* suppressing a current acute target on another line.
*
* Bare "old" is not used as a generic prefix because phrases such as "old age"
* created false historical flags in the full audit.
*
* "Probable", "possible" and similar uncertainty words do NOT downgrade a
* diagnosis: WHO ICD-10 Volume 2 section 4.3.2 says such expressions are ignored
* for mortality coding. See NOS005.
* =============================================================================

foreach x in 1a 1b 1c 1d 2a 2b {

    generate byte hrt_hist_`x' = ///
        hrt_dir_`x' & ( ///
        ustrregexm(m`x', ///
        "(history of|previous|prior|remote|status post).{0,40}(myocard|heart attack|stemi|nstemi|ischaemic heart|ischemic heart|coronary|ischaemic cardiomyopathy|ischemic cardiomyopathy)") | ///
        ustrregexm(m`x', ///
        "(^| )post (myocard|heart attack|stemi|nstemi|ischaemic heart|ischemic heart|coronary)") | ///
        ustrregexm(m`x', ///
        "(^| )old (myocard|heart attack|stemi|nstemi|ischaemic heart|ischemic heart|coronary)") )

    generate byte str_hist_`x' = ///
        str_dir_`x' & ( ///
        ustrregexm(m`x', ///
        "(history of|previous|prior|remote|status post).{0,35}(strokes?|cva|cerebro|cerebral|intracere|subarach)") | ///
        ustrregexm(m`x', "(^| )post (strokes?|cva)( |$)") | ///
        ustrregexm(m`x', ///
        "(^| )old (strokes?|cva|cerebro|cerebral|intracere|subarach)") )

    generate byte ami_current_`x' = ami_dir_`x' & !hrt_hist_`x'
    generate byte hrt_current_`x' = hrt_dir_`x' & !hrt_hist_`x'
    generate byte str_current_`x' = str_dir_`x' & !str_hist_`x'
}


* =============================================================================
* SECTION 4 - DO NOT TOUCH THIS SECTION
* Aggregate position flags
* =============================================================================

generate byte ami_dir_p1 = ///
    ami_dir_1a | ami_dir_1b | ami_dir_1c | ami_dir_1d

generate byte ami_dir_p2 = ///
    ami_dir_2a | ami_dir_2b

generate byte hrt_ihd_p1 = ///
    hrt_ihd_1a | hrt_ihd_1b | hrt_ihd_1c | hrt_ihd_1d

generate byte hrt_ihd_p2 = ///
    hrt_ihd_2a | hrt_ihd_2b

generate byte hrt_scd_p1 = ///
    hrt_scd_1a | hrt_scd_1b | hrt_scd_1c | hrt_scd_1d

generate byte hrt_scd_p2 = ///
    hrt_scd_2a | hrt_scd_2b

generate byte hrt_dir_p1 = ///
    hrt_dir_1a | hrt_dir_1b | hrt_dir_1c | hrt_dir_1d

generate byte hrt_dir_p2 = ///
    hrt_dir_2a | hrt_dir_2b

generate byte hrt_current_p1 = ///
    hrt_current_1a | hrt_current_1b | hrt_current_1c | hrt_current_1d

generate byte hrt_current_p2 = ///
    hrt_current_2a | hrt_current_2b

generate byte hrt_ctx_p1 = hrt_scd_p1
generate byte hrt_ctx_p2 = hrt_scd_p2

generate byte str_dir_p1 = ///
    str_dir_1a | str_dir_1b | str_dir_1c | str_dir_1d

generate byte str_dir_p2 = ///
    str_dir_2a | str_dir_2b

generate byte str_current_p1 = ///
    str_current_1a | str_current_1b | str_current_1c | str_current_1d

generate byte str_current_p2 = ///
    str_current_2a | str_current_2b

generate byte str_ctx_p1 = ///
    str_ctx_1a | str_ctx_1b | str_ctx_1c | str_ctx_1d

generate byte str_ctx_p2 = ///
    str_ctx_2a | str_ctx_2b

generate byte hrt_hist_p1 = ///
    hrt_hist_1a | hrt_hist_1b | hrt_hist_1c | hrt_hist_1d

generate byte hrt_hist_p2 = ///
    hrt_hist_2a | hrt_hist_2b

generate byte str_hist_p1 = ///
    str_hist_1a | str_hist_1b | str_hist_1c | str_hist_1d

generate byte str_hist_p2 = ///
    str_hist_2a | str_hist_2b

generate byte str_intracranial_p1 = ///
    str_intracranial_1a | str_intracranial_1b | ///
    str_intracranial_1c | str_intracranial_1d

generate byte str_intracranial_p2 = ///
    str_intracranial_2a | str_intracranial_2b

generate byte hrt_at_low = ///
    (p1_low == 1 & hrt_current_1a) | ///
    (p1_low == 2 & hrt_current_1b) | ///
    (p1_low == 3 & hrt_current_1c) | ///
    (p1_low == 4 & hrt_current_1d)

generate byte str_at_low = ///
    (p1_low == 1 & str_current_1a) | ///
    (p1_low == 2 & str_current_1b) | ///
    (p1_low == 3 & str_current_1c) | ///
    (p1_low == 4 & str_current_1d)

generate byte hrt_scd_at_low = ///
    (p1_low == 1 & hrt_scd_1a) | ///
    (p1_low == 2 & hrt_scd_1b) | ///
    (p1_low == 3 & hrt_scd_1c) | ///
    (p1_low == 4 & hrt_scd_1d)

generate byte both_dir_p1 = ///
    hrt_current_p1 & str_current_p1

generate byte both_dir_any = ///
    (hrt_current_p1 | hrt_current_p2) & ///
    (str_current_p1 | str_current_p2)


* =============================================================================
* SECTION 4A - DO NOT TOUCH THIS SECTION
* Position and small provenance-backed relationship flags
*
* The classifier deliberately does NOT attempt a full causal-pair matrix.
* Named relationships are retained only where the rule can be stated plainly
* and tied to an external mortality-coding principle.
* =============================================================================

generate byte hrt_above_low = ///
    (p1_low >= 2 & hrt_current_1a) | ///
    (p1_low >= 3 & hrt_current_1b) | ///
    (p1_low >= 4 & hrt_current_1c)

generate byte ami_above_low = ///
    (p1_low >= 2 & ami_current_1a) | ///
    (p1_low >= 3 & ami_current_1b) | ///
    (p1_low >= 4 & ami_current_1c)

generate byte str_above_low = ///
    (p1_low >= 2 & str_current_1a) | ///
    (p1_low >= 3 & str_current_1b) | ///
    (p1_low >= 4 & str_current_1c)

generate byte hrt_scd_above_low = ///
    (p1_low >= 2 & hrt_scd_1a) | ///
    (p1_low >= 3 & hrt_scd_1b) | ///
    (p1_low >= 4 & hrt_scd_1c)

generate byte low_hyp = ///
    (p1_low == 1 & (strpos(m1a, "hypertension") > 0 | strpos(m1a, "hypertensive") > 0 | ustrregexm(m1a, "(^| )htn( |$)"))) | ///
    (p1_low == 2 & (strpos(m1b, "hypertension") > 0 | strpos(m1b, "hypertensive") > 0 | ustrregexm(m1b, "(^| )htn( |$)"))) | ///
    (p1_low == 3 & (strpos(m1c, "hypertension") > 0 | strpos(m1c, "hypertensive") > 0 | ustrregexm(m1c, "(^| )htn( |$)"))) | ///
    (p1_low == 4 & (strpos(m1d, "hypertension") > 0 | strpos(m1d, "hypertensive") > 0 | ustrregexm(m1d, "(^| )htn( |$)")))

generate byte low_athero = ///
    (p1_low == 1 & (strpos(m1a, "atheroscl") > 0 | strpos(m1a, "atherom") > 0)) | ///
    (p1_low == 2 & (strpos(m1b, "atheroscl") > 0 | strpos(m1b, "atherom") > 0)) | ///
    (p1_low == 3 & (strpos(m1c, "atheroscl") > 0 | strpos(m1c, "atherom") > 0)) | ///
    (p1_low == 4 & (strpos(m1d, "atheroscl") > 0 | strpos(m1d, "atherom") > 0))

generate byte low_ihd = ///
    (p1_low == 1 & hrt_ihd_1a) | ///
    (p1_low == 2 & hrt_ihd_1b) | ///
    (p1_low == 3 & hrt_ihd_1c) | ///
    (p1_low == 4 & hrt_ihd_1d)

* Pass 6: a narrowly defined reversed Stroke/aspiration sequence.
* WHO ICD-10 Volume 2 treats paralysing cerebrovascular disease as an obvious
* cause of pneumonia/aspiration. We use this only where current Stroke wording
* is immediately above a final aspiration-pneumonia/pneumonitis line and there
* is no further competing Part I cause. See NOS021.
generate byte str_asp_below = ///
    (p1_low == 2 & str_current_1a & str_asp_simple_1b) | ///
    (p1_low == 3 & str_current_1b & str_asp_simple_1c) | ///
    (p1_low == 4 & str_current_1c & str_asp_simple_1d)

* Part-II direct Stroke plus a sole aspiration complication in Part I remains
* uncertain, but stronger than Mention only. See NOS021.
generate byte str_p2_asp_support = ///
    p1_pattern == "a" & str_asp_simple_1a & ///
    str_current_p2 & !str_current_p1

label variable hrt_above_low "Current BNR-Heart evidence above lowest used Part I line"
label variable ami_above_low "Current explicit AMI evidence above lowest used Part I line"
label variable str_above_low "Current BNR-Stroke evidence above lowest used Part I line"
label variable hrt_scd_above_low "Sudden cardiac death wording above lowest used Part I line"
label variable low_hyp "Lowest used Part I line contains hypertension"
label variable low_athero "Lowest used Part I line contains atherosclerosis"
label variable low_ihd "Lowest used Part I line contains ischaemic/coronary heart disease"
label variable str_asp_below "Current Stroke immediately above final aspiration pneumonia/pneumonitis line"
label variable str_p2_asp_support "Part II current Stroke with sole Part I aspiration complication"


* =============================================================================
* SECTION 4B - DO NOT TOUCH THIS SECTION
* Source-structure confidence contract
*
* source_structure is created by the Step 2 controller before this rules file
* is called:
*     1 = certificate line structure preserved
*     2 = known BNR-concatenated representation
*     3 = structure/provenance uncertain
*
* This is a data-quality/provenance constraint, NOT an ICD-10 nosology rule.
* A record with source_structure 2 or 3 may still contain strong direct target
* wording, but the lost/uncertain causal-line order means it cannot support the
* highest-confidence Clear classification.
* =============================================================================


* =============================================================================
* SECTION 5 - DO NOT TOUCH THIS SECTION
* Explicit BNR-Heart-or-Stroke alternative wording
*
* NOS006:
* WHO ICD-10 Volume 2 section 4.3.3 gives "Stroke or heart attack" as an
* example coded to I99 because both alternatives are circulatory disorders.
*
* Pass 6 uses current, non-historical target expressions for this flag.
* =============================================================================

generate byte target_or = 0

foreach x in 1a 1b 1c 1d 2a 2b {
    replace target_or = 1 if ///
        hrt_current_`x' & str_current_`x' & ///
        ustrregexm(m`x', "(^| )or( |$)")
}

label variable target_or ///
    "Explicit alternative wording between current BNR-Heart and BNR-Stroke"


* =============================================================================
* SECTION 6 - DO NOT TOUCH THIS SECTION
* Evidence-class labels
* =============================================================================

label define mortcls ///
    1 "Clear" ///
    2 "Likely" ///
    3 "Possible" ///
    4 "Mention only" ///
    5 "No evidence", replace


* =============================================================================
* SECTION 7 - DO NOT TOUCH THIS SECTION
* BNR-Heart evidence class
*
* The target is the BNR-Heart mortality surveillance family, not literal AMI
* alone. Pass 6 keeps the decision tree deliberately short:
*
* - current direct Heart in Part I: Possible, rising to Likely by simple
*   certificate position or a named provenance-backed relationship;
* - current direct Heart in Part II only: Mention;
* - historical-only Heart in Part I: Possible; historical-only Part II: Mention;
* - sudden cardiac death alone: Possible only if sole/lowest in preserved Part I
*   or if source order is not preserved; otherwise Mention;
* - cardiac arrest/heart failure alone are not Heart triggers.
* =============================================================================

generate byte hrt_cls = 5
generate str10 hrt_rule = "HRT_N000"
generate str12 hrt_nos = ""
generate str24 hrt_basis = ""
generate str12 hrt_scope = ""

* Mention/context layer.
replace hrt_cls  = 4 if hrt_ctx_p1 | hrt_ctx_p2 | hrt_dir_p2
replace hrt_rule = "HRT_M001" if hrt_cls == 4

* Current direct Heart in Part II only.
replace hrt_cls  = 4 if hrt_current_p2 & !hrt_current_p1
replace hrt_rule = "HRT_M002" if hrt_current_p2 & !hrt_current_p1

* Historical-only Heart evidence starts at Mention.
replace hrt_cls  = 4 if ///
    (hrt_hist_p1 | hrt_hist_p2) & !hrt_current_p1 & !hrt_current_p2
replace hrt_rule = "HRT_M003" if ///
    hrt_cls == 4 & (hrt_hist_p1 | hrt_hist_p2) & ///
    !hrt_current_p1 & !hrt_current_p2

* Historical-only Heart in Part I is stronger than a Part II history, but does
* not establish a current acute Heart UCoD.
replace hrt_cls  = 3 if hrt_hist_p1 & !hrt_current_p1 & !hrt_current_p2
replace hrt_rule = "HRT_P006" if ///
    hrt_cls == 3 & hrt_hist_p1 & !hrt_current_p1 & !hrt_current_p2
replace hrt_nos  = "NOS017" if hrt_rule == "HRT_P006"

* Possible: current direct BNR-Heart disease evidence somewhere in Part I.
* v0.6.1: attach HRT_P001 only to records with current Part-I Heart evidence.
* This preserves HRT_P006 for historical-only Part-I Heart evidence; class and
* scenario membership are unchanged.
replace hrt_cls  = 3 if hrt_current_p1
replace hrt_rule = "HRT_P001" if hrt_cls == 3 & hrt_current_p1
replace hrt_rule = "HRT_P002" if hrt_cls == 3 & hrt_current_p1 & target_or
replace hrt_rule = "HRT_P003" if hrt_cls == 3 & hrt_current_p1 & str_current_p1

* Sudden cardiac death alone.
* - source order not preserved: keep Possible;
* - preserved structure and SCD sole/lowest in Part I: Possible;
* - preserved structure and SCD above another Part I cause: Mention.
replace hrt_cls  = 3 if ///
    hrt_scd_p1 & !hrt_current_p1 & !str_current_p1 & ///
    (source_structure != 1 | hrt_scd_at_low)
replace hrt_rule = "HRT_P005" if ///
    hrt_cls == 3 & hrt_scd_p1 & !hrt_current_p1 & !str_current_p1 & ///
    (source_structure != 1 | hrt_scd_at_low)
replace hrt_nos  = "NOS017" if hrt_rule == "HRT_P005"

replace hrt_cls  = 4 if ///
    source_structure == 1 & hrt_scd_above_low & ///
    !hrt_current_p1 & !str_current_p1
replace hrt_rule = "HRT_M004" if ///
    hrt_cls == 4 & source_structure == 1 & hrt_scd_above_low & ///
    !hrt_current_p1 & !str_current_p1
replace hrt_nos  = "NOS017" if hrt_rule == "HRT_M004"

* Likely: current direct BNR-Heart disease on the lowest used Part I line.
replace hrt_cls = 2 if ///
    hrt_at_low & !target_or & !str_current_p1 & ///
    !p1_gap & !i1a_long
replace hrt_rule = "HRT_L001" if hrt_cls == 2
replace hrt_nos  = "NOS002" if hrt_cls == 2

* NOS010: current explicit AMI above a lowest Part I IHD/coronary condition.
replace hrt_rule = "HRT_L010" if ///
    hrt_cls == 2 & ami_above_low & low_ihd & ///
    !target_or & !str_current_p1 & !p1_gap & !i1a_long
replace hrt_nos = "NOS010" if hrt_rule == "HRT_L010"

* NOS011: hypertension with current IHD/AMI -> IHD/AMI.
replace hrt_cls = 2 if ///
    hrt_above_low & low_hyp & !target_or & ///
    !str_current_p1 & !p1_gap & !i1a_long
replace hrt_rule = "HRT_L011" if hrt_cls == 2 & hrt_above_low & low_hyp
replace hrt_nos  = "NOS011" if hrt_rule == "HRT_L011"

* NOS012: atherosclerosis with current IHD/AMI -> IHD/AMI.
replace hrt_cls = 2 if ///
    hrt_above_low & low_athero & !low_hyp & !target_or & ///
    !str_current_p1 & !p1_gap & !i1a_long
replace hrt_rule = "HRT_L012" if ///
    hrt_cls == 2 & hrt_above_low & low_athero & !low_hyp
replace hrt_nos  = "NOS012" if hrt_rule == "HRT_L012"

* Clear: one clean Part I line only, with current direct BNR-Heart disease.
replace hrt_cls = 1 if ///
    p1_pattern == "a" & hrt_current_1a & !str_current_p1 & ///
    !target_or & !i1a_long & !i1a_multi
replace hrt_rule = "HRT_C001" if hrt_cls == 1
replace hrt_nos  = "NOS009" if hrt_cls == 1

* Source-structure confidence cap.
generate byte hrt_structure_cap = ///
    hrt_cls == 1 & source_structure != 1

replace hrt_cls = 2 if hrt_structure_cap == 1
replace hrt_rule = "HRT_L020" if hrt_structure_cap == 1
replace hrt_nos = "" if hrt_structure_cap == 1

label variable hrt_structure_cap ///
    "BNR-Heart Clear downgraded to Likely because source structure is not preserved"

* Diagnostic basis retained separately from the surveillance-family class.
replace hrt_basis = "Sudden cardiac death" if ///
    (hrt_scd_p1 | hrt_scd_p2) & hrt_cls < 5
replace hrt_basis = "IHD/coronary" if ///
    (hrt_ihd_p1 | hrt_ihd_p2) & hrt_cls < 5
replace hrt_basis = "Explicit AMI" if ///
    (ami_dir_p1 | ami_dir_p2) & hrt_cls < 5
replace hrt_basis = "AMI + IHD/coronary" if ///
    (ami_dir_p1 | ami_dir_p2) & (hrt_ihd_p1 | hrt_ihd_p2) & hrt_cls < 5

* NOS015: coronary thrombosis (including "coronary artery thrombosis") is
* treated as MI for mortality coding.
foreach x in 1a 1b 1c 1d 2a 2b {
    replace hrt_nos = "NOS015" if ///
        ami_cor_thromb_`x' & inrange(hrt_cls, 1, 3)
}

label values hrt_cls mortcls
label variable hrt_cls "Automated BNR-Heart approximate-UCoD evidence class"
label variable hrt_rule "BNR-Heart rule ID"
label variable hrt_nos "Primary provenance ID for BNR-Heart class"
replace hrt_scope = "NOS017" if hrt_cls < 5

label variable hrt_basis "BNR-Heart diagnostic basis"
label variable hrt_scope "BNR-Heart surveillance-scope provenance ID"


* =============================================================================
* SECTION 8 - DO NOT TOUCH THIS SECTION
* BNR-Stroke evidence class
*
* Pass 6 corrects the specific undercount pathways found in the complete audit
* without creating a general causal-pair engine:
*
* - current and historical Stroke mentions are separated line by line;
* - specified non-traumatic brain "bleed" wording is direct evidence;
* - generic non-traumatic intracranial haemorrhage/bleed is Possible only;
* - a narrow Stroke/aspiration relationship is recognised using WHO obvious-
*   cause guidance;
* - heat stroke and post-stroke sequela wording are not acute Stroke triggers.
* =============================================================================

generate byte str_cls = 5
generate str10 str_rule = "STR_N000"
generate str12 str_nos = ""
generate str32 str_basis = ""
generate str12 str_scope = ""

* Mention/context layer.
replace str_cls  = 4 if str_ctx_p1 | str_ctx_p2 | str_dir_p2
replace str_rule = "STR_M001" if str_cls == 4

* Current direct Stroke in Part II only.
replace str_cls  = 4 if str_current_p2 & !str_current_p1
replace str_rule = "STR_M002" if str_current_p2 & !str_current_p1

* Historical-only Stroke evidence remains Mention only.
replace str_cls  = 4 if ///
    (str_hist_p1 | str_hist_p2) & !str_current_p1 & !str_current_p2
replace str_rule = "STR_M003" if ///
    str_cls == 4 & (str_hist_p1 | str_hist_p2) & ///
    !str_current_p1 & !str_current_p2

* Possible: current direct BNR-Stroke in Part I.
replace str_cls  = 3 if str_current_p1
replace str_rule = "STR_P001" if str_cls == 3
replace str_rule = "STR_P002" if str_cls == 3 & target_or
replace str_rule = "STR_P003" if str_cls == 3 & hrt_current_p1

* NOS020: generic non-traumatic intracranial haemorrhage/bleed is compatible
* with acute Stroke but too broad for Primary because excluded haemorrhage
* subtypes cannot always be resolved from the wording.
replace str_cls = 3 if ///
    str_intracranial_p1 & !str_current_p1
replace str_rule = "STR_P010" if ///
    str_cls == 3 & str_intracranial_p1 & !str_current_p1
replace str_nos = "NOS020" if str_rule == "STR_P010"

* NOS021: current Stroke in Part II plus a sole Part I aspiration complication.
* Keep at Possible because Part II is not the stated causal sequence.
replace str_cls = 3 if ///
    str_p2_asp_support & !target_or & !hrt_current_p1
replace str_rule = "STR_P011" if ///
    str_cls == 3 & str_p2_asp_support & !target_or & !hrt_current_p1
replace str_nos = "NOS021" if str_rule == "STR_P011"

* Likely: current direct Stroke on the lowest used Part I line.
replace str_cls = 2 if ///
    str_at_low & !target_or & !hrt_current_p1 & ///
    !p1_gap & !i1a_long
replace str_rule = "STR_L001" if str_cls == 2
replace str_nos  = "NOS002" if str_cls == 2

* NOS021: current Stroke immediately above a final aspiration complication.
* This is deliberately narrow; other lower-line disease pairs remain Possible
* rather than being resolved through an expanding causal matrix.
replace str_cls = 2 if ///
    source_structure == 1 & str_asp_below & ///
    !target_or & !hrt_current_p1 & !p1_gap & !i1a_long
replace str_rule = "STR_L012" if ///
    str_cls == 2 & source_structure == 1 & str_asp_below
replace str_nos = "NOS021" if str_rule == "STR_L012"

* NOS013: hypertension with current cerebrovascular disease -> cerebrovascular disease.
replace str_cls = 2 if ///
    str_above_low & low_hyp & !target_or & ///
    !hrt_current_p1 & !p1_gap & !i1a_long
replace str_rule = "STR_L010" if str_cls == 2 & str_above_low & low_hyp
replace str_nos  = "NOS013" if str_rule == "STR_L010"

* NOS014: atherosclerosis with current cerebrovascular disease -> cerebrovascular disease.
replace str_cls = 2 if ///
    str_above_low & low_athero & !low_hyp & !target_or & ///
    !hrt_current_p1 & !p1_gap & !i1a_long
replace str_rule = "STR_L011" if ///
    str_cls == 2 & str_above_low & low_athero & !low_hyp
replace str_nos  = "NOS014" if str_rule == "STR_L011"

* Clear: one clean Part I line only, with current direct Stroke wording.
replace str_cls = 1 if ///
    p1_pattern == "a" & str_current_1a & !hrt_current_p1 & ///
    !target_or & !i1a_long & !i1a_multi
replace str_rule = "STR_C001" if str_cls == 1
replace str_nos  = "NOS009" if str_cls == 1

* Source-structure confidence cap.
generate byte str_structure_cap = ///
    str_cls == 1 & source_structure != 1

replace str_cls = 2 if str_structure_cap == 1
replace str_rule = "STR_L020" if str_structure_cap == 1
replace str_nos = "" if str_structure_cap == 1

label variable str_structure_cap ///
    "BNR-Stroke Clear downgraded to Likely because source structure is not preserved"

* Diagnostic basis for audit/interpretation.
replace str_basis = "Stroke/CVA" if ///
    (str_current_p1 | str_current_p2 | str_hist_p1 | str_hist_p2) & str_cls < 5

replace str_basis = "Cerebral infarct/thrombosis" if ///
    (str_inf_1a | str_inf_1b | str_inf_1c | str_inf_1d | str_inf_2a | str_inf_2b | ///
     str_thromb_1a | str_thromb_1b | str_thromb_1c | str_thromb_1d | str_thromb_2a | str_thromb_2b) & ///
    str_cls < 5

replace str_basis = "Cerebral haemorrhage" if ///
    (str_hem_1a | str_hem_1b | str_hem_1c | str_hem_1d | str_hem_2a | str_hem_2b) & ///
    str_cls < 5

replace str_basis = "Intracranial haemorrhage" if ///
    str_rule == "STR_P010"

* NOS019: Pass 6 high-specificity expansion for specified non-traumatic brain
* haemorrhage/bleed terminology found in the full certificate audit.
foreach x in 1a 1b 1c 1d 2a 2b {
    replace str_nos = "NOS019" if ///
        str_hem_new_`x' & inrange(str_cls, 1, 3)
}

* NOS016 remains the more specific provenance for non-traumatic
* intraventricular/intraparenchymal haemorrhage.
foreach x in 1a 1b 1c 1d 2a 2b {
    replace str_nos = "NOS016" if ///
        str_hem_`x' & ///
        (strpos(m`x', "intraventric") > 0 | strpos(m`x', "intraparen") > 0) & ///
        inrange(str_cls, 1, 3)
}

label values str_cls mortcls
label variable str_cls "Automated BNR-Stroke approximate-UCoD evidence class"
label variable str_rule "BNR-Stroke rule ID"
label variable str_nos "Primary provenance ID for BNR-Stroke class"
replace str_scope = "NOS018" if str_cls < 5

label variable str_basis "BNR-Stroke diagnostic basis"
label variable str_scope "BNR-Stroke surveillance-scope provenance ID"


* =============================================================================
* SECTION 9 - DO NOT TOUCH THIS SECTION
* Publication scenarios
* =============================================================================

generate byte hrt_cons = hrt_cls == 1
generate byte hrt_prim = inlist(hrt_cls, 1, 2)
generate byte hrt_incl = inrange(hrt_cls, 1, 3)

generate byte str_cons = str_cls == 1
generate byte str_prim = inlist(str_cls, 1, 2)
generate byte str_incl = inrange(str_cls, 1, 3)

label variable hrt_cons "BNR-Heart Conservative scenario: Clear"
label variable hrt_prim "BNR-Heart Primary scenario: Clear + Likely"
label variable hrt_incl "BNR-Heart Inclusive scenario: Clear + Likely + Possible"

label variable str_cons "BNR-Stroke Conservative scenario: Clear"
label variable str_prim "BNR-Stroke Primary scenario: Clear + Likely"
label variable str_incl "BNR-Stroke Inclusive scenario: Clear + Likely + Possible"


* =============================================================================
* SECTION 10 - DO NOT TOUCH THIS SECTION
* Combined BNR-Heart-or-Stroke endpoint
*
* This is NOT a measure of all cardiovascular mortality.
* =============================================================================

egen byte cvd_cls = rowmin(hrt_cls str_cls)

replace cvd_cls = 1 if target_or == 1

generate byte cvd_structure_cap = ///
    cvd_cls == 1 & source_structure != 1
replace cvd_cls = 2 if cvd_structure_cap == 1

label variable cvd_structure_cap ///
    "Combined Clear downgraded to Likely because source structure is not preserved"

label values cvd_cls mortcls
label variable cvd_cls ///
    "Combined BNR-Heart-or-Stroke endpoint evidence class"

generate byte cvd_cons = cvd_cls == 1
generate byte cvd_prim = inlist(cvd_cls, 1, 2)
generate byte cvd_incl = inrange(cvd_cls, 1, 3)

label variable cvd_cons "Combined CVD Conservative scenario"
label variable cvd_prim "Combined CVD Primary scenario"
label variable cvd_incl "Combined CVD Inclusive scenario"


* =============================================================================
* SECTION 11 - DO NOT TOUCH THIS SECTION
* Scenario-specific resolved surveillance family
*
* 0 = not in combined endpoint for this scenario
* 1 = resolved BNR-Heart
* 2 = resolved BNR-Stroke
* 3 = unresolved Heart/Stroke
* =============================================================================

label define cvdsub ///
    0 "Not included" ///
    1 "BNR-Heart" ///
    2 "BNR-Stroke" ///
    3 "Heart/Stroke unresolved", replace

generate byte cvd_sub_c = 0
replace cvd_sub_c = 1 if cvd_cons & hrt_cons & !str_cons
replace cvd_sub_c = 2 if cvd_cons & str_cons & !hrt_cons
replace cvd_sub_c = 3 if cvd_cons & cvd_sub_c == 0

generate byte cvd_sub_p = 0
replace cvd_sub_p = 1 if cvd_prim & hrt_prim & !str_prim
replace cvd_sub_p = 2 if cvd_prim & str_prim & !hrt_prim
replace cvd_sub_p = 3 if cvd_prim & cvd_sub_p == 0

generate byte cvd_sub_i = 0
replace cvd_sub_i = 1 if cvd_incl & hrt_incl & !str_incl
replace cvd_sub_i = 2 if cvd_incl & str_incl & !hrt_incl
replace cvd_sub_i = 3 if cvd_incl & cvd_sub_i == 0

label values cvd_sub_c cvdsub
label values cvd_sub_p cvdsub
label values cvd_sub_i cvdsub

label variable cvd_sub_c "Resolved surveillance family: Conservative"
label variable cvd_sub_p "Resolved surveillance family: Primary"
label variable cvd_sub_i "Resolved surveillance family: Inclusive"

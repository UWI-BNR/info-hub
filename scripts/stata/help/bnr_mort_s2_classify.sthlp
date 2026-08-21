{smcl}
{* *! package version 1.0.0; classifier definition 0.6.1 frozen; 19aug2026}{...}
{vieweralsosee "BNR mortality Step 2 dialog" "db bnr_mort_s2_classify"}{...}

{title:BNR Mortality Step 2: classify causes of death}

{pstd}
Step 2 applies the frozen BNR mortality classifier to the matching private
Step 1 all-deaths dataset.

{pstd}
It estimates whether {bf:BNR-Heart} or {bf:BNR-Stroke} is the approximate
underlying cause of death from the wording and structure of the medical
certificate.

{pstd}
This is a practical surveillance approximation. It is {bf:not} formal national
ICD-10 underlying-cause coding.

{title:Open the dialog}

{phang2}{cmd:db bnr_mort_s2_classify}

{title:Equivalent command-line use}

{phang2}{cmd:do "$BNR_STATA/mortality/bnr_mort_s2_classify.do" 2026 7}

{pstd}
Add {cmd:replace} as the third argument only when the same Step 2 release is
deliberately being rerun.

{title:Before running}

{pstd}
Run Mortality Step 1 for the same release first. Step 2 expects:

{phang2}
{cmd:$BNR_DATA_RAW/redcap/mortality/yYYYY/mMM/bnr_mort_s1_YYYYMM.dta}

{pstd}
Routine analysts should not edit {cmd:bnr_mort_s2_rules.do}. The classifier
definition is frozen at version 0.6.1.

{title:What the classifier means}

{pstd}
The classifier uses a deliberately small set of transparent rules. It looks at:

{phang2}the disease wording written on the certificate;{break}
{phang2}whether the wording appears in Part I or Part II;{break}
{phang2}the order of the Part I causal sequence;{break}
{phang2}a small number of documented mortality-coding principles; and{break}
{phang2}whether the original certificate line structure is preserved.

{pstd}
It does not use machine learning, fuzzy matching or an external NLP package.

{title:Evidence classes}

{phang}{bf:Clear} means the strongest evidence available to this practical BNR
method.

{phang}{bf:Likely} means good evidence for approximate underlying cause, but
some uncertainty remains.

{phang}{bf:Possible} means the attribution is plausible but materially
uncertain.

{phang}{bf:Mention only} means relevant wording is present but does not support
approximate-underlying-cause attribution.

{phang}{bf:No evidence} means the approved rules detected no qualifying
evidence.

{title:Sensitivity scenarios}

{phang}{bf:Conservative} = Clear only.

{phang}{bf:Primary} = Clear + Likely. This is the default reporting scenario
unless an approved product specification states otherwise.

{phang}{bf:Inclusive} = Clear + Likely + Possible.

{pstd}
These are {bf:classification-sensitivity scenarios}. They are not confidence
intervals and should not be described as statistical lower and upper bounds.

{title:BNR-Heart}

{pstd}
Fatal BNR-Heart surveillance is not restricted to certificates that literally
say acute myocardial infarction. Compatible ischaemic/coronary Heart wording
can also qualify.

{pstd}
The dataset retains {cmd:hrt_basis} so analysts can distinguish explicit AMI
from broader IHD/coronary evidence.

{pstd}
Cardiac arrest and heart failure alone are not sufficient BNR-Heart evidence.
Sudden cardiac death alone is retained as uncertain evidence rather than being
silently treated as confirmed AMI.

{title:BNR-Stroke}

{pstd}
BNR-Stroke follows the established acute Stroke surveillance family. The
classifier recognises direct Stroke/CVA wording, qualifying cerebral
infarction/thrombosis and qualifying non-traumatic brain haemorrhage.

{pstd}
Explicit traumatic, subdural, epidural/extradural and clearly historical or
post-stroke-only patterns are protected from direct acute-Stroke attribution.

{title:Source structure}

{pstd}
A separate source-structure variable records whether the original certificate
line structure is preserved, known to be historically concatenated, or
uncertain.

{pstd}
A record whose original line structure is not reliably known cannot remain
{bf:Clear}. If disease evidence would otherwise be Clear, it is capped at
{bf:Likely}.

{pstd}
The current historical fallback is a data-provenance rule, not a rule saying
that Heart or Stroke definitions changed by year.

{title:Residency}

{pstd}
Step 2 assumes that Barbados residency eligibility has already been checked by
the BNR team during review of each death certificate. It does not attempt to
reconstruct residency in Stata.

{title:DCO linkage}

{pstd}
Do not use Step 2 classification as the gate for future Death Certificate Only
event identification.

{pstd}
Future DCO processing is a separate workflow. It begins with the matching
private Step 1 {bf:all-deaths} dataset because Step 1 retains authorised
identity/linkage fields such as NRN. Selected Step 2 Heart/Stroke evidence is
then merged by {cmd:record_id}.

{pstd}
The Step 2 mortality class, rule, diagnostic basis, provenance and source
structure may support the DCO decision, but a mortality scenario flag must not
be used as an automatic DCO-event rule. Mortality attribution and evidence for
a registrable acute event are related but different questions.

{title:Private outputs}

{pstd}
A successful run creates:

{phang2}{cmd:bnr_mort_s2_YYYYMM.dta} - labelled private classified deaths;{break}
{phang2}{cmd:bnr_mort_s2_YYYYMM_summary.csv} - annual evidence-class counts;{break}
{phang2}{cmd:bnr_mort_s2_YYYYMM_review.csv} - focused private review queue;{break}
{phang2}{cmd:bnr_mort_s2_YYYYMM_structure_summary.csv} - source-structure QA;{break}
{phang2}{cmd:bnr_mort_s2_YYYYMM_manifest.yml} - operational receipt;{break}
{phang2}private Stata log.

{pstd}
The final DTA deliberately omits the many temporary detector variables used
while the classifier runs. It retains the certificate evidence, final classes,
plain-language rule descriptions, provenance IDs, scenario flags and essential
QA/review information.

{title:Metadata and plain-language references}

{pstd}
The code folder contains four companion references:

{phang2}{cmd:bnr_mort_s2_rule_dictionary.csv} - what each rule ID means and why
it receives its evidence class;{break}
{phang2}{cmd:bnr_mort_s2_nosology.csv} - provenance principles with
plain-language interpretations;{break}
{phang2}{cmd:bnr_mort_s2_variable_dictionary.csv} - every retained DTA
variable;{break}
{phang2}{cmd:bnr_mort_s2_methods.md} - the complete plain-language method and
limitations.

{title:Confidentiality}

{pstd}
All Step 2 outputs are private. The final DTA does not carry direct identity or
linkage fields such as name, address or NRN, but it still contains internal
{cmd:record_id} and death-certificate text. It must never be copied into the
public repository.

{title:Human review}

{pstd}
The focused review CSV identifies records requiring BNR attention. Human
adjudication belongs in REDCap, not in a permanent local spreadsheet.

{pstd}
The agreed REDCap adjudication instrument has not yet been added to the
operational Step 1 extract. When it is implemented and tested, Step 1 should
re-extract those fields and Step 2 should use the documented human decision
while retaining the automated provenance.

{title:Read the final report}

{pstd}
A successful run ends with {bf:MORTALITY STEP 2: OPERATIONAL RUN SUMMARY}.
Check the release, classifier version, death count, Heart/Stroke scenario
counts, review count and source-structure counts.

{pstd}
If the run cannot continue, the final block is
{bf:MORTALITY STEP 2 DID NOT COMPLETE}. Correct the cause and rerun. Do not
manually edit generated output files.

{title:Change control}

{pstd}
Routine users must not change the frozen classifier rules. A future change to
terminology, evidence classes, causal rules or scenario membership requires a
new classifier-definition version, deliberate validation and updated metadata.

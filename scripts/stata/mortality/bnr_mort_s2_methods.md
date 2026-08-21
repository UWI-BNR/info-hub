# BNR Mortality Step 2: approximate underlying cause of death

**Operational package version:** 1.0.0  
**Frozen classifier definition:** 0.6.1  
**Freeze date:** 19 August 2026  
**Status:** Frozen for routine use

## 1. Purpose

Mortality Step 2 classifies each eligible death certificate for two BNR surveillance families:

- **BNR-Heart**; and
- **BNR-Stroke**.

The aim is to produce a transparent **BNR approximation of underlying cause of death (UCoD)** for routine mortality surveillance while Barbados does not provide BNR with a formally coded national UCoD.

This is deliberately a practical second-best method. It is useful because it is reproducible, auditable and understandable, but it is **not** a substitute for formal ICD mortality coding and it does not attempt to reproduce specialist software such as DORIS.

The central design principle is simple:

> Use a small number of explicit terminology, certificate-position and documented causal rules. When those rules do not resolve a certificate confidently, retain the uncertainty rather than hide it behind increasingly complex automation.

## 2. What Step 2 does not do

Step 2 does not:

- change the source wording on the death certificate;
- perform complete ICD-10 coding of every condition;
- claim to assign the official national underlying cause of death;
- infer a disease simply because a vague terminal mechanism such as cardiac arrest is present;
- use machine learning, fuzzy matching or an external NLP package;
- decide whether an unmatched death should become a Death Certificate Only (DCO) event;
- repeat the BNR residency-eligibility check.

All Step 2 outputs remain private.

## 3. Eligibility and residency assumption

The analytical input is the Step 1 private all-deaths mortality dataset.

For Step 2, **residency eligibility is assumed to have already been established by the BNR team during review of each death certificate**. Step 2 therefore does not attempt to reconstruct or re-check residency from analytical variables.

If the operating process changes in future, residency should be corrected upstream in the BNR data-management process rather than inferred silently in this classifier.

## 4. How to read a death certificate

The classifier uses the standard distinction between Part I and Part II of the medical certificate.

### Part I

Part I is intended to show the causal sequence leading to death:

- **Part I(a):** immediate condition leading to death;
- **Part I(b):** condition giving rise to I(a);
- **Part I(c):** earlier antecedent condition;
- **Part I(d):** still earlier antecedent condition, where used.

The lowest used Part I line is therefore important, but it is not treated as an infallible answer. The reported sequence still needs to be interpretable under the deliberately limited BNR rules.

Example:

```text
Part I(a)  Aspiration pneumonia
Part I(b)  Acute stroke
```

This supports Stroke more strongly than:

```text
Part I(a)  Acute stroke
Part I(b)  Diabetes mellitus
```

because the second certificate states another disease below the Stroke in the causal sequence.

### Part II

Part II contains other important conditions that contributed to death but are not stated as part of the Part I causal sequence.

For that reason, a Heart or Stroke term that occurs only in Part II is generally weaker evidence for approximate UCoD than the same term in Part I.

## 5. Evidence classes

Every death receives one Heart class and one Stroke class independently.

| Code | Class | Plain-language meaning |
|---|---|---|
| 1 | **Clear** | Strongest evidence available to this practical BNR method. |
| 2 | **Likely** | Good evidence for approximate UCoD, with some residual uncertainty. |
| 3 | **Possible** | Plausible approximate UCoD, but uncertainty is material. |
| 4 | **Mention only** | Relevant disease wording is present, but it does not support approximate-UCoD attribution. |
| 5 | **No evidence** | No qualifying evidence was detected by the approved rules. |

These classes describe **classification evidence**, not statistical probability.

## 6. Reporting sensitivity scenarios

The three scenarios are derived directly from the evidence class:

| Scenario | Included classes | Interpretation |
|---|---|---|
| **Conservative** | Clear only | Most restrictive classification. |
| **Primary** | Clear + Likely | Default BNR reporting scenario. |
| **Inclusive** | Clear + Likely + Possible | Broader sensitivity scenario retaining materially uncertain cases. |

These scenarios are **not confidence intervals** and should not be described as statistical lower and upper confidence bounds.

## 7. BNR-Heart surveillance meaning

The fatal-event BNR-Heart surveillance family is broader than certificates that literally contain the words “acute myocardial infarction”.

Qualifying evidence includes:

- explicit AMI / STEMI / NSTEMI terminology;
- coronary thrombosis;
- compatible ischaemic heart disease and coronary disease terminology;
- selected specific ischaemic/coronary expressions documented in the frozen terminology rules.

The variable `hrt_basis` preserves the important distinction between:

- **Explicit AMI**;
- **IHD/coronary**;
- **AMI + IHD/coronary**; and
- **Sudden cardiac death**.

This prevents broader fatal BNR-Heart surveillance from being mislabeled as if every qualifying death were a clinically confirmed AMI.

### Cardiac arrest and heart failure

Cardiac arrest and heart failure alone are not treated as BNR-Heart UCoD evidence. They may be terminal consequences of many diseases.

If AMI/IHD is also present in the relevant causal sequence, the Heart classification is based on the AMI/IHD evidence, not on the arrest or heart failure itself.

### Sudden cardiac death

Sudden cardiac death is deliberately treated with caution:

- where it is alone or appears as the lowest Part I condition, it can remain **Possible**;
- where preserved line structure shows another Part I cause below it, it is **Mention only** unless independent Heart evidence is present;
- where old source text is concatenated and the original line order is not known, uncertainty is retained.

## 8. BNR-Stroke surveillance meaning

BNR-Stroke mortality follows the established acute Stroke surveillance family.

Direct evidence includes recognised acute Stroke/CVA terminology, cerebral infarction/thrombosis and qualifying non-traumatic intracerebral or related specified brain haemorrhage.

The classifier deliberately protects against obvious non-target expressions such as:

- heat stroke;
- traumatic haemorrhage;
- subdural / epidural / extradural haemorrhage;
- post-stroke wording when it only describes a previous event or sequela.

Generic non-traumatic intracranial haemorrhage is kept **Possible**, rather than automatically Primary, because the wording may be insufficient to distinguish every included and excluded haemorrhage subtype.

## 9. Source structure and confidence

Disease evidence and **source-data structure** are separate concepts.

`source_structure` has three values:

1. **Certificate lines preserved**
2. **Known BNR-concatenated representation**
3. **Structure/provenance uncertain**

A record whose original certificate line structure is not reliably preserved cannot remain **Clear**. If the disease rules would otherwise make it Clear, the result is capped at **Likely**.

This is a data-provenance safeguard, not a disease rule.

### Temporary historical fallback

The current Step 1 dataset does not yet supply an explicit source-structure field. Until it does, Step 2 uses a narrow historical fallback based on the confirmed BNR data lineage to identify the known old concatenated representation.

This fallback contains a date condition because it is reconstructing **data provenance**, not because Heart or Stroke classification changes by calendar year.

Once Step 1 supplies `mort_source_structure`, the explicit field takes precedence and the fallback is bypassed.

## 10. Plain-language Heart rules

### `HRT_N000` — No evidence

**Rule:** No qualifying BNR-Heart evidence was detected on the certificate.

**Why:** The automated rules found no explicit AMI, qualifying ischaemic/coronary Heart wording, or qualifying sudden-cardiac-death evidence.

**Provenance:** no separate nosology ID; this is a default classification state.

**Scenario use:** Not included.

### `HRT_M001` — Mention only

**Rule:** Heart-related context was detected, but it does not by itself support BNR-Heart as the approximate underlying cause.

**Why:** This is the general context/mention layer. Stronger rules can overwrite it when the certificate position and wording justify greater confidence.

**Provenance:** `NOS017`

**Scenario use:** Not included.

### `HRT_M002` — Mention only

**Rule:** Current direct BNR-Heart wording appears only in Part II.

**Why:** Part II records contributing conditions outside the stated Part I causal sequence, so a Part-II-only Heart statement is retained as a mention rather than treated as approximate underlying cause.

**Provenance:** `NOS001`

**Scenario use:** Not included.

### `HRT_M003` — Mention only

**Rule:** Only historical BNR-Heart evidence is present outside a current Part I Heart sequence.

**Why:** A previous, prior, remote or old Heart condition does not establish a current BNR-Heart underlying cause.

**Provenance:** `NOS017`

**Scenario use:** Not included.

### `HRT_M004` — Mention only

**Rule:** Sudden cardiac death is written above another Part I cause on a certificate whose line order is preserved.

**Why:** The certificate itself places another condition lower in the stated causal chain. Sudden cardiac death alone is therefore not promoted to approximate Heart underlying cause.

**Provenance:** `NOS017`

**Scenario use:** Not included.

### `HRT_P001` — Possible

**Rule:** Current direct BNR-Heart evidence appears somewhere in Part I, but a simple rule does not resolve it as the approximate underlying cause.

**Why:** The Heart diagnosis is real certificate evidence, but another lower Part I condition or structural issue leaves meaningful uncertainty.

**Provenance:** `NOS007`

**Scenario use:** Inclusive only.

### `HRT_P002` — Possible

**Rule:** The certificate explicitly gives Heart and Stroke as alternatives, for example 'heart attack or stroke'.

**Why:** The combined circulatory endpoint may be supported, but the Heart subtype cannot be resolved confidently from alternative wording.

**Provenance:** `NOS006`

**Scenario use:** Inclusive only.

### `HRT_P003` — Possible

**Rule:** Current BNR-Heart and BNR-Stroke evidence both appear in Part I.

**Why:** Both surveillance families are present in the stated causal sequence, so Heart is retained as possible rather than forced to be the sole subtype.

**Provenance:** `NOS006`

**Scenario use:** Inclusive only.

### `HRT_P005` — Possible

**Rule:** Sudden cardiac death appears alone or as the lowest Part I condition, or the original certificate line order is not preserved.

**Why:** Sudden cardiac death is within the historical BNR fatal-event ascertainment scope but is less specific than explicit AMI/IHD evidence.

**Provenance:** `NOS017`

**Scenario use:** Inclusive only.

### `HRT_P006` — Possible

**Rule:** Historical-only Heart evidence appears in Part I with no separate current Heart evidence.

**Why:** A historical Heart condition in the stated causal sequence is stronger than a Part-II history, but it still does not establish a current acute Heart underlying cause.

**Provenance:** `NOS017`

**Scenario use:** Inclusive only.

### `HRT_L001` — Likely

**Rule:** Current direct BNR-Heart evidence is on the lowest used Part I line of a reasonably formed multi-line certificate.

**Why:** The lowest used Part I line is the usual starting point for underlying-cause selection when the reported sequence is acceptable. The BNR approximation stops at Likely because it does not perform full formal ICD sequence validation.

**Provenance:** `NOS002`

**Scenario use:** Primary and Inclusive.

### `HRT_L010` — Likely

**Rule:** Explicit AMI appears above a lowest Part I ischaemic/coronary Heart condition.

**Why:** WHO mortality linkage rules support resolving the IHD/AMI combination toward acute myocardial infarction.

**Provenance:** `NOS010`

**Scenario use:** Primary and Inclusive.

### `HRT_L011` — Likely

**Rule:** Current BNR-Heart evidence appears above hypertension on the lowest used Part I line.

**Why:** WHO mortality linkage rules support assigning the ischaemic Heart disease rather than hypertension in this combination.

**Provenance:** `NOS011`

**Scenario use:** Primary and Inclusive.

### `HRT_L012` — Likely

**Rule:** Current BNR-Heart evidence appears above atherosclerosis on the lowest used Part I line.

**Why:** WHO mortality linkage rules support assigning the ischaemic Heart disease rather than atherosclerosis in this combination.

**Provenance:** `NOS012`

**Scenario use:** Primary and Inclusive.

### `HRT_L020` — Likely

**Rule:** A record that would otherwise be Clear is capped at Likely because the original certificate line structure is concatenated or uncertain.

**Why:** Strong disease wording remains useful, but lost or uncertain line order prevents the highest confidence level.

**Provenance:** `SOURCE_STRUCTURE`

**Scenario use:** Primary and Inclusive.

### `HRT_C001` — Clear

**Rule:** One clean Part I line contains current direct BNR-Heart evidence, with no competing Heart/Stroke ambiguity.

**Why:** With a single preserved Part I cause and no obvious structural ambiguity, the certificate provides the strongest evidence available to this BNR approximation.

**Provenance:** `NOS009`

**Scenario use:** Conservative, Primary and Inclusive.

## 11. Plain-language Stroke rules

### `STR_N000` — No evidence

**Rule:** No qualifying BNR-Stroke evidence was detected on the certificate.

**Why:** The automated rules found no direct or contextual Stroke evidence that meets the approved terminology rules.

**Provenance:** no separate nosology ID; this is a default classification state.

**Scenario use:** Not included.

### `STR_M001` — Mention only

**Rule:** Stroke-related context was detected, but it does not by itself support BNR-Stroke as the approximate underlying cause.

**Why:** This is the general context/mention layer. Stronger rules can overwrite it when wording and certificate position justify greater confidence.

**Provenance:** `NOS018`

**Scenario use:** Not included.

### `STR_M002` — Mention only

**Rule:** Current direct BNR-Stroke wording appears only in Part II.

**Why:** Part II records contributing conditions outside the stated Part I causal sequence, so a Part-II-only Stroke statement is normally retained as a mention.

**Provenance:** `NOS001`

**Scenario use:** Not included.

### `STR_M003` — Mention only

**Rule:** Only historical or post-stroke evidence is present, with no separate current Stroke evidence.

**Why:** Previous, prior, old or post-stroke wording does not establish a current acute Stroke underlying cause.

**Provenance:** `NOS018`

**Scenario use:** Not included.

### `STR_P001` — Possible

**Rule:** Current direct BNR-Stroke evidence appears somewhere in Part I, but a simple rule does not resolve it as the approximate underlying cause.

**Why:** The Stroke diagnosis is real certificate evidence, but another lower Part I condition or structural issue leaves meaningful uncertainty.

**Provenance:** `NOS007`

**Scenario use:** Inclusive only.

### `STR_P002` — Possible

**Rule:** The certificate explicitly gives Heart and Stroke as alternatives, for example 'stroke or heart attack'.

**Why:** The combined circulatory endpoint may be supported, but the Stroke subtype cannot be resolved confidently from alternative wording.

**Provenance:** `NOS006`

**Scenario use:** Inclusive only.

### `STR_P003` — Possible

**Rule:** Current BNR-Stroke and BNR-Heart evidence both appear in Part I.

**Why:** Both surveillance families are present in the stated causal sequence, so Stroke is retained as possible rather than forced to be the sole subtype.

**Provenance:** `NOS006`

**Scenario use:** Inclusive only.

### `STR_P010` — Possible

**Rule:** Generic non-traumatic intracranial haemorrhage or bleed appears in Part I without a more specific direct Stroke expression.

**Why:** The wording is compatible with acute Stroke but is too broad to exclude all non-Stroke intracranial haemorrhage subtypes confidently.

**Provenance:** `NOS020`

**Scenario use:** Inclusive only.

### `STR_P011` — Possible

**Rule:** Current Stroke is recorded in Part II while the only Part I condition is a simple aspiration pneumonia or pneumonitis.

**Why:** Stroke can plausibly cause aspiration, but its Part-II position prevents confident underlying-cause attribution.

**Provenance:** `NOS021`

**Scenario use:** Inclusive only.

### `STR_L001` — Likely

**Rule:** Current direct BNR-Stroke evidence is on the lowest used Part I line of a reasonably formed multi-line certificate.

**Why:** The lowest used Part I line is the usual starting point for underlying-cause selection when the reported sequence is acceptable. The BNR approximation stops at Likely because it does not perform full formal ICD sequence validation.

**Provenance:** `NOS002`

**Scenario use:** Primary and Inclusive.

### `STR_L010` — Likely

**Rule:** Current BNR-Stroke evidence appears above hypertension on the lowest used Part I line.

**Why:** WHO mortality linkage rules support assigning the cerebrovascular disease rather than hypertension in this combination.

**Provenance:** `NOS013`

**Scenario use:** Primary and Inclusive.

### `STR_L011` — Likely

**Rule:** Current BNR-Stroke evidence appears above atherosclerosis on the lowest used Part I line.

**Why:** WHO mortality linkage rules support assigning the cerebrovascular disease rather than atherosclerosis in this combination.

**Provenance:** `NOS014`

**Scenario use:** Primary and Inclusive.

### `STR_L012` — Likely

**Rule:** Current Stroke appears immediately above a final simple aspiration pneumonia or pneumonitis line on a certificate with preserved line structure.

**Why:** WHO mortality guidance recognises paralysing cerebrovascular disease as an obvious cause of pneumonia/aspiration. The BNR rule is deliberately restricted to this simple pattern.

**Provenance:** `NOS021`

**Scenario use:** Primary and Inclusive.

### `STR_L020` — Likely

**Rule:** A record that would otherwise be Clear is capped at Likely because the original certificate line structure is concatenated or uncertain.

**Why:** Strong disease wording remains useful, but lost or uncertain line order prevents the highest confidence level.

**Provenance:** `SOURCE_STRUCTURE`

**Scenario use:** Primary and Inclusive.

### `STR_C001` — Clear

**Rule:** One clean Part I line contains current direct BNR-Stroke evidence, with no competing Heart/Stroke ambiguity.

**Why:** With a single preserved Part I cause and no obvious structural ambiguity, the certificate provides the strongest evidence available to this BNR approximation.

**Provenance:** `NOS009`

**Scenario use:** Conservative, Primary and Inclusive.

## 12. Provenance register

The rule ID tells the analyst **which BNR rule was applied**.

The NOS ID tells the analyst **which external or BNR methodological principle supports that decision**, where a specific principle is required.

The complete operational register is `bnr_mort_s2_nosology.csv`. Its plain-language interpretation column is intended to be readable without specialist coding knowledge.

A blank `hrt_nos` or `str_nos` does not automatically mean that a classification is invalid. Some final states, such as the general default Possible state or a source-structure cap, are BNR workflow rules rather than direct implementations of one external nosology rule.

## 13. Review and human judgement

The classifier is deterministic. It does not learn from previous cases and it does not rewrite its own rules.

Step 2 creates a focused private review CSV for certificates with high-priority ambiguity or unusual target-bearing structure.

Human decisions belong in REDCap, not in a permanent local spreadsheet. The agreed future design is a small separate adjudication instrument in the existing mortality REDCap project. Once that instrument is implemented and tested:

1. the BNR reviewer opens the relevant death record;
2. records the adjudication in REDCap;
3. Step 1 extracts the adjudication fields on the next ordinary run;
4. Step 2 uses the documented human decision while preserving the automated classification and provenance.

The current frozen classifier does not invent or write those REDCap fields. Their integration should be added only after the REDCap instrument and exact field names have been approved.

## 14. DCO linkage is deliberately separate

The mortality classifier asks:

> Does the certificate support BNR-Heart or BNR-Stroke as the approximate underlying cause of death?

A future DCO workflow asks a different question:

> Does an unmatched death provide enough evidence that a registrable acute BNR-Heart or BNR-Stroke event occurred?

Those decisions are related but not identical.

Future DCO processing should therefore use **both private layers, for different purposes**:

1. begin with the matching **Step 1 all-deaths dataset**, because this remains the authoritative post-REDCap source for authorised identity and linkage fields such as NRN;
2. merge the relevant **Step 2 Heart/Stroke classification evidence** by `record_id`;
3. apply a separate, deliberately small DCO event-eligibility decision to unmatched deaths.

`record_id` is retained in the Step 2 DTA partly to make this private, release-matched merge straightforward. NRN is not duplicated into Step 2.

The future DCO layer should use the underlying evidence, such as Heart/Stroke class, rule, diagnostic basis, nosology provenance and source structure. The mortality sensitivity flags (`Conservative`, `Primary`, `Inclusive`) must not be treated as automatic DCO decisions. In particular, a death can reasonably qualify for BNR-Heart mortality because of IHD/coronary evidence while still providing insufficient evidence, on its own, to create an acute MI DCO event.

A death may be relevant to mortality surveillance but still provide insufficient evidence to create a DCO event. Conversely, a person may have a genuine BNR event and subsequently die from another underlying cause, so restricting linkage to Step 2-positive deaths could miss real event outcomes.

The design principle is therefore: **one certificate-interpretation layer, two downstream decisions**. Step 2 provides transparent mortality evidence; the future DCO workflow decides whether that evidence is sufficiently acute and specific to support a registrable event.

## 15. Final Step 2 private dataset

The operational Step 2 DTA is intentionally smaller than the development dataset.

It retains:

- the internal REDCap record ID;
- reporting time variables;
- limited demographic fields needed downstream;
- Step 1 QA flags;
- original and cleaned cause-of-death text;
- source-structure information;
- final Heart and Stroke classes;
- final rule IDs and plain-language rule descriptions;
- provenance IDs and diagnostic basis;
- sensitivity-scenario flags;
- combined Heart-or-Stroke endpoint variables;
- the focused review flag and reason.

It does **not** retain the many line-specific text-detector helper variables used internally while the classifier runs.

The DTA remains confidential because it contains `record_id` and certificate text.

The companion `bnr_mort_s2_variable_dictionary.csv` gives a plain-language description and retention reason for every variable saved in the DTA.

## 16. Routine outputs

For each release, Step 2 creates:

- `bnr_mort_s2_YYYYMM.dta` — private classified death-level dataset;
- `bnr_mort_s2_YYYYMM_summary.csv` — annual evidence-class counts;
- `bnr_mort_s2_YYYYMM_review.csv` — focused private review queue;
- `bnr_mort_s2_YYYYMM_structure_summary.csv` — source-structure QA summary;
- `bnr_mort_s2_YYYYMM_manifest.yml` — operational receipt;
- private Stata log.

The earlier development-only negative-audit and residual-Possible CSVs are not routine operational outputs after the freeze. They can be recreated deliberately in future method-development work if a new classifier version is being evaluated.

## 17. Change control

Classifier definition **0.6.1 is frozen**.

Routine analysts should not edit `bnr_mort_s2_rules.do`.

Any future change to:

- recognised terminology;
- evidence classes;
- Heart or Stroke causal/position rules;
- source-structure effect on class;
- Conservative / Primary / Inclusive membership;

constitutes a **new classifier definition** and requires:

1. a new classifier version;
2. deliberate review against real BNR certificates;
3. comparison with the frozen version;
4. updated rule and nosology metadata;
5. documentation and sign-off.

Changes to labels, notes or output packaging that do not alter classification can increment the operational script/package version while leaving the classifier-definition version unchanged.

## 18. Main reference sources

The frozen method was developed using the following source hierarchy:

1. **World Health Organization. ICD-10 Volume 2 Instruction Manual, Fifth edition (2016).** Used for death-certificate structure and mortality-selection principles.
2. **BNR established Heart and Stroke case-definition material**, including the historical Appendix C definitions used for BNR-Heart and BNR-Stroke event surveillance.
3. **Rose AM, Hambleton IR, Jeyaseelan SM, et al. Establishing national noncommunicable disease surveillance in a developing country: a model for small island nations. Rev Panam Salud Publica. 2016;39(2):76–85.** Used for BNR surveillance architecture, national death-register ascertainment and the original simplicity/economy design principle.
4. **BNR CVD Annual Report 2023.** Used as historical BNR reporting context and to understand the previous fatal-event ascertainment approach.
5. **NCHS/ACME mortality decision material**, where explicitly recorded in the nosology register as supplementary provenance.

The operational `bnr_mort_s2_nosology.csv` is the controlling detailed provenance register for the implemented classifier.

## 19. One-sentence interpretation for non-technical readers

> BNR uses a small, documented set of death-certificate rules to estimate whether Heart disease or Stroke probably started the chain of events leading to death; when the certificate does not support a confident answer, the uncertainty is kept visible rather than being guessed away.

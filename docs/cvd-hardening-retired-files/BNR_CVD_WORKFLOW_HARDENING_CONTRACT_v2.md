# BNR CVD events workflow hardening contract

**Status:** Approved amended design baseline for rate implementation  
**Version:** 2.0 (26 August 2026)  
**Applies from:** approval of the joint subtype estimator and rate-construction work  
**Replaces:** Version 1.0 of this contract. It retains the completed hardening decisions and adds the approved joint subtype and incidence-rate extensions.

## Purpose

This is the controlling contract for hardening the BNR CVD events workflow.
It records the agreed analytical, disclosure-control and operational boundaries
before code is changed. Read it before designing, changing, reviewing or
approving affected CVD workflow code.

The work is an incremental hardening of the existing workflow, not a rebuild.
The CVD and mortality workflows share the same release discipline but must not
be forced into identical epidemiological structures.

This amended contract incorporates the completed Stage 4A–4E-c work. It now
governs construction of annual crude and directly age-standardised national
incidence estimates for All-CVD, Heart and Stroke, including the approved
Primary and Inclusive DCO definitions.

## Fixed workflow boundary

The existing six operational Stata Steps remain in place:

1. Step 1 extracts private REDCap data.
2. Step 2 prepares the private confidential cumulative event dataset.
3. Step 3 prepares private, deidentified metric inputs.
4. Step 4 calculates and stages private metric outputs.
5. Step 5 applies deterministic disclosure control, prepares review material
   and records human approval.
6. Step 6 alone promotes an approved payload.

Stages are implementation work packages. They are not new menu Steps.
No Stage may weaken the compute → review → approve → publish separation.

## Fixed operational and disclosure policy

- Supporting frequencies **1–5** receive primary suppression. Zero is not
  automatically primary-suppressed.
- Analysts must not edit generated datasets, workbooks, suppression symbols,
  metadata or public-ready files by hand.
- Secondary, temporal and derived suppression must be deterministic,
  automated and visible in private QA.
- Before release, repeatedly test the complete proposed public release until
  no published additive, comparator or derived equation has exactly one
  protected term.
- A suppressed metric row has blank numeric value, numerator and denominator
  fields, a safe `display_value`, `suppression_status`, and a non-blank
  `disclosure_note`.
- Confidential linkage variables, DCO components and matching diagnostics are
  never copied to the public candidate or public-ready payload.
- Rates are calculated in Stata from private aggregate numerators and approved
  population denominators. The dashboard may display and filter released rate
  rows but must not calculate, combine or reconstruct them.

## Event terminology and legacy DCOs

The public CVD event families are **Heart**, **Stroke** and **All CVD**.
`heart`, `stroke` and `all_cvd` are the corresponding machine values. This is
a terminology correction reflecting the historic abstraction process; manuals
do not need to defend a former AMI label.

Imported legacy records with `dco == 1` are retained and flagged in Step 2 for
private comparison. They are excluded from hospital-recorded event metrics and
from the new linkage candidate pool. New DCOs are constructed consistently for
the analytical event range beginning in 2010 through the specified
mortality-linkage process. Records from 2008–09 do not enter the hardened CVD
incidence series.

## Distinct concepts — never overload one status field

| Concept | Public field | Allowed values | Meaning |
|---|---|---|---|
| Event ascertainment | `ascertainment_scope` | `hospital_only`, `hospital_plus_dco` | Whether the numerator includes estimated additional DCOs. |
| Mortality definition | `mortality_definition` | `not_applicable`, `primary`, `inclusive` | Mortality classification used only for DCO-enhanced values. |
| Estimate basis | `estimate_basis` | `observed`, `estimated` | Observed hospital metric or DCO-enhanced estimate. |
| Linkage uncertainty | `linkage_lower_value`, `linkage_upper_value` | numeric or missing | Bounds around DCO-enhanced central values only. |
| Disclosure control | `suppression_status` | `none`, `primary`, `secondary`, `temporal`, `derived` | Public release protection result. |
| Period completeness | `period_complete`, `status_flag` | `0/1`; `final`, `incomplete`, `insufficient_history` | Whether a value is analytically available. |

`source_status` is retained temporarily for backward compatibility, but
`ascertainment_scope` is authoritative in the hardened schema.

## Linkage and DCO contract

### Candidate pool and mortality definitions

- Run deterministic linkage once against the **Inclusive** mortality pool.
- Retain `primary` and `inclusive` classification flags from that same run.
- Primary and Inclusive are alternative selectable definitions, not lower and
  upper linkage bounds.
- Enforce the invariant that an Inclusive DCO-enhanced numerator cannot be
  below its Primary counterpart in an identical stratum and period.

### Deterministic person matching

Use canonical sex values and normalized names. Retain a private provenance
record for every mortality candidate.

1. **L01 — exact NRN:** exact valid NRN, with no material contradiction.
2. **L02 — full name, DOB and sex:** exact normalized full name, canonical sex,
   exact explicit/NRN-derived DOB, unique candidate.
3. **L03 — boundary names and demographic fallback:** exact first/surname
   boundary tokens in either order, canonical sex and exact DOB where available
   or compatible age otherwise, unique candidate.

The NRN is handled as text. Its initial `yymmdd` component may derive DOB only
after validity checks, leading-zero preservation/restoration checks and century
resolution using explicit CVD DOB first, then age and event/death dates. It is
never a stand-alone person match. Conflicting non-missing NRNs are unresolved;
a shared DOB cannot override that conflict.

### Episode linkage and DCO outcome

Person matching and episode linkage are separate operations.

- A same-person Heart or Stroke event **0–27 days before death** is an
  already-recorded event, not an additional DCO.
- No event in that window plus sufficient identity evidence is an additional
  DCO.
- Ambiguous identity, contradictory identifiers or insufficient evidence is
  unresolved.
- A same-person event more than 28 days before death is not an episode link
  and does not prevent an additional-DCO classification. Retain its indicator,
  nearest prior event date and elapsed days privately for QA.

Retain rule ID, linkage outcome, family concordance, matching-candidate count,
days to death and remote-event indicators privately. Do not publish individual
or component linkage evidence.

### Aggregate unresolved-link estimator

For each mortality definition and approved estimation stratum, estimate the
additional-DCO fraction among resolvable candidates:

\[
\hat p = \frac{A}{L + A},
\]

where `L` is an already-recorded 0–27-day event link and `A` is a deterministic
additional DCO. Apply `\hat p` to unresolved records `U` only at aggregate
level. No individual unresolved record is relabelled as a DCO.

Use the approved fallback hierarchy, separately within each mortality
definition and (for subtype work) category: target year; target year plus or
minus one year; then all available years. A selected source requires at least
20 resolved candidates. Otherwise record `insufficient_resolved` and do not
produce a central estimate.

### Joint Heart/Stroke/mixed allocation

The All-CVD Stage 4D DCO component is the fixed anchor. Stage 4E-c partitions
the candidate outcomes into three mutually exclusive categories:
`heart`, `stroke` and `mixed_unallocated`. Heart and Stroke require
family-concordant evidence. Both-family certificates, discordant episodes,
unclassified evidence and other unusable subtype information remain in
`mixed_unallocated` for accounting and private QA; they are not silently
forced into either subtype.

For the selected fallback source, category probabilities are calculated from
the observed deterministic additional-DCO composition:

\[
p_k = \frac{A_k}{\sum_k A_k}, \qquad k\in\{heart,stroke,mixed\}.
\]

For each category `k`, current-year deterministic additional DCOs are `A_k`.
Let `R_C` and `R_U` denote the All-CVD unresolved central and upper components,
respectively. The jointly allocated DCO components are:

\[
\begin{aligned}
\text{lower}_k &= A_k,\\
\text{central}_k &= A_k + p_k R_C,\\
\text{upper}_k &= A_k + p_k R_U.
\end{aligned}
\]

Thus, for every mortality definition, year and bound:

\[
\text{All-CVD}_b = \text{Heart}_b + \text{Stroke}_b + \text{mixed}_b.
\]

This is a structural accounting identity, not an assertion that Heart and
Stroke alone sum to All-CVD. The independent subtype estimator remains a
private sensitivity diagnostic; Stage 4E-c is the production subtype source.

### Incidence rates

The annual DCO-enhanced national numerator is the relevant joint component
plus the corresponding observed hospital-event count. For each published
series, the crude rate is:

\[
\text{crude rate per 100,000} =
\frac{\text{annual numerator}}{\text{annual Barbados population}}\times100,000.
\]

The rate is calculated separately for All-CVD, Heart and Stroke, and for the
Primary and Inclusive mortality definitions. Lower, central and upper DCO
rates use the same approved denominator. The mixed category is retained for
private accounting and QA and is not a public headline subtype.

Age-standardised rates use direct standardisation over 5-year age groups:

\[
ASR = \sum_i r_i w_i,
\]

where `r_i` is the Barbados age-specific rate and `w_i` is the proportion in
the fixed WHO World Standard Population. The standard has bands 0–4 through
95–99 plus 100+. If an input population source supplies only 85+, the WHO
weights are aggregated to 85+ and that mapping is recorded in metadata.
Weights are normalised to sum to one after importing the published rounded
weights. Records with unusable age remain in count and crude-rate numerators
but are excluded from age-standardised numerator construction and reported in
private QA.

### Denominators and standard population

Barbados denominators are drawn from the latest United Nations World Population
Prospects release, currently **WPP 2024**. The release, extraction date,
country code, sex, age-band mapping and population units are recorded with
each rate package. The fixed standard population is the WHO World Standard
Population based on the world average age structure for 2000–2025; it is not
updated when a new WPP release is issued. Five-year age intervals are the
required implementation grain; this is compatible with the WHO standard.

Authoritative references:

- United Nations DESA, *World Population Prospects 2024*:  
  https://population.un.org/wpp/
- WHO, *Age standardization of rates: a new WHO standard* (World Standard
  Population, 2000–2025):  
  https://cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/gpe_discussion_paper_series_paper31_2001_age_standardization_rates.pdf

## Public metric schema v2

All public data are calculated in Stata. The dashboard may filter, label and
format public rows but must never reconstruct values from suppressed components
or calculate epidemiological estimates.

| Field | Allowed values / type | Public applicability |
|---|---|---|
| `schema_version` | `bnr_cvd_public_metric_v2` | All rows |
| `metric_id` | `CVD-BURDEN-001`, `CVD-BURDEN-002`, `CVD-INCIDENCE-001` | As valid for the series below |
| `release_id` | `cvd_YYYY_MM` | All rows |
| `event_type` | `all_cvd`, `heart`, `stroke` | Valid lattice only |
| `sex` | `all`, `female`, `male` | Valid lattice only |
| `age_group` | `all`, `under_70`, `age_70_plus`, `age_standardised` (public); 5-year bands privately | Valid lattice only |
| `period_type` | `monthly`, `quarterly`, `annual` | Valid lattice only |
| Existing period fields | existing date/order fields | All rows |
| `ascertainment_scope` | `hospital_only`, `hospital_plus_dco` | All rows |
| `mortality_definition` | `not_applicable`, `primary`, `inclusive` | `primary`/`inclusive` only for DCO rows |
| `estimate_basis` | `observed`, `estimated` | All rows |
| `value` | number or blank | Central value; blank if suppressed |
| `numerator` | number or blank | Exact or estimated numerator; blank if suppressed |
| `denominator` | number or blank | Approved population denominator for rates |
| `linkage_lower_value` | number or blank | DCO rows only; blank with parent suppression |
| `linkage_upper_value` | number or blank | DCO rows only; blank with parent suppression |
| `comparison_n` | number or blank | Comparator only |
| `unit` | `count`, `percent`, `rate_per_100000` | All rows |
| `period_complete` | `0`, `1` | All rows |
| `status_flag` | `final`, `incomplete`, `insufficient_history` | All rows |
| `suppression_status` | fixed disclosure values above | All rows |
| `display_value` | safe text | All rows |
| `disclosure_note` | controlled text | All rows |

## Valid public series matrix

| Series | Metric / unit | Scope and definition | Event / sex / age | Period | Comparator or uncertainty |
|---|---|---|---|---|---|
| Monthly counts | Burden / count | Hospital only; observed | All CVD / all / all | Monthly | Fixed 2015–2019 seasonal reference asset only |
| Quarterly counts | Burden / count | Hospital only; observed | All CVD, Heart, Stroke / all, female, male / all | Quarterly | Same-period rolling five-year mean only when disclosure safe |
| Annual counts | Burden / count | Hospital only; observed | All CVD, Heart, Stroke / all, female, male / all | Annual | Same-period rolling five-year mean only when disclosure safe |
| Annual age counts | Burden / count | Hospital only; observed | All CVD / all / under 70, 70+ | Annual | Safe rolling mean where valid |
| Annual distributions | Burden / percent | Hospital only; observed | Existing approved distribution lattice | Annual | No DCO bounds |
| Annual national counts | Burden / count | Hospital + DCO; Primary or Inclusive | All CVD, Heart, Stroke / all / all | Annual | Central estimate plus linkage lower/upper values |
| Annual hospital rates | Incidence / rate per 100,000 | Hospital only; observed | All CVD, Heart, Stroke / all / all and age-standardised | Annual | Exact hospital rate |
| Annual national rates | Incidence / rate per 100,000 | Hospital + DCO; Primary or Inclusive | All CVD, Heart, Stroke / all / all and age-standardised | Annual | Central rate plus linkage lower/upper values |

Initial public DCO reporting is deliberately annual, sexes combined and all
ages. Keep sex-specific linkage fields and private diagnostics, but calculate
the public combined-sex series directly from records; do not derive it by
adding potentially suppressed public sex series.

National Heart and Stroke DCO-incidence estimates are included in the amended
annual rate contract. They remain separate estimates and must not be added to
reproduce All-CVD. `mixed_unallocated` remains private accounting output.

## Fixed monthly reference asset

The monthly dashboard uses a separately produced, checksum-bound public asset
covering calendar months in 2015–2019. It contains only hospital-only,
All-CVD, sexes-combined, all-age reference minimum, mean and maximum plus
method/version fields. It is not regenerated in routine monthly releases.

Step 4 validates the asset and Step 5 approval binds it alongside the candidate
dataset. The reference is a historical seasonal comparison, not an uncertainty
interval, forecast or rolling comparator.

## Required disclosure-equation audit

The hardening engine must construct and repeatedly audit, as applicable:

1. quarter = its three months;
2. annual = its four quarters;
3. annual = its twelve months where both resolutions are published;
4. all sex = female + male + unknown/other components where published;
5. All-CVD = Heart + Stroke + mixed/unallocated for the joint DCO components
   at lower, central and upper bounds;
6. rolling five-year comparators and overlapping comparator relationships; and
7. derived percentages, crude rates, directly standardised rates and DCO
   lower/central/upper values; and
8. Primary/Inclusive ordering and rate-bound propagation in every identical
   annual stratum.

The private review worklist must state the protected source cell, equation ID,
equation description, complementary cell selected and final public status.
Public outputs expose only safe values and the controlled disclosure note.

## Acceptance invariants

- Existing hospital-only values remain unchanged except for deliberately
  approved scope, terminology and disclosure changes.
- No public monthly sex, age or subtype row and no monthly rolling comparator
  is released.
- No protected value is recoverable from the complete proposed public release.
- All linkage-bound fields are absent or blank for hospital-only rows.
- Inclusive DCO-enhanced values are never below Primary values in the same
  annual stratum.
- Joint Heart + Stroke + mixed/unallocated components equal the All-CVD
  component at lower, central and upper bounds in every annual stratum.
- Every released rate uses the approved WPP 2024 Barbados denominator and the
  fixed WHO 2000–2025 World Standard weights where standardised.
- Crude and age-standardised rates are calculated in Stata, not in the
  dashboard, and their displayed values are suppressed whenever the parent
  numerator is suppressed.
- Suppressing a parent DCO-enhanced row suppresses all its bounds and numeric
  components.
- Records without usable age remain in count metrics but are flagged in private
  rate QA and excluded from age-standardised numerator construction.
- Legacy imported DCOs never enter the hospital-event or new-DCO numerator.

## Deferred, explicitly tracked work

- Issue #155: mortality evidence-class components.
- Issue #157: private n<10 suppression diagnostic; it must not alter routine
  n<6 publication policy.

## Change control

Any material alteration to the metric lattice, linkage rule hierarchy, 28-day
episode rule, estimator hierarchy, rate method, disclosure equations or public
fields requires a contract update, synthetic-test update and renewed review
before publication. Routine releases use the fixed approved contract.

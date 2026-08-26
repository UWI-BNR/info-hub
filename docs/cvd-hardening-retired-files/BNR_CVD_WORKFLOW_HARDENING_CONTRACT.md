# BNR CVD events workflow hardening contract

**Status:** Approved design baseline for implementation  
**Stage:** 1 — contract and synthetic-test foundation  
**Applies from:** the first hardening code change  
**Replaces:** no published metric definition; it governs the move from the existing public metric schema to the approved CVD hardening contract.

## Purpose

This is the controlling contract for hardening the BNR CVD events workflow.
It records the agreed analytical, disclosure-control and operational boundaries
before code is changed. Read it before designing, changing, reviewing or
approving affected CVD workflow code.

The work is an incremental hardening of the existing workflow, not a rebuild.
The CVD and mortality workflows share the same release discipline but must not
be forced into identical epidemiological structures.

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

## Event terminology and legacy DCOs

The public CVD event families are **Heart**, **Stroke** and **All CVD**.
`heart`, `stroke` and `all_cvd` are the corresponding machine values. This is
a terminology correction reflecting the historic abstraction process; manuals
do not need to defend a former AMI label.

Imported legacy records with `dco == 1` are retained and flagged in Step 2 for
private comparison. They are excluded from hospital-recorded event metrics and
from the new linkage candidate pool. New DCOs are constructed consistently for
the full event range through the specified mortality-linkage process.

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

where `L` is already-recorded event links and `A` is deterministic additional
DCOs. Apply `\hat p` to unresolved records `U` only at aggregate level:

\[
\widehat{U}_{DCO}=\hat p U.
\]

Use the approved fallback hierarchy where a stratum has fewer than 20 resolved
candidates. Record the selected estimation stratum and diagnostics privately.

For a hospital count or numerator `H`, deterministic additional DCOs `A`, and
unresolved records `U`, publish one central estimate and its linkage bounds:

\[
\begin{aligned}
\text{lower} &= H + A,\\
\text{central} &= H + A + \widehat{U}_{DCO},\\
\text{upper} &= H + A + U.
\end{aligned}
\]

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
| `age_group` | `all`, `under_70`, `age_70_plus`, `age_standardised` | Valid lattice only |
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
| Annual national counts | Burden / count | Hospital + DCO; Primary or Inclusive | All CVD / all / all | Annual | Central estimate plus linkage lower/upper values |
| Annual hospital rates | Incidence / rate per 100,000 | Hospital only; observed | All CVD, Heart, Stroke / all / age-standardised | Annual | Exact hospital rate |
| Annual national rate | Incidence / rate per 100,000 | Hospital + DCO; Primary or Inclusive | All CVD / all / age-standardised | Annual | Central rate plus linkage lower/upper values |

Initial public DCO reporting is deliberately annual, sexes combined and all
ages. Keep sex-specific linkage fields and private diagnostics, but calculate
the public combined-sex series directly from records; do not derive it by
adding potentially suppressed public sex series.

National Heart and Stroke DCO-incidence estimates may be calculated privately
for family-concordance evaluation. They are not initially part of the public
contract.

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
5. all CVD = Heart + Stroke only where the definition makes that equation
   valid; otherwise no false closure equation is asserted;
6. rolling five-year comparators and overlapping comparator relationships; and
7. derived percentages, rates and DCO lower/central/upper values.

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
- Suppressing a parent DCO-enhanced row suppresses all its bounds and numeric
  components.
- Records without usable age remain in count metrics but are flagged in private
  rate QA and excluded from age-standardised numerator construction.
- Legacy imported DCOs never enter the hospital-event or new-DCO numerator.

## Deferred, explicitly tracked work

- Issue #155: mortality evidence-class components.
- Issue #156: mortality dashboard rates after CVD incidence is proven.
- Issue #157: private n<10 suppression diagnostic; it must not alter routine
  n<6 publication policy.

## Change control

Any material alteration to the metric lattice, linkage rule hierarchy, 28-day
episode rule, estimator hierarchy, rate method, disclosure equations or public
fields requires a contract update, synthetic-test update and renewed review
before publication. Routine releases use the fixed approved contract.


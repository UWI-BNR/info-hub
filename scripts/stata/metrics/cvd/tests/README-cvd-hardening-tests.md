# BNR CVD hardening synthetic-test specification

**Status:** Stage 2 disclosure test implemented; other suites remain pending  
**Implemented test:** `test_bnr_cvd_stage2_disclosure.do`  
**Purpose:** Define reproducible regression tests before and alongside changes
to the hospital-only calculation and disclosure-control engine.

## Safety boundary

Every synthetic release must use a clearly impossible future release ID (for
example `cvd_2099_01`), carry `synthetic_test: true` in its metadata, and
contain `SYNTHETIC_TEST_ONLY.txt` in the staging package. Step 5 approval and
Step 6 publication must refuse a marked synthetic package.

Do not use confidential records in the test source. Commit only synthetic
source-generating code and its README; never commit generated DTA, CSV, Excel,
logs, ZIPs or review packages.

## Test suites and required scenarios

| Suite | Scenario | Required result |
|---|---|---|
| `scope` | Monthly public lattice contains only All CVD / all sex / all age counts | No monthly subtype, sex, age or rolling-comparator row reaches the candidate |
| `monthly_quarter` | A primary-suppressed monthly cell appears in a published quarterly total | Deterministic complementary protection closes the equation; no equation has one protected term |
| `monthly_annual` | A primary-suppressed monthly cell appears in a published annual total | Deterministic closure protects the annual reconstruction route |
| `quarter_annual` | A primary-suppressed quarterly cell appears in an annual total | Deterministic closure protects the annual reconstruction route |
| `rolling_direct` | A protected count enters a later same-period rolling five-year mean | The affected comparator is protected or a valid deterministic complementary solution closes the route |
| `rolling_overlap` | Overlapping rolling comparators create a subtraction route | Iterative audit reaches closure, not merely first-pass protection |
| `rolling_safe` | No protected component contributes to a comparator | Comparator remains published unchanged |
| `sex_combined` | Private sex-specific counts include small cells | Directly calculated public all-sex series is assessed only against its public equations; no unnecessary public-sex suppression is introduced |
| `age_scope` | Annual all-CVD under-70 and 70-plus counts are present | Existing approved age lattice remains available and safe |
| `candidate_integrity` | Protected values and associated numeric fields are present before public-candidate creation | Candidate blanks all protected numeric fields and retains a disclosure note |
| `approval_boundary` | Synthetic package supplied to approval/publish actions | Both actions stop before creating public-ready or website files |

`test_bnr_cvd_stage2_disclosure.do` (version 1.0.7) currently implements the
`monthly_quarter`, `monthly_annual`, `quarter_annual`, `rolling_direct` and
`candidate_integrity` checks using fabricated aggregate rows. It also confirms
that the public candidate excludes row-level disclosure provenance and that a
legacy `ami` predecessor is matched to the Stage 2 `heart` label for temporal
comparison. It asserts the private QA PASS result and never calls approval or
publication. The remaining scenarios stay required before final workflow
handover.

The test writes a persistent text log to
`$BNR_PRIVATE_LOGS/bnr_cvd_stage2_disclosure_test.log`. If an assertion fails,
upload that log together with the exact test version; it contains the
suppression table and all synthetic all-CVD time rows immediately before the
assertions.

## Future DCO test suite

The following tests are added with Stages 4–7, after confidential linkage and
DCO metrics exist. They must use wholly fabricated identifiable-looking test
values that cannot be mistaken for real people.

| Suite | Scenario | Required result |
|---|---|---|
| `nrn` | Valid NRN-derived DOB; missing leading zero; invalid date; century ambiguity | String handling and QA flags follow the contract; no invalid date creates a link |
| `link_rules` | L01, L02, L03, conflicting NRNs and non-unique candidates | Only unique qualifying candidates link; every result has a rule ID or unresolved reason |
| `episode_window` | Events 0, 27, 28 and more days before death | 0–27 days are linked episodes; 28+ days are remote/private diagnostics, not episode links |
| `estimator` | Resolved stratum at n=20, n=19 and fallback levels | Correct rate/fallback selection and aggregate unresolved estimate |
| `definition_nesting` | Primary and Inclusive candidate pools | Inclusive central/lower/upper values never fall below Primary equivalents |
| `dco_suppression` | Small DCO-enhanced annual count/rate | Parent, linkage bounds and numeric components are protected together |
| `rate_age_missing` | DCO candidate without usable age | Count retained; rate QA reports exclusion and reconciliation difference |

## Required test evidence

Each implemented suite must assert expected row counts, suppression statuses,
equation-audit results, QA-pass counts and the absence of public output. It
must end with a clear PASS message; reaching the final Stata line is not
sufficient.

On failure: stop before approval or publication, preserve the log and private
review artefacts, correct code or test design, and rerun. Generated outputs are
never manually edited to manufacture a pass.

## When to rerun

Run the relevant suite after a change to CVD Step 3 metric inputs, Step 4
calculation/staging, the shared suppression engine, CVD Step 5 review/approval,
the approved public metric schema, linkage rules, estimator or metadata/QA
receipt structure. Run the full suite before final workflow handover.

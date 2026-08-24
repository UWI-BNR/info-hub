# CVD workflow hardening — Stage 2 handover

## Purpose

This replacement package implements the approved Stage 2 hospital-only CVD
contract. It does not implement mortality linkage, DCO-enhanced metrics or
incidence rates; those remain later Stages.

## Install together

Replace the files at their matching repository paths, preserving the two
controlling documents already installed in `scripts/stata/metrics/cvd/`:

1. `scripts/stata/metrics/cvd/bnr_step4_cvd_burden.do`
2. `scripts/stata/monthly/bnr_step4_metrics.do`
3. `scripts/stata/common/bnr_step4_stage_metric.do`
4. `scripts/stata/common/bnr_step5_suppress.do`
5. `scripts/stata/metrics/cvd/bnr_step5_cvd_monthly_reference.do` (new)
6. `scripts/stata/monthly/bnr_step5_review.do`
7. `scripts/stata/monthly/bnr_step6_publish.do`
8. `scripts/stata/metrics/cvd/tests/README-cvd-hardening-tests.md`
9. `scripts/stata/metrics/cvd/tests/test_bnr_cvd_stage2_disclosure.do` (new)

The supplied copy of `BNR_CVD_WORKFLOW_HARDENING_CONTRACT.md` is unchanged;
retain the repository copy as the controlling contract.

## What changes

- Public monthly metrics are restricted to observed, hospital-only All-CVD,
  all-sex, all-age counts. Monthly rolling comparators are removed.
- `heart` replaces `ami` in calculated rows. Input values labelled AMI still
  map to `heart` for historic compatibility.
- Stage 2 writes schema-v2 scope fields with hospital-only values and blank
  linkage-bound fields.
- Step 5 repeatedly closes monthly–quarterly–annual additive equations and
  writes a private equation audit and row-level provenance audit for the
  workbook. The public candidate contains neither internal flags nor private
  temporal values.
- Previous-release temporal checks bridge legacy `ami` rows to the approved
  Stage 2 `heart` designation only for matching historical counterparts.
- A quarterly or annual five-year comparator is withheld whenever one of its
  five contributing counts is protected.
- The 2015–2019 monthly min/mean/max reference asset is created once on the
  first hardened release. Later releases copy and fingerprint the approved
  public asset; they do not recalculate it.
- Step 5 approval and Step 6 promotion bind the reference DTA, CSV and YAML.
  The approved payload is therefore ten files, not seven.

## Required local verification

1. Run `test_bnr_cvd_stage2_disclosure.do` after loading local BNR paths. It
   must end with its explicit PASS message.
2. Run CVD Step 4 for a non-production staging release. Confirm the Step 4 QA
   has thirteen PASS rows and contains the approved monthly lattice only.
3. Run Step 5 Prepare. Review the workbook's `Equation audit` and `Monthly
   reference` sheets; do not approve yet.
4. Inspect the candidate CSV: no suppressed row may retain `value`,
   `numerator`, `denominator` or a linkage-bound value; it must also exclude
   internal Step 4/5 flag, temporal and row-order helper fields. Review those
   fields only in the private `step5_row_audit.dta` and workbook sheets.
5. On the first hardened release, confirm the reference contains exactly 12
   calendar-month rows derived from 2015–2019. On later runs, verify its
   review-basis checksum matches the already-published asset.
6. After human approval, run Step 6 only in a safe test environment and check
   that its manifest and ZIP contain exactly ten payload files.

Do not manually edit generated candidate, reference, metadata, manifest or
review files to make a check pass.

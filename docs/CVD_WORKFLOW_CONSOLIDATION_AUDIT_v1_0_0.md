# CVD workflow consolidation audit

**Version:** 1.0.0 (28 August 2026)  
**Source reviewed:** `cvd-workflow-hardening` commit `42f5800a254a1143b9f4ec10f6303d9c1dd2fd42`

## Finding

The committed source contains the current combined Step 4 controller and the
tested expanded Step 5/6 controllers, but its canonical Step 5/6 filenames,
dialogs, help files and several technical QMD pages still describe the retired
burden-only workflow. This is an operational risk: the visible menu/help could
construct commands that do not match the current combined release package.

## Consolidation in this update

- Canonical Step 5 dispatches `prepare` and `approve` to the tested combined
  helpers; canonical Step 6 dispatches to the tested combined publisher.
- The Step 4, 5 and 6 dialogs and help files use the canonical arguments and
  combined staging/public locations.
- Technical workflow pages, the Stata README, reference index and approval
  guide describe the combined package and minimal website mirror.
- The controlling contract records the approved annual all-age
  `additional_dco` count scope and its count-identity protection rule.
- Public method pages explain the annual DCO count/rate scope without exposing
  private components.

## Deliberately deferred

`site/surveillance/cvd/metrics/burden/index.qmd` is not changed. It is a
burden-only dashboard source with retired data paths and controls; replacing it
is a separate dashboard project that must consume only
`site/downloads/files/metrics/cvd/cvd_metrics_current.csv`.

Historical handover material and files under `docs/cvd-hardening-retired-files/`
are retained as evidence. They are not active operational instructions and are
not rewritten to imply that they described the final architecture.

## Required local verification

1. Install this update over the committed source tree.
2. Check each dialog's generated command against the corresponding help page.
3. Run the existing Stage 4 and expanded Step 5 end-to-end regression tests.
4. Run a no-change Step 5 prepare/approve/Step 6 test only with an authorised
   test package; do not recreate a production approval casually.
5. Run `python site/scripts/build_download_catalogue.py` and inspect the
   dashboard transition note. An unchanged catalogue is valid when the release
   record and ZIP filename are unchanged.

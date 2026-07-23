# Steps 1–4 clean controller reporting

## Purpose

This bundle updates the presentation of the operational Steps 1–4 controllers.
It does not change their analytical methods, input contracts or output
locations.

The revised controllers:

- run routine Stata and helper code quietly after the private log opens;
- show a short run heading;
- end successful runs with one framed `STEP n: OPERATIONAL RUN SUMMARY`;
- end handled failures with one framed `STEP n DID NOT COMPLETE`;
- state the reason, private log path and safety boundary on failure; and
- keep the existing frame-based summaries and handover sequence.

## Revised controller versions

| Step | Controller | Version |
|---|---|---|
| 1 | `monthly/bnr_cvd_redcap_extract.do` | 1.1.0 |
| 2 | `monthly/bnr_cvd_prepare_confidential.do` | 1.1.0 |
| 3 | `monthly/bnr_cvd_create_metric_inputs.do` | 1.2.0 |
| 4 | `monthly/bnr_cvd_metric_controller.do` | 1.4.0 |

The corresponding Stata help files and monthly run guide are also updated.
Dialogs and common helpers are included unchanged so the bundle preserves the
working source structure.

## Install

1. Close Stata dialogs that use these files.
2. Back up the currently installed source bundle.
3. Copy the folders in this bundle into the corresponding `scripts/stata/`
   folders, preserving the folder structure.
4. Replace the four controller DO files and four help files.
5. Replace the current `bnr-monthly-cvd-run-guide.qmd` in its usual
   documentation location.
6. Restart Stata or reopen the relevant dialogs.

## Workstation checks

Stata 19 is not available in the build workspace. Run these checks on the
authorised BNR workstation before routine use.

For each step:

1. Run a successful test using a completed development release and explicit
   `replace` where that controller supports it.
2. Confirm the last substantive output is the framed operational summary.
3. Rerun without `replace` where replacement protection applies.
4. Confirm the last substantive output is the framed failure report followed
   only by Stata's return code.
5. Confirm the private log contains the short heading and final report, not the
   controller transcript.
6. Confirm the expected files and record counts are unchanged from the prior
   operational version.

Step 1 also needs one normal API extraction test because it contains the
embedded Python/PyCap operation.

## Safety boundary

Steps 1–3 remain private data preparation. Step 4 creates private staging only.
None of these controllers records approval or creates public or website files.

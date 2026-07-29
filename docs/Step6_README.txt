BNR STEP 6 PUBLICATION - INSTALLATION AND FIRST TEST
====================================================

Files in this bundle
--------------------

Replace or add the files at the matching relative paths:

  .gitignore
  scripts/stata/config/bnr_menu.do
  scripts/stata/dialogs/bnr_step6_publish.dlg
  scripts/stata/help/bnr_step6_publish.sthlp
  scripts/stata/monthly/bnr_step6_publish.do
  docs/operations-manual/monthly-cvd-step-6.md
  site/operations/bnr-monthly-cvd-run-guide.qmd

No change is required to bnr_paths_LOCAL.do. Step 6 uses the existing:

  $BNR_STAGING
  $BNR_PUBLIC
  $BNR_REPO
  $BNR_PRIVATE_LOGS

First workstation test
----------------------

1. Install all seven files.
2. Restart Stata, or rerun the menu configuration.
3. Confirm Step 5 Approve completed for the chosen release.
4. Run Step 6 without replace:

     do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 1 burden

5. Confirm the final summary reports:

     Run status:             PUBLISHED
     Approved payload files: 8
     Verification:           PASSED

6. Inspect both:

     outputs/public/metrics/cvd/burden/
     site/downloads/files/metrics/cvd/burden/

7. Confirm that release/current CSV and DTA files, three YAML files,
   disclosure_qa.csv and the release ZIP are present.

Important
---------

- Do not use "replace" for the first test.
- approval.yml and public_manifest.csv must remain private.
- Step 6 has been statically reviewed against the supplied approved 2024-01
  example, but Stata 19 is not available in the build environment. The first
  run on the authorised workstation is therefore the executable acceptance
  test.


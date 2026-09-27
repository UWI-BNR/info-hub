# BNR reporting templates

This folder contains controlled starting points for BNR reports and report-related pages. Templates are repository source files; confidential data and generated report outputs must remain outside Git.

## One-off CVD analysis template

Use `bnr_report_oneoff_analysis_template.do` when beginning a new bespoke one-off CVD report. Copy and rename it into a report-specific subfolder before adding analytical code. Do not turn the shared template itself into a substantive report.

The template separates three kinds of code:

- **REPORT-SPECIFIC — EDIT:** report identity, frozen inputs, methods, interpretation and metadata.
- **ANALYST INSERTION POINT:** cohort construction, statistical analysis, quality review, disclosure control, figures, tables and `putpdf` content.
- **CONTROLLED — LEAVE UNCHANGED:** configuration, output naming, public-data writing, YAML and README production, final validation and the Step 1 handoff.

The analytical template creates finished private inputs only. It never approves or publishes a report. Candidate preparation, approval and publication remain the separate one-off report Steps 1–3.

## Required handoff

Every one-off analysis must create a finished PDF. An associated public dataset is optional. When a dataset is supplied, the template requires the complete set:

- a portable CSV;
- a labelled and documented Stata DTA;
- structured YAML metadata using `bnr_dataset_metadata_v1`; and
- a Markdown README.

The template deliberately provides no legacy TXT metadata route.

For a public dataset, the report-specific code must:

1. create the complete proposed public payload;
2. apply direct, complementary and deductive disclosure control;
3. include a string `release_status` field;
4. list the value fields that must be blank on non-release rows;
5. label every variable in plain language; and
6. save the final disclosure-controlled dataset to the template's `public_work` tempfile.

The controlled writer then creates the CSV first and rebuilds the DTA from that CSV using double-precision numeric import. This provides a clean boundary from confidential source metadata and keeps the two public formats aligned. Only the report-specific labels and notes are added to the public DTA.

## Starting a report

1. Copy `bnr_report_oneoff_analysis_template.do` into a new report-specific folder under `scripts/stata/reporting/`.
2. Give the copy a report-specific filename.
3. Complete every report-specific setting and methods field.
4. Replace the analyst insertion block with readable Stata analysis and review code.
5. Build the report body using `putpdf`.
6. If a dataset is included, save its final public form to `public_work`.
7. Set the analytical and disclosure completion flags only after the corresponding reviews are complete.
8. Run the copied DO file and inspect all finished files listed in its final summary.
9. Run one-off report Step 1 separately using the command printed by the template.

The report ID, analytical code version and publication version have different purposes. Maintain one `analysis_code_version` local in the report-specific DO file; the controlled template writes that value into the generated metadata and final summary.

## Testing the unchanged template

The shared template has a harmless engineering mode for a quick manual run:

```stata
do "$BNR_STATA/reporting/templates/bnr_report_oneoff_analysis_template.do" ///
    template_test
```

This creates a fictional PDF and a two-row public dataset in private staging. It contains no surveillance data and does not invoke Step 1.

For the automated check, run the accompanying contract test instead:

```stata
do "$BNR_STATA/reporting/tests/bnr_report_test_oneoff_analysis_template.do"
```

The contract test invokes the template's engineering mode itself. It verifies the five finished inputs, the YAML structure, the absence of a legacy TXT metadata file, the public release-status behaviour and the CSV/DTA row and variable structure. The existing one-off lifecycle test continues to verify preparation, approval and publication separately.

## Other files in this folder

The remaining files support the annual report and rolling-update products. Their individual workflow documentation remains authoritative; do not use them as substitutes for the one-off analysis template.

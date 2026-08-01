# Occasional briefings: analyst review and publication

## Purpose

Occasional briefings use the same separation principles as monthly metrics but a lighter, analyst-led disclosure process. Each briefing remains bespoke.

## Roles

- The analyst runs the briefing-specific Stata DO file and reviews the private staging package.
- The approver confirms analytical correctness, disclosure safety, interpretation and publication readiness.
- The publisher runs the separate approval-and-publication helper. One authorised person may hold more than one role where BNR governance permits.

## Operating sequence

1. Confirm the intended versioned Step 3 deidentified input.
2. Run the briefing-specific analysis DO file.
3. Inspect every staged dataset, figure, metadata file and workbook.
4. Open 'review/disclosure_flags.csv'.
5. Review the Quarto page, PDF source, slide source and all surrounding narrative.
6. Complete every field in 'review/disclosure_review.txt'.
7. Record whether complementary disclosure, differencing and external information create additional risk.
8. Set 'review_status: APPROVE FOR PUBLICATION' only when the complete briefing is safe.
9. Run the separate approval-and-publication helper.
10. Render the HTML, PDF and slides, inspect them, rebuild the Downloads catalogue and review the Git changes before deployment.

## Rebuilding after review

Rerunning the analytical DO file deliberately replaces the disclosure-review template with an incomplete copy. Results that change must be reviewed again.

## Case-count pilot

The 'cvd_cases_2023_v2' pilot:

- reads 'bnr_cvd_input_count_202401_v01.dta';
- excludes death-certificate-only records;
- publishes combined, unstratified monthly CVD counts for 2022–2023;
- compares them with the 2018–2022 average for each calendar month;
- does not publish weekly data or cumulative weekly values;
- retains the existing annual age/sex/event-type figure and data;
- preserves 'cvd_cases_2023_v1' as an immutable historical release.

Before accepting the pilot, run 'cvd_cases_2023_v2_equivalence_check.do' and investigate every reported difference.

## Publication command

~~~stata
do "$BNR_STATA/common/bnr_approve_publish_briefing.do" ///
    "cvd_cases_2023_v2" ///
    "Full name" ///
    "Registry Statistician"
~~~

The review folder stays private. 'outputs/public/briefings/cvd_cases_2023_v2/' is authoritative; the website copy is disposable.

## Private review rendering

Before approval, a staged briefing has no public website mirror. To review the
draft PDF, HTML page and slides without promoting it, first prepare a local
review-only figure mirror:

~~~stata
do "$BNR_STATA/common/bnr_prepare_briefing_review.do" ///
    "cvd_cases_2023_v2"
~~~

From the `site` folder, render with Quarto's `review` profile. For example:

~~~powershell
quarto render --profile review surveillance/cvd/briefings/pdf/case-counts-pdf.qmd
~~~

This reads only the staged PNG figures from the Git-ignored `site/_review/`
folder and writes to `site/_site-review/`. It does not change `outputs/public/`,
`site/downloads/files/` or the download catalogue. Normal Quarto rendering
continues to use the approved public website mirror after promotion.

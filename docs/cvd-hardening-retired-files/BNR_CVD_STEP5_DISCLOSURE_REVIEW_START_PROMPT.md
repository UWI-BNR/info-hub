# BNR CVD workflow — Step 5 disclosure-review starting prompt

Continue the BNR CVD workflow hardening project from the completed Stage 3 rate-construction release.

## Immediate task

Undertake the equivalent of the revised CVD workflow Step 5: disclosure control, private review and approval-package design. Do not begin dashboard redesign yet.

Review the existing CVD Step 5 suppression/review/approval workflow in the repository and determine what can be reused, what needs extending for annual incidence rates, and what should remain unchanged.

## Established decisions

- Stage 3 rate construction is complete in release **v1.0.7**.
- The complete annual production period for the current April 2024 CVD release is **2010–2023**. Years 2008–2009 are outside the analytical event range and should not drive decisions.
- National rates use the approved Barbados UN WPP 2024 population reference:
  `wpp2024_brb_population_2010_2035_5y.dta`.
- Age standardisation uses the supplied WHO World Standard 2000–2025 weights:
  `who_world_standard_2000_2025.dta`.
- Five-year age components, age-unknown records, unknown-sex records, allocation probabilities and `mixed_unallocated` accounting remain private.
- Public rate rows are annual and include All-CVD, Heart and Stroke; all, female and male; hospital-only and hospital + DCO; crude and directly age-standardised forms.
- DCO-enhanced rows retain lower, central and upper estimates where applicable.
- Primary and Inclusive subtype classifications are alternative, non-nested classifications. Subtype Primary/Inclusive ordering is therefore a diagnostic, not a hard acceptance rule.
- Pooled All-CVD Primary/Inclusive lower, central and upper ordering remains a hard acceptance rule.
- Heart and Stroke estimates must not be added to recreate All-CVD.
- The final public dashboard dataset must not expose private accounting components or permit reconstruction of them from related released rows.

## Current Stage 3 evidence

The v1.0.7 private production run completed successfully. The QA CSV reported zero failures for:

- lower, central and upper DCO accounting;
- component lattice completeness;
- rate bounds;
- age-standardised rows;
- public dimensions;
- metadata;
- numerator/denominator fields;
- annual period coverage;
- rate lattice completeness;
- pooled All-CVD Primary/Inclusive ordering; and
- all-sex numerator accounting.

It reported two informative subtype Primary/Inclusive ordering diagnostics in 2012 Heart/female rows. These were accepted as expected consequences of alternative, non-nested subtype classification and were not corrected by forcing values upward.

## Disclosure-review scope

Review the full related-cell system jointly:

- All-CVD, Heart and Stroke;
- hospital-only and hospital + DCO;
- Primary and Inclusive mortality definitions;
- all, female and male;
- crude and age-standardised rates;
- lower, central and upper estimates; and
- counts and rates together where both are released.

Assess direct small-cell risk, complementary suppression and arithmetic reconstruction risk. In particular, test whether released All-CVD, Heart and Stroke values could reveal the private `mixed_unallocated` component, including through bounds, sex totals, mortality definitions or count/rate relationships. Assess complementary disclosure risk across time periods.

## Expected outputs from this session

1. A clear inventory of the existing Step 5 workflow.
2. A proposed disclosure specification for the revised CVD outputs.
3. A private review-package design, including candidate data, suppression-review table, protected-cell worklist, QA output, reviewer sign-off and approval manifest.
4. A list of required code changes, with a distinction between reusable code and new code.
5. Synthetic test cases for direct suppression, complementary suppression and reconstruction risks.
6. A frozen public-schema proposal for the later dashboard dataset assembler.

Do not delete testing code or alter menuing yet. First freeze the disclosure rules and public schema. Dialogs, menuing, help files, repository cleanup and final release packaging should follow the disclosure decision.

## Preferred review files

If repository access is available, inspect the relevant files directly. Otherwise use this compact attachment set:

- `BNR_CVD_WORKFLOW_HARDENING_CONTRACT_v2_2.md`;
- `STAGE3_RATE_CONSTRUCTION_HANDOVER.md`;
- `STAGE3_RATE_CONSTRUCTION_RELEASE_REVIEW_v1_0_7.md`;
- the current CVD Step 5 suppression/review/approval DO-files and tests;
- the production Stage 3 QA CSV and log; and
- a schema or small extract of the existing approved count dataset.

Avoid uploading large confidential DTAs unless a specific inspection requires them. Use compact QA extracts and variable inventories where possible.

Keep Stata code simple and reviewable for a mixed-skill team. Do not use `///` line breaks in commands intended for direct CLI copying.

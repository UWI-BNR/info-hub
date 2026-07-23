# BNR Refit Phase 2: Operations and Handover

**Status:** Concise development framework  
**Updated:** 23 July 2026

This document subsumes the earlier Operations Manual outline and changelog template. Detailed, task-specific instructions should sit in `site/operations/` and `site/technical/`.

## Roles

- **Analyst:** runs the Stata analysis, checks the staging package and resolves errors.
- **Approver:** an authorised BNR Lead, BNR Analyst or BNR Statistician; completes one combined approval covering analytical correctness, disclosure control, interpretation and publication readiness.
- **Publisher:** runs the approved Stata promotion action and renders/publishes the site. The analyst, approver and publisher may be the same authorised person where local governance permits.

## Single approval process

The approver confirms that:

- the intended dataset release and period were used;
- methods and results are plausible and consistent with the approved specification;
- public files contain no confidential or disclosive information;
- titles, interpretation and limitations are suitable for release;
- required data, figures, metadata and build information are present.

Approval should be recorded in one small `approval.yml` file inside the approved package:

```yaml
status: approved
approved_by: Full name
approved_role: BNR Lead
approved_date: 2026-07-17
package_id: example_package_id
```

No signatures, separate forms or duplicate checklists are required unless BNR governance later requires them.

The routine Step 5 prepare action creates only private review materials. The
`public_ready` package and `approval.yml` are created together only after the
named approver records approval.

## Stata-facing promotion

The intended handover command is one simple Stata DO file, for example:

```stata
do "$BNR_STATA/common/bnr_approve_publish.do" ///
    "briefing" "cvd_cases_2023_v1" ///
    "Full name" "BNR Statistician"
```

The command should:

1. confirm the staging package exists;
2. require a named authorised approver;
3. create the disclosure-controlled `public_ready` package and `approval.yml`;
4. replace the matching `outputs/public/` package;
5. create any required ZIP;
6. refresh the website mirror; and
7. stop clearly if any step fails.

Until this separate command is implemented, the existing publishing helpers must be run only after the combined review has been completed.

## Release rule

`outputs/public/` is the authoritative approved release. The copy under `site/downloads/files/` is a disposable mirror. Published values must be regenerated from data and code, never edited by hand.

## Post-release change control

During development, rely on Git history and keep documentation light. After formal release and handover, record only changes that materially affect:

- an approved metric definition or method;
- the approval or publication pathway;
- the public output structure;
- disclosure control;
- a required software dependency; or
- staff responsibilities.

## ToR assumptions requiring periodic review

The assumptions are in **Section 4 of the Terms of Reference, pages 2-3**:

- BNR remains responsible for data completeness, clinical accuracy and corrections.
- The approved dataset structure remains stable during automation.
- Indicator definitions and templates are approved before automation.
- Stata remains the primary analytical platform.
- BNR and its oversight authorities retain dissemination approval.
- Scope remains CVD plus the defined hypertension and diabetes extensions.
- Timely data and infrastructure access continue.
- Each release uses a defined data freeze and version.
- BNR staff provide timely validation and sign-off.
- Disclosure-control rules are agreed and applied before publication.
- Material post-approval methodological or structural changes may require scope review.

Review these assumptions at major delivery milestones and before final handover. Record only exceptions or changes; do not create routine paperwork when all remain valid.

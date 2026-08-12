BNR Refit Phase 2: Operations and Handover

Status: Current implementation summaryUpdated: 12 August 2026

This document is the concise handover map for the implemented BNR analytical and publication environment. Routine operator decisions belong in site/operations/; exact setup, commands and recovery instructions belong in site/technical/.

1. Current scope

Implemented

CVD monthly dashboard workflow: Steps 1-6.

CVD burden metrics, including registered event counts and distributions.

CVD tabulation workflow: Steps 1, 2A, 2B and 3.

Routine briefing workflow: Steps 1-3.

Routine CVD briefings for incidence, case fatality and hospital length of stay.

Manifest-driven Downloads catalogue and Quarto website publication.

Operations, Technical and Public Methods Manuals.

CVD event counts are reported through dashboards and tabulations. There is no operational case-count briefing.

Still in development

CVD mortality data preparation and publication.

Hypertension analytical workflow and approved measures.

Diabetes analytical workflow and approved measures.

Final end-to-end operational testing, training and formal handover.

The hypertension and diabetes site and Methods pages are intentional first-class holding pages, not archive or future-surveillance sections.

2. Roles and authority

Role

Main responsibility

BNR Lead

Owns registry priorities, governance and dissemination authority

BNR Analyst

Runs analytical workflows and reviews statistical plausibility

BNR Developer

Maintains the Stata, Quarto, Git and publication environment

Registry officer / abstractor

Identifies cases, abstracts evidence and maintains REDCap records

Clinical reviewer

Resolves classifications requiring clinical judgement

Approver

Records combined analytical, disclosure and publication-readiness approval

Publisher

Runs the separate controlled promotion step and website deployment

The Stata workflows accept BNR Lead, BNR Analyst and BNR Developer as approval roles. BNR decides which named people are authorised to approve dissemination.

One authorised person may hold more than one role where staffing requires it. Preparation, approval, analytical publication and website deployment must still be separate deliberate actions with separate evidence.

3. System locations

Location

Status and use

Private raw and frozen data

Confidential source material; outside Git

Private derived data

Confidential cumulative and deidentified analytical inputs; outside Git

Private staging

Unapproved analysis, review and public-ready candidates; outside Git

outputs/public/

Authoritative approved public analytical packages

site/downloads/

Website mirror rebuilt from approved packages

site/_site/

Generated Quarto render; never edit directly

Git repository

Public-safe code, documentation, approved outputs and website source

Machine-specific roots and the REDCap token-file location are defined in the untracked scripts/stata/config/bnr_paths_LOCAL.do.

4. Routine entry point

Load scripts/stata/menu/bnr_menu.do at Stata startup. Operators then use User > BNR.

Dashboard metrics

Step

Menu action

Result

1

Extract REDCap data

Private cumulative REDCap snapshot and manifest

2

Build cumulative dataset

Confidential historical-plus-current CVD dataset

3

Build deidentified datasets

Purpose-limited analytical inputs

4

Calculate metrics for dashboards

Private unsuppressed metric staging package

5 Prepare

Review and approve package for release

Suppressed review candidate and review evidence; no approval yet

5 Approve

Same Step 5 dialog, approval action

Exact approved public_ready package, manifest and approval.yml

6

Publish approved outputs

Authoritative metric package, ZIP, website mirror and download record

The currently implemented metric family is burden.

Tabulations

Step

Menu action

Result

1

Build private table package

Seven unsuppressed analytical datasets and QA material

2A

Prepare suppressed tables

Disclosure-controlled datasets, workbook, Markdown, metadata and review worklist

2B

Approve reviewed tables

Approval receipt for the exact 26-file manifest; no publication

3

Publish approved tables

Release-stamped and latest public packages, ZIP, website mirror and download record

Table Step 1 uses the Step 3 all_variables input. Table Step 2A owns suppression; Quarto displays the generated public Markdown and does not calculate or suppress table values.

Briefings

Step

Menu action

Result

1

Build review package

Analyst-owned analysis and complete private briefing package

2

Review and approve briefing

Completed review record, public manifest and approval.yml

3

Publish approved briefing

Authoritative public package, ZIP and website mirror

Routine Briefing Step 1 dispatches only:

CVD incidence rates;

CVD case fatality; and

CVD length of stay.

Mortality is visibly reserved but must stop as not yet migrated. Ad-hoc briefings use an analyst-owned DO file to create the same staging contract, then use the standard Step 2 and Step 3 controls.

Updating the narrative QMD, PDF or slides is a separate publish-layer task after Briefing Step 3.

5. Approval contract

The approver reviews the exact proposed public payload and confirms:

the intended source release, reporting period and product identity;

analytical correctness and plausibility;

exclusions, missingness, warnings and limitations;

primary and complementary disclosure control;

titles, labels, interpretation and presentation;

completeness of the required public files; and

absence of confidential data, private paths, logs and review files.

Approval creates a small approval.yml and a public manifest. These bind approval to the identified package. They must not be created or edited manually.

approval.yml means approved, not published. Publication is permitted only when the separate publication step verifies the approval, manifest and approved files.

6. Publication and website deployment

The controlled Stata publication step:

finds the selected approved package;

validates approval.yml and the public manifest;

verifies the required files and fingerprints where used;

copies only approved public files to outputs/public/;

creates required ZIP and catalogue records; and

refreshes the website mirror.

It does not rerun analysis, make a new suppression decision, edit a QMD, render Quarto or run Git.

After successful analytical publication:

inspect the authoritative public package and website mirror;

update any separate Quarto narrative or link;

preview the affected page;

run a complete local Quarto render;

inspect downloads, figures, tables, PDF/slide links and site search;

inspect every Git change for confidentiality and intent;

commit and push; and

confirm the GitHub Pages deployment and live pages.

7. Stop and correction rules

Stop when:

the selected release, package or version is unclear;

a required input, log, review file, manifest or approval is absent;

results are implausible or inconsistent;

disclosure review is incomplete;

a payload changed after approval;

Git shows confidential, private or unexplained files; or

the rendered site differs from the approved product.

To correct an error:

identify the earliest affected source, reference, configuration or code;

correct it in the authoritative location;

rerun from that step;

repeat disclosure review and approval;

publish the corrected package through the controlled step; and

rerender, review and redeploy the site.

Never repair a generated dataset, CSV, workbook, Markdown table, figure, manifest, approval receipt or rendered file by hand.

8. Evidence retained

REDCap and data-release authorisation records;

private Stata logs and review outputs;

package metadata and QA summaries;

disclosure worklists or review records;

approval.yml and public manifests;

authoritative public packages and publication receipts;

Git commit history; and

GitHub Pages deployment history.

Private review evidence remains private. Only approved public payloads enter the website pathway.

9. Documentation ownership

Need

Authoritative source

Operator responsibilities and decision points

site/operations/

Workstation setup, exact steps and troubleshooting

site/technical/

Public measure definitions and interpretation

site/methods/

Stata file responsibilities and dependencies

scripts/stata/README.qmd

Project-wide architecture

docs/bnr-refit-project-guiderails.md

Implementation history

Git history

Do not create a second operational pathway in a development note. Update the authoritative manual page when a workflow materially changes.

10. Handover checks

Before formal handover, confirm that:

a clean workstation can be configured from the template and Technical Manual;

the Stata menu loads and every active dialog opens;

current CVD dashboard, table and briefing workflows pass end to end;

failure and overwrite protections behave as documented;

the full site renders without broken internal links;

GitHub Pages deploys successfully;

recovery from a rejected or partially failed release has been rehearsed;

role-to-person mappings and dissemination authority are confirmed by BNR;

the mortality, hypertension and diabetes status is accurately stated; and

training has included at least one analyst and one backup operator.

11. ToR assumptions requiring review

At major delivery milestones and before final handover, confirm that:

BNR remains responsible for data completeness, clinical accuracy and corrections;

the approved dataset structure remains stable enough for automation;

indicator definitions and reporting templates are approved;

Stata remains the primary analytical platform;

BNR and relevant oversight authorities retain dissemination approval;

scope remains within CVD and the defined hypertension and diabetes extensions;

timely access to required datasets and secure infrastructure continues;

each release uses a defined data freeze and version;

designated BNR staff provide timely validation and sign-off;

agreed disclosure controls are applied before publication; and

material methodological, structural or governance changes are handled through explicit change control.

Record exceptions and decisions. Do not create routine paperwork when the assumptions remain unchanged.
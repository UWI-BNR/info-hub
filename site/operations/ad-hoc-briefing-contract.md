---
title: "Ad-hoc briefing contract"
---

# Purpose

This contract covers one-off public analytical briefings created in response
to an external request or an analyst-led research question. They use the same
private staging, human approval, immutable public release and ZIP-download
pathway as routine BNR briefings.

An ad-hoc briefing is a public **briefing**, not a new catalogue product type.
The `briefing_kind` field records why it followed a different analyst build
route.

# Boundaries

- The analyst-owned DO file performs the analysis and creates only a private
  Step 1 staging package.
- The common staging helper completes metadata, the disclosure-review pack and
  `downloads.yml`. It does not approve or publish.
- Briefing Step 2 records the completed human review.
- Briefing Step 3 publishes only the approved manifest and creates the ZIP.
- Quarto pages, rendering, Git and GitHub remain separate.
- The workflow never accepts an arbitrary DO-file path through a dialog.

# Package identifier

Use a stable, meaningful identifier:

```text
{domain}_{short_topic}_{period}_v{version}
```

For example:

```text
cvd_external_request_2023_v1
```

The identifier must:

- contain only lowercase letters, numbers and underscores;
- begin with a letter;
- be no longer than 80 characters; and
- end `_v1`, `_v2`, and so on.

Never reuse an approved or published identifier for changed content. Create a
new version.

# Required release-control settings

The analyst-owned DO file must write these values in
`metadata/release_control.yml`:

```yaml
briefing_id: cvd_external_request_2023_v1
briefing_name: cvd_external_request_2023_v1
output_type: briefing
briefing_kind: ad_hoc
create_zip: 1
list_zip: 1
```

It must also provide the ordinary briefing fields required by
`bnr_stage_briefing.do`, including source dataset details, reporting period,
title, description, released datasets and figures, and any workbook settings.

The analyst-owned DO file ends by calling:

```stata
do "$BNR_STATA/common/bnr_stage_briefing.do" "`briefing_id'"
```

# Public contents

Only deliberately declared aggregate products may be released:

- DTA and CSV datasets with companion metadata;
- PNG figures;
- an optional workbook;
- briefing-level metadata;
- `readme.txt`; and
- `downloads.yml`.

No direct identifiers, confidential microdata, review files, approval files,
logs, analytical source code or release-control file may enter the manifest.

# Disclosure review

Disclosure control remains analyst-led. The analyst and approver must review:

- all low and zero cells, including cells not caught by automatic flags;
- totals and components that could reveal a suppressed value;
- differencing across versions, periods or related public products;
- figures, labels, annotations and narrative claims;
- external information that may increase disclosure risk; and
- every released dataset and workbook sheet.

An ad-hoc request does not justify relaxing the BNR disclosure standard.

# Operating sequence

1. Copy a proven analyst-owned briefing DO file and give it a new package ID.
2. Make the analytical changes visibly in that DO file.
3. Set `output_type`, `briefing_kind`, `create_zip` and `list_zip` exactly as
   specified above.
4. Run the analyst DO file directly to create the private staging package.
5. Inspect every staged artefact and complete the disclosure review.
6. In Briefing Step 2, select **Ad-hoc briefing**, enter the exact package ID,
   complete all five confirmations and approve.
7. Inspect `approval.yml`, `public_manifest.csv` and the completed disclosure
   record.
8. In Briefing Step 3, select **Ad-hoc briefing**, enter the same package ID and
   publish.
9. Rebuild the download catalogue and preview the website.
10. Use the normal Git and GitHub deployment process.

# Recovery and corrections

- An unapproved staging package may be rebuilt only through the analyst-owned
  DO file's explicit replacement control.
- An approved or published package is immutable.
- A correction uses a new versioned package ID and repeats review, approval and
  publication.
- A missing disposable website mirror may be rebuilt by rerunning Step 3 only
  when the authoritative public files still match the approval manifest.


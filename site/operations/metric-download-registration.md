# Metric ZIP publication and Downloads catalogue registration

## Purpose

Metric Step 6 publishes an approved metric package and registers its verified
release ZIP for the central Downloads page. Registration is part of the
publication layer; it does not calculate metrics, apply suppression or approve
results.

## Normal operator sequence

1. Complete Step 5 review and approval for the selected metric release.
2. Run the Step 6 dialog for the same year, month and metric family.
3. Confirm that the Step 6 summary reports `PUBLISHED`, the release ZIP and the
   release-specific catalogue record.
4. Run:

   ```text
   python site/scripts/build_download_catalogue.py
   ```

5. Confirm that the builder finds the metric record and adds one ZIP row.
6. Preview the Downloads page and check its area, period, type, title, updated
   date and ZIP link.
7. Commit, render and deploy through the normal Info-Hub process.

## Files created by Step 6

For release `cvd_2024_01`, Step 6 creates the authoritative files:

```text
outputs/public/metrics/cvd/burden/
  bnr_cvd_burden_cvd_2024_01.zip
  catalogue/
    cvd_2024_01.yml
```

and copies them to the disposable website mirror:

```text
site/downloads/files/metrics/cvd/burden/
  bnr_cvd_burden_cvd_2024_01.zip
  catalogue/
    cvd_2024_01.yml
```

The catalogue record contains publication metadata and points to the verified
ZIP. The central `site/downloads/downloads.yml` remains generated output and
must not be edited by hand.

## Release behaviour

- Each monthly release has one immutable release-stamped ZIP and one catalogue
  record.
- Stable `current` datasets remain within the ZIP; they do not create a second
  catalogue row.
- Re-running Step 6 for an existing release requires the existing deliberate
  `replace` authorisation.
- The catalogue record uses the Step 5 approval date as its public update date,
  so a technical rerun does not silently change the release date.
- Step 6 does not run Python or render Quarto. This preserves the separation
  between Stata publication and website catalogue generation.

## Failure checks

- Missing or invalid Step 5 approval: Step 6 stops before public folders are
  changed.
- ZIP failure: no catalogue record is created.
- Missing website ZIP or catalogue copy: Step 6 stops and reports the failing
  path.
- Broken ZIP link in a catalogue record: the Python builder stops and retains
  the last good central catalogue.
- Re-running the Python builder without changes must report
  `Catalogue status: unchanged` and must not duplicate the metric row.

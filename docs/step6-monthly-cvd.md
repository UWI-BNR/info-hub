# Monthly CVD workflow — Step 6

## Purpose

Step 6 is the separate publication action. It verifies the package approved in Step 5, copies only the eight manifested payload files to authoritative public output, creates one release ZIP, and refreshes the website-download mirror.

It does not calculate metrics, change suppression, edit metadata, approve results, render Quarto or deploy the website.

## Run Step 6

For March 2024:

```stata
do "$BNR_STATA/monthly/bnr_step6_publish.do" 2024 3 burden
```

Or open:

```stata
db bnr_step6_publish
```

The burden family is currently the only implemented selection.

## Required Step 5 controls

Step 6 stops unless:

- `approval.yml` records approved status for the selected release and family;
- the review standard and disclosure policy are correct;
- the approval records `disclosure_check: passed`;
- `public_manifest.csv` still matches the fingerprint in `approval.yml`;
- the manifest lists exactly the eight expected payload files; and
- every source file still matches its approved size and checksum.

The approval record and manifest remain private. Step 6 never copies the whole `public_ready` folder.

## Backward-compatible public layout

Step 5 keeps datasets in `public_ready/datasets/`. The existing dashboard expects them at the burden-family root, so Step 6 applies this explicit mapping:

| Step 5 source | Public and website destination |
|---|---|
| `datasets/*.dta` | `metrics/cvd/burden/*.dta` |
| `datasets/*.csv` | `metrics/cvd/burden/*.csv` |
| `metadata/*.yml` | `metrics/cvd/burden/metadata/*.yml` |
| `disclosure_qa.csv` | `metrics/cvd/burden/disclosure_qa.csv` |

Both release-stamped and stable `current` DTA files are intentionally public. They are approved, disclosure-controlled analytical datasets and contain no individual-level information.

## Outputs

The authoritative public package is:

```text
$BNR_PUBLIC/metrics/cvd/burden/
```

The disposable website mirror is:

```text
$BNR_REPO/site/downloads/files/metrics/cvd/burden/
```

For March 2024, each contains:

```text
cvd_burden_metrics_cvd_2024_03.dta
cvd_burden_metrics_cvd_2024_03.csv
cvd_burden_metrics_current.dta
cvd_burden_metrics_current.csv
disclosure_qa.csv
bnr_cvd_burden_cvd_2024_03.zip
metadata/
    cvd_burden_metrics_cvd_2024_03.yml
    cvd_burden_metrics_current.yml
    metric_package.yml
```

The ZIP contains the eight approved payload files. It is created from the verified authoritative public copy.

## Existing releases and `replace`

A first publication should be run without `replace`. Step 6 stops if release-stamped files or the release ZIP already exist in either destination.

For an authorised republication of the same release:

```stata
do "$BNR_STATA/monthly/bnr_step6_publish.do" ///
    2024 3 burden replace
```

Do not use `replace` simply to bypass an unexplained failure. Inspect the existing release and the private Step 6 log first.

Stable `current` files are expected to exist after the first release. They are refreshed from the newly selected approved release on every successful Step 6 run.

## Success and failure

A successful run ends with:

```text
STEP 6: OPERATIONAL RUN SUMMARY
  Run status:             PUBLISHED
  Verification:           PASSED
```

The private operational log is:

```text
$BNR_PRIVATE_LOGS/bnr_step6_publish_YYYYMM.log
```

If Step 6 stops, read the precise reason and inspect both destination folders before rerunning. A filesystem error can occur after an earlier file has already copied.

After success, use the normal Git and Quarto process to review repository changes, commit the approved public files, render the Info-Hub and deploy it.


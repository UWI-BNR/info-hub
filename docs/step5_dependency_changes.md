# Step 5 refactor: dependency changes

## Renamed files

| Previous name | Refactored name |
|---|---|
| `bnr_cvd_review_controller.do` | `bnr_step5_review.do` |
| `bnr_cvd_review_controller.dlg` | `bnr_step5_review.dlg` |
| `bnr_cvd_review_controller.sthlp` | `bnr_step5_review.sthlp` |
| `bnr_apply_suppression.do` | `bnr_step5_suppress.do` |

## Updated direct references

- Step 5 dialog command and help target
- BNR menu
- Step 5 section of `bnr-monthly-cvd-run-guide.qmd`
- Controller call to the suppression helper

## Deliberately unchanged

- Every `info-hub-private` path
- Step 4 staging package names
- Step 5 generated review filenames
- Private log filenames
- Review fingerprinting, suppression rules and Step 6 boundary
- `bnr_paths_LOCAL.do`
- `bnrcvd_globals.do` remains available elsewhere, but Step 5 no longer loads it

## Repository search terms

Search for these exact old identifiers after placement:

- `bnr_cvd_review_controller`
- `bnr_apply_suppression.do`
- `db bnr_cvd_review_controller`
- `help bnr_cvd_review_controller`

Do not rename generated files such as `bnr_cvd_review_prepare_YYYYMM.log`.

## Approval-package changes in version 2.1.0

- Replaced the third authorised role `BNR Statistician` with `BNR Developer`.
- Moved `public_manifest.csv` and `approval.yml` into `public_ready/`.
- Replaced generic `release.*` payload names with release-stamped filenames.
- Retained stable `current` filenames for dashboards and other latest-release consumers.
- Renamed public-ready metadata files to match the Step 4 naming convention.
- Added `payload_root` to the manifest; paths are relative to `public_ready/`.
- The manifest inventories payload files only. `approval.yml` records the manifest checksum.

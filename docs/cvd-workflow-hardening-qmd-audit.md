# Combined CVD location audit

**Scope:** final workflow consolidation before the separately scoped CVD dashboard redesign.

The operational workflow is now centred on these locations:

- private linkage calculations: `$BNR_PRIVATE/data/derived/cvd/yYYYY/mMM/linkage/mort_yYYYY_mMM/`;
- private Step 4/5 package: `$BNR_STAGING/metrics/cvd/cvd_YYYY_MM/`;
- authoritative public release: `$BNR_PUBLIC/metrics/cvd/`;
- lean website mirror: `site/downloads/files/metrics/cvd/`.

## Updated in this release

| File group | Change |
|---|---|
| Step 4, Step 5 and Step 6 dialogs/help | Match the combined package, explicit mortality release and canonical command syntax. |
| Step 5 approval | Labels the public dataset `BNR combined CVD metrics` rather than inheriting the burden-only label. |
| Step 6 publisher | Writes a complete catalogue manifest to `metrics/cvd/catalogue/`, compatible with `site/scripts/build_download_catalogue.py`. |
| CVD workflow technical pages | Replace the former `metrics/cvd/burden/cvd_YYYY_MM` staging and public locations. |
| Stage 4 handover notes | Replace the retired `data/derived/cvd_linkage` root with the active `data/derived/cvd/.../linkage/...` root. |

## Deferred intentionally: dashboard-consumer update

| File | Why deferred |
|---|---|
| `site/surveillance/cvd/metrics/burden/index.qmd` | It still reads the legacy burden-only current CSV and contains the existing dashboard presentation. Updating it is the separate public-release/dashboard redesign. |
| `site/technical/website/cvd-events-dashboard.qmd` | It documents that currently deployed legacy dashboard behaviour and should change with the dashboard source, not before it. |

The legacy public burden files and their website mirror therefore remain in place until the dashboard redesign has been reviewed and rendered. They are not the retired private `cvd_linkage` tree.

## Checks before retirement

1. Run Step 6 with `replace` once using this release so it rebuilds the CVD catalogue manifest in the canonical location.
2. Run `python site/scripts/build_download_catalogue.py`; it must complete successfully and list the combined CVD ZIP.
3. Run the two maintenance scripts first without `-Apply`.
4. After reviewing their output, apply the public catalogue-record cleanup and the recoverable private-tree move.
5. Run the catalogue builder again, so the generated Downloads table no longer contains the superseded burden-only entry.

The private-tree script searches live `scripts/`, `site/` and `docs/` sources for the retired root before it moves anything. It deliberately excludes `docs/cvd-hardening-retired-files/`, which is preserved as an explicitly retired historical record.

The public-record cleanup removes a legacy catalogue entry only when the same
release has a current combined-CVD replacement. It does not remove the legacy
CSV or ZIP still used by the deferred dashboard source.

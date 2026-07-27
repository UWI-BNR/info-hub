# Step 4 refactor: file and dependency changes

## Renamed files

- `bnr_cvd_metric_controller.do` -> `bnr_step4_metrics.do`
- `bnr_cvd_metric_controller.dlg` -> `bnr_step4_metrics.dlg`
- `bnr_cvd_metric_controller.sthlp` -> `bnr_step4_metrics.sthlp`
- `metric_cvd_burden.do` -> `bnr_step4_cvd_burden.do`
- `bnr_stage_metric.do` -> `bnr_step4_stage_metric.do`

## Updated shared files

- `bnr_menu.do`
- `bnr-monthly-cvd-run-guide.qmd`

## Deliberately unchanged

- All `info-hub-private` paths
- Generated staging folder names and metric dataset names
- Private log name `bnr_cvd_metric_controller_YYYYMM.log`
- Metric IDs `CVD-BURDEN-001` and `CVD-BURDEN-002`
- SDC policy and suppression worklist names

## Repository search terms

Search for these exact old references after manual placement:

```text
bnr_cvd_metric_controller.do
bnr_cvd_metric_controller.dlg
bnr_cvd_metric_controller.sthlp
db bnr_cvd_metric_controller
help bnr_cvd_metric_controller
metric_cvd_burden.do
bnr_stage_metric.do
```

Do not rename occurrences that refer specifically to the generated private log.

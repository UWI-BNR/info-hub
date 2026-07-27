# Step 3 dependency changes

## Renamed workflow files

| Previous name | Refactored name |
|---|---|
| `bnr_cvd_create_metric_inputs.do` | `bnr_step3_metric_inputs.do` |
| `bnr_cvd_create_metric_inputs.dlg` | `bnr_step3_metric_inputs.dlg` |
| `bnr_cvd_create_metric_inputs.sthlp` | `bnr_step3_metric_inputs.sthlp` |

The shortened base name is a valid Stata identifier and remains below Stata's
32-character name limit.

## Files updated in this bundle

- `bnr_menu.do`
- `bnr-monthly-cvd-run-guide.qmd`
- the Step 3 dialog and help file
- self-references in the Step 3 controller

## Dependency removed

The refactored controller no longer calls `bnrcvd_globals.do`. It defines only
the two run values it needs (`today_iso` and the current Stata username).

## Generated products deliberately unchanged

- `bnr_cvd_input_count_YYYYMM_v01.dta/.yml`
- `bnr_cvd_input_case_fatality_YYYYMM_v01.dta/.yml`
- `bnr_cvd_input_length_of_stay_YYYYMM_v01.dta/.yml`
- `bnr_cvd_input_performance_YYYYMM_v01.dta/.yml`
- `bnr_cvd_input_all_variables_YYYYMM_v01.dta/.yml`
- `bnr_cvd_create_metric_inputs_YYYYMM.log`

## Targeted repository search after manual placement

Search for these exact old references:

```text
bnr_cvd_create_metric_inputs.do
bnr_cvd_create_metric_inputs.dlg
bnr_cvd_create_metric_inputs.sthlp
db bnr_cvd_create_metric_inputs
help bnr_cvd_create_metric_inputs
```

Do not replace occurrences referring to the generated log filename.

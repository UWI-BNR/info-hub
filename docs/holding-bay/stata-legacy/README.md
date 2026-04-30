# Stata legacy holding bay

This folder stores Stata files that may remain useful but are not part of the active BNR info-hub workflow.

Files in this folder are not loaded by the standard Stata path setup.

Active Stata workflow files belong under:

- `scripts/stata/config/`
- `scripts/stata/common/`
- `scripts/stata/ado/`
- `scripts/stata/briefings/`

## Current files

### `bnrpath.ado`

Legacy path-setting helper from the previous `resource-analytics` structure.

The new info-hub workflow uses:

```stata
do "scripts/stata/config/bnr_paths_LOCAL.do"

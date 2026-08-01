# Occasional Briefings Re-engineering

## Step 4 — Case-count pilot implementation

**Status:** Code prepared; local Stata execution and equivalence validation required  
**Date:** 31 July 2026  
**Pilot:** 'cvd_cases_2023_v2'

## Implemented changes

- The analyst DO file now reads the versioned Step 3 'count' dataset directly.
- The legacy 'bnrcvd_prep_2023_v1.do' call has been removed from the v2 pathway.
- The public weekly and cumulative-weekly outputs have been removed.
- The new time-series output combines AMI and stroke into unstratified national monthly counts for January 2022–December 2023.
- The comparator is the 2018–2022 mean for each calendar month.
- The existing age/sex/event-type output is retained.
- Analysis ends in private staging.
- A briefing-specific 'disclosure_flags.csv' is generated.
- The staging helper creates a fresh incomplete 'disclosure_review.txt' on every rebuild.
- A separate approval-and-publication helper verifies the human review and promotes only approved artefacts.
- The private review folder is excluded from the public package.
- Quarto HTML, PDF and slides now use the v2 monthly figure and revised narrative.
- The original v1 analysis and historical public package remain unchanged.

## Files

| File | Purpose |
|---|---|
| 'cvd_cases_2023_v2.do' | Briefing-specific computation and private staging |
| 'cvd_cases_2023_v2_equivalence_check.do' | Controlled comparison of old and new inputs |
| 'bnr_stage_briefing.do' | Routine private package completion |
| 'bnr_approve_publish_briefing.do' | Human gate, approval, public copy, ZIP and site mirror |
| 'bnr_stage_briefing.sthlp' | Stata help for private staging |
| 'bnr_approve_publish_briefing.sthlp' | Stata help for approval and publication |
| 'site/operations/occasional-briefings.md' | Operations Manual pathway |

## Required local validation

1. Run the legacy preparation once if '$BNR_PRIVATE_WORK/bnrcvd_count_2023_v1.dta' is absent.
2. Run 'cvd_cases_2023_v2_equivalence_check.do'.
3. Investigate unmatched event IDs or differing cells.
4. Run 'cvd_cases_2023_v2.do'.
5. Inspect both public-candidate datasets and figures in private staging.
6. Review the automatic disclosure worklist and the complete Quarto narrative.
7. Complete 'disclosure_review.txt'.
8. Run the approval-and-publication helper.
9. Render and visually inspect HTML, PDF and slides.
10. Rebuild the Downloads catalogue and inspect Git changes before deployment.

## Validation boundary

The code has been structurally reviewed in this development environment. Stata and the confidential DTA inputs are not available here, so successful execution and numerical equivalence must be confirmed locally before approval.


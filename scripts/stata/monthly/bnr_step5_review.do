/*******************************************************************************
DO-FILE: bnr_step5_review.do
VERSION: 4.0.2 (29 August 2026)
PURPOSE: Canonical Step 5 controller for the combined CVD release package.

USAGE:
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 prepare
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 prepare replace
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 approve "<actual authorised name>" "BNR Analyst"
  do "$BNR_STATA/monthly/bnr_step5_review.do" 2026 1 approve "<actual authorised name>" "BNR Analyst" replace

PREPARE creates private review evidence only. APPROVE verifies that evidence
and creates public_ready. Neither action publishes to outputs/public or site.

CHANGE 4.0.2:
  Make the APPROVE usage example explicitly require the actual authorised name.
  The approval helper now rejects common placeholder values.

CHANGE 4.0.1:
  Parse PREPARE and APPROVE arguments explicitly from `0'. This preserves the
  documented "prepare replace" syntax instead of treating replace as an
  approver name.
*******************************************************************************/
version 19
clear all
set more off

* ---------------------------------------------------------------------------
* Parse the common first three arguments, then parse the action-specific tail.
* ---------------------------------------------------------------------------
local command_line `"`0'"'
gettoken release_year remainder : command_line
gettoken release_month remainder : remainder
gettoken action remainder : remainder
local remainder : list retokenize remainder

if "`release_year'" == "" | "`release_month'" == "" | "`action'" == "" exit 198

local action = lower(strtrim("`action'"))
if !inlist("`action'", "prepare", "approve") exit 198

local approver_name ""
local approver_role ""
local option ""

if "`action'" == "prepare" {
    if `"`remainder'"' != "" {
        if lower(`"`remainder'"') != "replace" {
            display as error "The only optional PREPARE argument is replace."
            exit 198
        }
        local option "replace"
    }
}
else {
    gettoken approver_name remainder : remainder
    gettoken approver_role remainder : remainder
    local remainder : list retokenize remainder

    if `"`approver_name'"' == "" | `"`approver_role'"' == "" {
        display as error "APPROVE requires the actual full name and an authorised BNR role."
        exit 198
    }

    if `"`remainder'"' != "" {
        if lower(`"`remainder'"') != "replace" {
            display as error "The only optional APPROVE argument after name and role is replace."
            exit 198
        }
        local option "replace"
    }
}

if "$BNR_STATA" == "" capture noisily do "scripts/stata/config/bnr_paths_LOCAL.do"
if "$BNR_STATA" == "" exit 198

if "`action'" == "prepare" {
    do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_prepare.do" ///
        `release_year' `release_month' `option'
    exit _rc
}

do "$BNR_STATA/monthly/bnr_step5_review_expanded_cvd_approve.do" ///
    `release_year' `release_month' `"`approver_name'"' `"`approver_role'"' `option'
exit _rc

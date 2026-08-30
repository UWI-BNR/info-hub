# CVD source-quarantine review disposition design note

**Status:** deferred design note, 29 August 2026  
**Workflow:** BNR CVD monthly workflow, Step 2 source quarantine

## Purpose

The Step 2 quarantine mechanism deliberately separates analytical safety from
source correction. A quarantined event or field remains analytically
quarantined until the authoritative source supports a safe value. Human review
must not silently overwrite or bypass the deterministic quarantine rule.

Some source problems may be reviewed but cannot be corrected. The team therefore
needs a way to distinguish an item that still requires review from one that has
already been reviewed and has a known final disposition.

## Proposed controlled vocabulary

A future source-level review field should use a small controlled vocabulary:

- `pending review`
- `corrected`
- `reviewed - cannot be corrected`
- `reviewed - accepted as recorded`

A short review note, reviewer and review date may accompany the status.

## Interim and future ownership

During the interim period, the private quarantine report may be used as the
operational review record. These review fields are governance information only:
they must not change the deterministic analytical quarantine treatment.

Once upstream REDCap hardening adds authoritative review/disposition fields,
REDCap should become the source of truth. Step 2 should then read and report the
source disposition rather than maintain a parallel correction database.

## Analytical rule

`reviewed - cannot be corrected` does **not** mean "include the unsafe value".
The event or field remains fully or partially quarantined as required. The
status simply tells the team that no further source correction is currently
possible.

`reviewed - accepted as recorded` should only remove quarantine if the relevant
validation rule has also been revised or the source value can be demonstrated
to satisfy the approved analytical contract. Review status alone must never
bypass a validation rule.

## Documentation follow-up

After the revised CVD workflow has passed end-to-end validation, this design
should be incorporated into the Operations Manual and relevant Step 2 help or
technical documentation. This note is not itself a production procedure.

{smcl}
{title:BNR Tables Step 2B: Approve reviewed CVD tables}

{p 4 4 2}
{cmd:db bnr_step2b_cvd_tables_approve} opens the approval dialog. Step 2B
records that an authorised person has completed the combined analytical,
presentation and disclosure review of the exact products created by Step 2A.

{p 4 4 2}
Step 2B creates only {cmd:public_ready/approval.yml}. It does not recalculate,
suppress, rebuild, copy or publish any table product.

{title:Before running}

{p 4 4 2}
Complete Step 2A for the selected year and month. Review
{cmd:review/qa_summary.txt}, {cmd:review/suppression_summary.txt}, every row in
the private suppression workbook and all products under {cmd:public_ready/}.
Close any workbook after inspection.

{title:Dialog instructions}

{p 4 4 2}
1. Open {bf:User > BNR > Produce tables > Step 2B: Approve reviewed tables}.

{p 4 4 2}
2. Enter the year and month of the reviewed Step 2A package.

{p 4 4 2}
3. Enter the approver's full name and choose one authorised role:
{bf:BNR Lead}, {bf:BNR Analyst}, or {bf:BNR Developer}.

{p 4 4 2}
4. Select each confirmation only after completing that part of the review. The
{bf:Approve} button remains grey and unavailable until all five are selected.

{p 4 4 2}
5. Select {bf:Approve}. A successful run ends with
{cmd:COMPLETED - APPROVED, NOT PUBLISHED}.

{title:Required confirmations}

{p 8 8 2}
The intended dataset release and reporting period were used;

{p 8 8 2}
results and permanent YTD presentation are plausible and correct;

{p 8 8 2}
every suppression flag and disclosure-control decision was reviewed;

{p 8 8 2}
the publication workbook and all public-ready products were inspected; and

{p 8 8 2}
the complete package is ready for publication.

{title:Command-line syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/tables/bnr_step2b_cvd_tables_approve.do"} {it:year}
{it:month} {it:"Full name"} {it:"Approver role"}
{cmd:release results disclosure workbook ready}

{p 4 4 2}
All five confirmation words are mandatory. The DO file checks them independently
of the dialog.

{title:Validation performed}

{p 4 4 2}
Step 2B confirms that the selected package is public-ready and unapproved, that
its package ID and coverage match the dialog selection, and that every required
file listed in {cmd:public_manifest.csv} exists. It refuses an incomplete,
malformed or already-approved package.

{title:Approval receipt}

{p 4 4 2}
The receipt records the package ID, coverage, approver name and role, date and
time, all five confirmations and the number of required manifest files checked.
It also records that publication has not yet been performed.

{title:Corrections after approval}

{p 4 4 2}
Approval cannot be overwritten directly. If any reviewed product needs to
change, rerun Step 2A with explicit replacement. Step 2A removes the earlier
approval, after which the complete review and Step 2B approval must be repeated.
Never edit a generated product or the approval receipt manually.

{title:Next step}

{p 4 4 2}
Run Table Step 3 to promote the approved package. Step 3 must require the valid
approval receipt and public manifest before copying any file.


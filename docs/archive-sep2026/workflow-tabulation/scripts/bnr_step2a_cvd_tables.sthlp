{smcl}
{title:BNR Tables Step 2A: Prepare suppressed tables for review}

{p 4 4 2}
{cmd:db bnr_step2a_cvd_tables} opens the operational dialog. Step 2A reads a
completed, unsuppressed Table Step 1 package, applies the approved small-number
rules, and creates the exact products proposed for publication.

{p 4 4 2}
All outputs remain in private staging. Step 2A does not approve a package,
write {cmd:approval.yml}, copy anything to {cmd:outputs/public/}, update the
website mirror, render Quarto, or deploy the site.

{title:Before running}

{p 4 4 2}
Complete Table Step 1 for the selected year and month. Review
{cmd:review/qa_summary.txt} and resolve any analytical problem before applying
disclosure control. Close any Step 2A workbooks that are open in Excel.

{title:Dialog instructions}

{p 4 4 2}
1. Open {bf:User > BNR > Produce tables > Step 2A: Prepare suppressed tables}.

{p 4 4 2}
2. Enter the year and month used for the completed Step 1 package.

{p 4 4 2}
3. Leave replacement unticked on the first run. Tick it only when deliberately
rebuilding Step 2A after checking the selected package. Replacement removes any
earlier {cmd:approval.yml}, because rebuilt products must be approved again.

{p 4 4 2}
4. Select {bf:Prepare Step 2A review package}. A successful run ends with
{cmd:COMPLETED - PUBLIC-READY, UNAPPROVED}.

{title:Command-line syntax}

{p 8 8 2}
{cmd:do "$BNR_STATA/tables/bnr_step2a_cvd_tables.do"} {it:year} {it:month} [{cmd:replace}]

{title:Disclosure-control rules}

{p 4 4 2}
The primary threshold is a contributing frequency from 1 to 5; a true zero is
not automatically primary-suppressed. The file also applies explicit
complementary rules for annual totals, monthly All-CVD totals, paired age
percentages, small DCO increments, and affected both-sex incidence totals.
Ratios, case-fatality percentages and length-of-stay summaries use their
recorded supporting counts.

{p 4 4 2}
Tables 1 and 2 are controlled jointly. Step 2A first reconciles their exact
annual and monthly counts. It then checks every annual margin, every monthly
Stroke-plus-AMI total, and every annual-total-equals-monthly-sum relationship.
The run stops if any published equation would contain exactly one hidden term,
because that term would be recoverable by subtraction.

{p 4 4 2}
The public suppression symbol is an em dash ({cmd:—}). Numeric values in
public-safe datasets are missing when suppressed; the accompanying display
field and {cmd:suppression_status} explain why.

{title:Private review outputs}

{p 4 4 2}
Review these files under the package's {cmd:review/} folder:

{p 8 8 2}
{cmd:suppression_summary.txt} - counts of primary and complementary flags;

{p 8 8 2}
{cmd:suppression_worklist.csv} - affected cells and exact private values; and

{p 8 8 2}
{cmd:suppression_review.xlsx} - summary, worklist, rules and data dictionary.

{p 8 8 2}
{cmd:cross_table_disclosure_check.csv} - the fail-closed additive-equation
audit for Tables 1 and 2. Every row must have status {cmd:PASS}.

{title:Public-ready outputs}

{p 4 4 2}
The package gains {cmd:public_ready/}, containing seven suppressed DTA/CSV
pairs, the publication workbook, seven generated Markdown fragments, metadata,
the proposed public manifest and a readme. These are the exact files Step 2B
must approve and Step 3 must promote unchanged.

{p 4 4 2}
Tabbed Markdown fragments generate every available year automatically. Current
year counts and length of stay are labelled YTD. Incidence and case fatality
remain completed-period outputs.

{title:Review requirements}

{p 4 4 2}
Inspect every worklist item, confirm that suppressed symbols appear in all
corresponding public representations, open every workbook sheet, and preview
the generated Markdown through the site review pathway. Never edit generated
outputs manually; correct the code or source and rerun the complete step.

{title:Next step}

{p 4 4 2}
When all review checks are satisfactory, use Table Step 2B. Its approver roles
are {bf:BNR Lead}, {bf:BNR Analyst}, and {bf:BNR Developer}. Step 2B will remain
disabled until all required confirmations have been selected, and it will
record approval without publishing.

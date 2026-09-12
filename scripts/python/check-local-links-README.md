# Python utilities

This folder contains small support utilities for the BNR Info-Hub. Run them
from the repository root in **PowerShell**. They are not part of a Stata
analysis, approval or publication workflow.

## Check local documentation links

`check-local-links.py` creates a read-only link register for the Public
Methods, Operations or Technical Manual. It checks whether local destinations
exist and records where every link leads.

The utility does **not** edit QMD files, render the website, access REDCap or
make any Git or GitHub change.

### Before you run it

1. Open PowerShell in the Info-Hub repository:

   ```powershell
   cd C:\yoshimi-hot\output\analyse-bnr\info-hub
   ```

2. Make any intended QMD edits and save them.

### Run a manual-specific check

Use one of the following commands. The same report folder can safely hold the
three separate reports because each output name includes the selected manual.

```powershell
python scripts\python\check-local-links.py --root . --manual methods --report-dir outputs\manual-link-check
```

```powershell
python scripts\python\check-local-links.py --root . --manual operations --report-dir outputs\manual-link-check
```

```powershell
python scripts\python\check-local-links.py --root . --manual technical --report-dir outputs\manual-link-check
```

For a broad repository check, omit `--manual`:

```powershell
python scripts\python\check-local-links.py --root . --report-dir outputs\manual-link-check
```

The broad check can include archived or historical material. For a manual
review, use the relevant `--manual` command to avoid unrelated findings.

## Reports created

For example, the Methods command creates:

```text
outputs\utility-reports\methods-link-register.csv
outputs\utility-reports\methods-link-register.md
```

The CSV is useful for sorting and filtering. The Markdown report is a quick
readable register.

Each row includes:

| Column | Meaning |
|---|---|
| Origin page | Title of the page containing the link. |
| Link context | Nearest preceding page heading. |
| Link text | The words a reader clicks. |
| Link target | The literal destination written in the source QMD. |
| Destination page | Title of the resolved destination page, where available. |
| Destination path | The actual local QMD, Markdown file or directory-index path reached by the link. |
| Link works? | Whether the local destination exists or is expected to be generated when Quarto renders. |
| Appropriate? | Starts as `Not assessed`; this requires human editorial judgement. |

## Interpreting the result

| Result | Meaning | Action |
|---|---|---|
| `Yes — local target exists` | The destination file is present locally. | Review whether it is the right destination in context. |
| `Yes — generated on render` | The source page exists, but its HTML or directory page is created by Quarto. | Usually acceptable; confirm by rendering if needed. |
| `No — target missing` | No destination file or recognised Quarto source was found. | Correct the source link or restore the intended destination before marking the page reviewed. |

The report confirms local link resolution. It does not decide whether a link is
editorially useful or whether the destination is the best page. Review that
question using the link text, link context and destination-page summary.

## Exit status

The command returns exit code `0` when no local links are missing. It returns
`1` when one or more local links are missing. This makes it suitable as a
simple final check after a batch of manual edits.

## Suggested manual-review routine

1. Review and edit a manageable group of pages.
2. Run the relevant manual-specific link check.
3. Resolve any missing links and consider whether each destination is
   appropriate in context.
4. Change reviewed pages from `manual-review-status: not-reviewed` to
   `manual-review-status: reviewed-by-irh`.
5. Render the website locally and inspect the edited pages before committing
   your local changes.

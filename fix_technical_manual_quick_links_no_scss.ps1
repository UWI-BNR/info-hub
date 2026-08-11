# Repair the Technical Manual quick links after the SCSS design experiment.
# This removes only the tile SCSS block added by the previous patch and
# replaces the quick links with Bootstrap/Quarto classes already in the site.
# Run from the info-hub repository root on branch technical-manual-v1.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) {
    throw "Run this script from the info-hub repository root."
}

$branch = (git branch --show-current).Trim()
if ($branch -ne "technical-manual-v1") {
    throw "Expected branch technical-manual-v1; current branch is $branch."
}

# ----------------------------------------------------------------------
# 1. Remove only the Technical Manual tile SCSS added by the previous patch.
# ----------------------------------------------------------------------

$scssPath = "site/assets/scss/bnr.scss"
$scss = Get-Content -Raw -Path $scssPath

$scssPattern = '(?s)/\* -------------------------------------------------------------------------\s*Technical Manual landing-page section tiles.*?\n\}\s*$'

if ([regex]::IsMatch($scss, $scssPattern)) {
    $scss = [regex]::Replace($scss, $scssPattern, "", 1).TrimEnd() + "`r`n"
    Set-Content -Path $scssPath -Value $scss -Encoding utf8
    Write-Host "Removed the previous Technical Manual tile SCSS block."
}
else {
    Write-Host "Tile SCSS block not found at the end of bnr.scss; no SCSS removed."
}

# ----------------------------------------------------------------------
# 2. Replace the Technical Manual quick-link section with Bootstrap-only cards.
# ----------------------------------------------------------------------

$indexPath = "site/technical/index.qmd"
$content = Get-Content -Raw -Path $indexPath

$sectionPattern = '(?s)::: \{#technical-manual-sections\}.*?:::\s*(?=## What this manual covers)'

if (-not [regex]::IsMatch($content, $sectionPattern)) {
    throw "Could not find the current Technical Manual quick-link section."
}

$newCards = @'
::: {#technical-manual-sections}

## Quick links

::: {.grid}

::: {.g-col-12 .g-col-md-6 .g-col-xl-4}
::: {.card .h-100 .border-top .border-4 .border-primary .bg-light .shadow-sm}
::: {.card-body .d-flex .flex-column}

[01-02]{.small .fw-bold style="color:#d89c60; letter-spacing:0.08em;"}

### Getting started {.card-title}

Environment and workstation setup.

::: {.mt-auto}
[Open section](getting-started/environment.qmd){.btn .btn-outline-primary .btn-sm}
:::

:::
:::
:::

::: {.g-col-12 .g-col-md-6 .g-col-xl-4}
::: {.card .h-100 .border-top .border-4 .border-primary .bg-light .shadow-sm}
::: {.card-body .d-flex .flex-column}

[03-06]{.small .fw-bold style="color:#d89c60; letter-spacing:0.08em;"}

### Analytical workflows {.card-title}

Dashboards, tables and briefings.

::: {.mt-auto}
[Open section](workflows/overview.qmd){.btn .btn-outline-primary .btn-sm}
:::

:::
:::
:::

::: {.g-col-12 .g-col-md-6 .g-col-xl-4}
::: {.card .h-100 .border-top .border-4 .border-primary .bg-light .shadow-sm}
::: {.card-body .d-flex .flex-column}

[07-09]{.small .fw-bold style="color:#d89c60; letter-spacing:0.08em;"}

### Review & publication {.card-title}

Review, disclosure control and approval.

::: {.mt-auto}
[Open section](controls/review-release.qmd){.btn .btn-outline-primary .btn-sm}
:::

:::
:::
:::

::: {.g-col-12 .g-col-md-6 .g-col-xl-4}
::: {.card .h-100 .border-top .border-4 .border-primary .bg-light .shadow-sm}
::: {.card-body .d-flex .flex-column}

[10-11]{.small .fw-bold style="color:#d89c60; letter-spacing:0.08em;"}

### Operate the Info-Hub {.card-title}

Render, publish and update the site.

::: {.mt-auto}
[Open section](website/render-publish.qmd){.btn .btn-outline-primary .btn-sm}
:::

:::
:::
:::

::: {.g-col-12 .g-col-md-6 .g-col-xl-4}
::: {.card .h-100 .border-top .border-4 .border-primary .bg-light .shadow-sm}
::: {.card-body .d-flex .flex-column}

[12-14]{.small .fw-bold style="color:#d89c60; letter-spacing:0.08em;"}

### Maintain & recover {.card-title}

Change safely and fix problems.

::: {.mt-auto}
[Open section](maintenance/safe-code-change.qmd){.btn .btn-outline-primary .btn-sm}
:::

:::
:::
:::

::: {.g-col-12 .g-col-md-6 .g-col-xl-4}
::: {.card .h-100 .border-top .border-4 .border-primary .bg-light .shadow-sm}
::: {.card-body .d-flex .flex-column}

[15]{.small .fw-bold style="color:#d89c60; letter-spacing:0.08em;"}

### Quick reference {.card-title}

Files, folders, commands and terms.

::: {.mt-auto}
[Open section](reference/index.qmd){.btn .btn-outline-primary .btn-sm}
:::

:::
:::
:::

:::
:::
'@

$content = [regex]::Replace(
    $content,
    $sectionPattern,
    $newCards.TrimEnd() + "`r`n`r`n",
    1
)

Set-Content -Path $indexPath -Value $content -Encoding utf8

Write-Host ""
Write-Host "Technical Manual quick links repaired."
Write-Host "  - no new SCSS"
Write-Host "  - existing Bootstrap/Quarto classes only"
Write-Host "  - BNR primary blue from the existing theme"
Write-Host "  - warm BNR accent used only for chapter-range labels"
Write-Host "  - 3 columns wide / 2 medium / 1 small"
Write-Host "  - short descriptions and equal-height cards within each row"
Write-Host ""
git status --short
Write-Host ""
Write-Host "Next:"
Write-Host "  cd site"
Write-Host "  quarto render"

# Restore bnr.scss to the last committed Git version.
# Keeps the Technical Manual quick-link QMD changes.
# Run from the info-hub repository root on branch technical-manual-v1.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) {
    throw "Run this script from the info-hub repository root."
}

$branch = (git branch --show-current).Trim()
if ($branch -ne "technical-manual-v1") {
    throw "Expected branch technical-manual-v1; current branch is $branch."
}

$scssPath = "site/assets/scss/bnr.scss"

if (-not (Test-Path $scssPath)) {
    throw "Could not find $scssPath"
}

# Preserve the current local file before restoring.
$backupPath = "site/assets/scss/bnr.scss.before-quick-link-recovery.bak"
Copy-Item $scssPath $backupPath -Force

Write-Host ""
Write-Host "Backup created:"
Write-Host "  $backupPath"
Write-Host ""

# Confirm the committed version exists.
git cat-file -e "HEAD:$scssPath"
if ($LASTEXITCODE -ne 0) {
    throw "Git could not find the committed version of $scssPath"
}

# Restore exactly the version from the current HEAD commit.
git restore --source=HEAD --worktree -- $scssPath
if ($LASTEXITCODE -ne 0) {
    throw "Git restore failed."
}

Write-Host "Restored:"
Write-Host "  $scssPath"
Write-Host "from the current HEAD commit."
Write-Host ""

# Show whether SCSS now differs from HEAD. There should be no output here.
Write-Host "SCSS diff after restore (should be empty):"
git diff -- $scssPath

Write-Host ""
Write-Host "Current repository changes:"
git status --short

Write-Host ""
Write-Host "The .bak file is ignored by the repository's *.bak rule."
Write-Host ""
Write-Host "Next:"
Write-Host "  cd site"
Write-Host "  quarto render"

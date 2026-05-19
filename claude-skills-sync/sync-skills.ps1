# =============================================================================
# HIVEMIND — Claude Code Skills Sync (Windows / PowerShell)
# Runs on SessionStart on both HiVEMiND and DRONE01.
# Pulls the shared skills repo and copies any new/updated skills into
# the local Claude Code skills folder. Existing skills are updated in place.
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"

# ── Paths ────────────────────────────────────────────────────────────────────
# Shared Drive config (same file on both machines via Google Drive sync)
$DRIVE_AI     = "D:\My Drive\AI"
$CONFIG_FILE  = "$DRIVE_AI\claude-skills-sync\skills-config.json"
$CACHE_DIR    = "$DRIVE_AI\claude-skills-sync\.repo-cache"   # cloned repo lands here

# Local Claude Code skills folder (Windows)
$CLAUDE_SKILLS = "$env:USERPROFILE\.claude\skills"

# ── Load config ───────────────────────────────────────────────────────────────
if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "[skills-sync] Config not found at $CONFIG_FILE — skipping." -ForegroundColor Yellow
    exit 0
}

$config = Get-Content $CONFIG_FILE | ConvertFrom-Json
$REPO_URL  = $config.skills_repo_url
$BRANCH    = if ($config.branch) { $config.branch } else { "main" }
$SUBDIR    = $config.skills_subdir   # may be empty

if ($REPO_URL -eq "PASTE_GITHUB_REPO_URL_HERE" -or -not $REPO_URL) {
    Write-Host "[skills-sync] Repo URL not set in skills-config.json — skipping." -ForegroundColor Yellow
    exit 0
}

# ── Ensure local Claude skills dir exists ────────────────────────────────────
if (-not (Test-Path $CLAUDE_SKILLS)) {
    New-Item -ItemType Directory -Path $CLAUDE_SKILLS -Force | Out-Null
}

# ── Clone or pull the skills repo into the shared cache ──────────────────────
if (-not (Test-Path "$CACHE_DIR\.git")) {
    Write-Host "[skills-sync] Cloning skills repo..." -ForegroundColor Cyan
    git clone --branch $BRANCH --depth 1 $REPO_URL $CACHE_DIR 2>&1 | Out-Null
} else {
    Write-Host "[skills-sync] Pulling latest skills..." -ForegroundColor Cyan
    git -C $CACHE_DIR fetch --depth 1 origin $BRANCH 2>&1 | Out-Null
    git -C $CACHE_DIR reset --hard "origin/$BRANCH" 2>&1 | Out-Null
}

if (-not (Test-Path $CACHE_DIR)) {
    Write-Host "[skills-sync] Failed to clone/pull repo. Check URL and network." -ForegroundColor Red
    exit 1
}

# ── Determine source of skills inside the repo ───────────────────────────────
$SKILLS_SRC = if ($SUBDIR) { Join-Path $CACHE_DIR $SUBDIR } else { $CACHE_DIR }

# ── Copy each skill folder into local Claude skills dir ──────────────────────
$copied = 0
$skipped = 0

Get-ChildItem -Path $SKILLS_SRC -Directory | ForEach-Object {
    $skillName = $_.Name
    # Skip hidden dirs and the git dir
    if ($skillName -match '^\.' ) { $skipped++; return }

    $dest = Join-Path $CLAUDE_SKILLS $skillName

    # Robocopy: mirror skill folder, suppress most output
    $result = robocopy $_.FullName $dest /MIR /NFL /NDL /NJH /NJS /NC /NS 2>&1
    $copied++
}

Write-Host "[skills-sync] Done — $copied skill(s) synced to $CLAUDE_SKILLS" -ForegroundColor Green

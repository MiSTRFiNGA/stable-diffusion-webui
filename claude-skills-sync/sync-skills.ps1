# =============================================================================
# HIVEMIND — Claude Code Skills Sync (Windows / PowerShell)
# Runs on SessionStart on HiVEMiND and DRONE01.
# Pulls all skills repos from skills-config.json and installs into
# %USERPROFILE%\.claude\skills\
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"

$DRIVE_AI      = "D:\My Drive\AI"
$CONFIG_FILE   = "$DRIVE_AI\claude-skills-sync\skills-config.json"
$CACHE_ROOT    = "$DRIVE_AI\claude-skills-sync\.repo-cache"
$CLAUDE_SKILLS = "$env:USERPROFILE\.claude\skills"

if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "[skills-sync] Config not found — skipping." -ForegroundColor Yellow
    exit 0
}

$config     = Get-Content $CONFIG_FILE | ConvertFrom-Json
$repos      = $config.repos
$branch     = if ($config.branch) { $config.branch } else { "main" }

if (-not $repos -or $repos.Count -eq 0) {
    Write-Host "[skills-sync] No repos configured — skipping." -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Force -Path $CLAUDE_SKILLS | Out-Null
New-Item -ItemType Directory -Force -Path $CACHE_ROOT    | Out-Null

$totalSkills = 0

foreach ($repo in $repos) {
    $repoUrl = $repo.url
    $subdir  = $repo.subdir

    # Safe cache folder name
    $repoSlug  = $repoUrl -replace "https://github.com/", "" -replace "/", "-"
    $cacheDir  = Join-Path $CACHE_ROOT $repoSlug

    # Clone or pull — try configured branch then master
    $cloned = $false
    foreach ($branchTry in @($branch, "master")) {
        if (-not (Test-Path "$cacheDir\.git")) {
            git clone --branch $branchTry --depth 1 $repoUrl $cacheDir 2>&1 | Out-Null
            if (Test-Path "$cacheDir\.git") { $cloned = $true; break }
        } else {
            git -C $cacheDir fetch --depth 1 origin $branchTry 2>&1 | Out-Null
            git -C $cacheDir reset --hard "origin/$branchTry" 2>&1 | Out-Null
            $cloned = $true; break
        }
    }

    if (-not $cloned -or -not (Test-Path $cacheDir)) {
        Write-Host "[skills-sync] WARN: failed to clone $repoUrl — skipping." -ForegroundColor Yellow
        continue
    }

    $skillsSrc = if ($subdir) { Join-Path $cacheDir $subdir } else { $cacheDir }

    # If repo root is a single skill (has SKILL.md at root)
    if (Test-Path (Join-Path $skillsSrc "SKILL.md")) {
        $skillName = ($repoSlug -split "-")[-1]
        robocopy $skillsSrc (Join-Path $CLAUDE_SKILLS $skillName) /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
        $totalSkills++
        continue
    }

    # Otherwise each subdir with SKILL.md is a separate skill
    Get-ChildItem -Path $skillsSrc -Directory | ForEach-Object {
        $skillName = $_.Name
        if ($skillName -match '^\.' ) { return }
        if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
            robocopy $_.FullName (Join-Path $CLAUDE_SKILLS $skillName) /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
            $totalSkills++
        }
    }
}

Write-Host "[skills-sync] Done — $totalSkills skill(s) synced to $CLAUDE_SKILLS" -ForegroundColor Green

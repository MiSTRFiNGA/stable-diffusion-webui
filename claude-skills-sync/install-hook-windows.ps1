# =============================================================================
# Run this ONCE on HiVEMiND and DRONE01 (in PowerShell, no admin needed).
# It adds a SessionStart hook to Claude Code's settings so skills sync
# automatically every time Claude Code starts.
# =============================================================================

$SETTINGS_FILE = "$env:USERPROFILE\.claude\settings.json"
$SYNC_SCRIPT   = "D:\My Drive\AI\claude-skills-sync\sync-skills.ps1"

# ── Load or create settings ───────────────────────────────────────────────────
if (Test-Path $SETTINGS_FILE) {
    $settings = Get-Content $SETTINGS_FILE | ConvertFrom-Json
} else {
    New-Item -ItemType Directory -Path (Split-Path $SETTINGS_FILE) -Force | Out-Null
    $settings = [PSCustomObject]@{}
}

# ── Ensure hooks structure exists ─────────────────────────────────────────────
if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
}
if (-not $settings.hooks.PSObject.Properties['SessionStart']) {
    $settings.hooks | Add-Member -NotePropertyName 'SessionStart' -NotePropertyValue @()
}

# ── Build the hook entry ──────────────────────────────────────────────────────
$hookCommand = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SYNC_SCRIPT`""
$newHook = [PSCustomObject]@{
    matcher = ""
    hooks   = @(
        [PSCustomObject]@{
            type    = "command"
            command = $hookCommand
        }
    )
}

# ── Check if hook already exists ─────────────────────────────────────────────
$exists = $settings.hooks.SessionStart | Where-Object {
    $_.hooks | Where-Object { $_.command -like "*sync-skills*" }
}

if ($exists) {
    Write-Host "[install-hook] SessionStart hook already installed — skipping." -ForegroundColor Yellow
} else {
    $settings.hooks.SessionStart += $newHook
    Write-Host "[install-hook] SessionStart hook added." -ForegroundColor Green
}

# ── Save settings ─────────────────────────────────────────────────────────────
$settings | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS_FILE -Encoding UTF8

Write-Host ""
Write-Host "Done. Skills will now sync automatically every time Claude Code starts." -ForegroundColor Cyan
Write-Host "Settings file: $SETTINGS_FILE"
Write-Host ""
Write-Host "To sync immediately without restarting Claude, run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$SYNC_SCRIPT`""

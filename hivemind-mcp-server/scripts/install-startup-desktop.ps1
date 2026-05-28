# ============================================================
# HIVEMIND MCP SERVER — Register Windows 10 Startup Task
# Run this ONCE as Administrator in PowerShell.
# It registers the server to auto-start on every boot.
# ============================================================

$TaskName    = "HivemindMCPServer"
$ScriptPath  = "$PSScriptRoot\start-hivemind-desktop.bat"
$Description = "Hivemind MCP Server — keeps the hub running so all devices can connect over Tailscale"

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script as Administrator."
    exit 1
}

# Remove existing task if present
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task."
}

$Action  = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup

# Delay 30s after boot so Tailscale has time to connect first
$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$Trigger.Delay = "PT30S"   # 30-second delay for Tailscale to initialise

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName    $TaskName `
    -Action      $Action `
    -Trigger     $Trigger `
    -Settings    $Settings `
    -Principal   $Principal `
    -Description $Description

Write-Host ""
Write-Host "✓ Hivemind MCP Server will now auto-start 30 seconds after every boot."
Write-Host "  Task name : $TaskName"
Write-Host "  Script    : $ScriptPath"
Write-Host ""
Write-Host "To start it right now without rebooting:"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "To stop it:"
Write-Host "  Stop-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "To remove auto-start:"
Write-Host "  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"

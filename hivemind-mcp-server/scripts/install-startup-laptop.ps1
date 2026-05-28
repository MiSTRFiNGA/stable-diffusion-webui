# ============================================================
# HIVEMIND MCP SERVER — Register Windows 11 Startup Task
# Run this ONCE as Administrator on the drone-laptop.
# ============================================================

$TaskName    = "HivemindMCPServer"
$ScriptPath  = "$PSScriptRoot\start-hivemind-laptop.bat"
$Description = "Hivemind MCP Server — drone-laptop node, connects the laptop to the Tailscale hivemind"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script as Administrator."
    exit 1
}

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task."
}

$Action  = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Trigger.Delay = "PT30S"

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

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
Write-Host "✓ Hivemind MCP Server (drone-laptop) will auto-start 30s after every boot."
Write-Host ""
Write-Host "To start now:   Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "To stop:        Stop-ScheduledTask  -TaskName '$TaskName'"
Write-Host "To remove:      Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"

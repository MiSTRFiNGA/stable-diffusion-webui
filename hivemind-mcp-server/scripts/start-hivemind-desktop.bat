@echo off
:: ============================================================
:: HIVEMIND MCP SERVER — Desktop Startup Script (Windows 10)
:: PRIME DIRECTIVE: Keep this server running so any device
:: (laptop, Android) can connect and share processing.
:: ============================================================

:: Get the Tailscale IP dynamically
for /f "tokens=*" %%i in ('tailscale ip -4 2^>nul') do set TAILSCALE_IP=%%i

if "%TAILSCALE_IP%"=="" (
    echo [HIVEMIND] WARNING: Tailscale not running or no IP found. Binding to 0.0.0.0
    set TAILSCALE_IP=0.0.0.0
)

echo [HIVEMIND] Starting on %TAILSCALE_IP%:3737 ...

:: Set your secret key here — keep this file private
set HIVEMIND_API_KEY=your-secret-key
set MACHINE_NAME=hivemind-desktop
set BIND_HOST=%TAILSCALE_IP%
set PORT=3737

:: Run via WSL (Node is installed there)
wsl -d Ubuntu -- bash -c "cd /home/user/stable-diffusion-webui/hivemind-mcp-server && HIVEMIND_API_KEY=%HIVEMIND_API_KEY% MACHINE_NAME=%MACHINE_NAME% BIND_HOST=%BIND_HOST% PORT=%PORT% npm start"

@echo off
:: ============================================================
:: HIVEMIND MCP SERVER — Drone Laptop Startup Script (Win 11)
:: PRIME DIRECTIVE: The laptop runs its OWN server instance
:: so it can act as a hub if the desktop is offline, and so
:: the desktop can also offload work to the laptop.
:: ============================================================

:: Get the Tailscale IP dynamically
for /f "tokens=*" %%i in ('tailscale ip -4 2^>nul') do set TAILSCALE_IP=%%i

if "%TAILSCALE_IP%"=="" (
    echo [HIVEMIND] WARNING: Tailscale not running or no IP found. Binding to 0.0.0.0
    set TAILSCALE_IP=0.0.0.0
)

echo [HIVEMIND] drone-laptop starting on %TAILSCALE_IP%:3737 ...

:: Must use the SAME API key as the desktop
set HIVEMIND_API_KEY=your-secret-key
set MACHINE_NAME=drone-laptop
set BIND_HOST=%TAILSCALE_IP%
set PORT=3737

:: Adjust path if the repo is cloned to a different location on the laptop
set REPO_PATH=C:\Users\%USERNAME%\stable-diffusion-webui\hivemind-mcp-server

node "%REPO_PATH%\dist\index.js"

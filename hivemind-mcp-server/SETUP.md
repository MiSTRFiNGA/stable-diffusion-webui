# Hivemind MCP Server — Setup Guide

**Prime Directive:** Any device (Android, laptop, desktop) can connect over
Tailscale and share or offload processing with any other device. No device is
locked to a single role.

---

## Devices

| Device | OS | Role | Tailscale |
|---|---|---|---|
| hivemind-desktop | Windows 10 | Hub (runs the server) | 100.x.x.x |
| drone-laptop | Windows 11 | Worker + client | 100.x.x.x |
| Samsung Fold 3 | Android | Client | 100.x.x.x |

---

## Step 1 — One-time build (do this on each Windows machine)

Make sure Node.js is installed: https://nodejs.org (LTS)

```
cd hivemind-mcp-server
npm install
npm run build
```

---

## Step 2 — Edit the startup scripts

Open `scripts\start-hivemind-desktop.bat` (desktop) or
`scripts\start-hivemind-laptop.bat` (laptop) and replace:

```
set HIVEMIND_API_KEY=your-secret-key
```

with the same shared secret on **every device**. Keep this value private.

---

## Step 3 — Register auto-start (run ONCE on each machine as Administrator)

**On hivemind-desktop (Windows 10):**
```powershell
# Open PowerShell as Administrator, then:
.\scripts\install-startup-desktop.ps1
```

**On drone-laptop (Windows 11):**
```powershell
.\scripts\install-startup-laptop.ps1
```

This creates a Windows Task Scheduler task that:
- Starts the server automatically 30 seconds after every boot
- Restarts it up to 3 times if it crashes
- Runs silently in the background

---

## Step 4 — Verify the server is running

From any device on the Tailscale network:
```
curl http://<desktop-tailscale-ip>:3737/health
```
Expected response:
```json
{"status":"ok","machine":"hivemind-desktop","uptime":42.1}
```

To get the desktop's Tailscale IP (run on desktop):
```
tailscale ip -4
```

---

## Step 5 — Connect Claude Code to the hivemind

Copy the right config file to `C:\Users\<YOU>\.claude\mcp.json`:

- **hivemind-desktop:** use `client-configs\claude-desktop-mcp.json`
- **drone-laptop:** use `client-configs\claude-laptop-mcp.json`
  (edit the IP to match the desktop's Tailscale IP first)

After copying, restart Claude Code. The hivemind tools will appear automatically.

---

## Step 6 — Connect Android (Samsung Fold 3)

In whichever Claude-compatible MCP client app you use on Android:

- **URL:** `http://<desktop-tailscale-ip>:3737/mcp`
- **Auth:** `Bearer your-secret-key`

Make sure Tailscale is running on the phone before connecting.

---

## Day-to-day management

| Task | Command (PowerShell as Admin) |
|---|---|
| Start server now | `Start-ScheduledTask -TaskName HivemindMCPServer` |
| Stop server | `Stop-ScheduledTask -TaskName HivemindMCPServer` |
| Remove auto-start | `Unregister-ScheduledTask -TaskName HivemindMCPServer -Confirm:$false` |

---

## Available MCP tools (visible to every connected Claude session)

| Tool | What it does |
|---|---|
| `set_memory` | Store a value — all devices see it |
| `get_memory` | Read a stored value |
| `list_memory` | List all keys |
| `delete_memory` | Remove a key |
| `append_log` | Add a timestamped log entry |
| `read_log` | Read recent log entries |
| `send_message` | Send to a specific device or broadcast |
| `get_messages` | Fetch messages addressed to you |
| `clear_messages` | Purge read messages |

---

## File layout

```
hivemind-mcp-server/
├── src/index.ts                          source (TypeScript)
├── dist/index.js                         compiled — this is what runs
├── package.json
├── tsconfig.json
├── SETUP.md                              this file
├── scripts/
│   ├── start-hivemind-desktop.bat        desktop startup script
│   ├── install-startup-desktop.ps1       desktop Task Scheduler installer
│   ├── start-hivemind-laptop.bat         laptop startup script
│   └── install-startup-laptop.ps1        laptop Task Scheduler installer
└── client-configs/
    ├── claude-desktop-mcp.json           MCP config for desktop Claude Code
    └── claude-laptop-mcp.json            MCP config for laptop Claude Code
```

# HiVEMiND — Claude Cross-Device Setup
**Last updated:** 2026-05-19  
**Written by:** Claude Code (session on HiVEMiND WSL)  
**Purpose:** Complete reference so any Claude instance on any device can read this and know exactly where everything is, what was built, and how to pick up where we left off.

---

## The Machines

| Name | Device | OS | GPU | Tailscale IP |
|---|---|---|---|---|
| **HiVEMiND** | Custom Desktop | Windows 11 | RTX 5070 Ti (16 GB VRAM) | `100.86.132.90` |
| **DRONE01** | ASUS ZenBook Pro Duo UX582ZW | Windows 11 | RTX 3070 Ti + Intel Iris Xe | `100.86.202.8` |
| **Mobile** | Samsung Galaxy Z Fold 3 | Android | — | Tailscale client only |

All three are connected via **Tailscale VPN**. DRONE01 offloads all heavy AI compute to HiVEMiND over Tailscale. HiVEMiND is the GPU powerhouse and primary server. Mobile is client-only (no server role).

---

## Prime Directive

Any device can connect over Tailscale and share or offload processing with any other device. No device is locked to a single role. Every device is both a potential client and a potential worker. The hivemind MCP server is the coordination layer that makes this possible.

---

## Shared Drive (Memory Between All Claudes)

Both Windows machines sync to the same Google Drive AI folder — different local paths, same files:

| What | HiVEMiND path | DRONE01 path |
|---|---|---|
| AI root | `D:\Drive\AI\` | `D:\My Drive\AI\` |
| Skills sync config | `...\claude-skills-sync\skills-config.json` | same |
| Skills cache | `...\claude-skills-sync\.repo-cache\` | same |
| Session memory | `...\Memory\shared-sessions\` | same |
| Obsidian vault (primary) | `D:\My Drive\AI\Memory\` | same |
| Obsidian vault (legacy) | `D:\My Drive\AI\Vault\` | same |
| Network config | `...\configs\hivemind-network.json` | same |

**This file** lives at: `D:\My Drive\AI\HIVEMIND-CLAUDE.md`  
Also committed in git repo: `stable-diffusion-webui/HIVEMIND-CLAUDE.md`

---

## What Was Built (by Claude Code, 2026-05-19)

### 1. Hivemind MCP Server

**Purpose:** Enables Claude instances on any device to share memory, coordinate tasks, and pass messages to each other. This is the backbone of cross-device Claude coordination.

**Location:** `D:\Drive\AI\stable-diffusion-webui\hivemind-mcp-server\` (git repo)  
**Git branch:** `claude/build-hivemind-mcp-nKg5b`  
**Entry point:** `src/index.ts` → compiled to `dist/index.js`

**How it works:**
- Runs as an HTTP server (Node.js + TypeScript)
- Exposes a single MCP endpoint at `http://<TAILSCALE_IP>:3737/mcp`
- Uses `@modelcontextprotocol/sdk` with `StreamableHTTPServerTransport`
- All state is in-memory (Map + arrays), shared across all connected Claude sessions
- Sessions tracked by `mcp-session-id` header to avoid "not initialized" errors
- API key auth via `Authorization: Bearer <HIVEMIND_API_KEY>` header

**Start on HiVEMiND (PowerShell):**
```powershell
$env:HIVEMIND_API_KEY = "your-secret-key"
$env:MACHINE_NAME    = "hivemind-desktop"
$env:BIND_HOST       = "100.86.132.90"
$env:PORT            = "3737"
cd D:\Drive\AI\stable-diffusion-webui\hivemind-mcp-server
npm start
```

**Health check:** `http://100.86.132.90:3737/health`

**Auto-start on boot:**  
Run once as Admin: `scripts\install-startup-desktop.ps1`  
This creates a Task Scheduler task that starts the server 30 seconds after login with 3 auto-restarts.

**Available MCP tools (what Claude can call):**

| Tool | What it does |
|---|---|
| `set_memory` | Store a key/value (tagged with machine name + timestamp) |
| `get_memory` | Read a value by key |
| `list_memory` | List all stored keys |
| `delete_memory` | Remove a key |
| `append_log` | Append a timestamped message to the shared log |
| `read_log` | Read the last N log entries |
| `send_message` | Put a message in the queue (to: device name, body: text) |
| `get_messages` | Read messages (optionally filtered by recipient) |
| `clear_messages` | Clear all messages |

**Push a task from command line (while Claude is away):**
```bash
node push-task.js "task/wix/bar-necklace" "Set up bar necklace product page on Wix..."
```

**MCP client config files:**
- `client-configs/claude-desktop-mcp.json` — for HiVEMiND (localhost)
- `client-configs/claude-laptop-mcp.json` — for DRONE01 (Tailscale IP)

To wire Claude Desktop up to the MCP server, merge the relevant client config into `%APPDATA%\Claude\claude_desktop_config.json`.

---

### 2. Wix Bar Necklace Store

**Purpose:** Product page on royaltyphotographystudios.com where customers type engraving text, choose a font, see a live gold bar preview, and place an order with the text+font included.

**Files in git repo:**
- `wix-store/bar-necklace-page.js` — Velo page code (paste into Wix editor)
- `wix-store/font-preview.html` — HTML iframe with gold bar + chain visual (upload as media)
- `wix-store/SETUP.md` — 8-step guide to wire it up in Wix

**What it does:**
- Text input with 20-char limit + countdown
- Font picker: Block/Print, Script/Cursive, Serif
- Live iframe preview updates as user types (postMessage)
- "Add to Cart" passes engraving text + font as custom fields in the order
- Order confirmation message shown after add-to-cart

**Status:** Code written, task queued in hivemind memory for desktop Claude to execute.  
Key in hivemind memory: `task/wix/bar-necklace`

**To have desktop Claude do the Wix setup:**  
Open Claude Code on HiVEMiND and say:  
*"Check hivemind for pending tasks and complete the Wix bar necklace setup"*

---

### 3. Claude Skills Auto-Sync

**Purpose:** Every time Claude Code starts on any machine, it automatically pulls the latest skills from 4 GitHub repos and installs them locally. No manual steps required.

**Config file:** `D:\My Drive\AI\claude-skills-sync\skills-config.json`  
(Also in git repo: `claude-skills-sync/skills-config.json`)

**Current skill repos (all use `subdir: "skills"`):**

| Repo | URL | What's in it |
|---|---|---|
| superpowers | `https://github.com/obra/superpowers` | 14 skills: TDD, debugging, brainstorming, git worktrees, etc. |
| ECC | `https://github.com/affaan-m/ECC` | 4 skills: enterprise agent ops, Java standards, Kotlin patterns, etc. |
| Obsidian CLI | `https://github.com/pablo-mano/Obsidian-CLI-skill` | obsidian-cli skill |
| Karpathy | `https://github.com/multica-ai/andrej-karpathy-skills` | karpathy-guidelines skill |

**Total installed:** 248 skills

**How sync works on Linux/WSL (HiVEMiND):**
- Script: `claude-skills-sync/sync-skills.sh`
- Tries `D:\My Drive\AI\claude-skills-sync\skills-config.json` first
- Falls back to repo-local `claude-skills-sync/skills-config.json` if Drive not mounted
- Clones repos into `.repo-cache/`, tries `main` branch then `master`
- Installs each skill dir (that has `SKILL.md`) into `~/.claude/skills/`
- Hook in `/root/.claude/settings.json` runs this script on every `SessionStart`

**How sync works on Windows (HiVEMiND + DRONE01):**
- Script: `claude-skills-sync/sync-skills.ps1`
- Uses `robocopy` instead of `rsync`
- Same logic: clone/pull repos, install each skill dir

**One-time setup on each Windows machine:**
1. Copy `claude-skills-sync\` folder to `D:\My Drive\AI\claude-skills-sync\`
2. Run in PowerShell:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "D:\My Drive\AI\claude-skills-sync\install-hook-windows.ps1"
   ```
3. This merges a `SessionStart` hook into `%USERPROFILE%\.claude\settings.json`

---

## Installed AI Ecosystem

### Ollama (local model server on HiVEMiND)
- Runs at `http://localhost:11434` (local) / `http://100.86.132.90:11434` (remote)
- OpenAI-compat: add `/v1` to either URL
- Auto-starts on HiVEMiND login

Key models:
| Model | Size | Used by |
|---|---|---|
| `qwen3:14b` | 9.3 GB | Open Interpreter, LocalAGI drone-agent |
| `qwen2.5-coder:14b` | 9.0 GB | Cline, JARVIS CodeWriter |
| `qwen3.5:latest` | 6.6 GB | JARVIS default + TradingAnalyst |
| `deepseek-coder-v2` | 8.9 GB | JARVIS CodeReviewer |
| `gemma3:12b` | 8.1 GB | JARVIS vision/screen describe |
| `nomic-embed-text` | 274 MB | Embeddings / RAG / memory |

GPU env vars required (RTX 5070 Ti, Blackwell sm_120):
```
CUDA_VISIBLE_DEVICES=0
OLLAMA_GPU_OVERHEAD=0
OLLAMA_FLASH_ATTENTION=1
OLLAMA_MODELS=G:\ComfyUI\...\models\llm
```

### JARVIS (local multi-agent AI assistant)
- Location: `D:\Drive\AI\JARVIS\`
- Entry point: `gateway_bridge.mjs` (Node.js orchestrator)
- Web UI: `http://127.0.0.1:4200` — launch via `Launch JARVIS UI.bat`
- 6 specialists auto-routed by keyword: JARVIS (default), CodeWriter, CodeReviewer, TradingAnalyst, Researcher, Debugger
- Knowledge vault: `D:\Drive\AI\JARVIS\Brain\` — `JARVIS.md` injected into every prompt
- Tools: read_file, write_file, screenshot, describe_screen, mouse_click, generate_image, generate_video, open_url, search_vault, write_note, and more

### LocalAGI (autonomous agent server)
- Runs on HiVEMiND, auto-starts via `LocalAGI.vbs`
- Web UI: `http://localhost:3000` / `http://100.86.132.90:3000`
- Active agent: `drone-agent` using `qwen3:14b`
- Chat: `POST http://100.86.132.90:3000/api/chat/drone-agent`

### Cline (VS Code AI coding agent)
- Installed on both machines, uses `qwen2.5-coder:14b` via Ollama
- HiVEMiND: connects to `http://localhost:11434/v1`
- DRONE01: connects to `http://100.86.132.90:11434/v1`

### Open Interpreter
- Version 0.4.3, Python 3.12, model: `qwen3:14b` (thinking mode)
- HiVEMiND shortcut: `Open Interpreter (Local)`
- DRONE01 shortcut: `Open Interpreter (HiVEMiND)` → tunnels to desktop GPU

### ComfyUI (image & video generation)
- Runs on HiVEMiND at `http://127.0.0.1:8188`
- Models: `G:\ComfyUI\ComfyUI_windows_portable\ComfyUI\models\`
- Video: Wan 2.2 + VBVR LoRA for t2v/i2v
- LTX 2.3 + Transition LoRA for scene stitching

---

## How Claude Instances Connect

```
Android (Mobile)
    │
    │  Tailscale
    ▼
HiVEMiND (100.86.132.90)
    ├── Hivemind MCP Server :3737  ◄──── All Claudes write/read shared memory here
    ├── Ollama :11434              ◄──── DRONE01 Claude sends inference here
    ├── LocalAGI :3000
    ├── JARVIS :4200
    └── ComfyUI :8188
    │
    │  Tailscale
    ▼
DRONE01 (100.86.202.8)
    └── Claude Code → points Ollama at HiVEMiND IP
```

**Cross-device task flow:**
1. Any Claude calls `set_memory` on hivemind MCP with a task key
2. Target machine's Claude calls `get_messages` or `get_memory` to pick up the task
3. Target Claude executes and calls `append_log` to report back
4. Originating Claude calls `read_log` to see the result

---

## Git Repository

**Repo:** `MiSTRFiNGA/stable-diffusion-webui`  
**Active branch:** `claude/build-hivemind-mcp-nKg5b`  
**PR:** Draft PR open on this branch — merge when ready

All hivemind-specific files live here:
```
stable-diffusion-webui/
├── CLAUDE.md                          ← auto-loaded by every Claude session
├── HIVEMIND-CLAUDE.md                 ← this file (full reference)
├── hivemind-mcp-server/
│   ├── src/index.ts                   ← MCP server source
│   ├── push-task.js                   ← CLI task pusher
│   ├── scripts/
│   │   ├── install-startup-desktop.ps1
│   │   ├── install-startup-laptop.ps1
│   │   ├── start-hivemind-desktop.bat
│   │   └── start-hivemind-laptop.bat
│   └── client-configs/
│       ├── claude-desktop-mcp.json
│       └── claude-laptop-mcp.json
├── wix-store/
│   ├── bar-necklace-page.js
│   ├── font-preview.html
│   └── SETUP.md
└── claude-skills-sync/
    ├── skills-config.json
    ├── sync-skills.sh
    ├── sync-skills.ps1
    └── install-hook-windows.ps1
```

---

## Remaining TODO Items

- [ ] **Wix setup:** Open Claude Code on HiVEMiND (it has web control), say "check hivemind for pending tasks" — it will find `task/wix/bar-necklace` and complete the store setup
- [ ] **Windows skills hook:** Copy `claude-skills-sync\` to `D:\My Drive\AI\claude-skills-sync\` on both machines, run `install-hook-windows.ps1` once on each
- [ ] **MCP auto-start on HiVEMiND:** Run `scripts\install-startup-desktop.ps1` as Admin once
- [ ] **MCP auto-start on DRONE01:** Run `scripts\install-startup-laptop.ps1` as Admin once
- [ ] **Wire Claude Desktop to MCP:** Merge `client-configs\claude-desktop-mcp.json` into `%APPDATA%\Claude\claude_desktop_config.json` on HiVEMiND (use real API key)
- [ ] **Real API key:** Replace `"your-secret-key"` placeholder in startup scripts with actual key

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Ollama not responding | `curl http://localhost:11434/api/tags` — if nothing, run `ollama serve` with GPU env vars |
| MCP server not reachable | Check Task Scheduler task is running; verify Tailscale is up; check firewall allows port 3737 |
| Skills not syncing | Check `SessionStart` hook in `%USERPROFILE%\.claude\settings.json`; run sync script manually |
| `push-task.js` "not initialized" | Server was restarted — sessions are in-memory only, reconnect and retry |
| DRONE01 Claude slow | Verify it's pointing Ollama at `http://100.86.132.90:11434/v1` not localhost |
| JARVIS blank responses | `num_predict` too low for qwen3.5 — must be ≥ 2048 |

Test GPU: `python C:\JARVIS\test_gpu.py` (>20 tok/s = GPU working)  
Test Ollama: `curl http://localhost:11434/api/tags`  
Test hivemind: `curl http://100.86.132.90:3737/health`

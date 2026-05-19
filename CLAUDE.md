# HiVEMiND AI Ecosystem — Claude Reference

**Owner:** MiSTRFiNGA (Eric)
**Last updated:** 2026-05-19

This file is loaded automatically by every Claude Code session.
It tells you who Eric is, what machines exist, what is installed,
where everything lives, and what the prime directive is.

---

## Prime Directive

Any device (Android, DRONE01 laptop, HiVEMiND desktop) can connect
over Tailscale and share or offload processing with any other device.
No device is locked to a single role. Every device is both a potential
client and a potential worker.

---

## The Machines

| Name | Device | OS | GPU | Tailscale IP |
|---|---|---|---|---|
| **HiVEMiND** | Custom Desktop | Windows 11 | RTX 5070 Ti (16 GB VRAM) | `100.86.132.90` |
| **DRONE01** | ASUS ZenBook Pro Duo UX582ZW | Windows 11 | RTX 3070 Ti + Intel Iris Xe | `100.86.202.8` |
| **Mobile** | Samsung Galaxy Z Fold 3 | Android | — | Tailscale client |

DRONE01 offloads all AI compute to HiVEMiND over Tailscale.
HiVEMiND runs everything locally on its GPU.

---

## Shared Drive / Memory Locations

Both machines sync to the same Google Drive AI folder — different local paths, same files.

| What | HiVEMiND path | DRONE01 path |
|---|---|---|
| AI root | `D:\Drive\AI\` | `D:\My Drive\AI\` |
| Session memory | `...\Memory\shared-sessions\` | `...\Memory\shared-sessions\` |
| Obsidian vault (primary) | `D:\My Drive\AI\Memory\` | `D:\My Drive\AI\Memory\` |
| Obsidian vault (legacy) | `D:\My Drive\AI\Vault\` | `D:\My Drive\AI\Vault\` |
| Network config | `...\configs\hivemind-network.json` | `...\configs\hivemind-network.json` |

**JARVIS Brain vault:** `D:\Drive\AI\JARVIS\Brain\`
- `JARVIS.md` = master briefing injected into every JARVIS prompt
- Subfolders: Projects, Trading, Notes, Research, People, Daily, Resources

---

## Ollama (local model server)

Runs on HiVEMiND. Serves all models via OpenAI-compatible API.
Auto-starts on HiVEMiND login. Version: 0.22.0

| Endpoint | URL |
|---|---|
| Local (on HiVEMiND) | `http://localhost:11434` |
| Remote (from DRONE / phone) | `http://100.86.132.90:11434` |
| OpenAI-compat local | `http://localhost:11434/v1` |
| OpenAI-compat remote | `http://100.86.132.90:11434/v1` |

**GPU config required (RTX 5070 Ti, Blackwell sm_120):**
```
CUDA_VISIBLE_DEVICES=0
OLLAMA_GPU_OVERHEAD=0
OLLAMA_MODELS=G:\ComfyUI\ComfyUI_windows_portable\ComfyUI\models\llm
OLLAMA_FLASH_ATTENTION=1
```

### Installed models

| Model | Size | Used by |
|---|---|---|
| `qwen3:14b` | 9.3 GB | Open Interpreter, LocalAGI drone-agent |
| `qwen2.5-coder:14b` | 9.0 GB | Cline, JARVIS CodeWriter |
| `qwen3.5:latest` | 6.6 GB | JARVIS default + TradingAnalyst |
| `deepseek-coder-v2` | 8.9 GB | JARVIS CodeReviewer, Cline deep tasks |
| `qwen2.5-coder:7b` | 4.7 GB | JARVIS Debugger |
| `gemma3:12b` | 8.1 GB | JARVIS vision / screen describe |
| `gemma3:4b` | 3.3 GB | JARVIS Researcher |
| `nomic-embed-text` | 274 MB | Embeddings / RAG / memory |
| `gemma-td:latest` | 9.6 GB | UE5 theatrical TD agent |
| `openclaw-td:latest` | 9.0 GB | UE5 / OpenClaw TD |
| `glm-4.7-flash` | 19.0 GB | Available, CPU-offloads (too large for VRAM) |

---

## JARVIS (local multi-agent AI assistant)

**Location:** `D:\Drive\AI\JARVIS\`
**Entry point:** `gateway_bridge.mjs` (Node.js orchestrator)
**Frontends:**
- JARVIS UI → `http://127.0.0.1:4200` (launch: `Launch JARVIS UI.bat`)
- OpenClaw → stdin/stdout JSON to gateway

### 6 Specialists (auto-routed by keyword scoring)

| Agent | Model | Access | Triggers |
|---|---|---|---|
| JARVIS (default) | qwen3.5:latest | write | catch-all |
| CodeWriter | qwen2.5-coder:14b | write | write, create, implement, build, fix |
| CodeReviewer | deepseek-coder-v2 | read-only | review, audit, find bugs, security |
| TradingAnalyst | qwen3.5:latest | read-only | trade, fortress, p&l, portfolio |
| Researcher | gemma3:4b | read-only | search, look up, fetch, browse |
| Debugger | qwen2.5-coder:7b | read-only | error, crash, traceback, broken |

**Advanced protocols:**
- `/tlddr` — summarises session → saves to `Brain/Daily/`
- `/dream` — consolidates all session notes → `Brain/JARVIS-Master-State.md`
- AutoResearch agent — closed-loop hypothesis→implement→test→evaluate
- SwarmDebate agent — Developer vs Auditor internal debate (Mirofish Protocol)

**Key files:**
```
D:\Drive\AI\JARVIS\
├── gateway_bridge.mjs     Node.js orchestrator (main entry point)
├── jarvis_server.mjs      Web UI HTTP server (port 4200)
├── jarvis_ui.html         Dark-theme streaming chat UI
├── jarvis_tools.py        Python tool executor (screen, mouse, browser, vault)
├── Launch JARVIS UI.bat   One-click launcher
├── agents\                Specialist JSON configs
└── Brain\                 Obsidian knowledge vault
    └── JARVIS.md          Master briefing (injected into every prompt)
```

**Tools available to JARVIS:** read_file, write_file, list_dir, run_command,
screenshot, describe_screen, mouse_click, type_text, press_hotkey, scroll,
get_clipboard, set_clipboard, list_windows, open_url, get_page, search_vault,
write_note, generate_image, generate_video

---

## LocalAGI (autonomous agent server)

Runs on HiVEMiND, auto-starts via `LocalAGI.vbs` on login.
Accessible from any browser on Tailscale.

| Endpoint | URL |
|---|---|
| Web UI (remote) | `http://100.86.132.90:3000` |
| Web UI (local) | `http://localhost:3000` |
| Chat agent | `POST http://100.86.132.90:3000/api/chat/drone-agent` |
| List agents | `GET http://100.86.132.90:3000/api/agents` |
| SSE stream | `GET http://100.86.132.90:3000/api/sse/drone-agent` |
| OpenAI-compat | `POST http://100.86.132.90:3000/v1/responses` |

Active agent: `drone-agent` | Model: `qwen3:14b`
State/memory: `D:\Drive\AI\LocalAGI\pool\`
Source: `D:\Drive\AI\LocalAGI\localagi-src\`

---

## Cline (AI coding agent in VS Code)

Installed on both machines. Uses `qwen2.5-coder:14b` via Ollama.

| Machine | API endpoint |
|---|---|
| HiVEMiND | `http://localhost:11434/v1` |
| DRONE01 | `http://100.86.132.90:11434/v1` |

Access: VS Code → robot icon in left sidebar

---

## Open Interpreter (computer automation)

Version 0.4.3 (Python 3.12). Model: `qwen3:14b` (thinking mode).
Installed on both machines. DRONE tunnels to HiVEMiND GPU.

| Machine | Shortcut | API endpoint |
|---|---|---|
| HiVEMiND | `Open Interpreter (Local)` | `http://localhost:11434/v1` |
| DRONE01 | `Open Interpreter (HiVEMiND)` | `http://100.86.132.90:11434/v1` |

Profiles: `...\configs\open-interpreter-hivemind.yaml` / `open-interpreter-drone.yaml`

---

## ComfyUI (image & video generation)

Runs on HiVEMiND at `http://127.0.0.1:8188`
JARVIS can generate images/video autonomously via `generate_image` tool.
Models: `G:\ComfyUI\ComfyUI_windows_portable\ComfyUI\models\`

Video pipeline: Wan 2.2 + VBVR LoRA (physics fix) for t2v/i2v.
LTX 2.3 + Transition LoRA for scene stitching (image_start + image_end).

---

## Hivemind MCP Server (built in this repo)

Enables shared memory and task coordination between Claude sessions across all devices.

**Location:** `stable-diffusion-webui/hivemind-mcp-server/`
**MCP endpoint:** `http://<TAILSCALE_IP>:3737/mcp`
**Health check:** `http://<TAILSCALE_IP>:3737/health`
**Auth:** `Authorization: Bearer <HIVEMIND_API_KEY>`

Start on HiVEMiND (PowerShell):
```powershell
$env:HIVEMIND_API_KEY="your-secret-key"
$env:MACHINE_NAME="hivemind-desktop"
$env:BIND_HOST="100.86.132.90"
$env:PORT="3737"
npm start
```

Auto-start: `scripts\install-startup-desktop.ps1` (run as Admin once)
MCP client config: `client-configs\claude-desktop-mcp.json`

Push a task to another Claude session:
```
node push-task.js "task/key" "task description"
```

**Tools:** set_memory, get_memory, list_memory, delete_memory,
append_log, read_log, send_message, get_messages, clear_messages

---

## Faceless Video Pipeline

Location: `D:\Drive\AI\FacelessVideo\`
Steps: Ingest transcript → Rewrite (gemma3:12b) → Audio (edge-tts) → Visuals (ComfyUI) → Assembly (moviepy)
Key file: `faceless_pipeline.py`
ffmpeg: installed via WinGet

---

## Troubleshooting Quick Reference

| Problem | Fix |
|---|---|
| Ollama not responding | `curl http://localhost:11434/api/tags` — if nothing, run `ollama serve` with GPU env vars |
| JARVIS gives blank responses | `num_predict` too low for qwen3.5 — must be ≥ 2048 |
| GPU not used (slow <5 tok/s) | Set `CUDA_VISIBLE_DEVICES=0` + `OLLAMA_GPU_OVERHEAD=0`, restart Ollama |
| Wrong JARVIS agent triggered | Edit triggers in `agents\<name>.json`, restart gateway |
| JARVIS Brain not loading | Check `Brain\JARVIS.md` exists; check `VAULT` path in `gateway_bridge.mjs` |
| Screenshot/vision not working | `ollama list` — check `gemma3:12b` is installed |

Test GPU: `python C:\JARVIS\test_gpu.py` (>20 tok/s = GPU working)
Test Ollama: `curl http://localhost:11434/api/tags`
Test gateway syntax: `node --input-type=module --check < gateway_bridge.mjs`

---

## Software Versions (last confirmed working)

| Software | Version |
|---|---|
| Ollama | 0.22.0 |
| Node.js | 24.14.0 |
| Python | 3.14.3 |
| PyTorch | 2.12.0.dev+cu128 (RTX 5070 Ti sm_120 support) |
| Cline | v3.82.0 |
| Open Interpreter | 0.4.3 |
| mss | 10.1.0 |
| Pillow | 12.1.1 |
| pyautogui | 0.9.54 |
| pyperclip | 1.11.0 |

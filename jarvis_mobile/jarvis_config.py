"""
JARVIS II Mobile Thin Client Configuration
Ported from HiVEMiND (Windows) -> Android (Termux/proot Ubuntu)
Mode: CONTROLLER — all heavy compute routed to HiVEMiND via Tailscale
"""

import os
import sys
import socket
import subprocess

# ─── Operational Mode ──────────────────────────────────────────────────────────
MODE = os.environ.get("JARVIS_MODE", "CONTROLLER")

# ─── HiVEMiND Tailscale Network ────────────────────────────────────────────────
# IPv4:     100.86.132.90
# Hostname: hivemind.tailcbd4e0.ts.net
# IPv6:     fd7a:115c:a1e0::c301:8499
HIVEMIND_TAILSCALE_IP = os.environ.get("HIVEMIND_IP", "100.86.132.90")

# ─── Remote Service Endpoints (all traffic → HiVEMiND) ─────────────────────────
ENDPOINTS = {
    "sdwebui":  f"http://{HIVEMIND_TAILSCALE_IP}:7860",
    "comfyui":  f"http://{HIVEMIND_TAILSCALE_IP}:8188",
    "fastapi":  f"http://{HIVEMIND_TAILSCALE_IP}:8000",
    "ollama":   f"http://{HIVEMIND_TAILSCALE_IP}:11434",
    "tts":      f"http://{HIVEMIND_TAILSCALE_IP}:5002",
    "whisper":  f"http://{HIVEMIND_TAILSCALE_IP}:9000",
}

# ─── Local Controller Settings ─────────────────────────────────────────────────
LOCAL_CONTROLLER_PORT = int(os.environ.get("JARVIS_LOCAL_PORT", "8765"))
LOCAL_HOST            = "127.0.0.1"
LOG_LEVEL             = os.environ.get("JARVIS_LOG_LEVEL", "INFO")

# ─── Connectivity ───────────────────────────────────────────────────────────────
TAILSCALE_PING_TIMEOUT = 5   # seconds
TAILSCALE_PING_COUNT   = 3


def resolve_endpoint(service: str) -> str:
    """Return the remote endpoint URL for a named service, raising if unknown."""
    if service not in ENDPOINTS:
        raise KeyError(f"Unknown service '{service}'. Known: {list(ENDPOINTS)}")
    return ENDPOINTS[service]


def check_tailscale_connectivity(ip: str = HIVEMIND_TAILSCALE_IP) -> bool:
    """Ping the HiVEMiND Tailscale IP. Returns True if reachable."""
    try:
        result = subprocess.run(
            ["ping", "-c", str(TAILSCALE_PING_COUNT), "-W", str(TAILSCALE_PING_TIMEOUT), ip],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=TAILSCALE_PING_TIMEOUT * TAILSCALE_PING_COUNT + 2,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def check_tcp_reachable(ip: str, port: int, timeout: int = 5) -> bool:
    """TCP-level check — faster than ping when ICMP is blocked."""
    try:
        with socket.create_connection((ip, port), timeout=timeout):
            return True
    except OSError:
        return False


def assert_controller_mode():
    """Abort if not running in CONTROLLER mode."""
    if MODE != "CONTROLLER":
        sys.exit(f"[JARVIS] Expected MODE=CONTROLLER, got '{MODE}'. Aborting.")


def print_config():
    print(f"[JARVIS] Mode              : {MODE}")
    print(f"[JARVIS] HiVEMiND IP       : {HIVEMIND_TAILSCALE_IP}")
    print(f"[JARVIS] Controller port   : {LOCAL_CONTROLLER_PORT}")
    for svc, url in ENDPOINTS.items():
        print(f"[JARVIS]   {svc:<12}: {url}")

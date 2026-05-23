#!/usr/bin/env bash
# ============================================================
# JARVIS II — Thin Client Brain Startup Script
# Checks Tailscale, activates venv, starts CONTROLLER module.
# Usage:  bash start_brain.sh [--probe] [--no-wait]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$REPO_DIR/venv"
ENV_FILE="$SCRIPT_DIR/.env.jarvis"
LOG_FILE="$SCRIPT_DIR/logs/jarvis_controller.log"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[JARVIS]${NC} $*"; }
success() { echo -e "${GREEN}[JARVIS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[JARVIS]${NC} $*"; }
die()     { echo -e "${RED}[JARVIS ERROR]${NC} $*" >&2; exit 1; }

ARG_PROBE=false
ARG_NO_WAIT=false
for arg in "$@"; do
    case "$arg" in
        --probe)    ARG_PROBE=true ;;
        --no-wait)  ARG_NO_WAIT=true ;;
    esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════╗"
echo -e "  ║   JARVIS II  —  Mobile Controller    ║"
echo -e "  ║   Android Thin Client  │  HiVEMiND    ║"
echo -e "  ╚══════════════════════════════════════╝${NC}"
echo ""

# ── Load env ──────────────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    info "Loaded env from $ENV_FILE"
else
    warn ".env.jarvis not found. Using defaults (HIVEMIND_IP=100.x.x.x)."
fi

HIVEMIND_IP="${HIVEMIND_IP:-100.x.x.x}"
JARVIS_MODE="${JARVIS_MODE:-CONTROLLER}"
JARVIS_LOCAL_PORT="${JARVIS_LOCAL_PORT:-8765}"

info "Mode           : $JARVIS_MODE"
info "HiVEMiND IP    : $HIVEMIND_IP"
info "Controller port: $JARVIS_LOCAL_PORT"

# ── Validate IP ───────────────────────────────────────────────────────────────
if [[ "$HIVEMIND_IP" == "100.x.x.x" ]]; then
    die "HIVEMIND_IP is not configured. Edit $ENV_FILE and set your Tailscale IP."
fi

# ── Tailscale connectivity check ──────────────────────────────────────────────
info "Checking Tailscale connectivity to HiVEMiND ($HIVEMIND_IP)…"
PING_OK=false
if command -v ping &>/dev/null; then
    if ping -c 3 -W 5 "$HIVEMIND_IP" &>/dev/null; then
        PING_OK=true
        success "Tailscale ping: HiVEMiND is REACHABLE."
    fi
fi

if ! $PING_OK; then
    # Fallback: TCP check on port 8000 (FastAPI)
    if command -v python3 &>/dev/null; then
        TCP_OK=$(python3 -c "
import socket, sys
try:
    s=socket.create_connection(('$HIVEMIND_IP',8000),timeout=5)
    s.close(); print('1')
except: print('0')
")
        if [ "$TCP_OK" = "1" ]; then
            PING_OK=true
            success "TCP check on port 8000: HiVEMiND is REACHABLE."
        fi
    fi
fi

if ! $PING_OK; then
    warn "HiVEMiND is NOT reachable right now."
    if $ARG_NO_WAIT; then
        warn "Proceeding without Tailscale (--no-wait). Controller will start but proxy calls will fail."
    else
        warn "Waiting 10 s and retrying once…"
        sleep 10
        if ping -c 2 -W 5 "$HIVEMIND_IP" &>/dev/null; then
            success "HiVEMiND now reachable on retry."
        else
            die "HiVEMiND still unreachable. Make sure Tailscale is up on both devices."
        fi
    fi
fi

# ── Activate virtual environment ──────────────────────────────────────────────
if [ ! -d "$VENV_DIR" ]; then
    die "venv not found at $VENV_DIR. Run setup_mobile_env.sh first."
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
success "Virtual environment activated: $VENV_DIR"

# ── Optional probe ────────────────────────────────────────────────────────────
if $ARG_PROBE; then
    info "Running pre-flight probe against HiVEMiND FastAPI…"
    python3 -c "
import sys; sys.path.insert(0,'$SCRIPT_DIR')
import jarvis_config as cfg
from jarvis_controller import probe_hivemind
ok = probe_hivemind()
print('[JARVIS] Probe result:', 'PASS' if ok else 'FAIL')
sys.exit(0 if ok else 1)
"
fi

# ── Start controller ──────────────────────────────────────────────────────────
mkdir -p "$SCRIPT_DIR/logs"
info "Starting JARVIS Controller… (log → $LOG_FILE)"
echo ""

export JARVIS_MODE HIVEMIND_IP JARVIS_LOCAL_PORT

python3 "$SCRIPT_DIR/jarvis_controller.py" 2>&1 | tee -a "$LOG_FILE"

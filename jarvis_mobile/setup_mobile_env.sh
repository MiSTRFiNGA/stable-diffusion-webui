#!/usr/bin/env bash
# ============================================================
# JARVIS II — Android Thin Client Environment Setup
# Target: Termux → proot-distro → Ubuntu (Samsung Fold 7)
# Run this ONCE inside the Ubuntu proot environment.
# ============================================================
set -euo pipefail

REPO_DIR="$HOME/stable-diffusion-webui"
JARVIS_DIR="$HOME/jarvis_mobile"
VENV_DIR="$REPO_DIR/venv"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[JARVIS SETUP]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── 1. System packages ────────────────────────────────────────────────────────
info "Updating package lists and upgrading…"
apt update -qq && apt upgrade -y -qq

info "Installing Python, Git, curl…"
apt install -y -qq python3 python3-pip python3-venv git curl iputils-ping

success "System packages ready."

# ── 2. Project directory ──────────────────────────────────────────────────────
info "Ensuring project directory: $REPO_DIR"
if [ ! -d "$REPO_DIR" ]; then
    warn "Repo not found. Cloning from GitHub…"
    git clone https://github.com/mistrfinga/stable-diffusion-webui.git "$REPO_DIR"
else
    info "Repo already present. Pulling latest on branch: $(git -C "$REPO_DIR" branch --show-current)"
    git -C "$REPO_DIR" pull --ff-only
fi

# ── 3. Virtual environment ────────────────────────────────────────────────────
info "Setting up Python venv at $VENV_DIR…"
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

info "Upgrading pip inside venv…"
pip install --upgrade pip -q

info "Installing controller-mode requirements (requests + psutil only — no torch/GPU)…"
pip install requests psutil -q

success "Virtual environment ready."

# ── 4. jarvis_mobile symlink ──────────────────────────────────────────────────
if [ ! -L "$JARVIS_DIR" ] && [ ! -d "$JARVIS_DIR" ]; then
    ln -s "$REPO_DIR/jarvis_mobile" "$JARVIS_DIR"
    success "Symlink created: $JARVIS_DIR → $REPO_DIR/jarvis_mobile"
fi

# ── 5. .env.jarvis file (user edits HiVEMiND IP here) ────────────────────────
ENV_FILE="$REPO_DIR/jarvis_mobile/.env.jarvis"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<'ENV'
# JARVIS II Mobile Thin Client — Environment Variables
# Edit HIVEMIND_IP to your actual HiVEMiND Tailscale IP (100.x.x.x)
export JARVIS_MODE=CONTROLLER
export HIVEMIND_IP=100.x.x.x
export JARVIS_LOCAL_PORT=8765
export JARVIS_LOG_LEVEL=INFO
ENV
    warn "Created $ENV_FILE — SET YOUR HIVEMIND_IP BEFORE STARTING."
else
    success ".env.jarvis already exists."
fi

# ── 6. Inject alias into shell rc ────────────────────────────────────────────
ALIAS_LINE="alias jarvis='bash $REPO_DIR/jarvis_mobile/start_brain.sh'"
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ] && ! grep -q "alias jarvis=" "$RC"; then
        echo "" >> "$RC"
        echo "# JARVIS II Thin Client" >> "$RC"
        echo "$ALIAS_LINE" >> "$RC"
        success "Alias 'jarvis' added to $RC"
    fi
done

success "Setup complete. Next steps:"
echo "  1. Edit $ENV_FILE — set HIVEMIND_IP=100.<your.tailscale.ip>"
echo "  2. Run:  bash $REPO_DIR/jarvis_mobile/start_brain.sh"
echo "  3. Or just type: jarvis  (after restarting shell)"

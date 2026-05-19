#!/usr/bin/env bash
# =============================================================================
# HIVEMIND — Claude Code Skills Sync (WSL / Linux / bash)
# Runs on SessionStart for Claude Code in WSL.
# Pulls the shared skills repo and copies any new/updated skills into
# the local Claude Code skills folder.
# =============================================================================

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
# Shared Drive (Google Drive) — WSL path
DRIVE_AI="/mnt/d/My Drive/AI"
CONFIG_FILE="$DRIVE_AI/claude-skills-sync/skills-config.json"
CACHE_DIR="$DRIVE_AI/claude-skills-sync/.repo-cache"

# Local Claude Code skills folder (WSL / Linux)
CLAUDE_SKILLS="$HOME/.claude/skills"

# ── Check config ──────────────────────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[skills-sync] Config not found at $CONFIG_FILE — skipping."
    exit 0
fi

REPO_URL=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('skills_repo_url',''))" "$CONFIG_FILE")
BRANCH=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('branch','main'))" "$CONFIG_FILE")
SUBDIR=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('skills_subdir',''))" "$CONFIG_FILE")

if [[ -z "$REPO_URL" || "$REPO_URL" == "PASTE_GITHUB_REPO_URL_HERE" ]]; then
    echo "[skills-sync] Repo URL not set in skills-config.json — skipping."
    exit 0
fi

# ── Ensure Claude skills dir exists ──────────────────────────────────────────
mkdir -p "$CLAUDE_SKILLS"

# ── Clone or pull the skills repo into the shared Drive cache ────────────────
if [[ ! -d "$CACHE_DIR/.git" ]]; then
    echo "[skills-sync] Cloning skills repo..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$CACHE_DIR" 2>/dev/null
else
    echo "[skills-sync] Pulling latest skills..."
    git -C "$CACHE_DIR" fetch --depth 1 origin "$BRANCH" 2>/dev/null
    git -C "$CACHE_DIR" reset --hard "origin/$BRANCH" 2>/dev/null
fi

# ── Determine source of skills inside the repo ───────────────────────────────
SKILLS_SRC="$CACHE_DIR"
if [[ -n "$SUBDIR" ]]; then
    SKILLS_SRC="$CACHE_DIR/$SUBDIR"
fi

# ── Copy each skill folder into the local Claude skills dir ──────────────────
copied=0
for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    # Skip hidden dirs
    [[ "$skill_name" == .* ]] && continue
    [[ ! -d "$skill_dir" ]] && continue

    rsync -a --delete "$skill_dir" "$CLAUDE_SKILLS/$skill_name/"
    ((copied++))
done

echo "[skills-sync] Done — $copied skill(s) synced to $CLAUDE_SKILLS"

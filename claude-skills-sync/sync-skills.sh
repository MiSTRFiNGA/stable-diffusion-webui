#!/usr/bin/env bash
# =============================================================================
# HIVEMIND — Claude Code Skills Sync (WSL / bash)
# Pulls all skills repos defined in skills-config.json and installs
# every skill into ~/.claude/skills/ on session start.
# =============================================================================

set -euo pipefail

DRIVE_AI="/mnt/d/My Drive/AI"
DRIVE_CONFIG="$DRIVE_AI/claude-skills-sync/skills-config.json"
# Repo-local fallback: same directory as this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONFIG="$SCRIPT_DIR/skills-config.json"

if [[ -f "$DRIVE_CONFIG" ]]; then
    CONFIG_FILE="$DRIVE_CONFIG"
    CACHE_ROOT="$DRIVE_AI/claude-skills-sync/.repo-cache"
elif [[ -f "$LOCAL_CONFIG" ]]; then
    CONFIG_FILE="$LOCAL_CONFIG"
    CACHE_ROOT="$SCRIPT_DIR/.repo-cache"
else
    echo "[skills-sync] Config not found — skipping."
    exit 0
fi

CLAUDE_SKILLS="$HOME/.claude/skills"

mkdir -p "$CLAUDE_SKILLS" "$CACHE_ROOT"

BRANCH=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('branch','main'))" "$CONFIG_FILE")
REPO_COUNT=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get('repos',[])))" "$CONFIG_FILE")

if [[ "$REPO_COUNT" -eq 0 ]]; then
    echo "[skills-sync] No repos configured — skipping."
    exit 0
fi

total_skills=0

for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_URL=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['repos'][int(sys.argv[2])]['url'])" "$CONFIG_FILE" "$i")
    SUBDIR=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['repos'][int(sys.argv[2])].get('subdir',''))" "$CONFIG_FILE" "$i")

    # Derive a safe cache folder name from the repo URL
    REPO_SLUG=$(echo "$REPO_URL" | sed 's|https://github.com/||; s|/|-|g')
    CACHE_DIR="$CACHE_ROOT/$REPO_SLUG"

    # Try main branch first, fall back to master
    for branch_try in "$BRANCH" master; do
        if [[ ! -d "$CACHE_DIR/.git" ]]; then
            git clone --branch "$branch_try" --depth 1 "$REPO_URL" "$CACHE_DIR" 2>/dev/null && break
        else
            git -C "$CACHE_DIR" fetch --depth 1 origin "$branch_try" 2>/dev/null && \
            git -C "$CACHE_DIR" reset --hard "origin/$branch_try" 2>/dev/null && break
        fi
    done

    if [[ ! -d "$CACHE_DIR" ]]; then
        echo "[skills-sync] WARN: failed to clone $REPO_URL — skipping."
        continue
    fi

    SKILLS_SRC="$CACHE_DIR"
    [[ -n "$SUBDIR" ]] && SKILLS_SRC="$CACHE_DIR/$SUBDIR"

    # If the repo root itself is a single skill (has SKILL.md at root), install it as one skill
    if [[ -f "$SKILLS_SRC/SKILL.md" ]]; then
        skill_name=$(basename "$REPO_SLUG")
        rsync -a --delete "$SKILLS_SRC/" "$CLAUDE_SKILLS/$skill_name/"
        total_skills=$((total_skills + 1))
        continue
    fi

    # Otherwise each subdirectory containing a SKILL.md is a separate skill
    for skill_dir in "$SKILLS_SRC"/*/; do
        skill_name=$(basename "$skill_dir")
        [[ "$skill_name" == .* ]] && continue
        [[ ! -d "$skill_dir" ]] && continue
        # Only install if it looks like a skill (has SKILL.md)
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            rsync -a --delete "$skill_dir" "$CLAUDE_SKILLS/$skill_name/"
            total_skills=$((total_skills + 1))
        fi
    done
done

echo "[skills-sync] Done — $total_skills skill(s) synced to $CLAUDE_SKILLS"

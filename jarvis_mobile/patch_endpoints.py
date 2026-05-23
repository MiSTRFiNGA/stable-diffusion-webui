"""
JARVIS II — Endpoint Patcher
Scans the codebase for hardcoded localhost/127.0.0.1 API references and
replaces them with the HiVEMiND Tailscale IP for CONTROLLER mode.

Usage:
    python3 patch_endpoints.py --ip 100.x.x.x [--dry-run] [--revert]
"""

import argparse
import os
import re
import sys
from pathlib import Path

LOCALHOST_PATTERNS = [
    r"http://localhost",
    r"http://127\.0\.0\.1",
]

# Ports that belong to services running on HiVEMiND
REMOTE_PORTS = {7860, 8188, 8000, 11434, 5002, 9000}

EXCLUDE_DIRS  = {".git", "venv", "__pycache__", "node_modules", ".mypy_cache"}
INCLUDE_EXTS  = {".py", ".sh", ".json", ".yaml", ".yml", ".env", ".cfg", ".ini", ".toml"}


def should_skip(path: Path) -> bool:
    return any(part in EXCLUDE_DIRS for part in path.parts)


def patch_file(filepath: Path, hivemind_ip: str, dry_run: bool, revert: bool) -> list[str]:
    try:
        original = filepath.read_text(encoding="utf-8", errors="replace")
    except (PermissionError, IsADirectoryError):
        return []

    changed_lines = []
    lines = original.splitlines(keepends=True)
    new_lines = list(lines)

    for i, line in enumerate(lines):
        new_line = line
        for pattern in LOCALHOST_PATTERNS:
            match = re.search(pattern + r":(\d+)", line)
            if match:
                port = int(match.group(1))
                if port in REMOTE_PORTS:
                    if revert:
                        new_line = re.sub(
                            re.escape(f"http://{hivemind_ip}:{port}"),
                            f"http://localhost:{port}",
                            new_line,
                        )
                    else:
                        new_line = re.sub(
                            pattern + rf":{port}",
                            f"http://{hivemind_ip}:{port}",
                            new_line,
                        )
        if new_line != line:
            changed_lines.append(f"  line {i+1}: {line.rstrip()!r}\n    =>  {new_line.rstrip()!r}")
            new_lines[i] = new_line

    if changed_lines and not dry_run:
        filepath.write_text("".join(new_lines), encoding="utf-8")

    return changed_lines


def run(repo_root: Path, hivemind_ip: str, dry_run: bool, revert: bool):
    mode = "REVERTING" if revert else "PATCHING"
    target = "localhost" if revert else hivemind_ip
    print(f"[patcher] {mode}: localhost → {target}  (dry_run={dry_run})")
    print(f"[patcher] Scanning: {repo_root}\n")

    total_files = 0
    total_changes = 0

    for fpath in sorted(repo_root.rglob("*")):
        if fpath.is_dir() or should_skip(fpath) or fpath.suffix not in INCLUDE_EXTS:
            continue
        changes = patch_file(fpath, hivemind_ip, dry_run, revert)
        if changes:
            total_files += 1
            total_changes += len(changes)
            rel = fpath.relative_to(repo_root)
            print(f"  {rel}  ({len(changes)} change{'s' if len(changes)!=1 else ''})")
            for c in changes:
                print(c)
            print()

    label = "Would change" if dry_run else "Changed"
    print(f"[patcher] Done. {label} {total_changes} line(s) in {total_files} file(s).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Patch localhost API endpoints to HiVEMiND Tailscale IP.")
    parser.add_argument("--ip",      required=True, help="HiVEMiND Tailscale IP (e.g. 100.64.0.1)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without writing files")
    parser.add_argument("--revert",  action="store_true", help="Undo: replace HiVEMiND IP back with localhost")
    parser.add_argument("--root",    default=None, help="Repo root (default: parent of this script)")
    args = parser.parse_args()

    root = Path(args.root) if args.root else Path(__file__).resolve().parent.parent
    if not root.is_dir():
        sys.exit(f"[patcher] ERROR: repo root not found: {root}")

    run(root, args.ip, args.dry_run, args.revert)

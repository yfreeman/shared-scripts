#!/bin/bash
# Setup .claude and .codex symlinks from shared-scripts.
#
# Usage:
#   setup-claude-links.sh [target-dir]
#
# target-dir defaults to the current working directory. Pass "$HOME" to
# install user-level symlinks (~/.claude, ~/.codex), which Claude Code and
# Codex pick up across all projects — no per-project setup needed.
#
# The target must already contain .claude and/or .codex (Claude/Codex create
# these on first run). Derives the shared-scripts path from this script's
# own location.

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SHARED_SCRIPTS_PATH=$(dirname "$SCRIPT_DIR")

TARGET_DIR="${1:-.}"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

if [ ! -d "$TARGET_DIR/.claude" ] && [ ! -d "$TARGET_DIR/.codex" ]; then
    echo "Error: no .claude or .codex directory found in $TARGET_DIR"
    exit 1
fi

echo "=== Setting up .claude/.codex symlinks ==="
echo "  shared-scripts: $SHARED_SCRIPTS_PATH"
echo "  target:         $TARGET_DIR"

link_items() {
    local base_dir="$1"
    local category="$2"
    local src_dir="$SHARED_SCRIPTS_PATH/$category"
    local dst_dir="$TARGET_DIR/$base_dir/$category"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dst_dir"

    for item in "$src_dir"/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping $base_dir/$category/$name (exists as regular file)"
            continue
        fi

        ln -sf "$item" "$dst"
        echo "  linked: $base_dir/$category/$name"
    done
}

if [ -d "$TARGET_DIR/.claude" ]; then
    link_items ".claude" "agents"
    link_items ".claude" "commands"
    link_items ".claude" "skills"
fi

if [ -d "$TARGET_DIR/.codex" ]; then
    link_items ".codex" "agents"
    link_items ".codex" "commands"
    link_items ".codex" "skills"
fi

echo "✓ .claude/.codex symlinks set up"

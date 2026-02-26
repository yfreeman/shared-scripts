#!/bin/bash
# Setup .claude and .codex symlinks from shared-scripts.
# Run from the root of a project that has .claude and/or .codex directories.
# Derives the shared-scripts path from this script's own location.

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SHARED_SCRIPTS_PATH=$(dirname "$SCRIPT_DIR")

if [ ! -d ".claude" ] && [ ! -d ".codex" ]; then
    echo "Error: no .claude or .codex directory found in $(pwd)"
    exit 1
fi

echo "=== Setting up .claude/.codex symlinks ==="
echo "  shared-scripts: $SHARED_SCRIPTS_PATH"
echo "  project:        $(pwd)"

link_items() {
    local base_dir="$1"
    local category="$2"
    local src_dir="$SHARED_SCRIPTS_PATH/$category"
    local dst_dir="$base_dir/$category"

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

if [ -d ".claude" ]; then
    link_items ".claude" "agents"
    link_items ".claude" "commands"
    link_items ".claude" "skills"
fi

if [ -d ".codex" ]; then
    link_items ".codex" "agents"
    link_items ".codex" "commands"
    link_items ".codex" "skills"
fi

echo "✓ .claude/.codex symlinks set up"

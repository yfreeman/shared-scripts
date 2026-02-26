#!/bin/bash
# Setup .claude symlinks from shared-scripts.
# Run from the root of a project that has a .claude directory.
# Derives the shared-scripts path from this script's own location.

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SHARED_SCRIPTS_PATH=$(dirname "$SCRIPT_DIR")

if [ ! -d ".claude" ]; then
    echo "Error: no .claude directory found in $(pwd)"
    exit 1
fi

echo "=== Setting up .claude symlinks ==="
echo "  shared-scripts: $SHARED_SCRIPTS_PATH"
echo "  project:        $(pwd)"

link_items() {
    local category="$1"
    local src_dir="$SHARED_SCRIPTS_PATH/$category"
    local dst_dir=".claude/$category"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dst_dir"

    for item in "$src_dir"/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping $category/$name (exists as regular file)"
            continue
        fi

        ln -sf "$item" "$dst"
        echo "  linked: $category/$name"
    done
}

link_items "agents"
link_items "commands"
link_items "skills"

echo "✓ .claude symlinks set up"

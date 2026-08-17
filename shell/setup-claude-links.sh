#!/bin/bash
# Setup .claude, .agents, .codex, and .opencode symlinks from shared-scripts.
#
# Usage:
#   setup-claude-links.sh [target-dir]
#
# target-dir defaults to the current working directory. Pass "$HOME" to
# install user-level symlinks (~/.claude, ~/.agents, ~/.codex, ~/.opencode),
# which Claude Code, Codex, and opencode pick up across all projects — no
# per-project setup needed.
#
# The target must already contain .claude, .agents, .codex, and/or .opencode
# (Claude creates .claude on first run; .agents is Codex's skill discovery
# dir — see https://learn.chatgpt.com/docs/build-skills; .codex/agents is
# Codex's subagent discovery dir — see
# https://learn.chatgpt.com/docs/agent-configuration/subagents;
# .opencode/agents is opencode's agent discovery dir — see
# https://opencode.ai/docs/agents/). Derives the shared-scripts path from
# this script's own location.

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SHARED_SCRIPTS_PATH=$(dirname "$SCRIPT_DIR")

TARGET_DIR="${1:-.}"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

if [ ! -d "$TARGET_DIR/.claude" ] && [ ! -d "$TARGET_DIR/.agents" ] && [ ! -d "$TARGET_DIR/.codex" ] && [ ! -d "$TARGET_DIR/.opencode" ]; then
    echo "Error: no .claude, .agents, .codex, or .opencode directory found in $TARGET_DIR"
    exit 1
fi

echo "=== Setting up .claude/.agents/.codex/.opencode symlinks ==="
echo "  shared-scripts: $SHARED_SCRIPTS_PATH"
echo "  target:         $TARGET_DIR"

link_items() {
    local base_dir="$1"
    local category="$2"
    local include_filter="$3" # optional: only link items matching this glob (e.g. "*.toml")
    local exclude_filter="$4" # optional: space-separated globs to skip (e.g. "*.toml *.opencode.md")
    local src_dir="$SHARED_SCRIPTS_PATH/$category"
    local dst_dir="$TARGET_DIR/$base_dir/$category"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dst_dir"

    for item in "$src_dir"/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")

        if [ -n "$include_filter" ]; then
            case "$name" in
                $include_filter) ;;
                *) continue ;;
            esac
        fi

        if [ -n "$exclude_filter" ]; then
            skip=0
            for pat in $exclude_filter; do
                case "$name" in
                    $pat) skip=1; break ;;
                esac
            done
            [ "$skip" = "1" ] && continue
        fi

        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping $base_dir/$category/$name (exists as regular file)"
            continue
        fi

        ln -sfn "$item" "$dst"
        echo "  linked: $base_dir/$category/$name"
    done
}

if [ -d "$TARGET_DIR/.claude" ]; then
    # Claude Code reads .md agent files only; the Codex .toml and opencode
    # .opencode.md siblings would just be clutter (and .opencode.md isn't
    # valid Claude frontmatter for this filename).
    link_items ".claude" "agents" "" "*.toml *.opencode.md"
    link_items ".claude" "commands"
    link_items ".claude" "skills"
fi

if [ -d "$TARGET_DIR/.agents" ]; then
    link_items ".agents" "skills"
fi

if [ -d "$TARGET_DIR/.codex" ]; then
    # Codex only loads .toml files from its agents dir; .md/.js siblings
    # (Claude's agent format and its support files) would just be clutter.
    link_items ".codex" "agents" "*.toml"
fi

link_opencode_agents() {
    # opencode's `tools:` schema (object) and `permission:` field are
    # incompatible with Claude's `tools:` array, so opencode agents are
    # dedicated agents/*.opencode.md files rather than shared with Claude's
    # agents/*.md — link them in as their plain name (opencode uses the
    # filename as the agent identifier). Support files (e.g. the Testing
    # Library injection script) are shared as-is.
    local src_dir="$SHARED_SCRIPTS_PATH/agents"
    local dst_dir="$TARGET_DIR/.opencode/agents"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dst_dir"

    for item in "$src_dir"/*.opencode.md; do
        [ -e "$item" ] || continue
        name=$(basename "$item" .opencode.md).md
        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping .opencode/agents/$name (exists as regular file)"
            continue
        fi

        ln -sfn "$item" "$dst"
        echo "  linked: .opencode/agents/$name"
    done

    for item in "$src_dir"/*.js; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping .opencode/agents/$name (exists as regular file)"
            continue
        fi

        ln -sfn "$item" "$dst"
        echo "  linked: .opencode/agents/$name"
    done
}

mkdir -p "$TARGET_DIR/.opencode"
link_opencode_agents

echo "✓ .claude/.agents/.codex/.opencode symlinks set up"

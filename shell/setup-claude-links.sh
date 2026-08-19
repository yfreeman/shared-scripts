#!/bin/bash
# Setup .claude, .agents, .codex, .opencode, and .pi symlinks from
# shared-scripts.
#
# Usage:
#   setup-claude-links.sh [target-dir]
#
# target-dir defaults to the current working directory. Pass "$HOME" to
# install user-level symlinks (~/.claude, ~/.agents, ~/.codex, ~/.opencode,
# ~/.pi), which Claude Code, Codex, opencode, and pi pick up across all
# projects — no per-project setup needed.
#
# The target must already contain .claude, .agents, .codex, .opencode,
# and/or .pi (Claude creates .claude on first run; .agents is Codex's skill
# discovery dir — see https://learn.chatgpt.com/docs/build-skills;
# .codex/agents is Codex's subagent discovery dir — see
# https://learn.chatgpt.com/docs/agent-configuration/subagents;
# .opencode/agents is opencode's agent discovery dir — see
# https://opencode.ai/docs/agents/; .pi/skills is pi's skill discovery dir;
# .pi/agent/extensions is pi's global extension discovery dir; .pi/agent/agents
# is the subagent extension's agent discovery dir).
# Derives the shared-scripts path from this script's own location.

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SHARED_SCRIPTS_PATH=$(dirname "$SCRIPT_DIR")

TARGET_DIR="${1:-.}"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

if [ ! -d "$TARGET_DIR/.claude" ] && [ ! -d "$TARGET_DIR/.agents" ] && [ ! -d "$TARGET_DIR/.codex" ] && [ ! -d "$TARGET_DIR/.opencode" ] && [ ! -d "$TARGET_DIR/.pi" ]; then
    echo "Error: no .claude, .agents, .codex, .opencode, or .pi directory found in $TARGET_DIR"
    exit 1
fi

echo "=== Setting up .claude/.agents/.codex/.opencode/.pi symlinks ==="
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
    # Claude Code reads .md agent files only; the Codex .toml, opencode
    # .opencode.md, and pi .pi.md siblings would just be clutter (and
    # .opencode.md/.pi.md aren't valid Claude frontmatter for these filenames,
    # so they'd conflict with the plain .md agent of the same base name).
    link_items ".claude" "agents" "" "*.toml *.opencode.md *.pi.md"
    link_items ".claude" "commands"
    link_items ".claude" "skills"
fi

if [ -d "$TARGET_DIR/.agents" ]; then
    link_items ".agents" "skills"
fi

mkdir -p "$TARGET_DIR/.pi"
link_items ".pi" "skills"

link_pi_extensions() {
    # pi loads extensions from agentDir/extensions (global: ~/.pi/agent/extensions)
    # where each extension is a subdirectory containing index.ts (or package.json
    # with a "pi" manifest). Discovery follows directory symlinks, so each shared
    # pi-extensions/<name> directory is linked wholesale.
    # NOTE: project-local pi extensions live at cwd/.pi/extensions and are
    # trust-gated; this links the user-level (global) location only.
    local src_dir="$SHARED_SCRIPTS_PATH/pi-extensions"
    local dst_dir="$TARGET_DIR/.pi/agent/extensions"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dst_dir"

    for item in "$src_dir"/*/; do
        [ -d "$item" ] || continue
        name=$(basename "$item")
        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping pi-extensions/$name (exists as regular file/dir)"
            continue
        fi

        ln -sfn "$item" "$dst"
        echo "  linked: .pi/agent/extensions/$name"
    done
}

link_pi_extensions

link_pi_agents() {
    # pi subagent definitions (subagent extension) are Claude-style frontmatter
    # .md files, but with pi-compatible tools lists — dedicated agents/*.pi.md
    # variants (like *.opencode.md for opencode), linked in as plain .md (pi
    # dispatches by frontmatter `name`; the filename is irrelevant).
    local src_dir="$SHARED_SCRIPTS_PATH/agents"
    local dst_dir="$TARGET_DIR/.pi/agent/agents"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dst_dir"

    for item in "$src_dir"/*.pi.md; do
        [ -e "$item" ] || continue
        name=$(basename "$item" .pi.md).md
        dst="$dst_dir/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  skipping .pi/agent/agents/$name (exists as regular file)"
            continue
        fi

        ln -sfn "$item" "$dst"
        echo "  linked: .pi/agent/agents/$name"
    done
}

link_pi_agents

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

echo "✓ .claude/.agents/.codex/.opencode/.pi symlinks set up (skills, extensions, agents)"

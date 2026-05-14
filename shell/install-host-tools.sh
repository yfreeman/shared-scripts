#!/bin/bash
# Install host-side tooling needed by shared-scripts agents/commands.
# Mirrors the per-user tools section of install-container-tools.sh, but runs
# on the host (macOS/Linux outside any devcontainer). Idempotent — skips
# anything already installed.
set -e

echo "=== Installing host development tools ==="

if ! command -v npm >/dev/null 2>&1; then
    echo "Error: npm not found. Install Node.js first (nvm or brew)."
    exit 1
fi

install_npm_global() {
    local cmd="$1"
    local pkg="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ $cmd already installed ($(command -v "$cmd"))"
    else
        echo "Installing $pkg..."
        npm install -g "$pkg"
        echo "✓ $cmd installed"
    fi
}

# Claude Code
if command -v claude >/dev/null 2>&1; then
    echo "✓ claude already installed ($(command -v claude))"
else
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    echo "✓ Claude Code installed"
fi

install_npm_global osgrep         osgrep
install_npm_global codex          @openai/codex
install_npm_global playwright-cli @playwright/cli

echo ""
echo "=== Verifying installations ==="
claude --version 2>/dev/null         | head -n 1 || echo "claude: not in PATH"
osgrep --version 2>/dev/null         | head -n 1 || echo "osgrep: not in PATH"
codex --version 2>/dev/null          | head -n 1 || echo "codex: not in PATH"
playwright-cli --version 2>/dev/null | head -n 1 || echo "playwright-cli: not in PATH"

echo ""
echo "=== Wiring user-level .claude/.codex symlinks ==="
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
mkdir -p "$HOME/.claude"
"$SCRIPT_DIR/setup-claude-links.sh" "$HOME"

echo ""
echo "=== Done ==="

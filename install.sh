#!/usr/bin/env sh
SHARED_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_RC="$SHARED_DIR/.rc"
SOURCE_LINE="source \"$SHARED_RC\""

# Detect rc file based on current shell
case "$(basename "$SHELL")" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) RC="$HOME/.bashrc" ;;
  *)    RC="$HOME/.profile" ;;
esac

# Install uv if not present
if ! command -v uv >/dev/null 2>&1 && [ ! -f "$HOME/.local/bin/uv" ]; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo "uv installed."
else
  echo "uv already installed."
fi

# uv lands tools in ~/.local/bin — make sure we can call it now
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac

# Install term-agent CLI from GitHub (pipx-equivalent via uv)
if ! command -v term-agent >/dev/null 2>&1; then
  echo "Installing term-agent..."
  uv tool install git+https://github.com/yfreeman/term-agent.git
  echo "term-agent installed."
else
  echo "term-agent already installed."
fi

# Populate submodules (python/term-agent, rust/sgrep — term-agent provides
# the skill files that skills/terminal-session symlinks into; rust/sgrep is
# the source of the sgrep binaries)
if [ -f "$SHARED_DIR/.gitmodules" ]; then
  git -C "$SHARED_DIR" submodule update --init --recursive
fi

# sgrep: build the binaries if a Rust toolchain is present (skipped
# otherwise — the per-platform binaries in bin/ are gitignored, so a box
# without cargo just doesn't get sgrep until it has a toolchain).
if command -v cargo >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/cargo" ]; then
  echo "Building sgrep..."
  SH="$(command -v cargo >/dev/null 2>&1 && echo cargo || echo "$HOME/.cargo/bin/cargo")"
  PATH="$(dirname "$SH"):$PATH" "$SHARED_DIR/shell/build-sgrep.sh"
else
  echo "cargo not found — skipping sgrep build (run shell/build-sgrep.sh after installing Rust)."
fi

# sgrep semantic model (~396 MB, gitignored under models/). Skipped with
# SGREP_SKIP_MODEL=1, e.g. on machines that won't use --semantic.
if [ "${SGREP_SKIP_MODEL:-0}" != 1 ] && [ -x "$SHARED_DIR/bin/sgrep" ]; then
  "$SHARED_DIR/shell/get-sgrep-model.sh"
fi

# Add shared-scripts .rc to shell rc file
if grep -qF "$SOURCE_LINE" "$RC" 2>/dev/null; then
  echo "Already installed in $RC"
else
  echo "" >> "$RC"
  echo "# shared-scripts" >> "$RC"
  echo "$SOURCE_LINE" >> "$RC"
  echo "Installed: added to $RC"
fi

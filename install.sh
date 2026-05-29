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

# Populate submodules (python/term-agent — provides the skill files that
# skills/terminal-session symlinks into)
if [ -f "$SHARED_DIR/.gitmodules" ]; then
  git -C "$SHARED_DIR" submodule update --init --recursive
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

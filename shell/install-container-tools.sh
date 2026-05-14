#!/bin/bash
set -e

TARGET_USER="${1:-node}"
if [ "$TARGET_USER" = "root" ]; then
    TARGET_HOME="/root"
else
    TARGET_HOME="/home/$TARGET_USER"
fi

echo "=== Installing development tools (user: $TARGET_USER) ==="

# Install neovim (latest from GitHub releases)
echo "Installing neovim..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    NVIM_ASSET="nvim-linux-x86_64.tar.gz"
    NVIM_DIR="nvim-linux-x86_64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NVIM_ASSET="nvim-linux-arm64.tar.gz"
    NVIM_DIR="nvim-linux-arm64"
else
    echo "Warning: Unsupported architecture $ARCH for neovim, falling back to apt..."
    sudo apt-get update && sudo apt-get install -y neovim
    NVIM_ASSET=""
fi

if [ -n "$NVIM_ASSET" ]; then
    curl -L "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}" | sudo tar -xz -C /usr/local
    sudo ln -sf "/usr/local/${NVIM_DIR}/bin/nvim" /usr/local/bin/nvim
fi
echo "✓ neovim installed"

# Install zellij - detect architecture
echo "Installing zellij..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ZELLIJ_ARCH="x86_64-unknown-linux-musl"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ZELLIJ_ARCH="aarch64-unknown-linux-musl"
else
    echo "Warning: Unsupported architecture $ARCH for zellij, skipping..."
    exit 0
fi

curl -L "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZELLIJ_ARCH}.tar.gz" | sudo tar -xz -C /usr/local/bin
sudo chmod +x /usr/local/bin/zellij
echo "✓ zellij installed"

# Install FiraCode Nerd Font
echo "Installing FiraCode Nerd Font..."
sudo mkdir -p /usr/share/fonts/truetype/firacode-nerd-font
if [ -d "$TARGET_HOME/.local/share/fonts/FiraCode" ]; then
    sudo cp "$TARGET_HOME/.local/share/fonts/FiraCode/"*.ttf /usr/share/fonts/truetype/firacode-nerd-font/
    sudo fc-cache -f -v
    echo "✓ FiraCode Nerd Font installed"
else
    echo "Warning: FiraCode fonts not found in mounted directory, skipping..."
fi

# Verify installations
echo ""
echo "=== Verifying installations ==="
nvim --version | head -n 1
zellij --version

echo ""
echo "=== All tools installed successfully ==="

# Prepare directories for target user
echo ""
echo "=== Preparing directories for $TARGET_USER ==="
if [ "$TARGET_USER" != "root" ]; then
    sudo mkdir -p "$TARGET_HOME/.npm" "$TARGET_HOME/.cache" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.claude/tmp"
    sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.npm" "$TARGET_HOME/.cache" "$TARGET_HOME/.local" "$TARGET_HOME/.claude"
    sudo chmod -R 755 "$TARGET_HOME/.npm" "$TARGET_HOME/.cache" "$TARGET_HOME/.local" "$TARGET_HOME/.claude"
fi
echo "✓ Directories prepared"

# Install user tools as target user
echo ""
echo "=== Installing user tools (as $TARGET_USER) ==="

run_as_user() {
    if [ "$TARGET_USER" = "root" ]; then
        bash -c "$1"
    else
        sudo su - "$TARGET_USER" -c "$1"
    fi
}

# Install Claude Code
echo "Installing Claude Code..."
run_as_user 'curl -fsSL https://claude.ai/install.sh | bash'
echo "✓ Claude Code installed"

# Install osgrep
echo "Installing osgrep..."
run_as_user 'npm install -g osgrep'
echo "✓ osgrep installed"

# Install Codex
echo "Installing Codex..."
run_as_user 'npm i -g @openai/codex'
echo "✓ Codex installed"

# Install Claude Code plugins
#echo "Installing Claude Code plugins..."
#run_as_user "osgrep install-claude-code"
#echo "✓ Claude Code plugins installed"



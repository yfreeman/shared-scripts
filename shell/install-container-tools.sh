#!/bin/bash
set -e

echo "=== Installing development tools ==="

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
# Fonts are mounted to /home/node/.local/share/fonts (onCreateCommand runs as node user)
if [ -d "/home/node/.local/share/fonts/FiraCode" ]; then
    sudo cp /home/node/.local/share/fonts/FiraCode/*.ttf /usr/share/fonts/truetype/firacode-nerd-font/
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

# Prepare directories for node user
echo ""
echo "=== Preparing directories for node user ==="
sudo mkdir -p /home/node/.npm /home/node/.cache /home/node/.local/bin /home/node/.claude/tmp
sudo chown -R node:node /home/node/.npm /home/node/.cache /home/node/.local /home/node/.claude
sudo chmod -R 755 /home/node/.npm /home/node/.cache /home/node/.local /home/node/.claude
echo "✓ Directories prepared"

# Install user tools as node user
echo ""
echo "=== Installing user tools (as node) ==="

# Install Claude Code as node user
echo "Installing Claude Code..."
sudo su - node -c 'curl -fsSL https://claude.ai/install.sh | bash'
echo "✓ Claude Code installed"

# Install Claude Code plugins as node user
echo "Installing Claude Code plugins..."
sudo su - node -c 'TMPDIR=/home/node/.claude/tmp claude plugin install osgrep'
echo "✓ Claude Code plugins installed"

# Install osgrep as node user
echo "Installing osgrep..."
sudo su - node -c 'npm install -g osgrep'
echo "✓ osgrep installed"

# Run shared-scripts installer
echo ""
echo "=== Running shared-scripts/install.sh ==="
if [ -f "/usr/local/shared-scripts/install.sh" ]; then
    bash /usr/local/shared-scripts/install.sh
    echo "✓ shared-scripts installed"
else
    echo "Warning: /usr/local/shared-scripts/install.sh not found, skipping..."
fi

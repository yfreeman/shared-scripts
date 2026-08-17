#!/bin/bash
# Update .mcp.json with current Docker host IP address
# Can be run multiple times to refresh the IP address

set -e

MCP_FILE="$(pwd)/.mcp.json"

echo "🔍 Detecting Docker host IP address..."

# Get the IPv4 address for host.docker.internal
HOST_IP=$(getent ahostsv4 host.docker.internal 2>/dev/null | awk 'NR==1 {print $1}')

# Fallback: Try other methods if getent doesn't work
if [ -z "$HOST_IP" ]; then
    echo "⚠️  getent method failed, trying alternative methods..."

    # Method 2: Parse from getent hosts
    HOST_IP=$(getent hosts host.docker.internal 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
fi

# Fallback: Try gateway IP
if [ -z "$HOST_IP" ]; then
    echo "⚠️  host.docker.internal not resolved, trying gateway IP..."
    HOST_IP=$(ip route show default | awk '{print $3}')
fi

# Validate IP address
if [ -z "$HOST_IP" ]; then
    echo "❌ Error: Could not determine host IP address"
    echo "Please check:"
    echo "  1. You're running inside a Docker container"
    echo "  2. host.docker.internal is accessible"
    echo "  3. Network connectivity is working"
    exit 1
fi

# Validate IP format
if ! echo "$HOST_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "❌ Error: Invalid IP address format: $HOST_IP"
    exit 1
fi

echo "✓ Detected host IP address: $HOST_IP"

# Test if Chrome is accessible at this IP
echo "🔌 Testing Chrome connection at $HOST_IP:9222..."
if timeout 2 curl -s "http://$HOST_IP:9222/json/version" > /dev/null 2>&1; then
    echo "✓ Chrome is accessible at $HOST_IP:9222"
    CHROME_ACCESSIBLE=true
else
    echo "⚠️  Warning: Could not connect to Chrome at $HOST_IP:9222"
    echo "   Make sure Chrome is running with:"
    echo "   --remote-debugging-port=9222 --remote-allow-origins=*"
    CHROME_ACCESSIBLE=false
fi

# Check if .mcp.json exists
if [ ! -f "$MCP_FILE" ]; then
    echo "❌ Error: $MCP_FILE does not exist"
    echo "Creating new file..."

    cat > "$MCP_FILE" <<EOF
{
  "mcpServers": {
   "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl=http://$HOST_IP:9222"
      ]
    }
  }
}
EOF
    echo "✓ Created $MCP_FILE"
else
    # Get current IP from .mcp.json
    CURRENT_IP=$(grep -oP 'http://\K[0-9.]+' "$MCP_FILE" | head -1)

    if [ "$CURRENT_IP" = "$HOST_IP" ]; then
        echo "✓ IP address is already up to date ($HOST_IP)"

        if [ "$CHROME_ACCESSIBLE" = false ]; then
            echo ""
            echo "⚠️  Note: IP is correct but Chrome is not accessible"
            echo "   Start Chrome with remote debugging enabled"
        fi

        exit 0
    fi

    echo "📝 Updating IP address: $CURRENT_IP → $HOST_IP"

    # Update the IP address in the file
    # Use sed to replace the IP in the browserUrl
    sed -i "s|http://[0-9.]*:9222|http://$HOST_IP:9222|g" "$MCP_FILE"

    echo "✓ Updated $MCP_FILE"
fi

# Update PLAYWRIGHT_CDP_ENDPOINT in .env
ENV_FILE="$(pwd)/.env"
CDP_VALUE="http://$HOST_IP:9222"

if [ ! -f "$ENV_FILE" ]; then
    echo "PLAYWRIGHT_CDP_ENDPOINT=$CDP_VALUE" > "$ENV_FILE"
    echo "✓ Created $ENV_FILE with PLAYWRIGHT_CDP_ENDPOINT=$CDP_VALUE"
elif grep -q "^PLAYWRIGHT_CDP_ENDPOINT=" "$ENV_FILE"; then
    CURRENT_CDP=$(grep "^PLAYWRIGHT_CDP_ENDPOINT=" "$ENV_FILE" | cut -d= -f2-)
    if [ "$CURRENT_CDP" = "$CDP_VALUE" ]; then
        echo "✓ PLAYWRIGHT_CDP_ENDPOINT is already up to date"
    else
        sed -i "s|^PLAYWRIGHT_CDP_ENDPOINT=.*|PLAYWRIGHT_CDP_ENDPOINT=$CDP_VALUE|" "$ENV_FILE"
        echo "✓ Updated PLAYWRIGHT_CDP_ENDPOINT: $CURRENT_CDP → $CDP_VALUE"
    fi
else
    echo "PLAYWRIGHT_CDP_ENDPOINT=$CDP_VALUE" >> "$ENV_FILE"
    echo "✓ Added PLAYWRIGHT_CDP_ENDPOINT=$CDP_VALUE to $ENV_FILE"
fi

echo ""
echo "Current configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$MCP_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$CHROME_ACCESSIBLE" = true ]; then
    echo "✅ Done! Chrome DevTools MCP is ready to use."
    echo "   Restart Claude Code if it's already running."
else
    echo "⚠️  Done! But Chrome is not accessible yet."
    echo "   Start Chrome with: --remote-debugging-port=9222 --remote-allow-origins=*"
fi

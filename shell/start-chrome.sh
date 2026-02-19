#!/bin/bash

# Start Chrome with remote debugging for MCP
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --remote-debugging-address=0.0.0.0 \
  --user-data-dir="$(dirname "$0")/../.browser_profile" \
  --window-size=1080,1080 \
  --no-first-run \
  --no-default-browser-check \ 
  --remote-allow-origins=*

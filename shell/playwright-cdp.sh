#!/bin/bash
# Resolve PLAYWRIGHT_CDP_ENDPOINT for playwright-cli agents.
# Never launches a new browser — only resolves an endpoint for an
# already-running one and verifies it's reachable.
# Priority:
#   1. Already set in the environment
#   2. .env file found by walking up from $PWD
#   3. .env in the shared-scripts install dir ($(dirname $0)/..)
#   4. Last resort: http://127.0.0.1:9222, only if something answers there
# Prints the endpoint to stdout on success; exits 1 with a message on stderr
# if no reachable CDP endpoint can be found by any of the above.

set -euo pipefail

_find_env_value() {
  local file="$1"
  grep -s '^PLAYWRIGHT_CDP_ENDPOINT=' "$file" | head -1 | cut -d= -f2-
}

_is_reachable() {
  curl -s -o /dev/null -m 2 "$1/json/version"
}

# 1. Already in environment
if [[ -n "${PLAYWRIGHT_CDP_ENDPOINT:-}" ]]; then
  echo "$PLAYWRIGHT_CDP_ENDPOINT"
  exit 0
fi

# 2. Walk up from CWD
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  candidate="$dir/.env"
  if [[ -f "$candidate" ]]; then
    val="$(_find_env_value "$candidate")"
    if [[ -n "$val" ]]; then
      echo "$val"
      exit 0
    fi
  fi
  dir="$(dirname "$dir")"
done

# 3. .env next to this script's parent (shared-scripts root)
scripts_root="$(cd "$(dirname "$0")/.." && pwd)"
candidate="$scripts_root/.env"
if [[ -f "$candidate" ]]; then
  val="$(_find_env_value "$candidate")"
  if [[ -n "$val" ]]; then
    echo "$val"
    exit 0
  fi
fi

# 4. Last resort: default local CDP port, only if it actually answers
DEFAULT="http://127.0.0.1:9222"
if _is_reachable "$DEFAULT"; then
  echo "$DEFAULT"
  exit 0
fi

echo "playwright-cdp: no reachable CDP endpoint. PLAYWRIGHT_CDP_ENDPOINT is not set, no .env file has it, and $DEFAULT is not reachable. Start a browser with remote debugging enabled and set PLAYWRIGHT_CDP_ENDPOINT, or pass one explicitly." >&2
exit 1

#!/bin/bash
# Resolve PLAYWRIGHT_CDP_ENDPOINT and start the chrome-devtools-mcp daemon
# connected to that running Chrome instance. Never launches a new browser —
# only attaches to one that's already running and reachable.
# Priority:
#   1. Already set in the environment
#   2. .env file found by walking up from $PWD
#   3. .env in the shared-scripts install dir ($(dirname $0)/..)
#   4. Last resort: http://127.0.0.1:9222, only if something answers there
# Usage: chrome-devtools-attach [extra chrome-devtools start flags]
# Prints the resolved URL to stderr, then starts the daemon. Exits 1 with
# a clear error if no reachable CDP endpoint can be found.

set -euo pipefail

_find_env_value() {
  local file="$1"
  grep -s '^PLAYWRIGHT_CDP_ENDPOINT=' "$file" | head -1 | cut -d= -f2-
}

_is_reachable() {
  curl -s -o /dev/null -m 2 "$1/json/version"
}

_resolve_endpoint() {
  # 1. Already in environment
  if [[ -n "${PLAYWRIGHT_CDP_ENDPOINT:-}" ]]; then
    echo "$PLAYWRIGHT_CDP_ENDPOINT"
    return 0
  fi

  # 2. Walk up from CWD
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    local candidate="$dir/.env"
    if [[ -f "$candidate" ]]; then
      local val
      val="$(_find_env_value "$candidate")"
      if [[ -n "$val" ]]; then
        echo "$val"
        return 0
      fi
    fi
    dir="$(dirname "$dir")"
  done

  # 3. .env next to this script's parent (shared-scripts root)
  local scripts_root
  scripts_root="$(cd "$(dirname "$0")/.." && pwd)"
  local candidate="$scripts_root/.env"
  if [[ -f "$candidate" ]]; then
    local val
    val="$(_find_env_value "$candidate")"
    if [[ -n "$val" ]]; then
      echo "$val"
      return 0
    fi
  fi

  # 4. Last resort: default local CDP port, only if it actually answers
  local default="http://127.0.0.1:9222"
  if _is_reachable "$default"; then
    echo "$default"
    return 0
  fi

  echo "chrome-devtools-attach: no reachable CDP endpoint. PLAYWRIGHT_CDP_ENDPOINT is not set, no .env file has it, and $default is not reachable. Start a browser with remote debugging enabled and set PLAYWRIGHT_CDP_ENDPOINT, or pass one explicitly." >&2
  return 1
}

CDP="$(_resolve_endpoint)"
echo "chrome-devtools-attach: connecting to $CDP" >&2
exec chrome-devtools start --browserUrl "$CDP" "$@"

#!/bin/bash
# Resolve PLAYWRIGHT_CDP_ENDPOINT and start the chrome-devtools-mcp daemon
# connected to that running Chrome instance.
# Priority:
#   1. Already set in the environment
#   2. .env file found by walking up from $PWD
#   3. .env in the shared-scripts install dir ($(dirname $0)/..)
# Usage: chrome-devtools-attach [extra chrome-devtools start flags]
# Prints the resolved URL to stderr, then starts the daemon.

set -euo pipefail

_find_env_value() {
  local file="$1"
  grep -s '^PLAYWRIGHT_CDP_ENDPOINT=' "$file" | head -1 | cut -d= -f2-
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

  echo "chrome-devtools-attach: PLAYWRIGHT_CDP_ENDPOINT not found in environment or any .env file" >&2
  return 1
}

CDP="$(_resolve_endpoint)"
echo "chrome-devtools-attach: connecting to $CDP" >&2
exec chrome-devtools start --browserUrl "$CDP" "$@"

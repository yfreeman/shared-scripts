#!/bin/bash
# Resolve PLAYWRIGHT_CDP_ENDPOINT for playwright-cli agents.
# Priority:
#   1. Already set in the environment
#   2. .env file found by walking up from $PWD
#   3. .env in the shared-scripts install dir ($(dirname $0)/..)
# Prints the endpoint to stdout on success; exits 1 with a message on stderr on failure.

set -euo pipefail

_find_env_value() {
  local file="$1"
  grep -s '^PLAYWRIGHT_CDP_ENDPOINT=' "$file" | head -1 | cut -d= -f2-
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

echo "playwright-cdp: PLAYWRIGHT_CDP_ENDPOINT not found in environment or any .env file" >&2
exit 1

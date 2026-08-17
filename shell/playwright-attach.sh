#!/bin/bash
# Resolve CDP endpoint and attach a named playwright-cli session.
# Usage: playwright-attach <session-name> [extra playwright-cli attach flags]
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: playwright-attach <session-name> [flags]" >&2
  exit 1
fi

SESSION="$1"
shift

CDP="$(playwright-cdp)"
exec playwright-cli -s="$SESSION" attach --cdp="$CDP" "$@"

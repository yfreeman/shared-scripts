#!/usr/bin/env bash
set -e -u -o pipefail

usage() {
  cat << EOF
Usage: $(basename "$0") <ref>

Close a lazygit popup opened by lazygit-wrapper.sh.

Arguments:
  ref   The pane ref printed between the === LAZYGIT POPUP === markers
        when the popup was launched (e.g. %12).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  usage
  exit 1
fi

ref="$1"

# -C closes the popup attached to ref's window (a no-op, exit 0, if there
# isn't one open).
tmux display-popup -C -t "$ref"

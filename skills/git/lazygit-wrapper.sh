#!/usr/bin/env bash
set -e -u -o pipefail

# Configuration - override via environment variables
LAZYGIT_POPUP_SIZE="${LAZYGIT_POPUP_SIZE:-95}"  # percent of the screen, width and height

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[lazygit]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[lazygit]${NC} $*"
}

log_error() {
  echo -e "${RED}[lazygit]${NC} $*"
}

usage() {
  cat << EOF
Usage: $(basename "$0") [directory]

Launch lazygit in a floating tmux popup over the calling pane, and return
immediately without waiting for it to close. Prints a ref between
=== LAZYGIT POPUP === markers; pass that ref to lazygit-close.sh to close
the popup later.

Arguments:
  directory    Git repository directory to open (default: current directory)

Environment variables:
  LAZYGIT_POPUP_SIZE  Width/height of the popup, as a percentage of the
                      screen (default: 95)

Examples:
  $(basename "$0")                       # Open lazygit for the current directory
  $(basename "$0") ~/project             # Open lazygit for ~/project
  LAZYGIT_POPUP_SIZE=80 $(basename "$0") # Use 80% of the screen
EOF
}

check_tmux() {
  [[ -n "${TMUX:-}" ]]
}

check_lazygit() {
  if ! command -v lazygit &> /dev/null; then
    log_error "lazygit not found. Install it first."
    return 1
  fi
  return 0
}

check_repo() {
  local dir="$1"
  if git -C "$dir" rev-parse --git-dir &> /dev/null; then
    return 0
  fi
  log_error "Not a git repository: $dir"
  return 1
}

launch_lazygit_popup() {
  local target_dir="$1"

  # Target the window this wrapper runs in, not whichever pane the human
  # happens to be looking at. tmux sets $TMUX_PANE for every pane it spawns.
  local caller_pane="${TMUX_PANE:-}"
  if [[ -z "$caller_pane" ]]; then
    caller_pane=$(tmux display-message -p '#{pane_id}')
  fi

  log_info "Launching lazygit in a floating popup (${LAZYGIT_POPUP_SIZE}% of the screen)"
  log_info "Directory: $target_dir"

  # tmux's CLI call for display-popup blocks until the popup closes (-E
  # closes it as soon as the shell-command below exits). Background it so
  # this wrapper can return right away; the caller deals with the repo in
  # the popup and closes it later with lazygit-close.sh.
  tmux display-popup -E \
    -t "$caller_pane" \
    -d "$target_dir" \
    -w "${LAZYGIT_POPUP_SIZE}%" \
    -h "${LAZYGIT_POPUP_SIZE}%" \
    -T " lazygit " \
    "cd '$target_dir' && lazygit" &
  local popup_pid=$!
  disown "$popup_pid" 2> /dev/null || true

  # Give it a moment to fail fast on something like "no current client"
  # (no attached terminal) before reporting success.
  sleep 0.3
  if ! kill -0 "$popup_pid" 2> /dev/null; then
    wait "$popup_pid" 2> /dev/null
    log_error "tmux display-popup exited immediately — is a client attached to this session?"
    exit 1
  fi

  log_info "lazygit is running in a popup on $caller_pane"
  log_info "Already has a popup open for that window? tmux no-ops this call instead of stacking a second one; close the existing popup first if you want a different repo."

  echo ""
  echo "=== LAZYGIT POPUP ==="
  echo "$caller_pane"
  echo "=== END LAZYGIT POPUP ==="
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if ! check_lazygit; then
    exit 1
  fi

  local target_dir="${1:-.}"
  target_dir=$(cd "$target_dir" && pwd)  # Get absolute path

  if ! check_repo "$target_dir"; then
    exit 1
  fi

  if ! check_tmux; then
    log_error "Not running inside tmux!"
    echo ""
    echo "To use lazygit with your coding agent, run that agent inside tmux."
    echo ""
    echo "1. Exit the current agent session."
    echo ""
    echo "2. Restart the agent inside tmux."
    echo ""
    echo "3. Then run /git again."
    exit 1
  fi

  launch_lazygit_popup "$target_dir"
}

main "$@"

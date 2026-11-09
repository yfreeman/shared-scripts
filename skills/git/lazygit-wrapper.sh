#!/usr/bin/env bash
set -e -u -o pipefail

# Configuration - override via environment variables
LAZYGIT_POPUP_SIZE="${LAZYGIT_POPUP_SIZE:-95}"        # percent of the screen, width and height
LAZYGIT_WAIT_TIMEOUT="${LAZYGIT_WAIT_TIMEOUT:-300}"    # seconds to wait for another popup to close

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

Launch lazygit in a floating tmux popup over the calling pane.

Arguments:
  directory    Git repository directory to open (default: current directory)

Environment variables:
  LAZYGIT_POPUP_SIZE    Width/height of the popup, as a percentage of the
                        screen (default: 95)
  LAZYGIT_WAIT_TIMEOUT  Seconds to wait for another lazygit popup on this
                        pane to close before giving up (default: 300)

Examples:
  $(basename "$0")                      # Open lazygit for the current directory
  $(basename "$0") ~/project            # Open lazygit for ~/project
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

# tmux popups aren't regular panes, so there's no `list-panes` entry to probe
# for an already-open one. Serialize on a lock file keyed to the calling pane
# instead: a second launch from the same pane waits for the first popup to
# close rather than tmux silently dropping or replacing it.
launch_lazygit_popup() {
  local target_dir="$1"

  local caller_pane="${TMUX_PANE:-}"
  if [[ -z "$caller_pane" ]]; then
    caller_pane=$(tmux display-message -p '#{pane_id}')
  fi

  local lock_name
  lock_name=$(printf '%s' "$caller_pane" | tr -c 'A-Za-z0-9' '_')
  local lock_file="${TMPDIR:-/tmp}/lazygit-popup-${lock_name}.lock"

  exec 9> "$lock_file"
  if ! flock -w "$LAZYGIT_WAIT_TIMEOUT" 9; then
    log_error "lazygit is still open in another popup on this pane after ${LAZYGIT_WAIT_TIMEOUT}s; rerun once it's closed"
    exit 75
  fi

  log_info "Launching lazygit in a floating popup (${LAZYGIT_POPUP_SIZE}% of the screen)"
  log_info "Directory: $target_dir"

  # tmux's CLI call for display-popup blocks until the popup closes (-E
  # closes it as soon as the shell-command below exits), unlike split-window
  # / new-window, which detach immediately and need an explicit wait-for
  # signal to block on.
  tmux display-popup -E \
    -t "$caller_pane" \
    -d "$target_dir" \
    -w "${LAZYGIT_POPUP_SIZE}%" \
    -h "${LAZYGIT_POPUP_SIZE}%" \
    -T " lazygit " \
    "cd '$target_dir' && lazygit"

  flock -u 9
  exec 9>&-

  log_info "lazygit finished"
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

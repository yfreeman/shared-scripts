#!/usr/bin/env bash
set -e -u -o pipefail

# Configuration - override via environment variables
LAZYGIT_PANE_POSITION="${LAZYGIT_PANE_POSITION:-top}"   # top or bottom
LAZYGIT_PANE_SIZE="${LAZYGIT_PANE_SIZE:-80}"              # percentage of the calling pane

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

Launch lazygit in a tmux split pane for the given repository.

Arguments:
  directory    Git repository directory to open (default: current directory)

Environment variables:
  LAZYGIT_PANE_POSITION  Position of the pane: top or bottom (default: top)
  LAZYGIT_PANE_SIZE       Size of pane as percentage of the calling pane (default: 80)
  LAZYGIT_WAIT_TIMEOUT    Seconds to wait for another lazygit in this window to
                          close before giving up (default: 300)

Examples:
  $(basename "$0")                      # Open lazygit for the current directory
  $(basename "$0") ~/project            # Open lazygit for ~/project
  LAZYGIT_PANE_SIZE=70 $(basename "$0") # Use 70% of screen
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

check_lazygit_running() {
  # Only the caller's window counts: the new pane would open there, while a
  # lazygit in another window belongs to another agent session and can stay
  # open alongside this one.
  local caller_pane="${TMUX_PANE:-}"
  if [[ -z "$caller_pane" ]]; then
    caller_pane=$(tmux display-message -p '#{pane_id}')
  fi
  tmux list-panes -t "$caller_pane" -F '#{pane_current_command}' 2>/dev/null | grep -q '^lazygit$'
}

wait_for_running() {
  local timeout="${LAZYGIT_WAIT_TIMEOUT:-300}"
  local waited=0
  check_lazygit_running || return 0
  log_warn "lazygit is already running in another pane; waiting up to ${timeout}s for it to close"
  while check_lazygit_running; do
    if (( waited >= timeout )); then
      log_error "lazygit is still running after ${timeout}s; rerun once it's closed"
      exit 75
    fi
    sleep 1
    waited=$(( waited + 1 ))
  done
  log_info "The other lazygit closed; launching this one"
}

launch_lazygit_pane() {
  local target_dir="$1"

  # Split the pane this wrapper runs in, not whichever pane is focused. Without
  # an explicit target tmux uses the client's active pane — the one the human
  # is looking at — so an agent's lazygit lands in someone else's pane and
  # blocks it. tmux sets $TMUX_PANE for every pane it spawns.
  local caller_pane="${TMUX_PANE:-}"
  if [[ -z "$caller_pane" ]]; then
    caller_pane=$(tmux display-message -p '#{pane_id}')
  fi

  # Get the caller's height and calculate lines (using -l instead of -p to avoid "size missing" error)
  local pane_height
  pane_height=$(tmux display-message -p -t "$caller_pane" '#{pane_height}')
  local pane_lines=$(( pane_height * LAZYGIT_PANE_SIZE / 100 ))

  local split_args=()
  if [[ "$LAZYGIT_PANE_POSITION" == "top" ]]; then
    split_args+=(-b)  # Create pane above
  fi
  # For bottom, no -b flag needed (default)
  split_args+=(-l "$pane_lines")
  split_args+=(-c "$target_dir")

  log_info "Launching lazygit in $LAZYGIT_PANE_POSITION pane of $caller_pane (${pane_lines} lines, ${LAZYGIT_PANE_SIZE}%)"
  log_info "Directory: $target_dir"

  # Create unique channel for wait-for
  local wait_channel="lazygit-$$"

  # Create the split pane with lazygit, signal when done.
  # Use -d to not switch, -P to print pane info so we can capture the ID.
  local new_pane_id
  new_pane_id=$(tmux split-window -d -P -F '#{pane_id}' -t "$caller_pane" "${split_args[@]}" \
    "cd '$target_dir' && lazygit; tmux wait-for -S '$wait_channel'")

  # Focus the new pane only when the caller already has focus in its window.
  # If the human is working in another pane, leave them alone — they will
  # come back to the agent's pane and find lazygit waiting next to it.
  if [[ "$(tmux display-message -p -t "$caller_pane" '#{pane_active}')" == "1" ]]; then
    tmux select-pane -t "$new_pane_id"
  else
    log_info "Caller pane is not focused; leaving focus where it is"
  fi

  log_info "lazygit is running in pane $new_pane_id"
  log_info "Waiting for lazygit to exit..."

  # Block until lazygit exits
  tmux wait-for "$wait_channel"

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

  # Wait for a lazygit that is already open in this window, or this launch
  # would stack a second pane on top of it.
  wait_for_running

  launch_lazygit_pane "$target_dir"
}

main "$@"

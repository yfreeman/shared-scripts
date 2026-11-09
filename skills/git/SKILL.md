---
name: git
description: Open lazygit in a tmux split pane so the user can interactively stage, commit, branch, or resolve conflicts in a repo. Use when the user wants a git TUI pane rather than raw git commands.
---

# lazygit pane

Use this skill when the user wants an interactive git TUI — staging hunks,
committing, branching, rebasing, resolving conflicts — instead of you running
raw `git` commands on their behalf.

This only supports tmux today (the multiplexer in use everywhere lazygit is
installed). If other multiplexers show up later, this skill should grow
wrapper variants the way the `tuicr` skill has one per multiplexer.

## Launch

```bash
<skill-directory>/lazygit-wrapper.sh /path/to/repo
```

- `directory` defaults to the current directory if omitted.
- The wrapper requires `$TMUX` to be set. If it isn't, tell the user you need
  to be running inside tmux and ask them to restart the agent there, then run
  `/git` again — do not try to launch lazygit outside tmux.
- The wrapper splits the *caller's* pane (via `$TMUX_PANE`), not whichever
  pane the human happens to be looking at, so the new pane doesn't appear in
  someone else's window.
- It blocks until the user quits lazygit (`q`), then returns control to you.
  Use a long command timeout (e.g. 10 minutes) when invoking it.
- If a lazygit is already open in the caller's window, the wrapper waits (up
  to `LAZYGIT_WAIT_TIMEOUT`, default 300s) for it to close rather than
  stacking a second pane on top of it. After the timeout it exits 75 —
  rerun once the other pane is closed.

Pane size/position are configurable via `LAZYGIT_PANE_POSITION` (`top` or
`bottom`, default `top`) and `LAZYGIT_PANE_SIZE` (percent of the caller's
pane height, default `80`).

## Multiplexer tips (tmux)

- Switch panes: `Ctrl-b` then arrow keys
- Quit lazygit: `q`
- Resize panes: `Ctrl-b` then `Ctrl-arrow`
- Zoom pane: `Ctrl-b` then `z`

## When Not To Use

- The user wants you to run specific git commands yourself — just run them.
- The task needs scripted/non-interactive git operations.
- `lazygit` is not installed — tell the user to install it.

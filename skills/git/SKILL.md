---
name: git
description: Open lazygit in a floating tmux popup so the user can interactively stage, commit, branch, or resolve conflicts in a repo. Use when the user wants a git TUI pane rather than raw git commands.
---

# lazygit popup

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
- lazygit opens in a floating popup (`tmux display-popup`) covering
  `LAZYGIT_POPUP_SIZE` percent of the screen (default `95`) — not a split
  pane. The popup is tied to the *caller's* pane (via `$TMUX_PANE`) so it
  attaches to the right window/client.
- It blocks until the user quits lazygit (`q`), which closes the popup, then
  returns control to you. Use a long command timeout (e.g. 10 minutes) when
  invoking it.
- If a second launch targets the same calling pane while a popup from this
  wrapper is already open there, it waits (up to `LAZYGIT_WAIT_TIMEOUT`,
  default 300s) rather than racing to open a second popup. After the timeout
  it exits 75 — rerun once the other popup is closed.

## Multiplexer tips (tmux)

- Dismiss the popup without quitting lazygit's own shell: `Escape`
- Quit lazygit (closes the popup via `-E`): `q`
- Switch panes in the underlying window (while no popup is open): `Ctrl-b`
  then arrow keys

## When Not To Use

- The user wants you to run specific git commands yourself — just run them.
- The task needs scripted/non-interactive git operations.
- `lazygit` is not installed — tell the user to install it.

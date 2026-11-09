---
name: git
description: Open lazygit in a floating tmux popup so the user can interactively stage, commit, branch, or resolve conflicts in a repo, without blocking the agent. Use when the user wants a git TUI pane rather than raw git commands.
---

# lazygit popup

Use this skill when the user wants an interactive git TUI — staging hunks,
committing, branching, rebasing, resolving conflicts — instead of you running
raw `git` commands on their behalf.

This only supports tmux today (the multiplexer in use everywhere lazygit is
installed). If other multiplexers show up later, this skill should grow
wrapper variants the way the `tuicr` skill has one per multiplexer.

## Open

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
- **It does not block.** The wrapper launches the popup in the background
  and returns in well under a second — the user deals with the repo in the
  popup while you keep working. Don't wait around for it to close; just
  continue with whatever else the user asked for.
- It prints a ref between `=== LAZYGIT POPUP ===` markers, e.g.:
  ```
  === LAZYGIT POPUP ===
  %12
  === END LAZYGIT POPUP ===
  ```
  Capture that ref if you'll need to close the popup programmatically later
  (see Close below). If the user just quits lazygit themselves (`q`), the
  popup closes on its own and there's nothing else to do.
- If a popup is already open on that same window, tmux no-ops a second
  `display-popup` call instead of stacking one on top — nothing opens, and
  there's no error. Close the existing popup first if the user wants to point
  it at a different repo.

## Close

```bash
<skill-directory>/lazygit-close.sh <ref>
```

Closes the popup opened for that ref's window (`tmux display-popup -C`).
Use this when the user says they're done, or when you need to repurpose the
pane for a different repo. Closing when nothing is open is a harmless no-op.

## When Not To Use

- The user wants you to run specific git commands yourself — just run them.
- The task needs scripted/non-interactive git operations.
- `lazygit` is not installed — tell the user to install it.

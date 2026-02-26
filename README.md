# shared-scripts

A collection of personal CLI scripts organized by language, with a unified `bin/` entrypoint and shell integration.

## Structure

```
shared-scripts/
├── .rc              # Shell config: adds bin/ to PATH, aliases
├── install.sh       # One-time setup script
├── bin/             # Entrypoints for all scripts (wrappers/symlinks)
├── python/          # Python scripts (each in its own subdirectory)
├── node/            # Node.js scripts
├── shell/           # Shell scripts (includes setup-claude-links.sh)
├── agents/          # Claude Code agents (symlinked into .claude/agents/)
├── commands/        # Claude Code commands (symlinked into .claude/commands/)
└── skills/          # Claude Code skills (symlinked into .claude/skills/)
```

## Installation

```sh
./install.sh
source ~/.zshrc  # or ~/.bashrc
```

`install.sh` will:
- Install [uv](https://github.com/astral-sh/uv) if not present
- Add `source .../shared-scripts/.rc` to your shell rc file (`~/.zshrc`, `~/.bashrc`, or `~/.profile` depending on `$SHELL`)

Works on macOS and Linux.

## Adding a Script

### Python

1. Create a directory under `python/` with your script:
   ```
   python/my-script/
   ├── my-script.py
   └── pyproject.toml   # optional, for dependencies
   ```

2. Declare dependencies inline (no `pyproject.toml` needed for simple scripts):
   ```python
   # /// script
   # requires-python = ">=3.10"
   # dependencies = ["requests"]
   # ///
   ```

3. Create a wrapper in `bin/`:
   ```sh
   #!/usr/bin/env sh
   cd "$(dirname "$0")/../python/my-script"
   uv run my-script.py "$@"
   ```

4. Make it executable:
   ```sh
   chmod +x bin/my-script
   ```

Python scripts are run with [uv](https://github.com/astral-sh/uv), which automatically manages virtual environments and dependencies — no manual `pip install` or venv activation needed.

### Node

1. Create a directory under `node/`:
   ```
   node/my-script/
   ├── my-script.js
   └── package.json
   ```

2. Create a wrapper in `bin/`:
   ```sh
   #!/usr/bin/env sh
   cd "$(dirname "$0")/../node/my-script"
   node my-script.js "$@"
   ```

### Shell

1. Add your script to `shell/`:
   ```
   shell/my-script.sh
   ```

2. Create a wrapper (or symlink) in `bin/`:
   ```sh
   ln -s ../shell/my-script.sh bin/my-script
   chmod +x shell/my-script.sh
   ```

## Claude Code Integration

Shared agents, commands, and skills are symlinked into each project's `.claude/` directory by `shell/setup-claude-links.sh` (runs as `postCreateCommand` in devcontainers). The script links everything in `agents/`, `commands/`, and `skills/` automatically — just drop files in the right directory.

### Agents (`agents/`)

| File | Description |
|---|---|
| `chrome-browser.md` | Browser automation agent using Chrome DevTools MCP. Supports Testing Library queries. |
| `inject-testing-library.js` | Standalone CDP script that injects `@testing-library/dom` into a browser page. Used by the chrome-browser agent to enable semantic queries (`getByRole`, `getByText`, etc.) without loading the library into the agent's context. |
| `testing-library-dom.umd.min.js` | `@testing-library/dom` v10.4.1 UMD bundle. Read and injected by `inject-testing-library.js`. |

#### Testing Library injection flow

The chrome-browser agent can query page elements using Testing Library's semantic queries. The injection happens outside the agent to avoid bloating its context with the 181KB library:

1. Agent gets the target page's CDP ID from `list_pages`
2. Agent runs via Bash: `node .claude/agents/inject-testing-library.js --page-id=<ID>`
3. The script connects to Chrome via CDP, reads the UMD bundle from disk, injects it, and disconnects
4. Agent reconnects via MCP — `window.TL` is available with all Testing Library queries

### Commands (`commands/`)

| File | Description |
|---|---|
| `devtools.md` | Slash command (`/devtools`) for browser inspection tasks |

### Skills (`skills/`)

| File | Description |
|---|---|
| `worktree` | Git worktree management skill |

## Scripts

| Command | Language | Description |
|---|---|---|
| `term-agent` | Python | Stateless terminal agent for Claude Code using tmux |
| `ta` | alias | Shorthand for `term-agent` |

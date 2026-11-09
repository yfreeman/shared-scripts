# shared-scripts

A collection of personal CLI scripts organized by language, with a unified `bin/` entrypoint and shell integration.

## Structure

```
shared-scripts/
├── .rc              # Shell config: adds bin/ to PATH, aliases
├── .gitmodules      # Submodules — python/term-agent, rust/sgrep
├── install.sh       # One-time setup script
├── bin/             # Entrypoints for all scripts (wrappers/symlinks;
│                    #   gitignored per-platform binaries: sgrep, sgrep-sem)
├── CLAUDE.md        # default agent persona — linked into ~/CLAUDE.md
│                    #   (+ ~/AGENTS.md mirror) of every container that
│                    #   bind-mounts this checkout; see "Default persona"
├── AGENTS.md        # symlink -> CLAUDE.md
├── python/          # Python scripts (each in its own subdirectory)
│   └── term-agent/  # ↳ git submodule (github.com/yfreeman/term-agent)
├── rust/            # Rust projects
│   └── sgrep/       # ↳ git submodule (github-personal/yfreeman/sgrep):
│                    #   passage-level BM25 search, ripgrep-style CLI
├── models/          # gitignored: sgrep semantic embedding model
│                    #   (granite-97m-r2/; fetched by shell/get-sgrep-model.sh)
├── node/            # Node.js scripts
├── shell/           # Shell scripts (includes setup-claude-links.sh, age-*.sh)
├── age-store/       # Shared age secret recipients: keys/ + groups.conf (see its README)
├── agents/          # Claude Code agents (symlinked into .claude/agents/)
│                    #   *.opencode.md → opencode variants (→ .opencode/agents/)
│                    #   *.pi.md       → pi subagent variants (→ .pi/agent/agents/)
├── commands/        # Claude Code commands (symlinked into .claude/commands/)
├── skills/          # Claude Code skills (symlinked into .claude/skills/)
│                    #   terminal-session → ../python/term-agent/terminal-session-skill
│                    #   age-secrets      → manage age-store secrets
└── pi-extensions/   # pi extensions (symlinked into ~/.pi/agent/extensions/)
                     #   subagent → delegate tasks to isolated pi subprocesses
```

## Secrets (age-store)

`age-store/` is the single source of truth for which SSH keys can decrypt which
secrets, across repos and devices. The `age-{recipients,encrypt,decrypt,reencrypt}`
commands (in `bin/`) operate it. See [`age-store/README.md`](age-store/README.md).

## Installation

```sh
./install.sh
source ~/.zshrc  # or ~/.bashrc
```

`install.sh` will:
- Install [uv](https://github.com/astral-sh/uv) if not present
- `uv tool install` the `term-agent` CLI from
  `git+https://github.com/yfreeman/term-agent.git` (pipx-equivalent)
- `git submodule update --init --recursive` so submodules
  (`python/term-agent`, `rust/sgrep`) are populated — needed so
  `skills/terminal-session` resolves
- Builds the `sgrep` binaries into `bin/` via `shell/build-sgrep.sh` when a
  Rust toolchain is present (skipped otherwise — the binaries are
  per-platform and gitignored)
- Fetches the sgrep semantic embedding model into `models/` via
  `shell/get-sgrep-model.sh` (~396 MB; skip with `SGREP_SKIP_MODEL=1`)
- Exports `SGREP_MODEL_DIR` from `.rc`, so semantic search works in every
  container that bind-mounts this checkout (each still builds its own
  per-directory `.sgrep/` index on first `--semantic` query)
- Add `source .../shared-scripts/.rc` to your shell rc file
  (`~/.zshrc`, `~/.bashrc`, or `~/.profile` depending on `$SHELL`)

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

### Rust (`rust/`)

Rust projects live as submodules under `rust/<name>/`. Built binaries are
**per-platform and never committed** — they go into `bin/` (gitignored) via
`shell/build-sgrep.sh`, which copies every artifact `bin/` needs into place
(sgrep's lexical binary execs `sgrep-sem` from its own directory, so both
land in `bin/`). To add another Rust tool, follow that pattern: build from
the submodule into a local-disk dir, install the binaries into `bin/`, and
gitignore them.

## Claude Code Integration

### Default persona (`CLAUDE.md`)

The repo-root `CLAUDE.md` (`AGENTS.md` is a symlink to it) is the default
persona doc for agents running **inside the dev containers** — tooling
mount layout, the tools on PATH (`sgrep` incl. semantic mode, `ta`,
`age-*`), house rules for a container home on a persistent volume. It's
container-facing by design: box-specific facts (steel IPs, network
topology) live in `agent-container-dev.md` in the agents-server repo,
bind-mounted at `/etc/agent-container-dev.md`, which the persona doc tells
you to read when present.

`setup-claude-links.sh` links it into the target home as `~/CLAUDE.md` +
`~/AGENTS.md` with this precedence:

- a **regular file** `~/CLAUDE.md` wins as a safety net (nothing should
  occupy it any more — see the layering convention below),
- an existing **symlink** (including the legacy
  `~/CLAUDE.md → /etc/agent-container-dev.md`) is replaced by the shared
  default,
- containers without the shared-scripts mount get no persona from here —
  their entrypoints' `agent-container-dev.md` fallback still applies
  (dev-base `entrypoint-tail.sh` / `agent` image `entrypoint.sh`).

**Layering convention:** container/workspace-specific guidance does *not*
replace this home file — coding agents (Claude Code, Codex, pi) merge
`CLAUDE.md`/`AGENTS.md` hierarchically from home down to the cwd, so the
right shape is an extra doc deeper in the tree that wins on conflicts and
never hides the base layer. Example: wordpress-dev installs its
WordPress-specific doc at `/home/agent/projects/CLAUDE.md` (regenerated
from the image on every start by its entrypoint), so agents working in
any repo under `projects/` see persona + WP layer together.

Re-linking runs on every container start, so editing the root `CLAUDE.md`
here takes effect in all mounted containers on their next restart.

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

### Pi subagent variants (`agents/*.pi.md`)

`cdc` and `playwright-browser` have `*.pi.md` variants linked into
`~/.pi/agent/agents/` for the pi subagent extension. They differ from the
Claude originals because pi semantics differ: `tools: read, bash` (pi has no
`Skill` tool; skills are loaded by `read`ing SKILL.md and driven via Bash), and
no `model:` line (subagents inherit the dispatching session's model instead of
Claude's `sonnet`/`haiku`).

### Commands (`commands/`)

| File | Description |
|---|---|
| `devtools.md` | Slash command (`/devtools`) for browser inspection tasks |

### Skills (`skills/`)

| File | Description |
|---|---|
| `worktree` | Git worktree management skill |
| `terminal-session` | Persistent tmux-backed terminal sessions. Symlink to `../python/term-agent/terminal-session-skill/` (so the skill ships from the term-agent submodule — run `git submodule update --init` if it's empty). |
| `pr-review` | Local PR-Agent review loop against a git diff via the `pr-agent` container. Uses `bin/pr-review`. |
| `tuicr` | Attach to / drive `tuicr` TUI review sessions and launch a review pane (tmux, Zellij, cmux, Rex, or Herdr) via its bundled wrappers. Vendored verbatim from `agavra/tuicr`'s own `skills/tuicr/`. |

### Extensions (`pi-extensions/`)

| Directory | Description |
|---|---|
| `subagent` | Pi extension: delegates tasks to isolated `pi` subprocesses (keeps heavy work like browser automation out of the main context). Copied from the pi package's `examples/extensions/subagent/`. |

`setup-claude-links.sh` links each `pi-extensions/<name>/` wholesale into
`~/.pi/agent/extensions/<name>/` (pi follows dir symlinks when discovering
extensions). Project-local pi extensions are trust-gated and live at
`.pi/extensions/` instead — the script only installs the user-level location.

`setup-claude-links.sh` passes `ln -sfn` so re-running it on top of
existing dir-symlinks replaces the link in place instead of dereferencing
into the target directory (which would create a self-referencing loop
inside the source skill dir).

## Scripts

| Command | Language | Description |
|---|---|---|
| `term-agent` | Python | Stateless terminal agent for Claude Code using tmux |
| `ta` | alias | Shorthand for `term-agent` |
| `sgrep` | Rust | Passage-level BM25 + semantic search (ripgrep-style CLI). Binary gitignored; rebuild with `shell/build-sgrep.sh`. Semantic mode uses `SGREP_MODEL_DIR` (set in `.rc`, model fetched by `shell/get-sgrep-model.sh`). |
| `sgrep-sem` | Rust | Semantic engine exec'd by `sgrep` — must stay beside it in `bin/`. |
| `pr-review` | Bash | Wrapper around the `pr-agent` container for local diff reviews; writes JSON output and prints a short summary. |
| `ssh-refresh` | Bash | `ssh-refresh <host>` forgets the stored host key(s) for an `~/.ssh/config` host (resolves HostName/Port/HostKeyAlias via `ssh -G`), so the next ssh prompts to accept the new key after a container is recreated. `-c` connects straight after. |

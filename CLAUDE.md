# Agent working notes — shared default

You're an agent in one of the dev containers on this box. This file is the
default persona doc every container gets at `~/CLAUDE.md` (mirrored to
`~/AGENTS.md`) through the read-only bind-mount at
`/usr/local/shared-scripts`. Containers that need a workspace-specific persona instead
install their own `CLAUDE.md` deeper in the tree (e.g. wordpress-dev's
`projects/CLAUDE.md`), which coding agents merge hierarchically on top of
this one — this file is the base layer, never an override.

## The tooling mount: `/usr/local/shared-scripts`

One shared checkout of skills, agents, commands, and CLIs, mounted
read-only into your container and wired into `~/.bashrc` on start (PATH +
aliases + symlinks into `~/.claude`, `~/.agents`, `~/.codex`,
`~/.opencode`, `~/.pi`). It's the single source of truth for the tools
below; its own `README.md` maps the whole repo. **Never write to it** — if
you need to change a tool or skill, that happens in the upstream repo, not
from in here.

Your project code lives elsewhere (typically `/opt/...`, `/projects`, or
whatever your container's docs say) and is yours to edit.

## Tools already on your PATH

| Command | What it's for |
|---|---|
| `sgrep` | Passage-level search over notes/code — ripgrep-style flags. Works instantly, no index needed. |
| `sgrep --semantic "phrase"` | Meaning-based search. Needs a per-directory index; add `--index-if-missing` and the first query builds it (`.sgrep/` next to your files, git/self-ignored). The embedding model is pre-configured via `SGREP_MODEL_DIR` — don't unset it. |
| `ta` / `term-agent` | Persistent tmux-backed terminal sessions for long-running commands — see the `terminal-session` skill. |
| `chrome` / `start-chrome` | Local headless Chrome when you need one. |
| `age-encrypt`, `age-decrypt`, `age-recipients`, `age-reencrypt` | Encrypted secrets via `age-store/` — see the `age-secrets` skill before touching secrets. Never commit decrypted material. |

Prefer `sgrep` over `grep -r` when searching prose/notes: it returns ranked
passages instead of a wall of lines. Prefer the skills (browser automation
via `steel-browser` / `playwright-cli-cdp` / `chrome-devtools-cli`) over
installing anything browser-related locally — there's a shared Chrome pool.

## If your links look stale

The mount updates when the host pulls shared-scripts, but the symlinks into
your home are created at container start. New skills/agents/commands appear
after a container restart, or immediately with:

```sh
bash /usr/local/shared-scripts/shell/setup-claude-links.sh ~
```

## House rules for this container

- `~/` is a persistent volume (survives recreates); `/` outside it is not —
  anything you `apt install` here is gone on recreate. Put durable things
  under your project mounts or `~`.
- `/shared` (if mounted) is the cross-container/cross-device drop box
  (Syncthing). Good for handing files to another container or the laptop;
  not a build cache or database.
- If `/etc/agent-container-dev.md` exists here, read it — it carries the
  box-specific facts this generic doc deliberately omits (Chrome pool
  addresses, network topology, how to reach other containers).
- Your container may also have project-specific instructions (`CLAUDE.md`
  or `AGENTS.md` in the project root, or a persona under `/home/agents`) —
  those win over this file for anything they cover.

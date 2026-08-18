# pi-extensions

Pi (coding-agent) extensions shared across machines/harnesses. Each entry is a
directory that pi loads from `~/.pi/agent/extensions/<name>/` (global discovery;
directories with an `index.ts` entrypoint, or `package.json` with a `pi` field).
The pi loader follows directory symlinks, so `shell/setup-claude-links.sh` links
each of these wholesale into `~/.pi/agent/extensions/`.

## Layout

```
pi-extensions/
└── subagent/          # Delegates tasks to isolated pi subprocesses
```

## Adding an extension

Drop a directory here with an `index.ts` entrypoint (keep it self-contained —
pi resolves its imports against pi's own node_modules at load time), then
re-run:

```sh
shell/setup-claude-links.sh "$HOME"
```

## Provenance

- `subagent/` — copied verbatim from the pi package's examples
  (`examples/extensions/subagent/{index.ts,agents.ts}`), where it is the
  reference implementation for spawning isolated subagent processes from the
  main TUI. It is not built into pi by default — this is the install.
  Re-sync with `pi update` output when the source example changes.

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
└── shell/           # Shell scripts
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

## Scripts

| Command | Language | Description |
|---|---|---|
| `term-agent` | Python | Stateless terminal agent for Claude Code using tmux |
| `ta` | alias | Shorthand for `term-agent` |

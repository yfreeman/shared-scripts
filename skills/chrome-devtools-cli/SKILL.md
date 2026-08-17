---
name: chrome-cli
description: Automate browser interactions and inspect pages via the chrome-devtools CLI. Use when you need to navigate, click, fill forms, evaluate JavaScript, take screenshots/snapshots, inspect network/console, run Lighthouse audits, or analyze memory/performance using the chrome-devtools-mcp daemon.
allowed-tools: Bash(chrome-devtools:*) Bash(chrome-devtools-attach:*)
---

# Browser Automation with chrome-devtools CLI

The `chrome-devtools` CLI drives a background `chrome-devtools-mcp` daemon (Unix socket on Mac/Linux).

**Never launch a new browser. Only attach to one that is already running via CDP.** Do not let the daemon auto-start a fresh browser, and never run bare `chrome-devtools start` (no `--browserUrl`) — that launches a new browser. Always run `chrome-devtools-attach` first; it resolves an existing CDP endpoint and starts the daemon against it. If no reachable endpoint can be found, `chrome-devtools-attach` exits non-zero with a clear error — treat that as a hard stop and surface it to the caller. Do not work around it by starting a fresh browser.

**Never create script files to interact with the browser.** Do not write `.js`, `.ts`, `.sh`, or any other files to automate browser actions. Every browser interaction must be a direct `chrome-devtools` CLI call. Work interactively — run a command, observe the output, run the next command based on what you see.

## Sessions

Unlike `playwright-cli`'s `-s=<name>` flag, `chrome-devtools` has no documented session concept — but the daemon does support an **undocumented** `--sessionId` flag (verified against `chrome-devtools-mcp` v1.7.0 source; hidden from `--help`, absent from `docs/cli.md`). Each distinct `--sessionId` runs its own daemon process against its own socket, so parallel sessions each get an independent *selected page* — even though they can all attach to and see the same underlying browser. Without this, two `cdc` agents run at the same time would fight over which page is selected.

`--sessionId` must match `/^[a-fA-F0-9-]+$/` (hex + dashes, i.e. UUID-shaped) — arbitrary names like `agent-1` are rejected. `chrome-devtools-attach` handles this for you: pass a human-readable session name as its first argument and it deterministically hashes it into a valid `--sessionId` (same name always maps to the same id, so reusing a name reattaches to the same daemon).

```bash
# Attach with a named session — derives and starts a scoped daemon
chrome-devtools-attach checkout-flow
# stderr shows: chrome-devtools-attach: sessionId=<derived-uuid>

# Every subsequent call for this session must repeat --sessionId
chrome-devtools --sessionId=<derived-uuid> navigate_page --url "https://example.com"
chrome-devtools --sessionId=<derived-uuid> take_snapshot
chrome-devtools --sessionId=<derived-uuid> stop
```

Capture the derived id from `chrome-devtools-attach`'s stderr (last line, `chrome-devtools-attach: sessionId=<value>`) at the start of a session and reuse it on every command for that task. If no session name is given, `chrome-devtools-attach` starts the default unscoped daemon (same as omitting `--sessionId`) — fine for single-agent use, but always pass a session name when you know or suspect other `cdc` agents may run concurrently against the same browser.

## Environment Variables

`PLAYWRIGHT_CDP_ENDPOINT` — this is the same variable used by `playwright-cli`. `chrome-devtools-attach` resolves it and connects to that running Chrome instance, verifying reachability before use, in this order:

1. Already set in the shell environment.
2. A `.env` file found by walking up from `$PWD`.
3. A `.env` in the shared-scripts install root.
4. Last resort: `http://127.0.0.1:9222`, but only if something actually answers there.

If none of the above yield a reachable endpoint, `chrome-devtools-attach` **exits non-zero with a clear error** instead of launching a new browser. Treat that as a hard stop and surface it to the caller.

```bash
chrome-devtools-attach         # resolves endpoint, starts daemon attached to it via --browserUrl
# … interact …
chrome-devtools stop
```

## Quick Start

```bash
# Always attach first — never let the daemon auto-start a fresh browser
# Give it a session name if other cdc agents may run concurrently (see Sessions)
chrome-devtools-attach

# Navigate
chrome-devtools navigate_page --url "https://example.com"

# Take a snapshot to discover UIDs for elements
chrome-devtools take_snapshot

# Interact using the uid from the snapshot
chrome-devtools click "1_4"
chrome-devtools fill "1_7" "user@example.com"

# Evaluate JavaScript
chrome-devtools evaluate_script "() => document.title"

# Screenshot
chrome-devtools take_screenshot --filePath screenshot.png

# Stop daemon when done
chrome-devtools stop
```

## Command Usage

```bash
chrome-devtools <tool> [positional-args] [--flags]
chrome-devtools <tool> --help   # see all flags for a command
```

Required arguments are positional; optional ones are `--flags`.

**Not every MCP tool is available via this CLI.** `wait_for` and `fill_form` are excluded entirely — calling them fails, not just discouraged. For waiting, poll with `evaluate_script` (e.g. re-check a condition, sleep between calls) instead of `wait_for`. For multi-field forms, call `fill` once per field instead of `fill_form`. `--categoryExtensions` tools are also unavailable via the CLI.

## Output Format

Default output is Markdown. For structured data, use `--output-format=json`.

```bash
chrome-devtools list_pages --output-format=json
```

## Input Automation (uid from snapshot)

```bash
chrome-devtools take_snapshot                                      # get UIDs for elements
chrome-devtools click "uid"                                        # click element
chrome-devtools click "uid" --dblClick true --includeSnapshot true # double-click + snapshot
chrome-devtools drag "src-uid" "dst-uid"                          # drag element onto another
chrome-devtools fill "uid" "text"                                  # type text / select option
chrome-devtools fill "uid" "true"                                  # check a checkbox
chrome-devtools handle_dialog accept                               # accept a browser dialog
chrome-devtools handle_dialog dismiss --promptText "hi"           # dismiss with prompt text
chrome-devtools hover "uid"                                        # hover over element
chrome-devtools press_key "Enter"                                  # press a key
chrome-devtools press_key "Control+A"                             # key combination
chrome-devtools type_text "hello"                                  # type into focused input
chrome-devtools type_text "hello" --submitKey "Enter"             # type then press key
chrome-devtools upload_file "uid" "file.txt"                      # upload a file
```

## Navigation

```bash
chrome-devtools list_pages                                         # list open pages
chrome-devtools select_page 1                                      # select page for future calls
chrome-devtools select_page 1 --bringToFront true
chrome-devtools new_page "https://example.com"                     # open new tab
chrome-devtools new_page "https://example.com" --background true
chrome-devtools navigate_page --url "https://example.com"         # navigate current page
chrome-devtools navigate_page --type reload --ignoreCache true    # hard reload
chrome-devtools navigate_page --type back
chrome-devtools navigate_page --type forward
chrome-devtools close_page 1                                       # close page by index
```

## Emulation

```bash
chrome-devtools emulate --networkConditions "Offline"
chrome-devtools emulate --cpuThrottlingRate 4 --geolocation "37.7749,-122.4194"
chrome-devtools emulate --colorScheme "dark" --viewport "1920x1080"
chrome-devtools emulate --userAgent "Mozilla/5.0..."
chrome-devtools resize_page 1920 1080
```

## Debugging & Inspection

```bash
chrome-devtools evaluate_script "() => document.title"
chrome-devtools evaluate_script "(el) => el.innerText" --args "1_4"   # pass UID as arg
chrome-devtools take_snapshot
chrome-devtools take_snapshot --verbose true --filePath snapshot.txt
chrome-devtools take_screenshot
chrome-devtools take_screenshot --fullPage true --format jpeg --quality 80
chrome-devtools take_screenshot --uid "uid" --filePath element.png
chrome-devtools list_console_messages
chrome-devtools list_console_messages --types error --types warn
chrome-devtools get_console_message 1
chrome-devtools lighthouse_audit --mode navigation
chrome-devtools lighthouse_audit --mode snapshot --device mobile
chrome-devtools lighthouse_audit --outputDirPath ./reports
```

## Network

```bash
chrome-devtools list_network_requests
chrome-devtools list_network_requests --pageSize 50 --pageIdx 0
chrome-devtools list_network_requests --resourceTypes Fetch
chrome-devtools get_network_request
chrome-devtools get_network_request --reqid 1 --responseFilePath res.md
```

## Performance

```bash
chrome-devtools performance_start_trace true false
chrome-devtools performance_start_trace true true --filePath trace.gz
chrome-devtools performance_stop_trace
chrome-devtools performance_stop_trace --filePath trace.json
chrome-devtools performance_analyze_insight "1" "LCPBreakdown"
chrome-devtools take_memory_snapshot ./snap.heapsnapshot
```

## Service Management

```bash
chrome-devtools-attach                              # resolve endpoint and attach (always use this, never bare `start`)
chrome-devtools-attach checkout-flow                # same, scoped to a named session — see Sessions
chrome-devtools status                              # check default-session daemon status
chrome-devtools --sessionId=<derived-uuid> status   # check a named session's daemon status
chrome-devtools stop                                # stop default-session daemon
chrome-devtools --sessionId=<derived-uuid> stop     # stop a named session's daemon
```

Do not run bare `chrome-devtools start` or `chrome-devtools start --headless false` — both launch a new browser. `chrome-devtools start --browserUrl <url>` does attach to a specific URL without launching, but prefer `chrome-devtools-attach` so the endpoint resolution and reachability check run.

## Installation

```bash
npm install -g chrome-devtools-mcp@latest
chrome-devtools status   # verify install
```

## AI Workflow

0. **ALWAYS run these two commands first — no exceptions:**
   ```bash
   which chrome-devtools || npm install -g chrome-devtools-mcp@latest
   chrome-devtools-attach <session-name>   # pass a session name if the caller gave you one — see Sessions
   ```
   `chrome-devtools-attach` attaches to the existing Chrome session via `PLAYWRIGHT_CDP_ENDPOINT` (falling back to `127.0.0.1:9222` only if it's reachable). It must run before any other `chrome-devtools` command. If it exits non-zero — no reachable endpoint found, or the daemon fails to connect — surface the error and stop. Never work around this by launching a new browser. Capture the derived `sessionId` from its stderr output if a session name was given, and repeat `--sessionId=<value>` on every subsequent command.

1. After attaching, use `chrome-devtools` commands directly (with `--sessionId=<value>` on every call if you used one) — do **not** call `start`/`status`.
2. Call `take_snapshot` to get element `uid` values.
3. Use `click`, `fill`, `evaluate_script`, etc. State persists across commands.
4. After each action, observe the output and decide the next step — do not pre-plan a sequence of steps in a script.
5. Call `stop` only when you're completely done with the browser session.

**Do not write files.** Never create `.js`, `.ts`, `.sh`, or any script files to automate browser steps. Use the CLI directly for every action.

## Targeting Strategy

**Prefer these in order:**

1. **`evaluate_script` with semantic JS** — fastest, no snapshot cost:
   ```bash
   chrome-devtools evaluate_script "() => document.querySelector('button[type=submit]').click()"
   chrome-devtools evaluate_script "() => document.title"
   ```
2. **Snapshot + uid** — take `take_snapshot`, then use the uid:
   ```bash
   chrome-devtools take_snapshot
   chrome-devtools click "1_5"
   ```
3. **`--includeSnapshot`** on interaction commands — combines act + re-snapshot in one call:
   ```bash
   chrome-devtools click "1_5" --includeSnapshot true
   ```

## Example: Form Submission

```bash
chrome-devtools navigate_page --url "https://example.com/login"
chrome-devtools take_snapshot
chrome-devtools fill "1_3" "user@example.com"
chrome-devtools fill "1_4" "password123"
chrome-devtools click "1_5" --includeSnapshot true
```

## Example: Multi-tab Workflow

```bash
chrome-devtools list_pages
chrome-devtools new_page "https://example.com/other" --background true
chrome-devtools list_pages
chrome-devtools select_page 2
chrome-devtools take_snapshot
```

## Example: Debugging with DevTools

```bash
chrome-devtools navigate_page --url "https://example.com"
chrome-devtools list_console_messages --types error
chrome-devtools list_network_requests --resourceTypes Fetch
chrome-devtools evaluate_script "() => JSON.stringify(window.__APP_STATE__)"
```

## Example: Performance Audit

```bash
chrome-devtools navigate_page --url "https://example.com"
chrome-devtools performance_start_trace true true
chrome-devtools performance_analyze_insight "1" "LCPBreakdown"
chrome-devtools lighthouse_audit --mode navigation --outputDirPath ./reports
```

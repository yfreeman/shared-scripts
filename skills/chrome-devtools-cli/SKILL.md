---
name: chrome-cli
description: Automate browser interactions and inspect pages via the chrome-devtools CLI. Use when you need to navigate, click, fill forms, evaluate JavaScript, take screenshots/snapshots, inspect network/console, run Lighthouse audits, or analyze memory/performance using the chrome-devtools-mcp daemon.
allowed-tools: Bash(chrome-devtools:*) Bash(chrome-devtools-attach:*)
---

# Browser Automation with chrome-devtools CLI

The `chrome-devtools` CLI drives a background `chrome-devtools-mcp` daemon (Unix socket on Mac/Linux). The daemon starts automatically on the first command; you do not need to run `start` before each session.

**Never create script files to interact with the browser.** Do not write `.js`, `.ts`, `.sh`, or any other files to automate browser actions. Every browser interaction must be a direct `chrome-devtools` CLI call. Work interactively — run a command, observe the output, run the next command based on what you see.

## Environment Variables

`PLAYWRIGHT_CDP_ENDPOINT` — if set (in the shell environment or any `.env` file walking up from `$PWD`), `chrome-devtools-attach` connects to that running Chrome instance instead of launching a new browser. This is the same variable used by `playwright-cli`.

If `PLAYWRIGHT_CDP_ENDPOINT` is set, run `chrome-devtools-attach` instead of letting the daemon start implicitly — it handles all resolution internally:
```bash
chrome-devtools-attach         # resolves env var, starts daemon with --browserUrl
# … interact …
chrome-devtools stop
```

## Quick Start

```bash
# Daemon starts implicitly on first tool call — no explicit start needed
chrome-devtools list_pages

# Or attach to a running Chrome via PLAYWRIGHT_CDP_ENDPOINT
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
chrome-devtools start                          # explicit start (usually not needed)
chrome-devtools-attach                         # attach to PLAYWRIGHT_CDP_ENDPOINT
chrome-devtools start --browserUrl http://localhost:9222   # attach to specific URL
chrome-devtools start --headless false         # visible browser
chrome-devtools status                         # check if daemon is running
chrome-devtools stop                           # stop daemon
```

## Installation

```bash
npm install -g chrome-devtools-mcp@latest
chrome-devtools status   # verify install
```

## AI Workflow

0. **ALWAYS run these two commands first — no exceptions:**
   ```bash
   which chrome-devtools || npm install -g chrome-devtools-mcp@latest
   chrome-devtools-attach
   ```
   `chrome-devtools-attach` attaches to the existing Chrome session via `PLAYWRIGHT_CDP_ENDPOINT`. It must run before any other `chrome-devtools` command. If it fails, surface the error and stop.

1. After attaching, use `chrome-devtools` commands directly — do **not** call `start`/`status`.
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

# Browser Session Management

Run multiple isolated sessions concurrently against the same external browser, each with its own state.

**Never launch a new browser.** Every session below is created via `attach`/`playwright-attach`, never `open`. See the main [SKILL.md](../SKILL.md#connection-model) for endpoint resolution and the attach-only policy.

## Named Sessions

Use `-s` to isolate contexts within the same attached browser:

```bash
# Session 1: Authentication flow
playwright-attach auth

# Session 2: Public browsing (separate cookies, storage)
playwright-attach public

# Commands are isolated by session
playwright-cli -s=auth fill e1 "user@example.com"
playwright-cli -s=public snapshot
```

## Session Isolation Properties

Each session has independent:
- Cookies
- LocalStorage / SessionStorage
- IndexedDB
- Cache
- Browsing history
- Open tabs

## Session Commands

```bash
# List all sessions
playwright-cli list

# Detach a session — leaves the external browser running
playwright-cli -s=mysession detach
```

Do not run `close`, `close-all`, `kill-all`, or `delete-data` — the browser is external and may be in use by others; only `detach` tears down a session without affecting it.

## Attaching to the Running Browser

`playwright-attach <session>` (see [Connection model](../SKILL.md#connection-model)) resolves `PLAYWRIGHT_CDP_ENDPOINT` and attaches in one step. The underlying forms it wraps:

### Attach by channel name

Connect to a running Chrome or Edge instance by its channel name. The browser must have remote debugging enabled — navigate to `chrome://inspect/#remote-debugging` in the target browser and check "Allow remote debugging for this browser instance".

```bash
playwright-cli attach --cdp=chrome
playwright-cli attach --cdp=chrome-canary
playwright-cli attach --cdp=msedge
playwright-cli attach --cdp=msedge-dev
```

Supported channels: `chrome`, `chrome-beta`, `chrome-dev`, `chrome-canary`, `msedge`, `msedge-beta`, `msedge-dev`, `msedge-canary`.

When `--session` is not provided, the session is named after the channel (e.g. `--cdp=msedge` creates a session called `msedge`), so parallel attaches to Chrome and Edge don't collide on `default`. Pass `--session=<name>` to override.

### Attach via explicit CDP endpoint

```bash
playwright-cli attach --cdp=http://localhost:9222
```

Prefer `playwright-attach <session>` over this form so the endpoint resolution and reachability check run first.

### Attach via browser extension

Connect to a browser with the Playwright extension installed:

```bash
playwright-cli attach --extension
```

### Detach

Tear down an attached session without affecting the external browser:

```bash
# Detach the default attached session
playwright-cli detach

# Detach a specific attached session
playwright-cli -s=msedge detach
```

## Default Session

When `-s` is omitted, commands use the default session (named `default` unless attached by channel — see above):

```bash
playwright-attach default
playwright-cli snapshot
playwright-cli detach
```

## Best Practices

### 1. Name Sessions Semantically

```bash
# GOOD: Clear purpose
playwright-attach github-auth
playwright-attach docs-scrape

# AVOID: Generic names
playwright-attach s1
```

### 2. Always Detach When Done

```bash
playwright-cli -s=auth detach
playwright-cli -s=scrape detach
```

`detach` leaves the browser and its other sessions untouched — safe to run even if other agents or tasks are using the same browser concurrently.

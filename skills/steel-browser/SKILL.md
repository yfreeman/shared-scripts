---
name: steel-browser
description: Reference info for `steel`, the shared headless-Chrome pool running on this box — what it is, its ports/addresses, how to create and release a session, and how to hand that session's CDP endpoint to the playwright-cli-cdp or chrome-devtools-cli skill. Use whenever a task needs browser automation on this box and a session needs to be stood up before playwright-cli-cdp/chrome-devtools-cli can attach. Triggers on "steel", "steel-browser", "headless chrome", or when playwright-attach/chrome-devtools-attach have no browser to find.
allowed-tools: Bash(curl:*) Bash(playwright-cli:*) Bash(playwright-attach:*) Bash(chrome-devtools:*) Bash(chrome-devtools-attach:*)
---

# steel — the shared headless-Chrome pool

**This skill is reference info only — it doesn't drive the browser itself.**
Use it to stand up (or find) a steel session and get its CDP endpoint, then
hand that endpoint to **playwright-cli-cdp** or **chrome-devtools-cli** for the
actual automation (navigation, clicking, snapshots, etc.).

## What it is

`steel` ([steel-dev/steel-browser](https://github.com/steel-dev/steel-browser),
Apache-2.0, self-hosted) is one Chrome process shared by every container on
this box, handing out isolated sessions/contexts on demand instead of each
container launching and maintaining its own browser. Two containers:

| Container | Role |
|---|---|
| `steel` | REST API (create/release sessions) + the CDP surface itself |
| `steel-ui` | React dashboard — session list, live viewer, recordings |

**Never install Playwright/Chromium locally in any container to automate the
browser.** Always get a session from `steel` instead.

## Addresses / ports

| From | steel (API/CDP) | steel-ui (dashboard) |
|---|---|---|
| Default bridge network (most containers) | `172.17.0.3:3000` | `http://172.17.0.4/` |
| `data` network (e.g. `wordpress-dev`) | `http://steel:3000` (DNS) or `172.21.0.8:3000` (pinned) | `172.21.0.9` (pinned) |
| Tailnet | `steel-api.agents.yfreeman.com` (api), `steel.agents.yfreeman.com` (ui) | same |
| Public internet | — (tailnet-only) | `steel.public.agents.yfreeman.com` (basic auth) |

Bridge IPs aren't pinned and can drift if `steel`/`steel-ui` are ever
recreated — confirm with `docker inspect -f '{{(index
.NetworkSettings.Networks "bridge").IPAddress}}' steel`. The `data`-network
addresses are pinned and don't drift.

Port **`:9223`** also exists on `steel` (raw Chrome CDP, every page across
every session, not session-scoped) — see "Raw CDP (:9223)" below. It is
**not** a reliable way to attach a generic CDP tool; use the session flow.

## Session lifecycle

Unlike a plain `chrome --remote-debugging-port`, there's no bare always-on
CDP endpoint to just point a tool at — you create a session first, and the
response tells you exactly where to connect:

```bash
curl -s -X POST http://172.17.0.3:3000/v1/sessions \
  -H 'Content-Type: application/json' -d '{}'
# {"id":"<uuid>", "websocketUrl":"ws://172.17.0.3:3000/", ...}
```

`websocketUrl` is the CDP endpoint for *this* session — hand it to
the playwright-cli-cdp / chrome-devtools-cli skills (see below). Optional body fields:

- `"userDataDir": "/profiles/<name>"` — persistent profile (cookies, login
  state). One path per *concurrent* identity — Chrome locks the directory,
  so two sessions can't share one at the same time.
- `"proxyUrl": "socks5h://<host>:1080"` — route the session's traffic
  through a SOCKS proxy (the `socks5h` scheme resolves DNS inside the
  tunnel too).

**Release when done — always `POST /v1/sessions/release`, NOT `DELETE
/v1/sessions/<id>`:**

```bash
curl -s -X POST http://172.17.0.3:3000/v1/sessions/release \
  -H 'Content-Type: application/json' -d '{"sessionId":"<id>"}'
```

`DELETE /v1/sessions/<id>` looks plausible and is what older docs/scripts on
this box used to do — it 404s on this API version and silently leaks the
session if the caller swallows the error (a real bug found and fixed
2026-10-30; `wp-worktree`'s `steel-fixture.js` template and
`agent-container-dev.md` now use the correct route). Sessions aren't free
and the pool is shared by the whole box — always release.

## Connecting playwright-cli-cdp or chrome-devtools-cli to a session

Both take the session's `websocketUrl` directly, but through **different
flags** — verified empirically against this exact steel instance, since the
obvious approach (discovery-based `--browserUrl` / plain `PLAYWRIGHT_CDP_ENDPOINT`
pointed at :9223) does not work here (see "Raw CDP" below).

**playwright-cli-cdp** — the CDP attach skill. The binary is still `playwright-cli`. Works via the normal wrapper, just export the session's
URL first so it skips endpoint discovery:

```bash
export PLAYWRIGHT_CDP_ENDPOINT="ws://172.17.0.3:3000/"   # from websocketUrl
playwright-attach my-session
# ...use playwright-cli -s=my-session <command> as normal (see the playwright-cli-cdp skill)...
```

Equivalently, direct (no wrapper): `playwright-cli attach --cdp="<websocketUrl>" --session=my-session`.

**chrome-devtools-cli** — the `chrome-devtools-attach` wrapper does **not**
work against steel (it hardcodes `--browserUrl`, which requires standard CDP
HTTP discovery — broken here, see below). Bypass the wrapper and call the
underlying command with `--wsEndpoint` instead of `--browserUrl`:

```bash
chrome-devtools start --wsEndpoint "ws://172.17.0.3:3000/"   # from websocketUrl
# optionally: --sessionId=<hex-uuid> for multi-agent scoping, same convention
# chrome-devtools-attach uses — see that skill's "Sessions" section
chrome-devtools list_pages
# ...then chrome-devtools <tool> as normal (see that skill)...
chrome-devtools stop
```

## Raw CDP (`:9223`) — what it's for, and why not to attach tools to it

```bash
curl -s http://172.17.0.3:9223/json/list     # every open page, across every session
```

Useful for a quick look at what's open, or building a DevTools inspector URL
by hand. **Known upstream bug**: the `webSocketDebuggerUrl` it reports is
missing its port entirely (`ws://172.17.0.3/devtools/page/...` instead of
`...172.17.0.3:9223/...`) — add `:9223` back manually if you build a URL
from this output. This is also *why* pointing `--browserUrl`/plain
`PLAYWRIGHT_CDP_ENDPOINT` at `:9223` fails for a generic tool: the tool
fetches `/json/version`, trusts the broken (portless) URL it gets back, and
fails to connect (confirmed: lands on port 80 instead of 9223). Always go
through a session's own `websocketUrl` instead — it's built from steel's
`DOMAIN` config, not Chrome's self-report, so it doesn't have this bug.

## Visual debugging

- **Dashboard** (`http://172.17.0.4/` / `steel.agents.yfreeman.com`) —
  session list, click one for a live view a human can take control of.
- **Direct screencast**, no dashboard: `http://172.17.0.3:3000/v1/sessions/debug`
- **Raw CDP tab list**: `http://172.17.0.3:9223/json/list` (see above)

## Known env quirks on this box's `steel` container

- `SKIP_FINGERPRINT_INJECTION=true` — upstream `:latest` had a fingerprint
  library bug that failed every Chrome launch; this disables the
  (unneeded here) anti-bot fingerprint randomization as a workaround.
- `DOMAIN`/`HOST` are set to steel's bridge identity (`172.17.0.3:3000`) —
  this is what gets baked into every session's `websocketUrl`, regardless
  of which network/address you used to create the session. A container on
  `data` (e.g. `wordpress-dev`) creating a session via `http://steel:3000`
  still gets back a bridge-IP `websocketUrl` — that's fine, since `steel`
  is dual-homed onto `data` too and the bridge IP is directly reachable
  from there.

## Known crash: a page-close race kills the whole shared process

Confirmed 2026-11-02, while running a Playwright acceptance suite (many
sequential `browser.newContext()` sessions, each navigating to a live page)
against this box's `steel` container. What looks at first like the
already-known `page.goto` hang (see below) can actually be the **entire
`steel` process crashing**, not just a slow response:

```
TargetCloseError: Protocol error (Page.addScriptToEvaluateOnNewDocument):
Session closed. Most likely the page has been closed.
    at ... installMouseHelper (file:///app/api/build/utils/browser.js:31:16)
    at CDPService.handleNewTarget (file:///app/api/build/services/cdp/cdp.service.js:250:21)
```

This is an **uncaught exception inside steel's own CDP instrumentation** — a
race between a page closing and steel's `handleNewTarget` trying to attach
`installMouseHelper` to it — not a bug in the calling code or in whatever
page it was navigating to. The uncaught rejection kills the container's Node
process; Docker's restart policy brings it back a few seconds later, but
every session in flight at that moment gets `ECONNREFUSED` or `getaddrinfo
ENOTFOUND steel`, and the crash can outlast a couple of client-side retries.

**How to tell this is what's happening** (vs. an ordinary slow page):
```bash
docker logs steel --tail 60 | grep -A8 TargetCloseError   # the crash itself
docker inspect steel --format 'RestartCount: {{.RestartCount}}, StartedAt: {{.State.StartedAt}}'
# RestartCount climbing across a test run = steel is crash-looping, not just slow
```

**What to do about it:**
- Don't just raise retry counts and move on if you're seeing `ECONNREFUSED`/
  `ENOTFOUND steel` rather than a plain timeout — that's a different failure
  mode (total outage, not latency) and retries only help if steel is back up
  by the time the retry fires.
- Before re-running a failed suite, check `RestartCount` first. If it's
  climbing or just bumped, give it 30–60s and confirm `curl
  http://steel:3000/v1/sessions` responds cleanly before retrying — hammering
  a crash-looping container immediately tends to just trigger it again.
- This is a bug in the `steel` image itself (steel-dev/steel-browser), not
  fixable from a consuming container. If it's happening often enough to
  block real work, it's worth upgrading the image or filing upstream rather
  than continuing to work around it per-task.
- Separately (and already partly mitigated via `retries: 2` in affected
  `playwright.config.js` files): `steel` also genuinely *hangs* on
  `page.goto` for 30–45s under sustained use without crashing, confirmed by
  timing an identical navigation via a raw script (reliably 2–3s) against
  the same navigation through a test runner (intermittently 45s+). That's a
  separate, milder issue from the crash above — don't conflate the two when
  diagnosing a failure.

## Further reading

- `agent-container-dev.md` — fuller Python examples, visual-testing/pixel-diff
  pattern, more gotchas (`--shm-size`, page IDs resetting on restart, etc.)
- `google-chrome.md` (agents-server repo) — original architecture doc,
  day-2 ops (updating the image, tailing logs).
- `containers/images/wordpress-dev/CLAUDE.md` — how `wp-worktree test`'s
  Playwright acceptance suite uses steel from the `data` network.

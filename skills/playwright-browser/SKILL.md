---
name: playwright-browser
description: Drive the shared Playwright run-server on this box. One Chromium per CLI session, concurrent up to MAX_CLIENTS. Use for browser automation that must not go through Steel. Attach with playwright-cli --endpoint. The CLI's Playwright major.minor must match the server or the socket is rejected.
allowed-tools: Bash(playwright-cli:*) Bash(node:*)
---

# playwright-browser — shared run-server

One skill. Do not use `steel-browser` or `playwright-cli-cdp` for this server.
Those attach over CDP. This server speaks the Playwright protocol only.

The container is `playwright`. It runs `playwright run-server`. Each
`playwright-cli -s=<name> attach --endpoint=...` gets its own Chromium.
A second attach does not steal the first. Cap is `MAX_CLIENTS` (8). A
client past the cap is rejected. It does not queue.

There is no dashboard and no `:9222` inspector. Console, network, and
traces are CLI commands on the same connection.

## Version lock — check this before attaching

The server is `playwright-core@1.65.0-alpha-2026-10-30`.
The client must be that same major.minor. Anything else gets:

```
HTTP 428 Precondition Required
Playwright version mismatch:
  - server version: v1.65
  - client version: v1.64
```

Stop on 428. Do not retry with a different binary, and do not fall back
to Steel or `playwright-cli open`.

Do not trust `command -v playwright-cli`. A default shell in
wordpress-dev resolves `/usr/local/bin/playwright-cli`, which is 1.64 and
will 428. Every `playwright-cli` command below means this binary:

```bash
~/.npm-global/bin/playwright-cli
```

That is `@playwright/cli` 0.1.23. Also wrong: the host's
`/usr/bin/playwright-cli` (0.1.22 / 1.64).

Confirm before attaching:

```bash
node -e '
const fs = require("fs");
const path = require("path");
const os = require("os");
const bin = path.join(os.homedir(), ".npm-global/bin/playwright-cli");
const real = fs.realpathSync(bin);
const pkg = path.join(path.dirname(real), "node_modules/playwright-core/package.json");
const v = JSON.parse(fs.readFileSync(pkg, "utf8")).version;
const need = "1.65.0-alpha-2026-10-30";
if (v !== need) {
  console.error("refusing to attach: " + bin + " is playwright-core " + v + ", server is " + need);
  process.exit(1);
}
console.log(bin, v);
'
```

If that exits non-zero, report the two versions and stop.

## Where to connect

| From | Endpoint |
|---|---|
| `data` network (wordpress-dev and anything that can resolve `playwright`) | `ws://playwright:3000/` |
| Same, if DNS is down | `ws://172.21.0.12:3000/` (pinned) |
| Default bridge | `ws://<bridge-ip>:3000/` — drifts on recreate. `docker inspect -f '{{(index .NetworkSettings.Networks "bridge").IPAddress}}' playwright` |
| Tailnet browser, not a container | `wss://playwright.agents.yfreeman.com/` |

Containers must not use the tailnet hostname. Packets from a container to
the box's own tailnet IP are dropped. Use `ws://playwright:3000/`.

Do not export `PLAYWRIGHT_CDP_ENDPOINT`. Do not run `playwright-attach`.
That wrapper is CDP-only and will not speak to this server.

## Session

Pick the session name the caller gave you. If none, use `agent`. Always
pass `-s=<name>`. Two names are two browsers. The same name reuses that
CLI daemon's connection.

```bash
playwright-cli -s=<session> attach --endpoint=ws://playwright:3000/
playwright-cli -s=<session> goto https://example.com
playwright-cli -s=<session> eval "() => document.title"
```

When finished, detach. That drops the websocket and that Chromium exits.

```bash
playwright-cli -s=<session> detach
```

Do not `close`, `close-all`, or `kill-all`. `close` is for a browser the
CLI itself launched. `detach` is the release.

Leave the session attached only if the caller asked you to hold it.

## Driving the page

Prefer `eval` / `run-code` over snapshots. Snapshots are large.

After attach, register Testing Library once per context. The bundle sits
next to this skill. `addInitScript` runs before `document.body` exists, so
the second script rebinds `screen` on `DOMContentLoaded`.

```bash
TL_BUNDLE="${CLAUDE_SKILL_DIR}/testing-library-dom.umd.min.js"
playwright-cli -s=<session> run-code "async page => {
  const ctx = page.context();
  await ctx.addInitScript({ path: '$TL_BUNDLE' });
  await ctx.addInitScript(() => {
    const rebind = () => {
      if (window.TestingLibraryDom && document.body) {
        const TL = window.TestingLibraryDom;
        TL.screen = TL.getQueriesForElement(document.body);
        window.TL = TL;
      }
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', rebind);
    else rebind();
  });
  return 'init-scripts-registered';
}"
```

If `CLAUDE_SKILL_DIR` is unset, the bundle is
`/usr/local/shared-scripts/skills/playwright-browser/testing-library-dom.umd.min.js`
inside wordpress-dev, or
`/srv/shared/shared-scripts/skills/playwright-browser/testing-library-dom.umd.min.js`
on the host.

Check on a real page (not `about:blank`):

```bash
playwright-cli -s=<session> --raw eval "() => !!window.TL && typeof TL.screen.getByRole === 'function'"
# expects: true
```

Order of action:

1. `eval` with `TL.screen.getByRole` / `getByLabelText` / `getByText`.
2. `eval` / `run-code` with `document.querySelector` or `page.url()`.
3. CSS selector: `playwright-cli -s=<session> click "#submit"`.
4. `snapshot` only when the structure is unknown. Narrow it (`--depth=4`).

Query priority inside `eval`: `getByRole`, `getByLabelText`,
`getByPlaceholderText`, `getByText`, `getByDisplayValue`, `getByAltText`,
`getByTitle`, `getByTestId`.

## Inspect, without a DevTools UI

```bash
playwright-cli -s=<session> console
playwright-cli -s=<session> requests
playwright-cli -s=<session> request 1
playwright-cli -s=<session> tracing-start
playwright-cli -s=<session> tracing-stop
```

`tracing-stop` writes a zip. Open it with `playwright show-trace` on a
machine that has the same Playwright. That is the performance timeline
(actions, network, console, screenshots). It is not a CPU flame chart.

Raw CDP still works, proxied through the Playwright connection:

```bash
playwright-cli -s=<session> run-code "async page => {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Performance.enable');
  return await cdp.send('Performance.getMetrics');
}"
```

## What this server does not do

- No per-session proxy and no persistent `userDataDir`. Launch options are
  the server defaults. Do not pass `--unsafe` tricks from the client; the
  server is not started with `--unsafe`.
- No Steel session id, no `POST /v1/sessions`, no `websocketUrl` from Steel.
- Chromium inside `playwright` can reach the tailnet (sidecar
  `playwright-ts`) and other containers on `data`. A page URL of
  `127.0.0.1` means the browser container, not the caller. From
  wordpress-dev use `http://wordpress-dev:<port>/` or the pinned
  `172.21.0.6`.

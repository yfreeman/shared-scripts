---
name: playwright-cli
description: Automate browser interactions, test web pages and work with Playwright tests.
allowed-tools: Bash(playwright-cli:*) Bash(npx:*) Bash(npm:*) Bash(playwright-cdp) Bash(playwright-attach:*)
---

# Browser Automation with playwright-cli

## Connection model

**Never launch a new browser. Only attach to one that is already running via CDP.** Do not use `playwright-cli open` — not as a fallback, not in examples, not for any reason. Every workflow in this skill is attach-only.

Use `playwright-attach <session>` to resolve the endpoint and attach in one statically-analyzable command:

```bash
playwright-attach <session>
```

`playwright-attach` (and the underlying `playwright-cdp`) resolve `PLAYWRIGHT_CDP_ENDPOINT` in this order, verifying reachability before use:

1. Already set in the shell environment.
2. A `.env` file found by walking up from `$PWD`.
3. A `.env` in the shared-scripts install root.
4. Last resort: `http://127.0.0.1:9222`, but only if something actually answers there.

If none of the above yield a reachable endpoint, `playwright-attach`/`playwright-cdp` **exit non-zero with a clear error**. Treat that as a hard stop: surface the error to the caller. Do not fall back to `playwright-cli open` to work around it — that means no browser is available for this task, not that one should be launched.

Once the named session exists, every subsequent command operates on it via `-s=<session>`. Use `playwright-cli detach` instead of `playwright-cli close` when tearing down — `close` kills the browser, `detach` leaves the external browser running.

```bash
# probe before attaching — reuse if already present
playwright-cli list --json

# attach
playwright-attach agent

# subsequent calls
playwright-cli -s=agent snapshot
playwright-cli -s=agent click e15

# detach when done — leaves the external browser running
playwright-cli -s=agent detach
```

Always pass `-s=<session-name>` so parallel agents don't collide. Use the session name the caller gives you in the task; if none was provided, default to `agent`.

## Testing Library injection (mandatory)

After attaching, register two init scripts on the context. Playwright fires them on every existing and future page automatically — no manual re-injection on navigation.

The bundle is co-located with this skill at `${CLAUDE_SKILL_DIR}/testing-library-dom.umd.min.js`, so the path resolves correctly regardless of where the skill is installed (personal, project, or plugin) or what directory the session started in.

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
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', rebind);
    } else {
      rebind();
    }
  });
  return 'init-scripts-registered';
}"
```

**Why two scripts and a rebind?** `addInitScript` runs after document creation but **before** any page scripts — at that point `document.body` is still null. The TL bundle's `screen` object captures `document.body` at module-evaluation time, so without the rebind it falls into a stub branch and every `screen.getByRole(...)` call throws `For queries bound to document.body a global document has to be available`. The second init script defers a rebind to `DOMContentLoaded`, which gives `screen` a fresh queries object pointed at the live body.

Verify on a real page (not `chrome://*` — `addScriptTag` is blocked there):

```bash
playwright-cli -s=<session> --raw eval "() => !!window.TL && typeof TL.screen.getByRole === 'function'"
# expects: true
```

If `window.TL` is ever missing (e.g. a page opened in a different context), re-run the `run-code` step.

## Targeting strategy

**Snapshots are expensive — avoid them by default.** Only take a snapshot when other methods have failed or you need structural/positional information you cannot obtain via JS.

Order of preference:

1. **Testing Library via injected `window.TL` (primary).** Query and act entirely through `eval` — no snapshot needed:
   ```bash
   playwright-cli -s=agent eval "() => { TL.screen.getByRole('button', { name: /submit/i }).click(); }"
   playwright-cli -s=agent eval "() => TL.screen.getByLabelText('Email').value"
   playwright-cli -s=agent eval "() => TL.screen.queryByText('Error') ? true : false"
   ```
   This bypasses Playwright's locator layer entirely, which is the brittle part over CDP.

2. **Script execution via `eval` or `run-code` (secondary).** When TL queries aren't a natural fit, drive the page with direct JS:
   ```bash
   playwright-cli -s=agent eval "() => document.querySelector('#submit-btn').click()"
   playwright-cli -s=agent eval "() => document.title"
   playwright-cli -s=agent run-code "async page => page.url()"
   ```

3. **CSS selectors (tertiary).** When the selector is stable and known:
   ```bash
   playwright-cli -s=agent click "#main > button.submit"
   ```

4. **Snapshot + ref (last resort).** Only use when the above methods fail, you need to discover unknown structure, or pixel-level layout information is required. Take the narrowest snapshot possible:
   ```bash
   playwright-cli -s=agent snapshot --depth=4
   playwright-cli -s=agent snapshot e34        # scoped to one element
   ```
   Never take a full-page snapshot just to find a single element.

5. **Playwright locators (avoid).** `getByRole(...)`, `getByText(...)` as locator *strings* passed to `click`/`fill` are brittle over CDP. Use `window.TL` via `eval` instead.

### Testing Library query priority

Inside `eval` calls, follow the standard Testing Library guidance:

1. `getByRole` — buttons, headings, links, form controls
2. `getByLabelText` — form fields with labels
3. `getByPlaceholderText` — inputs with placeholder text
4. `getByText` — visible text content
5. `getByDisplayValue` — current value of form elements
6. `getByAltText` — images, area elements
7. `getByTitle` — title attribute
8. `getByTestId` — last resort

All have `getBy`/`getAllBy`/`queryBy`/`queryAllBy`/`findBy`/`findAllBy` variants.

## Quick start

```bash
# attach to the already-running browser (see Connection model)
playwright-attach agent
# navigate to a page
playwright-cli -s=agent goto https://playwright.dev
# interact with the page using refs from the snapshot
playwright-cli -s=agent click e15
playwright-cli -s=agent type "page.click"
playwright-cli -s=agent press Enter
# take a screenshot (rarely used, as snapshot is more common)
playwright-cli -s=agent screenshot
# detach when done — leaves the browser running
playwright-cli -s=agent detach
```

## Commands

### Core

```bash
playwright-attach agent
playwright-cli -s=agent goto https://playwright.dev
playwright-cli -s=agent type "search query"
playwright-cli -s=agent click e3
playwright-cli -s=agent dblclick e7
# --submit presses Enter after filling the element
playwright-cli -s=agent fill e5 "user@example.com"  --submit
playwright-cli -s=agent drag e2 e8
# drop files or data onto an element (from outside the page)
playwright-cli -s=agent drop e4 --path=./image.png
playwright-cli -s=agent drop e4 --data="text/plain=hello world"
playwright-cli -s=agent hover e4
playwright-cli -s=agent select e9 "option-value"
playwright-cli -s=agent upload ./document.pdf
playwright-cli -s=agent check e12
playwright-cli -s=agent uncheck e12
playwright-cli -s=agent snapshot
playwright-cli -s=agent eval "document.title"
playwright-cli -s=agent eval "el => el.textContent" e5
# get element id, class, or any attribute not visible in the snapshot
playwright-cli -s=agent eval "el => el.id" e5
playwright-cli -s=agent eval "el => el.getAttribute('data-testid')" e5
playwright-cli -s=agent dialog-accept
playwright-cli -s=agent dialog-accept "confirmation text"
playwright-cli -s=agent dialog-dismiss
playwright-cli -s=agent resize 1920 1080
playwright-cli -s=agent detach
```

### Navigation

```bash
playwright-cli go-back
playwright-cli go-forward
playwright-cli reload
```

### Keyboard

```bash
playwright-cli press Enter
playwright-cli press ArrowDown
playwright-cli keydown Shift
playwright-cli keyup Shift
```

### Mouse

```bash
playwright-cli mousemove 150 300
playwright-cli mousedown
playwright-cli mousedown right
playwright-cli mouseup
playwright-cli mouseup right
playwright-cli mousewheel 0 100
```

### Save as

```bash
playwright-cli screenshot
playwright-cli screenshot e5
playwright-cli screenshot --filename=page.png
playwright-cli pdf --filename=page.pdf
```

### Tabs

```bash
playwright-cli tab-list
playwright-cli tab-new
playwright-cli tab-new https://example.com/page
playwright-cli tab-close
playwright-cli tab-close 2
playwright-cli tab-select 0
```

### Storage

```bash
playwright-cli state-save
playwright-cli state-save auth.json
playwright-cli state-load auth.json

# Cookies
playwright-cli cookie-list
playwright-cli cookie-list --domain=example.com
playwright-cli cookie-get session_id
playwright-cli cookie-set session_id abc123
playwright-cli cookie-set session_id abc123 --domain=example.com --httpOnly --secure
playwright-cli cookie-delete session_id
playwright-cli cookie-clear

# LocalStorage
playwright-cli localstorage-list
playwright-cli localstorage-get theme
playwright-cli localstorage-set theme dark
playwright-cli localstorage-delete theme
playwright-cli localstorage-clear

# SessionStorage
playwright-cli sessionstorage-list
playwright-cli sessionstorage-get step
playwright-cli sessionstorage-set step 3
playwright-cli sessionstorage-delete step
playwright-cli sessionstorage-clear
```

### Network

```bash
playwright-cli route "**/*.jpg" --status=404
playwright-cli route "https://api.example.com/**" --body='{"mock": true}'
playwright-cli route-list
playwright-cli unroute "**/*.jpg"
playwright-cli unroute
```

### DevTools

```bash
playwright-cli console
playwright-cli console warning
playwright-cli network
playwright-cli run-code "async page => await page.context().grantPermissions(['geolocation'])"
playwright-cli run-code --filename=script.js
playwright-cli tracing-start
playwright-cli tracing-stop
playwright-cli video-start video.webm
playwright-cli video-chapter "Chapter Title" --description="Details" --duration=2000
playwright-cli video-stop

# launch the dashboard with annotation prompt to ask the user for input
playwright-cli show --annotate

# generate a Playwright locator for an element from its ref or selector
playwright-cli generate-locator e5 --raw

# show a persistent highlight overlay for an element, optionally with a custom style
playwright-cli highlight e5
playwright-cli highlight e5 --style="outline: 3px dashed red"
# hide a single element highlight, or all page highlights when no target is given
playwright-cli highlight e5 --hide
playwright-cli highlight --hide
```

## Raw output

The global `--raw` option strips page status, generated code, and snapshot sections from the output, returning only the result value. Use it to pipe command output into other tools. Commands that don't produce output return nothing.

```bash
playwright-cli --raw eval "JSON.stringify(performance.timing)" | jq '.loadEventEnd - .navigationStart'
playwright-cli --raw eval "JSON.stringify([...document.querySelectorAll('a')].map(a => a.href))" > links.json
playwright-cli --raw snapshot > before.yml
playwright-cli click e5
playwright-cli --raw snapshot > after.yml
diff before.yml after.yml
TOKEN=$(playwright-cli --raw cookie-get session_id)
playwright-cli --raw localstorage-get theme
```

For structured output wrapping every reply as JSON, pass --json
```bash
playwright-cli list --json
```

## Attach parameters

```bash
# Connect to browser via Playwright Extension
playwright-cli attach --extension=chrome

# Connect to a running Chrome or Edge by channel name
playwright-cli attach --cdp=chrome
playwright-cli attach --cdp=msedge

# Connect to a running browser via explicit CDP endpoint
# (prefer playwright-attach <session> — see Connection model — over this
# form, so the endpoint resolution/reachability check runs)
playwright-cli attach --cdp=http://localhost:9222

# Detach from an attached browser (leaves the external browser running)
playwright-cli -s=agent detach
```

## Snapshots

After each command, playwright-cli provides a snapshot of the current browser state.

```bash
> playwright-cli goto https://example.com
### Page
- Page URL: https://example.com/
- Page Title: Example Domain
### Snapshot
[Snapshot](.playwright-cli/page-2026-02-14T19-22-42-679Z.yml)
```

You can also take a snapshot on demand using `playwright-cli snapshot` command. All the options below can be combined as needed.

```bash
# default - save to a file with timestamp-based name
playwright-cli snapshot

# save to file, use when snapshot is a part of the workflow result
playwright-cli snapshot --filename=after-click.yaml

# snapshot an element instead of the whole page
playwright-cli snapshot "#main"

# limit snapshot depth for efficiency, take a partial snapshot afterwards
playwright-cli snapshot --depth=4
playwright-cli snapshot e34

# include each element's bounding box as [box=x,y,width,height]
playwright-cli snapshot --boxes
```

See [Targeting strategy](#targeting-strategy) above for the priority order to use when targeting elements — prefer `window.TL` via `eval` over raw snapshot refs, CSS selectors, or Playwright locator strings.

## Browser Sessions

```bash
playwright-attach mysession
playwright-cli -s=mysession click e6
playwright-cli -s=mysession detach  # leaves the external browser running

# list all local sessions
playwright-cli list
```

Do not run `close`, `close-all`, `kill-all`, or `delete-data` — the browser is external and may be in use by others; only `detach`.

## Installation

If global `playwright-cli` command is not available, try a local version via `npx playwright-cli`:

```bash
npx --no-install playwright-cli --version
```

When local version is available, use `npx playwright-cli` in all commands. Otherwise, install `playwright-cli` as a global command:

```bash
npm install -g @playwright/cli@latest
```

## Example: Form submission

```bash
playwright-attach agent
playwright-cli -s=agent goto https://example.com/form
playwright-cli -s=agent snapshot

playwright-cli -s=agent fill e1 "user@example.com"
playwright-cli -s=agent fill e2 "password123"
playwright-cli -s=agent click e3
playwright-cli -s=agent snapshot
playwright-cli -s=agent detach
```

## Example: Multi-tab workflow

```bash
playwright-attach agent
playwright-cli -s=agent goto https://example.com
playwright-cli -s=agent tab-new https://example.com/other
playwright-cli -s=agent tab-list
playwright-cli -s=agent tab-select 0
playwright-cli -s=agent snapshot
playwright-cli -s=agent detach
```

## Example: Debugging with DevTools

```bash
playwright-attach agent
playwright-cli -s=agent goto https://example.com
playwright-cli -s=agent click e4
playwright-cli -s=agent fill e7 "test"
playwright-cli -s=agent console
playwright-cli -s=agent network
playwright-cli -s=agent detach
```

```bash
playwright-attach agent
playwright-cli -s=agent goto https://example.com
playwright-cli -s=agent tracing-start
playwright-cli -s=agent click e4
playwright-cli -s=agent fill e7 "test"
playwright-cli -s=agent tracing-stop
playwright-cli -s=agent detach
```

## Example: Interactive session

Ask the user to annotate the UI. User can provide contextual tasks or ask contextual questions using annotations:

```bash
playwright-attach agent
playwright-cli -s=agent goto https://example.com
playwright-cli -s=agent show --annotate
```

## Specific tasks

* **Running and Debugging Playwright tests** [references/playwright-tests.md](references/playwright-tests.md)
* **Request mocking** [references/request-mocking.md](references/request-mocking.md)
* **Running Playwright code** [references/running-code.md](references/running-code.md)
* **Browser session management** [references/session-management.md](references/session-management.md)
* **Storage state (cookies, localStorage)** [references/storage-state.md](references/storage-state.md)
* **Test generation** [references/test-generation.md](references/test-generation.md)
* **Tracing** [references/tracing.md](references/tracing.md)
* **Video recording** [references/video-recording.md](references/video-recording.md)
* **Inspecting element attributes** [references/element-attributes.md](references/element-attributes.md)

## Operating loop

1. `playwright-cli list --json` — check if your session is already attached.
2. If not attached: run `playwright-attach <session>`, then run the **Testing Library injection** block above (registers `addInitScript` for the whole context).
3. **Act** using `window.TL` eval (primary), direct JS eval (secondary), or CSS selectors (tertiary). Do not take a snapshot unless those methods fail or you need structural discovery.
4. **Verify** with a TL `queryBy*` check, `eval`, console output, or network log. Use a scoped snapshot (`snapshot e34` or `snapshot --depth=4`) only if JS-based verification isn't sufficient.
5. **Report back concisely**: one sentence on what you did and the outcome, relevant data (URL, key text, error messages, counts), anything unexpected worth flagging, and a suggested next step if useful. Keep it tight — the caller does not want a transcript or a full snapshot dump.

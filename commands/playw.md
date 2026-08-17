"There is a powerful playwright-browser agent that drives an external Chrome/Edge over CDP via `playwright-cli`. Delegate browser tasks to it instead of trying them inline. The agent attaches to a running browser using `PLAYWRIGHT_CDP_ENDPOINT` from `./.env`, takes a named session (`-s=<name>`), and runs through `Bash`.

Default targeting is **snapshot + ref**: the agent runs `playwright-cli -s=<s> snapshot`, reads the YAML accessibility tree, and acts by ref (`e15`, `e23`, …). Refs are reliable over CDP attach where Playwright's own locator strings (`getByRole(...)` etc.) are brittle.

The agent also auto-injects `@testing-library/dom` via two `addInitScript` calls when it attaches, so `window.TL` is available on every page in the context — no manual re-injection on navigation. Use `playwright-cli -s=<s> eval \"() => TL.screen.getByRole(...)\"` for semantic queries when refs are awkward (large pages, dynamic content). Trigger DOM events directly (`.click()`, `.dispatchEvent(...)`) from inside `eval` rather than relying on Playwright's locator-based click.

When investigating a page, prefer snapshot + ref or `window.TL`-driven `eval` over screenshots. Only fall back to screenshots when visual rendering is the actual question (layout, styling, regression checks).

## Session name persistence (harness guidance)

The agent always ends its response with a `Session: <name>` line describing the session it used and the current browser state (e.g. `Session: wp-admin — logged into WordPress admin, on Posts list`).

When you receive this, the session name is already in your context for the current conversation turn. On the **next** `/playw` invocation for the same task, pass that session name in the agent prompt so it reattaches to the same browser context instead of starting fresh. No memory write needed — it stays in context."

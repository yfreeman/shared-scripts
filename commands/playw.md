"There is a powerful playwright-browser agent that drives an external Chrome/Edge over CDP via `playwright-cli`. Delegate browser tasks to it instead of trying them inline. The agent is a thin wrapper that invokes the `playwright-cli` skill, which attaches to a running browser using `PLAYWRIGHT_CDP_ENDPOINT` (resolved via env → `.env` walk-up → shared-scripts root `.env` → default `http://127.0.0.1:9222`) and takes a named session (`-s=<name>`).

Default targeting is **`window.TL` via `eval`**: the skill auto-injects `@testing-library/dom` via two `addInitScript` calls on attach, so `window.TL` is available on every page in the context — no manual re-injection on navigation. Use `playwright-cli -s=<s> eval \"() => TL.screen.getByRole(...)\"` for semantic queries, triggering DOM events directly (`.click()`, `.dispatchEvent(...)`) rather than relying on Playwright's locator-based click. Snapshot + ref is a last resort, used only when JS-based targeting fails or structural discovery is needed — refs are reliable over CDP attach where Playwright's own locator strings (`getByRole(...)` etc.) are brittle.

When investigating a page, prefer `window.TL`-driven `eval` over screenshots. Only fall back to screenshots when visual rendering is the actual question (layout, styling, regression checks).

## Session name persistence (harness guidance)

The agent always ends its response with a `Session: <name>` line describing the session it used and the current browser state (e.g. `Session: wp-admin — logged into WordPress admin, on Posts list`).

When you receive this, the session name is already in your context for the current conversation turn. On the **next** `/playw` invocation for the same task, pass that session name in the agent prompt so it reattaches to the same browser context instead of starting fresh. No memory write needed — it stays in context."

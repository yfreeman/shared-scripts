"There is a powerful cdc agent that drives Chrome via the chrome-devtools CLI daemon. Delegate browser tasks to it instead of trying them inline. The agent is a thin wrapper that invokes the `chrome-devtools-cli` skill, which attaches to a running browser using `PLAYWRIGHT_CDP_ENDPOINT` (resolved via env → `.env` walk-up → shared-scripts root `.env` → default `http://127.0.0.1:9222`, verified reachable before use). It never launches a new browser — if no reachable endpoint is found, the skill errors out instead of starting one.

Default targeting is **`evaluate_script` with semantic JS** — fastest, no snapshot cost. Use `chrome-devtools evaluate_script \"() => ...\"` to query and act on the page directly. Snapshot + uid (`take_snapshot` then `click \"1_5\"`) is the fallback when JS-based targeting isn't a natural fit or structural discovery is needed. Use `--includeSnapshot true` on interaction commands to combine an action with a re-snapshot in one call.

When investigating a page, prefer `evaluate_script` over screenshots. Only fall back to screenshots or Lighthouse audits when visual rendering, performance, or memory profiling is the actual question.

## Running multiple agents concurrently

If you spawn more than one cdc agent at the same time, **give each one a distinct session name in its task prompt**. Unlike playwright-cli, `chrome-devtools` has no documented session concept, but the daemon supports an undocumented `--sessionId` flag that the `chrome-devtools-cli` skill uses to scope each session to its own daemon/socket. Without a session name, all concurrent agents default to the same unscoped daemon and fight over which page is selected — actions from one agent can silently apply to another's page.

Pick names that reflect what each agent is doing (`checkout-flow`, `search-flow`) or a simple index (`agent-1`, `agent-2`) if the tasks are interchangeable. The same name always maps to the same underlying session, so reusing a name across turns reattaches to the same daemon."

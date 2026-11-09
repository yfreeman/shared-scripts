---
name: pr-review
description: Kick off local PR-Agent code reviews from a checked-out repo and read structured feedback back. Use when an agent needs to review a branch/working diff without creating or publishing to GitHub, or when iterating on findings before pushing. Requires the `pr-agent` container and Docker access.
allowed-tools: Bash(pr-review:*), Bash(docker:*), Bash(git:*), Read
---

# pr-review — local PR-Agent feedback loop

Use this skill when you want to run PR-Agent locally against a git diff and
consume the JSON/markdown feedback yourself.

The helper is:

```bash
pr-review [options] [repo-path]
```

It is on `PATH` when `/usr/local/shared-scripts` is mounted and wired.

## What it does

1. Resolves the repo with:
   ```bash
   git -c safe.directory='*' -C <repo> rev-parse --show-toplevel
   ```
2. Builds a diff:
   - default: `origin/HEAD...HEAD`, falling back to `main`/`master`
   - if empty, falls back to `git diff HEAD`
   - `--uncommitted` forces `git diff HEAD`
3. Runs PR-Agent locally in one of two modes:
   - Docker mode, if `docker` and the `pr-agent` container are visible:
     ```bash
     docker exec -i pr-agent python -m pr_agent.cli --stdin ...
     ```
   - Runner mode, if Docker is not available:
     ```bash
     curl -X POST http://pr-agent:8000/review-local
     ```
4. Writes JSON feedback:
   - Docker mode host output:
     ```text
     /root/containers/data/pr-agent/outputs/<repo>-<timestamp>-<command>.json
     ```
   - Container output:
     ```text
     /app/pr-agent-outputs/<repo>-<timestamp>-<command>.json
     ```
   - Runner mode can also save the API response locally with `--local-out`.
5. Prints a short summary unless `--raw` or `--json` is used.

## Basic commands

Review the current branch against its base:

```bash
pr-review /home/dev/projects/myrepo
```

Review only uncommitted working-tree changes:

```bash
pr-review --uncommitted /home/dev/projects/myrepo
```

Review a specific base:

```bash
pr-review --base origin/main /home/dev/projects/myrepo
```

Generate code suggestions locally:

```bash
pr-review --command improve /home/dev/projects/myrepo
```

Generate PR description locally:

```bash
pr-review --command describe /home/dev/projects/myrepo
```

Add context to the review:

```bash
pr-review \
  --title "Session renderer updates" \
  --description "Focus on session state, renderer lifecycle, and ESM/CJS compatibility." \
  --extra "Check for race conditions, stale closures, and missing cleanup." \
  /home/dev/projects/myrepo
```

Machine-readable output only:

```bash
pr-review --json /home/dev/projects/myrepo
```

## Feedback loop pattern

Use this when you want to iterate before pushing:

1. Run:
   ```bash
   OUT=$(pr-review --json /home/dev/projects/myrepo)
   ```
2. Read the JSON:
   ```bash
   cat "$OUT"
   ```
3. For `review`, inspect:
   ```json
   {
     "review": {
       "estimated_effort_to_review_[1-5]": 3,
       "key_issues_to_review": [
         {
           "relevant_file": "src/foo.ts",
           "issue_header": "Possible Bug",
           "issue_content": "...",
           "start_line": 12,
           "end_line": 18
         }
       ]
     },
     "usage": {},
     "coverage": {}
   }
   ```
4. Apply fixes locally.
5. Re-run `pr-review` until findings are addressed.

## Where it must run

The helper now has two access paths.

Docker mode works from:

- the host
- `agent-ops`
- any container with `/var/run/docker.sock` mounted

Runner mode works from containers on the `data` network that can reach:

```text
http://pr-agent:8000/review-local
```

This includes `wordpress-dev` and `projects`.

When running from a dev container, pass `--local-out` if you want the JSON
response saved inside that container:

```bash
cd /home/agent/projects/frameshop-custom-framer
/usr/local/shared-scripts/bin/pr-review \
  --uncommitted \
  --title "Local review" \
  --local-out /tmp/pr-review.json
```

The helper infers the PR-Agent container repo path for common mounts:

| Your path | pr-agent path |
|---|---|
| `/home/dev/projects/<repo>` | `/home/agent/projects/<repo>` |
| `/home/agent/projects/<repo>` | `/home/agent/projects/<repo>` |
| `/opt/projects/<repo>` | `/home/agent/projects/<repo>` |
| `/projects/<repo>` | `/home/agent/projects/<repo>` |

Use `--pr-agent-repo PATH` if the repo is mounted somewhere unusual.

## Repo visibility

The `pr-agent` container mounts:

```text
/home/dev/projects -> /home/agent/projects:ro
```

So repos under `/home/dev/projects` get better working-tree context because
PR-Agent can read the checked-out files while reviewing the diff.

Repos outside that tree still work, but PR-Agent runs in patch-only mode with
less surrounding file context.

## Model/output configuration

PR-Agent server/container model profile lives in:

```text
/root/containers/data/pr-agent/model.env
```

GitHub/App secrets live in:

```text
/root/containers/data/pr-agent/settings_prod/.secrets.toml
```

Do not put secrets in `/shared` or commit them. The local CLI path uses the
same container environment.

## Useful checks

Container status:

```bash
docker ps --format '{{.Names}}\t{{.Status}}' | grep pr-agent
```

Logs while a review runs:

```bash
docker logs -f pr-agent
```

Output directory:

```bash
ls -l /root/containers/data/pr-agent/outputs
```

## Caveats

- `/review` is usually the fastest local loop.
- `/improve` is slower and more expensive because it generates suggestions and
  self-reflection.
- Plain-diff mode does not publish comments to GitHub.
- If the diff is large, start with `--command review` and narrow the diff or
  pass explicit files to `git diff` manually.
- The runner API is currently unauthenticated and only reachable on the private
  `data` network. Do not expose `:8000` publicly unless you add
  `PR_AGENT_RUNNER_TOKEN`.

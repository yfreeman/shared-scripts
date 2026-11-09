#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: pr-review [options] [repo-path]

Runs PR-Agent locally against a git diff and writes JSON feedback that an agent
can read back.

Modes:
  1. Docker mode, when docker + /var/run/docker.sock are available:
       docker exec -i pr-agent python -m pr_agent.cli ...
  2. Runner mode, when no docker socket is available:
       POST http://pr-agent:8000/review-local

Options:
  --base REF             Base branch/commit. Default: origin/HEAD, main, or master.
  --uncommitted          Force diff of HEAD against the working tree.
  --command CMD          review|describe|improve. Default: review.
  --title TEXT           Plain-diff title/context.
  --description TEXT     Plain-diff description/context.
  --extra TEXT           Tool-specific extra instructions.
  --out NAME             Output JSON filename. Docker mode writes under
                         /root/containers/data/pr-agent/outputs.
  --json                 Print the JSON file path only in Docker mode; print the
                         runner JSON path in runner mode.
  --raw                  Do not print a short summary.
  --container NAME       PR-Agent container. Default: pr-agent.
  --runner URL           Force runner URL. Default: $PR_AGENT_RUNNER or
                         http://pr-agent:8000/review-local.
  --pr-agent-repo PATH   Path inside the pr-agent container for the repo. Use
                         this from dev containers so PR-Agent can read the
                         checked-out working tree.
  --local-out PATH       In runner mode, also save the API response JSON here.
  -h, --help             Show this help.

Environment:
  PR_AGENT_RUNNER        Runner URL override.
  PR_AGENT_REPO_PATH     pr-agent container path override.

Notes:
  - Plain-diff mode does not publish to GitHub; it is for local feedback loops.
  - Repos under /home/dev/projects are mounted read-only into pr-agent at
    /home/agent/projects. From wordpress-dev, pass:
      --pr-agent-repo /home/agent/projects/<repo>
  - From projects, pass:
      --pr-agent-repo /home/agent/projects/<repo>
    even if your local path is /opt/projects/<repo>.
USAGE
}

REPO="${PWD}"
BASE=""
COMMAND="review"
UNCOMMITTED=0
TITLE=""
DESCRIPTION=""
EXTRA=""
OUT=""
JSON_ONLY=0
RAW=0
CONTAINER="pr-agent"
RUNNER="${PR_AGENT_RUNNER:-}"
PR_AGENT_REPO="${PR_AGENT_REPO_PATH:-}"
LOCAL_OUT=""
HOST_OUTPUT_DIR="/root/containers/data/pr-agent/outputs"
CONTAINER_OUTPUT_DIR="/app/pr-agent-outputs"
HOST_PROJECTS="/home/dev/projects"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE="${2:?--base requires a value}"
      shift 2
      ;;
    --uncommitted)
      UNCOMMITTED=1
      shift
      ;;
    --command)
      COMMAND="${2:?--command requires a value}"
      shift 2
      ;;
    --title)
      TITLE="${2:?--title requires a value}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:?--description requires a value}"
      shift 2
      ;;
    --extra)
      EXTRA="${2:?--extra requires a value}"
      shift 2
      ;;
    --out)
      OUT="${2:?--out requires a value}"
      shift 2
      ;;
    --json)
      JSON_ONLY=1
      shift
      ;;
    --raw)
      RAW=1
      shift
      ;;
    --container)
      CONTAINER="${2:?--container requires a value}"
      shift 2
      ;;
    --runner)
      RUNNER="${2:?--runner requires a value}"
      shift 2
      ;;
    --pr-agent-repo)
      PR_AGENT_REPO="${2:?--pr-agent-repo requires a value}"
      shift 2
      ;;
    --local-out)
      LOCAL_OUT="${2:?--local-out requires a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      REPO="$1"
      shift
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "pr-review: python3 is required to build the request and summarize output." >&2
  exit 127
fi

if ! command -v git >/dev/null 2>&1; then
  echo "pr-review: git is not available." >&2
  exit 127
fi

REPO="$(git -c safe.directory='*' -C "$REPO" rev-parse --show-toplevel)"
gitcmd() {
  git -c safe.directory="$REPO" -C "$REPO" "$@"
}

if [[ -z "$BASE" ]]; then
  BASE="$(gitcmd symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  BASE="${BASE#origin/}"
fi

if [[ -z "$BASE" ]]; then
  for candidate in main master; do
    if gitcmd show-ref --verify --quiet "refs/heads/$candidate"; then
      BASE="$candidate"
      break
    fi
  done
fi

if [[ -z "$BASE" ]]; then
  echo "pr-review: could not infer a base branch. Pass --base REF." >&2
  exit 1
fi

if [[ "$UNCOMMITTED" -eq 1 ]]; then
  DIFF="$(gitcmd diff HEAD)"
else
  DIFF="$(gitcmd diff "$BASE...HEAD" || true)"
  if [[ -z "$DIFF" ]]; then
    DIFF="$(gitcmd diff HEAD)"
  fi
fi

if [[ -z "$DIFF" ]]; then
  echo "pr-review: no diff found against $BASE (and no working-tree diff)." >&2
  exit 1
fi

if [[ -z "$TITLE" ]]; then
  TITLE="Local $(basename "$REPO") review"
fi

if [[ -z "$DESCRIPTION" ]]; then
  DESCRIPTION="Review the local diff produced by pr-review. No hosted PR is available."
fi

if [[ -z "$OUT" ]]; then
  OUT="$(basename "$REPO")-$(date +%Y%m%d-%H%M%S)-${COMMAND}.json"
fi

infer_pr_agent_repo() {
  local repo="$1"
  if [[ -n "$PR_AGENT_REPO" ]]; then
    printf '%s\n' "$PR_AGENT_REPO"
    return
  fi

  if [[ "$repo" == "$HOST_PROJECTS/"* ]]; then
    printf '%s\n' "/home/agent/projects/${repo#"$HOST_PROJECTS/"}"
    return
  fi

  # Common dev-container paths that map back to the same host projects tree.
  if [[ "$repo" == "/home/agent/projects/"* ]]; then
    printf '%s\n' "$repo"
    return
  fi
  if [[ "$repo" == "/opt/projects/"* ]]; then
    printf '%s\n' "/home/agent/projects/${repo#"/opt/projects/"}"
    return
  fi
  if [[ "$repo" == "/projects/"* ]]; then
    printf '%s\n' "/home/agent/projects/${repo#"/projects/"}"
    return
  fi

  printf ''
}

CONTAINER_REPO="$(infer_pr_agent_repo "$REPO")"

docker_mode=0
if [[ -z "$RUNNER" ]] && command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  docker_mode=1
fi

if [[ "$docker_mode" -eq 1 ]]; then
  HOST_OUT="$HOST_OUTPUT_DIR/$OUT"
  CONTAINER_OUT="$CONTAINER_OUTPUT_DIR/$OUT"

  mkdir -p "$HOST_OUTPUT_DIR"

  cli_args=(python -m pr_agent.cli --stdin --json-output "$CONTAINER_OUT" "$COMMAND")
  cli_args+=(--plain_diff.title="$TITLE")
  cli_args+=(--plain_diff.description="$DESCRIPTION")
  if [[ -n "$EXTRA" ]]; then
    case "$COMMAND" in
      review) cli_args+=(--pr_reviewer.extra_instructions="$EXTRA") ;;
      improve) cli_args+=(--pr_code_suggestions.extra_instructions="$EXTRA") ;;
      describe) cli_args+=(--pr_description.extra_instructions="$EXTRA") ;;
      *) cli_args+=(--pr_reviewer.extra_instructions="$EXTRA") ;;
    esac
  fi

  exec_args=(docker exec -i)
  if [[ -n "$CONTAINER_REPO" ]]; then
    exec_args+=(-w "$CONTAINER_REPO")
  fi
  exec_args+=("$CONTAINER" "${cli_args[@]}")

  printf '%s\n' "$DIFF" | "${exec_args[@]}"

  if [[ "$JSON_ONLY" -eq 1 ]]; then
    printf '%s\n' "$HOST_OUT"
    exit 0
  fi

  printf '\nJSON: %s\n' "$HOST_OUT"

  if [[ "$RAW" -eq 0 ]]; then
    python3 - "$HOST_OUT" "$COMMAND" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
command = sys.argv[2]

try:
    data = json.loads(path.read_text())
except Exception as exc:
    print(f"summary unavailable: {exc}")
    raise SystemExit(0)

usage = data.get("usage") or {}
if usage:
    print(f"usage: {usage}")

if command == "review":
    review = data.get("review") or {}
    issues = review.get("key_issues_to_review") or []
    print(f"effort: {review.get('estimated_effort_to_review_[1-5]', 'unknown')}")
    print(f"key issues: {len(issues)}")
    for issue in issues[:5]:
        header = (issue.get("issue_header") or "").strip()
        content = (issue.get("issue_content") or "").strip().splitlines()[0] if issue.get("issue_content") else ""
        file = (issue.get("relevant_file") or "").strip()
        print(f"- {header} [{file}]: {content}")
elif command == "improve":
    suggestions = data.get("code_suggestions") or data.get("suggestions") or []
    print(f"suggestions: {len(suggestions)}")
    for item in suggestions[:5]:
        header = (item.get("relevant_header") or item.get("suggestion_summary") or "suggestion")
        file = (item.get("relevant_file") or "").strip()
        print(f"- {header} [{file}]")
elif command == "describe":
    print("describe JSON written")
else:
    print("JSON written")
PY
  fi

  exit 0
fi

if [[ -z "$RUNNER" ]]; then
  RUNNER="http://pr-agent:8000/review-local"
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "pr-review: neither docker nor curl is available, so runner mode cannot run." >&2
  exit 127
fi

if [[ -z "$CONTAINER_REPO" ]]; then
  echo "pr-review: could not infer a pr-agent container repo path. Pass --pr-agent-repo PATH." >&2
  exit 1
fi

BODY_FILE="$(mktemp)"
RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE" "$RESPONSE_FILE"' EXIT

read -r -d '' RUNNER_BODY_PY <<'PY' || true
import json
import sys

diff = sys.stdin.read()
command, title, description, extra, cwd, repo, out = sys.argv[1:8]
print(json.dumps({
    "diff": diff,
    "command": command,
    "title": title,
    "description": description,
    "extra": extra,
    "cwd": cwd,
    "repo": repo,
    "output_name": out,
}))
PY

printf '%s\n' "$DIFF" | python3 -c "$RUNNER_BODY_PY" "$COMMAND" "$TITLE" "$DESCRIPTION" "$EXTRA" "$CONTAINER_REPO" "$REPO" "$OUT" > "$BODY_FILE"

curl -sS -X POST "$RUNNER" \
  -H 'Content-Type: application/json' \
  --data-binary "@$BODY_FILE" > "$RESPONSE_FILE"

if [[ -n "$LOCAL_OUT" ]]; then
  cp "$RESPONSE_FILE" "$LOCAL_OUT"
fi

if [[ "$JSON_ONLY" -eq 1 ]]; then
  cat "$RESPONSE_FILE"
  exit 0
fi

python3 - "$RESPONSE_FILE" "$COMMAND" "$RAW" <<'PY'
import json
import sys
from pathlib import Path

response_file = sys.argv[1]
command = sys.argv[2]
raw = sys.argv[3] == "1"
raw_response = Path(response_file).read_text()

try:
    data = json.loads(raw_response)
except Exception as exc:
    print(f"runner returned non-JSON: {exc}")
    print(raw_response[:1000])
    raise SystemExit(1)

if not data.get("ok", False):
    print("runner failed")
    print(data.get("error") or data.get("stderr") or raw_response[:1000])
    raise SystemExit(1)

print(f"output_path: {data.get('output_path')}")
result = data.get("json") or {}
usage = result.get("usage") or {}
if usage:
    print(f"usage: {usage}")

if raw:
    print(result)
elif command == "review":
    review = result.get("review") or {}
    issues = review.get("key_issues_to_review") or []
    print(f"effort: {review.get('estimated_effort_to_review_[1-5]', 'unknown')}")
    print(f"key issues: {len(issues)}")
    for issue in issues[:5]:
        header = (issue.get("issue_header") or "").strip()
        content = (issue.get("issue_content") or "").strip().splitlines()[0] if issue.get("issue_content") else ""
        file = (issue.get("relevant_file") or "").strip()
        print(f"- {header} [{file}]: {content}")
elif command == "improve":
    suggestions = result.get("code_suggestions") or result.get("suggestions") or []
    print(f"suggestions: {len(suggestions)}")
    for item in suggestions[:5]:
        header = (item.get("relevant_header") or item.get("suggestion_summary") or "suggestion")
        file = (item.get("relevant_file") or "").strip()
        print(f"- {header} [{file}]")
elif command == "describe":
    print("describe JSON written")
else:
    print("JSON written")
PY

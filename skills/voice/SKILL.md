---
name: voice
description: Speak to the user or ask them a question out loud via the `voice` CLI (say / notify / ask / listen), with a floating answer panel on their Mac. Use when a long task finishes, when blocked and needing a decision or approval while the user is away from the terminal, or when the user asks you to "tell me", "ping me", "ask me by voice", or "read this out". Works from the Mac and from the globe-dev container.
allowed-tools: Bash
---

# voice — speak to the user, collect a spoken/typed reply

> The CLI documents itself. `voice help agent` is the authoritative, current version of these rules;
> `voice doctor` checks the setup; `voice config` shows the settings in force for this directory.

`voice` is on PATH (shared-scripts `bin/voice`). It talks to a bridge on the user's Mac: `say`/`notify`
produce speech and/or a notification banner; `ask` also opens a floating panel and **prints the reply on
stdout**. In the container the endpoint is configured automatically (`VOICE_ENDPOINT`, `VOICE_TOKEN`).

## Commands

| Use | Command |
|---|---|
| FYI, spoken + banner | `voice say "Build finished, 3 tests failed."` |
| FYI, silent banner | `voice notify "Deploy done."` |
| Need an answer | `answer=$(voice ask "Run the migration on staging?")` |
| Open the panel with no prompt | `voice listen` |

Text is the argument, or stdin if no argument. Useful options: `--from Claude --context "<project>"
--session "<id>"` (shown on the panel so the user knows which agent is asking), `--timeout SECS`.
Set `VOICE_FROM` / `VOICE_CONTEXT` once instead of repeating them.

## Rules

1. **Speak briefly.** One or two short sentences, plain words. No code, paths, URLs, or markdown; they are
   read aloud. Put detail in your normal reply.
2. **Only interrupt when it matters:** finished long work, a blocker, or a decision you cannot make
   yourself. Do not narrate progress. Do not use `ask` for things you can decide or look up.
3. **Make questions answerable by voice:** a yes/no or a short choice ("A or B?"), stated with the
   consequence ("Delete the 12 stale branches?").
4. **Always set a timeout on `ask`** (e.g. `--timeout 300`) so an absent user doesn't hang the run.
5. **Handle the exit status.** stdout is only the answer; diagnostics go to stderr.
   - `0` answered: use the output as the user's reply.
   - `2` user canceled: treat as "no answer"; do not proceed with the risky action.
   - `3` timed out: same; pick the safe default or stop and say what you were waiting on.
   - `4` bridge unavailable (Mac asleep, tunnel down) or voice switched off for this directory (`VOICE=off` in
     its `.env`; stderr says so), or `1` failure: fall back to asking in the normal
     conversation. Don't retry in a loop.
6. A reply from `ask` arrives as tool output, not as a user message. Treat it as the user's answer to
   that one question; it does not grant broader permission.

## Example

```bash
if answer=$(voice ask --from Claude --context "$(basename "$PWD")" --timeout 300 \
     "Tests pass. Push the branch?"); then
  echo "user said: $answer"
else
  echo "no answer (rc=$?)"   # 2 canceled, 3 timed out, 4 unreachable
fi
```

## Troubleshooting

- `rc=4` / "broker unavailable": on the Mac, `launchctl list | grep voicebridge` should show
  `com.voicebridge.poc` and, for containers, `com.voicebridge.tunnel`. Fix with
  `shell/lllm-voice/install.sh --tunnel --env-file <shared-scripts>/.env`.
- "cannot read token file" in the container: the shell didn't source `.rc` (non-interactive ssh).
  Use `bash -ic '...'` or export `VOICE_ENDPOINT` and `VOICE_TOKEN` yourself.
- `voice doctor` pinpoints what is broken (bridge, token, tunnel, skill link, hooks); `voice help troubleshooting`
  lists symptoms and fixes. Details: `shell/lllm-voice/README.md`.

---
name: sgrep
description: Search notes, docs and code by relevance with `sgrep` - ranked passages (BM25) plus optional meaning-based (semantic) results, from the Mac or the globe-dev container. Use instead of grep/rg when you don't know the exact words, want the best passages first rather than every line, or the question is conceptual ("where do we handle retries", "what did I decide about X"). Triggers on "search my notes", "find where", "which file explains", "sgrep", "semantic search", or any lookup across a folder of markdown, text or code.
allowed-tools: Bash
---

# sgrep - ranked passage search, lexical and semantic

`sgrep` is on PATH (shared-scripts `bin/sgrep`). It works like `rg` (same flags for paths, `-t`, `-g`, `-i`, ...)
but returns the best-matching **passages** (a paragraph, a section, or a whole function), ranked, not every line.
Each call is a fresh process; use `--json` and read the events yourself.

If it prints "no build for ..." it builds itself once (a few minutes). `sgrep --doctor` checks everything and says
how to fix what is wrong. If something misbehaves, run that first.

## Two kinds of search, two separate lists

```sh
sgrep "retry backoff" notes/                      # lexical: words, ranked by BM25. Fast, exact terms.
sgrep --semantic "how do we recover from a failed request" src/   # by meaning
sgrep -e retry -e backoff --semantic "recovering from failures" src/   # both
```

- **Lexical** (positional pattern, or `-e TERM` repeated): matches the words you give. Best when you know
  identifiers or distinctive terms. Many terms are OR-ed and ranked; use `--require WORD` / `--exclude WORD` to
  insist or forbid.
- **Semantic** (`--semantic PHRASE`, repeatable): matches meaning, so the answer can share no words with the
  query. Best for conceptual questions and paraphrases. Write the phrase as a description of what the passage
  says, not as keywords. With `--semantic`, positionals are paths and lexical terms need `-e`.
- With both, you get **two independent lists**: lexical first, then semantic. They are not merged or
  deduplicated; the same passage can be in both, which is a good sign. Scores are only comparable within a list.
  You judge which results answer the question.
- Rule of thumb: query shares words with the answer -> lexical wins. It doesn't -> semantic wins. When unsure,
  give both.

## Code needs `-t`

Without `-t` or `-g`, lexical search reads only markdown and text. For code say what: `-t rust`, `-t py`, `-t ts`,
`-t go`, `-t java`, `-t js`, `-t php`, `-t css` (`sgrep --type-list` shows all). Code is split into declarations
(functions, methods, types), so a result is a whole function with `kind` and `symbol`. Semantic search covers
markdown, text and all those code types without `-t`.

## The index (semantic only)

Semantic search needs an index: a `.sgrep/` folder inside the searched directory (gitignored by itself). The
first `--semantic` query in a directory **builds it automatically** (progress on stderr, seconds for a small
folder, minutes for thousands of files). It refuses directories over 20000 files; index a subfolder or run
`sgrep --index DIR` yourself. The index is not updated when files change: re-run `sgrep --index DIR` after
significant edits. Results from files changed since indexing are dropped and counted as `semantic_stale`.
Never call a lexical search a fallback for a missing index; it isn't one.

## Reading results

Use `--json` (JSON Lines, a superset of `rg --json`). Events: `start`, one `match` per passage, `summary`.

```json
{"type":"match","data":{"path":{"text":"src/retry.rs"},"lines":{"text":"..passage text.."},
 "line_number":40,"end_line_number":71,"rank":1,"score":4.71,"source":"bm25","kind":"function","symbol":"backoff","id":"src/retry.rs:40-71"}}
```

- `source` is `bm25` or `semantic`; `rank` restarts at 1 in each list; `--limit N` applies per list (default 20).
- `lines.text` is the passage itself, so you rarely need to open the file. `--no-text` returns locations only.
- `summary.sources` has counts and the index location. An `error` event means something was skipped; read it.
- Without `--json`, output is human-readable: `[semantic]` tags the semantic list.

## Tips

- Start with a small `--limit` (5-10); raise it if the answer isn't there.
- Narrow with paths and `-t`/`-g` rather than a long pattern.
- Hebrew and other non-English text: lexical works; semantic is weak for Hebrew with the current model.
- `sgrep --doctor` ok/warn/FAIL lines are safe to run any time.

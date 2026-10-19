---
name: sgrep
description: Search notes, docs and code by relevance with `sgrep` - ranked passages (BM25), optional meaning-based (semantic) results, and an exhaustive mode (`--all --hits`) that lists every matching line like rg -n. Works on the Mac and in the globe-dev container. Use instead of grep/rg when you don't know the exact words, want the best passages first rather than every line, the question is conceptual ("where do we handle retries", "what did I decide about X"), or you need all usages of a term. Triggers on "search my notes", "find where", "which file explains", "all usages of", "sgrep", "semantic search", or any lookup across a folder of markdown, text or code.
allowed-tools: Bash
---

# sgrep - ranked passage search, lexical and semantic

`sgrep` is on PATH (shared-scripts `bin/sgrep`) and works like `rg` (same `-t`, `-g`, `-i`, paths, `--json`), but it
returns the best-matching **passages** (a paragraph, a section, a whole function), ranked, instead of every line.
Each call is a fresh process. `sgrep --help` lists everything; `sgrep --doctor` checks the setup and says how to fix
what is wrong (run it first if anything misbehaves). If there is no build for the platform it builds itself once.

## Pick the command

| You want | Run |
|---|---|
| Best passages for words you know | `sgrep -e retry -e backoff src/` |
| An exact phrase | `sgrep "retry backoff" notes/` |
| An answer that shares no words with the question | `sgrep --semantic "recovering from a failed downstream call" src/` |
| Both signals | `sgrep -e retry --semantic "recovering from failures" src/` |
| **Every** usage of a term (instead of rg) | `sgrep --all --hits -e render src/` |
| Update the semantic index after edits | `sgrep --refresh src/` |
| Check the setup | `sgrep --doctor` |

Add `--json` to read results programmatically, `--limit N` to change the list size (default 20).

## Lexical, semantic, and the two lists

- **Lexical** (positional pattern or `-e TERM`): matches the words you give, ranked by BM25. Best for identifiers and
  distinctive terms. **A bare multi-word pattern is one exact phrase** (as in rg): `sgrep "cache eviction ttl"` finds
  passages with those words together, usually nothing. For any-of, give each word its own `-e`. Matching is
  **smart-case**: `cache` also finds `Cache`, an uppercase letter makes it exact; `-s` forces exact, `-i` forces
  insensitive. `--require WORD` and `--exclude WORD` insist or forbid. A search that finds nothing prints a hint on
  stderr when it can guess why; read it.
- **Semantic** (`--semantic PHRASE`, repeatable): matches meaning. Write a description of what the passage says, not
  keywords. With `--semantic`, positionals are paths and lexical terms need `-e`. It is good at getting you to the
  right area and not always at the exact answer: scan the top 5, do not trust hit #1. Hebrew is weak with the current
  model; lexical is fine.
- With both you get **two independent lists, lexical first**, never merged or deduplicated. A passage in both lists
  is a good sign. Scores are comparable only within a list; you decide which results answer the question.
- Rule of thumb: the query shares words with the answer, use lexical. It doesn't, use semantic. Unsure, give both.
- Use **rg** for regexes you need exact control over, context lines (`-A/-B/-C`), `-l`, `-c`, `-o`, `-v`, multiline.

## All results: `--all --hits`

Results are cut at `--limit`; stderr then says `showing 20 of 138 matching passages; --all returns every one` and the
`summary` event has `stats.passages_admitted`. For "every usage / all callers / blast radius" use:

```sh
sgrep --all --hits -e render src/        # every matching line, grouped by ranked passage
sgrep --all --no-text -e render src/     # locations only
```

`--hits` replaces the passage text with the matching lines and their line numbers: the same lines `rg -S -n` lists
(checked), plus ranking and the enclosing function. `--all` lifts the cap on the lexical list only; the semantic list
keeps its `--limit`. Memory grows with the number of matches.

## What is searched

By default lexical search and the index cover markdown, text and code (Go, Rust, Python, JS, TS, Java, PHP, CSS, HTML, XML,
FreeMarker `.ftl`) and
honor `.gitignore` (so `node_modules/` stays out; `--no-ignore` includes ignored files, as does naming the directory).
Narrow with `-t rust|py|java|ts|js|go|php|css|html|xml|ftl|md|txt` (`sgrep --type-list`); other files (SCSS, JSP, logs)
need `-g '*.ext'`. Code is split into declarations, so a result is a whole function with `kind` and `symbol`; markup is
split by element (`bean cacheManager`, `section#help Help`, `dependency lib-cache`), and an inline `<script>` or
`<style>` is chunked as JavaScript or CSS.

## The index (semantic only)

- **It builds itself.** The first `--semantic` query in a directory builds the index (progress on stderr; the shared
  wrapper sets `SGREP_INDEX_IF_MISSING=1`). Roughly 30-120 chunks/s: a module of 1,400 files is 4-9 minutes. **Index a
  module or subfolder, never a monorepo root.** It refuses over 20,000 files, but a few thousand can still take 20
  minutes. If you run it in the background, read the progress. `sgrep --index DIR` builds one explicitly.
- **It does not update itself.** After edits run `sgrep --refresh [DIR]`: it compares file sizes and times (about
  0.1 s, no model) and says "up to date", or re-embeds only what changed, repeating the options the index was built
  with. Symptoms of a stale index: results dropped and counted as `semantic_stale`, or new files never found.
- **Where it lives.** In `.sgrep/` inside the indexed folder, or, where `SGREP_INDEX_HOME` is set (it is `/workspaces` in
  the container), under `<home>/.sgrep/<path>/` with nothing inside the repository. You never need the path: search,
  `--refresh` and `--doctor` find the nearest index. Git worktrees of one repo each get an index and share embeddings,
  so a new worktree indexes in seconds. Deleting an index folder is always safe.
- A missing index is never answered with a lexical search; semantic means semantic.

## Reading results

`--json` gives JSON Lines (a superset of `rg --json`): `start`, one `match` per passage, then `summary`.

```json
{"type":"match","data":{"path":{"text":"src/retry.rs"},"lines":{"text":"..passage text.."},
 "line_number":40,"end_line_number":71,"rank":1,"score":4.71,"source":"bm25","kind":"function","symbol":"backoff",
 "id":"src/retry.rs:40-71","hits":[{"line_number":52,"lines":{"text":"    sleep(backoff(n));"}}]}}
```

- `source` is `bm25` or `semantic`; `rank` restarts at 1 in each list. `lines.text` is the passage (absent with
  `--no-text` or `--hits`); `hits` appears only with `--hits`.
- `summary.stats` has `matches` returned and `passages_admitted` total; `summary.sources` counts each list and names
  the index (`semantic_stale` > 0 means refresh). An `error` event means something was skipped; read it.
- Without `--json` the output is human-readable and `[semantic]` tags the semantic list. Exit status: 0 results,
  1 none, 2 error.

## Tips

- Start with `--limit 5-10`; raise it, or use `--all --hits`, if the answer is not there.
- Narrow with paths, `-t` and `-g` rather than a long pattern.
- Do not add `.sgrep/` to ignore files; it ignores itself.

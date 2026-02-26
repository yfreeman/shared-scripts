---
name: worktree
description: Create and manage git worktrees with isolated WordPress environments (thin wrapper around npm scripts)
argument-hint: <create|list> [feature-name]
disable-model-invocation: true
allowed-tools: Bash
---

# Git Worktree Manager

Thin wrapper around automated npm worktree scripts.

## Usage

```bash
/worktree create <feature-name> [base-branch]
/worktree list
```

## Implementation

### Create
- Extracts feature name and optional base branch from arguments
- Runs: `npm run worktree:create <feature-name> [base-branch]`

### List
- Runs: `npm run worktree:list`

## Documentation

- **Help:** `npm run worktree:create` (shows usage and workflow)
- **Full docs:** See `WORKTREE.md` in project root
- **Troubleshooting:** All common issues documented in `WORKTREE.md`

## Other Commands

Run these directly (not through skill):
- `npm run worktree:start` - Start WordPress (from within worktree)
- `npm run worktree:stop` - Stop WordPress
- `npm run worktree:destroy` - Destroy WordPress environment

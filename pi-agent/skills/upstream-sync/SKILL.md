---
disable-model-invocation: true
name: upstream-sync
description: Safely sync a customized fork or long-lived local branch with an upstream remote while preserving local features. Use when the user asks to fetch upstream changes, merge/rebase upstream, resolve conflicts, validate, push, or establish a repeatable upstream-following workflow.
---

# Upstream Sync

Use this skill when maintaining a customized fork that should keep following an upstream repository.

The primary goal is to bring in upstream bug fixes and features while preserving the user's local custom work, producing a clean, validated integration branch or merge commit.

## Core Principles

- Treat the user's current branch as their product/integration branch unless they say otherwise.
- Prefer a dedicated sync branch over resolving upstream conflicts directly on `main`.
- Prefer merge over rebase for already-pushed or long-lived customized branches, unless the user explicitly asks for rebase.
- Preserve local custom features.
- Prefer upstream bug fixes, security fixes, compatibility fixes, and refactors that local code can adopt safely.
- Do not push to any remote unless the user explicitly asks.
- Do not run expensive or project-prohibited build commands. First read project instructions such as `AGENTS.md`, `CLAUDE.md`, `.pi/settings.json`, package scripts, or repo docs when relevant.
- Keep the working tree safe: inspect status before merging, and do not overwrite uncommitted user work without asking.

## Standard Workflow

### 1. Inspect current state

Run:

```bash
git status --short --branch
git remote -v
git branch -vv --all | sed -n '1,120p'
git log --oneline --decorate --graph --all --max-count=60
```

Check:

- current branch
- whether the worktree is clean
- `origin` and `upstream` remote URLs
- whether `upstream/main` exists
- local commits not in upstream
- upstream commits not in local branch

If there are uncommitted changes, ask the user whether to commit, stash, or stop unless the request explicitly covers handling them.

### 2. Fetch remotes

```bash
git fetch --all --prune
```

Then inspect divergence:

```bash
git rev-list --left-right --count upstream/main...HEAD
git log --oneline HEAD..upstream/main --max-count=40
git log --oneline upstream/main..HEAD --max-count=40
```

Interpret `git rev-list --left-right --count A...B` carefully:

- first number: commits reachable only from `A`
- second number: commits reachable only from `B`

### 3. Preview changed files and conflicts

Find the merge base:

```bash
base=$(git merge-base HEAD upstream/main)
git diff --name-status "$base"..upstream/main
git diff --name-status "$base"..HEAD
```

Optionally preview likely conflicts:

```bash
git merge-tree --write-tree --name-only HEAD upstream/main
```

Do not rely solely on the preview; the real merge is authoritative.

### 4. Create a sync branch

Use a dated branch name:

```bash
git switch <integration-branch>
git switch -c sync/upstream-YYYYMMDD
```

For most customized forks, merge upstream:

```bash
git merge --no-ff upstream/main
```

If Git reports conflicts, proceed to conflict resolution.

### 5. Resolve conflicts

For each conflict file:

1. Read the conflicted file and surrounding context.
2. Compare local and upstream versions when needed:

```bash
git show HEAD:path/to/file
git show upstream/main:path/to/file
```

3. Resolve with this policy:
   - Keep local custom UI/workflow/product features.
   - Keep upstream bug fixes and hardening.
   - Integrate both sides when they are complementary.
   - Remove duplicate logic introduced by combining both sides.
   - Remove all conflict markers.

4. Stage resolved files:

```bash
git add path/to/file
```

Confirm no markers remain:

```bash
grep -R "^<<<<<<<\|^=======\|^>>>>>>>" -n <resolved-files> || true
git diff --check
```

### 6. Validate

Prefer project-specific validation from docs or package scripts. Common checks:

```bash
node_modules/.bin/tsc --noEmit
npm run lint
```

Run relevant tests if present. For Node test files, one possible pattern is:

```bash
for f in lib/*.test.mjs; do node "$f" || exit $?; done
```

Do **not** run `next build`, deploy scripts, database migrations, destructive tests, or network-heavy/eval-heavy commands unless the project docs require it or the user explicitly asks.

### 7. Commit the merge

If merge conflicts were resolved and validation passes:

```bash
git status --short --branch
git commit --no-edit
```

If Git already created the merge commit automatically, do not create an extra commit unless needed.

### 8. Integrate back to the product branch

If the user asked to actually apply the sync to the main branch:

```bash
git switch <integration-branch>
git merge --ff-only sync/upstream-YYYYMMDD
```

If fast-forward fails, stop and explain why.

### 9. Push only when asked

If the user explicitly asks to push:

```bash
git push origin <integration-branch>
```

Never push to `upstream` unless the user explicitly asks and the remote is intended for contribution.

For safety, suggest disabling accidental pushes to upstream:

```bash
git remote set-url --push upstream DISABLED
```

### 10. Report results

Final report should include:

- branch used
- upstream commit or range integrated
- merge commit hash, if any
- conflicts resolved and notable decisions
- validation commands and pass/fail results
- current `git status --short --branch`
- whether push was performed or the exact push command to run

## Recommended Long-Term Workflow

For a customized fork:

```bash
git fetch upstream --prune
git switch main
git switch -c sync/upstream-YYYYMMDD
git merge --no-ff upstream/main
# resolve conflicts, validate
git switch main
git merge --ff-only sync/upstream-YYYYMMDD
git push origin main   # only when ready
```

For new local features:

- Create small feature branches.
- Merge them into the integration branch after validation.
- Keep local features modular to reduce future upstream conflicts.
- Enable rerere to reuse repeated conflict resolutions:

```bash
git config rerere.enabled true
git config rerere.autoupdate true
```

## Conflict Resolution Checklist

Before marking the task complete:

- [ ] No conflict markers remain.
- [ ] `git diff --check` passes.
- [ ] Typecheck passes or failures are explained.
- [ ] Lint passes or failures are explained.
- [ ] Relevant tests pass or failures are explained.
- [ ] Local custom features involved in conflicts are preserved.
- [ ] Upstream fixes involved in conflicts are preserved.
- [ ] Working tree status is reported.

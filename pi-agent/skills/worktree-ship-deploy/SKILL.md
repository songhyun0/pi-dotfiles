---
name: worktree-ship-deploy
description: Create a focused git worktree for implementation work, then after explicit user approval commit, push, redeploy the real served app/service, and verify deployment. Use when the user asks for a new worktree plus a later commit/push/redeploy flow, or says to clean up the workflow around that process.
license: Apache-2.0
---

# Worktree Ship Deploy

Use this skill for a two-phase local development flow:

1. Create a focused git worktree and implement the requested change there.
2. Only after the user explicitly asks, commit, push, redeploy the actual served app/service, and verify it is running the intended code.

This skill exists to avoid a common failure mode: building or deploying a feature worktree while the local service manager still serves another checkout.

## Golden Rules

- Do not commit, push, or redeploy merely because implementation is done. Wait for an explicit user request such as “커밋 푸시 재배포”, “ship it”, or “deploy”.
- Never stage unrelated working tree changes silently. Stage explicit files unless the user confirms the whole worktree scope.
- Before redeploying, prove which checkout the running service actually uses. A deploy from the wrong worktree does not count.
- If the served checkout differs from the feature worktree, stop and choose a safe strategy: merge/cherry-pick into the served checkout, switch the service config, or ask the user.
- Do not push a branch that contains unrelated pre-existing local commits without telling the user and getting confirmation.
- Keep concise evidence: branch, commit hash, pushed ref, deploy command, running process/config, and validation commands.

## Phase 1: Create the Implementation Worktree

### 1. Confirm the target repository

When the current directory is a meta repo, dotfiles repo, monorepo, or repo containing nested repos, identify the actual implementation repository before creating a worktree.

Run the equivalent of:

```bash
git rev-parse --show-toplevel
git status --short --branch
git worktree list
find . -maxdepth 3 -name package.json -o -name AGENTS.md -o -name README.md
```

If a likely app repo lives under `repos/<name>` or a nested path, inspect that repo too before acting.

### 2. Pick names

Use a short kebab-case slug from the feature, for example:

- Branch: `mobile-sidebar-swipe-delete` or `feature/mobile-sidebar-swipe-delete`, following existing repo convention.
- Worktree path: sibling worktrees directory, usually `<repo-root>-worktrees/<slug>`.

Avoid spaces, uppercase, and vague names like `test` or `changes`.

### 3. Create the worktree safely

Before adding:

```bash
git branch --list '*<slug>*'
git worktree list
ls -1 ../<repo-name>-worktrees 2>/dev/null || true
```

Create:

```bash
git worktree add -b <branch> ../<repo-name>-worktrees/<slug> HEAD
```

If you accidentally create a worktree in the wrong repo and it is clean/unused, remove it immediately and delete the mistaken branch:

```bash
git worktree remove <wrong-worktree-path>
git branch -D <wrong-branch>
```

### 4. Plan before editing

Read project instructions such as `AGENTS.md`, package scripts, and relevant source files. Produce a concrete plan including:

- files likely to change
- integration points
- risks/regressions
- validation commands
- deployment target assumptions to verify later

Use the `todo` tool for 3+ step work. Mark exactly one item `in_progress` at a time and complete items immediately when done.

## Phase 2: Implement in the Worktree

- Edit only intended files.
- Reuse existing API/client flows where possible.
- Run targeted validation before shipping, e.g. `node_modules/.bin/tsc --noEmit`, `npm run lint`, unit tests, or project-specific commands from docs.
- If dependencies are missing in a git worktree but the main checkout has `node_modules`, prefer a safe local symlink only when that is already the project’s convention; otherwise report the missing dependency.

## Phase 3: Commit and Push After User Approval

When the user explicitly asks to commit/push:

### 1. Inspect scope

```bash
git status --short --branch
git diff --stat
git diff --check
```

If unrelated changes exist, ask which files belong in the commit.

### 2. Validate before commit

Run the relevant checks from the implementation plan. If checks fail, stop unless the user explicitly asks to commit despite failures.

### 3. Stage explicit files and commit

```bash
git add <intended-file-1> <intended-file-2>
git diff --cached --stat
git diff --cached --check
git commit -m "<type>: <concise subject>"
```

Use conventional commit style, e.g. `feat: add mobile session swipe delete`.

### 4. Push the feature branch

```bash
git push -u origin "$(git branch --show-current)"
```

If the user asks for a PR, load and follow the `yeet` skill for draft PR creation/update. Do not open a PR by default when the user only asked to commit/push/redeploy.

## Phase 4: Redeploy the Actual Served App

### 1. Detect the serving target

Do not assume the feature worktree is served. Check service manager config, process args, and working directory.

Examples:

```bash
# macOS LaunchAgent examples
for f in "$HOME/Library/LaunchAgents"/*.plist; do
  plutil -p "$f" 2>/dev/null | grep -q '<app-or-port>' && echo "$f"
done
launchctl print gui/$(id -u)/<label> 2>&1 | sed -n '1,120p'
ps aux | grep -E '<app|next|node|server>' | grep -v grep
```

For `pi-web`, explicitly verify `com.agegr.pi-web` and its `WorkingDirectory`. A `deploy:local` run from a worktree does not change a LaunchAgent whose plist points at `repos/pi-web`.

### 2. If served checkout differs from the feature worktree

Choose one, with user-visible explanation:

- **Cherry-pick/merge into served checkout** when local deployment is intentionally served from main checkout.
- **Switch service WorkingDirectory** only if the user wants the service to run from the feature worktree.
- **Stop and ask** when pushing/deploying would include unrelated local commits or unclear state.

Before cherry-picking/merging into a served checkout:

```bash
git status --short --branch
git log --oneline origin/$(git branch --show-current)..$(git branch --show-current)
git cherry-pick <feature-commit>
```

Resolve conflicts carefully. Preserve served-checkout-only props/config such as `onRequestClose` or layout fixes.

Do not push the served branch if it has unrelated pre-existing ahead commits without explicit confirmation.

### 3. Run the deploy command from the served checkout

Prefer project scripts, e.g.:

```bash
npm run deploy:local
```

Respect project docs. For example, if docs say not to run `next build` during ordinary dev, only run a build when the user explicitly requested redeploy and the deploy script requires it.

### 4. Verify deployment

Collect evidence:

```bash
git log -1 --oneline
ls -l .next/BUILD_ID 2>/dev/null || true
launchctl print gui/$(id -u)/<label> 2>&1 | sed -n '1,120p'
ps aux | grep -E '<app|next|node|server>' | grep -v grep
curl -I http://<host>:<port> 2>/dev/null | head
```

If logs show transient `EADDRINUSE` during restart but a new process is running and the app reports ready, mention that warning and the final running PID.

For mobile UI fixes, remind the user to hard refresh/close-reopen the iPhone browser or clear the PWA/browser cache if stale JS may be cached.

## Phase 5: Workflow and Session Cleanup

At the end:

- Mark all `todo` items completed or explain any blocker.
- Summarize any workflow/subagent findings used; do not leave stale analysis-workflow tasks in progress.
- If the workflow task panel still shows a completed/paused run, use `/workflows list` to get the run id and `/workflows rm <runId>` to remove it. If slash commands are not available, delete that run's `.json`, `.json.bak`, `.json.tmp`, `.lock`, and `.log` files from the relevant `~/.pi/workflows/projects/<project-key>/runs/` directory only after confirming the run is not active.
- Remove mistaken clean worktrees created in the wrong repo.
- Keep the feature worktree unless the user asks to remove it.
- Report:
  - feature branch and commit hash
  - pushed remote ref
  - served checkout branch and commit hash
  - deploy command and verification evidence
  - workflow runs cleaned up, if any
  - any branch that is ahead of remote but intentionally not pushed
See [references/workflow.md](references/workflow.md) for a compact checklist.
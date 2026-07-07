# Worktree Ship Deploy Checklist

Use this checklist when running the `worktree-ship-deploy` skill.

## A. Setup / Worktree

- [ ] Confirm actual implementation repo, not just current shell cwd.
- [ ] Inspect `git status --short --branch` and `git worktree list`.
- [ ] Choose slug and branch name.
- [ ] Create worktree under sibling `<repo>-worktrees/<slug>`.
- [ ] Remove any mistaken clean worktree/branch created in the wrong repo.
- [ ] Read project instructions (`AGENTS.md`, package scripts, docs).
- [ ] Draft implementation plan with files, risks, checks, and deploy assumptions.

## B. Implementation

- [ ] Edit only intended files.
- [ ] Reuse existing flows where possible.
- [ ] Run targeted validation.
- [ ] Keep todo state current.

## C. Commit / Push (only after explicit user request)

- [ ] `git status --short --branch`
- [ ] `git diff --stat`
- [ ] `git diff --check`
- [ ] Validate again if needed.
- [ ] Stage explicit files only.
- [ ] `git diff --cached --stat`
- [ ] `git diff --cached --check`
- [ ] Commit with conventional message.
- [ ] Push branch with upstream.
- [ ] Create/update PR only if requested.

## D. Redeploy

- [ ] Identify actual served checkout from process/service config.
- [ ] Compare served checkout with feature worktree.
- [ ] If different, safely merge/cherry-pick or ask before changing service config.
- [ ] Do not push a served branch containing unrelated ahead commits without confirmation.
- [ ] Run deploy command from actual served checkout.
- [ ] Verify process restarted and app is ready.
- [ ] For mobile/browser UI, advise hard refresh or browser/PWA restart.

## E. Workflow Cleanup

- [ ] Complete or explain all `todo` tasks.
- [ ] Run `/workflows list` if the workflow task panel still shows stale runs.
- [ ] Remove stale completed/paused workflow runs with `/workflows rm <runId>`.
- [ ] If slash commands are unavailable, remove only the confirmed inactive run sidecars under `~/.pi/workflows/projects/<project-key>/runs/`.

## F. Final Report

Include:

- Worktree path
- Feature branch
- Feature commit hash/title
- Pushed remote ref
- Served checkout path
- Served commit hash/title
- Deploy command
- Verification commands/results
- Workflow runs cleaned up, if any
- Unpushed commits or intentional non-actions
- Any cleanup performed

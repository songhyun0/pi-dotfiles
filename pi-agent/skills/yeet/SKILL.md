---
name: yeet
description: "Safely publish local git changes to GitHub using the GitHub CLI: confirm scope, create or reuse a branch, stage intended changes, commit, push, and open or update a draft pull request. Use only when explicitly invoked or when the user explicitly asks for the full commit-push-PR flow."
license: Apache-2.0
---

# Yeet: Publish Local Changes to GitHub

Pi-port of the Codex GitHub `yeet` skill. This version assumes **local `git` + GitHub CLI (`gh`) only**. Do not assume a Codex GitHub App connector, GitHub MCP server, or OMP `github` tool is available.

Use this skill only for the full publish flow from a local checkout: branch setup when needed, staging, commit, validation, push, and opening or updating a GitHub pull request.

## Prerequisites

Before changing anything, verify:

```bash
gh --version
gh auth status
git rev-parse --show-toplevel
git status --short --branch
git remote -v
```

Stop and report a blocker if:

- `gh` is missing.
- `gh auth status` is not authenticated for the target GitHub host.
- The current directory is not inside a git repository.
- The repository does not have an accessible GitHub remote.
- The intended scope of changes is ambiguous.

## Safety Rules

- Never stage unrelated user changes silently.
- Never use `git add -A` unless the user has confirmed that the whole worktree belongs in this PR.
- Prefer explicit file paths when the worktree is mixed.
- Never push without confirming scope when unrelated changes may exist.
- Default to a **draft PR** unless the user explicitly asks for ready-for-review.
- If an existing PR already exists for the current branch, update it in place; do not create a duplicate PR.
- Preserve the existing PR draft/ready state when updating an existing PR.
- Avoid absolute local paths in commit messages or PR bodies; use repo-relative paths.
- Do not include secrets, local credentials, session files, auth files, or runtime state.

## Naming Conventions

Let the user override any naming choice. Otherwise:

- Branch from default branch: `pi/{short-description}`.
- Commit title: conventional-commit style, e.g. `feat: add hat wobble`.
- PR title: same style as the commit title, summarizing the net diff.

Good PR title types:

- `feat`: user-facing feature
- `fix`: user-facing bug fix
- `docs`: documentation-only change
- `style`: formatting-only change
- `refactor`: production-code refactor without behavior change
- `test`: test-only change
- `chore`: maintenance/tooling change

## Workflow

### 1. Confirm intended scope

Inspect status and diff before staging:

```bash
git status --short --branch
git diff --stat
git diff -- . ':!package-lock.json' ':!pnpm-lock.yaml' ':!bun.lockb'
```

Adjust the diff command for the repository. If the worktree contains unrelated changes, ask which files belong in this PR before staging.

### 2. Determine branch strategy

Find the current branch and default branch:

```bash
current_branch="$(git branch --show-current)"
default_branch="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')"
```

If on `main`, `master`, or the remote default branch, create a focused branch:

```bash
git switch -c "pi/{short-description}"
```

Otherwise stay on the current branch unless the user asks for a new one.

### 3. Stage only intended changes

Use explicit paths when scope is mixed:

```bash
git add path/to/file another/path
```

Use all-files staging only after confirmation:

```bash
git add -A
```

Then review staged changes:

```bash
git diff --cached --stat
git diff --cached --check
```

### 4. Commit tersely

Use a focused message that reflects the staged net change:

```bash
git commit -m "<type>(<scope>): <subject>"
```

If there is nothing staged, stop and report that no commit was created.

### 5. Validate

Run the most relevant checks that are already available from project docs or package scripts. Prefer quick targeted checks over expensive broad checks unless the repository requires them.

If checks fail because dependencies or tools are missing, install what is needed only when appropriate for the project and rerun once. If checks still fail, stop unless the user explicitly asks to publish despite failures.

### 6. Push with tracking

```bash
branch="$(git branch --show-current)"
git push -u origin "$branch"
```

If push fails due to auth, permissions, branch protection, or missing remote, stop and explain the blocker.

### 7. Discover PR template

Resolve the repository root:

```bash
repo_root="$(git rev-parse --show-toplevel)"
```

Template candidates, in order:

- `.github/pull_request_template.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- exactly one `*.md` under `.github/pull_request_template/`
- exactly one `*.md` under `.github/PULL_REQUEST_TEMPLATE/`

If exactly one template is found, read it before composing the PR body and pass it to `gh pr create` with `--template "$template"` when creating a new PR.

If multiple template files are found, ask which template to use before PR creation. If no template exists, use the fallback body shape below.

### 8. Open or update the PR

Check whether the current branch already has a PR:

```bash
branch="$(git branch --show-current)"
gh pr view "$branch" --json number,isDraft,url,title,body
```

If a PR exists:

- Update the PR title/body to match the net change when needed.
- Preserve meaningful existing body content such as screenshots, links, or reviewer-provided context.
- Do not change draft/ready state unless the user explicitly asks.

If no PR exists, create a new draft PR:

```bash
GH_PROMPT_DISABLED=1 GIT_TERMINAL_PROMPT=0 gh pr create --draft --fill --head "$branch"
```

With one template:

```bash
GH_PROMPT_DISABLED=1 GIT_TERMINAL_PROMPT=0 gh pr create --draft --fill --template "$template" --head "$branch"
```

For carefully formatted bodies, write Markdown to a temp file with real newlines and use `--body-file` or `gh pr edit --body-file`.

## PR Body Guidance

When composing or editing the PR body:

- Explain **why** the change is being made before explaining what changed.
- Limit discussion to the **net change** in the final diff; omit attempts that were later reverted.
- Preserve repository template headings, required checklists, and prompts.
- Replace placeholder text with change-specific content or `N/A` where appropriate.
- Use professional Markdown.
- Put code, paths, commands, flags, and identifiers in backticks.
- Use GitHub permalinks when citing existing code relevant to the change.
- Reference relevant issues or related PRs, but do not reference the PR in its own body.

Default fallback body when there is no repository template:

```markdown
## Why

Describe the user-facing or maintainer-facing problem, including cause and effect where useful.

## What Changed

Describe the net implementation change in concise prose.
```

Add `Verification` only when there is evidence worth preserving for reviewers: a reproduced bug, a before/after check, a targeted test that exercises changed behavior, or a manual scenario with input and observed outcome. Do not add generic filler.

## Final Response

Summarize:

- branch name
- commit hash and title
- PR URL and draft/ready state
- validation commands and results
- any skipped checks or remaining user action

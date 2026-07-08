# pi-dotfiles

Personal Pi agent dotfiles and `pi-web` installer.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/songhyun0/pi-dotfiles/main/install.sh | bash
```

Local checkout install:

```bash
bash install.sh
```

## What this manages

Symlinked into `~/.pi/agent`:

- `settings.json`
- `keybindings.json`
- `skills/`
- `extensions/`
- `prompts/`
- `themes/`

`rpiv-mono` is installed as a separate local git checkout that tracks upstream `main`, because `pi-agent/settings.json` points `rpiv-todo` at this checkout until the npm package release catches up:

- repo: `https://github.com/juicesharp/rpiv-mono.git`
- default dir: `repos/rpiv-mono` inside this dotfiles checkout (ignored by git)
- Pi package path: `<pi-dotfiles>/repos/rpiv-mono/packages/rpiv-todo`

`pi-web` is also installed as a separate local git checkout that tracks `main`:

- repo: `https://github.com/songhyun0/pi-web.git`
- default dir: `repos/pi-web` inside this dotfiles checkout (ignored by git)
- command symlink: `~/.pi/agent/bin/pi-web -> <pi-dotfiles>/repos/pi-web/bin/pi-web.js` by default
- this keeps Pi agent config and the editable pi-web checkout under one `pi-dotfiles` directory while still letting `pi-web` remain its own git repo.
- this works with the current PATH because `~/.pi/agent/bin` is already before Homebrew paths.

## Security policy

This repo must not contain Pi auth/session/runtime data.

Never commit:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/mcp-oauth/`
- `~/.pi/agent/sessions/`
- `~/.pi/agent/state/`
- `~/.pi/agent/tmp/`
- `~/.pi/agent/run-history.jsonl`
- `~/.pi/agent/npm/`
- `~/.pi/agent/git/`

The installer backs up existing managed files/directories as `*.backup.YYYYMMDDHHMMSS` before replacing them with symlinks.

## Local edit workflow

Pi agent resources:

```bash
cd ~/.local/share/pi-dotfiles   # or the checkout you installed from
$EDITOR pi-agent/skills/upstream-sync/SKILL.md
# In running pi: /reload, or restart pi
```

`rpiv-todo` from upstream `rpiv-mono`:

```bash
cd ~/.local/share/pi-dotfiles/repos/rpiv-mono  # or <your checkout>/repos/rpiv-mono
git pull --ff-only
npx vitest run packages/rpiv-todo
```

`pi-web`:

```bash
cd ~/.local/share/pi-dotfiles/repos/pi-web  # or <your checkout>/repos/pi-web
$EDITOR ...
npm run build
pi-web
```

## Update

```bash
cd ~/.local/share/pi-dotfiles
git pull --ff-only
./install.sh
```

Update only symlinks:

```bash
./scripts/relink.sh
```

Update only `rpiv-mono` / local `rpiv-todo`:

```bash
./scripts/update-rpiv-mono.sh
```

Update/rebuild only `pi-web`:

```bash
./scripts/update-pi-web.sh
```

## Environment variables

- `DOTFILES_DIR`: local dotfiles checkout path. Defaults to the current checkout when running `install.sh` locally, otherwise `~/.local/share/pi-dotfiles`.
- `DOTFILES_REPO`: clone source for curl installs. Defaults to `https://github.com/songhyun0/pi-dotfiles.git`.
- `PI_CODING_AGENT_DIR`: Pi config dir. Defaults to `~/.pi/agent`.
- `INSTALL_PI_CLI=0`: skip global Pi CLI install.
- `INSTALL_PI_PACKAGES=0`: skip `pi install` for packages in `settings.json`.
- `INSTALL_RPIV_MONO=0`: skip `rpiv-mono` clone/update/dependency install for the local `rpiv-todo` package path.
- `INSTALL_PI_WEB=0`: skip `pi-web` clone/build/link.
- `PI_WEB_SOURCE`: pi-web git source. Defaults to `https://github.com/songhyun0/pi-web.git`.
- `PI_WEB_DIR`: pi-web checkout path. Defaults to `<DOTFILES_DIR>/repos/pi-web`.
- `PI_WEB_BIN_DIR`: symlink dir for `pi-web`. Defaults to `${PI_CODING_AGENT_DIR:-~/.pi/agent}/bin`.
- `PI_WEB_BUILD=0`: skip `npm ci --include=dev && npm run build` in `update-pi-web.sh`.
- `RPIV_MONO_SOURCE`: rpiv-mono git source. Defaults to `https://github.com/juicesharp/rpiv-mono.git`.
- `RPIV_MONO_REF`: rpiv-mono ref to check out. Defaults to `main`.
- `RPIV_MONO_DIR`: rpiv-mono checkout path. Defaults to `<DOTFILES_DIR>/repos/rpiv-mono`.
- `RPIV_MONO_INSTALL=0`: skip `npm install --include=dev --ignore-scripts` in `update-rpiv-mono.sh`.

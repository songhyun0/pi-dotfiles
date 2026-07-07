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

`pi-web` is installed as a separate local git checkout that tracks `main`:

- repo: `https://github.com/songhyun0/pi-web.git`
- default dir: `~/.local/share/pi-web`
- command symlink: `~/.pi/agent/bin/pi-web -> ~/.local/share/pi-web/bin/pi-web.js` by default
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

`pi-web`:

```bash
cd ~/.local/share/pi-web
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
- `INSTALL_PI_WEB=0`: skip `pi-web` clone/build/link.
- `PI_WEB_SOURCE`: pi-web git source. Defaults to `https://github.com/songhyun0/pi-web.git`.
- `PI_WEB_DIR`: pi-web checkout path. Defaults to `~/.local/share/pi-web`.
- `PI_WEB_BIN_DIR`: symlink dir for `pi-web`. Defaults to `${PI_CODING_AGENT_DIR:-~/.pi/agent}/bin`.
- `PI_WEB_BUILD=0`: skip `npm ci --include=dev && npm run build` in `update-pi-web.sh`.

#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/songhyun0/pi-dotfiles.git}"
INSTALL_PI_CLI="${INSTALL_PI_CLI:-1}"
INSTALL_PI_PACKAGES="${INSTALL_PI_PACKAGES:-1}"
INSTALL_PI_WEB="${INSTALL_PI_WEB:-1}"
INSTALL_RPIV_MONO="${INSTALL_RPIV_MONO:-1}"

log() { printf '[pi-dotfiles] %s\n' "$*"; }
fail() { printf '[pi-dotfiles] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

need_cmd git
need_cmd node
need_cmd npm

# If this script is run from a checked-out pi-dotfiles repo, use that checkout as
# the live dotfiles directory so edits are immediately reflected through symlinks.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fi

if [ -z "${DOTFILES_DIR:-}" ]; then
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/pi-agent/settings.json" ]; then
    DOTFILES_DIR="$SCRIPT_DIR"
  else
    DOTFILES_DIR="$HOME/.local/share/pi-dotfiles"
  fi
fi

PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

case "$PI_DIR" in
  "/"|"$HOME"|"$HOME/"|"$DOTFILES_DIR"|"$DOTFILES_DIR/")
    fail "Refusing unsafe PI_CODING_AGENT_DIR: $PI_DIR"
    ;;
esac

if [ -d "$DOTFILES_DIR/.git" ]; then
  log "Using dotfiles repo: $DOTFILES_DIR"
  # Only auto-pull managed clone locations. If running from an arbitrary local
  # checkout, avoid surprising the user by pulling over local work.
  if [ "$DOTFILES_DIR" != "$SCRIPT_DIR" ]; then
    git -C "$DOTFILES_DIR" checkout main
    git -C "$DOTFILES_DIR" pull --ff-only
  fi
elif [ -e "$DOTFILES_DIR" ]; then
  fail "$DOTFILES_DIR exists but is not a git repo. Move it aside or set DOTFILES_DIR."
else
  log "Cloning $DOTFILES_REPO -> $DOTFILES_DIR"
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  git -C "$DOTFILES_DIR" checkout main
fi

[ -f "$DOTFILES_DIR/pi-agent/settings.json" ] || fail "Missing $DOTFILES_DIR/pi-agent/settings.json"

if [ "$INSTALL_PI_CLI" = "1" ]; then
  log "Installing/updating pi CLI"
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
else
  log "Skipping pi CLI install because INSTALL_PI_CLI=$INSTALL_PI_CLI"
fi

mkdir -p "$PI_DIR"

backup_path() {
  local dst="$1"
  local backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
  mv "$dst" "$backup"
  log "Backed up $dst -> $backup"
}

link_managed() {
  local src="$1"
  local dst="$2"
  [ -e "$src" ] || fail "Missing source for symlink: $src"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
    ln -s "$src" "$dst"
    log "Relinked $dst -> $src"
  elif [ -e "$dst" ]; then
    backup_path "$dst"
    ln -s "$src" "$dst"
    log "Linked $dst -> $src"
  else
    ln -s "$src" "$dst"
    log "Linked $dst -> $src"
  fi
}

log "Linking Pi agent files into $PI_DIR"
link_managed "$DOTFILES_DIR/pi-agent/settings.json" "$PI_DIR/settings.json"
link_managed "$DOTFILES_DIR/pi-agent/skills" "$PI_DIR/skills"
link_managed "$DOTFILES_DIR/pi-agent/extensions" "$PI_DIR/extensions"
link_managed "$DOTFILES_DIR/pi-agent/prompts" "$PI_DIR/prompts"
link_managed "$DOTFILES_DIR/pi-agent/themes" "$PI_DIR/themes"
if [ -f "$DOTFILES_DIR/pi-agent/keybindings.json" ]; then
  link_managed "$DOTFILES_DIR/pi-agent/keybindings.json" "$PI_DIR/keybindings.json"
fi

if [ "$INSTALL_RPIV_MONO" = "1" ]; then
  log "Installing/updating rpiv-mono for local rpiv-todo"
  DOTFILES_DIR="$DOTFILES_DIR" bash "$DOTFILES_DIR/scripts/update-rpiv-mono.sh"
else
  log "Skipping rpiv-mono install because INSTALL_RPIV_MONO=$INSTALL_RPIV_MONO"
fi

if [ "$INSTALL_PI_PACKAGES" = "1" ]; then
  log "Installing Pi packages from pi-agent/settings.json"
  PI_CODING_AGENT_DIR="$PI_DIR" node - "$DOTFILES_DIR/pi-agent/settings.json" <<'NODE'
const { existsSync, readFileSync } = require('node:fs');
const { execFileSync } = require('node:child_process');
const { dirname, isAbsolute, resolve } = require('node:path');
const { fileURLToPath } = require('node:url');
const settingsPath = process.argv[2];
const settings = JSON.parse(readFileSync(settingsPath, 'utf8'));
const agentDir = process.env.PI_CODING_AGENT_DIR ?? dirname(settingsPath);
const homeDir = process.env.HOME ?? '';

function isManagedPackageSource(spec) {
  return /^(npm:|git:|github:|https?:|ssh:)/.test(spec.trim());
}

function resolveLocalPackageSpec(spec) {
  const trimmed = spec.trim();
  const expanded = trimmed.startsWith('file://')
    ? fileURLToPath(trimmed)
    : trimmed === '~'
      ? homeDir
      : trimmed.startsWith('~/')
        ? resolve(homeDir, trimmed.slice(2))
        : trimmed;
  return isAbsolute(expanded) ? resolve(expanded) : resolve(agentDir, expanded);
}

for (const entry of settings.packages ?? []) {
  const spec = typeof entry === 'string' ? entry : entry?.source;
  if (typeof spec !== 'string' || spec.trim() === '') {
    throw new Error(`Invalid Pi package entry in ${settingsPath}: ${JSON.stringify(entry)}`);
  }

  if (isManagedPackageSource(spec)) {
    console.log(`[pi-dotfiles] pi install ${spec}`);
    execFileSync('pi', ['install', spec], {
      stdio: 'inherit',
      env: { ...process.env, PI_CODING_AGENT_DIR: process.env.PI_CODING_AGENT_DIR },
    });
    continue;
  }

  const resolved = resolveLocalPackageSpec(spec);
  if (!existsSync(resolved)) {
    throw new Error(`Local Pi package path does not exist: ${spec} -> ${resolved}`);
  }
  console.log(`[pi-dotfiles] local Pi package ${spec} -> ${resolved}`);
}
NODE
else
  log "Skipping Pi package install because INSTALL_PI_PACKAGES=$INSTALL_PI_PACKAGES"
fi

if [ "$INSTALL_PI_WEB" = "1" ]; then
  log "Installing/updating pi-web"
  bash "$DOTFILES_DIR/scripts/update-pi-web.sh"
else
  log "Skipping pi-web install because INSTALL_PI_WEB=$INSTALL_PI_WEB"
fi

log "Done. Restart pi or run /reload in an existing session."

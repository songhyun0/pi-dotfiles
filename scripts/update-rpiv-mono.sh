#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"

RPIV_MONO_SOURCE="${RPIV_MONO_SOURCE:-https://github.com/juicesharp/rpiv-mono.git}"
RPIV_MONO_REF="${RPIV_MONO_REF:-main}"
RPIV_MONO_DIR="${RPIV_MONO_DIR:-$DOTFILES_DIR/repos/rpiv-mono}"
RPIV_MONO_INSTALL="${RPIV_MONO_INSTALL:-1}"

log() { printf '[rpiv-mono] %s\n' "$*"; }
fail() { printf '[rpiv-mono] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

need_cmd git
need_cmd node
need_cmd npm

mkdir -p "$(dirname "$RPIV_MONO_DIR")"

if [ -d "$RPIV_MONO_DIR/.git" ]; then
  log "Updating existing repo: $RPIV_MONO_DIR"
  current_url="$(git -C "$RPIV_MONO_DIR" remote get-url origin 2>/dev/null || true)"
  if [ -n "$current_url" ] && [ "$current_url" != "$RPIV_MONO_SOURCE" ]; then
    log "Repointing origin from $current_url to $RPIV_MONO_SOURCE"
    git -C "$RPIV_MONO_DIR" remote set-url origin "$RPIV_MONO_SOURCE"
  fi
  git -C "$RPIV_MONO_DIR" fetch origin "$RPIV_MONO_REF" --prune
  git -C "$RPIV_MONO_DIR" checkout "$RPIV_MONO_REF"
  git -C "$RPIV_MONO_DIR" pull --ff-only origin "$RPIV_MONO_REF"
elif [ -e "$RPIV_MONO_DIR" ]; then
  fail "$RPIV_MONO_DIR exists but is not a git repo. Move it aside or set RPIV_MONO_DIR."
else
  log "Cloning $RPIV_MONO_SOURCE -> $RPIV_MONO_DIR"
  git clone "$RPIV_MONO_SOURCE" "$RPIV_MONO_DIR"
  git -C "$RPIV_MONO_DIR" checkout "$RPIV_MONO_REF"
fi

if [ "$RPIV_MONO_INSTALL" = "1" ]; then
  log "Installing rpiv-mono workspace dependencies"
  npm --prefix "$RPIV_MONO_DIR" install --include=dev --ignore-scripts
else
  log "Skipping dependency install because RPIV_MONO_INSTALL=$RPIV_MONO_INSTALL"
fi

[ -f "$RPIV_MONO_DIR/packages/rpiv-todo/index.ts" ] || fail "Missing rpiv-todo extension at $RPIV_MONO_DIR/packages/rpiv-todo/index.ts"
log "rpiv-todo ready at $RPIV_MONO_DIR/packages/rpiv-todo"

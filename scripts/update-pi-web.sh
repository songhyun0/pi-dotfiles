#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"

PI_WEB_SOURCE="${PI_WEB_SOURCE:-https://github.com/songhyun0/pi-web.git}"
PI_WEB_DIR="${PI_WEB_DIR:-$DOTFILES_DIR/repos/pi-web}"
PI_WEB_BIN_DIR="${PI_WEB_BIN_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/bin}"
PI_WEB_BUILD="${PI_WEB_BUILD:-1}"

log() { printf '[pi-web] %s\n' "$*"; }
fail() { printf '[pi-web] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

need_cmd git
need_cmd node
need_cmd npm

mkdir -p "$(dirname "$PI_WEB_DIR")" "$PI_WEB_BIN_DIR"

if [ -d "$PI_WEB_DIR/.git" ]; then
  log "Updating existing repo: $PI_WEB_DIR"
  git -C "$PI_WEB_DIR" checkout main
  git -C "$PI_WEB_DIR" pull --ff-only
elif [ -e "$PI_WEB_DIR" ]; then
  fail "$PI_WEB_DIR exists but is not a git repo. Move it aside or set PI_WEB_DIR."
else
  log "Cloning $PI_WEB_SOURCE -> $PI_WEB_DIR"
  git clone "$PI_WEB_SOURCE" "$PI_WEB_DIR"
  git -C "$PI_WEB_DIR" checkout main
fi

if [ "$PI_WEB_BUILD" = "1" ]; then
  log "Installing dependencies (including dev dependencies required by Next.js build)"
  npm --prefix "$PI_WEB_DIR" ci --include=dev
  log "Building pi-web"
  npm --prefix "$PI_WEB_DIR" run build
else
  log "Skipping build because PI_WEB_BUILD=$PI_WEB_BUILD"
fi

chmod +x "$PI_WEB_DIR/bin/pi-web.js"
ln -sfn "$PI_WEB_DIR/bin/pi-web.js" "$PI_WEB_BIN_DIR/pi-web"
log "Linked $PI_WEB_BIN_DIR/pi-web -> $PI_WEB_DIR/bin/pi-web.js"

resolved_pi_web="$(command -v pi-web 2>/dev/null || true)"
case ":$PATH:" in
  *":$PI_WEB_BIN_DIR:"*)
    if [ -n "$resolved_pi_web" ] && [ "$resolved_pi_web" != "$PI_WEB_BIN_DIR/pi-web" ]; then
      log "Current PATH resolves pi-web to $resolved_pi_web. Put $PI_WEB_BIN_DIR earlier in PATH to use this clone by default."
    fi
    ;;
  *)
    log "Add $PI_WEB_BIN_DIR to PATH if 'pi-web' is not found in new shells."
    ;;
esac

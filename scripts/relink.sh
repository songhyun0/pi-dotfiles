#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DOTFILES_DIR="$SCRIPT_DIR" INSTALL_PI_CLI=0 INSTALL_PI_PACKAGES=0 INSTALL_PI_WEB=0 bash "$SCRIPT_DIR/install.sh"

#!/usr/bin/env bash
#
# fish as the login shell on a terminal-only machine, which WSL starts
# straight into. The desktop's login shell is left as it is.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

FISH=/usr/bin/fish

has_flag WITH_DESKTOP && exit 0

user="$(id -un)"
# Only when it isn't fish already, so a re-run changes nothing.
if is_dry_run || [[ $(getent passwd "$user" | cut -d: -f7) != "$FISH" ]]; then
  log_info "Making fish the login shell"
  run sudo usermod --shell "$FISH" "$user"
fi

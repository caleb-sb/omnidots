#!/usr/bin/env bash
#
# Developer toolchains that install into the home directory from upstream:
# Rust via rustup, pnpm and the Node it manages, bun and Claude Code. Go comes
# from the core list. Each is skipped when it's already there.
#
# The installers edit shell startup files for $SHELL. They run with
# SHELL=/bin/bash so those edits land in ~/.bashrc, never in the fish config
# this repo links, which sets up these paths itself.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
# Where pnpm installs itself (bin/) and links the Node it manages (the top
# level). pnpm refuses global installs unless that is on PATH.
export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
# So a tool installed earlier in this run is found by the next check and step.
export PATH="$HOME/.local/bin:$PNPM_HOME/bin:$PNPM_HOME:$HOME/.bun/bin:$CARGO_BIN:$PATH"

# missing <command> — true in dry-run, so the plan doesn't depend on the host.
missing() { is_dry_run || ! command -v "$1" >/dev/null; }

# run_installer <url> <shell...> — run an upstream install script as this
# user. The script is downloaded in full before it runs, so a dropped
# connection can't run half of it.
run_installer() {
  local url="$1"
  shift
  if is_dry_run; then
    plan run "curl -fsSL $url | $*"
    return
  fi
  local script
  script="$(curl -fsSL "$url")"
  SHELL=/bin/bash "$@" <<<"$script"
}

log_info "Installing developer toolchains"

# Fedora's rustup package only ships rustup-init; this puts rustup and the
# stable toolchain in ~/.cargo. config/fish/conf.d/cargo.fish adds its PATH.
if is_dry_run || [[ ! -x $CARGO_BIN/rustup ]]; then
  run rustup-init -y --no-modify-path
fi

if missing pnpm; then
  run_installer https://get.pnpm.io/install.sh sh -
fi
# pnpm's replacement for the deprecated `pnpm env use --global lts`.
if missing node; then
  run pnpm runtime set node lts -g
fi

if missing bun; then
  run_installer https://bun.sh/install bash
fi

if missing claude; then
  run_installer https://claude.ai/install.sh bash
fi

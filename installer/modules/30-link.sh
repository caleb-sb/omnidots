#!/usr/bin/env bash
#
# Symlinks each entry of config/ into the XDG config dir, each desktop entry
# in applications/ into the XDG applications dir, and each systemd user unit
# in systemd/ into the user unit dir. A terminal-only machine gets just the
# configs in TERMINAL_CONFIGS. Safe to re-run, and runnable on its own to
# re-link an existing machine:
#
#   installer/modules/30-link.sh

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

CONFIG_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}"
APPLICATIONS_TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
# The units one by one, not the whole dir, so `systemctl --user enable` doesn't
# write into the repo.
SYSTEMD_TARGET="$CONFIG_TARGET/systemd/user"

# The entries of config/ a terminal-only machine uses.
TERMINAL_CONFIGS=(fish git nvim starship.toml tmux)

# link_into <dir> <source...> — symlink each source into dir under its own name.
link_into() {
  local dir="$1" source target backup
  shift
  run mkdir -p "$dir"
  for source in "$@"; do
    target="$dir/${source##*/}"
    [[ $(readlink "$target") == "$source" ]] && continue
    if [[ -e $target && ! -L $target ]]; then
      backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
      act backup "$target -> $backup" mv "$target" "$backup"
    fi
    # -n replaces a link to a directory instead of linking inside it.
    act link "$target -> $source" ln -sfn "$source" "$target"
  done
}

log_info "Linking dotfiles"

if has_flag WITH_DESKTOP; then
  link_into "$CONFIG_TARGET" "$OMNIDOTS_ROOT"/config/*
  link_into "$APPLICATIONS_TARGET" "$OMNIDOTS_ROOT"/applications/*.desktop
  link_into "$SYSTEMD_TARGET" "$OMNIDOTS_ROOT"/systemd/*
else
  link_into "$CONFIG_TARGET" "${TERMINAL_CONFIGS[@]/#/$OMNIDOTS_ROOT/config/}"
fi

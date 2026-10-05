#!/usr/bin/env bash
#
# Under WSL, the Alacritty config for Windows: config/alacritty/alacritty.toml
# plus a [terminal.shell] that starts this distro in fish at home, written to
# %APPDATA%\alacritty\alacritty.toml. It's a copy, because Windows Alacritty
# can't follow a link into WSL, so update.sh runs this again to carry changes
# across. An alacritty.toml there that this didn't write is backed up first.
# Outside WSL it does nothing.
#
# Input, overridable so tests don't need Windows:
#   OMNIDOTS_APPDATA  Windows' %APPDATA%, as a WSL path (default: asks cmd.exe)

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

is_wsl || exit 0

SOURCE="$OMNIDOTS_ROOT/config/alacritty/alacritty.toml"
# The first line of every copy this writes, which marks it as ours.
MARKER="# Written by omnidots from config/alacritty/alacritty.toml; edit that, then run update.sh."

# windows_appdata — %APPDATA% as a WSL path, e.g. /mnt/c/Users/me/AppData/Roaming.
windows_appdata() {
  if [[ -n ${OMNIDOTS_APPDATA:-} ]]; then
    printf '%s\n' "$OMNIDOTS_APPDATA"
    return
  fi
  local cmd=cmd.exe appdata
  command -v "$cmd" >/dev/null || cmd=/mnt/c/Windows/System32/cmd.exe
  # cmd.exe warns on stderr that it can't start in a WSL directory.
  appdata="$("$cmd" /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')" || appdata=
  [[ -n $appdata && $appdata != *%* ]] || die "Couldn't find Windows' %APPDATA% through cmd.exe."
  wslpath -u "$appdata"
}

# windows_config — the copy for Windows, on stdout.
windows_config() {
  printf '%s\n\n' "$MARKER"
  cat "$SOURCE"
  printf '\n[terminal.shell]\nprogram = "wsl.exe"\nargs = ["--distribution", "%s", "--cd", "~"]\n' \
    "$WSL_DISTRO_NAME"
}

dest="$(windows_appdata)/alacritty/alacritty.toml"

log_info "Writing the Alacritty config for Windows"

# Unchanged since the last run: nothing to do.
if ! is_dry_run && cmp -s <(windows_config) "$dest"; then
  exit 0
fi
if [[ -e $dest ]] && [[ $(head -n 1 "$dest") != "$MARKER" ]]; then
  backup="$dest.bak.$(date +%Y%m%d-%H%M%S)"
  act backup "$dest -> $backup" mv "$dest" "$backup"
fi
if is_dry_run; then
  plan deploy "$SOURCE + shell wsl.exe --distribution $WSL_DISTRO_NAME -> $dest"
else
  mkdir -p "$(dirname "$dest")"
  windows_config >"$dest"
fi

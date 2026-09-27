#!/usr/bin/env bash
#
# The graphical login screen: greetd runs the Quickshell greeter (greeter/ in
# the repo) inside a minimal Hyprland session, and falls back to tuigreet if
# it exits abnormally (see installer/greeter/omnidots-greeter.sh). The greeter
# user can't read the repo in HOME, so the greeter is deployed as a copy,
# with qs-bar's theme and components (symlinked into greeter/), the user to log
# in as, the wallpaper for its background, and the fonts it uses. greetd's PAM stack is password-only, so the keyring unlocks and
# tuigreet can't be bypassed with fprintd. Then the machine boots to the
# graphical target.
#
# Runnable on its own to redeploy the greeter after changing it:
#
#   installer/modules/88-greeter.sh
#
# Before fingerprint enrollment, which is interactive and stays at the end;
# greetd is enabled but not started, so it takes over at the next boot and not
# in the middle of this session.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

GREETER_SRC="$OMNIDOTS_ROOT/greeter"
SYSTEM_SRC="$OMNIDOTS_ROOT/installer/greeter"
GREETER_DIR=/usr/local/share/omnidots-greeter
# System-wide, since the greeter user can't read the ones 35-theme-assets.sh
# put in the user's font dir.
GREETER_FONTS_DIR=/usr/local/share/fonts/omnidots-greeter
FONTS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
# The proportional JetBrainsMono Nerd Font qs-bar's theme names, hyprlock's
# for the clock, and the icons.
GREETER_FONTS=(
  "$FONTS_DIR/JetBrainsMonoNerdFont/JetBrainsMonoNerdFontPropo-*.ttf"
  "$FONTS_DIR/JetBrainsMonoNerdFont/JetBrainsMonoNerdFont-Regular.ttf"
  "$FONTS_DIR/JetBrainsMonoNerdFont/JetBrainsMonoNerdFont-Bold.ttf"
  "$FONTS_DIR/MaterialSymbolsRounded/MaterialSymbolsRounded.ttf"
)

# deploy_dir <source> <dest> — replace dest with a copy of source, following
# symlinks, unless they already match. The copy is made next to dest and
# swapped in, so dest is never half-written, and made readable by the greeter
# user whatever the source's modes.
deploy_dir() {
  local src="$1" dest="$2"
  if ! is_dry_run && diff -rq "$src" "$dest" &>/dev/null; then
    return
  fi
  act deploy "$src -> $dest" swap_in_copy "$src" "$dest"
}

swap_in_copy() {
  local src="$1" dest="$2"
  sudo rm -rf "$dest.new"
  sudo mkdir -p "$(dirname "$dest")"
  sudo cp -rL "$src" "$dest.new"
  sudo chmod -R u=rwX,go=rX "$dest.new"
  sudo rm -rf "$dest"
  sudo mv "$dest.new" "$dest"
}

# deploy_file <source> <dest> [mode] — install source as dest, owned by root,
# unless it's already there.
deploy_file() {
  local src="$1" dest="$2" mode="${3:-644}"
  if ! is_dry_run && cmp -s "$src" "$dest"; then
    return
  fi
  act deploy "$src -> $dest" sudo install -D -m "$mode" "$src" "$dest"
}

# The greeter logs this user in, with no user field.
GREETER_USER="$(id -un)"
# The desktop's wallpaper: hyprpaper's first, with ~ expanded.
WALLPAPER="$(sed -n 's/^wallpaper *= *[^,]*, *//p' "$OMNIDOTS_ROOT/config/hypr/hyprpaper.conf" | head -n 1)"
WALLPAPER="${WALLPAPER/#\~/$HOME}"

# deploy_greeter — deploy the greeter with its `user` file and its
# `background`, the wallpaper. Without the wallpaper the background is plain.
deploy_greeter() {
  if is_dry_run; then
    plan deploy "$GREETER_SRC + user $GREETER_USER + background $WALLPAPER -> $GREETER_DIR"
    return
  fi
  local staging
  staging="$(mktemp -d)"
  cp -rL "$GREETER_SRC/." "$staging/"
  printf '%s\n' "$GREETER_USER" >"$staging/user"
  if [[ -f $WALLPAPER ]]; then
    cp "$WALLPAPER" "$staging/background"
  else
    log_warn "The wallpaper ($WALLPAPER) isn't there; the login screen's background will be plain."
  fi
  deploy_dir "$staging" "$GREETER_DIR"
  rm -rf "$staging"
}

# deploy_fonts — copy the greeter's fonts into GREETER_FONTS_DIR. Without
# them the greeter still works, in a fallback font with icon names for icons.
deploy_fonts() {
  if is_dry_run; then
    plan deploy "${GREETER_FONTS[*]} -> $GREETER_FONTS_DIR"
    return
  fi
  local -a fonts
  # Expands the patterns.
  # shellcheck disable=SC2206
  fonts=(${GREETER_FONTS[@]})
  if [[ ! -f ${fonts[0]} || ! -f ${fonts[-1]} ]]; then
    log_warn "The greeter's fonts aren't in $FONTS_DIR; it will use a fallback font."
    return
  fi
  local staging
  staging="$(mktemp -d)"
  cp "${fonts[@]}" "$staging/"
  deploy_dir "$staging" "$GREETER_FONTS_DIR"
  rm -rf "$staging"
}

log_info "Setting up the login screen"

install_package_list greeter

deploy_greeter
deploy_fonts
deploy_file "$SYSTEM_SRC/omnidots-greeter.sh" /usr/local/bin/omnidots-greeter 755
deploy_file "$SYSTEM_SRC/greetd.toml" /etc/greetd/config.toml
deploy_file "$SYSTEM_SRC/greetd.pam" /etc/pam.d/greetd

# greetd and every other display manager are aliased as display-manager.service;
# --force points the alias at greetd. GDM stays installed but no longer starts.
if is_dry_run || [[ $(readlink /etc/systemd/system/display-manager.service) != */greetd.service ]]; then
  run sudo systemctl enable --force greetd
fi
if is_dry_run || [[ $(systemctl get-default) != graphical.target ]]; then
  run sudo systemctl set-default graphical.target
fi

#!/usr/bin/env bash
#
# One-off: brings a desktop set up by the old installer in line with a fresh
# install, by removing what the refresh dropped. Lists everything it would
# remove, then asks before removing anything. Items already gone are skipped.
#
# Usage: ./migrate.sh [--dry-run]
#   --dry-run  print the list to stdout, one item per line, and change nothing
#
# Run it after ./install.sh: GDM, the starship and lazygit rpms, the Discord
# rpm and the old theme copies each stay until their replacement is in place.
#
# Inputs, overridable so tests use a fixture:
#   OMNIDOTS_REPOS_DIR  dnf's repo files (default: /etc/yum.repos.d)
#   and the detection module's OMNIDOTS_SYSFS_ROOT and OMNIDOTS_LSPCI_FILE

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=installer/lib.sh
source installer/lib.sh
# shellcheck source=installer/detect.sh
source installer/detect.sh

# Globs sort the same way everywhere.
export LC_COLLATE=C

REPOS_DIR="${OMNIDOTS_REPOS_DIR:-/etc/yum.repos.d}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
FONTS_DIR="$DATA_DIR/fonts"

# Packages the old installer put on this desktop that no list installs now:
# replaced by qs-bar (dunst, waybar, wlogout, nm-applet's tray icon; the bar
# hides it anyway), rofi (wofi), Hyprland's monitor events (kanshi) and qt6ct
# (qt5ct), or dropped (inxi, Podman, Firefox and its langpacks). The package
# nm-connection-editor is separate and stays.
DROPPED_PACKAGES=(dunst wofi kanshi waybar wlogout network-manager-applet
  qt5ct inxi podman firefox firefox-langpacks)
# Dependencies of those that stay: nm-connection-editor came with
# network-manager-applet, and tuned with tuned-ppd. They're marked as
# user-installed first, so no later autoremove takes them.
KEPT_DEPENDENCIES=(nm-connection-editor tuned)
DROPPED_FLATPAKS=(net.davidotek.pupgui2) # ProtonUp-Qt
DROPPED_COPRS=(solopasha/hyprland erikreider/SwayNotificationCenter)
MULLVAD_REPO="$REPOS_DIR/mullvad.repo"
# The Electron safe-storage key the Mullvad app left in the login keyring.
MULLVAD_KEYRING_LABEL="Mullvad VPN Safe Storage"

# The old installer's copies in HOME, as <copy>=<what 35-theme-assets.sh
# installs in its place>. A copy goes only once its replacement is there,
# because ~/.icons and ~/.themes shadow the XDG dirs.
OLD_THEME_COPIES=(
  "$HOME/.icons/Bibata-Modern-Ice=$DATA_DIR/icons/Bibata-Modern-Ice"
  "$HOME/.icons/hyprcursors=$DATA_DIR/icons/Bibata-Modern-Ice"
  "$HOME/.icons/Tela-circle-purple=$DATA_DIR/icons/Tela-circle-purple"
  "$HOME/.icons/Tela-circle-purple-dark=$DATA_DIR/icons/Tela-circle-purple-dark"
  "$HOME/.themes/Andromeda-dark=$DATA_DIR/themes/Tokyonight-Dark"
)

REMOVE_PACKAGES=()
REMOVE_FLATPAKS=()
REMOVE_COPRS=()
REMOVE_REPOS=()
REMOVE_KEYRING_ITEMS=()
REMOVE_PATHS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '3,15s/^# \{0,1\}//p' "${BASH_SOURCE[0]##*/}"
      exit 0
      ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

[[ $EUID -ne 0 ]] || die "Run this as your user, not root; it uses sudo where needed."

installed() { rpm -q --quiet "$1"; }

not() { ! "$@"; }

# keep <item> <reason> — log why something dropped stays for now.
keep() { log_info "Keeping $1: $2"; }

# want_package <pkg> [<reason to keep>] — queue the package if it's installed,
# unless a reason to keep it is given.
want_package() {
  installed "$1" || return 0
  if [[ -n ${2:-} ]]; then
    keep "$1" "$2"
  else
    REMOVE_PACKAGES+=("$1")
  fi
}

# want_replaced <pkg> <reason to keep> <check...> — queue the package if it's
# installed and the check passes.
want_replaced() {
  local pkg="$1" reason="$2"
  shift 2
  if "$@"; then
    want_package "$pkg"
  else
    want_package "$pkg" "$reason"
  fi
}

# drop_required_packages — take out every queued package that something
# staying installed requires, until none is left, so that removing the rest
# can't take anything else with it. What requires only a capability that
# another package also provides is for dnf to show before it goes ahead.
drop_required_packages() {
  local changed=1 pkg requirers requirer
  while ((changed)); do
    changed=0
    for pkg in "${REMOVE_PACKAGES[@]}"; do
      # rpm prints "no package requires <pkg>" and fails when none does.
      requirers="$(rpm -q --whatrequires --qf '%{NAME}\n' "$pkg")" || continue
      for requirer in $requirers; do
        if ! queued_package "$requirer"; then
          keep "$pkg" "$requirer requires it"
          unqueue_package "$pkg"
          changed=1
          continue 3
        fi
      done
    done
  done
}

queued_package() {
  local pkg
  for pkg in "${REMOVE_PACKAGES[@]}"; do
    [[ $pkg == "$1" ]] && return 0
  done
  return 1
}

unqueue_package() {
  local pkg rest=()
  for pkg in "${REMOVE_PACKAGES[@]}"; do
    [[ $pkg == "$1" ]] || rest+=("$pkg")
  done
  REMOVE_PACKAGES=("${rest[@]}")
}

# gdm_replaced — true once the greeter module made greetd the display
# manager, so removing GDM can't leave the machine without one, and GDM isn't
# running: removing its package stops it, and the session it runs with it.
gdm_replaced() {
  [[ $(systemctl is-enabled greetd 2>/dev/null) == enabled ]] &&
    [[ $(systemctl show -p Id --value display-manager.service 2>/dev/null) == greetd.service ]] &&
    ! systemctl is-active --quiet gdm
}

has_release_binary() { [[ -x $LOCAL_BIN/$1 ]]; }

has_flatpak() { flatpak info --system "$1" &>/dev/null; }

copr_repo_file() {
  printf '%s/_copr:copr.fedorainfracloud.org:%s:%s.repo\n' "$REPOS_DIR" "${1%%/*}" "${1#*/}"
}

# want_copr <owner/project> [<reason to keep> <check...>] — queue the COPR if
# its repo file is there and the check, if any, passes.
want_copr() {
  local copr="$1" reason="${2:-}"
  [[ -f $(copr_repo_file "$copr") ]] || return 0
  if (($# < 3)) || "${@:3}"; then
    REMOVE_COPRS+=("$copr")
  else
    keep "copr $copr" "$reason"
  fi
}

# dbus_paths — the object paths in busctl's printout of an `ao` property.
dbus_paths() { grep -oE '"[^"]*"' | tr -d '"'; }

# secret_items_labelled <label> — the paths of the Secret Service items with
# that label, in every collection. Only labels are read, never secrets. No
# Secret Service means no items.
secret_items_labelled() {
  local collections collection items item
  collections="$(busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets org.freedesktop.Secret.Service Collections 2>/dev/null)" ||
    return 0
  for collection in $(dbus_paths <<<"$collections"); do
    items="$(busctl --user get-property org.freedesktop.secrets "$collection" \
      org.freedesktop.Secret.Collection Items 2>/dev/null)" || continue
    for item in $(dbus_paths <<<"$items"); do
      if [[ $(busctl --user get-property org.freedesktop.secrets "$item" \
        org.freedesktop.Secret.Item Label 2>/dev/null) == "s \"$1\"" ]]; then
        printf '%s\n' "$item"
      fi
    done
  done
}

# want_paths <replacement> <path...> — queue the old copies that exist once
# their replacement is there.
want_paths() {
  local replacement="$1" path found=()
  shift
  for path in "$@"; do
    if [[ -e $path || -L $path ]]; then found+=("$path"); fi
  done
  ((${#found[@]})) || return 0
  if [[ -e $replacement ]]; then
    REMOVE_PATHS+=("${found[@]}")
  elif ((${#found[@]} == 1)); then
    keep "${found[0]}" "$replacement isn't installed yet"
  else
    keep "${#found[@]} files like ${found[0]}" "$replacement isn't installed yet"
  fi
}

find_packages() {
  local pkg
  for pkg in "${DROPPED_PACKAGES[@]}"; do
    want_package "$pkg"
  done
  want_replaced gdm "greetd isn't the display manager yet, or GDM is running" gdm_replaced
  for pkg in starship lazygit; do
    want_replaced "$pkg" "no release binary in $LOCAL_BIN yet" has_release_binary "$pkg"
  done
  want_replaced discord "the Discord flatpak isn't installed yet" \
    has_flatpak com.discordapp.Discord
  # tuned-ppd serves the power profile UI, which only machines with a battery
  # have; without one it could override tuned's throughput-performance.
  want_replaced tuned-ppd "this machine has a battery" not has_flag HAS_BATTERY
  want_replaced brightnessctl "this machine has a backlight" not has_flag HAS_BACKLIGHT
  drop_required_packages
}

find_repos() {
  local app copr
  for app in "${DROPPED_FLATPAKS[@]}"; do
    if has_flatpak "$app"; then REMOVE_FLATPAKS+=("$app"); fi
  done
  for copr in "${DROPPED_COPRS[@]}"; do
    want_copr "$copr"
  done
  for copr in starship lazygit; do
    want_copr "atim/$copr" "no release binary in $LOCAL_BIN yet" has_release_binary "$copr"
  done
  if [[ -f $MULLVAD_REPO ]]; then REMOVE_REPOS+=("$MULLVAD_REPO"); fi
}

find_keyring_items() {
  if installed mullvad-vpn; then
    keep "the $MULLVAD_KEYRING_LABEL keyring entry" "Mullvad is installed"
    return
  fi
  mapfile -t REMOVE_KEYRING_ITEMS < <(secret_items_labelled "$MULLVAD_KEYRING_LABEL")
}

find_paths() {
  local copy link
  for copy in "${OLD_THEME_COPIES[@]}"; do
    want_paths "${copy#*=}" "${copy%%=*}"
  done
  # ~/.icons and ~/.themes themselves, once nothing would be left in them.
  local dir entry
  for dir in "$HOME/.icons" "$HOME/.themes"; do
    [[ -d $dir && ! -L $dir ]] || continue
    for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
      [[ -e $entry || -L $entry ]] || continue
      [[ " ${REMOVE_PATHS[*]} " == *" $entry "* ]] || continue 2
    done
    REMOVE_PATHS+=("$dir")
  done
  # The Nerd Font zip's files, which the old installer unpacked loose.
  want_paths "$FONTS_DIR/JetBrainsMonoNerdFont" \
    "$FONTS_DIR"/JetBrainsMono*NerdFont*.ttf "$FONTS_DIR"/{OFL.txt,README.md}
  want_paths "$FONTS_DIR/MaterialSymbolsRounded/MaterialSymbolsRounded.ttf" \
    "$FONTS_DIR/MaterialSymbolsRounded.ttf"
  # Links to config dirs the repo no longer has, like kanshi and qt5ct.
  for link in "$CONFIG_DIR"/*; do
    if [[ -L $link && ! -e $link && $(readlink "$link") == "$OMNIDOTS_ROOT"/* ]]; then
      REMOVE_PATHS+=("$link")
    fi
  done
}

plan_removals() {
  local item
  for item in "${REMOVE_PACKAGES[@]}"; do plan remove "pkg $item"; done
  for item in "${REMOVE_FLATPAKS[@]}"; do plan remove "flatpak $item"; done
  for item in "${REMOVE_COPRS[@]}"; do plan remove "copr $item"; done
  for item in "${REMOVE_REPOS[@]}"; do plan remove "repo $item"; done
  if ((${#REMOVE_KEYRING_ITEMS[@]})); then
    plan remove "keyring $MULLVAD_KEYRING_LABEL"
  fi
  for item in "${REMOVE_PATHS[@]}"; do plan remove "path $item"; done
}

# delete_secret_item <path> — delete a keyring item without reading it.
# Deleting from an unlocked keyring needs no prompt; any other answer is left
# for the user.
delete_secret_item() {
  local prompt
  prompt="$(busctl --user call org.freedesktop.secrets "$1" \
    org.freedesktop.Secret.Item Delete)" || prompt=
  [[ $prompt == 'o "/"' ]] ||
    log_warn "Couldn't delete '$MULLVAD_KEYRING_LABEL' from the keyring; unlock it and re-run, or delete it in Seahorse."
}

remove_all() {
  local item fonts_changed=0
  if ((${#REMOVE_PACKAGES[@]})); then
    local keep=()
    for item in "${KEPT_DEPENDENCIES[@]}"; do
      if installed "$item"; then keep+=("$item"); fi
    done
    if ((${#keep[@]})); then sudo dnf -y mark user "${keep[@]}"; fi
    # Without -y: dnf shows the whole transaction and asks again.
    sudo dnf remove --noautoremove "${REMOVE_PACKAGES[@]}"
  fi
  if ((${#REMOVE_FLATPAKS[@]})); then
    sudo flatpak uninstall --system --noninteractive "${REMOVE_FLATPAKS[@]}"
  fi
  for item in "${REMOVE_COPRS[@]}"; do sudo dnf copr remove "$item"; done
  for item in "${REMOVE_REPOS[@]}"; do sudo rm -f -- "$item"; done
  for item in "${REMOVE_KEYRING_ITEMS[@]}"; do delete_secret_item "$item"; done
  for item in "${REMOVE_PATHS[@]}"; do
    rm -rf -- "$item"
    [[ $item != "$FONTS_DIR"/* ]] || fonts_changed=1
  done
  if ((fonts_changed)); then fc-cache -f; fi
  if queued_package tuned-ppd; then
    log_info "tuned-ppd is gone; installer/modules/50-power.sh pins tuned's throughput-performance profile."
  fi
}

detect_capabilities
find_packages
find_repos
find_keyring_items
find_paths

removals="$(plan_removals)"
if [[ -z $removals ]]; then
  log_info "Nothing to remove."
  exit 0
fi
printf '%s\n' "$removals"
is_dry_run && exit 0

read -r -p "Remove all of the above? dnf lists its transaction and asks again. [y/N] " answer ||
  answer=
[[ $answer == [yY]* ]] || die "Migration aborted; nothing was removed."
remove_all
log_info "Migration complete."

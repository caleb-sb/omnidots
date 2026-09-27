#!/usr/bin/env bats
#
# The migration command, against a stubbed "installed" state: stub rpm,
# systemctl, flatpak and busctl answer from files under $STATE, the repo
# files live in a temporary dir, and HOME is a temporary fixture. sudo and
# fc-cache only record their calls, so nothing on this machine is touched.
# The hardware comes from the recorded fixtures, as in installer.bats.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config" "$HOME/.local/share"
  REPOS="$BATS_TEST_TMPDIR/repos"
  STATE="$BATS_TEST_TMPDIR/state"
  STUBS="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$REPOS" "$STATE" "$STUBS"
  touch "$STATE/rpms" "$STATE/requires" "$STATE/enabled" "$STATE/active" "$STATE/flatpaks" \
    "$STATE/keyring" "$CALLS"
  echo gdm.service >"$STATE/display-manager"

  # rpm -q --quiet <pkg>: installed when listed in rpms. rpm -q --whatrequires
  # --qf '%{NAME}\n' <pkg>: the "<requirer> <pkg>" lines of requires.
  cat >"$STUBS/rpm" <<EOF
#!/bin/sh
eval "pkg=\\\${\$#}"
case "\$*" in
  *--whatrequires*)
    awk -v p="\$pkg" '\$2 == p { print \$1; found = 1 }
      END { if (!found) print "no package requires " p; exit !found }' "$STATE/requires" ;;
  *) grep -qxF "\$pkg" "$STATE/rpms" ;;
esac
EOF
  # systemctl is-enabled <unit>: enabled when listed in enabled.
  # systemctl show -p Id --value display-manager.service: display-manager.
# systemctl is-active --quiet <unit>: active when listed in active.
  cat >"$STUBS/systemctl" <<EOF
#!/bin/sh
case "\$1" in
  is-enabled)
    if grep -qxF "\$2" "$STATE/enabled"; then echo enabled; else echo disabled; exit 1; fi ;;
  show) cat "$STATE/display-manager" ;;
  is-active) grep -qxF "\$3" "$STATE/active" ;;
  *) echo "systemctl \$*" >>"$CALLS" ;;
esac
EOF
  # flatpak info --system <app>: installed when listed in flatpaks.
  cat >"$STUBS/flatpak" <<EOF
#!/bin/sh
eval "app=\\\${\$#}"
case "\$1" in
  info) grep -qxF "\$app" "$STATE/flatpaks" ;;
  *) echo "flatpak \$*" >>"$CALLS" ;;
esac
EOF
  # The Secret Service: one collection whose items are the "<path> <label>"
  # lines of keyring. Labels can be read; Delete is recorded.
  cat >"$STUBS/busctl" <<EOF
#!/bin/sh
shift # --user
case "\$1 \$4 \$5" in
  "get-property org.freedesktop.Secret.Service Collections")
    echo 'ao 1 "/org/freedesktop/secrets/collection/login"' ;;
  "get-property org.freedesktop.Secret.Collection Items")
    printf 'ao %s' "\$(wc -l <"$STATE/keyring")"
    awk '{ printf " \"%s\"", \$1 }' "$STATE/keyring"
    echo ;;
  "get-property org.freedesktop.Secret.Item Label")
    awk -v p="\$3" '\$1 == p { sub(/^[^ ]+ /, ""); printf "s \"%s\"\n", \$0 }' "$STATE/keyring" ;;
  "call org.freedesktop.Secret.Item Delete")
    echo "busctl --user \$*" >>"$CALLS"
    echo 'o "/"' ;;
  *) exit 1 ;;
esac
EOF
  printf '#!/bin/sh\necho "sudo $*" >>"%s"\n' "$CALLS" >"$STUBS/sudo"
  printf '#!/bin/sh\necho "fc-cache $*" >>"%s"\n' "$CALLS" >"$STUBS/fc-cache"
  chmod +x "$STUBS"/*
}

# migrate [--dry-run] — run the command on the desktop fixture, or another
# one given as FIXTURE, answering $ANSWER, or with no input at all when it's
# unset.
migrate() {
  run --separate-stderr env -u HAS_NVIDIA -u HAS_AMD_GPU -u HAS_INTEL_GPU \
    -u HAS_LEGACY_INTEL_GPU -u HAS_HYBRID_GPU -u HAS_BATTERY -u HAS_BACKLIGHT \
    -u HAS_BLUETOOTH -u HAS_FPRINT -u XDG_CONFIG_HOME -u XDG_DATA_HOME \
    OMNIDOTS_SYSFS_ROOT="$FIXTURES/${FIXTURE:-desktop}/sysfs" \
    OMNIDOTS_LSPCI_FILE="$FIXTURES/${FIXTURE:-desktop}/lspci.txt" \
    OMNIDOTS_REPOS_DIR="$REPOS" PATH="$STUBS:$PATH" \
    "$REPO_ROOT/migrate.sh" "$@" < <([ -z "${ANSWER+set}" ] || echo "$ANSWER")
}

installed() { printf '%s\n' "$@" >>"$STATE/rpms"; }

# greetd_is_display_manager — what the greeter module leaves behind.
greetd_is_display_manager() {
  echo greetd >>"$STATE/enabled"
  echo greetd.service >"$STATE/display-manager"
}

release_binary() {
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\n' >"$HOME/.local/bin/$1"
  chmod +x "$HOME/.local/bin/$1"
}

copr_repo() {
  touch "$REPOS/_copr:copr.fedorainfracloud.org:${1%/*}:${1#*/}.repo"
}

# old_theme_copies — what the old installer copied into HOME: the vendored
# icons, cursors and GTK theme, and the loose Nerd Font and icon font files.
old_theme_copies() {
  mkdir -p "$HOME"/.icons/{Bibata-Modern-Ice,hyprcursors,Tela-circle-purple,Tela-circle-purple-dark} \
    "$HOME/.themes/Andromeda-dark" "$HOME/.local/share/fonts"
  touch "$HOME"/.local/share/fonts/{JetBrainsMonoNerdFont-Regular.ttf,JetBrainsMonoNLNerdFontMono-Bold.ttf,OFL.txt,README.md,MaterialSymbolsRounded.ttf}
}

# new_theme_assets — what 35-theme-assets.sh installs in their place.
new_theme_assets() {
  local data="$HOME/.local/share"
  mkdir -p "$data"/icons/{Bibata-Modern-Ice,Tela-circle-purple,Tela-circle-purple-dark} \
    "$data/themes/Tokyonight-Dark" "$data/fonts/JetBrainsMonoNerdFont" \
    "$data/fonts/MaterialSymbolsRounded"
  touch "$data/fonts/MaterialSymbolsRounded/MaterialSymbolsRounded.ttf"
}

# everything_present — this desktop before migrating, once the new install ran.
everything_present() {
  installed gdm greetd dunst wofi kanshi waybar wlogout network-manager-applet \
    nm-connection-editor qt5ct inxi podman firefox firefox-langpacks discord \
    starship lazygit tuned tuned-ppd brightnessctl
  echo "firefox-langpacks firefox" >>"$STATE/requires"
  greetd_is_display_manager
  release_binary starship
  release_binary lazygit
  printf '%s\n' net.davidotek.pupgui2 com.discordapp.Discord >>"$STATE/flatpaks"
  copr_repo solopasha/hyprland
  copr_repo erikreider/SwayNotificationCenter
  copr_repo atim/starship
  copr_repo atim/lazygit
  copr_repo lionheartp/Hyprland
  touch "$REPOS/mullvad.repo" "$REPOS/brave-browser.repo"
  printf '%s\n' \
    "/org/freedesktop/secrets/collection/login/1 Brave Safe Storage" \
    "/org/freedesktop/secrets/collection/login/7 Mullvad VPN Safe Storage" >"$STATE/keyring"
  old_theme_copies
  new_theme_assets
  ln -s "$REPO_ROOT/config/qt5ct" "$HOME/.config/qt5ct"
  ln -s "$REPO_ROOT/config/kanshi" "$HOME/.config/kanshi"
  ln -s "$REPO_ROOT/config/fish" "$HOME/.config/fish"
}

ALL_REMOVALS="remove: pkg dunst
remove: pkg wofi
remove: pkg kanshi
remove: pkg waybar
remove: pkg wlogout
remove: pkg network-manager-applet
remove: pkg qt5ct
remove: pkg inxi
remove: pkg podman
remove: pkg firefox
remove: pkg firefox-langpacks
remove: pkg gdm
remove: pkg starship
remove: pkg lazygit
remove: pkg discord
remove: pkg tuned-ppd
remove: pkg brightnessctl
remove: flatpak net.davidotek.pupgui2
remove: copr solopasha/hyprland
remove: copr erikreider/SwayNotificationCenter
remove: copr atim/starship
remove: copr atim/lazygit
remove: repo REPOS/mullvad.repo
remove: keyring Mullvad VPN Safe Storage
remove: path HOME/.icons/Bibata-Modern-Ice
remove: path HOME/.icons/hyprcursors
remove: path HOME/.icons/Tela-circle-purple
remove: path HOME/.icons/Tela-circle-purple-dark
remove: path HOME/.themes/Andromeda-dark
remove: path HOME/.local/share/fonts/JetBrainsMonoNLNerdFontMono-Bold.ttf
remove: path HOME/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf
remove: path HOME/.local/share/fonts/OFL.txt
remove: path HOME/.local/share/fonts/README.md
remove: path HOME/.local/share/fonts/MaterialSymbolsRounded.ttf
remove: path HOME/.config/kanshi
remove: path HOME/.config/qt5ct"

all_removals() {
  local list="${ALL_REMOVALS//REPOS/$REPOS}"
  printf '%s\n' "${list//HOME/$HOME}"
}

assert_output() {
  if [ "$output" != "$1" ]; then
    printf -- '--- expected ---\n%s\n--- got ---\n%s\n--- stderr ---\n%s\n' \
      "$1" "$output" "$stderr" >&2
    return 1
  fi
}

# assert_removals_except <line...> — the output is the full list without
# those lines.
assert_removals_except() {
  local expected line
  expected="$(all_removals)"
  for line in "$@"; do
    expected="$(grep -vxF -- "${line//HOME/$HOME}" <<<"$expected")"
  done
  assert_output "$expected"
}

assert_calls() {
  local calls
  calls="$(cat "$CALLS")"
  if [ "$calls" != "$1" ]; then
    printf -- '--- expected calls ---\n%s\n--- got ---\n%s\n' "$1" "$calls" >&2
    return 1
  fi
}

@test "dry-run lists exactly the dropped items when they're all present" {
  everything_present
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_output "$(all_removals)"
  assert_calls ""
  [ -d "$HOME/.icons/Bibata-Modern-Ice" ]
  [ -L "$HOME/.config/qt5ct" ]
}

@test "nothing left to remove: prints nothing and doesn't ask" {
  installed greetd nm-connection-editor tuned
  greetd_is_display_manager
  release_binary starship
  copr_repo lionheartp/Hyprland
  new_theme_assets
  ln -s "$REPO_ROOT/config/fish" "$HOME/.config/fish"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_output ""
  ANSWER=y migrate
  [ "$status" -eq 0 ]
  assert_output ""
  assert_calls ""
}

@test "keeps GDM while greetd isn't the display manager" {
  everything_present
  echo gdm.service >"$STATE/display-manager"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg gdm"

  greetd_is_display_manager
  : >"$STATE/enabled"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg gdm"
}

@test "keeps GDM while it's running, since removing it stops it" {
  everything_present
  echo gdm >"$STATE/active"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg gdm"
}

@test "keeps the starship and lazygit rpms and COPRs until the release binaries are in ~/.local/bin" {
  everything_present
  rm "$HOME/.local/bin/starship" "$HOME/.local/bin/lazygit"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg starship" "remove: pkg lazygit" \
    "remove: copr atim/starship" "remove: copr atim/lazygit"
}

@test "keeps the Discord rpm until the Discord flatpak is installed" {
  everything_present
  sed -i '/Discord/d' "$STATE/flatpaks"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg discord"
}

@test "a laptop keeps tuned-ppd and brightnessctl" {
  everything_present
  FIXTURE=core-ultra-laptop migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg tuned-ppd" "remove: pkg brightnessctl"
}

@test "keeps a package that something staying installed requires, and what that one requires" {
  everything_present
  printf '%s\n' "blueman dunst" "inxi-wrapper inxi" "inxi podman" >>"$STATE/requires"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: pkg dunst" "remove: pkg inxi" "remove: pkg podman"
}

@test "old theme copies stay until their replacements are installed" {
  everything_present
  rm -r "$HOME/.local/share/icons" "$HOME/.local/share/themes" \
    "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" \
    "$HOME/.local/share/fonts/MaterialSymbolsRounded"
  migrate --dry-run
  [ "$status" -eq 0 ]
  local copies
  copies="$(all_removals | grep "^remove: path $HOME/\.\(icons\|themes\|local\)")"
  [ -n "$copies" ]
  mapfile -t copies <<<"$copies"
  assert_removals_except "${copies[@]}"
}

@test "leaves theme copies and fonts the old installer didn't ship" {
  everything_present
  mkdir -p "$HOME/.icons/My-Theme" "$HOME/.themes/My-Theme"
  touch "$HOME/.local/share/fonts/Inter-Regular.ttf" "$HOME/.local/share/fonts/JetBrainsMono-Regular.ttf"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_output "$(all_removals)"
}

@test "only removes config links into the repo that no longer resolve" {
  everything_present
  ln -s /nowhere "$HOME/.config/elsewhere"
  ln -s "$REPO_ROOT/config/kitty" "$HOME/.config/kitty"
  mkdir "$HOME/.config/real"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_output "$(all_removals)"
}

@test "keeps the Mullvad keyring entry while Mullvad is installed" {
  everything_present
  installed mullvad-vpn
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: keyring Mullvad VPN Safe Storage"
}

@test "finds the Mullvad keyring entry only by its exact label" {
  everything_present
  printf '%s\n' \
    "/org/freedesktop/secrets/collection/login/3 Mullvad VPN Safe Storage Control" \
    "/org/freedesktop/secrets/collection/login/4 mullvad vpn safe storage" >"$STATE/keyring"
  migrate --dry-run
  [ "$status" -eq 0 ]
  assert_removals_except "remove: keyring Mullvad VPN Safe Storage"
}

@test "answering no, or nothing, removes nothing" {
  everything_present
  for answer in n "" EOF; do
    if [ "$answer" = EOF ]; then
      migrate
    else
      ANSWER="$answer" migrate
    fi
    [ "$status" -ne 0 ]
    assert_output "$(all_removals)"
    assert_calls ""
    [ -d "$HOME/.icons/Bibata-Modern-Ice" ]
    [ -L "$HOME/.config/qt5ct" ]
  done
}

@test "answering yes removes everything listed" {
  everything_present
  ANSWER=y migrate
  [ "$status" -eq 0 ]
  assert_output "$(all_removals)"
  assert_calls "sudo dnf -y mark user nm-connection-editor tuned
sudo dnf remove --noautoremove dunst wofi kanshi waybar wlogout network-manager-applet qt5ct inxi podman firefox firefox-langpacks gdm starship lazygit discord tuned-ppd brightnessctl
sudo flatpak uninstall --system --noninteractive net.davidotek.pupgui2
sudo dnf copr remove solopasha/hyprland
sudo dnf copr remove erikreider/SwayNotificationCenter
sudo dnf copr remove atim/starship
sudo dnf copr remove atim/lazygit
sudo rm -f -- $REPOS/mullvad.repo
busctl --user call org.freedesktop.secrets /org/freedesktop/secrets/collection/login/7 org.freedesktop.Secret.Item Delete
fc-cache -f"
  [ ! -e "$HOME/.icons/Bibata-Modern-Ice" ]
  [ ! -e "$HOME/.themes/Andromeda-dark" ]
  [ ! -e "$HOME/.local/share/fonts/OFL.txt" ]
  [ ! -L "$HOME/.config/qt5ct" ]
  [ -L "$HOME/.config/fish" ]
  [ -f "$HOME/.local/share/fonts/MaterialSymbolsRounded/MaterialSymbolsRounded.ttf" ]
}

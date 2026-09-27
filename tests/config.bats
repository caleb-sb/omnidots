#!/usr/bin/env bats
#
# Smoke checks on the committed config/ tree: it parses, the files it pulls in
# exist, and the themed apps use the Tokyo Night Night palette. These only
# read the repo; nothing is launched or reloaded.

bats_require_minimum_version 1.5.0

CONFIG="$BATS_TEST_DIRNAME/../config"

# Night's background (#1a1b26) or its darker variant (#16161e), and Storm's
# (#24283b, #1f2335).
NIGHT_BG='1a1b26|16161e'
STORM_BG='24283b|1f2335'

# resolve <config-file> <path> — where <path>, as written in <config-file>,
# points in the repo. ~/.config/<app>/... (or .config/<app>/..., relative to
# ~) maps to config/<app>/..., and any other relative path is relative to the
# file's own directory.
resolve() {
  local file="$1" path="${2//\"/}"
  path="${path//\'/}"
  case "$path" in
    \~/.config/*) printf '%s\n' "$CONFIG/${path#\~/.config/}" ;;
    .config/*) printf '%s\n' "$CONFIG/${path#.config/}" ;; # relative to ~
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$(dirname "$file")/$path" ;;
  esac
}

# assert_refs_exist <config-file> <path...> — each path resolves to a file.
assert_refs_exist() {
  local file="$1" path target missing=0
  shift
  for path in "$@"; do
    target="$(resolve "$file" "$path")"
    if [ ! -f "$target" ]; then
      printf '%s references missing %s\n' "${file#"$CONFIG"/}" "$path" >&2
      missing=1
    fi
  done
  return "$missing"
}

# assert_night <file...> — each file uses the Night background and none of
# Storm's.
assert_night() {
  local file bad=0
  for file in "$@"; do
    if [ ! -f "$file" ]; then
      printf 'missing: %s\n' "$file" >&2
      bad=1
    elif ! grep -qiE "$NIGHT_BG" "$file"; then
      printf 'no Night background in %s\n' "${file#"$CONFIG"/}" >&2
      bad=1
    elif grep -qiE "$STORM_BG" "$file"; then
      printf 'Storm background in %s:\n' "${file#"$CONFIG"/}" >&2
      grep -niE "$STORM_BG" "$file" | head -5 >&2
      bad=1
    fi
  done
  return "$bad"
}

# ini_value <file> <key> — the value of the first key=value line.
ini_value() {
  sed -n "s/^$2=//p" "$1" | head -1
}

# gsettings_value <key> — what hyprland.lua's startup gsettings sets <key> to.
gsettings_value() {
  sed -nE "s/.*gsettings set org\.gnome\.desktop\.interface $1 '([^']*)'.*/\1/p" \
    "$CONFIG/hypr/hyprland.lua" | head -1
}

@test "every Hyprland Lua file parses with luajit" {
  command -v luajit >/dev/null || skip "luajit is not installed"
  local file
  for file in "$CONFIG"/hypr/*.lua; do
    # -bl compiles and lists the bytecode without running the file.
    run luajit -bl "$file"
    if [ "$status" -ne 0 ]; then
      printf '%s\n' "$output" >&2
      return 1
    fi
  done
}

@test "kitty's includes, and the files its ssh kitten copies, all exist" {
  local file refs
  for file in "$CONFIG"/kitty/*.conf; do
    mapfile -t refs < <(sed -nE 's/^[[:space:]]*include[[:space:]]+(.*[^[:space:]])[[:space:]]*$/\1/p' "$file")
    assert_refs_exist "$file" "${refs[@]}"
  done
  # copy [--dest <remote>] <local>, with <local> relative to ~.
  mapfile -t refs < <(sed -nE 's/^[[:space:]]*copy[[:space:]]+(--dest[[:space:]]+[^[:space:]]+[[:space:]]+)?([^[:space:]]+)[[:space:]]*$/\2/p' "$CONFIG/kitty/ssh.conf")
  [ "${#refs[@]}" -gt 0 ]
  assert_refs_exist "$CONFIG/kitty/ssh.conf" "${refs[@]}"
}

@test "tmux's sourced files all exist" {
  local file refs
  for file in "$CONFIG"/tmux/*.conf; do
    mapfile -t refs < <(sed -nE 's/^[[:space:]]*source-file[[:space:]]+(-q[[:space:]]+)?(.*[^[:space:]])[[:space:]]*$/\2/p' "$file")
    assert_refs_exist "$file" "${refs[@]}"
  done
}

@test "qt6ct's colour scheme exists and it styles Qt with Kvantum" {
  local conf="$CONFIG/qt6ct/qt6ct.conf"
  [ "$(ini_value "$conf" style)" = kvantum ]
  assert_refs_exist "$conf" "$(ini_value "$conf" color_scheme_path)"
}

@test "kvantum.kvconfig selects the Tokyo Night theme, which exists" {
  local theme
  theme="$(ini_value "$CONFIG/Kvantum/kvantum.kvconfig" theme)"
  [ "$theme" = Tokyo-Night ]
  [ -f "$CONFIG/Kvantum/$theme/$theme.kvconfig" ]
  [ -f "$CONFIG/Kvantum/$theme/$theme.svg" ]
}

@test "only the Tokyo Night Night themes are kept" {
  [ ! -e "$CONFIG/qt5ct" ]
  LC_ALL=C run ls "$CONFIG/Kvantum"
  [ "$output" = "$(printf '%s\n' Tokyo-Night kvantum.kvconfig)" ]
  run ls "$CONFIG/kitty/themes"
  [ "$output" = tokyonight_night.conf ]
}

@test "the themed apps use the Night palette, not Storm" {
  local kitty_theme tmux_theme qt_colors rofi_theme
  kitty_theme="$(resolve "$CONFIG/kitty/kitty.conf" \
    "$(sed -nE 's/^include[[:space:]]+(.*themes\/.*)$/\1/p' "$CONFIG/kitty/kitty.conf")")"
  tmux_theme="$(resolve "$CONFIG/tmux/tmux.conf" \
    "$(sed -nE 's/^source-file[[:space:]]+(.*tokyonight.*)$/\1/p' "$CONFIG/tmux/tmux.conf")")"
  qt_colors="$(resolve "$CONFIG/qt6ct/qt6ct.conf" \
    "$(ini_value "$CONFIG/qt6ct/qt6ct.conf" color_scheme_path)")"
  # rofi looks a bare @theme name up in its config dir's themes/.
  rofi_theme="$CONFIG/rofi/themes/$(sed -nE 's/^@theme "([^"]*)".*/\1/p' "$CONFIG/rofi/config.rasi").rasi"
  assert_night "$kitty_theme" "$tmux_theme" "$qt_colors" "$rofi_theme" \
    "$CONFIG/Kvantum/Tokyo-Night/Tokyo-Night.kvconfig" \
    "$CONFIG/Kvantum/Tokyo-Night/Tokyo-Night.svg" \
    "$CONFIG/hypr/hyprlock.conf" \
    "$CONFIG/hypr/hyprland.lua" \
    "$CONFIG/qs-bar/config/Theme.qml"
}

@test "Hyprland's startup gsettings and GTK's settings.ini agree" {
  local ini="$CONFIG/gtk-3.0/settings.ini"
  [ "$(gsettings_value gtk-theme)" = Tokyonight-Dark ]
  [ "$(gsettings_value icon-theme)" = Tela-circle-purple-dark ]
  [ "$(gsettings_value cursor-theme)" = Bibata-Modern-Ice ]
  [ "$(gsettings_value color-scheme)" = prefer-dark ]
  [ "$(ini_value "$ini" gtk-theme-name)" = "$(gsettings_value gtk-theme)" ]
  [ "$(ini_value "$ini" gtk-icon-theme-name)" = "$(gsettings_value icon-theme)" ]
  [ "$(ini_value "$ini" gtk-cursor-theme-name)" = "$(gsettings_value cursor-theme)" ]
  [ "$(ini_value "$ini" gtk-application-prefer-dark-theme)" = 1 ]
}

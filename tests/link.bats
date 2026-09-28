#!/usr/bin/env bats
#
# The link step run on its own against a temporary HOME. Each test runs a copy
# of the installer inside a small fake repo, so a bug can never touch the real
# HOME or write into the real repo's config directories.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/config/hypr" "$REPO/config/fish" "$REPO/applications" \
    "$REPO/systemd"
  cp -r "$BATS_TEST_DIRNAME/../installer" "$REPO/"
  touch "$REPO/config/hypr/hyprland.conf" "$REPO/config/fish/config.fish" \
    "$REPO/config/starship.toml" "$REPO/applications/nvim.desktop" \
    "$REPO/systemd/hyprland-session.target"

  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_CONFIG_HOME XDG_DATA_HOME
  mkdir -p "$HOME"
}

link_step() {
  run --separate-stderr "$REPO/installer/modules/30-link.sh"
}

# assert_linked <target> <source> — target is a symlink to source.
assert_linked() {
  if [ ! -L "$1" ] || [ "$(readlink "$1")" != "$2" ]; then
    printf 'expected %s -> %s, got: %s\n' "$1" "$2" "$(ls -ld "$1" 2>&1)" >&2
    return 1
  fi
}

@test "fresh HOME: links each config entry, the desktop entry and the unit" {
  link_step
  [ "$status" -eq 0 ]
  assert_linked "$HOME/.config/hypr" "$REPO/config/hypr"
  assert_linked "$HOME/.config/fish" "$REPO/config/fish"
  assert_linked "$HOME/.config/starship.toml" "$REPO/config/starship.toml"
  assert_linked "$HOME/.local/share/applications/nvim.desktop" \
    "$REPO/applications/nvim.desktop"
  # Into the unit dir, which stays a real dir.
  assert_linked "$HOME/.config/systemd/user/hyprland-session.target" \
    "$REPO/systemd/hyprland-session.target"
  [ ! -L "$HOME/.config/systemd" ]
}

@test "re-run: succeeds, leaves correct links alone and nests nothing" {
  link_step
  [ "$status" -eq 0 ]
  local before
  before="$(ls -l --time-style=full-iso "$HOME/.config")"

  link_step
  [ "$status" -eq 0 ]
  [ "$(ls -l --time-style=full-iso "$HOME/.config")" = "$before" ]
  [ "$(ls "$REPO/config/hypr")" = "hyprland.conf" ]
  [ "$(ls "$REPO/config/fish")" = "config.fish" ]
  assert_linked "$HOME/.config/hypr" "$REPO/config/hypr"
  assert_linked "$HOME/.local/share/applications/nvim.desktop" \
    "$REPO/applications/nvim.desktop"
  [ -z "$(find "$HOME" -name '*.bak.*')" ]
}

@test "an existing real directory or file is moved to a timestamped backup" {
  mkdir -p "$HOME/.config/hypr"
  echo "monitor = local" >"$HOME/.config/hypr/hyprland.conf"
  echo "local prompt" >"$HOME/.config/starship.toml"

  link_step
  [ "$status" -eq 0 ]
  assert_linked "$HOME/.config/hypr" "$REPO/config/hypr"
  assert_linked "$HOME/.config/starship.toml" "$REPO/config/starship.toml"

  local stamp='[0-9]{8}-[0-9]{6}'
  [[ $(cd "$HOME/.config" && ls -d hypr.bak.*) =~ ^hypr\.bak\.$stamp$ ]]
  [[ $(cd "$HOME/.config" && ls -d starship.toml.bak.*) =~ ^starship\.toml\.bak\.$stamp$ ]]
  [ "$(cat "$HOME"/.config/hypr.bak.*/hyprland.conf)" = "monitor = local" ]
  [ "$(cat "$HOME"/.config/starship.toml.bak.*)" = "local prompt" ]
}

@test "a link pointing somewhere else is replaced, not nested into" {
  mkdir -p "$HOME/.config" "$BATS_TEST_TMPDIR/old-hypr"
  ln -s "$BATS_TEST_TMPDIR/old-hypr" "$HOME/.config/hypr"

  link_step
  [ "$status" -eq 0 ]
  assert_linked "$HOME/.config/hypr" "$REPO/config/hypr"
  [ -z "$(ls "$BATS_TEST_TMPDIR/old-hypr")" ]
}

@test "honours XDG_CONFIG_HOME and XDG_DATA_HOME" {
  XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg-config" \
    XDG_DATA_HOME="$BATS_TEST_TMPDIR/xdg-data" link_step
  [ "$status" -eq 0 ]
  assert_linked "$BATS_TEST_TMPDIR/xdg-config/fish" "$REPO/config/fish"
  assert_linked "$BATS_TEST_TMPDIR/xdg-data/applications/nvim.desktop" \
    "$REPO/applications/nvim.desktop"
  [ ! -e "$HOME/.config" ]
}

@test "dry-run plans the backup and link but moves nothing" {
  mkdir -p "$HOME/.config/hypr"
  DRY_RUN=1 link_step
  [ "$status" -eq 0 ]
  [[ $output =~ (^|$'\n')"backup: $HOME/.config/hypr -> $HOME/.config/hypr.bak."[0-9]{8}-[0-9]{6}$'\n' ]]
  grep -qxF "link: $HOME/.config/hypr -> $REPO/config/hypr" <<<"$output"
  [ -d "$HOME/.config/hypr" ] && [ ! -L "$HOME/.config/hypr" ]
  [ "$(ls "$HOME/.config")" = "hypr" ]
}

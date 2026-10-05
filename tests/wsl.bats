#!/usr/bin/env bats
#
# The WSL Alacritty step run on its own, for real, into a temporary directory
# standing in for Windows' %APPDATA%.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  APPDATA="$BATS_TEST_TMPDIR/appdata"
  DEST="$APPDATA/alacritty/alacritty.toml"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}

alacritty_step() {
  run --separate-stderr env WSL_DISTRO_NAME=FedoraLinux-44 \
    OMNIDOTS_APPDATA="$APPDATA" "$REPO_ROOT/installer/modules/36-wsl-alacritty.sh"
}

@test "writes the repo's config with a shell that starts this distro at home" {
  alacritty_step
  [ "$status" -eq 0 ]
  [ -f "$DEST" ]
  grep -qxF '[terminal.shell]' "$DEST"
  grep -qxF 'program = "wsl.exe"' "$DEST"
  grep -qxF 'args = ["--distribution", "FedoraLinux-44", "--cd", "~"]' "$DEST"
  grep -qF 'family = "JetBrainsMono Nerd Font"' "$DEST"
}

@test "the copy is valid TOML" {
  alacritty_step
  [ "$status" -eq 0 ]
  python3 -c 'import sys, tomllib; c = tomllib.load(open(sys.argv[1], "rb")); assert c["terminal"]["shell"]["program"] == "wsl.exe"' "$DEST"
}

@test "re-run: leaves an unchanged copy alone" {
  alacritty_step
  [ "$status" -eq 0 ]
  touch -d '2000-01-01' "$DEST"
  alacritty_step
  [ "$status" -eq 0 ]
  [ "$(stat -c %Y "$DEST")" = "$(date -d '2000-01-01' +%s)" ]
  [ "$(ls "$APPDATA/alacritty")" = alacritty.toml ]
}

@test "replaces its own older copy without a backup" {
  mkdir -p "$APPDATA/alacritty"
  alacritty_step
  [ "$status" -eq 0 ]
  echo '# stale' >>"$DEST"
  alacritty_step
  [ "$status" -eq 0 ]
  run ! grep -qF '# stale' "$DEST"
  [ "$(ls "$APPDATA/alacritty")" = alacritty.toml ]
}

@test "backs up an alacritty.toml it didn't write" {
  mkdir -p "$APPDATA/alacritty"
  echo '# mine' >"$DEST"
  alacritty_step
  [ "$status" -eq 0 ]
  grep -qF 'program = "wsl.exe"' "$DEST"
  local backups=("$DEST".bak.*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(cat "${backups[0]}")" = '# mine' ]
}

@test "outside WSL: does nothing" {
  run --separate-stderr env -u WSL_DISTRO_NAME OMNIDOTS_APPDATA="$APPDATA" \
    "$REPO_ROOT/installer/modules/36-wsl-alacritty.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$APPDATA" ]
}

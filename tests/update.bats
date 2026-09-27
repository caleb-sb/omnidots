#!/usr/bin/env bats
#
# The update command run on its own in dry-run, against a temporary HOME.
# Release lookups read the responses recorded in fixtures/releases, and a stub
# rpm reports what's installed, so the plan doesn't depend on the network or
# on this machine. Android Studio's install dir is a temporary /opt.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_CONFIG_HOME XDG_DATA_HOME
  mkdir -p "$HOME"

  STUBS="$BATS_TEST_TMPDIR/bin"
  RPMDB="$BATS_TEST_TMPDIR/rpmdb"
  mkdir -p "$STUBS"
  touch "$RPMDB"
  # Answers `rpm -q --qf %{VERSION} <pkg>` from $RPMDB ("<pkg> <version>"
  # lines) the way rpm does, and logs any other call.
  cat >"$STUBS/rpm" <<EOF
#!/bin/sh
if [ "\$1" = -q ]; then
  eval "pkg=\\\${\$#}"
  version="\$(awk -v p="\$pkg" '\$1 == p { print \$2 }' "$RPMDB")"
  [ -n "\$version" ] && printf '%s' "\$version" && exit 0
  echo "package \$pkg is not installed"
  exit 1
fi
echo "rpm \$*" >>"$BATS_TEST_TMPDIR/calls"
EOF
  chmod +x "$STUBS/rpm"
}

update() {
  run --separate-stderr env -u WITH_ANDROID \
    OMNIDOTS_RELEASES_DIR="$FIXTURES/releases" \
    OMNIDOTS_OPT_DIR="$BATS_TEST_TMPDIR/opt" PATH="$STUBS:$PATH" \
    "$REPO_ROOT/update.sh" "$@"
}

# installed_android_studio [version] — an Android Studio in /opt, installed
# by the Android module at that version, or by hand when none is given.
installed_android_studio() {
  local dir="$BATS_TEST_TMPDIR/opt/android-studio"
  mkdir -p "$dir/bin"
  [ -z "${1:-}" ] || printf '%s\n' "$1" >"$dir/.omnidots-version"
}

assert_line() {
  if ! grep -qxF -- "$1" <<<"$output"; then
    printf 'expected line: %s\n--- plan ---\n%s\n' "$1" "$output" >&2
    return 1
  fi
}

refute_match() {
  if grep -qiE -- "$1" <<<"$output"; then
    printf 'unexpected match: %s\n--- plan ---\n%s\n' "$1" "$output" >&2
    return 1
  fi
}

@test "fresh machine: plans starship, lazygit, OpenWhispr and Proton Mail from their latest releases" {
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: starship 1.26.0 https://github.com/starship/starship/releases/download/v1.26.0/starship-x86_64-unknown-linux-musl.tar.gz -> $HOME/.local/bin/starship"
  assert_line "release: lazygit 0.65.1 https://github.com/jesseduffield/lazygit/releases/download/v0.65.1/lazygit_0.65.1_linux_x86_64.tar.gz -> $HOME/.local/bin/lazygit"
  assert_line "release: open-whispr 1.10.2 https://github.com/OpenWhispr/openwhispr/releases/download/v1.10.2/OpenWhispr-1.10.2-linux-x86_64.rpm"
  assert_line "release: proton-mail 1.14.0 https://proton.me/download/mail/linux/1.14.0/ProtonMail-desktop-beta.rpm"
  [ -z "$(ls -A "$HOME")" ]
}

# installed_binary <name> <--version output> — a binary in ~/.local/bin.
installed_binary() {
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho "%s"\n' "$2" >"$HOME/.local/bin/$1"
  chmod +x "$HOME/.local/bin/$1"
}

@test "skips starship and lazygit when ~/.local/bin has the latest release" {
  installed_binary starship "starship 1.26.0"
  installed_binary lazygit "commit=abc123, build date=2026-09-01T10:00:00Z, build source=binaryRelease, version=0.65.1, os=linux, arch=amd64, git version=2.51.0"
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "current: starship 1.26.0"
  assert_line "current: lazygit 0.65.1"
  refute_match '^release: (starship|lazygit) '
}

@test "replaces an older starship in ~/.local/bin" {
  installed_binary starship "starship 1.24.2"
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: starship 1.26.0 https://github.com/starship/starship/releases/download/v1.26.0/starship-x86_64-unknown-linux-musl.tar.gz -> $HOME/.local/bin/starship"
  refute_match '^current: starship'
}

@test "a latest starship elsewhere on PATH, like a COPR build, doesn't count" {
  printf '#!/bin/sh\necho "starship 1.26.0"\n' >"$STUBS/starship"
  chmod +x "$STUBS/starship"
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: starship 1.26.0 https://github.com/starship/starship/releases/download/v1.26.0/starship-x86_64-unknown-linux-musl.tar.gz -> $HOME/.local/bin/starship"
}

@test "upgrades an older OpenWhispr rpm and skips a current Proton Mail" {
  printf '%s\n' "open-whispr 1.8.3" "proton-mail 1.14.0" >"$RPMDB"
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: open-whispr 1.10.2 https://github.com/OpenWhispr/openwhispr/releases/download/v1.10.2/OpenWhispr-1.10.2-linux-x86_64.rpm"
  assert_line "current: proton-mail 1.14.0"
  refute_match '^release: proton-mail '
}

# theme_asset <dir under ~/.local/share> <name> <version> — an asset this
# installed there at that version.
theme_asset() {
  mkdir -p "$HOME/.local/share/$1"
  printf '%s\n' "$3" >"$HOME/.local/share/$1/.omnidots-$2"
}

@test "fresh machine: fetches the pinned themes and the latest fonts, then rebuilds the font cache" {
  local share="$HOME/.local/share"
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: tela-circle-icons 2026-07-07 https://github.com/vinceliuice/Tela-circle-icon-theme/archive/refs/tags/2026-07-07.tar.gz -> $share/icons/Tela-circle-purple"
  assert_line "release: bibata-cursors 2.0.7 https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz -> $share/icons/Bibata-Modern-Ice"
  assert_line "release: bibata-hyprcursors 1.1 https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/v1.1/hypr_Bibata-Modern-Ice.tar.gz -> $share/icons/Bibata-Modern-Ice"
  assert_line "release: tokyonight-gtk 6c340e058e84c1975a038a8e5d1e384477225dc0 https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme/archive/6c340e058e84c1975a038a8e5d1e384477225dc0.tar.gz -> $share/themes/Tokyonight-Dark"
  assert_line "release: jetbrains-mono-nerd-font 3.5.1 https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz -> $share/fonts/JetBrainsMonoNerdFont"
  assert_line "release: material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef https://raw.githubusercontent.com/google/material-design-icons/bd8cb85bd4bad964fe6918f79665bb40c3a8efef/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf -> $share/fonts/MaterialSymbolsRounded"
  assert_line "run: fc-cache -f"
}

@test "skips themes already at their pinned versions" {
  theme_asset icons/Tela-circle-purple tela-circle-icons 2026-07-07
  theme_asset icons/Bibata-Modern-Ice bibata-cursors 2.0.7
  theme_asset icons/Bibata-Modern-Ice bibata-hyprcursors 1.1
  theme_asset themes/Tokyonight-Dark tokyonight-gtk 6c340e058e84c1975a038a8e5d1e384477225dc0
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "current: tela-circle-icons 2026-07-07"
  assert_line "current: bibata-cursors 2.0.7"
  assert_line "current: bibata-hyprcursors 1.1"
  assert_line "current: tokyonight-gtk 6c340e058e84c1975a038a8e5d1e384477225dc0"
  refute_match '^release: (tela|bibata|tokyonight)'
}

@test "replaces a theme installed at an older pin" {
  theme_asset themes/Tokyonight-Dark tokyonight-gtk 9d67b24f1d326816a645ba47933f9986a1ff8a23
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: tokyonight-gtk 6c340e058e84c1975a038a8e5d1e384477225dc0 https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme/archive/6c340e058e84c1975a038a8e5d1e384477225dc0.tar.gz -> $HOME/.local/share/themes/Tokyonight-Dark"
}

@test "refreshes an older Nerd Font, skips a current Material Symbols, and rebuilds the font cache" {
  theme_asset fonts/JetBrainsMonoNerdFont jetbrains-mono-nerd-font 3.2.1
  theme_asset fonts/MaterialSymbolsRounded material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: jetbrains-mono-nerd-font 3.5.1 https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz -> $HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  assert_line "current: material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef"
  assert_line "run: fc-cache -f"
}

@test "refreshes Material Symbols changed since, and leaves the font cache alone when no font changed" {
  theme_asset fonts/JetBrainsMonoNerdFont jetbrains-mono-nerd-font 3.5.1
  theme_asset fonts/MaterialSymbolsRounded material-symbols-rounded 27e9ef1dbeedc13d682fece4a58e1eda4cb0961a
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef https://raw.githubusercontent.com/google/material-design-icons/bd8cb85bd4bad964fe6918f79665bb40c3a8efef/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf -> $HOME/.local/share/fonts/MaterialSymbolsRounded"

  theme_asset fonts/MaterialSymbolsRounded material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "current: jetbrains-mono-nerd-font 3.5.1"
  assert_line "current: material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef"
  refute_match 'fc-cache'
}

@test "without Android Studio in /opt: never installs it" {
  update --dry-run
  [ "$status" -eq 0 ]
  refute_match 'android'
}

@test "WITH_ANDROID=1 doesn't make it install Android Studio either" {
  run --separate-stderr env WITH_ANDROID=1 \
    OMNIDOTS_RELEASES_DIR="$FIXTURES/releases" \
    OMNIDOTS_OPT_DIR="$BATS_TEST_TMPDIR/opt" PATH="$STUBS:$PATH" \
    "$REPO_ROOT/update.sh" --dry-run
  [ "$status" -eq 0 ]
  refute_match 'android'
}

@test "refreshes an older Android Studio in /opt from the latest tarball" {
  local opt="$BATS_TEST_TMPDIR/opt"
  installed_android_studio 2026.1.3.6
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: android-studio 2026.1.4.8 https://edgedl.me.gvt1.com/android/studio/ide-zips/2026.1.4.8/android-studio-quail4-patch1-linux.tar.gz -> $opt/android-studio"
  assert_line "conf: /usr/local/share/applications/android-studio.desktop Exec=$opt/android-studio/bin/studio"
}

@test "replaces an Android Studio installed by hand, whose version is unknown" {
  local opt="$BATS_TEST_TMPDIR/opt"
  installed_android_studio
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "release: android-studio 2026.1.4.8 https://edgedl.me.gvt1.com/android/studio/ide-zips/2026.1.4.8/android-studio-quail4-patch1-linux.tar.gz -> $opt/android-studio"
}

@test "skips an Android Studio already at the latest release" {
  installed_android_studio 2026.1.4.8
  update --dry-run
  [ "$status" -eq 0 ]
  assert_line "current: android-studio 2026.1.4.8"
  refute_match '^(release|conf): .*android-studio'
}

@test "dry-run changes nothing: no installs, downloads or files" {
  installed_android_studio 2026.1.3.6
  for cmd in sudo dnf curl tar install; do
    printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$BATS_TEST_TMPDIR/calls" >"$STUBS/$cmd"
    chmod +x "$STUBS/$cmd"
  done
  update --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/calls" ]
  [ -z "$(ls -A "$HOME")" ]
}

@test "rejects unknown arguments" {
  update --bogus
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

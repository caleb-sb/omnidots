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

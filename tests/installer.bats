#!/usr/bin/env bats
#
# The installer's dry-run plan is the test seam: each test runs the full
# installer against a recorded hardware fixture and asserts on printed lines.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
}

# plan_for <fixture> [VAR=value...] — dry-run the installer against a fixture.
plan_for() {
  local fixture="$1"
  shift
  run --separate-stderr env -u HAS_NVIDIA -u HAS_AMD_GPU -u HAS_INTEL_GPU \
    OMNIDOTS_SYSFS_ROOT="$FIXTURES/$fixture/sysfs" \
    OMNIDOTS_LSPCI_FILE="$FIXTURES/$fixture/lspci.txt" \
    "$@" "$REPO_ROOT/install.sh" --dry-run
}

assert_line() {
  if ! grep -qxF -- "$1" <<<"$output"; then
    printf 'expected line: %s\n--- plan ---\n%s\n' "$1" "$output" >&2
    return 1
  fi
}

refute_line() {
  if grep -qxF -- "$1" <<<"$output"; then
    printf 'unexpected line: %s\n--- plan ---\n%s\n' "$1" "$output" >&2
    return 1
  fi
}

@test "desktop: detects NVIDIA and AMD GPUs but no Intel GPU" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_NVIDIA=1"
  assert_line "flag: HAS_AMD_GPU=1"
  assert_line "flag: HAS_INTEL_GPU=0"
}

@test "desktop: configures dnf and enables only the expected repos" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "conf: /etc/dnf/dnf.conf max_parallel_downloads=10"
  assert_line "conf: /etc/dnf/dnf.conf defaultyes=True"
  assert_line "conf: /etc/dnf/dnf.conf unset fastestmirror"
  refute_line "conf: /etc/dnf/dnf.conf fastestmirror=True"

  local repos
  repos="$(grep '^repo: ' <<<"$output")"
  [ "$repos" = "repo: rpmfusion-free
repo: rpmfusion-nonfree
repo: copr:lionheartp/Hyprland
repo: copr:errornointernet/quickshell" ]
}

@test "desktop: installs the core packages and none of the dropped ones" {
  plan_for desktop
  [ "$status" -eq 0 ]
  for pkg in hyprland hyprlock quickshell fish kitty neovim rofi cliphist \
    nm-connection-editor Thunar pavucontrol golang inkscape vlc; do
    assert_line "pkg: $pkg"
  done
  for pkg in dunst wofi kanshi podman firefox network-manager-applet \
    waybar starship lazygit; do
    refute_line "pkg: $pkg"
  done
}

@test "an environment variable overrides a detected flag" {
  plan_for desktop HAS_NVIDIA=0 HAS_INTEL_GPU=1
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_NVIDIA=0"
  assert_line "flag: HAS_AMD_GPU=1"
  assert_line "flag: HAS_INTEL_GPU=1"
}

@test "dry-run executes nothing" {
  local stubs="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$stubs"
  for cmd in sudo dnf rpm; do
    printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$BATS_TEST_TMPDIR/calls" >"$stubs/$cmd"
    chmod +x "$stubs/$cmd"
  done
  plan_for desktop PATH="$stubs:$PATH"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/calls" ]
}

@test "rejects unknown arguments" {
  run --separate-stderr "$REPO_ROOT/install.sh" --bogus
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "without lspci, detects GPUs from sysfs" {
  # Fedora Minimal doesn't ship pciutils, so the first run has no lspci.
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  for cmd in /usr/bin/*; do
    [ "${cmd##*/}" = lspci ] || ln -s "$cmd" "$bin/"
  done
  plan_for desktop PATH="$bin" OMNIDOTS_LSPCI_FILE=
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_NVIDIA=1"
  assert_line "flag: HAS_AMD_GPU=1"
  assert_line "flag: HAS_INTEL_GPU=0"
}

@test "rejects a flag override that isn't 0 or 1" {
  plan_for desktop HAS_NVIDIA=yes
  [ "$status" -eq 1 ]
}

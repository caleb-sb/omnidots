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
  mkdir -p "$BATS_TEST_TMPDIR/home"
  run --separate-stderr env -u HAS_NVIDIA -u HAS_AMD_GPU -u HAS_INTEL_GPU \
    -u HAS_LEGACY_INTEL_GPU -u HAS_HYBRID_GPU -u XDG_CONFIG_HOME \
    -u XDG_DATA_HOME HOME="$BATS_TEST_TMPDIR/home" \
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

# refute_match <ERE> — no plan line matches the pattern, ignoring case.
refute_match() {
  if grep -qiE -- "$1" <<<"$output"; then
    printf 'unexpected match: %s\n--- plan ---\n%s\n' "$1" "$output" >&2
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

@test "plans linking the dotfiles into a fresh HOME and changes nothing" {
  plan_for desktop
  [ "$status" -eq 0 ]
  local home="$BATS_TEST_TMPDIR/home"
  assert_line "link: $home/.config/hypr -> $REPO_ROOT/config/hypr"
  assert_line "link: $home/.config/fish -> $REPO_ROOT/config/fish"
  assert_line "link: $home/.config/starship.toml -> $REPO_ROOT/config/starship.toml"
  assert_line "link: $home/.local/share/applications/nvim.desktop -> $REPO_ROOT/applications/nvim.desktop"
  [ -z "$(ls -A "$home")" ]
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
  for cmd in sudo dnf rpm mokutil kmodgenca akmods modinfo; do
    printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$BATS_TEST_TMPDIR/calls" >"$stubs/$cmd"
    chmod +x "$stubs/$cmd"
  done
  for fixture in desktop hybrid-laptop; do
    plan_for "$fixture" PATH="$stubs:$PATH"
    [ "$status" -eq 0 ]
  done
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

@test "core ultra laptop: modern Intel media driver and freeworld, no NVIDIA" {
  plan_for core-ultra-laptop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_INTEL_GPU=1"
  assert_line "flag: HAS_LEGACY_INTEL_GPU=0"
  assert_line "flag: HAS_NVIDIA=0"
  assert_line "pkg: intel-media-driver"
  assert_line "swap: mesa-va-drivers -> mesa-va-drivers-freeworld"
  refute_line "pkg: libva-intel-driver"
  refute_line "pkg: akmod-nvidia"
  refute_line "pkg: libva-nvidia-driver"
}

@test "old Intel laptop: legacy Intel VA driver, no modern one" {
  plan_for old-intel-laptop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_INTEL_GPU=1"
  assert_line "flag: HAS_LEGACY_INTEL_GPU=1"
  assert_line "flag: HAS_HYBRID_GPU=0"
  assert_line "pkg: libva-intel-driver"
  refute_line "pkg: intel-media-driver"
  refute_line "pkg: akmod-nvidia"
}

@test "without lspci, classifies a legacy Intel GPU from sysfs" {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  for cmd in /usr/bin/*; do
    [ "${cmd##*/}" = lspci ] || ln -s "$cmd" "$bin/"
  done
  plan_for old-intel-laptop PATH="$bin" OMNIDOTS_LSPCI_FILE=
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_INTEL_GPU=1"
  assert_line "flag: HAS_LEGACY_INTEL_GPU=1"
}

@test "desktop: NVIDIA packages and freeworld, no Intel driver, no GRUB edits" {
  plan_for desktop
  [ "$status" -eq 0 ]
  for pkg in akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver; do
    assert_line "pkg: $pkg"
  done
  assert_line "swap: mesa-va-drivers -> mesa-va-drivers-freeworld"
  refute_line "pkg: intel-media-driver"
  refute_line "pkg: libva-intel-driver"
  refute_match grub
}

@test "NVIDIA: waits for the akmods build after every package install" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "wait: akmods build of the nvidia kernel module"
  local wait_at last_pkg_at
  wait_at="$(grep -n '^wait: akmods' <<<"$output" | cut -d: -f1)"
  last_pkg_at="$(grep -n -E '^(pkg|swap): ' <<<"$output" | tail -n 1 | cut -d: -f1)"
  [ "$wait_at" -gt "$last_pkg_at" ]
}

@test "NVIDIA with Secure Boot off: no MOK enrollment" {
  plan_for desktop
  [ "$status" -eq 0 ]
  refute_match mokutil
}

@test "hybrid laptop: NVIDIA packages, runtime power management, iGPU first" {
  plan_for hybrid-laptop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_NVIDIA=1"
  assert_line "flag: HAS_INTEL_GPU=1"
  assert_line "flag: HAS_HYBRID_GPU=1"
  for pkg in akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver \
    intel-media-driver; do
    assert_line "pkg: $pkg"
  done
  assert_line "conf: /etc/modprobe.d/nvidia-runtime-pm.conf options nvidia NVreg_DynamicPowerManagement=0x02"
  assert_line "gpu-order: 0000:00:02.0 0000:01:00.0"
  refute_match grub
}

@test "NVIDIA with Secure Boot on: creates the akmods key and queues it for MOK enrollment before the driver" {
  plan_for hybrid-laptop
  [ "$status" -eq 0 ]
  local steps
  steps="$(grep -E '^(pkg: (akmods|mokutil|akmod-nvidia)|run: sudo (kmodgenca|mokutil))' <<<"$output")"
  [ "$steps" = "pkg: akmods
pkg: mokutil
run: sudo kmodgenca -a
run: sudo mokutil --import /etc/pki/akmods/certs/public_key.der
pkg: akmod-nvidia" ]
}

@test "single-GPU laptop: no hybrid steps" {
  plan_for core-ultra-laptop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_HYBRID_GPU=0"
  refute_match '^gpu-order: '
  refute_match 'nvidia-runtime-pm'
}

@test "desktop: a VGA-class NVIDIA card next to the AMD iGPU is not hybrid" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_HYBRID_GPU=0"
  refute_line "conf: /etc/modprobe.d/nvidia-runtime-pm.conf options nvidia NVreg_DynamicPowerManagement=0x02"
  refute_match '^gpu-order: '
}

@test "HAS_NVIDIA=0 drops the NVIDIA packages, key and build wait" {
  plan_for hybrid-laptop HAS_NVIDIA=0
  [ "$status" -eq 0 ]
  refute_line "pkg: akmod-nvidia"
  refute_line "pkg: libva-nvidia-driver"
  refute_match 'mokutil|kmodgenca|nvidia-runtime-pm|^wait: '
  assert_line "pkg: intel-media-driver"
}

@test "HAS_LEGACY_INTEL_GPU=1 swaps the Intel media driver for the legacy one" {
  plan_for core-ultra-laptop HAS_LEGACY_INTEL_GPU=1
  [ "$status" -eq 0 ]
  assert_line "pkg: libva-intel-driver"
  refute_line "pkg: intel-media-driver"
}

@test "HAS_HYBRID_GPU=0 drops runtime power management and GPU ordering" {
  plan_for hybrid-laptop HAS_HYBRID_GPU=0
  [ "$status" -eq 0 ]
  assert_line "pkg: akmod-nvidia"
  refute_match 'nvidia-runtime-pm|^gpu-order: '
}

@test "an NVIDIA-only machine gets no freeworld swap" {
  plan_for desktop HAS_AMD_GPU=0
  [ "$status" -eq 0 ]
  assert_line "pkg: akmod-nvidia"
  refute_match freeworld
}

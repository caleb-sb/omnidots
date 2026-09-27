#!/usr/bin/env bats
#
# The installer's dry-run plan is the test seam: each test runs the full
# installer against a recorded hardware fixture and asserts on printed lines.
# Release lookups read the responses recorded in fixtures/releases, and a stub
# rpm reports nothing installed, so the plan needs no network and doesn't
# depend on this machine. Android Studio's install dir is an empty temporary
# /opt.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  RPM_STUB="$BATS_TEST_TMPDIR/rpm-stub"
  mkdir -p "$RPM_STUB"
  printf '#!/bin/sh\necho "package is not installed"\nexit 1\n' >"$RPM_STUB/rpm"
  chmod +x "$RPM_STUB/rpm"
}

# plan_for <fixture> [VAR=value...] — dry-run the installer against a fixture.
plan_for() {
  local fixture="$1"
  shift
  mkdir -p "$BATS_TEST_TMPDIR/home"
  run --separate-stderr env -u HAS_NVIDIA -u HAS_AMD_GPU -u HAS_INTEL_GPU \
    -u HAS_LEGACY_INTEL_GPU -u HAS_HYBRID_GPU -u HAS_BATTERY -u HAS_BACKLIGHT \
    -u HAS_BLUETOOTH -u HAS_FPRINT -u WITH_GAMING -u WITH_ANDROID \
    -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="$BATS_TEST_TMPDIR/home" \
    OMNIDOTS_OPT_DIR="$BATS_TEST_TMPDIR/opt" \
    OMNIDOTS_SYSFS_ROOT="$FIXTURES/$fixture/sysfs" \
    OMNIDOTS_LSPCI_FILE="$FIXTURES/$fixture/lspci.txt" \
    OMNIDOTS_OS_RELEASE="$FIXTURES/os-release" \
    OMNIDOTS_RELEASES_DIR="$FIXTURES/releases" PATH="$RPM_STUB:$PATH" \
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
repo: copr:errornointernet/quickshell
repo: brave-browser
repo: google-chrome
repo: docker-ce
repo: protonvpn https://repo.protonvpn.com/fedora-44-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.4-1.noarch.rpm
repo: flathub" ]
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

@test "every machine: xrandr, which sets the XWayland primary output" {
  for fixture in desktop core-ultra-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "pkg: xrandr"
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
  for cmd in sudo dnf rpm mokutil kmodgenca akmods modinfo systemctl tuned-adm \
    authselect fprintd-list fprintd-enroll curl gpg flatpak usermod rustup-init \
    pnpm bun claude tar fc-cache; do
    printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$BATS_TEST_TMPDIR/calls" >"$stubs/$cmd"
    chmod +x "$stubs/$cmd"
  done
  for fixture in desktop hybrid-laptop core-ultra-laptop; do
    plan_for "$fixture" PATH="$stubs:$PATH" WITH_GAMING=1 WITH_ANDROID=1
    [ "$status" -eq 0 ]
  done
  # Only read-only queries ran: the installed versions of the release rpms.
  touch "$BATS_TEST_TMPDIR/calls"
  run grep -v '^rpm -q ' "$BATS_TEST_TMPDIR/calls"
  [ "$status" -eq 1 ]
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

@test "desktop: Bluetooth, but no battery or backlight" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_BATTERY=0"
  assert_line "flag: HAS_BACKLIGHT=0"
  assert_line "flag: HAS_BLUETOOTH=1"
}

@test "laptops: battery, backlight and Bluetooth" {
  for fixture in core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "flag: HAS_BATTERY=1"
    assert_line "flag: HAS_BACKLIGHT=1"
    assert_line "flag: HAS_BLUETOOTH=1"
  done
}

@test "desktop: Bluetooth packages, no brightnessctl" {
  plan_for desktop
  [ "$status" -eq 0 ]
  for pkg in bluez bluez-tools blueman; do
    assert_line "pkg: $pkg"
  done
  refute_line "pkg: brightnessctl"
}

@test "laptops: brightnessctl" {
  for fixture in core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "pkg: brightnessctl"
  done
}

@test "HAS_BLUETOOTH=0 drops the Bluetooth packages" {
  plan_for desktop HAS_BLUETOOTH=0
  [ "$status" -eq 0 ]
  refute_match '^pkg: (bluez|blueman)'
}

@test "HAS_BACKLIGHT=0 drops brightnessctl" {
  plan_for core-ultra-laptop HAS_BACKLIGHT=0
  [ "$status" -eq 0 ]
  refute_line "pkg: brightnessctl"
}

@test "desktop: tuned pinned to throughput-performance once, no tuned-ppd" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "pkg: tuned"
  [ "$(grep -c 'tuned-adm profile' <<<"$output")" -eq 1 ]
  assert_line "run: sudo tuned-adm profile throughput-performance"
  refute_line "pkg: tuned-ppd"
}

@test "laptops: tuned-ppd, and no pinned profile" {
  for fixture in core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "pkg: tuned-ppd"
    refute_match 'tuned-adm profile|throughput-performance'
  done
}

@test "HAS_BATTERY=1 on the desktop swaps the pinned profile for tuned-ppd" {
  plan_for desktop HAS_BATTERY=1
  [ "$status" -eq 0 ]
  assert_line "pkg: tuned-ppd"
  refute_match 'tuned-adm profile|throughput-performance'
}

@test "core ultra laptop: detects the Goodix fingerprint reader" {
  plan_for core-ultra-laptop
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_FPRINT=1"
}

@test "desktop, hybrid and old Intel: no fingerprint reader" {
  for fixture in desktop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "flag: HAS_FPRINT=0"
  done
}

@test "core ultra laptop: fprintd, its PAM module and authselect's fingerprint feature" {
  plan_for core-ultra-laptop
  [ "$status" -eq 0 ]
  assert_line "pkg: fprintd"
  assert_line "pkg: fprintd-pam"
  assert_line "run: sudo authselect enable-feature with-fingerprint"
}

@test "desktop, hybrid and old Intel: no fingerprint packages or authselect change" {
  for fixture in desktop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    refute_match 'fprintd|authselect'
  done
}

@test "HAS_FPRINT overrides add or drop the fingerprint steps" {
  plan_for desktop HAS_FPRINT=1
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_FPRINT=1"
  assert_line "pkg: fprintd"
  assert_line "run: sudo authselect enable-feature with-fingerprint"

  plan_for core-ultra-laptop HAS_FPRINT=0
  [ "$status" -eq 0 ]
  assert_line "flag: HAS_FPRINT=0"
  refute_match 'fprintd|authselect'
}

@test "core ultra laptop: offers fingerprint enrollment as the last step" {
  plan_for core-ultra-laptop
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 <<<"$output")" = "ask: fprintd-enroll" ]
}

@test "every machine: Brave, Chrome, Docker CE and Proton VPN repos for the running Fedora" {
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "pkg: dnf5-plugins"
    assert_line "repo: brave-browser"
    assert_line "pkg: fedora-workstation-repositories"
    assert_line "repo: google-chrome"
    assert_line "repo: docker-ce"
    assert_line "repo: protonvpn https://repo.protonvpn.com/fedora-44-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.4-1.noarch.rpm"
  done
}

@test "every machine: everyday apps, playerctl, rofi and Proton VPN, no wofi" {
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    for pkg in brave-browser google-chrome-stable inkscape meld vlc obs-studio \
      playerctl rofi proton-vpn-gnome-desktop; do
      assert_line "pkg: $pkg"
    done
    refute_line "pkg: wofi"
    refute_match 'snap|postman'
  done
}

@test "every machine: rootful Docker CE with its plugins and me in the docker group, no Podman" {
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
      docker-compose-plugin; do
      assert_line "pkg: $pkg"
    done
    assert_line "run: sudo systemctl enable --now docker"
    assert_line "run: sudo usermod -aG docker $(id -un)"
    refute_match '^pkg: podman'
  done
}

@test "every machine: Flathub with Obsidian, Spotify and Cura" {
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "pkg: flatpak"
    assert_line "repo: flathub"
    assert_line "flatpak: md.obsidian.Obsidian"
    assert_line "flatpak: com.spotify.Client"
    assert_line "flatpak: com.ultimaker.cura"
  done
}

@test "every machine: Go, rustup, pnpm with Node, bun and Claude Code" {
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "pkg: golang"
    assert_line "pkg: rustup"
    assert_line "run: rustup-init -y --no-modify-path"
    assert_line "run: curl -fsSL https://get.pnpm.io/install.sh | sh -"
    assert_line "run: pnpm runtime set node lts -g"
    assert_line "run: curl -fsSL https://bun.sh/install | bash"
    assert_line "run: curl -fsSL https://claude.ai/install.sh | bash"
  done
}

@test "every machine: starship, lazygit, OpenWhispr and Proton Mail from their latest upstream releases" {
  local home="$BATS_TEST_TMPDIR/home"
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "release: starship 1.26.0 https://github.com/starship/starship/releases/download/v1.26.0/starship-x86_64-unknown-linux-musl.tar.gz -> $home/.local/bin/starship"
    assert_line "release: lazygit 0.65.1 https://github.com/jesseduffield/lazygit/releases/download/v0.65.1/lazygit_0.65.1_linux_x86_64.tar.gz -> $home/.local/bin/lazygit"
    assert_line "release: open-whispr 1.10.2 https://github.com/OpenWhispr/openwhispr/releases/download/v1.10.2/OpenWhispr-1.10.2-linux-x86_64.rpm"
    assert_line "release: proton-mail 1.14.0 https://proton.me/download/mail/linux/1.14.0/ProtonMail-desktop-beta.rpm"
    assert_line "pkg: tar"
    assert_line "pkg: gzip"
    refute_match '^repo: copr:atim/'
  done
}

@test "optional modules: neither gaming nor Android by default" {
  for fixture in desktop core-ultra-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "flag: WITH_GAMING=0"
    assert_line "flag: WITH_ANDROID=0"
    refute_match 'steam|xdotool|discord|heroic|android-studio'
  done
}

@test "WITH_GAMING=1: Steam from RPM Fusion, Discord and Heroic from Flathub, nothing from Android" {
  for fixture in desktop core-ultra-laptop; do
    plan_for "$fixture" WITH_GAMING=1
    [ "$status" -eq 0 ]
    assert_line "flag: WITH_GAMING=1"
    assert_line "flag: WITH_ANDROID=0"
    assert_line "repo: rpmfusion-nonfree"
    assert_line "pkg: steam"
    assert_line "flatpak: com.discordapp.Discord"
    assert_line "flatpak: com.heroicgameslauncher.hgl"
    refute_match 'protonup|gamemode|android-studio'
  done
}

@test "WITH_GAMING=1: xdotool, which the dontkillsteam keybind needs to hide Steam" {
  plan_for desktop WITH_GAMING=1
  [ "$status" -eq 0 ]
  assert_line "pkg: xdotool"
}

@test "WITH_ANDROID=1: the latest Android Studio tarball into /opt with a desktop entry, nothing from gaming" {
  local opt="$BATS_TEST_TMPDIR/opt"
  for fixture in desktop core-ultra-laptop; do
    plan_for "$fixture" WITH_ANDROID=1
    [ "$status" -eq 0 ]
    assert_line "flag: WITH_GAMING=0"
    assert_line "flag: WITH_ANDROID=1"
    assert_line "release: android-studio 2026.1.4.8 https://edgedl.me.gvt1.com/android/studio/ide-zips/2026.1.4.8/android-studio-quail4-patch1-linux.tar.gz -> $opt/android-studio"
    assert_line "conf: /usr/local/share/applications/android-studio.desktop Exec=$opt/android-studio/bin/studio"
    refute_match 'steam|discord|heroic'
  done
}

@test "rejects a module choice that isn't 0 or 1" {
  plan_for desktop WITH_GAMING=yes
  [ "$status" -eq 1 ]
  plan_for desktop WITH_ANDROID=yes
  [ "$status" -eq 1 ]
}

@test "every machine: Tela circle icons, Bibata cursors and the Tokyonight GTK theme at pinned versions" {
  local share="$BATS_TEST_TMPDIR/home/.local/share"
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "release: tela-circle-icons 2026-07-07 https://github.com/vinceliuice/Tela-circle-icon-theme/archive/refs/tags/2026-07-07.tar.gz -> $share/icons/Tela-circle-purple"
    assert_line "release: bibata-cursors 2.0.7 https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz -> $share/icons/Bibata-Modern-Ice"
    assert_line "release: bibata-hyprcursors 1.1 https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/v1.1/hypr_Bibata-Modern-Ice.tar.gz -> $share/icons/Bibata-Modern-Ice"
    assert_line "release: tokyonight-gtk 6c340e058e84c1975a038a8e5d1e384477225dc0 https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme/archive/6c340e058e84c1975a038a8e5d1e384477225dc0.tar.gz -> $share/themes/Tokyonight-Dark"
  done
}

@test "every machine: the latest JetBrainsMono Nerd Font and Material Symbols Rounded, then the font cache is rebuilt" {
  local fonts="$BATS_TEST_TMPDIR/home/.local/share/fonts"
  for fixture in desktop core-ultra-laptop hybrid-laptop old-intel-laptop; do
    plan_for "$fixture"
    [ "$status" -eq 0 ]
    assert_line "release: jetbrains-mono-nerd-font 3.5.1 https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz -> $fonts/JetBrainsMonoNerdFont"
    assert_line "release: material-symbols-rounded bd8cb85bd4bad964fe6918f79665bb40c3a8efef https://raw.githubusercontent.com/google/material-design-icons/bd8cb85bd4bad964fe6918f79665bb40c3a8efef/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf -> $fonts/MaterialSymbolsRounded"
    assert_line "run: fc-cache -f"
  done
}

@test "every machine: what building and unpacking the theme assets needs" {
  plan_for desktop
  [ "$status" -eq 0 ]
  assert_line "pkg: sassc"
  assert_line "pkg: gtk-murrine-engine"
  assert_line "pkg: xz"
}

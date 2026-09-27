# omnidots

Turns a Fedora Minimal install (Everything netinstall, Minimal Install
selection) into my Hyprland desktop.

## Install

```sh
./install.sh            # detect hardware, confirm, install
./install.sh --dry-run  # print the plan, one action per line; change nothing
```

The installer detects hardware capabilities and shows them before doing
anything:

- `HAS_NVIDIA`, `HAS_AMD_GPU`, `HAS_INTEL_GPU`: a GPU from that vendor
- `HAS_LEGACY_INTEL_GPU`: the Intel GPU predates Broadwell (or is Braswell),
  so it gets `libva-intel-driver` instead of `intel-media-driver`
- `HAS_HYBRID_GPU`: a discrete GPU without display outputs (PCI class 0302,
  3D controller) next to an Intel or AMD GPU, as on muxless laptops. With
  NVIDIA this enables runtime power management. A card that reports as a VGA
  controller (0300), like a desktop card, doesn't count; set
  `HAS_HYBRID_GPU=1` on a MUX laptop whose dGPU reports 0300.
- `HAS_BATTERY`: a battery that powers the machine (a wireless mouse's
  doesn't count). With one, `tuned-ppd` is installed so qs-bar can switch
  power profiles; without one, tuned is set to `throughput-performance`.
- `HAS_BACKLIGHT`: a backlight device; installs `brightnessctl`
- `HAS_BLUETOOTH`: a Bluetooth adapter; installs BlueZ and blueman

Force any flag with an environment variable of the same name:

```sh
HAS_NVIDIA=0 ./install.sh --dry-run
```

It then asks once whether to include each optional module, before
installing anything:

- gaming: Steam from RPM Fusion, and Discord and Heroic from Flathub. It also
  installs xdotool, which `config/hypr/scripts/dontkillsteam.sh` uses to hide
  Steam's window instead of closing it.
- Android development: Android Studio from Google's Linux tarball, unpacked
  into `/opt/android-studio` (where the fish config looks for its bundled
  JDK), with a desktop entry in `/usr/local/share/applications`.

Choose them up front with `WITH_GAMING=0|1` and `WITH_ANDROID=0|1`, and the
installer doesn't ask about that module. A dry-run never asks, so a module
it wasn't told to include is left out:

```sh
WITH_GAMING=1 WITH_ANDROID=0 ./install.sh --dry-run
```

On NVIDIA machines the installer installs `akmod-nvidia`, CUDA and the VA-API
driver, and waits for akmods to build the kernel module before it finishes.
It doesn't edit the kernel command line. With Secure Boot on, it creates the
akmods signing key and queues it with `mokutil --import`, which asks for a
one-time password. At the next boot, choose Enroll MOK in the blue MOK
manager and enter that password, or the NVIDIA module won't load.

## Login screen

The machine boots to the graphical target and greetd, which runs a Quickshell
greeter (`greeter/`) inside a minimal Hyprland session (`greeter/hyprland.lua`)
as the `greetd` user. It uses qs-bar's theme and components, which
`greeter/config` and `greeter/components` link to. It remembers the last user
and session, and defaults to Hyprland via `start-hyprland`.

The greeter user can't read this repo in your home, so the installer copies
the greeter to `/usr/local/share/omnidots-greeter`, its fonts to
`/usr/local/share/fonts/omnidots-greeter`, and the system files in
`installer/greeter/` to `/usr/local/bin/omnidots-greeter`,
`/etc/greetd/config.toml` and `/etc/pam.d/greetd`. After changing any of them,
redeploy with:

```sh
installer/modules/88-greeter.sh
DRY_RUN=1 installer/modules/88-greeter.sh  # print the plan only
```

Login takes the password only: greetd's PAM stack uses `password-auth`, which
authselect's fingerprint feature leaves alone, so the keyring unlocks.

If the greeter fails (Quickshell errors or crashes, or Hyprland doesn't
start), tuigreet takes over. `Ctrl+Alt+Backspace` on the login screen
switches to tuigreet by hand, and `Ctrl+Alt+F2` reaches a text console.
GDM stays installed but no longer starts; `./migrate.sh` removes it (see below).

## Update

Tools that don't come from a dnf repo are installed from their upstream
releases: starship and lazygit into `~/.local/bin`, and the OpenWhispr and
Proton Mail rpms, and Android Studio when the Android module is installed.
Fonts and themes are fetched too, not kept in git: the JetBrainsMono Nerd
Font and Material Symbols Rounded at their latest versions into
`~/.local/share/fonts`, and Tela circle icons, Bibata-Modern-Ice cursors
(XCursor and hyprcursor) and the Tokyonight GTK theme at the versions pinned
in `installer/modules/35-theme-assets.sh`, into `~/.local/share/icons` and
`~/.local/share/themes`. Refresh them all with:

```sh
./update.sh            # install anything with a newer release
./update.sh --dry-run  # print what's new (`release:`) or current (`current:`)
```

It skips anything already at its latest release, so it's safe to run often.
It only refreshes Android Studio when `/opt/android-studio` exists, and never
installs it. A theme is replaced only when its pin changes. The installer
runs the same steps (`installer/modules/35-theme-assets.sh`,
`80-releases.sh` and `85-android.sh`) for the first install.

## Migrating a machine set up by the old installer

A one-off for the desktop that predates this installer: after `./install.sh`,
it removes what the refresh dropped. That's the old packages (GDM, dunst,
wofi, kanshi, waybar, wlogout, nm-applet, qt5ct, inxi, Podman, Firefox, the
starship, lazygit and Discord rpms, and tuned-ppd and brightnessctl where
there's no battery or backlight), the ProtonUp-Qt flatpak, the solopasha,
SwayNotificationCenter and atim COPRs, the Mullvad repo and keyring entry, the
theme copies and loose fonts the old installer put in `~/.icons`, `~/.themes`
and `~/.local/share/fonts`, and links to config dirs the repo no longer has.

```sh
./migrate.sh --dry-run  # print what it would remove (`remove:`), and stop
./migrate.sh            # print it, ask, then remove it
```

Anything already gone is skipped, so it's safe to re-run. Some items wait for
their replacement: GDM until greetd is the display manager, the starship and
lazygit rpms until their release binaries are in `~/.local/bin`, the Discord
rpm until the Discord flatpak is installed, and each old theme copy until its
replacement is in `~/.local/share`. A package that something staying
installed requires is kept. It logs why it keeps each one. Packages go in one
`dnf remove --noautoremove`, which shows its transaction and asks again.

Layout:

- `install.sh`: entry point
- `update.sh`: refreshes what doesn't come from a dnf repo
- `migrate.sh`: one-off removal of what the refresh dropped
- `installer/lib.sh`: logging, batched package and flatpak install, flag
  check, dry-run, upstream release install
- `installer/detect.sh`: capability detection
- `installer/modules/NN-*.sh`: one job each, run in order
- `installer/packages/*.txt`: package lists, one package per line, `#` comments

## Dotfiles

The installer's link step symlinks each entry of `config/` into
`$XDG_CONFIG_HOME` (default `~/.config`), and each desktop entry in
`applications/` into `~/.local/share/applications`. Run it on its own to
re-link an existing machine:

```sh
installer/modules/30-link.sh
DRY_RUN=1 installer/modules/30-link.sh  # print the plan only
```

It's safe to re-run. Links that already point at this repo are left alone. A
real file or directory in the way is moved to `<name>.bak.<YYYYMMDD-HHMMSS>`
first.

Files that apps rewrite with machine state are gitignored: fish's
`fish_variables` and OpenWhispr's `hypr/openwhispr-binds.conf`.

### Per-machine Hyprland settings

The Hyprland config is shared by every machine. It detects the GPUs when it
loads (`config/hypr/gpu.lua`) and gives every monitor its preferred mode.
Settings for one machine, such as a monitor's mode, position or scale, go in
`~/.config/hypr/override.lua`, which is gitignored and loaded last:

```sh
cp ~/.config/hypr/override.example.lua ~/.config/hypr/override.lua
```

### Monitors and the lid

`config/hypr/monitors.lua` lays out the outputs when Hyprland starts or
reloads and whenever a monitor is plugged in or out, on every machine:

- With an external monitor connected, the first by connector name (DP before
  HDMI-A, DP-2 before DP-10) is primary. It gets workspaces 1–10, the focus
  and cursor, qs-bar's full bar, notification popups and volume/brightness
  popup, and the XWayland primary. To prefer another output, set
  `require("monitors").primary` in `override.lua` (see `override.example.lua`).
- A laptop's built-in panel sits below the external monitor, and turns off
  while the lid is closed. Undocked, the panel is primary at its preferred
  mode with automatic position and scale.
- Closing the lid undocked locks with hyprlock and then suspends, on a machine
  with a battery. Without a battery it does nothing. While Hyprland runs on a
  laptop it holds logind's lid-switch inhibitor, so logind doesn't suspend on
  its own.
- `Super+Shift+M` turns the built-in panel off and on again, for when Hyprland
  leaves it off after an external monitor is unplugged.

A machine without a built-in panel, like the desktop, keeps its monitor rules
as they are.

## Development

```sh
tests/check.sh
```

Runs shellcheck on every installer script, then the bats suite in `tests/`.
Both are dev-only: `sudo dnf install ShellCheck bats`.

Tests run the installer in dry-run mode against recorded machines in
`tests/fixtures/<machine>/` (`lspci.txt` is `lspci -n` output, `sysfs/`
mirrors `/sys`) and assert only on the printed plan. Release lookups read
responses recorded in `tests/fixtures/releases/` (set `OMNIDOTS_RELEASES_DIR`),
so the suite runs offline.

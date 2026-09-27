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

On NVIDIA machines the installer installs `akmod-nvidia`, CUDA and the VA-API
driver, and waits for akmods to build the kernel module before it finishes.
It doesn't edit the kernel command line. With Secure Boot on, it creates the
akmods signing key and queues it with `mokutil --import`, which asks for a
one-time password. At the next boot, choose Enroll MOK in the blue MOK
manager and enter that password, or the NVIDIA module won't load.

Layout:

- `install.sh`: entry point
- `installer/lib.sh`: logging, batched package and flatpak install, flag
  check, dry-run
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

## Development

```sh
tests/check.sh
```

Runs shellcheck on every installer script, then the bats suite in `tests/`.
Both are dev-only: `sudo dnf install ShellCheck bats`.

Tests run the installer in dry-run mode against recorded machines in
`tests/fixtures/<machine>/` (`lspci.txt` is `lspci -n` output, `sysfs/`
mirrors `/sys`) and assert only on the printed plan.

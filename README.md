# omnidots

Turns a Fedora Minimal install (Everything netinstall, Minimal Install
selection) into my Hyprland desktop.

## Install

```sh
./install.sh            # detect hardware, confirm, install
./install.sh --dry-run  # print the plan, one action per line; change nothing
```

The installer detects hardware capabilities (`HAS_NVIDIA`, `HAS_AMD_GPU`,
`HAS_INTEL_GPU`) and shows them before doing anything. Force any flag with an
environment variable of the same name:

```sh
HAS_NVIDIA=0 ./install.sh --dry-run
```

Layout:

- `install.sh`: entry point
- `installer/lib.sh`: logging, batched package install, flag check, dry-run
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

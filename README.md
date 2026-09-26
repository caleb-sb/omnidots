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

## Development

```sh
tests/check.sh
```

Runs shellcheck on every installer script, then the bats suite in `tests/`.
Both are dev-only: `sudo dnf install ShellCheck bats`.

Tests run the installer in dry-run mode against recorded machines in
`tests/fixtures/<machine>/` (`lspci.txt` is `lspci -n` output, `sysfs/`
mirrors `/sys`) and assert only on the printed plan.

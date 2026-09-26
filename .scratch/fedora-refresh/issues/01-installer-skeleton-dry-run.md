# 01 — Installer skeleton that can print its plan

**What to build:** A thin, end-to-end version of the new installer. It detects the machine's GPUs, shows the flags for me to confirm, and then either prints its plan (`--dry-run`) or carries it out. At this stage the plan only covers the repos step and the core package list. It's the tracer bullet: every later installer ticket adds a module, package list or capability flag to it.

See spec: Installer architecture, Package sources (Hyprland, Quickshell), Testing Decisions.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] The top-level installer refuses to run as root, prints the detected capability flags, and asks for confirmation before doing anything.
- [ ] The detection module sets `HAS_NVIDIA`, `HAS_AMD_GPU` and `HAS_INTEL_GPU` from PCI display-class vendors. It reads the sysfs root and `lspci` output through overridable inputs.
- [ ] Any flag can be overridden by an environment variable of the same name.
- [ ] The shared library provides logging, batched package install (one dnf transaction per list), a flag check, and dry-run handling.
- [ ] Dry-run prints the actions it would take to stdout, one per line, in a stable format (e.g. `repo: …`, `pkg: …`, `run: …`), and executes nothing.
- [ ] The repos module sets dnf.conf to 10 parallel downloads and default-yes (no fastestmirror). It enables RPM Fusion free and nonfree, lionheartp/Hyprland and errornointernet/quickshell, and no other Hyprland COPR.
- [ ] A plain-text core package list (comments allowed) carries forward the still-wanted packages from the old install list. It drops dunst, wofi, kanshi, Podman, Firefox, waybar-era items and network-manager-applet's autostart use; nm-connection-editor is kept.
- [ ] The old COPR, system-install and top-level install flow are replaced by the new structure. The JaKooLit header is gone.
- [ ] A bats test harness exists, with a desktop fixture (NVIDIA RTX 3060 Ti + AMD Cezanne, no battery, no backlight). A test asserts the desktop's dry-run flags, repos and core packages.
- [ ] shellcheck passes on every shell script in the installer, and there is one documented command that runs shellcheck and the bats suite.

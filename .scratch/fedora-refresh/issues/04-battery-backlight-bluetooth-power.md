# 04 — Battery, backlight and Bluetooth packages, and the CPU power profile

**What to build:** Laptop-type tooling is installed only when the hardware exists, and the CPU power profile is set up correctly. On a machine without a battery, tuned is fixed at performance. On a machine with one, tuned-ppd is installed so the bar can switch profiles.

See spec: Installer architecture (detection), Package sources (Power profile), User Stories 30–31, 35–36.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] Detection sets `HAS_BATTERY`, `HAS_BACKLIGHT` and `HAS_BLUETOOTH` from sysfs, through the overridable sysfs root.
- [ ] brightnessctl is installed only with a backlight, and bluez, bluez-tools and blueman only with a Bluetooth adapter. These are removed from the core list.
- [ ] No battery: the plan sets tuned's throughput-performance profile once. Battery present: the plan installs tuned-ppd and doesn't pin a profile.
- [ ] All four fixtures are extended with the relevant sysfs entries, and bats asserts:
  - the desktop never gets brightnessctl or tuned-ppd, and does get throughput-performance
  - the laptops get brightnessctl and tuned-ppd
- [ ] shellcheck passes.

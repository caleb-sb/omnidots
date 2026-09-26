# 05 — Fingerprint support

**What to build:** On machines with a supported fingerprint reader, fingerprint authentication is installed and enabled, with an optional enrollment step at the end of the install. Machines without a reader get nothing.

See spec: Installer architecture (`HAS_FPRINT`), Package sources (Fingerprint), Greeter (PAM), User Stories 32–34, 97.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] Detection sets `HAS_FPRINT` by matching USB vendor IDs of known libfprint vendors: Goodix, Synaptics, Elan, Validity, Egis and FocalTech. The USB device list is readable through the overridable sysfs root.
- [ ] With a reader: install fprintd and fprintd-pam, and enable authselect's fingerprint feature (sudo and polkit). Offer interactive enrollment at the end of the run, which can be skipped. After install, `fprintd-list` confirms the device, with a warning if it doesn't.
- [ ] Without a reader: no fingerprint packages and no authselect change.
- [ ] hyprlock's fingerprint support is enabled in its config (in parallel with the password). It is harmless when no reader exists.
- [ ] bats asserts that the Core Ultra fixture (Goodix-class reader) gets the fingerprint steps, and that the desktop, hybrid and old Intel fixtures don't.
- [ ] shellcheck passes.

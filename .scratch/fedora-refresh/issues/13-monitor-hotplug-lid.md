# 13 — Monitor hotplug and lid handling

**What to build:** On any laptop, plugging in an external monitor makes it primary with the built-in panel below it. Closing the lid while docked turns the panel off. Unplugging restores the panel as the only display. Closing the lid undocked locks and suspends. None of this is keyed to a hostname, and the desktop never suspends.

See spec: Configuration (monitor handling, lid switch), User Stories 67–73.

**Blocked by:** 12

**Status:** ready-for-agent

- [x] Monitor logic runs on Hyprland's `monitor.added` and `monitor.removed` Lua events and at startup.
- [x] With an external output present, the first external output by connector name is primary: workspaces 1–N, bar and notification placement, focus and cursor, and the XWayland primary. The built-in panel sits below it. The per-machine override file can change the primary choice.
- [x] With the lid closed while docked, the built-in panel is disabled. Opening it re-enables it below the external monitor.
- [x] With no external output, the built-in panel is primary at its preferred mode with automatic position and scale.
- [x] A keybind force-enables the built-in panel (the workaround for Hyprland's stuck-off regression).
- [x] Lid close while undocked, on a machine with a battery, locks with hyprlock and then suspends. With no battery it does nothing. swaylock is not referenced anywhere.
- [x] The kanshi config is deleted.
- [x] Smoke check: the Lua files parse with luajit. The primary-selection logic is a pure function (outputs and lid state in, layout out) that has a small test run under luajit.

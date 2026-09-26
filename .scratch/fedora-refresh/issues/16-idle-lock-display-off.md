# 16 — Idle lock and display off

**What to build:** After 10 minutes idle the screen locks with hyprlock, and after 15 minutes the displays turn off. Apps that block idling, such as video players, are respected. Nothing suspends on idle.

See spec: qs-bar (Idle), User Story 89.

**Blocked by:** 15

**Status:** ready-for-agent

- [ ] The power module's idle monitor is repurposed: lock at 10 minutes and DPMS off at 15 minutes through Hyprland's dispatcher. Input wakes the displays.
- [ ] Idle inhibitors are respected.
- [ ] Suspend-on-idle and the sleep-minutes setting and its UI are removed, and saved state with the old key still loads.
- [ ] The lock action doesn't start a second hyprlock if one is already running.
- [ ] Smoke check: qs-bar loads without QML errors where a session is available.

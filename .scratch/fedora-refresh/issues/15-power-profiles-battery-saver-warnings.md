# 15 — Power profiles, battery saver and battery warnings

**What to build:** On machines with a battery, game mode switches the CPU to performance and a new battery-saver toggle switches it to power-saver. Balanced is the default. Battery saver turns itself on at 20% when discharging. I get notified at 20% and 10%. The desktop shows none of the power-profile controls.

See spec: qs-bar (Power, Battery warnings), User Stories 82–88.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] The power module uses Quickshell's PowerProfiles service. The profile is derived as: game mode → performance, else battery saver → power-saver, else balanced. Enabling one disables the other. Turning game mode off restores the derived profile.
- [ ] A battery-saver toggle appears in the power panel only when there's a laptop battery. With no battery, game mode keeps its visual effects but doesn't touch profiles.
- [ ] Battery saver auto-enables at 20% when discharging and auto-disables on AC. A manual toggle overrides the automatic behaviour until the next AC transition. State survives restarts, like the existing settings.
- [ ] The system stats module sends a normal notification at 20% and a critical one at 10% while discharging, once per threshold per discharge cycle. There is no auto-suspend.
- [ ] The battery-notify script is deleted.
- [ ] Smoke check: qs-bar loads without QML errors where a session is available.

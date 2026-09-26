# 14 — Volume and brightness popups

**What to build:** Pressing the volume or brightness keys changes the level and shows a popup at the bottom centre of the screen. Changes made elsewhere, such as in pavucontrol, don't trigger it.

See spec: qs-bar (popup module), Configuration (keys), User Stories 78–81.

**Blocked by:** 12

**Status:** ready-for-agent

- [ ] A new qs-bar popup module exposes IPC targets for volume up, volume down, mute, brightness up and brightness down. Each performs the change itself (PipeWire for volume, brightnessctl for brightness) and then shows the popup.
- [ ] The popup is centred at the bottom and shows an icon, a level bar and a percentage in the Night theme. It hides itself after a short timeout, and repeated presses extend it.
- [ ] Brightness targets do nothing when there's no backlight.
- [ ] Hyprland's volume and brightness keys call the IPC targets, keeping the locked and repeat flags. The media keys stay on playerctl, and mic mute is unchanged apart from dropping the old script.
- [ ] The old volume-control, brightness-control and global-control scripts are deleted if nothing else references them.
- [ ] qs-bar's README documents the new IPC targets.
- [ ] Smoke check: qs-bar loads without QML errors where a session is available, and the Lua files parse.

# 17 — Spotify media pill

**What to build:** While Spotify has a track loaded, a pill in the left group of the bar (after the workspaces) shows the title and artist with previous, play/pause and next buttons. Clicking the text focuses Spotify.

See spec: qs-bar (Media pill), User Stories 90–93.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] A new media module uses Quickshell's MPRIS service, filtered to the Spotify player by identity or D-Bus name. Other players and browser tabs are ignored.
- [ ] The pill sits after the workspaces in the left group. It's visible while Spotify has a track loaded (playing or paused) and hidden when Spotify closes.
- [ ] The text reads "Title — Artist", elided at about 30 characters with an ellipsis. The previous, play/pause and next icon buttons reflect whether each action is available. The play/pause icon follows playback state.
- [ ] Clicking the text focuses the Spotify window through Hyprland.
- [ ] It uses the existing bar components (BarGroup, IconButton, StyledText) and the Night theme.
- [ ] qs-bar's README documents the module.
- [ ] Smoke check: qs-bar loads without QML errors where a session is available.

# 19 — Migration command for this desktop

**What to build:** A one-off command that brings this existing desktop in line with a fresh install by removing everything the refresh dropped. It shows the full list and asks before acting, and it has a dry-run mode.

See spec: Installer architecture (migration command), User Stories 53–56.

**Blocked by:** 03, 04, 05, 06, 08, 09

**Status:** ready-for-agent

- [x] Removes packages that are no longer wanted if they're installed: GDM, dunst, wofi, kanshi, Podman, Firefox, ProtonUp-Qt, network-manager-applet (keeping nm-connection-editor), and anything else the new package lists dropped.
- [x] Disables and removes the solopasha, swaync and atim COPRs and the Mullvad repo, plus the old starship and lazygit rpms, once the release-binary versions are in place.
- [x] Deletes the leftover Mullvad keyring entry by its label, without printing any secrets.
- [x] Removes leftover vendored theme copies only if they're no longer referenced.
- [x] Prints everything it will remove and asks for confirmation. It supports dry-run, and it's safe to re-run: items already gone are skipped.
- [x] A bats test asserts the dry-run removal list against a stubbed "installed" state.
- [x] shellcheck passes.

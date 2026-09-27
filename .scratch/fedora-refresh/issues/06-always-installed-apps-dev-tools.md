# 06 — Always-installed apps and dev tools

**What to build:** Every machine gets my everyday apps and a working dev setup from the right upstream sources, including Proton VPN from Proton's official repo and Docker from Docker's repo.

See spec: Package sources, User Stories 37–42, 45–46, 49.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] Repos: Brave, Google Chrome (via fedora-workstation-repositories), the Docker CE repo, and Proton VPN.
  - Proton VPN is set up by installing the release rpm for the running Fedora version, printing the key fingerprint, and letting dnf verify it; the fingerprint is not hard-coded.
- [x] Packages: Brave, Chrome, Inkscape, Meld, VLC, OBS Studio, playerctl, rofi (wofi gone), and `proton-vpn-gnome-desktop`.
- [x] Docker: docker-ce, the CLI, containerd, and the buildx and compose plugins. The service is enabled and the user is added to the docker group, rootful. Podman is not installed.
- [x] The Flathub remote is added, with Obsidian, Spotify and Cura installed.
- [x] Dev tools: Go and rustup, plus pnpm with Node installed via pnpm's env command, bun, and Claude Code via its native installer. Each is skipped when already present.
- [x] The old fedora, flathub, js-dev and postman scripts are removed, and snap is never referenced.
- [x] bats asserts these appear in every fixture's plan.
- [x] shellcheck passes.

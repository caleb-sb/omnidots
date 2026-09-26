# 07 — Update command and GitHub-release installs

**What to build:** A single update command refreshes everything that doesn't come from a dnf repo, skipping anything already current. The installer uses the same path for the first install of starship, lazygit, OpenWhispr and Proton Mail.

See spec: Installer architecture (update command), Package sources (starship, lazygit, OpenWhispr, Proton Mail), User Stories 43–44, 50–51.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The shared library has a GitHub-release fetch helper. It resolves the latest release, compares it with the installed version, and installs a binary into the user's local bin directory or installs an rpm via dnf. It skips when versions match.
- [ ] starship and lazygit are installed from upstream release binaries. The atim COPRs are no longer used.
- [ ] OpenWhispr is installed and updated from its GitHub release rpm.
- [ ] Proton Mail is installed and updated from Proton's official rpm download.
- [ ] The update command runs standalone and supports dry-run. The installer invokes the same code for first install.
- [ ] bats asserts the dry-run plan lists these items. Network lookups are stubbed in tests so the suite runs offline.
- [ ] shellcheck passes.

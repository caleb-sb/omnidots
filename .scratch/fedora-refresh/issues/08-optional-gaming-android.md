# 08 — Optional gaming and Android modules

**What to build:** At the start of the install I'm asked once whether to include gaming and Android development. Choosing gaming installs Steam, Discord and Heroic. Choosing Android installs Android Studio where my shell expects it, and the update command keeps it current.

See spec: Package sources (Flathub, gaming), User Stories 6, 47–48, 52.

**Blocked by:** 06, 07

**Status:** ready-for-agent

- [ ] One up-front prompt covers both modules. Env vars can preselect them (for non-interactive runs and tests).
- [ ] Gaming: Steam from RPM Fusion, and Discord and Heroic from Flathub. No ProtonUp-Qt, no GameMode.
- [ ] Android: the official Android Studio tarball is installed into /opt with a desktop entry. The update command refreshes it only when the Android module was installed.
- [ ] The dontkillsteam helper script keeps working.
- [ ] bats asserts both modules are absent by default and present only when chosen, on at least two fixtures.
- [ ] shellcheck passes.

# 09 — Theme assets fetched at install time

**What to build:** Icons, cursors, the GTK theme and fonts are downloaded at pinned or latest versions during install and by the update command, instead of being stored in git. The repo drops about 180MB of vendored assets.

See spec: Theme, User Stories 58–61.

**Blocked by:** 07

**Status:** ready-for-agent

- [x] Tela circle icons (purple, plus the dark variant), Bibata-Modern-Ice cursors and the hyprcursor Bibata variant are fetched at pinned versions into the user icon directories.
- [x] Fausto-Korpsvart's Tokyonight-GTK-Theme is installed at a pinned commit using its libadwaita option, with the tweak closest to Tokyo Night Night. sassc and gtk-murrine-engine are in the package list.
- [x] The JetBrainsMono Nerd Font comes from the latest release, and the Material Symbols Rounded font is fetched. Both are refreshed by the update command, and the font cache is rebuilt.
- [x] The vendored icons, cursors, hyprcursors and Andromeda GTK theme directories are deleted from the repo, along with the old gtk, hyprcursor and fonts scripts.
- [x] bats asserts the dry-run plan lists each asset fetch, with network stubbed.
- [x] shellcheck passes.

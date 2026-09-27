# 10 — Tokyo Night Night everywhere

**What to build:** Every themed app uses the Tokyo Night Night palette, and Qt apps launched from Hyprland are themed correctly.

See spec: Theme, User Stories 57, 61–62.

**Blocked by:** 09

**Status:** ready-for-agent

- [x] Night palettes are in place for kitty, tmux, Kvantum (with kvantum.kvconfig pointing at it), qt6ct, rofi, hyprlock and the Hyprland active and inactive borders.
- [x] Neovim uses tokyonight.nvim with the night style.
- [x] qs-bar's theme is verified as Night, and corrected if not.
- [x] Hyprland's startup gsettings switch to the Tokyonight GTK theme, Tela icons, Bibata cursors and prefer-dark. The GTK settings.ini files agree.
- [x] The Catppuccin, Gruvbox and Rose Pine Kvantum and qt5ct themes and the Gruvbox and Storm kitty themes are deleted. The qt5ct config is replaced by qt6ct.
- [x] Smoke checks: the Lua config parses with luajit, and kitty and tmux configs reference only files that exist.

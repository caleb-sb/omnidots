# 12 — Hyprland cleanup and runtime detection

**What to build:** One Hyprland config that works unchanged on every machine. It detects hardware at runtime, loads an optional untracked per-machine override, sets the environment GUI apps need, and drops dead autostarts and rules.

See spec: Configuration, User Stories 20, 62, 66, 74–77.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [x] NVIDIA env vars are set only when the NVIDIA driver is loaded, checked at runtime. On hybrid machines the integrated GPU is ordered first for Hyprland's DRM device selection.
- [x] An optional, gitignored per-machine override file is loaded last if present. The DP-2 3840x2160@144 scale 1.5 rule moves into it (document how to create it). A generic preferred/auto fallback applies otherwise.
- [x] The Qt platform theme (qt6ct), Kvantum style, EDITOR and XDG dirs are set through Hyprland's env.
- [x] Autostart drops kanshi and nm-applet and keeps blueman-applet, hyprpolkitagent, qs-bar, hyprpaper and cliphist.
- [x] The KDE polkit window rules are replaced with float and opacity rules for hyprpolkitagent's window class. The nm-applet rules are removed.
- [x] The clipboard bind and cliphist script use rofi consistently. The launcher bind uses rofi.
- [x] The OpenWhispr bind stays in the Lua keybindings only.
- [x] Smoke check: all Hyprland Lua files parse with luajit.

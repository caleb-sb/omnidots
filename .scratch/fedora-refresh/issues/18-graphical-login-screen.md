# 18 — Graphical login screen

**What to build:** The machine boots to a Tokyo Night login screen built with Quickshell. It matches qs-bar and hyprlock and launches Hyprland. Login is by password so the keyring unlocks. If the greeter fails, a terminal greeter takes over, so I can never be locked out.

See spec: Greeter, Package sources (Greeter), User Stories 94–98.

**Blocked by:** 01, 05, 10

**Status:** ready-for-agent

- [x] A new Quickshell greeter config uses Quickshell's greetd service and shares qs-bar's theme and components (shared, not copied).
- [x] It handles the multi-step PAM conversation (info, error and secret prompts), and shows the time, a user field and a password field.
- [x] It lists sessions, with Hyprland (via start-hyprland) as the default.
- [x] The greeter runs inside a minimal Hyprland session launched by greetd. If it exits abnormally, greetd falls back to tuigreet.
- [x] The installer module installs greetd and tuigreet, deploys the greeter config to a system location greetd can read, and enables greetd. It sets the default target to graphical and makes sure greetd's PAM stack is password-only, including the gnome-keyring module so the keyring unlocks at login.
- [x] The greeter step appears in the dry-run plan, and bats asserts it for every fixture.
- [x] shellcheck passes. Smoke check: the greeter config loads under Quickshell without QML errors where a session is available.

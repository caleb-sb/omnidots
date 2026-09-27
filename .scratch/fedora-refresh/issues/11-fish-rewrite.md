# 11 — fish rewrite

**What to build:** An idiomatic fish config that starts cleanly on a fresh machine, where tools like cargo, bun or the Android SDK may not be installed yet.

See spec: fish, User Stories 63–65.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [x] The config is split into per-tool conf.d snippets (env, pnpm including the pnpm-12 PATH fix, bun, cargo, android, kitty, starship). Each checks that its tool or directory exists before doing anything.
- [x] Paths are added with fish's path helper, and the home directory is never hard-coded.
- [x] `lg` is an abbreviation. The kitten-ssh abbreviation is kept. The start-hyprland aliases are removed.
- [x] The home-manager scaffolding is removed. The env vars GUI apps need are not set here, since they move to Hyprland in ticket 12. EDITOR can stay for shells.
- [x] Smoke check: every fish file passes fish's syntax check, and a login shell with an empty HOME-like environment (no cargo, bun or Android SDK) starts with no errors.

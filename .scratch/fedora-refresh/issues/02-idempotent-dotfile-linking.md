# 02 — Idempotent dotfile linking

**What to build:** A link step that symlinks each config directory into the XDG config dir. It can run on its own, and it's safe to re-run on a machine that is already set up. Machine-state files that apps rewrite stay out of git.

See spec: Installer architecture (link step), User Stories 16–20.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] The link step runs standalone and as part of the installer, and appears in the dry-run plan.
- [x] An existing symlink that already points at the right place is left alone.
- [x] An existing real file or directory is moved aside with a timestamped backup name before linking.
- [x] Re-running the step produces no errors and no nested or duplicate links.
- [ ] fish's universal variables file and OpenWhispr's auto-generated Hyprland binds file are gitignored and removed from tracking. The stale keybindings backup file is deleted.
- [x] The existing desktop-entry copy step (the nvim .desktop file) is folded into the link step or kept working.
- [x] A bats test exercises the link step against a temporary HOME. It covers a fresh HOME, a re-run, and a pre-existing real directory that gets backed up.
- [x] shellcheck passes.

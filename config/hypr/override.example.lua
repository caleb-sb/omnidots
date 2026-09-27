-- Per-machine Hyprland overrides. To use:
--
--   cp ~/.config/hypr/override.example.lua ~/.config/hypr/override.lua
--
-- then edit override.lua. hyprland.lua loads it last, if it exists, so
-- anything here wins over the shared config. override.lua is gitignored and
-- stays on this machine; keep monitor modes, positions and other one-machine
-- settings here.

-- Example: the desktop's 4K monitor at 144 Hz, scaled 1.5. Without a rule
-- like this, every output uses its preferred mode with automatic position
-- and scale.
hl.monitor({
    output   = "DP-2",
    mode     = "3840x2160@144",
    position = "0x0",
    scale    = 1.5,
})

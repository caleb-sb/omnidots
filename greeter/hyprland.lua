-- The login screen's Hyprland session: just enough compositor for the
-- Quickshell greeter. omnidots-greeter (installer/greeter/omnidots-greeter.sh)
-- starts Hyprland with this file as its config, as the greetd user.
-- https://wiki.hypr.land/Configuring/Start/

-- The greeter first, so a mistake further down can't keep it from starting.
-- `omnidots-greeter quickshell` runs it, records how it ended, and ends this
-- session.
local greeter = os.getenv("OMNIDOTS_GREETER") or "/usr/local/bin/omnidots-greeter"
hl.on("hyprland.start", function()
    hl.exec_cmd(greeter .. " quickshell")
end)

-- A way out if the greeter shows up but doesn't work: ending this session
-- makes omnidots-greeter fall back to tuigreet.
hl.bind("CTRL + ALT + BackSpace", hl.dsp.exit())

-- Every output at its preferred mode; the greeter puts its background on all
-- of them and the login form on the one focused first.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Then the desktop's own monitor rules, from its override.lua, which
-- 88-greeter.sh copies here as desktop-monitors.lua. Each output gets the
-- scale it has on the desktop, so the login form comes out the size of
-- hyprlock's input field; with automatic scale it can be much bigger (e.g.
-- a 2560x1600 panel the desktop scales 1.25). Only its hl.monitor calls are
-- kept; the rest of it is meant for the desktop.
local config_dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local desktop_monitors = config_dir .. "desktop-monitors.lua"
local function ignore()
    return setmetatable({}, { __index = ignore, __call = ignore })
end
local rules = {}
local env = setmetatable({
    hl = setmetatable({ monitor = function(rule) rules[#rules + 1] = rule end }, { __index = ignore }),
    require = ignore,
}, { __index = _G })
local chunk = loadfile(desktop_monitors, "t", env)
if chunk then
    if setfenv then setfenv(chunk, env) end
    pcall(chunk)
    for _, rule in ipairs(rules) do
        hl.monitor(rule)
    end
end

-- The cursor theme lives in the user's home, which this user can't read, so
-- Hyprland's default cursor it is.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        border_size = 0,
        gaps_in     = 0,
        gaps_out    = 0,
    },

    decoration = {
        rounding = 0,
        blur     = { enabled = false },
        shadow   = { enabled = false },
    },

    animations = {
        enabled = false,
    },

    -- Same as the desktop's (config/hypr/hyprland.lua), so the password is
    -- typed the way it was set.
    input = {
        kb_layout = "us",
    },

    misc = {
        -- Tokyo Night (night) until the greeter draws.
        background_color                = "rgba(1a1b26ff)",
        disable_hyprland_logo           = true,
        disable_splash_rendering        = true,
        force_default_wallpaper         = 0,
        -- Started directly, not by start-hyprland, whose watchdog would
        -- restart a crashed greeter session in safe mode instead of letting
        -- omnidots-greeter fall back to tuigreet.
        disable_watchdog_warning        = true,
        disable_hyprland_guiutils_check = true,
        key_press_enables_dpms          = true,
        mouse_move_enables_dpms         = true,
    },

    ecosystem = {
        no_update_news   = true,
        no_donation_nag  = true,
    },
})

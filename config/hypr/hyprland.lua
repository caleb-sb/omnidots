-- Hyprland config (Lua format, 0.55+)
-- Refer to https://wiki.hypr.land/Configuring/Start/

--------------------
---- MY PROGRAMS ----
--------------------

-- Globals, so the required files below can see them.
browser = "brave"
editor  = "nvim"
file    = "thunar"
term    = "kitty"
mainMod = "SUPER"

------------------
---- MONITORS ----
------------------

-- Every output at its preferred mode, placed and scaled automatically. Modes
-- for one machine go in override.lua (see override.example.lua). On a laptop,
-- monitors.lua places the outputs and turns the built-in panel off and on.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
-- Set here, not in the shell, so apps launched from Hyprland get them too:
-- Qt apps are themed, and everything finds the XDG dirs and the editor.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("EDITOR", editor)

local home = os.getenv("HOME")
hl.env("XDG_CONFIG_HOME", home .. "/.config")
hl.env("XDG_DATA_HOME",   home .. "/.local/share")
hl.env("XDG_CACHE_HOME",  home .. "/.cache")
hl.env("XDG_STATE_HOME",  home .. "/.local/state")

-- NVIDIA and multi-GPU variables, detected on this machine (see gpu.lua).
require("gpu").apply()

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        allow_tearing = false,
        border_size   = 3,
        gaps_in       = 5,
        gaps_out      = 20,
        layout        = "dwindle",

        -- Tokyo Night (night): blue to cyan, and the background.
        col = {
            active_border   = { colors = { "rgba(7aa2f7ff)", "rgba(7dcfffff)" }, angle = 45 },
            inactive_border = "rgba(1a1b26ff)",
        },
    },

    decoration = {
        rounding = 10,

        blur = {
            enabled = true,
            passes  = 2,
            size    = 3,
        },

        shadow = {
            enabled      = true,
            color        = "rgba(1a1a1aee)",
            range        = 4,
            render_power = 3,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        force_split    = 2,
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        -- Input wakes displays that qs-bar's idle monitor turned off.
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
})

---- Animations ----

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("liner",    { type = "bezier", points = { { 1, 1 },      { 1, 1 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "liner",   style = "loop" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        follow_mouse   = 1,
        force_no_accel = true,
        kb_layout      = "us",
        sensitivity    = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("qs -p ~/.config/qs-bar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-purple-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'FreeSans'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-----------------
---- SOURCES ----
-----------------

require("keybindings")
require("windowrules")

-- This machine's overrides, if any, last so they win. Loaded with require so
-- Hyprland reloads when the file changes.
local config_dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local override = io.open(config_dir .. "override.lua", "r")
if override then
    override:close()
    require("override")
end

-- Monitor layout, primary output and the lid (see monitors.lua). Last, so it
-- sees the primary override.lua picks.
require("monitors").setup()

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

hl.monitor({
    output   = "DP-2",
    mode     = "3840x2160@144",
    position = "0x0",
    scale    = 1.5,
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

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

        col = {
            active_border   = { colors = { "rgba(0272E7ff)", "rgba(45CAFFff)" }, angle = 45 },
            inactive_border = "rgba(24283bff)",
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
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("kanshi")
    hl.exec_cmd("qs -p ~/.config/qs-bar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-purple-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'FreeSans'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Andromeda-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-----------------
---- SOURCES ----
-----------------

require("keybindings")
require("windowrules")

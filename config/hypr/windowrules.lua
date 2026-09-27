-- Window rules
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

---- Opacity ----

hl.window_rule({ match = { class = "^(org.mozilla.firefox)$" }, opacity = "0.90 0.90" })
hl.window_rule({ match = { class = "^(Brave-browser)$" },       opacity = "0.90 0.90" })
hl.window_rule({ match = { class = "^(Google-chrome)$" },       opacity = "0.90 0.90" })
hl.window_rule({ match = { class = "^(Spotify)$" },             opacity = "0.80 0.80" })
hl.window_rule({ match = { class = "^(code-url-handler)$" },    opacity = "0.80 0.80" })
hl.window_rule({ match = { class = "^(kitty)$" },               opacity = "0.90 0.90" })
hl.window_rule({ match = { class = "^(org.kde.ark)$" },         opacity = "0.80 0.80" })
hl.window_rule({ match = { class = "^(nwg-look)$" },            opacity = "0.80 0.80" })
hl.window_rule({ match = { class = "^(qt6ct)$" },               opacity = "0.80 0.80" })

hl.window_rule({ match = { class = "^(gnome-boxes)$" }, opacity = "0.80 0.80" }) -- Boxes-Gtk
hl.window_rule({ match = { class = "^(discord)$" },     opacity = "0.90 0.90" }) -- Discord-Electron

hl.window_rule({ match = { class = "^(pavucontrol)$" },          opacity = "0.80 0.70" })
hl.window_rule({ match = { class = "^(blueman-manager)$" },      opacity = "0.80 0.70" })
hl.window_rule({ match = { class = "^(nm-applet)$" },            opacity = "0.80 0.70" })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, opacity = "0.80 0.70" })
hl.window_rule({ match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, opacity = "0.80 0.70" })

---- Floating ----

hl.window_rule({ match = { class = "^(qt6ct)$" },                 float = true })
hl.window_rule({ match = { class = "^(nwg-look)$" },              float = true })
hl.window_rule({ match = { class = "^(org.kde.ark)$" },           float = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" },           float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" },       float = true })
hl.window_rule({ match = { class = "^(nm-applet)$" },             float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" },  float = true })
hl.window_rule({ match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })

---- xwaylandvideobridge ----

hl.window_rule({
    name  = "xwaylandvideobridge",
    match = { class = "^(xwaylandvideobridge)$" },

    opacity          = "0.0 override",
    no_anim          = true,
    no_initial_focus = true,
    max_size         = { 1, 1 },
    no_blur          = true,
})

---- qs-bar ----

-- Blur behind the see-through bar. ignore_alpha skips the empty, fully
-- transparent part of the bar's window (where popouts open).
hl.layer_rule({
    name  = "qs-bar-blur",
    match = { namespace = "^(qs-bar)$" },

    blur         = true,
    ignore_alpha = 0.2,
})

-- Keybindings
-- https://wiki.hypr.land/Configuring/Basics/Binds/

---- Apps and actions ----

hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd("~/.config/hypr/scripts/dontkillsteam.sh"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + W",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + X",         hl.dsp.exec_cmd("qs -p ~/.config/qs-bar ipc call power toggle"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(term))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(file))
hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd("pkill -x rofi || rofi -show drun"))
hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | wl-copy'))
hl.bind(mainMod .. " + CTRL + P",  hl.dsp.exec_cmd('grim -g "$(slurp)"'))
hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("pkill -x rofi || ~/.config/hypr/scripts/cliphist.sh c"))
hl.bind(mainMod .. " + G",         hl.dsp.layout("togglesplit"))

---- Focus movement ----

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

---- Workspaces ----

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
    hl.bind(mainMod .. " + ALT + " .. key,     hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

---- Special workspace (scratchpad) ----

hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special", follow = false }))
hl.bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special())

---- Window movement / resizing ----

hl.bind(mainMod .. " + SHIFT + CTRL + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + CTRL + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + CTRL + down",  hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -30, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

---- Media and hardware keys ----

hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("~/.config/hypr/scripts/volumecontrol.sh -o m"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("~/.config/hypr/scripts/volumecontrol.sh -i m"), { locked = true })
hl.bind("XF86AudioPlay",    hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true })
hl.bind("XF86AudioPause",   hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true })
hl.bind("XF86AudioNext",    hl.dsp.exec_cmd("playerctl next"),                               { locked = true })
hl.bind("XF86AudioPrev",    hl.dsp.exec_cmd("playerctl previous"),                           { locked = true })

hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("~/.config/hypr/scripts/volumecontrol.sh -o d"),    { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("~/.config/hypr/scripts/volumecontrol.sh -o i"),    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/brightnesscontrol.sh i"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/brightnesscontrol.sh d"),   { locked = true, repeating = true })

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("swaylock && systemctl suspend"), { locked = true })

---- OpenWhispr ----
-- The one place this bind lives. OpenWhispr also writes it to
-- ~/.config/hypr/openwhispr-binds.conf (gitignored), in the legacy format this
-- Lua config never loads.
hl.bind("CTRL + ALT + K", hl.dsp.exec_cmd("dbus-send --session --type=method_call --dest=com.openwhispr.App /com/openwhispr/App com.openwhispr.App.Toggle"))

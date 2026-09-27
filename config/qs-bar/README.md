# qs-bar

Quickshell bar, built one module at a time. Tokyo Night (night).

    qs -p ~/.config/qs-bar                          # run
    qs -p ~/.config/qs-bar ipc call bluetooth toggle   # open/close the BT panel
    qs -p ~/.config/qs-bar ipc call audio toggle       # open/close the audio panel
    qs -p ~/.config/qs-bar ipc call network toggle     # open/close the network panel
    qs -p ~/.config/qs-bar ipc call notifications toggle   # also: dnd, clear
    qs -p ~/.config/qs-bar ipc call clipboard toggle   # open/close clipboard history
    qs -p ~/.config/qs-bar ipc call display toggle     # toggle render scale 1.5x <-> 2.5x
    qs -p ~/.config/qs-bar ipc call calendar toggle    # open/close the calendar
    qs -p ~/.config/qs-bar ipc call volume up          # also: down, mute (shows the popup)
    qs -p ~/.config/qs-bar ipc call brightness up      # also: down (shows the popup)

Needs the **Material Symbols Rounded** font (installed to ~/.local/share/fonts).

## Layout

- `config/Theme.qml`: palette, sizes, motion curves (caelestia's M3 expressive curves)
- `components/`: shared primitives (Anim, MaterialIcon, StateLayer, Switch, ...)
- `bar/Bar.qml`: bar window. It's taller than the bar and input-masked so popouts live inside it
- `bar/Popout.qml`: popout host. It draws bar + popout as one SDF shape
  (`shaders/surface.frag`) so popouts grow out of the bar with curved joins and a
  slight jelly stretch, like caelestia's blob drawers
- `modules/<name>/`: a bar item plus its panel. The bar wires them together:

      SomeIcon { onClicked: popout.toggle("name", this, somePanelComponent) }

## Bluetooth

- Left click the icon to open the panel. Right click toggles the adapter.
- Click a device row to connect or disconnect it, pair it if it's new, or cancel pairing.
- Hover a paired device to show the forget button.
- Passkey prompts come from your system agent (blueman-applet).

## Audio

- Left click the icon to open the panel. Right click mutes the output, middle click mutes the input, and scrolling changes the output volume.
- A red mic_off badge appears next to the icon while the input is muted.
- The panel has a mute toggle, a volume slider and a device picker for both output and input. Picking a device makes it the PipeWire default.
- "Sound settings" opens pavucontrol.

## Volume and brightness popup

Hyprland's volume and brightness keys call these IPC targets. Each one changes
the level itself and then shows a popup at the bottom centre of the primary
screen, with an icon, a level bar and the percentage. It fades out after
1.5 s, and each further press restarts that.

- `volume up | down | mute` works on the default output through PipeWire.
  Up and down step 5%, stop at 100% and unmute.
- `brightness up | down` steps the backlight 5% through brightnessctl, never
  below 1%. On a machine without a backlight they do nothing and show no popup.
- Only these targets show the popup. Volume changed anywhere else, such as in
  pavucontrol or the audio panel, doesn't.
- Mic mute (a plain `wpctl` bind) and the media keys (playerctl) have no popup.

## Network

- Uses Quickshell.Networking, so NetworkManager must be running.
- Left click the icon to open the panel. Right click toggles Wi-Fi.
- The icon turns yellow when you're connected but have no internet.
- The panel scans while it's open and groups networks into Connected, Saved and Available, with one entry per SSID.
- Click a network to connect or disconnect. A new secured network opens an inline password field: Enter connects, Esc cancels. A wrong password shows an error and reopens the field.
- Hover a saved network to show the forget button.
- Enterprise (802.1X) networks and "Network settings" open nm-connection-editor.
- The Ethernet row shows cable state and link speed, and can connect or disconnect.

## Notifications

- The bar is the notification daemon, replacing dunst. Stop dunst before starting the bar (`systemctl --user stop dunst`). While another daemon holds the name, the bar keeps retrying and takes over once it's free. dunst D-Bus-activates again on the next notification after the bar exits.
- Pop-ups appear top-right under the bar and slide in from the screen edge.
  - Each shows a countdown line, and hovering pauses it. The default timeout is 5 s. Critical notifications stay until dismissed.
  - Clicking a pop-up runs its default action or hides it. The × dismisses it.
- Hidden pop-ups stay in the panel's history, grouped by app with the most recent app on top, and keep their action buttons while the sender is still around.
- A collapsed group shows its newest notification. Click the header or "+N more" to expand it, and use the × on hover to clear the whole group. History and do-not-disturb are saved to `~/.local/state/quickshell/by-shell/<id>/notifications.json`.
- Left click the bell to open the panel. Right click toggles do-not-disturb, which hides pop-ups except critical ones. Opening the panel hides any pop-ups that are showing.
- The panel has Do not disturb and Clear all tiles.

## Clipboard

History comes from cliphist, which the `wl-paste --watch cliphist store`
lines in the Hyprland config fill. The panel reloads whenever the clipboard changes.

- Click an entry, or press Enter, to copy it back to the clipboard and close the panel.
- Type to search. "image" matches picture entries.
- Up and Down move the selection. Shift+Delete removes the selected entry, and Esc clears the search, then closes the panel.
- Hover an entry to delete it. The footer clears the whole history on a second click.
- Image previews are decoded into Quickshell's cache dir (`…/clipboard/<id>.png`). Previews older than a week are pruned at startup.

## Display scale

The screen icon at the left of the icon row toggles the main monitor between
1.5x (the default) and 2.5x, for viewing from further away. The icon is blue and filled when enlarged,
and grey at 1.5x. It keeps the current mode, refresh rate and position.
The change only affects the running session, so a Hyprland config reload goes
back to the 1.5x set in `hyprland.lua`.

## Clock and calendar

The clock sits in the middle of the bar and shows the time and date, e.g.
`11:50 AM  Sat, Sep 26`. Click it to open the calendar.

- **Scrolling:** scroll the month name to change month and the year to change
  year. Scrolling anywhere on the day grid also steps by month.
- **Buttons:** the arrows step by one month. A "Today" pill appears once you're
  away from the current month and jumps back to it.
- **Layout:** weeks start on the locale's first day, which is Sunday for en_US.
  Weekends are magenta and today is filled blue.

## Workspaces

The left of the bar shows Hyprland workspaces 1 to 5, or more if a higher one
is in use (up to 10). Click one to switch to it.

- **Dots:** inactive workspaces are dots. Workspaces with windows get a larger,
  brighter dot than empty ones.
- **Active:** the active workspace is a soft magenta pill with its number
  in magenta. It slides, with a short stretch, when you switch.
- **App name:** the focused app's name follows the dots in bold, after a thin
  divider and a blue Fedora logo. The name comes from the app's desktop entry
  (e.g. "Firefox"), falls back to its app id, and is cut off with "…" past
  220 px.
- **Dispatch:** the Lua config needs Lua syntax, so clicks send
  `hl.dsp.focus({ workspace = N })` rather than `workspace N`.

## Power and device monitor

The leftmost pill shows memory used, disk used on `/`, and battery
percentage (only on machines with a battery). Memory refreshes every 5 s,
disk every 30 s. A gamepad glyph shows while game mode is on.

Click the pill to open the **system panel**:

- **CPU and GPU:** load and temperature (CPU from `/proc/stat` and
  k10temp/coretemp, GPU from `nvidia-smi`, hidden without one). These run
  every 2 s, and only while the panel is open.
- **Memory and disk:** used of total, with the NVMe temperature.
  Temperatures turn yellow, then red, when hot.
- **Game mode:** turns off Hyprland blur and animations, makes every
  window fully opaque (a catch-all window rule that overrides the per-app
  opacity rules), sets XWayland `force_zero_scaling` so X11 games render at
  native resolution, and hides notification popups (critical ones still
  show). It is applied live with `hyprctl eval`, reapplied after a config
  reload, and undone when switched off.

Press Super+X for the **power panel**. A power button slides out at the left
of the pill while it's open; clicking it closes the panel.

- **Actions:** lock (hyprlock), log out, restart and shut down. Keys run
  them straight away, as wlogout did: **L** lock, **E** log out, **R**
  restart, **S** shut down (Esc closes). With the mouse, the last three
  turn red and need a second click within 3 s.
- **Battery:** percentage and time left, when there is a battery.
- **Sleep after:** suspend after 5, 15, 30 or 60 idle minutes, or never. Idle
  inhibitors (video players, games) hold it off.

Game mode and the sleep timer are saved to `power.json` in the Quickshell
state dir. IPC: `ipc call power toggle | gameMode`, `ipc call system toggle`.

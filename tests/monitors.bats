#!/usr/bin/env bats
#
# Monitor and lid handling (config/hypr/monitors.lua). The layout is a pure
# function tested under luajit; the Hyprland glue runs under the stub hl of
# hypr-stub.lua against fake machines. Nothing is launched or reloaded.

bats_require_minimum_version 1.5.0

CONFIG="$BATS_TEST_DIRNAME/../config"

setup() {
  command -v luajit >/dev/null || skip "luajit is not installed"
  # Where the config tells qs-bar the primary output; never the real one.
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
  mkdir -p "$XDG_RUNTIME_DIR"
}

# layout <outputs> [<state>] — the layout for the outputs (a Lua list of
# { name =, height = } with height in logical px) and state (a Lua table with
# lid_closed and primary), one line each: `primary <name>`, then a rule per
# output, `<output> <position>` or `<output> disabled`.
layout() {
  luajit -e "
    package.path = '$CONFIG/hypr/?.lua;' .. package.path
    local l = require('monitors').layout($1, ${2:-{\}})
    print('primary ' .. tostring(l.primary))
    for _, r in ipairs(l.rules) do
      print(r.output .. ' ' .. (r.disabled and 'disabled' or r.position))
    end"
}

# fake_panel <root> [<connector>] — a connected built-in panel under <root>/sys.
fake_panel() {
  mkdir -p "$1/sys/class/drm/card1-${2:-eDP-1}"
  echo connected >"$1/sys/class/drm/card1-${2:-eDP-1}/status"
}

# fake_battery <root> — a laptop battery, next to a wireless mouse's.
fake_battery() {
  mkdir -p "$1/sys/class/power_supply/BAT0" "$1/sys/class/power_supply/hidpp_battery_0"
  echo Battery >"$1/sys/class/power_supply/BAT0/type"
  echo Battery >"$1/sys/class/power_supply/hidpp_battery_0/type"
  echo Device >"$1/sys/class/power_supply/hidpp_battery_0/scope"
}

# fake_lid <root> open|closed — the ACPI lid state.
fake_lid() {
  mkdir -p "$1/proc/acpi/button/lid/LID0"
  printf 'state:      %s\n' "$2" >"$1/proc/acpi/button/lid/LID0/state"
}

PANEL="{ name = 'eDP-1', width = 1920, height = 1200, scale = 1 }"
EXTERNAL="{ name = 'HDMI-A-1', width = 3840, height = 2160, scale = 1.5 }"

# hypr <root> <monitors> <after> — load hyprland.lua (without this machine's
# override.lua) under the stub on the machine at <root>, with hl.get_monitors()
# returning <monitors>, then run the Lua in <after>. Prints what the config
# asks of Hyprland after it loads (see hypr-stub.lua), minus env lines.
hypr() {
  local dir="$BATS_TEST_TMPDIR/hypr"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    cp "$CONFIG"/hypr/*.lua "$dir/"
    rm -f "$dir/override.lua"
  fi
  local out
  out="$(luajit "$BATS_TEST_DIRNAME/hypr-stub.lua" "$dir" "
    require('monitors').root = '$1'
    MONITORS = $2
    dofile(CONFIG_DIR .. '/hyprland.lua')
    print('--')
    $3")" || return
  sed '1,/^--$/d' <<<"$out"
}

# refute_output_matches <ERE> — no line of $output matches.
refute_output_matches() {
  if grep -qE -- "$1" <<<"$output"; then
    printf 'unexpected match: %s\n--- output ---\n%s\n' "$1" "$output" >&2
    return 1
  fi
}

# primary_file — the primary output the config told qs-bar about.
primary_file() {
  cat "$XDG_RUNTIME_DIR/omnidots-primary-output"
}

@test "undocked laptop: the panel is primary at an automatic position" {
  run -0 layout "{ { name = 'eDP-1', height = 1200 } }"
  [ "$output" = "$(printf '%s\n' 'primary eDP-1' 'eDP-1 auto')" ]
}

@test "docked, lid open: the external is primary at the origin and the panel sits below it" {
  run -0 layout "{ { name = 'eDP-1', height = 1200 }, { name = 'HDMI-A-1', height = 1440 } }"
  [ "$output" = "$(printf '%s\n' 'primary HDMI-A-1' 'HDMI-A-1 0x0' 'eDP-1 0x1440')" ]
}

@test "docked, lid closed: the panel is disabled" {
  run -0 layout "{ { name = 'eDP-1', height = 1200 }, { name = 'HDMI-A-1', height = 1440 } }" \
    "{ lid_closed = true }"
  [ "$output" = "$(printf '%s\n' 'primary HDMI-A-1' 'HDMI-A-1 0x0' 'eDP-1 disabled')" ]
}

@test "undocked, lid closed: the panel stays on as the only display" {
  # A disabled panel is listed without a height.
  run -0 layout "{ { name = 'eDP-1' } }" "{ lid_closed = true }"
  [ "$output" = "$(printf '%s\n' 'primary eDP-1' 'eDP-1 auto')" ]
}

@test "two externals: the first by connector type, then number, is primary; the other goes right" {
  run -0 layout "{ { name = 'eDP-1', height = 1200 }, { name = 'HDMI-A-1', height = 1080 },
    { name = 'DP-10', height = 1440 }, { name = 'DP-2', height = 1600 } }"
  [ "$output" = "$(printf '%s\n' 'primary DP-2' 'DP-2 0x0' 'DP-10 auto-right' \
    'HDMI-A-1 auto-right' 'eDP-1 0x1600')" ]
}

@test "the per-machine primary wins when it's connected, as a name or a list of names" {
  local outputs="{ { name = 'eDP-1', height = 1200 }, { name = 'DP-1', height = 1440 },
    { name = 'HDMI-A-1', height = 1080 } }"
  run -0 layout "$outputs" "{ primary = 'HDMI-A-1' }"
  [ "$output" = "$(printf '%s\n' 'primary HDMI-A-1' 'HDMI-A-1 0x0' 'DP-1 auto-right' 'eDP-1 0x1080')" ]

  run -0 layout "$outputs" "{ primary = { 'DP-3', 'HDMI-A-1' } }"
  [ "${lines[0]}" = 'primary HDMI-A-1' ]

  # Not connected: the usual choice.
  run -0 layout "$outputs" "{ primary = 'DP-3' }"
  [ "${lines[0]}" = 'primary DP-1' ]
}

@test "the per-machine primary can be the panel while docked, but not with the lid closed" {
  local outputs="{ { name = 'eDP-1', height = 1200 }, { name = 'DP-1', height = 1440 } }"
  run -0 layout "$outputs" "{ primary = 'eDP-1' }"
  [ "$output" = "$(printf '%s\n' 'primary eDP-1' 'eDP-1 0x0' 'DP-1 auto-right')" ]

  run -0 layout "$outputs" "{ primary = 'eDP-1', lid_closed = true }"
  [ "$output" = "$(printf '%s\n' 'primary DP-1' 'DP-1 0x0' 'eDP-1 disabled')" ]
}

@test "desktop without a built-in panel: a primary, but no monitor rules" {
  run -0 layout "{ { name = 'DP-2', height = 1440 } }"
  [ "$output" = 'primary DP-2' ]

  run -0 layout "{ { name = 'HDMI-A-1', height = 1080 }, { name = 'DP-3', height = 1440 } }" \
    "{ lid_closed = true }"
  [ "$output" = 'primary DP-3' ]
}

@test "no outputs: no primary and no rules" {
  run -0 layout "{}"
  [ "$output" = 'primary nil' ]
}

@test "desktop: no monitor rules beyond the override's, workspaces on DP-2, and a quiet reload" {
  local root="$BATS_TEST_TMPDIR/desktop" dir="$BATS_TEST_TMPDIR/hypr"
  mkdir -p "$root" "$dir"
  cp "$CONFIG"/hypr/*.lua "$dir/"
  cp "$CONFIG/hypr/override.example.lua" "$dir/override.lua"
  run -0 luajit "$BATS_TEST_DIRNAME/hypr-stub.lua" "$dir" "
    require('monitors').root = '$root'
    MONITORS = { { name = 'DP-2', width = 3840, height = 2160, scale = 1.5 } }
    dofile(CONFIG_DIR .. '/hyprland.lua')"
  [ "$(grep '^monitor' <<<"$output")" = "$(printf '%s\n' \
    'monitor  preferred auto auto' 'monitor DP-2 3840x2160@144 0x0 1.5')" ]
  [ "$(grep '^workspace' <<<"$output")" = "$(for i in $(seq 1 10); do echo "workspace $i DP-2"; done)" ]
  refute_output_matches '^(exec|dispatch)'
  [ "$(primary_file)" = DP-2 ]
}

@test "desktop: startup focuses the primary, and the lid switch does nothing" {
  local root="$BATS_TEST_TMPDIR/desktop"
  mkdir -p "$root"
  run -0 hypr "$root" "{ { name = 'DP-2', width = 3840, height = 2160, scale = 1.5 } }" "
    emit('hyprland.start')
    print('lid')
    BINDS['switch:on:Lid Switch']()
    BINDS['switch:off:Lid Switch']()"
  [ "$(sed -n '/^lid$/,$p' <<<"$output")" = lid ]
  grep -qx 'dispatch focus monitor=DP-2' <<<"$output"
  grep -qx 'exec sleep 1; xrandr --output DP-2 --primary' <<<"$output"
  refute_output_matches 'systemd-inhibit|hyprlock|suspend'
}

@test "laptop without a battery: closing the lid undocked does nothing" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  fake_lid "$root" open
  run -0 hypr "$root" "{ $PANEL }" "BINDS['switch:on:Lid Switch']()"
  [ "$output" = "" ]
}

@test "laptop with a battery: closing the lid undocked locks with hyprlock, then suspends" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  fake_battery "$root"
  fake_lid "$root" open
  run -0 hypr "$root" "{ $PANEL }" "BINDS['switch:on:Lid Switch']()"
  [ "${#lines[@]}" -eq 1 ]
  [[ ${lines[0]} == 'exec '*hyprlock*'systemctl suspend' ]]

  # A wireless mouse's battery doesn't count.
  rm -r "$root/sys/class/power_supply/BAT0"
  run -0 hypr "$root" "{ $PANEL }" "BINDS['switch:on:Lid Switch']()"
  [ "$output" = "" ]
}

@test "laptop: Hyprland takes over the lid from logind while it runs" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  run -0 hypr "$root" "{ $PANEL }" "emit('hyprland.start')"
  # shellcheck disable=SC2016 # $PPID is for the shell Hyprland runs
  grep -qx 'exec exec systemd-inhibit --what=handle-lid-switch .* tail --pid="$PPID" -f /dev/null' <<<"$output"
}

@test "docked: the lid turns the panel off and back on below the external, and never suspends" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  fake_battery "$root"
  fake_lid "$root" open
  run -0 hypr "$root" "{ $PANEL, $EXTERNAL }" "
    BINDS['switch:on:Lid Switch']()
    MONITORS = { $EXTERNAL }
    emit('monitor.removed', $PANEL)
    print('open')
    BINDS['switch:off:Lid Switch']()"
  [ "$output" = "$(printf '%s\n' \
    'monitor HDMI-A-1 nil 0x0 nil' 'monitor eDP-1 nil nil nil disabled' \
    'open' 'monitor HDMI-A-1 nil 0x0 nil' 'monitor eDP-1 nil 0x1440 nil')" ]
}

@test "a lid closed when the config loads keeps the docked panel off" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  fake_lid "$root" closed
  mkdir -p "$BATS_TEST_TMPDIR/hypr"
  cp "$CONFIG"/hypr/*.lua "$BATS_TEST_TMPDIR/hypr/"
  rm -f "$BATS_TEST_TMPDIR/hypr/override.lua"
  run -0 luajit "$BATS_TEST_DIRNAME/hypr-stub.lua" "$BATS_TEST_TMPDIR/hypr" "
    require('monitors').root = '$root'
    MONITORS = { $EXTERNAL }
    dofile(CONFIG_DIR .. '/hyprland.lua')"
  [ "$(grep '^monitor' <<<"$output")" = "$(printf '%s\n' 'monitor  preferred auto auto' \
    'monitor HDMI-A-1 nil 0x0 nil' 'monitor eDP-1 nil nil nil disabled')" ]
}

@test "plugging in an external makes it primary; unplugging gives everything back to the panel" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  run -0 hypr "$root" "{ $PANEL }" "
    WORKSPACES = { { id = 1, monitor = { name = 'eDP-1' } }, { id = 11, monitor = { name = 'eDP-1' } } }
    -- Hyprland's monitor list may not have caught up when the event comes.
    emit('monitor.added', $EXTERNAL)
    print('unplug')
    WORKSPACES = { { id = 1, monitor = { name = 'HDMI-A-1' } } }
    MONITORS = { $PANEL, $EXTERNAL }
    emit('monitor.removed', $EXTERNAL)"
  local expected=('monitor HDMI-A-1 nil 0x0 nil' 'monitor eDP-1 nil 0x1440 nil')
  for i in $(seq 1 10); do expected+=("workspace $i HDMI-A-1"); done
  expected+=('dispatch workspace.move monitor=HDMI-A-1 workspace=1'
    'dispatch focus monitor=HDMI-A-1' 'exec sleep 1; xrandr --output HDMI-A-1 --primary'
    unplug 'monitor eDP-1 nil auto nil')
  for i in $(seq 1 10); do expected+=("workspace $i eDP-1"); done
  expected+=('dispatch workspace.move monitor=eDP-1 workspace=1'
    'dispatch focus monitor=eDP-1' 'exec sleep 1; xrandr --output eDP-1 --primary')
  [ "$output" = "$(printf '%s\n' "${expected[@]}")" ]
  [ "$(primary_file)" = eDP-1 ]
}

@test "unplugging the external with the lid closed turns the panel on, then locks and suspends" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  fake_battery "$root"
  fake_lid "$root" closed
  run -0 hypr "$root" "{ $EXTERNAL }" "
    MONITORS = {}
    emit('monitor.removed', $EXTERNAL)"
  [ "${lines[0]}" = 'monitor eDP-1 nil auto nil' ]
  [[ ${lines[-1]} == 'exec '*hyprlock*'systemctl suspend' ]]

  # The panel going away (around a resume) doesn't suspend.
  run -0 hypr "$root" "{}" "emit('monitor.removed', $PANEL)"
  refute_output_matches 'suspend'
}

@test "the force-enable key turns the panel off and on again, even with the lid read as closed" {
  local root="$BATS_TEST_TMPDIR/laptop"
  fake_panel "$root"
  fake_lid "$root" closed
  run -0 hypr "$root" "{ $EXTERNAL }" "BINDS['SUPER + SHIFT + M']()"
  [ "$(grep '^monitor' <<<"$output")" = "$(printf '%s\n' \
    'monitor eDP-1 nil nil nil disabled' \
    'monitor HDMI-A-1 nil 0x0 nil' 'monitor eDP-1 nil 0x1440 nil')" ]
}

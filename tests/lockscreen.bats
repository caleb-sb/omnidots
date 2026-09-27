#!/usr/bin/env bats
#
# The lock screen's text (config/hypr/scripts/lockinfo.sh, which hyprlock's
# labels run): the greeting, the Spotify track and the battery. playerctl
# and getent are stubs; the battery comes from a fixture sysfs.

bats_require_minimum_version 1.5.0

LOCKINFO="$BATS_TEST_DIRNAME/../config/hypr/scripts/lockinfo.sh"
ICON='<span font_family="Material Symbols Rounded">'

setup() {
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  export OMNIDOTS_SYSFS_ROOT="$BATS_TEST_TMPDIR/sys"
  mkdir -p "$OMNIDOTS_SYSFS_ROOT/class/power_supply"
  export PATH="$STUBS:$PATH"
  export USER=caleb
}

# stub <name> <script body>
stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}

# spotify <status> <title> <artist> — Spotify is running in that state.
spotify() {
  stub playerctl "
case \"\$*\" in
  *status*) echo '$1' ;;
  *metadata*) printf '%s\t%s\n' '$2' '$3' ;;
esac"
}

# battery <name> <capacity> <status> [scope]
battery() {
  local dir="$OMNIDOTS_SYSFS_ROOT/class/power_supply/$1"
  mkdir -p "$dir"
  echo Battery >"$dir/type"
  echo "$2" >"$dir/capacity"
  echo "$3" >"$dir/status"
  if [ -n "${4:-}" ]; then echo "$4" >"$dir/scope"; fi
}

@test "greets the user by their full name" {
  stub getent 'echo "caleb:x:1000:1000:Caleb Smith,,,:/home/caleb:/usr/bin/fish"'
  run -0 "$LOCKINFO" greeting
  [ "$output" = "Hi, Caleb" ]
}

@test "greets the user by login name when there's no full name" {
  stub getent 'echo "caleb:x:1000:1000::/home/caleb:/usr/bin/fish"'
  run -0 "$LOCKINFO" greeting
  [ "$output" = "Hi, caleb" ]
}

@test "shows the Spotify track, playing or paused" {
  spotify Playing "Hurt" "Johnny Cash"
  run -0 "$LOCKINFO" media
  [ "$output" = "${ICON}music_note</span>  Hurt — Johnny Cash" ]

  spotify Paused "Hurt" "Johnny Cash"
  run -0 "$LOCKINFO" media
  [ "$output" = "${ICON}music_note</span>  Hurt — Johnny Cash" ]
}

@test "shows nothing when Spotify isn't running or has stopped" {
  stub playerctl 'echo "No players found" >&2; exit 1'
  run -0 "$LOCKINFO" media
  [ "$output" = "" ]

  spotify Stopped "Hurt" "Johnny Cash"
  run -0 "$LOCKINFO" media
  [ "$output" = "" ]
}

@test "cuts a long track to 40 characters and escapes markup" {
  spotify Playing "Symphony No. 9 in D minor, Op. 125 & Choral" "Beethoven"
  run -0 "$LOCKINFO" media
  [ "$output" = "${ICON}music_note</span>  Symphony No. 9 in D minor, Op. 125 &amp; Ch…" ]

  spotify Playing "Song" ""
  run -0 "$LOCKINFO" media
  [ "$output" = "${ICON}music_note</span>  Song" ]
}

@test "shows the laptop battery's level, red when low and discharging" {
  battery BAT0 57 Discharging
  run -0 "$LOCKINFO" battery
  [ "$output" = "${ICON}battery_3_bar</span>  57%" ]

  battery BAT0 12 Discharging
  run -0 "$LOCKINFO" battery
  [ "$output" = "<span foreground=\"#f7768e\">${ICON}battery_0_bar</span>  12%</span>" ]

  battery BAT0 12 Charging
  run -0 "$LOCKINFO" battery
  [ "$output" = "${ICON}battery_charging_full</span>  12%" ]

  battery BAT0 100 Full
  run -0 "$LOCKINFO" battery
  [ "$output" = "${ICON}battery_full</span>  100%" ]
}

@test "shows no battery on a desktop, even with a wireless mouse's battery" {
  run -0 "$LOCKINFO" battery
  [ "$output" = "" ]

  battery hidpp_battery_0 80 Discharging Device
  run -0 "$LOCKINFO" battery
  [ "$output" = "" ]
}

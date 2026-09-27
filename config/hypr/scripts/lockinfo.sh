#!/usr/bin/env sh
#
# Text for hyprlock's labels (see ../hyprlock.conf), as Pango markup. Prints
# nothing when there's nothing to show, so the label stays empty.
#
#   greeting  "Hi, <first name>", from the account's full name
#   media     Spotify's track while it's playing or paused
#   battery   the laptop battery's level; nothing on a desktop
#
# OMNIDOTS_SYSFS_ROOT overrides /sys for tests.

set -eu

SYS="${OMNIDOTS_SYSFS_ROOT:-/sys}"
# Longer tracks are cut to this many characters, ellipsis included.
MAX_CHARS=40

icon() {
  printf '<span font_family="Material Symbols Rounded">%s</span>' "$1"
}

escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

greeting() {
  name="$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1 | cut -d' ' -f1)"
  printf 'Hi, %s\n' "${name:-$USER}" | escape
}

media() {
  case "$(playerctl -p spotify status 2>/dev/null)" in
    Playing | Paused) ;;
    *) return 0 ;;
  esac
  track="$(playerctl -p spotify metadata --format '{{title}}	{{artist}}' 2>/dev/null)" ||
    return 0
  # "Title — Artist", or the title alone; cut by character, not byte.
  text="$(printf '%s\n' "$track" | LC_ALL=C.UTF-8 awk -F '\t' -v max="$MAX_CHARS" '{
    s = $2 == "" ? $1 : $1 " — " $2
    if (length(s) > max) s = substr(s, 1, max - 1) "…"
    print s
  }' | escape)"
  [ -n "$text" ] || return 0
  printf '%s  %s\n' "$(icon music_note)" "$text"
}

battery() {
  for dir in "$SYS"/class/power_supply/*; do
    [ "$(cat "$dir/type" 2>/dev/null)" = Battery ] || continue
    # Mice and other peripherals report their batteries too.
    [ "$(cat "$dir/scope" 2>/dev/null)" != Device ] || continue
    level="$(cat "$dir/capacity")"
    status="$(cat "$dir/status")"
    case "$status" in
      Charging) name=battery_charging_full ;;
      Full) name=battery_full ;;
      *) name="battery_$((level * 6 / 100))_bar" ;;
    esac
    line="$(icon "$name")  $level%"
    if [ "$status" = Discharging ] && [ "$level" -le 20 ]; then
      line="<span foreground=\"#f7768e\">$line</span>"
    fi
    printf '%s\n' "$line"
    return 0
  done
}

case "${1:-}" in
  greeting | media | battery) "$1" ;;
  *)
    echo "usage: lockinfo.sh greeting|media|battery" >&2
    exit 2
    ;;
esac

#!/usr/bin/env sh
#
# Clipboard history picker: cliphist's entries in rofi, themed by
# ~/.config/rofi/config.rasi. The SUPER+V bind runs `pkill -x rofi || ...`,
# so pressing it again closes the picker.
#
#   c  copy the chosen entry
#   d  delete the chosen entry
#   w  wipe the history, after confirmation

set -eu

# pick <prompt> — the entry chosen from the history; fails if none was.
pick() {
  entry="$(cliphist list | rofi -dmenu -p "$1")" || return 1
  [ -n "$entry" ] || return 1
  printf '%s\n' "$entry"
}

case "${1:-}" in
  c)
    entry="$(pick Copy)" || exit 0
    printf '%s\n' "$entry" | cliphist decode | wl-copy
    ;;
  d)
    entry="$(pick Delete)" || exit 0
    printf '%s\n' "$entry" | cliphist delete
    ;;
  w)
    answer="$(printf 'No\nYes\n' | rofi -dmenu -p 'Wipe clipboard history?')" || exit 0
    if [ "$answer" = Yes ]; then
      cliphist wipe
    fi
    ;;
  *)
    echo "usage: cliphist.sh c|d|w (copy, delete or wipe)" >&2
    exit 1
    ;;
esac

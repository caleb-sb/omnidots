#!/usr/bin/env bash
#
# greetd's greeter, deployed to /usr/local/bin/omnidots-greeter by
# installer/modules/88-greeter.sh and run by greetd as its default session.
#
#   omnidots-greeter             run the Quickshell greeter in a minimal
#                                Hyprland session, or tuigreet if it fails
#   omnidots-greeter quickshell  inside that session (its hyprland.lua runs
#                                this): run the greeter, record how it ended,
#                                and end Hyprland
#
# The greeter ends cleanly once greetd has accepted a login: Quickshell exits
# 0 and greetd starts the session. Anything else (a Quickshell error or
# crash, Hyprland failing to start or crashing, a Hyprland that exited without
# running the greeter) means no session was chosen, so tuigreet takes over
# and the machine can still be logged in to. When tuigreet exits, greetd runs
# this again, which tries the graphical greeter first.
#
# Input, overridable for tests:
#   OMNIDOTS_GREETER_DIR  the deployed greeter (default:
#                         /usr/local/share/omnidots-greeter)

set -uo pipefail

GREETER_DIR="${OMNIDOTS_GREETER_DIR:-/usr/local/share/omnidots-greeter}"
# The session tuigreet and agreety start.
SESSION_CMD=start-hyprland

# fallback — replace this process with a terminal greeter.
fallback() {
  echo "omnidots-greeter: the graphical greeter failed; falling back to tuigreet" >&2
  if command -v tuigreet >/dev/null; then
    exec tuigreet --time --remember --remember-session --asterisks \
      --cmd "$SESSION_CMD"
  fi
  # greetd's own, in case tuigreet is missing.
  exec agreety --cmd "$SESSION_CMD"
}

# run_quickshell — inside Hyprland: run the greeter, write its exit status to
# OMNIDOTS_GREETER_STATUS, then end Hyprland. The status is written first, so
# it's there when Hyprland returns.
run_quickshell() {
  qs -p "$GREETER_DIR"
  printf '%s\n' "$?" >"$OMNIDOTS_GREETER_STATUS"
  hyprctl dispatch 'hl.dsp.exit()'
}

# Not start-hyprland: its watchdog restarts a crashed Hyprland in safe mode,
# without the greeter, instead of returning here.
run_session() {
  local status_file status=
  status_file="$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" omnidots-greeter.XXXXXX)" || fallback
  OMNIDOTS_GREETER="$(readlink -f "$0")" OMNIDOTS_GREETER_STATUS="$status_file" \
    Hyprland --config "$GREETER_DIR/hyprland.lua"
  read -r status <"$status_file"
  rm -f "$status_file"
  [[ $status == 0 ]] || fallback
}

case "${1:-}" in
  quickshell) run_quickshell ;;
  "") run_session ;;
  *)
    echo "usage: omnidots-greeter [quickshell]" >&2
    exit 2
    ;;
esac

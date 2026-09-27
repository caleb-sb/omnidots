#!/usr/bin/env bats
#
# The login screen's system files (installer/greeter/). greetd runs
# omnidots-greeter, which runs the Quickshell greeter in a minimal Hyprland
# session and falls back to tuigreet when that doesn't end cleanly. These run
# it with stub commands on PATH that only record their calls; nothing is
# launched.

bats_require_minimum_version 1.5.0

SYSTEM="$BATS_TEST_DIRNAME/../installer/greeter"

setup() {
  STUBS="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  # PATH is the stubs plus a few basic tools, never /usr/bin, so a missing
  # stub can't run the real Hyprland, Quickshell or greeter.
  TOOLS="$BATS_TEST_TMPDIR/tools"
  mkdir -p "$STUBS" "$TOOLS"
  local tool
  for tool in bash env cat mktemp readlink rm; do
    ln -s "$(command -v "$tool")" "$TOOLS/"
  done
  : >"$CALLS"
  # stub <name> <body> — a command that records its arguments, then runs body.
  stub() {
    printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n%s\n' "$1" "$CALLS" "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
  }
  # Hyprland runs the greeter the way its config does at startup, unless
  # HYPR_CRASH is set, then exits with HYPR_EXIT.
  # shellcheck disable=SC2016 # expanded by the stub
  stub Hyprland '[ -n "${HYPR_CRASH:-}" ] || "$OMNIDOTS_GREETER" quickshell; exit "${HYPR_EXIT:-0}"'
  # shellcheck disable=SC2016
  stub qs 'exit "${QS_EXIT:-0}"'
  stub hyprctl ''
  stub tuigreet ''
  stub agreety ''
}

# greeter [VAR=value...] — run greetd's greeter command with the stubs.
greeter() {
  run "$TOOLS/env" PATH="$STUBS:$TOOLS" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR" \
    OMNIDOTS_GREETER_DIR=/greeter "$@" "$SYSTEM/omnidots-greeter.sh"
}

called() { grep -q "^$1\( \|$\)" "$CALLS"; }

not_called() {
  if called "$1"; then
    printf 'unexpected call: %s\n' "$(grep "^$1" "$CALLS")" >&2
    return 1
  fi
}

@test "the greeter runs Quickshell inside Hyprland with the greeter's own config" {
  greeter
  [ "$status" -eq 0 ]
  grep -qxF 'Hyprland --config /greeter/hyprland.lua' "$CALLS"
  grep -qxF 'qs -p /greeter' "$CALLS"
}

@test "once Quickshell exits cleanly, it ends Hyprland and the greeter ends without tuigreet" {
  greeter QS_EXIT=0
  [ "$status" -eq 0 ]
  grep -qxF "hyprctl dispatch hl.dsp.exit()" "$CALLS"
  not_called tuigreet
  not_called agreety
}

@test "Hyprland failing on its way out after a clean greeter doesn't matter: the session is already chosen" {
  greeter QS_EXIT=0 HYPR_EXIT=1
  [ "$status" -eq 0 ]
  not_called tuigreet
}

@test "Quickshell failing falls back to tuigreet, which starts Hyprland" {
  greeter QS_EXIT=1
  called tuigreet
  grep -q '^tuigreet .*--cmd start-hyprland' "$CALLS"
}

@test "Hyprland crashing before the greeter ends falls back to tuigreet" {
  greeter HYPR_CRASH=1 HYPR_EXIT=134
  called tuigreet
  # Even when it exits 0.
  : >"$CALLS"
  greeter HYPR_CRASH=1 HYPR_EXIT=0
  called tuigreet
}

@test "without Hyprland, it falls back to tuigreet" {
  rm "$STUBS/Hyprland"
  greeter
  called tuigreet
}

@test "without tuigreet, it falls back to greetd's own agreety" {
  rm "$STUBS/tuigreet"
  greeter QS_EXIT=1
  grep -qxF 'agreety --cmd start-hyprland' "$CALLS"
}

@test "greetd's PAM stack takes the password only, and unlocks the keyring" {
  local pam="$SYSTEM/greetd.pam"
  # password-auth, never system-auth, which authselect gives pam_fprintd.
  grep -qE '^auth\s+substack\s+password-auth$' "$pam"
  local rules
  rules="$(grep -vE '^#' "$pam")"
  run ! grep -qE 'system-auth|fingerprint-auth|pam_fprintd' <<<"$rules"
  grep -qE '^auth\s+optional\s+pam_gnome_keyring\.so$' "$pam"
  grep -qE '^session\s+optional\s+pam_gnome_keyring\.so\s+auto_start$' "$pam"
}

@test "on Fedora, password-auth has no pam_fprintd even with authselect's with-fingerprint" {
  local profile=/usr/share/authselect/default/local
  [ -d "$profile" ] || skip "authselect's profiles aren't installed"
  grep -q 'pam_fprintd.*with-fingerprint' "$profile/system-auth"
  run ! grep -q pam_fprintd "$profile/password-auth"
}

@test "greetd runs omnidots-greeter as Fedora's greetd user" {
  grep -qxF 'command = "/usr/local/bin/omnidots-greeter"' "$SYSTEM/greetd.toml"
  grep -qxF 'user = "greetd"' "$SYSTEM/greetd.toml"
}

# sessions <listing> [remembered] — the greeter's session list for a listing
# of session files (greeter/sessions.js under node), one per line
# as `name | command | environment`, with `*` before the default.
sessions() {
  command -v node >/dev/null || skip "node is not installed"
  node - "$BATS_TEST_DIRNAME/../greeter/sessions.js" "$@" <<'JS'
const fs = require("fs"), vm = require("vm");
const [lib, listing, remembered] = process.argv.slice(2);
const S = {};
vm.runInNewContext(fs.readFileSync(lib, "utf8").replace(/^\.pragma library$/m, ""), S);
const list = S.parse(listing);
const def = S.defaultIndex(list, remembered || "");
list.forEach((s, i) =>
  console.log(`${i === def ? "*" : " "}${s.name} | ${s.command} | ${S.environment(s).join(" ")}`));
JS
}

HYPRLAND_ENTRY='[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=/usr/bin/start-hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;'

UWSM_ENTRY='[Desktop Entry]
Name=Hyprland (uwsm-managed)
Exec=uwsm start -e -D Hyprland hyprland.desktop
TryExec=uwsm
DesktopNames=Hyprland
Type=Application'

GNOME_ENTRY='[Desktop Entry]
Name[de]=GNOME unter Wayland
Name=GNOME on Wayland
Comment=This session logs you into GNOME
Exec=/usr/bin/gnome-session %U
DesktopNames=GNOME;GNOME-Classic
Type=Application

[Desktop Action Safe]
Name=Safe mode
Exec=/usr/bin/gnome-session --safe'

@test "sessions: every session file's name and command, sorted, with Hyprland via start-hyprland the default" {
  run -0 sessions "$GNOME_ENTRY
$UWSM_ENTRY
$HYPRLAND_ENTRY"
  [ "$output" = "$(printf '%s\n' \
    ' GNOME on Wayland | /usr/bin/gnome-session | XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=GNOME:GNOME-Classic' \
    '*Hyprland | /usr/bin/start-hyprland | XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland' \
    ' Hyprland (uwsm-managed) | uwsm start -e -D Hyprland hyprland.desktop | XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland')" ]
}

@test "sessions: the session picked last time is the default while it's still there" {
  run -0 sessions "$GNOME_ENTRY
$HYPRLAND_ENTRY" "GNOME on Wayland"
  [ "${lines[0]}" = '*GNOME on Wayland | /usr/bin/gnome-session | XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=GNOME:GNOME-Classic' ]

  run -0 sessions "$HYPRLAND_ENTRY" "Sway"
  [ "${lines[0]:0:9}" = '*Hyprland' ]
}

@test "sessions: hidden entries are left out" {
  run -0 sessions "$HYPRLAND_ENTRY
[Desktop Entry]
Name=Old
Exec=old-session
Hidden=true
[Desktop Entry]
Name=Also old
Exec=also-old-session
NoDisplay=true"
  [ "$output" = '*Hyprland | /usr/bin/start-hyprland | XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland' ]
}

@test "sessions: with no session files, Hyprland via start-hyprland is still offered" {
  run -0 sessions ""
  [ "$output" = '*Hyprland | start-hyprland | XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland' ]
}

@test "the greeter's Hyprland config parses and starts the greeter through omnidots-greeter" {
  command -v luajit >/dev/null || skip "luajit is not installed"
  local dir="$BATS_TEST_DIRNAME/../greeter"
  run -0 luajit -bl "$dir/hyprland.lua"
  # shellcheck disable=SC2016 # Lua code
  run -0 env OMNIDOTS_GREETER=/x/omnidots-greeter luajit \
    "$BATS_TEST_DIRNAME/hypr-stub.lua" "$dir" \
    'dofile(CONFIG_DIR .. "/hyprland.lua"); print("--"); emit("hyprland.start")'
  [ "$(sed '1,/^--$/d' <<<"$output")" = 'exec /x/omnidots-greeter quickshell' ]
}

@test "the greeter's keyboard layout is the desktop's, so the password types the same" {
  local desktop greeter
  desktop="$(grep -oE 'kb_layout *= *"[^"]*"' "$BATS_TEST_DIRNAME/../config/hypr/hyprland.lua")"
  greeter="$(grep -oE 'kb_layout *= *"[^"]*"' "$BATS_TEST_DIRNAME/../greeter/hyprland.lua")"
  [ -n "$desktop" ]
  [ "${greeter//[[:space:]]/}" = "${desktop//[[:space:]]/}" ]
}

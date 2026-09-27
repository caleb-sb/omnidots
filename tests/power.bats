#!/usr/bin/env bats
#
# qs-bar's battery saver, CPU power profile and low-battery warnings
# (config/qs-bar/modules/system/power.js). The logic is a plain JS library;
# these drive it under node with event sequences, the way the power and
# system stats modules feed it UPower readings. Nothing is launched.

bats_require_minimum_version 1.5.0

LIB="$BATS_TEST_DIRNAME/../config/qs-bar/modules/system/power.js"

setup() {
  command -v node >/dev/null || skip "node is not installed"
}

# sim [--no-battery] <step...> — runs the steps in order and prints one line
# per step: `<step>: <profile>`, plus ` warn` or ` critical` when a
# notification goes out. The profile is "-" when none is set.
#   bat <n> / ac <n>   a UPower reading: on battery or on AC at n%
#                      (0 = not known yet)
#   saver on|off       the battery-saver toggle
#   game on|off        the game-mode toggle
#   restart            qs-bar restarts: the saved state comes back
sim() {
  local battery=true
  if [ "$1" = --no-battery ]; then
    battery=false
    shift
  fi
  node - "$LIB" "$battery" "$@" <<'EOF'
const fs = require("fs"), vm = require("vm");
const [lib, battery, ...steps] = process.argv.slice(2);
const P = {};
vm.runInNewContext(fs.readFileSync(lib, "utf8").replace(/^\.pragma library$/m, ""), P);
let st = P.initial(), warn = P.initialWarnings();
for (const step of steps) {
  const [cmd, arg] = step.split(" ");
  let note = "";
  if (cmd === "bat" || cmd === "ac") {
    const r = { onBattery: cmd === "bat", percent: +arg };
    st = P.battery(st, r);
    const w = P.warn(warn, r);
    warn = w.state;
    if (w.warning)
      note = w.warning.critical ? " critical" : " warn";
  } else if (cmd === "saver") {
    st = P.setSaver(st, arg === "on");
  } else if (cmd === "game") {
    st = P.setGameMode(st, arg === "on");
  } else if (cmd === "restart") {
    st = P.restore(JSON.parse(JSON.stringify(st)));
    warn = P.initialWarnings();
  }
  console.log(`${step}: ${P.profile(st, battery === "true") || "-"}${note}`);
}
EOF
}

@test "balanced by default; game mode is performance and turning it off goes back" {
  run -0 sim "ac 80" "game on" "game off"
  [ "$output" = "$(printf '%s\n' \
    'ac 80: balanced' \
    'game on: performance' \
    'game off: balanced')" ]
}

@test "discharging to 20% turns battery saver on and warns once" {
  run -0 sim "bat 25" "bat 21" "bat 20" "bat 19" "bat 18"
  [ "$output" = "$(printf '%s\n' \
    'bat 25: balanced' \
    'bat 21: balanced' \
    'bat 20: power-saver warn' \
    'bat 19: power-saver' \
    'bat 18: power-saver')" ]
}

@test "10% sends one critical warning" {
  run -0 sim "bat 12" "bat 11" "bat 10" "bat 9" "bat 5"
  [ "$output" = "$(printf '%s\n' \
    'bat 12: power-saver warn' \
    'bat 11: power-saver' \
    'bat 10: power-saver critical' \
    'bat 9: power-saver' \
    'bat 5: power-saver')" ]
}

@test "turning saver off by hand holds until the next AC transition" {
  run -0 sim "bat 20" "saver off" "bat 18" "bat 15" "ac 15" "bat 15"
  [ "$output" = "$(printf '%s\n' \
    'bat 20: power-saver warn' \
    'saver off: balanced' \
    'bat 18: balanced' \
    'bat 15: balanced' \
    'ac 15: balanced' \
    'bat 15: power-saver warn')" ]
}

@test "plugging in turns saver off and re-arms the warnings" {
  run -0 sim "bat 9" "ac 9" "ac 30" "bat 30" "bat 20" "bat 10"
  [ "$output" = "$(printf '%s\n' \
    'bat 9: power-saver critical' \
    'ac 9: balanced' \
    'ac 30: balanced' \
    'bat 30: balanced' \
    'bat 20: power-saver warn' \
    'bat 10: power-saver critical')" ]
}

@test "saver turned on by hand on AC holds until unplugged" {
  run -0 sim "ac 80" "saver on" "ac 90" "bat 90"
  [ "$output" = "$(printf '%s\n' \
    'ac 80: balanced' \
    'saver on: power-saver' \
    'ac 90: power-saver' \
    'bat 90: balanced')" ]
}

@test "game mode and battery saver turn each other off" {
  run -0 sim "bat 50" "saver on" "game on" "saver on" "game on" "game off"
  [ "$output" = "$(printf '%s\n' \
    'bat 50: balanced' \
    'saver on: power-saver' \
    'game on: performance' \
    'saver on: power-saver' \
    'game on: performance' \
    'game off: power-saver')" ]
}

@test "game mode holds off automatic saver, which comes back when game mode ends" {
  run -0 sim "bat 30" "game on" "bat 20" "bat 15" "game off"
  [ "$output" = "$(printf '%s\n' \
    'bat 30: balanced' \
    'game on: performance' \
    'bat 20: performance warn' \
    'bat 15: performance' \
    'game off: power-saver')" ]
}

@test "without a battery no profile is ever set, whatever the toggles" {
  run -0 sim --no-battery "game on" "game off" "saver on" "restart"
  [ "$output" = "$(printf '%s\n' \
    'game on: -' \
    'game off: -' \
    'saver on: -' \
    'restart: -')" ]
}

@test "no profile before the first battery reading" {
  run -0 sim "game on" "bat 50"
  [ "$output" = "$(printf '%s\n' \
    'game on: -' \
    'bat 50: performance')" ]
}

@test "an unknown percentage (0) changes nothing and warns about nothing" {
  run -0 sim "bat 0" "bat 50" "bat 0" "bat 49"
  [ "$output" = "$(printf '%s\n' \
    'bat 0: balanced' \
    'bat 50: balanced' \
    'bat 0: balanced' \
    'bat 49: balanced')" ]
}

@test "starting on battery at 15% turns saver on and sends one warning, not two" {
  run -0 sim "bat 15" "bat 14"
  [ "$output" = "$(printf '%s\n' \
    'bat 15: power-saver warn' \
    'bat 14: power-saver')" ]
}

@test "starting at 5% sends only the critical warning" {
  run -0 sim "bat 5" "bat 4"
  [ "$output" = "$(printf '%s\n' \
    'bat 5: power-saver critical' \
    'bat 4: power-saver')" ]
}

@test "a manual choice and game mode survive a restart on the same discharge" {
  run -0 sim "bat 18" "saver off" "restart" "bat 18" "bat 17" "game on" "restart" "bat 17"
  [ "$output" = "$(printf '%s\n' \
    'bat 18: power-saver warn' \
    'saver off: balanced' \
    'restart: balanced' \
    'bat 18: balanced warn' \
    'bat 17: balanced' \
    'game on: performance' \
    'restart: performance' \
    'bat 17: performance warn')" ]
}

@test "plugging in while qs-bar wasn't running still counts as an AC transition" {
  run -0 sim "bat 18" "saver off" "restart" "ac 18"
  [ "$output" = "$(printf '%s\n' \
    'bat 18: power-saver warn' \
    'saver off: balanced' \
    'restart: balanced' \
    'ac 18: balanced')" ]
  run -0 sim "bat 18" "saver off" "restart" "ac 18" "bat 18"
  [ "${lines[4]}" = 'bat 18: power-saver warn' ]
}

@test "charging while suspended or off starts a new discharge cycle" {
  run -0 sim "bat 15" "saver off" "bat 80" "bat 20"
  [ "$output" = "$(printf '%s\n' \
    'bat 15: power-saver warn' \
    'saver off: balanced' \
    'bat 80: balanced' \
    'bat 20: power-saver warn')" ]
  run -0 sim "bat 15" "saver off" "restart" "bat 80" "bat 20"
  [ "${lines[4]}" = 'bat 20: power-saver warn' ]
}

@test "a 1% jitter upwards on battery isn't a charge" {
  run -0 sim "bat 20" "saver off" "bat 21" "bat 20"
  [ "$output" = "$(printf '%s\n' \
    'bat 20: power-saver warn' \
    'saver off: balanced' \
    'bat 21: balanced' \
    'bat 20: balanced')" ]
}

@test "a bad or old state file gives the defaults" {
  run -0 node -e "
    const fs = require('fs'), vm = require('vm'), P = {};
    vm.runInNewContext(fs.readFileSync('$LIB', 'utf8').replace(/^\.pragma library\$/m, ''), P);
    for (const saved of [null, 'x', {}, { sleepMinutes: 5, gameMode: true }])
      console.log(JSON.stringify(P.restore(saved)));"
  [ "${lines[0]}" = "${lines[1]}" ]
  [ "${lines[0]}" = "${lines[2]}" ]
  [ "${lines[0]}" = "$(node -e "
    const fs = require('fs'), vm = require('vm'), P = {};
    vm.runInNewContext(fs.readFileSync('$LIB', 'utf8').replace(/^\.pragma library\$/m, ''), P);
    console.log(JSON.stringify(P.initial()))")" ]
  [[ "${lines[3]}" == *'"gameMode":true'* ]]
}

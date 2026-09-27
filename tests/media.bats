#!/usr/bin/env bats
#
# qs-bar's Spotify media pill (config/qs-bar/modules/media/media.js). The
# logic is a plain JS library; these drive it under node with plain objects
# standing in for Quickshell's MPRIS players. Nothing is launched.

bats_require_minimum_version 1.5.0

LIB="$BATS_TEST_DIRNAME/../config/qs-bar/modules/media/media.js"

setup() {
  command -v node >/dev/null || skip "node is not installed"
}

# js <expression> — evaluates the expression with the library's functions in
# scope and prints the result as JSON.
js() {
  node - "$LIB" "$1" <<'EOF'
const fs = require("fs"), vm = require("vm");
const [lib, expr] = process.argv.slice(2);
const M = {};
vm.runInNewContext(fs.readFileSync(lib, "utf8").replace(/^\.pragma library$/m, ""), M);
console.log(JSON.stringify(vm.runInNewContext(expr, M)));
EOF
}

BRAVE='{ identity: "Brave", dbusName: "org.mpris.MediaPlayer2.brave.instance823902" }'
FIREFOX='{ identity: "Mozilla firefox", dbusName: "org.mpris.MediaPlayer2.firefox.instance_1_42" }'
VLC='{ identity: "VLC media player", dbusName: "org.mpris.MediaPlayer2.vlc" }'

@test "picks Spotify out of the players, ignoring browsers and other players" {
  run -0 js "pick([$BRAVE, $FIREFOX, { identity: 'Spotify', dbusName: 'org.mpris.MediaPlayer2.spotify', id: 1 }, $VLC])"
  [[ "$output" == *'"id":1'* ]]
}

@test "matches Spotify by D-Bus name alone, including an instance suffix" {
  run -0 js "pick([$BRAVE, { identity: '', dbusName: 'org.mpris.MediaPlayer2.spotify.instance123', id: 2 }])"
  [[ "$output" == *'"id":2'* ]]
  run -0 js "pick([{ identity: '', dbusName: 'org.mpris.MediaPlayer2.spotify', id: 3 }])"
  [[ "$output" == *'"id":3'* ]]
}

@test "matches Spotify by identity alone, in any case" {
  run -0 js "pick([{ identity: 'spotify', dbusName: 'org.mpris.MediaPlayer2.something', id: 4 }])"
  [[ "$output" == *'"id":4'* ]]
}

@test "no player without Spotify, even with a Spotify tab in a browser" {
  run -0 js "pick([$BRAVE, $FIREFOX, $VLC, { identity: 'Spotify - Web Player', dbusName: 'org.mpris.MediaPlayer2.chromium.instance7' }, { identity: 'x', dbusName: 'org.mpris.MediaPlayer2.spotifyd' }])"
  [ "$output" = null ]
  run -0 js "pick([])"
  [ "$output" = null ]
}

@test "shown while a track is loaded, playing or paused" {
  run -0 js "visible({ trackTitle: 'Song' }, false)"
  [ "$output" = true ]
}

@test "hidden without Spotify, before a track loads, or when stopped" {
  run -0 js "[visible(null, false), visible({ trackTitle: '' }, false), visible({ trackTitle: '  ' }, false), visible({}, false), visible({ trackTitle: 'Song' }, true)]"
  [ "$output" = '[false,false,false,false,false]' ]
}

@test "the text is Title — Artist, or just the title without an artist" {
  run -0 js "[label('Song', 'Band'), label('Song', ''), label('Song', undefined), label(' Song ', ' Band ')]"
  [ "$output" = '["Song — Band","Song","Song","Song — Band"]' ]
}

@test "text up to 30 characters is left alone; longer is cut to 30 with an ellipsis" {
  # 22 + " — " + 5 is exactly 30; one more gives 29 characters and the "…".
  run -0 js "label('a'.repeat(22), 'b'.repeat(5))"
  [ "$output" = "\"$(printf 'a%.0s' {1..22}) — bbbbb\"" ]
  run -0 js "label('a'.repeat(22), 'b'.repeat(6))"
  [ "$output" = "\"$(printf 'a%.0s' {1..22}) — bbbb…\"" ]
  run -0 js "Array.from(label('x'.repeat(80), 'Band')).length"
  [ "$output" = 30 ]
}

@test "a cut never leaves a trailing space before the ellipsis" {
  # The first 29 characters end in the space after the a's.
  run -0 js "label('a'.repeat(28) + ' long title', 'Band')"
  [ "$output" = "\"$(printf 'a%.0s' {1..28})…\"" ]
}

@test "elision counts characters, not UTF-16 units, so emoji aren't split" {
  run -0 js "Array.from(label('😀'.repeat(40), '')).length"
  [ "$output" = 30 ]
  run -0 js "label('😀'.repeat(40), '').endsWith('😀…')"
  [ "$output" = true ]
}

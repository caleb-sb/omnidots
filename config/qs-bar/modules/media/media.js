.pragma library

// The Spotify media pill's logic, as plain functions over plain objects so
// tests/media.bats can drive them under node. Media.qml passes in
// Quickshell's MPRIS players, which have the same fields.

// Spotify's MPRIS bus name; a second instance adds a ".instance<pid>" suffix.
var BUS_NAME = "org.mpris.MediaPlayer2.spotify";

// Whether a player is the Spotify desktop app, by identity or D-Bus name.
// Browser tabs (including Spotify's web player) register under the
// browser's own name, so they never match.
function isSpotify(p) {
    const name = p.dbusName || "";
    return (p.identity || "").toLowerCase() === "spotify" || name === BUS_NAME || name.startsWith(BUS_NAME + ".");
}

// The Spotify player out of all MPRIS players, or null.
function pick(players) {
    return players.find(isSpotify) || null;
}

// Whether the pill shows: Spotify is running and has a track loaded, playing
// or paused. Spotify registers its player before any track is loaded, with
// an empty title. Stopped hides it even if the old metadata lingers, since
// there's nothing to resume.
function visible(p, stopped) {
    return !!p && !stopped && !!(p.trackTitle || "").trim();
}

// The pill's text is cut to this many characters, ellipsis included.
var MAX_CHARS = 30;

// "Title — Artist", or just the title when there's no artist, elided at
// MAX_CHARS with "…". Counts code points so an emoji is never split.
function label(title, artist) {
    const t = (title || "").trim(), a = (artist || "").trim();
    const chars = Array.from(a ? `${t} — ${a}` : t);
    if (chars.length <= MAX_CHARS)
        return chars.join("");
    return chars.slice(0, MAX_CHARS - 1).join("").replace(/\s+$/, "") + "…";
}

// A track position or length in seconds as "m:ss", or "h:mm:ss" past an
// hour. Anything that isn't a real time reads "0:00".
function clock(seconds) {
    const s = isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
    const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
    return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
}

// The entry in Spotify's tray menu that hides its window to the tray
// ("Minimize to Tray") or brings it back ("Show Spotify"), or null. Matched
// by label, so an English Spotify only, and never anything else: its menu
// also holds Exit.
function trayEntry(entries, hide) {
    const want = hide ? /^minimi[sz]e to tray$/i : /^show spotify$/i;
    return entries.find(e => !e.isSeparator && want.test((e.text || "").trim())) || null;
}

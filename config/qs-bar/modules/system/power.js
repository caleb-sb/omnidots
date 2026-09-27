.pragma library

// Battery saver, the CPU power profile and low-battery warnings, as plain
// functions over plain objects so tests/power.bats can drive them under node.
// Power.qml keeps the saver state and SysStats.qml the warning state; both
// feed in battery readings, { onBattery: bool, percent: int }, where a
// percent of 0 or less means UPower doesn't know it yet.

// Battery saver turns itself on at or below this while discharging.
var SAVER_AT = 20;
// Most severe first: a reading below both sends only the critical one.
var WARNINGS = [
    { percent: 10, critical: true },
    { percent: 20, critical: false }
];
// A rise this big while on battery means it charged while nothing was
// watching (suspended, or qs-bar not running), so a new discharge starts.
// Smaller rises are UPower's estimate jittering.
var CHARGED_BY = 3;

function known(percent) {
    return percent > 0;
}

// Whether a reading starts a new discharge cycle: an AC transition (plugged
// in or unplugged), including one missed while qs-bar wasn't running, or a
// charge missed while suspended. The first reading after a fresh start
// (onBattery still null) counts too.
function newCycle(prev, r) {
    if (prev.onBattery !== r.onBattery)
        return true;
    return r.onBattery && known(r.percent) && known(prev.percent) && r.percent >= prev.percent + CHARGED_BY;
}

// ── Battery saver and profile (Power.qml, saved to power.json) ────────

// override: the manual saver choice (null = none) until the next AC
// transition. auto: saver engaged by itself this discharge. onBattery and
// percent: the last reading, null and -1 before the first one.
function initial() {
    return { gameMode: false, override: null, auto: false, onBattery: null, percent: -1 };
}

// State from a parsed state file; anything missing or malformed gets the
// default, so an older power.json (sleepMinutes and gameMode only) works.
function restore(saved) {
    const s = initial();
    if (!saved || typeof saved !== "object")
        return s;
    if (typeof saved.gameMode === "boolean")
        s.gameMode = saved.gameMode;
    if (typeof saved.override === "boolean")
        s.override = saved.override;
    if (typeof saved.auto === "boolean")
        s.auto = saved.auto;
    if (typeof saved.onBattery === "boolean")
        s.onBattery = saved.onBattery;
    if (typeof saved.percent === "number")
        s.percent = saved.percent;
    return s;
}

// A new battery reading. Saver engages at SAVER_AT while discharging and
// stays on until the next AC transition, which also drops a manual choice.
function battery(st, r) {
    const s = Object.assign({}, st);
    if (newCycle(st, r)) {
        s.override = null;
        s.auto = false;
    }
    if (r.onBattery && known(r.percent) && r.percent <= SAVER_AT)
        s.auto = true;
    s.onBattery = r.onBattery;
    if (known(r.percent))
        s.percent = r.percent;
    return s;
}

// Whether battery saver is on. Game mode holds it off; turning game mode off
// brings back whatever the manual choice or the automatic rule says.
function saverOn(st) {
    return !st.gameMode && (st.override !== null ? st.override : st.auto);
}

// The saver toggle. Turning saver on turns game mode off.
function setSaver(st, on) {
    return Object.assign({}, st, { override: on, gameMode: on ? false : st.gameMode });
}

function setGameMode(st, on) {
    return Object.assign({}, st, { gameMode: on });
}

// The CPU power profile to set: "performance", "power-saver" or "balanced".
// "" (leave it alone) without a laptop battery, and until the first reading.
function profile(st, hasBattery) {
    if (!hasBattery || st.onBattery === null)
        return "";
    if (st.gameMode)
        return "performance";
    return saverOn(st) ? "power-saver" : "balanced";
}

// ── Low-battery warnings (SysStats.qml, not saved) ─────────────────────

// warned: the lowest threshold warned about this discharge (101 = none).
function initialWarnings() {
    return { onBattery: null, percent: -1, warned: 101 };
}

// A new battery reading. `warning` is the threshold newly crossed while
// discharging, { critical, percent } with the reading's percent, or null.
// Each threshold warns once per discharge cycle.
function warn(w, r) {
    const s = {
        onBattery: r.onBattery,
        percent: known(r.percent) ? r.percent : w.percent,
        warned: newCycle(w, r) ? 101 : w.warned
    };
    let warning = null;
    if (r.onBattery && known(r.percent)) {
        const t = WARNINGS.find(t => r.percent <= t.percent && t.percent < s.warned);
        if (t) {
            warning = { critical: t.critical, percent: r.percent };
            s.warned = t.percent;
        }
    }
    return { state: s, warning: warning };
}

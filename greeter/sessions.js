.pragma library

// The greeter's session list, from the session files in
// /usr/share/wayland-sessions. Plain JS so tests can run it under node.

// Offered when no session file can be read, so there's always a way in.
const FALLBACK = { name: "Hyprland", command: "start-hyprland", desktopNames: ["Hyprland"] };

// Exec's field codes (%f, %U, ...) have nothing to expand at login; %% is a %.
function stripFieldCodes(exec) {
    return exec.replace(/%(.)/g, (_, c) => (c === "%" ? "%" : "")).replace(/\s+/g, " ").trim();
}

// parse(listing) — the sessions in one or more concatenated session files,
// sorted by name. Only each file's [Desktop Entry] group counts, with its
// unlocalized Name; hidden entries and ones without Exec are left out.
function parse(listing) {
    const entries = [];
    let entry = null;
    for (const raw of listing.split("\n")) {
        const line = raw.trim();
        if (line.startsWith("[")) {
            entry = line === "[Desktop Entry]" ? {} : null;
            if (entry)
                entries.push(entry);
            continue;
        }
        const eq = line.indexOf("=");
        if (!entry || line.startsWith("#") || eq < 0)
            continue;
        const key = line.slice(0, eq).trim();
        if (!(key in entry))
            entry[key] = line.slice(eq + 1).trim();
    }

    const sessions = entries
        .filter(e => e.Name && e.Exec && e.Hidden !== "true" && e.NoDisplay !== "true")
        .map(e => ({
            name: e.Name,
            command: stripFieldCodes(e.Exec),
            desktopNames: (e.DesktopNames || "").split(";").filter(n => n)
        }))
        .filter(s => s.command);
    sessions.sort((a, b) => a.name.localeCompare(b.name));
    return sessions.length ? sessions : [FALLBACK];
}

// defaultIndex(sessions, remembered) — the session named `remembered` (the
// one picked last time), else Hyprland via start-hyprland, else the first.
function defaultIndex(sessions, remembered) {
    const last = sessions.findIndex(s => s.name === remembered);
    if (last >= 0)
        return last;
    const hyprland = sessions.findIndex(s => s.command.split(" ")[0].split("/").pop() === "start-hyprland");
    return hyprland >= 0 ? hyprland : 0;
}

// environment(session) — what greetd starts the session with, as tuigreet
// does for a Wayland session.
function environment(session) {
    const env = ["XDG_SESSION_TYPE=wayland"];
    if (session.desktopNames.length)
        env.push(`XDG_CURRENT_DESKTOP=${session.desktopNames.join(":")}`);
    return env;
}

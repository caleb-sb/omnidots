-- Monitor layout and the lid, the same on every machine and keyed to no
-- hostname. layout() is a pure function; the rest is thin glue that feeds it
-- what Hyprland and sysfs say and applies the result. It runs when the config
-- loads, when Hyprland starts, on the monitor.added and monitor.removed
-- events, and on the lid switch (keybindings.lua).
--
-- With an external output connected, the first by connector name is primary
-- and the built-in panel sits below it, or is off while the lid is closed.
-- Without one, the panel is primary at its preferred mode with automatic
-- position and scale. The primary gets workspaces 1-10, the focus and cursor,
-- the XWayland primary (xrandr), and qs-bar's full bar and notification popups
-- (through the file named by PRIMARY_FILE). override.lua can pick another
-- primary: see override.example.lua.
--
-- Monitor rules are set only for positions and on/off, and only on a machine
-- with a built-in panel. Modes and scales stay with hyprland.lua's default rule
-- and override.lua; a machine without a panel keeps its rules as they are.
--
-- The lid: while Hyprland runs on a laptop it holds logind's
-- handle-lid-switch inhibitor, so logind doesn't suspend behind hyprlock's
-- back. Docked, the lid turns the panel off and on. Undocked with a battery,
-- closing it locks with hyprlock, then suspends. Without a battery it does
-- nothing, and nothing here ever suspends a desktop.

local M = {}

-- Prefixes the /sys and /proc paths read. Tests point it at a fake machine.
M.root = ""

-- The per-machine primary: an output name, or a list of names in order of
-- preference. Used when connected; set it in override.lua.
M.primary = nil

local WORKSPACES = 10

-- qs-bar reads the primary output's name from here.
local PRIMARY_FILE = "omnidots-primary-output" -- in $XDG_RUNTIME_DIR

-- Held for as long as Hyprland (the shell's parent) runs.
local LID_INHIBITOR = "exec systemd-inhibit --what=handle-lid-switch --who=Hyprland"
    .. ' --why="Hyprland handles the lid" tail --pid="$PPID" -f /dev/null'

-- Suspends only once hyprlock is up (or already was).
local LOCK_AND_SUSPEND = "pidof hyprlock >/dev/null || hyprlock & sleep 1;"
    .. " pidof hyprlock >/dev/null && systemctl suspend"

-- Connector names of built-in panels: eDP-1, LVDS-1, DSI-1.
local function is_builtin(name)
    return name:match("^eDP%-") or name:match("^LVDS%-") or name:match("^DSI%-")
end

-- Connector order: by type, then by number, so DP-2 comes before DP-10 and
-- both before HDMI-A-1.
local function connector_less(a, b)
    local ta, na = a.name:match("^(.-)%-?(%d+)$")
    local tb, nb = b.name:match("^(.-)%-?(%d+)$")
    if ta and tb then
        if ta ~= tb then
            return ta < tb
        end
        return tonumber(na) < tonumber(nb)
    end
    return a.name < b.name
end

-- The first output in `wanted` (a name or a list of names) that is in
-- `candidates`, if any.
local function preferred(wanted, candidates)
    if type(wanted) == "string" then
        wanted = { wanted }
    end
    for _, name in ipairs(wanted or {}) do
        for _, o in ipairs(candidates) do
            if o.name == name then
                return o
            end
        end
    end
end

-- layout(outputs, state) — where every output goes.
--
-- outputs: the connected outputs, as { name = "DP-1", height = 1440 }, with
-- height in logical px (nil when the output is off).
-- state: { lid_closed = bool, primary = name or list of names }.
--
-- Returns { primary = name, docked = bool, rules = { { output, position,
-- disabled }, ... } }. rules is empty without a built-in panel: such a
-- machine keeps the shared and per-machine monitor rules as they are.
function M.layout(outputs, state)
    local externals, panels = {}, {}
    for _, o in ipairs(outputs) do
        table.insert(is_builtin(o.name) and panels or externals, o)
    end
    table.sort(externals, connector_less)
    table.sort(panels, connector_less)

    local docked = #externals > 0
    local panels_on = not (docked and state.lid_closed)

    local candidates = {}
    for _, o in ipairs(externals) do
        candidates[#candidates + 1] = o
    end
    if panels_on then
        for _, o in ipairs(panels) do
            candidates[#candidates + 1] = o
        end
    end
    local primary = preferred(state.primary, candidates) or candidates[1]

    local result = { primary = primary and primary.name, docked = docked, rules = {} }
    if #panels == 0 then
        return result
    end

    local rules = result.rules
    local function add(output, position)
        rules[#rules + 1] = { output = output.name, position = position, disabled = position == nil }
    end

    if not docked then
        for _, p in ipairs(panels) do
            add(p, "auto")
        end
        return result
    end

    add(primary, "0x0")
    for _, e in ipairs(externals) do
        if e ~= primary then
            add(e, "auto-right")
        end
    end
    -- The first panel goes right below an external primary; any other goes
    -- below everything.
    local below = primary.height and not is_builtin(primary.name) and "0x" .. math.ceil(primary.height)
    for _, p in ipairs(panels) do
        if not panels_on then
            add(p, nil)
        elseif p ~= primary then
            add(p, below or "auto-down")
            below = nil
        end
    end
    return result
end

---- Glue ----

local function read_line(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    return line
end

-- The entries of a directory, or none if it doesn't exist.
local function list_dir(dir)
    local entries = {}
    local p = io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
    if p then
        for entry in p:lines() do
            entries[#entries + 1] = entry
        end
        p:close()
    end
    return entries
end

-- Connected built-in panels, from sysfs (card1-eDP-1 is eDP-1), so a panel
-- that is off is still known.
local function connected_panels(root)
    local found = {}
    local drm = root .. "/sys/class/drm/"
    for _, entry in ipairs(list_dir(drm)) do
        local name = entry:match("^card%d+%-(.+)$")
        if name and is_builtin(name) and read_line(drm .. entry .. "/status") == "connected" then
            found[#found + 1] = name
        end
    end
    return found
end

-- A battery that powers the machine; a wireless mouse's has scope Device.
-- The same rule as the installer's HAS_BATTERY (installer/detect.sh).
local function has_battery(root)
    local supplies = root .. "/sys/class/power_supply/"
    for _, supply in ipairs(list_dir(supplies)) do
        if read_line(supplies .. supply .. "/type") == "Battery"
            and read_line(supplies .. supply .. "/scope") ~= "Device" then
            return true
        end
    end
    return false
end

local function lid_closed_now(root)
    local lids = root .. "/proc/acpi/button/lid/"
    for _, lid in ipairs(list_dir(lids)) do
        if (read_line(lids .. lid .. "/state") or ""):match("closed") then
            return true
        end
    end
    return false
end

-- The enabled monitors, with the one an event adds or removes: Hyprland's
-- list may not have caught up yet. Its stand-in outputs don't count.
local function enabled_monitors(added, removed)
    local list = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= removed and m.name ~= (added and added.name) then
            list[#list + 1] = m
        end
    end
    list[#list + 1] = added
    for i = #list, 1, -1 do
        if list[i].name == "FALLBACK" or list[i].name:match("^HEADLESS%-") then
            table.remove(list, i)
        end
    end
    return list
end

-- The outputs to lay out: the enabled monitors and the connected panels,
-- which include any the lid turned off.
local function outputs(monitors)
    local list, seen = {}, {}
    for _, m in ipairs(monitors) do
        local height = (m.transform or 0) % 2 == 1 and m.width or m.height
        list[#list + 1] = { name = m.name, height = height / m.scale }
        seen[m.name] = true
    end
    for _, name in ipairs(connected_panels(M.root)) do
        if not seen[name] then
            list[#list + 1] = { name = name }
        end
    end
    return list
end

local function contains(monitors, name)
    for _, m in ipairs(monitors) do
        if m.name == name then
            return true
        end
    end
    return false
end

local function write_primary(name)
    local dir = os.getenv("XDG_RUNTIME_DIR")
    local f = dir and io.open(dir .. "/" .. PRIMARY_FILE, "w")
    if f then
        f:write(name, "\n")
        f:close()
    end
end

-- What was last applied. The Lua state starts afresh on every config load,
-- as do Hyprland's rules.
local state = { lid_closed = false, rules = nil, primary = nil, settled = nil }

local function rules_key(rules)
    local parts = {}
    for i, r in ipairs(rules) do
        parts[i] = r.output .. "@" .. tostring(r.position) .. (r.disabled and "-off" or "")
    end
    return table.concat(parts, " ")
end

-- apply(opts) — lay out the outputs and apply what changed. opts.added is
-- the monitor being added, opts.removed the name of one being removed.
-- opts.settle also moves workspaces 1-10, the focus and the XWayland primary
-- to a new primary once it is on (always with opts.start); opts.force re-sends
-- the monitor rules.
local function apply(opts)
    opts = opts or {}
    local monitors = enabled_monitors(opts.added, opts.removed)
    local l = M.layout(outputs(monitors), { lid_closed = state.lid_closed, primary = M.primary })

    local key = rules_key(l.rules)
    if opts.force or key ~= state.rules then
        for _, rule in ipairs(l.rules) do
            hl.monitor(rule)
        end
        state.rules = key
    end

    if l.primary and l.primary ~= state.primary then
        for i = 1, WORKSPACES do
            hl.workspace_rule({ workspace = tostring(i), monitor = l.primary })
        end
        write_primary(l.primary)
    end
    state.primary = l.primary

    if opts.settle and l.primary and (opts.start or l.primary ~= state.settled) and contains(monitors, l.primary) then
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.id >= 1 and ws.id <= WORKSPACES and ws.monitor and ws.monitor.name ~= l.primary then
                hl.dispatch(hl.dsp.workspace.move({ workspace = ws.id, monitor = l.primary }))
            end
        end
        hl.dispatch(hl.dsp.focus({ monitor = l.primary }))
        -- Xwayland lists a new output a moment after Hyprland does.
        hl.exec_cmd("sleep 1; xrandr --output " .. l.primary .. " --primary")
        state.settled = l.primary
    end
    return l
end

-- Lid closed while undocked, on a machine with a battery: lock, then suspend.
local function suspend_if_lid_closed(l)
    if state.lid_closed and not l.docked and has_battery(M.root) then
        hl.exec_cmd(LOCK_AND_SUSPEND)
    end
end

-- setup() — apply the layout now and on every monitor change. hyprland.lua
-- calls it last, after override.lua.
function M.setup()
    state.lid_closed = lid_closed_now(M.root)
    -- A reload leaves the workspaces and focus where they are.
    local l = apply()
    if l.primary and contains(hl.get_monitors(), l.primary) then
        state.settled = l.primary
    end

    hl.on("monitor.added", function(mon)
        apply({ settle = true, added = mon })
    end)
    hl.on("monitor.removed", function(mon)
        local l = apply({ settle = true, removed = mon and mon.name })
        -- Unplugged with the lid closed. Not for the panel itself, which the
        -- lid turns off, and which may blink out and back on around a resume.
        if mon and not is_builtin(mon.name) then
            suspend_if_lid_closed(l)
        end
    end)
    hl.on("hyprland.start", function()
        apply({ settle = true, start = true })
        if #connected_panels(M.root) > 0 then
            hl.exec_cmd(LID_INHIBITOR)
        end
    end)
end

-- lid(closed) — the lid switch was closed (true) or opened (false).
function M.lid(closed)
    state.lid_closed = closed
    local l = apply({ settle = true })
    if closed then
        suspend_if_lid_closed(l)
    end
end

-- force_panel() — turn the built-in panel off and on again, for when Hyprland
-- leaves it off after an external monitor is unplugged. Treats the lid as open.
function M.force_panel()
    state.lid_closed = false
    for _, name in ipairs(connected_panels(M.root)) do
        hl.monitor({ output = name, disabled = true })
    end
    state.timer = hl.timer(function()
        apply({ settle = true, force = true })
    end, { timeout = 1000, type = "oneshot" })
end

return M

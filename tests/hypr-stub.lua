-- Runs Hyprland Lua config under a stub `hl` that prints what the config
-- asks of Hyprland, one per line, in call order:
--
--   env NAME=VALUE
--   monitor OUTPUT MODE POSITION SCALE [disabled]
--   workspace WORKSPACE MONITOR
--   exec COMMAND
--   dispatch DISPATCHER KEY=VALUE...    (e.g. dispatch focus monitor=DP-1)
--
-- Every other hl call is accepted and ignored, and nothing is launched.
-- Queries answer from globals the chunk may set: MONITORS for
-- hl.get_monitors() (e.g. { { name = "DP-1", width = 2560, height = 1440,
-- scale = 1 } }) and WORKSPACES for hl.get_workspaces() (e.g. { { id = 1,
-- monitor = { name = "DP-1" } } }). Event handlers land in HANDLERS[event]
-- (a list), which emit(event, ...) calls, and bound actions in BINDS[keys].
-- show_bind(keys) prints a bind's sorted flags and what it runs, e.g.
-- `bind XF86AudioMute [locked] exec COMMAND` for an exec_cmd bind.
-- Timers fire at once.
--
-- Usage: luajit hypr-stub.lua <config-dir> <lua-chunk>
-- The chunk runs with <config-dir> on package.path and CONFIG_DIR set to it,
-- e.g. 'dofile(CONFIG_DIR .. "/hyprland.lua")'.

CONFIG_DIR = assert(arg[1], "usage: hypr-stub.lua <config-dir> <lua-chunk>")
local chunk = assert(arg[2], "usage: hypr-stub.lua <config-dir> <lua-chunk>")

-- Any field of the stub is another stub, and calling one returns a stub, so
-- chains like hl.dsp.window.float({ ... }) work.
local function stub()
    return setmetatable({}, {
        __index = function() return stub() end,
        __call = function() return stub() end,
    })
end

hl = stub()

MONITORS, WORKSPACES, HANDLERS, BINDS, BIND_OPTS = {}, {}, {}, {}, {}

function hl.env(name, value)
    print("env " .. name .. "=" .. value)
end

function hl.monitor(rule)
    print(string.format("monitor %s %s %s %s%s",
        rule.output, rule.mode, rule.position, tostring(rule.scale),
        rule.disabled and " disabled" or ""))
end

function hl.workspace_rule(rule)
    print("workspace " .. rule.workspace .. " " .. rule.monitor)
end

function hl.exec_cmd(cmd)
    print("exec " .. cmd)
end

-- hl.dsp.<path>(args) returns a description that hl.dispatch prints.
local function dispatcher(path)
    return setmetatable({}, {
        __index = function(_, key) return dispatcher(path and path .. "." .. key or key) end,
        __call = function(_, args) return { path = path, args = args or {} } end,
    })
end
hl.dsp = dispatcher()

function hl.dispatch(d)
    local args = {}
    for k, v in pairs(d.args) do
        args[#args + 1] = k .. "=" .. tostring(v)
    end
    table.sort(args)
    print(table.concat({ "dispatch", d.path, unpack(args) }, " "))
end

function hl.on(event, fn)
    HANDLERS[event] = HANDLERS[event] or {}
    table.insert(HANDLERS[event], fn)
end

function emit(event, ...)
    for _, fn in ipairs(HANDLERS[event] or {}) do
        fn(...)
    end
end

function hl.bind(keys, action, opts)
    BINDS[keys] = action
    BIND_OPTS[keys] = opts or {}
end

function show_bind(keys)
    local action = assert(BINDS[keys], "nothing bound to " .. keys)
    local what = type(action) == "function" and "function"
        or action.path == "exec_cmd" and "exec " .. action.args
        or action.path
    local flags = {}
    for flag, on in pairs(BIND_OPTS[keys]) do
        if on then flags[#flags + 1] = flag end
    end
    table.sort(flags)
    print(string.format("bind %s [%s] %s", keys, table.concat(flags, ","), what))
end

function hl.timer(fn)
    fn()
end

function hl.get_monitors() return MONITORS end
function hl.get_workspaces() return WORKSPACES end

package.path = CONFIG_DIR .. "/?.lua;" .. package.path
assert(loadstring(chunk))()

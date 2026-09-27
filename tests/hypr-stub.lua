-- Runs Hyprland Lua config under a stub `hl` that prints the environment and
-- monitor rules the config sets, one per line, in call order:
--
--   env NAME=VALUE
--   monitor OUTPUT MODE POSITION SCALE
--
-- Every other hl call is accepted and ignored, and nothing is launched.
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

function hl.env(name, value)
    print("env " .. name .. "=" .. value)
end

function hl.monitor(rule)
    print(string.format("monitor %s %s %s %s",
        rule.output, rule.mode, rule.position, tostring(rule.scale)))
end

package.path = CONFIG_DIR .. "/?.lua;" .. package.path
assert(loadstring(chunk))()

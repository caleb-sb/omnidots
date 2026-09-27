-- GPU environment, detected each time Hyprland starts or reloads, so the same
-- config fits every machine. The hybrid rule matches the installer's
-- (installer/detect.sh).
--
-- Hybrid: a discrete GPU without display outputs (PCI class 0302, "3D
-- controller") next to an Intel or AMD GPU, as in a muxless laptop. Hyprland
-- renders on the first device in AQ_DRM_DEVICES, so the integrated GPUs go
-- first (Intel, then AMD, then the rest) and the discrete one can sleep. It
-- stays in the list so outputs wired to it keep working. Card numbers can
-- change between boots, which is fine here: the list is rebuilt at every start.
--
-- NVIDIA renders: its driver is loaded (it creates /proc/driver/nvidia/version)
-- and the machine isn't hybrid. Then GL, VA-API and the NVIDIA VA-API driver
-- are pointed at NVIDIA, as https://wiki.hypr.land/Nvidia/ recommends. On a
-- hybrid those would wake the discrete GPU for every app, so they stay unset.
--
-- A desktop card with outputs of its own (class 0300) isn't hybrid even next
-- to an iGPU, so there Hyprland picks its GPU itself.

local M = {}

-- Lua can't list a directory, so cards are probed by number.
local MAX_CARDS = 16

-- Integrated GPU vendors, in the order they go first.
local INTEGRATED_RANK = { ["8086"] = 1, ["1002"] = 2 }

local function read_line(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    return line
end

-- gpus(root) — the DRM cards backed by a PCI device, in card order, as
-- { card = "card1", vendor = "10de", class = "0302" }.
local function gpus(root)
    local found = {}
    for n = 0, MAX_CARDS - 1 do
        local dev = root .. "/sys/class/drm/card" .. n .. "/device/"
        local vendor, class = read_line(dev .. "vendor"), read_line(dev .. "class")
        if vendor and class then
            found[#found + 1] = { card = "card" .. n, vendor = vendor:sub(3), class = class:sub(3, 6) }
        end
    end
    return found
end

local function is_hybrid(list)
    local dgpu, igpu = false, false
    for _, gpu in ipairs(list) do
        if gpu.class == "0302" then
            dgpu = true
        elseif INTEGRATED_RANK[gpu.vendor] then
            igpu = true
        end
    end
    return dgpu and igpu
end

-- integrated_first(list) — the cards' device paths, integrated GPUs first and
-- otherwise in card order, joined with ':' for AQ_DRM_DEVICES.
local function integrated_first(list)
    local ranked = {}
    for i, gpu in ipairs(list) do
        ranked[i] = { rank = INTEGRATED_RANK[gpu.vendor] or 3, index = i, card = gpu.card }
    end
    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.index < b.index
    end)
    local paths = {}
    for i, gpu in ipairs(ranked) do
        paths[i] = "/dev/dri/" .. gpu.card
    end
    return table.concat(paths, ":")
end

-- apply([root]) — set the GPU environment through hl.env. root prefixes the
-- /sys and /proc paths read (tests pass a fake machine); it defaults to "".
function M.apply(root)
    root = root or ""
    local list = gpus(root)
    if is_hybrid(list) then
        hl.env("AQ_DRM_DEVICES", integrated_first(list))
    elseif read_line(root .. "/proc/driver/nvidia/version") then
        hl.env("LIBVA_DRIVER_NAME", "nvidia")
        hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
        hl.env("NVD_BACKEND", "direct")
    end
end

return M

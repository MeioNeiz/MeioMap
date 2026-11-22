-- Unexplored areas: the zone overlays Blizzard's exploration pin leaves out
-- (C_MapExplorationInfo returns only explored ones), drawn with the same tiling on our own
-- frame inside that pin, so they share its position, size and fade-in.
local _, ns = ...

local TINT = { 0.55, 0.62, 0.8 }

local parsed = {}

-- ns.OVERLAYS[mapID]: "w h x y fid fid ...;..." (gen/gen-data.mjs)
local function Overlays(mapID)
    local list = parsed[mapID]
    if list then return list end
    list = {}
    for entry in (ns.OVERLAYS[mapID] or ""):gmatch("[^;]+") do
        local n = {}
        for v in entry:gmatch("-?%d+") do n[#n + 1] = tonumber(v) end
        local fileDataIDs = {}
        for i = 5, #n do fileDataIDs[#fileDataIDs + 1] = n[i] end
        list[#list + 1] = { textureWidth = n[1], textureHeight = n[2], offsetX = n[3],
            offsetY = n[4], fileDataIDs = fileDataIDs }
    end
    parsed[mapID] = list
    return list
end
ns.Overlays = Overlays

local function Key(o) return o.offsetX .. ":" .. o.offsetY .. ":" .. (o.fileDataIDs[1] or 0) end

local map, pin, holder, pool

local function TileSize(mapID)
    local layers = C_Map.GetMapArtLayers(mapID)
    local index = map:GetCanvasContainer():GetCurrentLayerIndex() or 1
    local layer = layers and (layers[index] or layers[1])
    return layer and layer.tileWidth or 256, layer and layer.tileHeight or 256
end

-- size of the last, partial tile and the power-of-two file it sits in
local function Partial(total, tile)
    local pixels = total % tile
    if pixels == 0 then pixels = tile end
    local file = 16
    while file < pixels do file = file * 2 end
    return pixels, file
end

local function DrawOverlay(o, tileW, tileH, r, g, b)
    local wide = math.ceil(o.textureWidth / tileW)
    local tall = math.ceil(o.textureHeight / tileH)
    for j = 1, tall do
        local pixelH, fileH = tileH, tileH
        if j == tall then pixelH, fileH = Partial(o.textureHeight, tileH) end
        for k = 1, wide do
            local pixelW, fileW = tileW, tileW
            if k == wide then pixelW, fileW = Partial(o.textureWidth, tileW) end
            local fid = o.fileDataIDs[(j - 1) * wide + k]
            if fid then
                local tex = pool:Acquire()
                tex:SetSize(pixelW, pixelH)
                tex:SetTexCoord(0, pixelW / fileW, 0, pixelH / fileH)
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", holder, "TOPLEFT", o.offsetX + tileW * (k - 1),
                    -(o.offsetY + tileH * (j - 1)))
                tex:SetTexture(fid, nil, nil, "TRILINEAR")
                tex:SetVertexColor(r, g, b)
                tex:Show()
            end
        end
    end
end

local function Draw()
    if not pool then return end
    pool:ReleaseAll()
    local mapID = map:GetMapID()
    if not (ns.db.reveal and mapID and ns.OVERLAYS[mapID]) then return end
    local explored = {}
    for _, o in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        explored[Key(o)] = true
    end
    local tileW, tileH = TileSize(mapID)
    local r, g, b = 1, 1, 1
    if ns.db.tint then r, g, b = TINT[1], TINT[2], TINT[3] end
    for _, o in ipairs(Overlays(mapID)) do
        if not explored[Key(o)] then DrawOverlay(o, tileW, tileH, r, g, b) end
    end
end

local function FindPin()
    for p in map:EnumeratePinsByTemplate("MapExplorationPinTemplate") do return p end
end

function ns.SetupReveal(worldMap)
    map = worldMap
    pin = FindPin()
    if not pin then return end
    holder = CreateFrame("Frame", nil, pin)
    holder:SetAllPoints(pin)
    pool = CreateTexturePool(holder, "ARTWORK", 0)
    hooksecurefunc(pin, "RefreshOverlays", Draw)
    Draw()
end

ns.RefreshReveal = Draw

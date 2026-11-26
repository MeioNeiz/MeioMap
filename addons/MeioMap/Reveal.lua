-- Unexplored areas: the zone overlays Blizzard's exploration pin leaves out
-- (C_MapExplorationInfo returns only explored ones), drawn with the same tiling on our own
-- frame inside that pin, so they share its position, size and fade-in.
local _, ns = ...

-- Greyscale first: the overlays' soft edges differ slightly in hue where they meet, which a
-- plain colour multiply turns into visible seams; brightness matches, so grey hides them
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

local function ExploredKeys(mapID)
    local explored = {}
    for _, o in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        explored[Key(o)] = true
    end
    return explored
end

-- Area IDs of a zone's unexplored overlays, in map order; nil for a zone without data
function ns.UnexploredAreas(mapID)
    local areas = ns.OVERLAY_AREAS and ns.OVERLAY_AREAS[mapID]
    if not areas then return end
    local perOverlay = {}
    for entry in areas:gmatch("[^;]+") do perOverlay[#perOverlay + 1] = entry end
    local explored = ExploredKeys(mapID)
    local list, seen = {}, {}
    for i, o in ipairs(Overlays(mapID)) do
        if not explored[Key(o)] then
            for id in (perOverlay[i] or ""):gmatch("%d+") do
                id = tonumber(id)
                if id > 0 and not seen[id] then
                    seen[id] = true
                    list[#list + 1] = id
                end
            end
        end
    end
    return list
end

local map, pin, holder, pool

-- The pin's own layer index, set by RefreshOverlays just before Draw runs: asking the
-- canvas before the map has first been shown errors (no zoom levels yet)
local function TileSize(mapID)
    local layers = C_Map.GetMapArtLayers(mapID)
    local index = pin.layerIndex or 1
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

local function DrawOverlay(o, tileW, tileH, tint)
    local wide = math.ceil(o.textureWidth / tileW)
    local tall = math.ceil(o.textureHeight / tileH)
    for j = 1, tall do
        local pixelH, fileH = tileH, tileH
        if j == tall then pixelH, fileH = Partial(o.textureHeight, tileH) end
        for k = 1, wide do
            local pixelW, fileW = tileW, tileW
            if k == wide then pixelW, fileW = Partial(o.textureWidth, tileW) end
            local fid = o.fileDataIDs[(j - 1) * wide + k]
            if fid and fid > 0 then
                local tex = pool:Acquire()
                map:AddMaskableTexture(tex)
                tex:SetSize(pixelW, pixelH)
                tex:SetTexCoord(0, pixelW / fileW, 0, pixelH / fileH)
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", holder, "TOPLEFT", o.offsetX + tileW * (k - 1),
                    -(o.offsetY + tileH * (j - 1)))
                tex:SetTexture(fid, nil, nil, "TRILINEAR")
                tex:SetDesaturated(tint)
                if tint then
                    tex:SetVertexColor(TINT[1], TINT[2], TINT[3])
                else
                    tex:SetVertexColor(1, 1, 1)
                end
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
    if not map:IsShown() then return end
    local explored = ExploredKeys(mapID)
    local tileW, tileH = TileSize(mapID)
    for _, o in ipairs(Overlays(mapID)) do
        if not explored[Key(o)] then DrawOverlay(o, tileW, tileH, ns.db.tint) end
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

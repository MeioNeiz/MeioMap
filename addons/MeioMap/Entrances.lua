-- Dungeon and raid entrances on zone and continent maps (EntranceData.lua). Our own data
-- provider and pin template: nothing of WorldMapFrame's is written, pins exist only while the
-- map is open, and Blizzard's own entrance pins win on any map where the client has them.
local _, ns = ...

local TEMPLATE = "MeioMapDungeonPinTemplate"
-- Interface\Minimap\Dungeon and Raid: the portal swirls (the modern atlas isn't installed)
local ICON_DUNGEON, ICON_RAID = 1502543, 1502548
local SIZE_ZONE, SIZE_CONTINENT = 32, 20
local MUTED = "|cff999999"
local CLICKS = { "Click: open its map", "Shift-click: waypoint here", "Right-click: zoom out" }

local provider, map

local function On() return ns.db and ns.db.entrances end

local function Name(id)
    local d = ns.DUNGEONS[id]
    if GetLocale() ~= "enUS" and GetRealZoneText then
        local name = GetRealZoneText(id)
        if type(name) == "string" and name ~= "" then return name end
    end
    return d and d.name or ("Instance " .. id)
end
ns.DungeonName = Name

local function IsRaid(id)
    local l = ns.DUNGEON_LEVELS[id]
    return l and l[1] == 60 and l[2] == 60
end

-- the client's own entrance pins, should a later build fill its dungeon journal
local function BlizzardHas(mapID)
    if not (C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then
        return false
    end
    if GetCVarBool and not GetCVarBool("showDungeonEntrancesOnMap") then return false end
    local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
    return ok and type(list) == "table" and #list > 0
end

-- { x, y, ids, size, raid } per pin on a map
function ns.EntrancePins(mapID)
    local out = {}
    local list = ns.ENTRANCES[mapID]
    if not list or BlizzardHas(mapID) then return out end
    local info = C_Map.GetMapInfo(mapID)
    local size = info and info.mapType == Enum.UIMapType.Continent and SIZE_CONTINENT
        or SIZE_ZONE
    for _, e in ipairs(list) do
        local ids = { unpack(e, 3) }
        local raid = true
        for _, id in ipairs(ids) do raid = raid and IsRaid(id) end
        out[#out + 1] = { x = e[1], y = e[2], ids = ids, size = size, raid = raid }
    end
    return out
end

-- a zone map holding the same entrance: waypoints can't go on continent maps
local function WaypointSpot(mapID, d)
    if C_Map.CanSetUserWaypointOnMap(mapID) then return mapID, d.x, d.y end
    for zoneID, list in pairs(ns.ENTRANCES) do
        local info = zoneID ~= mapID and C_Map.GetMapInfo(zoneID)
        if info and info.mapType ~= Enum.UIMapType.Continent then
            for _, e in ipairs(list) do
                if e[3] == d.ids[1] and C_Map.CanSetUserWaypointOnMap(zoneID) then
                    return zoneID, e[1], e[2]
                end
            end
        end
    end
end

local function Waypoint(mapID, d)
    if not C_Map.CanSetUserWaypointOnMap then return end
    local spotMap, x, y = WaypointSpot(mapID, d)
    local name = Name(d.ids[1])
    if not (spotMap and ns.SetWaypoint(spotMap, x, y, name)) then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("No waypoint can go on this map.", 1, 0.82, 0) end
        return
    end
    ns.Say("waypoint set on " .. name)
end

local function Open(owner, ids)
    if not ns.db.dungeons then
        ns.Say("dungeon maps are " .. ns.OnOff(false) .. ": |cffffd100/meiomap dungeons on|r")
        return
    end
    if #ids == 1 or not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.ShowDungeon(ids[1])
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, id in ipairs(ids) do
            root:CreateButton(Name(id), function() ns.ShowDungeon(id) end)
        end
    end)
end

function ns.EntranceTooltip(owner, d)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local nf = NORMAL_FONT_COLOR
    for _, id in ipairs(d.ids) do
        local l = ns.DUNGEON_LEVELS[id]
        local right = l and ((IsRaid(id) and "Raid " or "") .. ns.LevelRange(l[1], l[2])) or ""
        GameTooltip:AddDoubleLine(Name(id), right, nf.r, nf.g, nf.b, 1, 1, 1)
    end
    if IsShiftKeyDown() then
        GameTooltip:AddLine(" ")
        for _, line in ipairs(CLICKS) do GameTooltip:AddLine(MUTED .. line .. "|r") end
    elseif not GameTooltip.meioShiftHint then
        GameTooltip:AddLine(MUTED .. "Shift: more|r")
        GameTooltip.meioShiftHint = true
    end
    GameTooltip:Show()
end

--------------------------------------------------
-- Pins
--------------------------------------------------
local Pin = {}

function Pin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
end

function Pin:OnAcquired(d)
    self.data = d
    self:UseFrameLevelType("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
    self:SetSize(d.size, d.size)
    self.Icon:SetTexture(d.raid and ICON_RAID or ICON_DUNGEON)
    self:SetPosition(d.x, d.y)
end

function Pin:OnReleased()
    self.data = nil
end

-- the map sets right-click passthrough on every pin it acquires, which is protected in a
-- fight: ours take the right-click themselves and zoom out
function Pin:SetPassThroughButtons() end

function Pin:OnMouseEnter()
    if self.data then ns.EntranceTooltip(self, self.data) end
end

function Pin:OnMouseLeave()
    GameTooltip_Hide()
end

function Pin:OnClick(button)
    local d, m = self.data, self:GetMap()
    if not d then return end
    if button == "RightButton" then
        m:NavigateToParentMap()
    elseif IsShiftKeyDown() then
        Waypoint(m:GetMapID(), d)
    else
        Open(self, d.ids)
    end
end

--------------------------------------------------
-- Data provider
--------------------------------------------------
function ns.SetupEntrances(m)
    if provider or not (m and MapCanvasDataProviderMixin and MapCanvasPinMixin) then return end
    map = m
    MeioMapDungeonPinMixin = CreateFromMixins(MapCanvasPinMixin, Pin)
    GameTooltip:HookScript("OnTooltipCleared", function(tip) tip.meioShiftHint = nil end)
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        if not On() then return end
        local ok, pins = pcall(ns.EntrancePins, self:GetMap():GetMapID())
        if not ok then return geterrorhandler()(pins) end
        for _, d in ipairs(pins) do self:GetMap():AcquirePin(TEMPLATE, d) end
    end
    map:AddDataProvider(provider)
end

-- the toggle flipped: only an open map redraws now
function ns.RefreshEntrances()
    if provider and map and map:IsShown() then provider:RefreshAllData() end
end

-- Search box on the world map's top bar: zones, dungeons and flight masters by name. Zones
-- open their map; flight masters open theirs with a waypoint; dungeons open their own map
-- (Dungeon maps on) or their entrance's zone with a waypoint. Built on first use.
local _, ns = ...

local ROWS = 8
local ROW_H = 18
local MUTED = "|cff999999"
local ROOTS = { 946, 947 }

local map, box, list
local places, zones
local results, selected = {}, 1
-- the place each result row shows
local rowPlace = {}

local function Key(s) return (s or ""):lower():gsub("[^%w]", "") end

-- every zone (and city) under Azeroth, by name
local function Zones()
    if zones then return zones end
    zones = {}
    local seen = {}
    for _, root in ipairs(ROOTS) do
        local kids = C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(root, nil, true)
        for _, info in ipairs(kids or {}) do
            if info.mapType == Enum.UIMapType.Zone and not seen[info.mapID]
                and type(info.name) == "string" and info.name ~= "" then
                seen[info.mapID] = true
                zones[#zones + 1] = { name = info.name, mapID = info.mapID }
            end
        end
    end
    table.sort(zones, function(a, b) return a.name < b.name end)
    return zones
end

-- exact name, then the start of one, then anywhere in one
function ns.FindZone(text)
    local key = Key(text)
    if key == "" then return end
    local start, inside
    for _, z in ipairs(Zones()) do
        local k = Key(z.name)
        if k == key then return z.mapID end
        if not start and k:sub(1, #key) == key then start = z.mapID end
        if not inside and k:find(key, 1, true) then inside = z.mapID end
    end
    return start or inside
end

local function Faction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    local enum = Enum.FlightPathFaction
    if not enum then return end
    return f == "Horde" and enum.Horde or f == "Alliance" and enum.Alliance or nil
end

local function FlightMasters(out)
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return end
    local mine, neutral = Faction(), Enum.FlightPathFaction and Enum.FlightPathFaction.Neutral
    local seen = {}
    for _, z in ipairs(Zones()) do
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, z.mapID)
        for _, n in ipairs(ok and nodes or {}) do
            local own = n.faction == nil or mine == nil or n.faction == mine
                or n.faction == neutral
            if own and not seen[n.nodeID] and n.position and type(n.name) == "string" then
                seen[n.nodeID] = true
                out[#out + 1] = { kind = "flight", name = n.name, mapID = z.mapID,
                    x = n.position.x, y = n.position.y, detail = "Flight master" }
            end
        end
    end
end

local function Dungeons(out)
    for id in pairs(ns.DUNGEONS or {}) do
        local l = ns.DUNGEON_LEVELS and ns.DUNGEON_LEVELS[id]
        local raid = MeioMapAPI.IsRaid(id)
        local detail = (raid and "Raid" or "Dungeon")
            .. (l and (" " .. ns.LevelRange(l[1], l[2])) or "")
        local mapID, x, y = MeioMapAPI.Entrance(id)
        out[#out + 1] = { kind = "dungeon", id = id, name = ns.DungeonName(id),
            mapID = mapID, x = x, y = y, detail = detail }
    end
end

local function Places()
    if places then return places end
    places = {}
    for _, z in ipairs(Zones()) do
        places[#places + 1] = { kind = "zone", name = z.name, mapID = z.mapID, detail = "Zone" }
    end
    Dungeons(places)
    FlightMasters(places)
    for _, p in ipairs(places) do p.key = Key(p.name) end
    return places
end

local KIND_ORDER = { zone = 1, dungeon = 2, flight = 3 }

-- names starting with the text first, then containing it; zones before dungeons before
-- flight masters, then by name
function ns.SearchPlaces(text)
    local key = Key(text)
    local out = {}
    if key == "" then return out end
    for _, p in ipairs(Places()) do
        local at = p.key:find(key, 1, true)
        if at then out[#out + 1] = { p = p, rank = at == 1 and 0 or 1 } end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        local ka, kb = KIND_ORDER[a.p.kind], KIND_ORDER[b.p.kind]
        if ka ~= kb then return ka < kb end
        return a.p.name < b.p.name
    end)
    for i, r in ipairs(out) do out[i] = r.p end
    return out
end

local function Waypoint(p)
    if p.mapID and p.x and ns.SetWaypoint(p.mapID, p.x, p.y, p.name) then
        ns.Say("waypoint set on " .. p.name)
        return true
    end
end

function ns.PickPlace(p, shift)
    if not (p and map) then return end
    if p.kind == "dungeon" then
        if not shift and ns.db.dungeons and MeioMapAPI.HasMap(p.id) then
            ns.ShowDungeon(p.id)
        elseif p.mapID then
            ns.HideDungeon()
            map:SetMapID(p.mapID)
            Waypoint(p)
        elseif ns.db.dungeons then
            -- a Forever dungeon: no entrance in the data, its boss list
            ns.ShowDungeon(p.id)
        end
        return
    end
    ns.HideDungeon()
    if p.mapID then map:SetMapID(p.mapID) end
    if p.kind == "flight" then Waypoint(p) end
end

--------------------------------------------------
-- Box and results
--------------------------------------------------
local function HideList()
    if list then list:Hide() end
end

local function Row(i)
    local row = list.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 8, -6 - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", -8, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(1, 0.82, 0, 0.15)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetJustifyH("LEFT")
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("RIGHT", -2, 0)
    row.detail:SetJustifyH("RIGHT")
    row.name:SetPoint("RIGHT", row.detail, "LEFT", -6, 0)
    row.name:SetWordWrap(false)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function()
        ns.PickPlace(rowPlace[i], IsShiftKeyDown())
        box:ClearFocus()
        HideList()
    end)
    list.rows[i] = row
    return row
end

local function ShowResults()
    local n = math.min(#results, ROWS)
    if n == 0 then
        local text = box:GetText()
        if text ~= "" then
            local row = Row(1)
            rowPlace[1] = nil
            row.name:SetText(MUTED .. "Nothing called that|r")
            row.detail:SetText("")
            row.sel:Hide()
            row:Show()
            list.hint:Hide()
            for i = 2, #list.rows do list.rows[i]:Hide() end
            list:SetHeight(ROW_H + 12)
            list:Show()
        else
            HideList()
        end
        return
    end
    for i = 1, n do
        local row, p = Row(i), results[i]
        rowPlace[i] = p
        row.name:SetText(p.name)
        row.detail:SetText(MUTED .. p.detail .. "|r")
        row.sel:SetShown(i == selected)
        row:Show()
    end
    for i = n + 1, #list.rows do list.rows[i]:Hide() end
    list.hint:ClearAllPoints()
    list.hint:SetPoint("TOPLEFT", 10, -8 - n * ROW_H)
    list.hint:Show()
    list:SetHeight(n * ROW_H + 30)
    list:Show()
end

local function OnText(self)
    results = ns.SearchPlaces(self:GetText())
    selected = 1
    ShowResults()
end

local function BuildList()
    list = CreateFrame("Frame", nil, map, "TooltipBackdropTemplate")
    list:SetFrameStrata("HIGH")
    list:SetFrameLevel(math.min(box:GetFrameLevel() + 20, 9200))
    list:SetWidth(300)
    list:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 2, -2)
    list.rows = {}
    list.hint = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    list.hint:SetText("Enter: go there || Shift-click: waypoint")
    list:Hide()
end

local function Build()
    box = CreateFrame("EditBox", nil, map, "SearchBoxTemplate")
    box:SetSize(150, 20)
    box:SetAutoFocus(false)
    box:SetFrameStrata("HIGH")
    box:SetFrameLevel(math.min(map:GetCanvasContainer():GetFrameLevel() + 1010, 9100))
    if box.Instructions then box.Instructions:SetText("Search the map") end
    BuildList()
    box:HookScript("OnTextChanged", OnText)
    box:HookScript("OnEditFocusGained", OnText)
    box:HookScript("OnEditFocusLost", function()
        -- a click on a row lands after the focus goes
        C_Timer.After(0.3, function() if not box:HasFocus() then HideList() end end)
    end)
    box:SetScript("OnEnterPressed", function(self)
        local p = results[selected]
        if p then ns.PickPlace(p, IsShiftKeyDown()) end
        self:ClearFocus()
        HideList()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        HideList()
    end)
    box:SetScript("OnArrowPressed", function(_, key)
        local n = math.min(#results, ROWS)
        if n == 0 then return end
        if key == "UP" then selected = selected > 1 and selected - 1 or n end
        if key == "DOWN" then selected = selected < n and selected + 1 or 1 end
        ShowResults()
    end)
    map:HookScript("OnHide", function()
        box:ClearFocus()
        HideList()
    end)
end

-- left of the Dungeons menu while it shows, else left of the tracking button
local function Place()
    box:ClearAllPoints()
    local dungeons = ns.dungeonButton
    local anchor = dungeons and dungeons:IsShown() and dungeons
        or map.WorldMapTrackingOptionsButton
    if anchor then
        box:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
    else
        box:SetPoint("TOPRIGHT", map, "TOPRIGHT", -40, -4)
    end
end

function ns.RefreshSearch()
    if not box then return end
    local on = ns.db and ns.db.search or false
    box:SetShown(on)
    if on then Place() else HideList() end
end

function ns.SetupSearch(m)
    map = m
    -- the template may be missing on another client build: map without the box
    if not pcall(Build) then
        if box then box:Hide() end
        box = nil
        return
    end
    ns.RefreshSearch()
end

-- for scenarios: the box and its result rows
function ns.SearchBox() return box, list end

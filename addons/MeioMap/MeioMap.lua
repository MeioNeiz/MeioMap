-- World map extras the client lacks. Coordinates are the client's own (Options > Gameplay >
-- Interface > Map Coordinates, restyled by FlareUI): MeioMap only switches them on once and
-- mirrors the toggle. Zone levels on continent hover are the client's too; MeioMap adds the
-- fishing and gathering skill there, and level range too while hovering a zone's own map.
-- Each map also keeps its zoom (Zoom.lua).
local ADDON, ns = ...

-- reveal off until its tint seams are checked in game; dungeon maps and entrances until
-- seen in game
local DEFAULTS = { reveal = false, tint = true, explore = true, levels = true,
    fishing = true, gather = true, zoom = true, dungeons = false, entrances = false,
    arrow = true, search = true }
local COORD_CVARS = { "worldMapShowPlayerCoords", "worldMapShowCursorCoords" }

local db
ns.DEFAULTS = DEFAULTS

local function Say(msg) print("|cffb090ffMeioMap:|r " .. msg) end
local function OnOff(v) return v and "|cff80ff80on|r" or "|cffff8080off|r" end
local function Cmd(text) return "|cffffd100" .. text .. "|r" end
ns.Say, ns.OnOff, ns.Cmd = Say, OnOff, Cmd

function ns.CoordsOn()
    for _, cvar in ipairs(COORD_CVARS) do
        if GetCVarBool(cvar) then return true end
    end
    return false
end

function ns.SetCoords(on)
    for _, cvar in ipairs(COORD_CVARS) do SetCVar(cvar, on and "1" or "0") end
end

-- Chat words, Settings labels and tooltips; Settings.lua builds its checkboxes from these.
-- coords lives in the client's CVars, the rest in MeioMapDB.
ns.TOGGLES = {
    { key = "reveal", label = "Show unexplored",
      tip = "Draws the parts of each zone map you have not explored yet, so the whole map "
          .. "is visible." },
    { key = "tint", label = "Tint unexplored",
      tip = "Unexplored areas are drawn bluish grey, so you can still tell where you have "
          .. "been. Off: they look the same as explored ones." },
    { key = "explore", label = "Left to explore",
      tip = "Hovering a zone names the areas you have not discovered there yet, for "
          .. "exploration credit and the Legacy talent point." },
    { key = "levels", label = "Zone levels",
      tip = "Hovering a zone's own map shows its level range under the area name, coloured "
          .. "for your level. Continent maps show it already." },
    { key = "fishing", label = "Fishing skill",
      tip = "Hovering a zone shows the fishing skill that lands every catch there: green "
          .. "when yours is enough, red when not." },
    { key = "gather", label = "Gathering skill",
      tip = "If you know Herbalism or Mining, hovering a zone shows the skill its easiest "
          .. "and hardest herbs or ore need: green when you can gather them all, yellow "
          .. "for some, red for none." },
    { key = "dungeons", label = "Dungeon maps",
      tip = "M inside a dungeon shows Blizzard's map of it, turned to the level you're "
          .. "on, with its bosses in kill order and a tick for each kill. Wheel zooms, "
          .. "drag moves. Any dungeon: the Dungeons menu on the map, or "
          .. "/meiomap dungeon <name>." },
    { key = "entrances", label = "Entrances",
      tip = "Zone and continent maps mark each dungeon and raid entrance; hover for its "
          .. "levels, coloured for yours. Click opens the dungeon's map (with Dungeon maps "
          .. "on), Shift-click sets a waypoint there." },
    { key = "arrow", label = "Waypoint arrow",
      tip = "While a waypoint is set (Shift-click a map pin, the map search or "
          .. "/meiomap way), an arrow on screen points to it with the yards and time "
          .. "left, and the waypoint clears when you arrive. Drag to move it, right-click "
          .. "clears the waypoint." },
    { key = "search", label = "Map search",
      tip = "A search box on the world map's top bar finds a zone, dungeon or flight "
          .. "master by name and shows it; Shift-click sets a waypoint there." },
    { key = "zoom", label = "Remember zoom",
      tip = "Each map keeps its zoom and position when you switch maps, close the map, "
          .. "reload or log out. Off: the map opens zoomed out, as the game does." },
    { key = "coords", label = "Show coordinates",
      tip = "Your position and the cursor's in the map's bottom-left corner. The client's "
          .. "own option (Options > Gameplay > Interface), switched on together.",
      get = ns.CoordsOn, set = ns.SetCoords },
}

function ns.Get(t) if t.get then return t.get() end return db[t.key] end

-- Reveal data comes from a DB2 extract (gen/gen-data.mjs); until it exists those toggles
-- would do nothing, so help and Settings leave them out
ns.HAS_REVEAL = next(ns.OVERLAYS) ~= nil
ns.REVEAL_KEYS = { reveal = true, tint = true, explore = true }
function ns.Shown(t) return ns.HAS_REVEAL or not ns.REVEAL_KEYS[t.key] end

-- Skill in a profession, gear and lure bonus included; nil when not learned. names: what
-- the skill tab calls it; line: its skill line ID, for GetProfessionInfo
local function ProfessionSkill(names, line)
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, _, modifier = GetSkillLineInfo(i)
            if not header and names[name] then return (rank or 0) + (modifier or 0) end
        end
    end
    if GetProfessions and GetProfessionInfo then
        for _, index in pairs({ GetProfessions() }) do
            local _, _, rank, _, _, _, skillLine, modifier = GetProfessionInfo(index)
            if skillLine == line then return (rank or 0) + (modifier or 0) end
        end
    end
end

local function Names(english, line)
    local names = { [english] = true }
    local display = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
        and C_TradeSkillUI.GetTradeSkillDisplayName(line)
    if display then names[display] = true end
    return names
end

local FISHING_NAMES = Names("Fishing", 356)
if PROFESSIONS_FISHING then FISHING_NAMES[PROFESSIONS_FISHING] = true end
local HERBALISM_NAMES, MINING_NAMES = Names("Herbalism", 182), Names("Mining", 186)

local function Hex(c) return RGBTableToColorCode and RGBTableToColorCode(c) or "|cffffffff" end

-- "18-30" in Blizzard's colouring for continent hover (arealabeldataprovider.lua)
function ns.LevelRange(min, max)
    local level = UnitLevel("player")
    local color
    if level < min then
        color = GetQuestDifficultyColor(min)
    elseif level > max then
        color = GetQuestDifficultyColor(max - 2)
    else
        color = QuestDifficultyColors.difficult
    end
    local range = min == max and tostring(max) or (min .. "-" .. max)
    return Hex(color) .. range .. "|r"
end

local function LevelText(mapID)
    if not C_Map.GetMapLevels then return end
    local min, max = C_Map.GetMapLevels(mapID)
    if not (min and max and min > 0 and max > 0) then return end
    return NORMAL_FONT_COLOR_CODE .. "Levels|r " .. ns.LevelRange(min, max)
end

local function FishingText(mapID)
    local need = ns.FISHING[mapID]
    if not need then return end
    local have = ProfessionSkill(FISHING_NAMES, 356)
    local color = not have and "|cffffffff" or have >= need and "|cff80ff80" or "|cffff8080"
    return NORMAL_FONT_COLOR_CODE .. "Fishing|r " .. color .. need .. "|r"
end

local function GatherText(label, range, have)
    if not (range and have) then return end
    local min, max = range[1], range[2]
    local color
    if have >= max then
        color = "|cff80ff80"
    elseif have >= min then
        -- plain yellow: the difficulty gold would read as part of the "Herbs" label
        color = "|cffffff00"
    else
        color = "|cffff8080"
    end
    local text = min == max and tostring(max) or (min .. "-" .. max)
    return NORMAL_FONT_COLOR_CODE .. label .. "|r " .. color .. text .. "|r"
end

function ns.ZoneLine(mapID, hovered)
    local parts = {}
    local isZoneMap = hovered == mapID
    if isZoneMap and db.levels then parts[#parts + 1] = LevelText(hovered) end
    if db.fishing then parts[#parts + 1] = FishingText(hovered) end
    local gather = db.gather and ns.GATHER[hovered]
    if gather then
        parts[#parts + 1] = GatherText("Herbs", gather.herb,
            ProfessionSkill(HERBALISM_NAMES, 182))
        parts[#parts + 1] = GatherText("Ore", gather.ore, ProfessionSkill(MINING_NAMES, 186))
    end
    if #parts > 0 then return table.concat(parts, "    ") end
end

-- Names of the first few unexplored areas, then how many more. Cached per zone while the
-- map is open: exploring with the map open is rare, and the cache is dropped on every open.
local EXPLORE_NAMES = 3
local exploreCache = {}
function ns.ForgetExplored() wipe(exploreCache) end

local function ExploreText(mapID)
    local cached = exploreCache[mapID]
    if cached ~= nil then return cached or nil end
    local areas = ns.UnexploredAreas and ns.UnexploredAreas(mapID)
    local text = false
    if areas and #areas > 0 then
        local names = {}
        for _, id in ipairs(areas) do
            local name = C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
            if type(name) == "string" and name ~= "" and #names < EXPLORE_NAMES then
                names[#names + 1] = name
            end
        end
        local more = #areas - #names
        local list = table.concat(names, ", ")
        if #names == 0 then
            list = more .. (more == 1 and " area" or " areas")
        elseif more > 0 then
            list = list .. " +" .. more
        end
        text = NORMAL_FONT_COLOR_CODE .. "Unexplored|r |cffa8b4d8" .. list .. "|r"
    end
    exploreCache[mapID] = text
    return text or nil
end

-- A cave, city district or other child area belongs to the zone above it, which holds the
-- level range and fishing data
local function ZoneOf(info)
    for _ = 1, 5 do
        if not info then return end
        if info.mapType <= Enum.UIMapType.Zone then return info.mapID end
        info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    end
end

-- The zone under the cursor: a child zone on a continent map, else the zone map itself
local function HoveredZone(map)
    if not map:IsCanvasMouseFocus() then return end
    local mapID = map:GetMapID()
    if not mapID then return end
    local x, y = map:GetNormalizedCursorPosition()
    local info = x and C_Map.GetMapInfoAtPosition(mapID, x, y)
    local zone = info and info.mapID ~= mapID and ZoneOf(info)
    if zone then return mapID, zone end
    local own = C_Map.GetMapInfo(mapID)
    if own and own.mapType == Enum.UIMapType.Zone then return mapID, mapID end
end

-- Blizzard's area label (name at the top of the map), to sit under it
local function AreaLabel(map)
    for provider in pairs(map.dataProviders or {}) do
        local label = type(provider) == "table" and rawget(provider, "Label")
        if label and label.labelInfoByType and label.Name then return label end
    end
end

local zoneFrame
local function SetupZoneLine(map)
    local label = AreaLabel(map)
    zoneFrame = CreateFrame("Frame", nil, map:GetCanvasContainer())
    zoneFrame:SetFrameStrata("HIGH")
    zoneFrame:SetSize(400, 20)
    local text = zoneFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font = text:GetFont()
    if font then text:SetFont(font, 14, "OUTLINE") end
    text:SetPoint("TOP")
    zoneFrame.text = text
    -- on a child frame: the zone line stays the frame's only region
    local exploreFrame = CreateFrame("Frame", nil, zoneFrame)
    exploreFrame:SetAllPoints()
    local explore = exploreFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if font then explore:SetFont(font, 13, "OUTLINE") end
    explore:SetPoint("TOP", text, "BOTTOM", 0, -3)
    zoneFrame.explore = explore
    -- under Blizzard's description line when something fills it (pet levels, or another
    -- addon's fishing skill), else straight under the area name
    local below
    local function Place()
        local desc = label and label.Description
        local target = label and label.Name
        if desc and desc:IsVisible() and (desc:GetText() or "") ~= "" then target = desc end
        if target == below and below then return end
        below = target
        zoneFrame:ClearAllPoints()
        if target then
            zoneFrame:SetPoint("TOP", target, "BOTTOM", 0, -4)
        else
            zoneFrame:SetPoint("TOP", map:GetCanvasContainer(), "TOP", 0, -40)
        end
    end
    Place()
    local last, lastExplore
    zoneFrame:SetScript("OnUpdate", function()
        Place()
        local mapID, hovered = HoveredZone(map)
        local line = hovered and ns.ZoneLine(mapID, hovered)
        if line ~= last then
            last = line
            text:SetText(line or "")
        end
        local unexplored = hovered and db.explore and ExploreText(hovered)
        if unexplored ~= lastExplore then
            lastExplore = unexplored
            explore:SetText(unexplored or "")
        end
    end)
    map:HookScript("OnShow", ns.ForgetExplored)
end

local function SetupMap()
    local map = WorldMapFrame
    if not map or zoneFrame then return end
    SetupZoneLine(map)
    if ns.HAS_REVEAL then ns.SetupReveal(map) end
    ns.SetupZoom(map)
    ns.SetupDungeon(map)
    ns.SetupEntrances(map)
    ns.SetupSearch(map)
end

local function PrintHelp()
    Say("world map extras: " .. (ns.HAS_REVEAL and "unexplored areas, " or "")
        .. "zone levels, fishing and gathering skill, waypoint arrow, map search, "
        .. "remembered zoom, coordinates")
    for _, t in ipairs(ns.TOGGLES) do
        if ns.Shown(t) then
            print(("  %s - %s (now %s)"):format(Cmd("/meiomap " .. t.key .. " on||off"),
                t.label:lower(), OnOff(ns.Get(t))))
        end
    end
    print("  " .. Cmd("/meiomap way <x> <y> [zone]") .. " - set a waypoint (no zone: the "
        .. "one you're in; no numbers: the current one)")
    print("  " .. Cmd("/meiomap way clear") .. " - clear the waypoint")
    print("  " .. Cmd("/meiomap dungeon <name>") .. " - open a dungeon's map (brd, sm, "
        .. "deadmines...; no name: the one you're in, or the list)")
    print("  " .. Cmd("/meiomap reset") .. " - all settings back to defaults, arrow back "
        .. "in place")
    print("  Settings: Esc > Options > AddOns > MeioMap (" .. Cmd("/meiomap") .. ")")
end

local function DungeonCommand(name)
    if not db.dungeons then
        Say("dungeon maps are " .. OnOff(false) .. ": " .. Cmd("/meiomap dungeons on"))
        return
    end
    local id
    if name == "" then
        local inside = select(8, GetInstanceInfo())
        if inside and ns.DUNGEONS[inside] then id = inside end
    else
        id = ns.FindDungeon(name)
    end
    if not id then
        if name ~= "" then Say(("no dungeon called \"%s\""):format(name)) end
        local withArt, without = ns.DungeonNames()
        Say("dungeons with a map: " .. table.concat(withArt, ", "))
        print("  |cff999999Boss list only: " .. table.concat(without, ", ") .. "|r")
        return
    end
    if not ns.ShowDungeon(id) then Say("open the map first (" .. Cmd("M") .. ")") end
end

function ns.Refresh()
    ns.RefreshDungeon()
    ns.RefreshEntrances()
    ns.RefreshSearch()
    ns.RefreshArrow()
    ns.ForgetExplored()
    if ns.RefreshReveal then ns.RefreshReveal() end
end

SLASH_MEIOMAP1 = "/meiomap"
SLASH_MEIOMAP2 = "/mapplus"
SlashCmdList.MEIOMAP = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local word, arg = msg:match("^(%S+)%s*(.-)$")
    if msg == "help" or msg == "?" then
        PrintHelp()
        return
    elseif msg == "" or msg == "settings" or msg == "options" then
        if not (ns.OpenSettings and ns.OpenSettings()) then PrintHelp() end
        return
    elseif word == "dungeon" then
        DungeonCommand(arg)
        return
    elseif word == "way" then
        ns.WayCommand(arg)
        return
    elseif msg == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
        db.arrowPos = nil
        ns.PlaceArrow()
        ns.SetCoords(true)
        Say("settings back to defaults")
        ns.Refresh()
        return
    end
    local toggle
    for _, t in ipairs(ns.TOGGLES) do
        if word == t.key and ns.Shown(t) then toggle = t end
    end
    if not (toggle and (arg == "" or arg == "on" or arg == "off")) then
        Say(("unknown command \"%s\""):format(msg))
        PrintHelp()
        return
    end
    local value
    if arg == "" then value = not ns.Get(toggle) else value = arg == "on" end
    if toggle.set then toggle.set(value) else db[toggle.key] = value end
    Say(toggle.label:lower() .. " " .. OnOff(value))
    ns.Refresh()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MeioMapDB = MeioMapDB or {}
        db = MeioMapDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        ns.db = db
    elseif event == "ADDON_LOADED" and name == "Blizzard_WorldMap" then
        SetupMap()
    elseif event == "PLAYER_LOGIN" then
        -- Leatrix Maps' coordinates, replaced by the client's: on once, then his choice
        if not db.coordsSet then
            db.coordsSet = true
            if not ns.CoordsOn() then ns.SetCoords(true) end
        end
        SetupMap()
        ns.RefreshDungeon()
        ns.RefreshSearch()
    end
end)

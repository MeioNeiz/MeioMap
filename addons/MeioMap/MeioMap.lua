-- World map extras the client lacks. Coordinates are the client's own (Options > Gameplay >
-- Interface > Map Coordinates, restyled by FlareUI): MeioMap only switches them on once and
-- mirrors the toggle. Zone levels on continent hover are the client's too; MeioMap adds the
-- fishing and gathering skill there, and level range too while hovering a zone's own map.
-- Each map also keeps its zoom (Zoom.lua).
local ADDON, ns = ...

-- reveal off until its tint seams are checked in game
local DEFAULTS = { reveal = false, tint = true, levels = true, fishing = true,
    gather = true, zoom = true }
local COORD_CVARS = { "worldMapShowPlayerCoords", "worldMapShowCursorCoords" }

local db
ns.DEFAULTS = DEFAULTS

local function Say(msg) print("|cffb090ffMeioMap:|r " .. msg) end
local function OnOff(v) return v and "|cff80ff80on|r" or "|cffff8080off|r" end
local function Cmd(text) return "|cffffd100" .. text .. "|r" end
ns.Say, ns.OnOff = Say, OnOff

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
    { key = "zoom", label = "Remember zoom",
      tip = "Each map keeps its zoom and position when you switch maps or close the map, "
          .. "until /reload. Off: the map opens zoomed out, as the game does." },
    { key = "coords", label = "Show coordinates",
      tip = "Your position and the cursor's in the map's bottom-left corner. The client's "
          .. "own option (Options > Gameplay > Interface), switched on together.",
      get = ns.CoordsOn, set = ns.SetCoords },
}

function ns.Get(t) if t.get then return t.get() end return db[t.key] end

-- Reveal data comes from a DB2 extract (gen/gen-data.mjs); until it exists those toggles
-- would do nothing, so help and Settings leave them out
ns.HAS_REVEAL = next(ns.OVERLAYS) ~= nil
ns.REVEAL_KEYS = { reveal = true, tint = true }
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

-- Blizzard's colouring for continent hover (arealabeldataprovider.lua)
local function LevelText(mapID)
    if not C_Map.GetMapLevels then return end
    local min, max = C_Map.GetMapLevels(mapID)
    if not (min and max and min > 0 and max > 0) then return end
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
    return NORMAL_FONT_COLOR_CODE .. "Levels|r " .. Hex(color) .. range .. "|r"
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
    if label then
        zoneFrame:SetPoint("TOP", label.Name, "BOTTOM", 0, -4)
    else
        zoneFrame:SetPoint("TOP", map:GetCanvasContainer(), "TOP", 0, -40)
    end
    local last
    zoneFrame:SetScript("OnUpdate", function()
        local mapID, hovered = HoveredZone(map)
        local line = hovered and ns.ZoneLine(mapID, hovered)
        if line ~= last then
            last = line
            text:SetText(line or "")
        end
    end)
end

local function SetupMap()
    local map = WorldMapFrame
    if not map or zoneFrame then return end
    SetupZoneLine(map)
    if ns.HAS_REVEAL then ns.SetupReveal(map) end
    ns.SetupZoom(map)
end

local function PrintHelp()
    Say("world map extras: " .. (ns.HAS_REVEAL and "unexplored areas, " or "")
        .. "zone levels, fishing and gathering skill, remembered zoom, coordinates")
    for _, t in ipairs(ns.TOGGLES) do
        if ns.Shown(t) then
            print(("  %s - %s (now %s)"):format(Cmd("/meiomap " .. t.key .. " on||off"),
                t.label:lower(), OnOff(ns.Get(t))))
        end
    end
    print("  " .. Cmd("/meiomap reset") .. " - all settings back to defaults")
    print("  Settings: Esc > Options > AddOns > MeioMap (" .. Cmd("/meiomap") .. ")")
end

function ns.Refresh()
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
    elseif msg == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
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
    end
end)

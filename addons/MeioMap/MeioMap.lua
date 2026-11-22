-- World map extras the client lacks. Coordinates are the client's own (Options > Gameplay >
-- Interface > Map Coordinates, restyled by FlareUI): MeioMap only switches them on once and
-- mirrors the toggle. Zone levels on continent hover are the client's too; MeioMap adds the
-- fishing skill there, and level range + fishing while hovering a zone's own map.
local ADDON, ns = ...

local DEFAULTS = { reveal = true, tint = true, levels = true, fishing = true }
local COORD_CVARS = { "worldMapShowPlayerCoords", "worldMapShowCursorCoords" }

local db

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

-- Fishing skill, gear and lure bonus included; nil when not learned
local FISHING_NAMES = { [PROFESSIONS_FISHING or "Fishing"] = true, Fishing = true }
local function FishingSkill()
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, _, modifier = GetSkillLineInfo(i)
            if not header and FISHING_NAMES[name] then return (rank or 0) + (modifier or 0) end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local _, _, _, fishing = GetProfessions()
        if fishing then
            local _, _, rank, _, _, _, _, modifier = GetProfessionInfo(fishing)
            return (rank or 0) + (modifier or 0)
        end
    end
end

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
    local have = FishingSkill()
    local color = not have and "|cffffffff" or have >= need and "|cff80ff80" or "|cffff8080"
    return NORMAL_FONT_COLOR_CODE .. "Fishing|r " .. color .. need .. "|r"
end

function ns.ZoneLine(mapID, hovered)
    local parts = {}
    local isZoneMap = hovered == mapID
    if isZoneMap and db.levels then parts[#parts + 1] = LevelText(hovered) end
    if db.fishing then parts[#parts + 1] = FishingText(hovered) end
    if #parts > 0 then return table.concat(parts, "    ") end
end

-- The zone under the cursor: a child zone on a continent map, else the zone map itself
local function HoveredZone(map)
    if not map:IsCanvasMouseFocus() then return end
    local mapID = map:GetMapID()
    if not mapID then return end
    local x, y = map:GetNormalizedCursorPosition()
    local info = x and C_Map.GetMapInfoAtPosition(mapID, x, y)
    if info and info.mapID ~= mapID then return mapID, info.mapID end
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
    if ns.SetupReveal then ns.SetupReveal(map) end
end

local function PrintHelp()
    Say("world map extras: " .. (ns.HAS_REVEAL and "unexplored areas, " or "")
        .. "zone levels, fishing skill, coordinates")
    for _, t in ipairs(ns.TOGGLES) do
        if ns.Shown(t) then
            print(("  %s - %s (now %s)"):format(Cmd("/meiomap " .. t.key .. " on||off"),
                t.label:lower(), OnOff(ns.Get(t))))
        end
    end
    print("  " .. Cmd("/meiomap reset") .. " - all settings back to defaults")
    print("  Settings: Esc > Options > AddOns > MeioMap (" .. Cmd("/meiomap settings") .. ")")
end

function ns.Refresh()
    if ns.RefreshReveal then ns.RefreshReveal() end
end

SLASH_MEIOMAP1 = "/meiomap"
SLASH_MEIOMAP2 = "/mapplus"
SlashCmdList.MEIOMAP = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local word, arg = msg:match("^(%S+)%s*(.-)$")
    if msg == "" or msg == "help" or msg == "?" then
        PrintHelp()
        return
    elseif msg == "settings" or msg == "options" then
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

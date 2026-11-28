-- Dungeon maps: Blizzard's classic dungeon art (installed with the client, read by
-- FileDataID from DungeonData.lua) on a panel of our own laid over the world map's canvas,
-- with level tabs and the bosses in kill order. The world map underneath is left alone: no
-- writes to WorldMapFrame or its ScrollContainer, no fake UiMap (both taint).
local _, ns = ...

-- art is 4x3 tiles of 256 px cropped to 1002x668, like zone maps
local ART_W, ART_H, TILE = 1002, 668, 256
-- right column: close button, boss list, level tabs; the art fits in the rest
local LIST_W = 230
local LINE_H = 14
local TAB_H = 22

-- tab names where the art's levels aren't floors
local LEVEL_NAMES = {
    [189] = { "Graveyard", "Library", "Armory", "Cathedral" },
    [229] = { "Lower Spire 1", "Lower Spire 2", "Lower Spire 3", "Lower Spire 4",
        "Lower Spire 5", "Lower Spire 6", "Upper Spire" },
    [429] = { "Gordok Commons", "Capital Gardens 1", "Capital Gardens 2",
        "Capital Gardens 3", "Warpwood Quarter 1", "Warpwood Quarter 2" },
}

-- room (GetSubZoneText, English) -> level, from the names painted on the art; walking into
-- one turns the page. Names on more than one level are left out. Other locales keep the
-- level last picked. No labels on Shadowfang Keep's art; raids not done yet.
local ROOMS = {
    [36] = { ["Mast Room"] = 1, ["Ironclad Cove"] = 2 },
    [48] = {
        ["The Pool of Ask'ar"] = 1, ["The Drowned Sacellum"] = 1, ["Moonshrine Ruins"] = 2,
        ["Moonshrine Sanctum"] = 2, ["Aku'mai's Lair"] = 2, ["The Forgotten Pool"] = 3,
    },
    [70] = {
        ["The Stone Vault"] = 1, ["Hall of the Crafters"] = 1, ["Dig Two"] = 1,
        ["Dig Three"] = 1, ["Temple Hall"] = 1, ["Echomok Cavern"] = 1,
        ["Hall of the Keepers"] = 1, ["Map Chamber"] = 1, ["Khaz'goroth's Seat"] = 2,
    },
    [90] = { ["The Clean Zone"] = 1, ["Tinkers' Court"] = 4 },
    [229] = {
        ["Tazz'Alor"] = 1, ["Mok'Doom"] = 3, ["Halycon's Lair"] = 5, ["The Storehouse"] = 5,
        ["Chamber of Battle"] = 6, ["Blackrock Stadium"] = 7, ["The Furnace"] = 7,
        ["Spire Throne"] = 7,
    },
    [289] = {
        ["The Reliquary"] = 1, ["Chamber of Summoning"] = 2, ["The Viewing Room"] = 2,
        ["Hall of Secrets"] = 3, ["The Headmaster's Study"] = 3, ["Hall of the Damned"] = 3,
        ["The Coven"] = 3, ["The Shadow Vault"] = 4, ["Barov Family Vault"] = 4,
        ["Vault of the Ravenian"] = 4, ["The Laboratory"] = 4,
    },
    [329] = {
        ["Crusaders' Square"] = 1, ["Crusader's Square"] = 1, ["Market Row"] = 1,
        ["Festival Lane"] = 1, ["King's Square"] = 1, ["The Hoard"] = 1,
        ["The Crimson Throne"] = 1, ["Slaughter Square"] = 2, ["The Gauntlet"] = 2,
        ["Elders' Square"] = 2,
    },
    [349] = {
        ["Foulspore Cavern"] = 1, ["The Noxious Hollow"] = 1, ["Poison Falls"] = 1,
        ["Vyletongue Seat"] = 1, ["The Wicked Grotto"] = 1, ["Earth Song Falls"] = 2,
        ["Zaetar's Grave"] = 2,
    },
    [429] = {
        ["Gordok's Seat"] = 1, ["Halls of Destruction"] = 1, ["Prison of Immol'thar"] = 4,
        ["The Athenaeum"] = 4, ["The Hidden Reach"] = 5, ["The Shrine of Eldretharr"] = 6,
        ["The Conservatory"] = 6,
    },
    [189] = {
        ["Forlorn Cloister"] = 1, ["Honor's Tomb"] = 1, ["Chamber of Atonement"] = 1,
        ["Gallery of Treasures"] = 2, ["Huntsman's Cloister"] = 2, ["Athenaeum"] = 2,
        ["Hall of Champions"] = 3, ["Crusader's Armory"] = 3, ["Footman's Armory"] = 3,
        ["Training Grounds"] = 3, ["Crusader's Chapel"] = 4, ["Chapel Gardens"] = 4,
    },
    [230] = {
        ["Detention Block"] = 1, ["Dark Iron Highway"] = 1, ["Hall of Crafting"] = 1,
        ["The Lyceum"] = 2, ["Summoners' Tomb"] = 2, ["Mold Foundry"] = 2,
        ["Chamber of Enchantment"] = 2, ["The Grim Guzzler"] = 2, ["West Garrison"] = 2,
        ["East Garrison"] = 2, ["The Domicile"] = 2, ["Ring of the Law"] = 2,
        ["Shrine of Thaurissan"] = 2,
    },
}

-- a run's kills survive /reload and a short relog; a new instance or a long gap starts over
local RUN_GAP = 2 * 3600
-- wheel zoom: multiple of the fitted size per notch, and the most it goes
local ZOOM_STEP, ZOOM_MAX = 1.25, 4
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local canaccess = canaccessvalue or function() return true end

-- for the menu; the rest with art are dungeons
local RAIDS = { [249] = true, [309] = true, [409] = true, [469] = true, [509] = true,
    [531] = true, [533] = true }

-- what players type; full names (and any part of one) match too
local ALIASES = {
    rfc = 389, wc = 43, dm = 36, vc = 36, sfk = 33, bfd = 48, stocks = 34, stockade = 34,
    gnomer = 90, rfk = 47, sm = 189, rfd = 129, ulda = 70, zf = 209, mara = 349, st = 109,
    brd = 230, brs = 229, lbrs = 229, ubrs = 229, dme = 429, dmw = 429, dmn = 429,
    scholo = 289, strat = 329, ony = 249, mc = 409, bwl = 469, aq40 = 531, aq20 = 509,
    naxx = 533, zg = 309,
}

local map, panel, area, art, list, noArt, menuButton
local tiles, tabs, lines = {}, {}, {}
local shownID
-- zoom (1 = fitted) and the art point at the middle of the view, 0..1 across and down
local view = { z = 1, x = 0.5, y = 0.5 }

-- the instance the player is in, if it's one we know
local function Inside()
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    if kind ~= "none" and id and ns.DUNGEONS[id] then return id end
end

local function Key(name) return (name or ""):lower():gsub("[^%w]", "") end

-- instance Map IDs, those with art first, then by ID: a name shared by a classic and a
-- Forever instance (Naxxramas) picks the one with a map
local function SortedIDs()
    local ids = {}
    for id in pairs(ns.DUNGEONS) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local artA, artB = ns.DUNGEONS[a].levels ~= nil, ns.DUNGEONS[b].levels ~= nil
        if artA ~= artB then return artA end
        return a < b
    end)
    return ids
end

function ns.FindDungeon(text)
    local key = Key(text)
    if key == "" then return end
    if ALIASES[key] then return ALIASES[key] end
    local ids = SortedIDs()
    for _, id in ipairs(ids) do
        if Key(ns.DUNGEONS[id].name) == key then return id end
    end
    for _, id in ipairs(ids) do
        if Key(ns.DUNGEONS[id].name):find(key, 1, true) then return id end
    end
end

-- "fid fid ..." per level, parsed on first use
local function Levels(d)
    if not d.levels then return end
    if not d.parsed then
        d.parsed = {}
        for i, s in ipairs(d.levels) do
            local fids = {}
            for fid in s:gmatch("%d+") do fids[#fids + 1] = tonumber(fid) end
            d.parsed[i] = fids
        end
    end
    return d.parsed
end

local function LevelName(mapID, level)
    local names = LEVEL_NAMES[mapID]
    return names and names[level] or ("Level " .. level)
end

local function Saved()
    local db = ns.db
    if type(db.dungeonLevel) ~= "table" then db.dungeonLevel = {} end
    return db.dungeonLevel
end

-- this run's kills; starts a new run when asked for another instance or after a long gap
local function Run(mapID)
    local run = ns.db.dungeonRun
    if type(run) ~= "table" or type(run.kills) ~= "table" or run.map ~= mapID
        or time() - (tonumber(run.seen) or 0) > RUN_GAP then
        run = { map = mapID, kills = {} }
        ns.db.dungeonRun = run
    end
    run.seen = time()
    return run
end

local function Killed(mapID, encounterID)
    local run = ns.db.dungeonRun
    if type(run) == "table" and run.map == mapID and type(run.kills) == "table"
        and run.kills[encounterID] then
        return true
    end
    -- raid lockouts: ticks after a relog days later
    local raid = C_RaidLocks and C_RaidLocks.IsEncounterComplete
    return raid and raid(mapID, encounterID) == true or false
end

-- the client's own name from a kill, so other locales read their own language
local function BossName(boss)
    local names = ns.db.bossNames
    return type(names) == "table" and names[boss[1]] or boss[2]
end

-- per instance { z, x, y } when "Remember zoom" is on
local function SavedZoom()
    local db = ns.db
    if type(db.dungeonZoom) ~= "table" then db.dungeonZoom = {} end
    return db.dungeonZoom
end

-- one axis: where the art starts in the view (px) and the clamped middle point
local function Place(size, artSize, mid)
    local start = size / 2 - mid * artSize
    if artSize <= size then
        start = (size - artSize) / 2
    else
        start = math.min(0, math.max(size - artSize, start))
    end
    return start, (size / 2 - start) / artSize
end

local function Scale()
    local w, h = area:GetSize()
    if not (w and h and w > 0 and h > 0) then return end
    return math.min(w / ART_W, h / ART_H) * view.z, w, h
end

local function Layout()
    local s, w, h = Scale()
    if not s then return end
    local left, top
    left, view.x = Place(w, ART_W * s, view.x)
    top, view.y = Place(h, ART_H * s, view.y)
    art:SetScale(s)
    art:ClearAllPoints()
    -- offsets are in the art's own (scaled) units
    art:SetPoint("TOPLEFT", area, "TOPLEFT", left / s, -top / s)
    if shownID and ns.db.zoom then
        SavedZoom()[shownID] = { z = view.z, x = view.x, y = view.y }
    end
end

-- the cursor in the view, from its top left
local function Cursor()
    local x, y = GetCursorPosition()
    local es = area:GetEffectiveScale()
    return x / es - (area:GetLeft() or 0), (area:GetTop() or 0) - y / es
end

-- zooms keeping the art point under the cursor still
local function Wheel(_, delta)
    local s, w, h = Scale()
    if not s then return end
    local step = delta > 0 and ZOOM_STEP or 1 / ZOOM_STEP
    local z = math.max(1, math.min(ZOOM_MAX, view.z * step))
    if z == view.z then return end
    local cx, cy = Cursor()
    local left = w / 2 - view.x * ART_W * s
    local top = h / 2 - view.y * ART_H * s
    local ax, ay = (cx - left) / (ART_W * s), (cy - top) / (ART_H * s)
    local s2 = s / view.z * z
    view.z = z
    view.x = (w / 2 - (cx - ax * ART_W * s2)) / (ART_W * s2)
    view.y = (h / 2 - (cy - ay * ART_H * s2)) / (ART_H * s2)
    Layout()
end

-- drag pans; OnUpdate only while the button is held
local function DragStart(_, button)
    if button ~= "LeftButton" then return end
    local s = Scale()
    if not s then return end
    local cx0, cy0 = Cursor()
    local x0, y0 = view.x, view.y
    area:SetScript("OnUpdate", function()
        local cx, cy = Cursor()
        view.x = x0 - (cx - cx0) / (ART_W * s)
        view.y = y0 - (cy - cy0) / (ART_H * s)
        Layout()
    end)
end

local function DragStop(_, button)
    area:SetScript("OnUpdate", nil)
    -- right-click goes back, as it goes up a level on the world map
    if button == "RightButton" then ns.HideDungeon() end
end

local function Line(i)
    local line = lines[i]
    if not line then
        line = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("TOPLEFT", list.title, "BOTTOMLEFT", 0, -8 - (i - 1) * LINE_H)
        line:SetPoint("RIGHT")
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        lines[i] = line
    end
    return line
end

-- "You are in <room>" above the bosses while you're inside the dungeon shown
local function ShowRoom()
    local room = shownID and shownID == Inside() and GetSubZoneText() or ""
    list.title:ClearAllPoints()
    if room == "" or not canaccess(room) then
        list.room:Hide()
        list.title:SetPoint("TOPLEFT")
        return 0, nil
    end
    list.room:SetText("|cff999999You are in|r " .. room)
    list.room:Show()
    local h = math.ceil(list.room:GetStringHeight() or LINE_H) + 10
    list.title:SetPoint("TOPLEFT", 0, -h)
    return h, room
end

local function ShowBosses(mapID, roomH)
    local bosses = ns.DUNGEONS[mapID].bosses or {}
    for i, boss in ipairs(bosses) do
        local line = Line(i)
        if Killed(mapID, boss[1]) then
            line:SetText(("%s |cff999999%s|r"):format(TICK, BossName(boss)))
        else
            line:SetText(("|cff999999%d|r  %s"):format(i, BossName(boss)))
        end
        line:Show()
    end
    for i = #bosses + 1, #lines do lines[i]:Hide() end
    list.title:SetText(#bosses > 0 and "Bosses" or "No bosses listed")
    list:SetHeight(roomH + 22 + #bosses * LINE_H)
end

-- false when a tile is missing: some locales (RU, ES-MX, IT) don't ship the dungeon art
local function ShowLevel(mapID, level)
    local fids = Levels(ns.DUNGEONS[mapID])[level]
    local ok = true
    for i, tex in ipairs(tiles) do
        if tex:SetTexture(fids[i]) == false then ok = false end
    end
    for i, tab in ipairs(tabs) do
        local text = tab:GetFontString()
        if i == level then
            tab:LockHighlight()
            if text then text:SetTextColor(1, 1, 1) end
        else
            tab:UnlockHighlight()
            if text then text:SetTextColor(NORMAL_FONT_COLOR:GetRGB()) end
        end
    end
    Saved()[mapID] = level
    return ok
end

local function Tab(i)
    local tab = tabs[i]
    if not tab then
        tab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        tab:SetSize(LIST_W, TAB_H - 2)
        tab:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -16 - (i - 1) * TAB_H)
        tab:SetScript("OnClick", function() ShowLevel(shownID, i) end)
        tabs[i] = tab
    end
    return tab
end

local function ShowTabs(mapID, count)
    for i = 1, count > 1 and count or 0 do
        local tab = Tab(i)
        tab:SetText(LevelName(mapID, i))
        tab:Show()
    end
    for i = (count > 1 and count or 0) + 1, #tabs do tabs[i]:Hide() end
end

local function ShowNoArt(d)
    art:Hide()
    for _, tab in ipairs(tabs) do tab:Hide() end
    noArt.title:SetText(d.name)
    noArt:Show()
end

local function Build()
    local container = map:GetCanvasContainer()
    panel = CreateFrame("Frame", nil, container)
    panel:SetAllPoints()
    -- above the map's pins and our zone line, inside the map frame
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(math.min(container:GetFrameLevel() + 1000, 9000))
    panel:SetClipsChildren(true)
    panel:EnableMouse(true)
    -- the map underneath would zoom; zoom in the panel comes later
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function() end)
    -- right-click goes back, as it goes up a level on the world map
    panel:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.HideDungeon() end
    end)
    panel:Hide()
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.05, 0.04, 1)

    area = CreateFrame("Frame", nil, panel)
    area:SetPoint("TOPLEFT")
    area:SetPoint("BOTTOMRIGHT", -(LIST_W + 20), 0)
    area:SetClipsChildren(true)
    area:EnableMouse(true)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", Wheel)
    area:SetScript("OnMouseDown", DragStart)
    area:SetScript("OnMouseUp", DragStop)
    area:SetScript("OnHide", function() area:SetScript("OnUpdate", nil) end)
    art = CreateFrame("Frame", nil, area)
    art:SetSize(ART_W, ART_H)
    art:SetPoint("TOPLEFT")
    for i = 1, 12 do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local w = math.min(TILE, ART_W - col * TILE)
        local h = math.min(TILE, ART_H - row * TILE)
        local tex = art:CreateTexture(nil, "ARTWORK")
        tex:SetSize(w, h)
        tex:SetTexCoord(0, w / TILE, 0, h / TILE)
        tex:SetPoint("TOPLEFT", col * TILE, -row * TILE)
        tiles[i] = tex
    end
    area:SetScript("OnSizeChanged", Layout)

    list = CreateFrame("Frame", nil, panel)
    list:SetWidth(LIST_W)
    list:SetPoint("TOPRIGHT", -10, -34)
    list.room = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    list.room:SetPoint("TOPLEFT")
    list.room:SetWidth(LIST_W)
    list.room:SetJustifyH("LEFT")
    list.title = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    list.title:SetPoint("TOPLEFT")

    noArt = CreateFrame("Frame", nil, panel)
    noArt:SetAllPoints(area)
    noArt.title = noArt:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    noArt.title:SetPoint("BOTTOM", noArt, "CENTER", 0, 6)
    local note = noArt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOP", noArt, "CENTER", 0, -6)
    note:SetText("|cff999999No map for this dungeon in the game yet|r")
    noArt:Hide()

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    -- the template's own frame level would put it under the panel
    close:SetFrameLevel(panel:GetFrameLevel() + 10)
    close:SetScript("OnClick", function() ns.HideDungeon() end)

    map:HookScript("OnHide", ns.HideDungeon)
    hooksecurefunc(map, "OnMapChanged", ns.HideDungeon)
end

function ns.HideDungeon()
    shownID = nil
    if panel then panel:Hide() end
end

function ns.DungeonShown() return shownID end

-- Opens the world map if needed, then the dungeon's panel over it. False when the map
-- can't open (in combat, opening it from a slash command could taint the panel layout).
function ns.ShowDungeon(mapID)
    local d = ns.DUNGEONS[mapID]
    map = map or WorldMapFrame
    if not (d and map) then return false end
    if not map:IsShown() then
        if InCombatLockdown() or not OpenWorldMap then return false end
        OpenWorldMap()
        if not map:IsShown() then return false end
    end
    if not panel then Build() end
    shownID = mapID
    local z = ns.db.zoom and SavedZoom()[mapID]
    if type(z) == "table" and tonumber(z.z) and tonumber(z.x) and tonumber(z.y) then
        view.z, view.x, view.y = z.z, z.x, z.y
    else
        view.z, view.x, view.y = 1, 0.5, 0.5
    end
    noArt:Hide()
    art:Show()
    local roomH, room = ShowRoom()
    ShowBosses(mapID, roomH)
    local levels = Levels(d)
    if not levels then
        ShowNoArt(d)
    else
        local level = room and ROOMS[mapID] and ROOMS[mapID][room] or Saved()[mapID]
        if not (level and levels[level]) then level = 1 end
        ShowTabs(mapID, #levels)
        if not ShowLevel(mapID, level) then ShowNoArt(d) end
    end
    panel:Show()
    Layout()
    return true
end

-- the room line, and the level when the new room is on another one
local function Moved()
    if not (shownID and panel and panel:IsShown()) then return end
    local roomH, room = ShowRoom()
    ShowBosses(shownID, roomH)
    local level = room and ROOMS[shownID] and ROOMS[shownID][room]
    local levels = Levels(ns.DUNGEONS[shownID])
    if level and levels and levels[level] and art:IsShown()
        and Saved()[shownID] ~= level then
        ShowLevel(shownID, level)
    end
end

local function MenuGenerator(_, root)
    local dungeons, raids, listOnly = {}, {}, {}
    for id, d in pairs(ns.DUNGEONS) do
        local into = not d.levels and listOnly or RAIDS[id] and raids or dungeons
        into[#into + 1] = id
    end
    local function Add(parent, ids)
        table.sort(ids, function(a, b) return ns.DUNGEONS[a].name < ns.DUNGEONS[b].name end)
        for _, id in ipairs(ids) do
            parent:CreateButton(ns.DUNGEONS[id].name, function() ns.ShowDungeon(id) end)
        end
    end
    Add(root, dungeons)
    Add(root:CreateButton("Raids"), raids)
    Add(root:CreateButton("Boss list only"), listOnly)
end
ns.DungeonMenu = MenuGenerator

-- "Dungeons" beside the map's tracking button, above the panel so it switches dungeons too
local function MenuButton()
    local container = map:GetCanvasContainer()
    -- on the map, not the canvas: the canvas clips, and the top bar is above it
    menuButton = CreateFrame("DropdownButton", nil, map, "WowStyle1DropdownTemplate")
    menuButton:SetWidth(120)
    menuButton:SetFrameStrata("HIGH")
    menuButton:SetFrameLevel(math.min(container:GetFrameLevel() + 1010, 9100))
    local anchor = map.WorldMapTrackingOptionsButton
    if anchor then
        menuButton:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    else
        menuButton:SetPoint("TOPRIGHT", -40, -2)
    end
    if menuButton.SetDefaultText then menuButton:SetDefaultText("Dungeons") end
    menuButton:SetupMenu(MenuGenerator)
    ns.dungeonButton = menuButton
end

-- MeioMapDB only exists from our ADDON_LOADED on; the map can load first
function ns.RefreshDungeon()
    local on = ns.db and ns.db.dungeons or false
    if not on then ns.HideDungeon() end
    if menuButton then menuButton:SetShown(on) end
end

-- M inside a dungeon opens its map: runs after WorldMapMixin:OnShow has set the map, so
-- the OnMapChanged hook doesn't close it again
function ns.SetupDungeon(m)
    map = m
    -- the menu template may be missing on another client build: map without the button
    if not pcall(MenuButton) then
        if menuButton then menuButton:Hide() end
        menuButton = nil
    end
    ns.RefreshDungeon()
    map:HookScript("OnShow", function()
        local id = ns.db and ns.db.dungeons and Inside()
        if id then ns.ShowDungeon(id) end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, ...)
    if not ns.db then return end
    if event == "ENCOUNTER_END" then
        local encounterID, name, _, _, success = ...
        local id = Inside()
        if not (id and canaccess(encounterID) and success == 1) then return end
        Run(id).kills[encounterID] = true
        if type(name) == "string" and canaccess(name) and name ~= "" then
            if type(ns.db.bossNames) ~= "table" then ns.db.bossNames = {} end
            ns.db.bossNames[encounterID] = name
        end
        Moved()
    elseif event == "CHAT_MSG_SYSTEM" then
        -- "<dungeon> has been reset.": only possible with everyone outside
        local msg = ...
        local pattern = type(INSTANCE_RESET_SUCCESS) == "string"
            and INSTANCE_RESET_SUCCESS:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
                :gsub("%%s", ".+")
        if pattern and type(msg) == "string" and canaccess(msg) and msg:match(pattern) then
            ns.db.dungeonRun = nil
        end
    else
        local id = Inside()
        if id then Run(id) end
        if event ~= "PLAYER_LOGOUT" then Moved() end
    end
end)

-- read-only API for MeioDungeons (and anyone): data stays here, one copy
local CONTINENTS = { [1414] = true, [1415] = true }
_G.MeioMapAPI = {
    -- [instance Map ID] = { name, levels?, bosses = { { encounterID, name }, ... } }
    Dungeons = function() return ns.DUNGEONS end,
    Levels = function(mapID)
        local l = ns.DUNGEON_LEVELS and ns.DUNGEON_LEVELS[mapID]
        if l then return l[1], l[2] end
    end,
    HasMap = function(mapID)
        local d = ns.DUNGEONS[mapID]
        return d ~= nil and d.levels ~= nil
    end,
    IsRaid = function(mapID) return RAIDS[mapID] == true end,
    -- "brd", "dire maul", any part of a name -> instance Map ID
    Find = function(text) return ns.FindDungeon(text) end,
    -- this run's kill (or a raid lockout's)
    Killed = function(mapID, encounterID) return ns.db ~= nil and Killed(mapID, encounterID) end,
    BossName = function(boss) return ns.db and BossName(boss) or boss[2] end,
    -- the zone map an entrance pin sits on: uiMapID, x, y (0-1)
    Entrance = function(mapID)
        for uiMapID, pins in pairs(ns.ENTRANCES or {}) do
            if not CONTINENTS[uiMapID] then
                for _, pin in ipairs(pins) do
                    for i = 3, #pin do
                        if pin[i] == mapID then return uiMapID, pin[1], pin[2] end
                    end
                end
            end
        end
    end,
    -- opens the world map on the dungeon's panel; false in combat with the map closed
    Show = function(mapID) return ns.db ~= nil and ns.ShowDungeon(mapID) end,
}

-- Dungeons for help: those with a map, then the rest
function ns.DungeonNames()
    local withArt, without = {}, {}
    for _, id in ipairs(SortedIDs()) do
        local d = ns.DUNGEONS[id]
        local into = d.levels and withArt or without
        into[#into + 1] = d.name
    end
    return withArt, without
end

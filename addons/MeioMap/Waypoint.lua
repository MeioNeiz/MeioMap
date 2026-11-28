-- Waypoints: one call for MeioMap's pins, /meiomap way, the map search and other addons
-- (MeioMapAPI.SetWaypoint), on Forever's own user waypoint, supertracked. The arrow follows
-- any supertracked user waypoint, whoever set it (MeioQuests, Ctrl-click on the map).
-- Forever ships Blizzard_QuestNavigation, but hides its "in-game navigation" option; when its
-- marker is on screen anyway, the arrow steps aside and only distance and time stay.
local _, ns = ...

local canaccess = canaccessvalue or function() return true end
-- Interface\Minimap\SuperTrackerArrow: gold, pointing up, edges transparent (corners sample
-- outside the art while turned)
local ARROW = 407337
local SIZE = 56
local ARRIVE = 10
local MUTED = "|cff999999"
local AHEAD = math.rad(15)

local frame, driver

local function Readable(v) return v ~= nil and canaccess(v) end

-- The player's map, position on it and facing: the reads that come back nil (instances,
-- taxis) or secret (some fights) all pass through here. facing may be nil on its own.
function ns.PlayerSpot()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not Readable(mapID) then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not Readable(pos) then return end
    local x, y = pos.x, pos.y
    if not (Readable(x) and Readable(y)) or (x == 0 and y == 0) then return end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not Readable(facing) then facing = nil end
    return mapID, x, y, facing
end

-- A map's origin and its east and south edges in world yards. Derived rather than assumed:
-- which world axis is north differs between APIs. false: the client has no world rect.
local axes = {}
local function Axes(mapID)
    local a = axes[mapID]
    if a ~= nil then return a end
    a = false
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local cont, o = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, e = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 0))
        local _, s = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 1))
        if cont and o and e and s then
            a = { cont = cont, ox = o.x, oy = o.y, ex = e.x - o.x, ey = e.y - o.y,
                sx = s.x - o.x, sy = s.y - o.y }
            a.el = math.sqrt(a.ex * a.ex + a.ey * a.ey)
            a.sl = math.sqrt(a.sx * a.sx + a.sy * a.sy)
            if a.el == 0 or a.sl == 0 then a = false end
        end
    end
    axes[mapID] = a
    return a
end

local function World(a, x, y)
    return a.ox + x * a.ex + y * a.sx, a.oy + x * a.ey + y * a.sy
end

-- yards to the waypoint and its direction from the way you face (radians, counter-clockwise,
-- nil without facing); "far" when it's on another continent; nil without a position
local function Bearing(point)
    local pm, px, py, facing = ns.PlayerSpot()
    if not pm then return end
    local A, B = Axes(point.uiMapID), Axes(pm)
    if not (A and B) then return end
    if A.cont ~= B.cont then return "far" end
    local tx, ty = World(A, point.position.x, point.position.y)
    local qx, qy = World(B, px, py)
    local dx, dy = tx - qx, ty - qy
    local east = (dx * A.ex + dy * A.ey) / A.el
    local north = -(dx * A.sx + dy * A.sy) / A.sl
    -- GetPlayerFacing: 0 north, growing towards west
    local bearing = math.atan2(-east, north)
    return math.sqrt(dx * dx + dy * dy), facing and (bearing - facing)
end
ns.Bearing = Bearing

-- turns the up-pointing art by a (counter-clockwise) through its texture corners: the
-- workbench draws these, and they need no SetRotation support
local function Rotate(tex, a)
    local c, s = math.cos(a), math.sin(a)
    local function UV(x, y) return 0.5 + c * x + s * y, 0.5 + s * x - c * y end
    local ulx, uly = UV(-0.5, 0.5)
    local llx, lly = UV(-0.5, -0.5)
    local urx, ury = UV(0.5, 0.5)
    local lrx, lry = UV(0.5, -0.5)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function Clock(sec)
    sec = math.floor(sec + 0.5)
    if sec >= 3600 then
        return ("%dh %02dm"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60))
    end
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end
ns.Clock = Clock

local function MapName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Map " .. mapID)
end

local function ContinentName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    for _ = 1, 6 do
        if not info then return end
        if info.mapType == Enum.UIMapType.Continent then return info.name end
        info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    end
end

local function Point()
    if not (C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return end
    local point = C_Map.GetUserWaypoint()
    if point and point.uiMapID and point.position then return point end
end

local function Tracked()
    return C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint
        and C_SuperTrack.IsSuperTrackingUserWaypoint()
end

-- our own title when the waypoint is still the one we set, else its zone and coords
function ns.WaypointTitle(point)
    local w = ns.db and ns.db.waypoint
    local x, y = point.position.x, point.position.y
    if type(w) == "table" and w.map == point.uiMapID and w.title
        and math.abs(w.x - x) < 1e-4 and math.abs(w.y - y) < 1e-4 then
        return w.title
    end
    return ("%s %.1f, %.1f"):format(MapName(point.uiMapID), x * 100, y * 100)
end

-- Blizzard's own marker drawing on screen
local function NativeShown()
    local f = SuperTrackedFrame
    return f and f.navFrame ~= nil and f:IsShown() and f:GetAlpha() > 0.5 or false
end

--------------------------------------------------
-- The one waypoint call
--------------------------------------------------
-- x, y 0-1 on uiMapID; false when that map can't hold a waypoint (continents, instances)
function ns.SetWaypoint(mapID, x, y, title)
    if not (mapID and x and y and C_Map.SetUserWaypoint and UiMapPoint
        and C_Map.CanSetUserWaypointOnMap) then
        return false
    end
    if not C_Map.CanSetUserWaypointOnMap(mapID) then return false end
    if ns.db then ns.db.waypoint = { map = mapID, x = x, y = y, title = title } end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    ns.RefreshArrow()
    return true
end

function ns.ClearWaypoint()
    if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end
    if ns.db then ns.db.waypoint = nil end
    ns.RefreshArrow()
end

-- MeioMapAPI is made in Dungeon.lua. Forever's user waypoint at x, y (0-1) on a zone map, supertracked, with MeioMap's arrow
-- showing title; false when the map can't hold one
MeioMapAPI.SetWaypoint = function(uiMapID, x, y, title)
    return ns.SetWaypoint(uiMapID, x, y, title)
end
MeioMapAPI.ClearWaypoint = function() ns.ClearWaypoint() end

--------------------------------------------------
-- Arrow
--------------------------------------------------
local function SavePosition()
    local point, _, rel, x, y = frame:GetPoint()
    ns.db.arrowPos = { point, rel, x, y }
end

function ns.PlaceArrow()
    if not frame then return end
    frame:ClearAllPoints()
    local p = ns.db and ns.db.arrowPos
    local point, rel, x, y
    if type(p) == "table" then point, rel, x, y = p[1], p[2], p[3], p[4] end
    if type(point) == "string" and type(rel) == "string" and type(x) == "number"
        and type(y) == "number" then
        frame:SetPoint(point, UIParent, rel, x, y)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

local function Tooltip(self)
    local point = Point()
    if not point then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(ns.WaypointTitle(point), 1, 1, 1)
    GameTooltip:AddLine(("%s %.1f, %.1f"):format(MapName(point.uiMapID),
        point.position.x * 100, point.position.y * 100), 1, 0.82, 0)
    GameTooltip:AddLine(MUTED .. "Drag: move || Right-click: clear|r")
    GameTooltip:Show()
end

local function Build()
    frame = CreateFrame("Frame", "MeioMapArrow", UIParent)
    frame:SetSize(170, SIZE + 34)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.ClearWaypoint() end
    end)
    frame:SetScript("OnEnter", Tooltip)
    frame:SetScript("OnLeave", GameTooltip_Hide)
    local arrow = frame:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(SIZE, SIZE)
    arrow:SetPoint("TOP")
    arrow:SetTexture(ARROW)
    frame.arrow = arrow
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", arrow, "BOTTOM", 0, -1)
    title:SetWidth(170)
    title:SetWordWrap(false)
    frame.title = title
    local dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dist:SetPoint("TOP", title, "BOTTOM", 0, -2)
    frame.dist = dist
    ns.PlaceArrow()
    frame:Hide()
end

-- closing speed (yards a second), sampled each second and smoothed, for the time left
local track = { t = 0, text = 0 }

local function Reset()
    track.speed, track.last, track.lastT = nil, nil, nil
end

local function Speed(dist, now)
    if track.lastT and now - track.lastT < 1 then return track.speed end
    if track.last and track.lastT then
        local v = (track.last - dist) / (now - track.lastT)
        track.speed = track.speed and (track.speed * 0.6 + v * 0.4) or v
    end
    track.last, track.lastT = dist, now
    return track.speed
end

local function Arrived(point)
    local title = ns.WaypointTitle(point)
    ns.ClearWaypoint()
    if UIErrorsFrame then UIErrorsFrame:AddMessage("Arrived: " .. title, 1, 0.82, 0) end
end

local function Update()
    local point = Point()
    if not point then return ns.RefreshArrow() end
    local dist, turn = Bearing(point)
    if not dist then
        frame:Hide()
        return
    end
    frame:Show()
    local now = GetTime()
    if dist == "far" then
        frame.arrow:Hide()
        frame.title:SetText(ns.WaypointTitle(point))
        local cont = ContinentName(point.uiMapID)
        frame.dist:SetText(MUTED .. (cont and ("in " .. cont) or "another continent") .. "|r")
        Reset()
        return
    end
    if dist <= ARRIVE then return Arrived(point) end
    local native = NativeShown()
    frame.arrow:SetShown(turn ~= nil and not native)
    if turn and not native then
        Rotate(frame.arrow, turn)
        local off = math.abs((turn + math.pi) % (2 * math.pi) - math.pi)
        if off < AHEAD then
            frame.arrow:SetVertexColor(0.5, 1, 0.4)
        else
            frame.arrow:SetVertexColor(1, 1, 1)
        end
    end
    local speed = Speed(dist, now)
    if now - track.text < 0.2 then return end
    track.text = now
    frame.title:SetText(ns.WaypointTitle(point))
    local text = ("%d yds"):format(math.floor(dist + 0.5))
    if speed and speed > 1 then text = text .. " - " .. Clock(dist / speed) end
    frame.dist:SetText(text)
end

function ns.RefreshArrow()
    if not driver then return end
    local on = ns.db and ns.db.arrow and Point() and Tracked()
    if on then
        if not driver:IsShown() then
            Reset()
            track.text = 0
        end
        driver:Show()
        Update()
    else
        driver:Hide()
        if frame then frame:Hide() end
    end
end

local function Setup()
    if driver then return end
    Build()
    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", function()
        local ok, err = pcall(Update)
        if not ok then
            driver:Hide()
            geterrorhandler()(err)
        end
    end)
    ns.RefreshArrow()
end
ns.SetupArrow = Setup

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("USER_WAYPOINT_UPDATED")
events:RegisterEvent("SUPER_TRACKING_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then Setup() return end
    if event == "USER_WAYPOINT_UPDATED" then Reset() end
    ns.RefreshArrow()
end)

--------------------------------------------------
-- /meiomap way
--------------------------------------------------
local function Num(s)
    local n = tonumber(s)
    if n and n >= 0 and n <= 100 then return n / 100 end
end

local function CurrentZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not Readable(mapID) then return end
    local info = C_Map.GetMapInfo(mapID)
    for _ = 1, 5 do
        if not info then return end
        if info.mapType == Enum.UIMapType.Zone then return info.mapID end
        info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    end
end

-- "42.5 71.7 [zone]" or "<zone> 42.5 71.7"; no args: the current waypoint
function ns.WayCommand(arg)
    local Cmd = ns.Cmd
    if arg == "clear" then
        ns.ClearWaypoint()
        ns.Say("waypoint cleared")
        return
    end
    if arg == "" then
        local point = Point()
        if point then
            ns.Say("waypoint: " .. ns.WaypointTitle(point) .. MUTED .. " ("
                .. Cmd("/meiomap way clear") .. MUTED .. " clears it)|r")
        else
            ns.Say("no waypoint: " .. Cmd("/meiomap way <x> <y> [zone]"))
        end
        return
    end
    local xs, ys, zone = arg:match("^([%d%.]+)[,%s]+([%d%.]+)%s*(.-)$")
    if not xs then zone, xs, ys = arg:match("^(.-)%s+([%d%.]+)[,%s]+([%d%.]+)$") end
    local x, y = Num(xs), Num(ys)
    if not (x and y) then
        ns.Say(("can't read \"%s\": %s, e.g. %s"):format(arg, Cmd("/meiomap way <x> <y> [zone]"),
            Cmd("/meiomap way 42.5 71.7 westfall")))
        return
    end
    local mapID
    if zone and zone ~= "" then
        mapID = ns.FindZone(zone)
        if not mapID then
            ns.Say(("no zone called \"%s\""):format(zone))
            return
        end
    else
        mapID = CurrentZone()
        if not mapID then
            ns.Say("no zone here: name one, " .. Cmd("/meiomap way 42.5 71.7 westfall"))
            return
        end
    end
    if not ns.SetWaypoint(mapID, x, y) then
        ns.Say(("no waypoint can go on %s"):format(MapName(mapID)))
        return
    end
    ns.Say(("waypoint set on %s %.1f, %.1f"):format(MapName(mapID), x * 100, y * 100))
end

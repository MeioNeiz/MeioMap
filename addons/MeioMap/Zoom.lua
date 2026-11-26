-- Remembered zoom: each map keeps its zoom and position, across /reload and logout (kept in
-- MeioMapDB.zoomed). The client zooms out on every map change and every time the map opens
-- (ScrollContainer:ResetZoom); right after that, put back what the map had. Zoom is kept as a
-- multiple of the zoomed-out scale, so it survives switching between the small and the
-- maximised map.
local _, ns = ...

local container

-- mapID -> { zoom, x, y }; MeioMapDB only exists from our ADDON_LOADED on
local function Saved()
    local db = ns.db
    if not db then return {} end
    if type(db.zoomed) ~= "table" then db.zoomed = {} end
    return db.zoomed
end

local function Restore()
    local s = ns.db and ns.db.zoom and Saved()[container.mapID]
    if not (s and s.zoom and s.x and s.y) then return end
    local min, max = container:GetScaleForMinZoom(), container:GetScaleForMaxZoom()
    container:InstantPanAndZoom(math.min(s.zoom * min, max), s.x, s.y, true)
end

-- read every frame while the map is open: by the time a map change or ResetZoom runs, the
-- old map's view is already gone. Updated in place: no table per frame.
local function Track()
    local mapID, scale = container.mapID, container.targetScale
    if not (mapID and scale and container.targetScrollX) then return end
    local saved = Saved()
    local zoom = scale / container:GetScaleForMinZoom()
    if zoom < 1.01 then
        saved[mapID] = nil
        return
    end
    local s = saved[mapID]
    if not s then
        s = {}
        saved[mapID] = s
    end
    s.zoom, s.x, s.y = zoom, container.targetScrollX, container.targetScrollY
end

function ns.SetupZoom(map)
    container = map.ScrollContainer
    if not (container and container.ResetZoom and container.InstantPanAndZoom) then return end
    hooksecurefunc(container, "ResetZoom", Restore)
    container:HookScript("OnUpdate", Track)
end

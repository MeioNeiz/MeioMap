-- Remembered zoom: each map keeps its zoom and position until /reload. The client zooms out
-- on every map change and every time the map opens (ScrollContainer:ResetZoom); right after
-- that, put back what the map had. Zoom is kept as a multiple of the zoomed-out scale, so it
-- survives switching between the small and the maximised map.
local _, ns = ...

local saved = {} -- mapID -> { zoom, x, y }
local container

local function Restore()
    local s = ns.db.zoom and saved[container.mapID]
    if not s then return end
    local min, max = container:GetScaleForMinZoom(), container:GetScaleForMaxZoom()
    container:InstantPanAndZoom(math.min(s.zoom * min, max), s.x, s.y, true)
end

-- read every frame while the map is open: by the time a map change or ResetZoom runs, the
-- old map's view is already gone
local function Track()
    local mapID, scale = container.mapID, container.targetScale
    if not (mapID and scale and container.targetScrollX) then return end
    local zoom = scale / container:GetScaleForMinZoom()
    if zoom < 1.01 then
        saved[mapID] = nil
    else
        saved[mapID] = { zoom = zoom, x = container.targetScrollX, y = container.targetScrollY }
    end
end

function ns.SetupZoom(map)
    container = map.ScrollContainer
    if not (container and container.ResetZoom and container.InstantPanAndZoom) then return end
    hooksecurefunc(container, "ResetZoom", Restore)
    container:HookScript("OnUpdate", Track)
end

function ns.ForgetZoom() wipe(saved) end

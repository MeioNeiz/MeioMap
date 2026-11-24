-- Options panel (Esc > Options > AddOns > MeioMap, or /meiomap). Checkboxes match
-- the /meiomap toggles; coordinates are a proxy for the client's own CVars.
local _, ns = ...

local category

local function Header(layout, title, tip)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title, tip))
    end
end

local function Register()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("MeioMap")
    local toggles = {}
    for _, t in ipairs(ns.TOGGLES) do toggles[t.key] = t end

    local function Checkbox(key)
        local t = toggles[key]
        local variable = "MEIOMAP_" .. key:upper()
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, t.label, true,
            function() return ns.Get(t) and true or false end,
            function(v)
                if t.set then t.set(v) else ns.db[key] = v end
                ns.Refresh()
            end)
        local tip = t.tip .. " (/meiomap " .. key .. " on||off)"
        Settings.CreateCheckbox(category, setting, tip)
    end

    if ns.HAS_REVEAL then
        Header(layout, "Unexplored areas", "Parts of a zone map you have not been to yet.")
        Checkbox("reveal")
        Checkbox("tint")
    end
    Header(layout, "On hover", "Under the area name while the mouse is over the map.")
    Checkbox("levels")
    Checkbox("fishing")
    Header(layout, "Coordinates", "Bottom-left corner of the world map.")
    Checkbox("coords")
    Settings.RegisterAddOnCategory(category)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    local ok, err = pcall(Register)
    if not ok then geterrorhandler()(err) end
end)

function ns.OpenSettings()
    if not category then return false end
    Settings.OpenToCategory(category:GetID())
    return true
end

function MeioMap_OnAddonCompartmentClick()
    if not ns.OpenSettings() then SlashCmdList.MEIOMAP("help") end
end

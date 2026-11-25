-- Herbalism and mining skill per zone: what the easiest and the hardest node there needs.
-- Lists counted from the client's GatherMate2_Data Forever node dump (nodes under ~5 per zone
-- ignored), Silver, Gold and Truesilver from Wowhead Classic: they share spots with Tin, Iron
-- and Mithril, so the dump undercounts them. Keyed by UiMap ID as Zones.lua.
local _, ns = ...

local SKILL = {
    Peacebloom = 1, Silverleaf = 1, Earthroot = 15, Mageroyal = 50, Briarthorn = 70,
    Stranglekelp = 85, Bruiseweed = 100, ["Wild Steelbloom"] = 115, ["Grave Moss"] = 120,
    Kingsblood = 125, Liferoot = 150, Fadeleaf = 160, Goldthorn = 170,
    ["Khadgar's Whisker"] = 185, Wintersbite = 195, Firebloom = 205, ["Purple Lotus"] = 210,
    ["Arthas' Tears"] = 220, Sungrass = 230, Blindweed = 235, ["Ghost Mushroom"] = 245,
    Gromsblood = 250, ["Golden Sansam"] = 260, Dreamfoil = 270, ["Mountain Silversage"] = 280,
    Plaguebloom = 285, Icecap = 290, ["Black Lotus"] = 300,

    Copper = 1, Tin = 65, Incendicite = 65, Silver = 75, Iron = 125, Gold = 155,
    Mithril = 175, Truesilver = 230, ["Dark Iron"] = 230, ["Small Thorium"] = 245,
    ["Rich Thorium"] = 275,
}

local function Range(names)
    if not names then return end
    local min, max
    for _, name in ipairs(names) do
        local skill = assert(SKILL[name], name)
        min = math.min(min or skill, skill)
        max = math.max(max or skill, skill)
    end
    return { min, max }
end

local G = {}
local function Zone(mapID, herbs, ores)
    G[mapID] = { herb = Range(herbs), ore = Range(ores) }
end

local STARTER = { "Peacebloom", "Silverleaf", "Earthroot" }
local LOW_ORE = { "Copper", "Tin", "Silver" }

-- Kalimdor
Zone(1411, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal" }, { "Copper" }) -- Durotar
Zone(1412, STARTER, { "Copper" }) -- Mulgore
Zone(1438, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal" }) -- Teldrassil
Zone(1439, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn",
    "Stranglekelp", "Bruiseweed" }, LOW_ORE) -- Darkshore
Zone(1413, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn",
    "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Kingsblood" }, LOW_ORE) -- The Barrens
Zone(1442, { "Mageroyal", "Briarthorn", "Bruiseweed", "Wild Steelbloom", "Kingsblood" },
    { "Copper", "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Stonetalon
Zone(1440, { "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom",
    "Kingsblood", "Liferoot", "Purple Lotus", "Gromsblood" },
    { "Copper", "Tin", "Silver", "Iron", "Gold" }) -- Ashenvale
Zone(1441, { "Bruiseweed", "Wild Steelbloom", "Kingsblood" },
    { "Copper", "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Thousand Needles
Zone(1443, { "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood",
    "Liferoot", "Gromsblood" },
    { "Copper", "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Desolace
Zone(1445, { "Stranglekelp", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn",
    "Khadgar's Whisker" },
    { "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Dustwallow Marsh
Zone(1444, { "Stranglekelp", "Liferoot", "Goldthorn", "Khadgar's Whisker", "Purple Lotus",
    "Sungrass", "Golden Sansam" },
    { "Silver", "Iron", "Gold", "Mithril", "Truesilver", "Small Thorium" }) -- Feralas
Zone(1446, { "Stranglekelp", "Firebloom", "Purple Lotus" },
    { "Silver", "Iron", "Gold", "Mithril", "Truesilver", "Small Thorium" }) -- Tanaris
Zone(1447, { "Stranglekelp", "Goldthorn", "Khadgar's Whisker", "Purple Lotus", "Sungrass",
    "Golden Sansam", "Dreamfoil", "Mountain Silversage" },
    { "Gold", "Mithril", "Truesilver", "Rich Thorium" }) -- Azshara
Zone(1448, { "Arthas' Tears", "Sungrass", "Gromsblood", "Golden Sansam", "Dreamfoil",
    "Mountain Silversage", "Plaguebloom" },
    { "Mithril", "Truesilver", "Small Thorium" }) -- Felwood
Zone(1449, { "Blindweed", "Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium", "Rich Thorium" }) -- Un'Goro Crater
Zone(1451, { "Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Black Lotus" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium", "Rich Thorium" }) -- Silithus
Zone(1452, { "Mountain Silversage", "Icecap", "Black Lotus" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium", "Rich Thorium" }) -- Winterspring

-- Eastern Kingdoms
Zone(1429, STARTER, { "Copper" }) -- Elwynn Forest
Zone(1426, STARTER, { "Copper" }) -- Dun Morogh
Zone(1420, STARTER, { "Copper" }) -- Tirisfal Glades
Zone(1436, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn",
    "Stranglekelp", "Bruiseweed" }, LOW_ORE) -- Westfall
Zone(1432, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn",
    "Bruiseweed" }, LOW_ORE) -- Loch Modan
Zone(1421, { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn",
    "Stranglekelp", "Bruiseweed" }, LOW_ORE) -- Silverpine Forest
Zone(1433, { "Earthroot", "Mageroyal", "Briarthorn", "Bruiseweed" },
    LOW_ORE) -- Redridge Mountains
Zone(1431, { "Mageroyal", "Briarthorn", "Bruiseweed", "Wild Steelbloom", "Grave Moss",
    "Kingsblood" }, { "Copper", "Tin", "Silver", "Iron", "Gold" }) -- Duskwood
Zone(1437, { "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom",
    "Grave Moss", "Kingsblood", "Liferoot" },
    { "Copper", "Tin", "Silver", "Incendicite", "Iron", "Gold" }) -- Wetlands
Zone(1424, { "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Wild Steelbloom",
    "Kingsblood", "Liferoot" },
    { "Copper", "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Hillsbrad
Zone(1416, { "Stranglekelp", "Bruiseweed", "Kingsblood", "Liferoot", "Fadeleaf",
    "Khadgar's Whisker", "Wintersbite" },
    { "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Alterac Mountains
Zone(1417, { "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Liferoot", "Fadeleaf",
    "Goldthorn", "Khadgar's Whisker" },
    { "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Arathi Highlands
Zone(1434, { "Stranglekelp", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn",
    "Khadgar's Whisker", "Purple Lotus" },
    { "Tin", "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Stranglethorn Vale
Zone(1418, { "Wild Steelbloom", "Kingsblood", "Fadeleaf", "Goldthorn", "Khadgar's Whisker",
    "Firebloom", "Purple Lotus" },
    { "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Badlands
Zone(1435, { "Stranglekelp", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn",
    "Khadgar's Whisker", "Blindweed" },
    { "Silver", "Iron", "Gold", "Mithril", "Truesilver" }) -- Swamp of Sorrows
Zone(1425, { "Stranglekelp", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker",
    "Purple Lotus", "Sungrass", "Ghost Mushroom", "Golden Sansam" },
    { "Silver", "Iron", "Gold", "Mithril", "Truesilver", "Small Thorium" }) -- Hinterlands
Zone(1427, { "Firebloom" },
    { "Iron", "Gold", "Mithril", "Truesilver", "Small Thorium" }) -- Searing Gorge
Zone(1428, { "Sungrass", "Dreamfoil", "Mountain Silversage", "Black Lotus" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium", "Rich Thorium" }) -- Burning Steppes
Zone(1419, { "Firebloom", "Sungrass", "Gromsblood" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium" }) -- Blasted Lands
Zone(1422, { "Arthas' Tears", "Sungrass", "Dreamfoil", "Mountain Silversage", "Plaguebloom" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium", "Rich Thorium" }) -- W Plaguelands
Zone(1423, { "Arthas' Tears", "Sungrass", "Golden Sansam", "Dreamfoil", "Mountain Silversage",
    "Plaguebloom", "Black Lotus" },
    { "Gold", "Mithril", "Truesilver", "Small Thorium", "Rich Thorium" }) -- E Plaguelands

ns.GATHER = G

-- Fishing skill to land every catch (no "got away") per zone, Classic values: the server's zone
-- base level + 95. Keyed by UiMap ID. Zones without fishable water are left out.
local _, ns = ...

local T = {}
local function Tier(skill, ...)
    for i = 1, select("#", ...) do T[select(i, ...)] = skill end
end

-- starting zones and capitals
Tier(25, 1411, 1412, 1420, 1426, 1429, 1438, 1453, 1454, 1455, 1456, 1457, 1458)
-- Darkshore, Barrens, Silverpine, Loch Modan, Westfall
Tier(75, 1439, 1413, 1421, 1432, 1436)
-- Ashenvale, Stonetalon, Duskwood, Redridge, Wetlands, Hillsbrad
Tier(150, 1440, 1442, 1431, 1433, 1437, 1424)
-- Desolace, Thousand Needles, Dustwallow, Alterac, Arathi, Stranglethorn, Swamp of Sorrows
Tier(225, 1443, 1441, 1445, 1416, 1417, 1434, 1435)
-- Azshara, Feralas, Tanaris, Un'Goro, Felwood, Moonglade, Hinterlands, Western Plaguelands
Tier(300, 1447, 1444, 1446, 1449, 1448, 1450, 1425, 1422)
-- Winterspring, Silithus, Eastern Plaguelands, Deadwind Pass
Tier(425, 1452, 1451, 1423, 1430)

ns.FISHING = T

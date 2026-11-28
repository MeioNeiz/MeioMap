# Meio Map

## 1.3.0

- The zone line no longer covers the map's own title or another addon's fishing line under
  it (Leatrix Maps): it moves below them
- Waypoint arrow: Shift-click a map pin or use the map search, and an arrow at the top of
  the screen points there with the yards and time left; it clears when you arrive. Drag to
  move, right-click clears. `/meiomap way 42.5 71.7 westfall`, `/meiomap arrow off`
- Map search: a box on the world map's top bar finds a zone, dungeon or flight master and
  shows it; a flight master or dungeon gets a waypoint. `/meiomap search off`
- Try it (off for now): `/meiomap dungeons on` shows Blizzard's map of the dungeon you are
  in with M, turned to your level, bosses in kill order with a tick for each kill; any
  dungeon from the map's Dungeons menu or `/meiomap dungeon <name>`
- Try it (off for now): `/meiomap entrances on` marks dungeon and raid entrances on zone and
  continent maps; hover for levels, click opens the dungeon map, Shift-click sets a waypoint

## 1.2.0

- Hovering a zone names the areas you have not discovered there yet ("Unexplored Addle's
  Stead, Raven Hill, Raven Hill Cemetery +5"), for exploration credit and the Legacy talent
  point. `/meiomap explore off` hides it
- Each map's zoom and position now last through /reload and logout

## 1.1.0

- With Herbalism or Mining, hovering a zone also shows the skill its herbs and ore need
  ("Herbs 50-125  Ore 1-155"): green when you can gather them all, yellow for some, red for
  none. `/meiomap gather off` hides it
- Each map keeps its zoom and position when you switch maps or close and reopen the map,
  until you reload. `/meiomap zoom off` for the old way
- Try it: `/meiomap reveal on` draws the unexplored parts of each zone map in a bluish grey
  (off for now)

## 1.0.1

- `/meiomap` alone opens the Settings panel, as the README said; `/meiomap help` lists the
  commands
- Hovering a cave or city district on a zone map shows that zone's levels and fishing

## 1.0.0

- First release: hover a zone on the world map to see its level range and the fishing skill
  that lands every catch there, green or red against yours
- Turns on the game's own player and cursor coordinates on the world map, once

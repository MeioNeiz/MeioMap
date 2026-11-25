# Meio Map

Hover a zone on the world map to see its level range and the fishing, herb and ore skill it
needs.

For WoW Forever.

![Duskwood's map with the mouse on The Darkened Bank: before, only the area name; with Meio
Map, "Levels 18-30" and "Fishing 150" under it](docs/before-after.png)

## What it does

The world map tells you what the zone under your mouse is good for.

- On a zone's own map: its level range under the area name, coloured for your level
- The fishing skill that lands every catch there, on zone and continent maps: green when
  yours is enough, red when not
- With Herbalism or Mining: the skill the zone's herbs and ore need ("Herbs 50-125
  Ore 1-155"), green when you can gather them all, yellow for some, red for none

![Twilight Grove in Duskwood hovered by a herbalist and miner: "Levels 18-30, Fishing 150,
Herbs 50-125, Ore 1-155", coloured for your skill](docs/gather.png)
- Each map keeps its zoom and position when you switch maps or close the map
- Turns on the game's own player and cursor coordinates once; switch them off any time

Settings: Esc > Options > AddOns > MeioMap, or `/meiomap`. Hovering a cave or city
district shows the zone it sits in.

- `/meiomap levels on|off`: level ranges
- `/meiomap fishing on|off`: fishing skill
- `/meiomap gather on|off`: herb and ore skill
- `/meiomap zoom on|off`: remembered zoom
- `/meiomap coords on|off`: coordinates
- `/meiomap reset`: everything back to defaults
- `/meiomap help`: these commands

New and off for now: unexplored parts of each zone map drawn in a bluish grey, so you
still see where you have been. Try it with `/meiomap reveal on` (`/meiomap tint off` for
full colour) and say on GitHub if anything looks wrong.

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs and ideas: [GitHub issues](https://github.com/MeioNeiz/MeioMap/issues)

## More Meio addons

[Meio Trainer Compare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio Auto Rank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio Meter Hover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Plates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio Stats](https://addons.wago.io/addons/meiostats) | [Meio Bags](https://addons.wago.io/addons/meiobags) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes) | [Meio Tooltip Fold](https://addons.wago.io/addons/meiotooltipfold) | [Meio Auto Run Turn](https://addons.wago.io/addons/meioautorunturn) | [Meio Mail](https://addons.wago.io/addons/meiomail) | [Meio QoL](https://addons.wago.io/addons/meioqol) | [Meio TSM Browse](https://addons.wago.io/addons/tsmbrowse) | [Meio Shards](https://addons.wago.io/addons/meioshards) | [Meionomics](https://www.curseforge.com/wow/addons/meionomics) | [Meio Spike Check](https://addons.wago.io/addons/meiospikecheck) | [Meio BiS Extras](https://addons.wago.io/addons/meiobisextras) | [Meio Buff Thanks](https://addons.wago.io/addons/meiobuffthanks) | [Meio Flare Fixes](https://addons.wago.io/addons/meioflarefixes) | [Meio Flare Questie](https://addons.wago.io/addons/meioflarequestie)

## Licence

[MIT](LICENSE)

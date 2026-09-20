# AtlasLootForever 0.5.0

Dungeon loot browser for **World of Warcraft: Forever**, with a collector that records
what actually drops for you.

## Two sources of loot

The addon shows both side by side:

- **Reference** — 23 dungeons, 261 boss entries and 1335 item rows (1131 unique items) pulled from
  [foreverchanges.pro](https://foreverchanges.pro/) on 2026-09-19. These show up tagged `ref`, with
  no count. It includes the two new dungeons that already have known loot (Hall of Thanes and Ruins
  of Lordaeron); the other seven either have no drop seen in the beta or no encounter named yet.
- **Collected** — what you saw drop yourself. Shows `drops/loots` and a percentage, and the boss
  turns green in the list. The two are joined by boss name, so as you farm, the reference table
  gains real numbers on top of it.

Anything you loot that the reference does not list is called out in chat as **NEW** and tagged in
the item list. That is how you find beta content nobody has published yet.

## Dungeons

28 are listed: the 9 new Forever dungeons and the 19 classic ones. Raids are out on purpose. Wings
(Scarlet Monastery, Dire Maul, Blackrock Spire, Stratholme) appear as one entry each, because that
is how `GetInstanceInfo()` names the instance — split them and the collector would never match.

## Install

Copy the `AtlasLootForever` folder into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\
```

Restart the client (a brand new addon does not appear on `/reload` alone). The TOC targets
`## Interface: 16001`, the beta client build, so no "out of date" warning.

If a patch changes that number, find the new one with `/dump select(4, GetBuildInfo())` and edit
both `.toc` files.

## Using it

| Command | What it does |
|---|---|
| `/alf` | open and close the browser |
| `/alf export` | export as lines, to paste into Discord or a spreadsheet |
| `/alf export lua` | export as a Lua table |
| `/alf import` | open the import window |
| `/alf blocked` | list functions the client blocked, with context |
| `/alf events` | show which events the client accepted registering |
| `/alf combatlog` | try registering the combat log (refused on this client) |
| `/alf minimap` | show or hide the minimap button |
| `/alf stats` | coverage and totals |
| `/alf reset` | erase everything collected |

There is also a **minimap button** (left click opens, right click exports, drag to move) and a
**keybinding** under Key Bindings → AddOns.

In the window: column one is dungeons with a `seen/total` coverage counter, column two is bosses,
column three is the loot.

- **Hover** an item for the full tooltip.
- **Shift-click** puts the item link in chat.
- **Ctrl-click** opens the dressing room.
- The **search box** looks through every item in both sources — it answers "where does this drop?".
- The number on the right of an item is `times dropped / times looted` plus the estimate. With 3
  runs it means nothing; with 30 it starts to.

**Item tooltips anywhere in the game** (bags, vendors, links in chat) get a line showing which
dungeon and boss the item comes from, and your own drop rate when you have a sample.

## How collection works

- Every looted corpse is attributed to the exact **NPC ID** from `GetLootSourceInfo`, so it does not
  confuse mobs killed next to each other.
- On client 16001 some GUIDs arrive as **secret values**: addon code cannot compare or slice them
  and trying raises an error. The addon never touches `UnitGUID("target")` or `UnitName("target")`,
  and every GUID read goes through `pcall`. When the corpse GUID is unreadable, the loot is
  attributed to the last mob killed and marked **(guess)**.
- The client **refuses** `COMBAT_LOG_EVENT_UNFILTERED` for addons (confirmed on the beta on
  2026-09-19: `ADDON_ACTION_FORBIDDEN` on `Frame:RegisterEvent`). It is not registered at load —
  that was what produced the block popup on every login. `/alf combatlog` tries it on demand in
  case a future patch allows it.
- Without the combat log, the NPC name comes from, in order: a name already known → the **loot
  window title** → the XP message ("X dies, you gain..."). The title also works at 60, where there
  is no XP. Item attribution never depends on the name: it uses the NPC ID.
- Reopening the same corpse counts neither the item nor the loot twice.
- By default it only records inside dungeons and raids, and only green or better.

## Sharing with your guild

Everyone runs `/alf export`, pastes the lines into a Discord channel, and whoever wants runs
`/alf import` and pastes it all back. Counters are merged, so the drop estimate improves with the
whole group's volume.

A line looks like:

```
ALF1;map=2100;inst=Ruins of Lordaeron;npc=12345;npcname=Witherfang;loots=7;item=54321;q=3;n=2;g=0
```

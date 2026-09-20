-- AtlasLootForeverImenso :: Data.lua
-- Known instances, grouped into sections.
--
-- Boss and loot lists are empty on purpose: as of 2026-09-19 Blizzard had not
-- published boss-by-boss data for any new dungeon, and the sites that did
-- contradict each other. The addon fills this from real drops (Collector.lua).
--
-- The names below are what GetInstanceInfo() returns, which is why wings
-- (Scarlet Monastery, Dire Maul, Blackrock Spire) appear as a single entry:
-- that is how the client names the instance.

local ADDON, ns = ...

ns.Data = ns.Data or {}

ns.Data.sections = {
	{
		title = "New dungeons (Forever)",
		entries = {
			{ name = "Hall of Thanes",      levels = "13-18", zone = "Ironforge" },
			{ name = "Ruins of Lordaeron",  levels = "15-20", zone = "Tirisfal Glades" },
			{ name = "Excavation Site",     levels = "24-29", zone = "Wetlands" },
			{ name = "City of Dalaran",     levels = "28-33", zone = "Alterac Mountains" },
			{ name = "The Drowned City",    levels = "35-40", zone = "Stranglethorn Vale" },
			{ name = "Krol'Dok Stronghold", levels = "40-45", zone = "The Riverglades" },
			{ name = "Alcaz Island Prison", levels = "48-53", zone = "Dustwallow Marsh" },
			{ name = "Blackmaw Hold",       levels = "55-60", zone = "Azshara" },
			{ name = "Shaper's Terrace",    levels = "58-60", zone = "Un'Goro Crater" },
		},
	},
	{
		title = "Classic dungeons",
		entries = {
			{ name = "Ragefire Chasm",            levels = "13-18", zone = "Orgrimmar" },
			{ name = "Wailing Caverns",           levels = "17-24", zone = "The Barrens" },
			{ name = "The Deadmines",             levels = "17-26", zone = "Westfall" },
			{ name = "Shadowfang Keep",           levels = "22-30", zone = "Silverpine Forest" },
			{ name = "Blackfathom Deeps",         levels = "24-32", zone = "Ashenvale" },
			{ name = "The Stockade",              levels = "24-32", zone = "Stormwind City" },
			{ name = "Gnomeregan",                levels = "29-38", zone = "Dun Morogh" },
			{ name = "Razorfen Kraul",            levels = "29-38", zone = "The Barrens" },
			{ name = "Scarlet Monastery",         levels = "28-45", zone = "Tirisfal Glades" },
			{ name = "Razorfen Downs",            levels = "37-46", zone = "The Barrens" },
			{ name = "Uldaman",                   levels = "41-51", zone = "Badlands" },
			{ name = "Zul'Farrak",                levels = "44-54", zone = "Tanaris" },
			{ name = "Maraudon",                  levels = "46-55", zone = "Desolace" },
			{ name = "The Temple of Atal'Hakkar", levels = "50-60", zone = "Swamp of Sorrows" },
			{ name = "Blackrock Depths",          levels = "52-60", zone = "Blackrock Mountain" },
			{ name = "Dire Maul",                 levels = "55-60", zone = "Feralas" },
			{ name = "Blackrock Spire",           levels = "55-60", zone = "Blackrock Mountain" },
			{ name = "Scholomance",               levels = "58-60", zone = "Western Plaguelands" },
			{ name = "Stratholme",                levels = "58-60", zone = "Eastern Plaguelands" },
		},
	},
}

-- Flat list + index by name
ns.Data.dungeons = {}
ns.Data.byName = {}

for _, section in ipairs(ns.Data.sections) do
	for _, entry in ipairs(section.entries) do
		entry.section = section.title
		tinsert(ns.Data.dungeons, entry)
		ns.Data.byName[entry.name] = entry
	end
end

function ns.Data.Info(name)
	if not name then return nil end
	return ns.Data.byName[name]
end

-- AtlasLootForever :: Core.lua
-- Namespace, database, helpers and item cache.

local ADDON, ns = ...

ns.ADDON = ADDON

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or "0.1.0"

local GetItemInfoFn = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemInfoInstantFn = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)

ns.QUALITY_COLOR = {
	[0] = "ff9d9d9d", -- poor
	[1] = "ffffffff", -- common
	[2] = "ff1eff00", -- uncommon
	[3] = "ff0070dd", -- rare
	[4] = "ffa335ee", -- epic
	[5] = "ffff8000", -- legendary
	[6] = "ffe6cc80", -- artifact
	[7] = "ffe6cc80", -- heirloom
}

function ns.Print(msg)
	local frame = DEFAULT_CHAT_FRAME
	if frame then
		frame:AddMessage("|cff66ccffAtlasLoot|r|cff00ff00Forever|r: " .. tostring(msg))
	end
end

-------------------------------------------------------------------------------
-- Database
-------------------------------------------------------------------------------

local DB_VERSION = 1

local function DefaultDB()
	return {
		version = DB_VERSION,
		-- [instanceKey] = { name, mapID, npcs = { [npcID] = true } }
		instances = {},
		-- [npcID] = { name, instanceKey, loots = n, items = { [itemID] = { q, n, guess } } }
		npcs = {},
		settings = {
			minQuality = 2, -- hide grey and white by default
			onlyInstances = true, -- only record inside dungeons and raids
			captureChatLoot = true, -- try to attribute loot party members pick up
			announceNew = true, -- announce drops the reference does not know
			minimapAngle = 210, -- where the button sits around the minimap
			minimapHide = false,
		},
	}
end

function ns.InitDB()
	if type(AtlasLootForeverDB) ~= "table" then
		AtlasLootForeverDB = DefaultDB()
	end
	local db = AtlasLootForeverDB
	local defaults = DefaultDB()
	for key, value in pairs(defaults) do
		if db[key] == nil then
			db[key] = value
		end
	end
	for key, value in pairs(defaults.settings) do
		if db.settings[key] == nil then
			db.settings[key] = value
		end
	end
	db.version = DB_VERSION
	ns.db = db
	return db
end

function ns.InstanceKey(mapID, name)
	if mapID and mapID > 0 then
		return "m" .. tostring(mapID)
	end
	return "n" .. tostring(name or "desconhecido")
end

function ns.GetInstanceEntry(mapID, name, create)
	local db = ns.db
	if not db then return nil end
	local key = ns.InstanceKey(mapID, name)
	local entry = db.instances[key]
	if not entry and create then
		entry = { name = name or "Desconhecido", mapID = mapID or 0, npcs = {} }
		db.instances[key] = entry
	end
	if entry and name and entry.name ~= name then
		entry.name = name
	end
	return entry, key
end

function ns.GetNpcEntry(npcID, create)
	local db = ns.db
	if not db or not npcID then return nil end
	local entry = db.npcs[npcID]
	if not entry and create then
		entry = { name = nil, instanceKey = nil, loots = 0, items = {} }
		db.npcs[npcID] = entry
	end
	return entry
end

-------------------------------------------------------------------------------
-- Utilidades
-------------------------------------------------------------------------------

-- "Creature-0-1234-5678-90-12345-000ABCDEF" -> 12345
--
-- Client 16001 returns some GUIDs as "secret values": addon code cannot
-- compare, concatenate or slice them, and any attempt raises an error. So
-- every read goes through pcall. If the parse worked the value is a plain
-- string and is safe to use as a table key.
local function ParseNpcID(guid)
	if type(guid) ~= "string" then return nil end
	local unitType, _, _, _, _, npcID = strsplit("-", guid)
	if unitType == "Creature" or unitType == "Vehicle" then
		return tonumber(npcID)
	end
	return nil
end

ns.secretHits = 0

function ns.NpcIDFromGUID(guid)
	local ok, npcID = pcall(ParseNpcID, guid)
	if ok then
		return npcID
	end
	ns.secretHits = ns.secretHits + 1
	return nil
end

function ns.ItemIDFromLink(link)
	if type(link) ~= "string" then return nil end
	local id = link:match("item:(%d+)")
	return tonumber(id)
end

function ns.ItemLink(itemID)
	return "item:" .. tostring(itemID)
end

-- Item name cache. GetItemInfo can return nil on first access; the item then
-- goes into a queue and is filled in on GET_ITEM_INFO_RECEIVED.
local pending = {}
ns.itemCache = {}

function ns.GetItemData(itemID)
	local cached = ns.itemCache[itemID]
	if cached and cached.name then
		return cached
	end

	local data = cached or {}
	local ok, name, _, quality, _, _, itemType, itemSubType, _, equipSlot, texture = pcall(GetItemInfoFn, itemID)
	if ok and name then
		data.name = name
		data.quality = quality
		data.itemType = itemType
		data.itemSubType = itemSubType
		data.equipSlot = equipSlot
		data.texture = texture
		pending[itemID] = nil
	else
		pending[itemID] = true
		if GetItemInfoInstantFn then
			local ok2, _, iType, iSubType, iEquip, iTexture = pcall(GetItemInfoInstantFn, itemID)
			if ok2 then
				data.itemType = data.itemType or iType
				data.itemSubType = data.itemSubType or iSubType
				data.equipSlot = data.equipSlot or iEquip
				data.texture = data.texture or iTexture
			end
		end
	end

	ns.itemCache[itemID] = data
	return data
end

function ns.OnItemInfoReceived(itemID)
	if itemID and pending[itemID] then
		pending[itemID] = nil
		ns.itemCache[itemID] = nil
		ns.GetItemData(itemID)
		if ns.RefreshUI then
			ns.RefreshUI()
		end
	end
end

-- Ask the server for items that still have no name, so the panel is not empty.
function ns.WarmItemCache()
	for itemID in pairs(pending) do
		ns.GetItemData(itemID)
	end
end

function ns.QualityText(quality, text)
	local color = ns.QUALITY_COLOR[quality or 1] or ns.QUALITY_COLOR[1]
	return "|c" .. color .. tostring(text) .. "|r"
end

function ns.Percent(part, total)
	if not total or total <= 0 then return "-" end
	local pct = (part / total) * 100
	if pct >= 99.5 then return "100%" end
	if pct < 1 then return string.format("%.1f%%", pct) end
	return string.format("%.0f%%", pct)
end

-- Replaced by Diagnostics.lua and Collector.lua; these stay so the addon
-- does not break if one of those files fails to load.
function ns.MarkAction() end
function ns.DumpBlocked() ns.Print("diagnostics module did not load.") end
function ns.DumpEvents() ns.Print("collector did not load.") end
function ns.TryCombatLog() ns.Print("collector did not load.") end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

SLASH_ATLASLOOTFOREVER1 = "/alf"
SLASH_ATLASLOOTFOREVER2 = "/atlaslootforever"

SlashCmdList["ATLASLOOTFOREVER"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if msg == "export" then
		ns.ShowExport("linha")
	elseif msg == "export lua" then
		ns.ShowExport("lua")
	elseif msg == "import" then
		ns.ShowImport()
	elseif msg == "reset" then
		AtlasLootForeverDB = nil
		ns.InitDB()
		ns.Print("database wiped.")
		if ns.RefreshUI then ns.RefreshUI() end
	elseif msg == "blocked" or msg == "bloqueios" then
		ns.DumpBlocked()
	elseif msg == "events" or msg == "eventos" then
		ns.DumpEvents()
	elseif msg == "combatlog" then
		ns.TryCombatLog()
	elseif msg == "minimap" then
		ns.ToggleMinimapButton()
	elseif msg == "stats" then
		local npcs, items = 0, 0
		for _, npc in pairs(ns.db.npcs) do
			npcs = npcs + 1
			for _ in pairs(npc.items) do items = items + 1 end
		end

		local seen, total, extra = ns.GlobalCoverage()
		ns.Print(string.format("reference coverage: %d/%d (%s)", seen, total, ns.Percent(seen, total)))
		if extra > 0 then
			ns.Print(string.format("|cff40d040%d|r item(s) the reference does not list", extra))
		end
		ns.Print(string.format("%d NPCs with loot recorded, %d items in total.", npcs, items))
	elseif msg == "help" or msg == "ajuda" then
		ns.Print("/alf - open the browser")
		ns.Print("/alf export - export as lines (to paste into Discord)")
		ns.Print("/alf export lua - export as a Lua table")
		ns.Print("/alf import - open the import window")
		ns.Print("/alf blocked - show the functions the client blocked")
		ns.Print("/alf events - show which events the client accepted")
		ns.Print("/alf combatlog - try the combat log (refused on this client)")
		ns.Print("/alf minimap - show or hide the minimap button")
		ns.Print("/alf stats - how much has been collected")
		ns.Print("/alf reset - erase everything collected")
	else
		ns.ToggleUI()
	end
end

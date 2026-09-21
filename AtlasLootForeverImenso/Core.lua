-- AtlasLootForeverImenso :: Core.lua
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
		frame:AddMessage("|cff66ccffAtlasLoot|r|cff00ff00Forever|r|cffffd100Imenso|r: " .. tostring(msg))
	end
end

-------------------------------------------------------------------------------
-- Database
-------------------------------------------------------------------------------

local DB_VERSION = 2

local function DefaultDB()
	return {
		version = DB_VERSION,
		-- [instanceKey] = { name, mapID, npcs = { [npcID] = true } }
		instances = {},
		-- [npcID] = { name, instanceKey, loots = n, items = { [itemID] = { q, n, guess } } }
		npcs = {},
		-- [itemID] = { s = status, n = client name when renamed, q, t } (Validate.lua)
		validation = {},
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

-- The addon used to be called AtlasLootForever. If its database is still in
-- memory (the old folder is installed and loads first) and this one is empty,
-- take everything over, once, so nothing collected is lost by the rename.
local function AdoptOldDatabase()
	local old = rawget(_G, "AtlasLootForeverDB")
	if type(old) ~= "table" then return false end
	if type(old.npcs) ~= "table" then return false end

	local copy = {}
	for key, value in pairs(old) do copy[key] = value end
	copy.adoptedFrom = "AtlasLootForever"
	AtlasLootForeverImensoDB = copy
	return true
end

function ns.InitDB()
	local adopted = false
	if type(AtlasLootForeverImensoDB) ~= "table" then
		adopted = AdoptOldDatabase()
		if not adopted then
			AtlasLootForeverImensoDB = DefaultDB()
		end
	end
	local db = AtlasLootForeverImensoDB
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

	if adopted then
		local npcs = 0
		for _ in pairs(db.npcs) do npcs = npcs + 1 end
		ns.Print(string.format("picked up the old AtlasLootForever database: %d NPC(s) with loot.", npcs))
	end

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

-- Hyperlink string for tooltips (SetHyperlink accepts this short form)
function ns.ItemLink(itemID)
	return "item:" .. tostring(itemID)
end

-- Real, clickable chat link: |cff...|Hitem:ID:...|h[Name]|h|r
-- GetItemInfo only returns it once the client has the item cached, so there is
-- a fallback that builds a valid link from the cached name and quality.
function ns.ItemChatLink(itemID)
	local ok, _, link = pcall(GetItemInfoFn, itemID)
	if ok and type(link) == "string" and link ~= "" then
		return link
	end

	local data = ns.GetItemData(itemID)
	if data and data.name then
		local color = ns.QUALITY_COLOR[data.quality or 1] or ns.QUALITY_COLOR[1]
		return string.format("|c%s|Hitem:%d|h[%s]|h|r", color, itemID, data.name)
	end

	return nil
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
	if ns.ValidateOnItemInfo then
		ns.ValidateOnItemInfo(itemID)
	end
end

-- Ask the server for items that still have no name, so the panel is not empty.
function ns.WarmItemCache()
	for itemID in pairs(pending) do
		ns.GetItemData(itemID)
	end
end

-- "Head, Plate" style description line, like AtlasLoot's item subtext
function ns.ItemSlotText(data)
	if not data then return "" end
	local parts = {}
	local slot = data.equipSlot
	if slot and slot ~= "" and _G[slot] then parts[#parts + 1] = _G[slot] end
	if data.itemSubType and data.itemSubType ~= "" then parts[#parts + 1] = data.itemSubType end
	return table.concat(parts, ", ")
end

-------------------------------------------------------------------------------
-- Fonts
--
-- Blizzard's font objects are shared by the whole interface, so changing one
-- changes every window in the game. Instead each one we use gets a private
-- copy, two points larger, and only this addon's text is pointed at the copy.
-------------------------------------------------------------------------------

ns.FONT_BUMP = 2

local fontCache = {}

function ns.Font(baseName)
	local cached = fontCache[baseName]
	if cached ~= nil then return cached end

	local base = _G[baseName]
	local made = false

	if base and base.GetFont and CreateFont then
		local ok, file, size, flags = pcall(base.GetFont, base)
		if ok and file and size then
			local copy = CreateFont("AtlasLootForeverImenso" .. baseName)
			if copy then
				pcall(copy.SetFont, copy, file, size + ns.FONT_BUMP, flags)
				local okColor, r, g, b, a = pcall(base.GetTextColor, base)
				if okColor and r then pcall(copy.SetTextColor, copy, r, g, b, a) end
				local okShadow, sr, sg, sb, sa = pcall(base.GetShadowColor, base)
				if okShadow and sr then pcall(copy.SetShadowColor, copy, sr, sg, sb, sa) end
				local okOffset, ox, oy = pcall(base.GetShadowOffset, base)
				if okOffset and ox then pcall(copy.SetShadowOffset, copy, ox, oy) end
				made = copy
			end
		end
	end

	fontCache[baseName] = made
	return made
end

-- Creates a font string already using the enlarged copy.
function ns.FontString(parent, layer, baseName)
	local fontString = parent:CreateFontString(nil, layer or "OVERLAY", baseName)
	local bumped = ns.Font(baseName)
	if bumped then pcall(fontString.SetFontObject, fontString, bumped) end
	return fontString
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
function ns.StartValidation() ns.Print("validation module did not load.") end
function ns.ValidationReport() ns.Print("validation module did not load.") end
function ns.InvalidateLooted() end
function ns.DumpBlocked() ns.Print("diagnostics module did not load.") end
function ns.DumpEvents() ns.Print("collector did not load.") end
function ns.TryCombatLog() ns.Print("collector did not load.") end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

SLASH_ATLASLOOTFOREVERIMENSO1 = "/alfi"
SLASH_ATLASLOOTFOREVERIMENSO2 = "/alf"
SLASH_ATLASLOOTFOREVERIMENSO3 = "/atlaslootforeverimenso"

local function Help()
	ns.Print("|cffffd100browser|r")
	ns.Print("   /alfi - open the browser")
	ns.Print("   /alfi minimap - show or hide the minimap button")
	ns.Print("|cffffd100validating the loot tables|r")
	ns.Print("   /alfi validate - check the dungeon you are standing in")
	ns.Print("   /alfi validate all - check every dungeon (takes a minute)")
	ns.Print("   /alfi validate <name> - e.g. /alfi validate strat")
	ns.Print("   /alfi report - summary of what was already validated")
	ns.Print("   /alfi report <name> - list the renamed and missing ids")
	ns.Print("|cffffd100your own data|r")
	ns.Print("   /alfi stats - how much has been collected")
	ns.Print("   /alfi export - export as lines (to paste into Discord)")
	ns.Print("   /alfi export lua - export as a Lua table")
	ns.Print("   /alfi import - open the import window")
	ns.Print("   /alfi reset - erase everything collected")
	ns.Print("|cffffd100client diagnostics|r")
	ns.Print("   /alfi blocked - functions client 16001 refused")
	ns.Print("   /alfi events - which events the client accepted")
	ns.Print("   /alfi combatlog - try the combat log (refused on this client)")
end

local function Validate(argument)
	if argument == "all" or argument == "tudo" then
		ns.StartValidation(nil)
		return
	end

	if argument == "" or argument == "here" or argument == "aqui" then
		local here = ns.CurrentDungeon and ns.CurrentDungeon()
		if not here then
			ns.Print("you are not in a dungeon - use |cffffd100/alfi validate all|r or name one.")
			return
		end
		ns.StartValidation(here)
		return
	end

	local name, matches = ns.ResolveDungeon and ns.ResolveDungeon(argument)
	if name then
		ns.StartValidation(name)
	elseif matches and #matches > 1 then
		ns.Print("which one? " .. table.concat(matches, ", "))
	else
		ns.Print(string.format("no dungeon matching \"%s\".", argument))
	end
end

local function Report(argument)
	if argument == "" then
		ns.ValidationReport(nil)
		return
	end

	local name, matches = ns.ResolveDungeon and ns.ResolveDungeon(argument)
	if name then
		ns.ValidationReport(name)
	elseif matches and #matches > 1 then
		ns.Print("which one? " .. table.concat(matches, ", "))
	else
		ns.Print(string.format("no dungeon matching \"%s\".", argument))
	end
end

SlashCmdList["ATLASLOOTFOREVERIMENSO"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local command, argument = msg:match("^(%S*)%s*(.-)$")
	command = (command or ""):lower()
	argument = argument or ""

	if command == "export" then
		ns.ShowExport(argument:lower() == "lua" and "lua" or "linha")
	elseif command == "import" then
		ns.ShowImport()
	elseif command == "validate" or command == "validar" then
		Validate(argument:lower())
	elseif command == "report" or command == "relatorio" then
		Report(argument)
	elseif command == "reset" then
		AtlasLootForeverImensoDB = nil
		ns.InitDB()
		ns.InvalidateLooted()
		ns.Print("database wiped.")
		if ns.RefreshUI then ns.RefreshUI() end
	elseif command == "blocked" or command == "bloqueios" then
		ns.DumpBlocked()
	elseif command == "events" or command == "eventos" then
		ns.DumpEvents()
	elseif command == "combatlog" then
		ns.TryCombatLog()
	elseif command == "minimap" then
		ns.ToggleMinimapButton()
	elseif command == "stats" then
		local npcs, items = 0, 0
		for _, npc in pairs(ns.db.npcs) do
			npcs = npcs + 1
			for _ in pairs(npc.items) do items = items + 1 end
		end

		local seen, total, extra = ns.GlobalCoverage()
		ns.Print(string.format("reference: %d items, %s (%s)",
			ns.RefTotal or total, ns.RefDate or "?", ns.RefSource or "?"))
		ns.Print(string.format("coverage by your own drops: %d/%d (%s)", seen, total, ns.Percent(seen, total)))
		if extra > 0 then
			ns.Print(string.format("|cff40d040%d|r item(s) the reference does not list", extra))
		end
		ns.Print(string.format("%d NPCs with loot recorded, %d items in total.", npcs, items))
	elseif command == "help" or command == "ajuda" then
		Help()
	else
		ns.ToggleUI()
	end
end

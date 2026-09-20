-- AtlasLootForever :: Collector.lua
-- Records real drops: which item came from which NPC, in which instance, and
-- how many times that corpse was looted (the denominator for the drop chance).
--
-- Client 16001 (Forever): some GUIDs arrive as "secret values" and addon code
-- may not compare or slice them. So this file never touches UnitGUID("target")
-- or UnitName("target"): the NPC id comes from GetLootSourceInfo when the value
-- is readable, and falls back to the last mob killed, in which case the record
-- is flagged as a guess.

local ADDON, ns = ...

local frame = CreateFrame("Frame")

-- NPC names seen dying this session: [npcID] = name
local npcNames = {}
-- Corpses already counted this session, so the denominator is not inflated
local countedCorpses = {}
-- Items already recorded per corpse, so reopening the same loot counts once
local corpseItems = {}
-- With no readable GUID, dedupe within the open loot window instead
local sessionNpc, sessionItems = nil, {}
-- Last boss/mob killed, used when the corpse GUID is not readable
local lastKill = nil
-- Name of the last mob killed, taken from the XP message, used when the combat
-- log is unavailable
local lastKillName = nil

local function CurrentInstance()
	local name, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
	return name, instanceType, instanceMapID
end

local function ShouldRecord(instanceType)
	if not ns.db or not ns.db.settings.onlyInstances then
		return true
	end
	return instanceType == "party" or instanceType == "raid"
end

-- Records one item from a specific NPC.
-- guess = true when the attribution did not come from the real loot source.
local function RecordItem(npcID, npcName, itemID, quality, guess)
	if not npcID or not itemID then return end

	local instanceName, instanceType, mapID = CurrentInstance()
	if not ShouldRecord(instanceType) then return end

	local minQuality = ns.db.settings.minQuality or 0
	if quality and quality < minQuality then return end

	local instanceEntry, instanceKey = ns.GetInstanceEntry(mapID, instanceName, true)
	local npc = ns.GetNpcEntry(npcID, true)

	npc.name = npcName or npc.name or npcNames[npcID]
	npc.instanceKey = instanceKey
	instanceEntry.npcs[npcID] = true

	local item = npc.items[itemID]
	if not item then
		item = { q = quality, n = 0, guess = guess and true or nil }
		npc.items[itemID] = item

		-- an item the reference does not list is beta news, worth flagging
		if ns.db.settings.announceNew and not guess
		   and ns.IsInReference and not ns.IsInReference(instanceName, itemID) then
			local data = ns.GetItemData(itemID)
			ns.Print(string.format("|cff40d040NEW|r (not in the reference): %s  <- %s",
				(data and data.name) or ("item " .. itemID),
				npcName or npc.name or "?"))
		end

		if ns.InvalidateSourceIndex then ns.InvalidateSourceIndex() end
	end

	item.n = item.n + 1
	if quality then item.q = quality end
	if not guess then item.guess = nil end

	ns.GetItemData(itemID)
end

-- Counts one loot of that corpse (denominator of the drop chance)
local function CountLoot(npcID, npcName, corpseGUID)
	if not npcID then return end

	if corpseGUID then
		if countedCorpses[corpseGUID] then return end
		countedCorpses[corpseGUID] = true
	else
		if sessionNpc == npcID then return end
		sessionNpc = npcID
	end

	local instanceName, instanceType, mapID = CurrentInstance()
	if not ShouldRecord(instanceType) then return end

	local instanceEntry, instanceKey = ns.GetInstanceEntry(mapID, instanceName, true)
	local npc = ns.GetNpcEntry(npcID, true)
	npc.name = npcName or npc.name or npcNames[npcID]
	npc.instanceKey = instanceKey
	npc.loots = (npc.loots or 0) + 1
	instanceEntry.npcs[npcID] = true
end

-- Works out which NPC the loot came from.
-- Returns npcID, corpseGUID (only when readable) and whether it is a guess.
local function ResolveSource(slots)
	if GetLootSourceInfo then
		for slot = 1, slots do
			local ok, guid = pcall(GetLootSourceInfo, slot)
			if ok then
				local npcID = ns.NpcIDFromGUID(guid)
				-- if the parse worked, guid is a plain string and is safe as a key
				if npcID then
					return npcID, guid, false
				end
			end
		end
	end

	-- No readable GUID: assume the last mob killed, and flag it as a guess.
	if lastKill and (GetTime() - lastKill.time) <= 60 then
		return lastKill.npcID, nil, true
	end

	return nil, nil, false
end

-- Corpse name read from the loot window title. Without the combat log this is
-- the most accurate source left, and it still works at level 60 where there is
-- no XP message. If the client returns empty, generic or secret, it is ignored.
local TITLE_GLOBALS = { "LootFrameTitleText", "LootFrameTitle" }

local function LootWindowName()
	for _, global in ipairs(TITLE_GLOBALS) do
		local obj = _G[global]
		if obj and obj.GetText then
			local ok, text = pcall(obj.GetText, obj)
			if ok and type(text) == "string" and text ~= "" and text ~= LOOT and text ~= "Loot" then
				return text
			end
		end
	end
	return nil
end

local function HandleLootOpened()
	ns.MarkAction("reading the loot window")

	local slots = GetNumLootItems and GetNumLootItems() or 0
	if slots == 0 then return end

	local npcID, corpseGUID, guess = ResolveSource(slots)
	if not npcID then return end

	-- order: name already known -> loot window title -> XP message
	local npcName = npcNames[npcID] or LootWindowName()
	if not npcName and lastKillName and (GetTime() - lastKillName.time) <= 30 then
		npcName = lastKillName.name
	end
	if npcName then
		npcNames[npcID] = npcName
	end

	CountLoot(npcID, npcName, corpseGUID)

	local recorded
	if corpseGUID then
		recorded = corpseItems[corpseGUID]
		if not recorded then
			recorded = {}
			corpseItems[corpseGUID] = recorded
		end
	else
		recorded = sessionItems
	end

	for slot = 1, slots do
		local okLink, link = pcall(GetLootSlotLink, slot)
		local itemID = okLink and ns.ItemIDFromLink(link) or nil
		if itemID and not recorded[itemID] then
			local quality
			if GetLootSlotInfo then
				local okInfo, _, _, _, _, slotQuality = pcall(GetLootSlotInfo, slot)
				if okInfo then quality = slotQuality end
			end
			RecordItem(npcID, npcName, itemID, quality, guess)
			recorded[itemID] = true
		end
	end

	if ns.RefreshUI then ns.RefreshUI() end
end

-- Loot shown in chat (items party members picked up).
-- Only attributed if a mob died recently, and always flagged as a guess.
local function HandleChatLoot(text)
	if not ns.db or not ns.db.settings.captureChatLoot then return end
	if not lastKill then return end
	if (GetTime() - lastKill.time) > 60 then return end

	local itemID = ns.ItemIDFromLink(text)
	if not itemID then return end

	local data = ns.GetItemData(itemID)
	RecordItem(lastKill.npcID, lastKill.name, itemID, data and data.quality, true)
end

-- "Kobold Laborer dies, you gain 42 experience."
-- A name source for when the combat log is unavailable. The Portuguese
-- patterns stay as a fallback for clients running in ptBR.
local function HandleXPGain(text)
	if type(text) ~= "string" then return end
	local name = text:match("^(.-) dies, you gain")
		or text:match("^(.-) morre, voc\195\170 ganha")
		or text:match("^(.-) morre, voce ganha")
	if name and name ~= "" then
		lastKillName = { name = name, time = GetTime() }
	end
end

local function HandleUnitDied()
	local _, subEvent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
	if subEvent ~= "UNIT_DIED" then return end

	local npcID = ns.NpcIDFromGUID(destGUID)
	if not npcID then return end

	if type(destName) == "string" then
		npcNames[npcID] = destName
	end
	lastKill = { npcID = npcID, name = npcNames[npcID], time = GetTime() }
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == ADDON then
			ns.InitDB()
			if ns.SetupMinimap then pcall(ns.SetupMinimap) end
			if ns.SetupTooltip then pcall(ns.SetupTooltip) end
			ns.Print("loaded. /alf opens the browser, /alf help lists the commands.")
		end

	elseif event == "LOOT_OPENED" then
		local ok, err = pcall(HandleLootOpened)
		if not ok then ns.Print("error reading the loot: " .. tostring(err)) end

	elseif event == "LOOT_CLOSED" then
		sessionNpc = nil
		sessionItems = {}

	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		pcall(HandleUnitDied)

	elseif event == "CHAT_MSG_LOOT" then
		local text = ...
		pcall(HandleChatLoot, text)

	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		local text = ...
		pcall(HandleXPGain, text)

	elseif event == "GET_ITEM_INFO_RECEIVED" then
		local itemID = ...
		ns.OnItemInfoReceived(itemID)

	elseif event == "PLAYER_ENTERING_WORLD" then
		wipe(npcNames)
		wipe(countedCorpses)
		wipe(corpseItems)
		sessionNpc, sessionItems = nil, {}
		lastKill, lastKillName = nil, nil
		if ns.WarmItemCache then ns.WarmItemCache() end
		if ns.UpdateMinimapPosition then pcall(ns.UpdateMinimapPosition) end
	end
end)

-------------------------------------------------------------------------------
-- Event registration
--
-- Client 16001 refuses some events for addons (ADDON_ACTION_FORBIDDEN on
-- Frame:RegisterEvent). We register one at a time, marking the context first,
-- and check right after with IsEventRegistered - so /alf events can name
-- exactly which one was refused, and the collector runs on what is left.
-------------------------------------------------------------------------------

-- COMBAT_LOG_EVENT_UNFILTERED was CONFIRMED refused by client 16001
-- (ADDON_ACTION_FORBIDDEN on Frame:RegisterEvent, verified on the beta on
-- 2026-09-19). Registering it only produced the block popup on every login, so
-- it is out of the list. The handler stays in the file and /alf combatlog tries
-- it on demand, in case a future patch allows it.
local EVENTS = {
	"ADDON_LOADED",
	"PLAYER_ENTERING_WORLD",
	"GET_ITEM_INFO_RECEIVED",
	"LOOT_OPENED",
	"LOOT_CLOSED",
	"CHAT_MSG_LOOT",
	"CHAT_MSG_COMBAT_XP_GAIN",
}

ns.eventStatus = {}

for _, event in ipairs(EVENTS) do
	ns.MarkAction("registering " .. event)
	pcall(frame.RegisterEvent, frame, event)

	local ok, active = pcall(frame.IsEventRegistered, frame, event)
	ns.eventStatus[event] = (ok and active) and true or false
end

ns.MarkAction("idle")

function ns.DumpEvents()
	ns.Print("collector events:")
	local refused = 0
	for _, event in ipairs(EVENTS) do
		local active = ns.eventStatus[event]
		if not active then refused = refused + 1 end
		ns.Print(string.format("  %s  %s",
			active and "|cff40d040active|r" or "|cffff4040REFUSED|r", event))
	end
	if refused > 0 then
		ns.Print(string.format("|cffff4040%d event(s) refused by the client.|r", refused))
	end
end

-- Tries to register the combat log on demand. If the client refuses, the block
-- popup shows up - but you asked for it, it no longer happens by itself.
function ns.TryCombatLog()
	local event = "COMBAT_LOG_EVENT_UNFILTERED"
	ns.MarkAction("manual test of " .. event)
	pcall(frame.RegisterEvent, frame, event)

	local ok, active = pcall(frame.IsEventRegistered, frame, event)
	ns.eventStatus[event] = (ok and active) and true or false

	if ns.eventStatus[event] then
		ns.Print("|cff40d040combat log allowed|r - NPC names come from it again.")
	else
		ns.Print("combat log still refused by the client. Nothing changed.")
	end
end

ns.collectorFrame = frame
ns.collectorEvents = EVENTS

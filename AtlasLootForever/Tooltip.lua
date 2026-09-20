-- AtlasLootForever :: Tooltip.lua
-- Adds the source of any item to its tooltip: dungeon, boss and, once you have
-- seen it drop, the drop estimate from your own runs.
--
-- Client 16001 uses TooltipDataProcessor; older clients use OnTooltipSetItem.
-- Both paths are covered, each wrapped in pcall.

local ADDON, ns = ...

local MAX_LINES = 4

-- itemID -> { {dungeon, boss}, ... }, built on demand
local sourceIndex
local collectedDirty = true

local function AddSource(index, itemID, dungeon, boss)
	local list = index[itemID]
	if not list then
		list = {}
		index[itemID] = list
	end
	for _, entry in ipairs(list) do
		if entry.dungeon == dungeon and entry.boss == boss then return end
	end
	list[#list + 1] = { dungeon = dungeon, boss = boss }
end

local function BuildIndex()
	local index = {}

	for dungeon, byBoss in pairs(ns.RefIndex or {}) do
		for boss, items in pairs(byBoss) do
			for _, item in ipairs(items) do
				AddSource(index, item.id, dungeon, boss)
			end
		end
	end

	if ns.db then
		for npcID, npc in pairs(ns.db.npcs) do
			local instance = npc.instanceKey and ns.db.instances[npc.instanceKey]
			local dungeon = instance and instance.name or "Unknown"
			local boss = npc.name or ("NPC " .. npcID)
			for itemID in pairs(npc.items) do
				AddSource(index, itemID, dungeon, boss)
			end
		end
	end

	sourceIndex = index
	collectedDirty = false
	return index
end

function ns.InvalidateSourceIndex()
	collectedDirty = true
end

function ns.SourcesForItem(itemID)
	if not sourceIndex or collectedDirty then BuildIndex() end
	return sourceIndex[itemID]
end

-- Drop chance computed from YOUR loots, when there is a sample
local function DropStat(itemID, bossName)
	if not ns.db then return nil end
	for _, npc in pairs(ns.db.npcs) do
		if npc.name == bossName then
			local item = npc.items[itemID]
			if item and (npc.loots or 0) > 0 then
				return string.format("%d/%d  %s", item.n or 1, npc.loots, ns.Percent(item.n or 1, npc.loots))
			end
		end
	end
	return nil
end

local function AddLines(tooltip, itemID)
	if not itemID or not tooltip or not tooltip.AddLine then return end

	local sources = ns.SourcesForItem(itemID)
	if not sources or #sources == 0 then return end

	tooltip:AddLine(" ")
	tooltip:AddLine("AtlasLoot|cff00ff00Forever|r", 0.4, 0.8, 1)

	local shown = 0
	for _, entry in ipairs(sources) do
		if shown >= MAX_LINES then
			tooltip:AddLine(string.format("... and %d more source(s)", #sources - shown), 0.6, 0.6, 0.6)
			break
		end

		local stat = DropStat(itemID, entry.boss)
		local right = stat or ""
		tooltip:AddDoubleLine(
			string.format("%s › %s", entry.dungeon, entry.boss), right,
			0.9, 0.9, 0.9,
			0.6, 0.9, 0.6
		)
		shown = shown + 1
	end
end

ns.AddTooltipLines = AddLines

local function Hook()
	-- modern path (client 16001)
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
	   and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
			local itemID = data and data.id
			if itemID then pcall(AddLines, tooltip, itemID) end
		end)
		return "TooltipDataProcessor"
	end

	-- classic path
	if GameTooltip and GameTooltip.HookScript then
		GameTooltip:HookScript("OnTooltipSetItem", function(self)
			local _, link = self:GetItem()
			local itemID = ns.ItemIDFromLink(link)
			if itemID then pcall(AddLines, self, itemID) end
		end)
		return "OnTooltipSetItem"
	end

	return nil
end

function ns.SetupTooltip()
	local ok, how = pcall(Hook)
	ns.tooltipHook = ok and how or nil
	return ns.tooltipHook
end

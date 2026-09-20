-- AtlasLootForever :: UI.lua
-- Browser: dungeon -> boss -> loot, with global search and drop estimates.

local ADDON, ns = ...

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ui
local state = { instance = nil, boss = nil, search = "" }

-------------------------------------------------------------------------------
-- List helpers
-------------------------------------------------------------------------------

local function MakeColumn(parent, title, x, width)
	local column = CreateFrame("Frame", nil, parent)
	column:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -74)
	column:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 16)
	column:SetWidth(width)

	column.title = column:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	column.title:SetPoint("TOPLEFT", column, "TOPLEFT", 4, 0)
	column.title:SetText(title)

	local scroll = CreateFrame("ScrollFrame", nil, column, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -16)
	scroll:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", -22, 0)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width - 24, 1)
	scroll:SetScrollChild(content)

	column.scroll = scroll
	column.content = content
	column.rows = {}
	return column
end

local function GetRow(column, index, height)
	local row = column.rows[index]
	if not row then
		row = CreateFrame("Button", nil, column.content)
		row:SetHeight(height or 18)

		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetAllPoints()
		row.highlight:SetColorTexture(1, 1, 1, 0.08)
		row.highlight:Hide()

		row:SetScript("OnEnter", function(self)
			self.highlight:Show()
			if self.tooltipItem then
				ns.MarkAction("item tooltip")
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, ns.ItemLink(self.tooltipItem))
				if not ok then
					GameTooltip:SetText("Item " .. tostring(self.tooltipItem))
				end
				GameTooltip:Show()
			elseif self.tooltipText then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function(self)
			if not self.selected then self.highlight:Hide() end
			GameTooltip:Hide()
		end)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(14, 14)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.label:SetJustifyH("LEFT")

		row.right = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.right:SetJustifyH("RIGHT")

		row.label:SetPoint("RIGHT", row.right, "LEFT", -4, 0)

		column.rows[index] = row
	end

	local offset = -((index - 1) * (height or 18))
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", column.content, "TOPLEFT", 0, offset)
	row:SetPoint("TOPRIGHT", column.content, "TOPRIGHT", 0, offset)
	row.tooltipItem, row.tooltipText, row.selected = nil, nil, false
	row.highlight:Hide()
	row:Show()
	return row
end

local function HideRowsFrom(column, index)
	for i = index, #column.rows do
		column.rows[i]:Hide()
	end
end

-------------------------------------------------------------------------------
-- Building the lists
-------------------------------------------------------------------------------

local function BuildInstanceList()
	local db = ns.db
	local list, seen = {}, {}

	local dbKeyByName = {}
	for key, instance in pairs(db.instances) do
		dbKeyByName[instance.name] = key
	end

	for _, section in ipairs(ns.Data.sections) do
		tinsert(list, { header = section.title })
		for _, entry in ipairs(section.entries) do
			tinsert(list, {
				name = entry.name,
				levels = entry.levels,
				zone = entry.zone,
				note = entry.note,
				dbKey = dbKeyByName[entry.name],
			})
			seen[entry.name] = true
		end
	end

	-- Anything the collector found that is not in the lists above
	local discovered = {}
	for key, instance in pairs(db.instances) do
		if not seen[instance.name] then
			tinsert(discovered, { name = instance.name, dbKey = key, discovered = true })
		end
	end

	if #discovered > 0 then
		table.sort(discovered, function(a, b) return a.name < b.name end)
		tinsert(list, { header = "Discovered" })
		for _, entry in ipairs(discovered) do
			tinsert(list, entry)
		end
	end

	return list
end

-- Merges the reference bosses (foreverchanges.pro) with what the collector saw.
-- The join key is the name: if a looted NPC has the same name as a reference
-- boss, the two become a single row.
local function BuildBossList(dbKey, instanceName)
	local db = ns.db
	local list, byName = {}, {}

	for _, entry in ipairs(ns.RefBosses(instanceName) or {}) do
		local bossName = entry[1]
		local e = { name = bossName, ref = ns.RefItems(instanceName, bossName) }
		tinsert(list, e)
		byName[bossName] = e
	end

	local instance = dbKey and db.instances[dbKey]
	if instance then
		for npcID in pairs(instance.npcs) do
			local npc = db.npcs[npcID]
			if npc then
				local label = npc.name or ("NPC " .. npcID)
				local e = byName[label]
				if not e then
					e = { name = label }
					tinsert(list, e)
					byName[label] = e
				end
				e.npcID, e.npc = npcID, npc
			end
		end
	end

	return list
end

local function FindEntry(list, name)
	for _, entry in ipairs(list) do
		if entry.name == name then return entry end
	end
	return nil
end

local function BuildItemList(entry)
	local list, byID = {}, {}
	if not entry then return list end

	for _, ref in ipairs(entry.ref or {}) do
		local row = { itemID = ref.id, refName = ref.name, loots = 0 }
		byID[ref.id] = row
		tinsert(list, row)
	end

	if entry.npc then
		for itemID, item in pairs(entry.npc.items) do
			local row = byID[itemID]
			if not row then
				row = { itemID = itemID }
				byID[itemID] = row
				tinsert(list, row)
			end
			row.count = item.n or 1
			row.quality = item.q
			row.guess = item.guess
			row.isNew = ns.IsInReference and not ns.IsInReference(state.instance, itemID)
			row.loots = entry.npc.loots or 0
		end
	end

	for _, row in ipairs(list) do
		local data = ns.GetItemData(row.itemID)
		row.name = (data and data.name) or row.refName or ("Item " .. row.itemID)
		row.texture = (data and data.texture) or FALLBACK_ICON
		row.quality = row.quality or (data and data.quality)
	end

	table.sort(list, function(a, b)
		local qa, qb = a.quality or -1, b.quality or -1
		if qa ~= qb then return qa > qb end
		return a.name < b.name
	end)
	return list
end

local function BuildSearchList(query)
	query = query:lower()
	local results, seen = {}, {}

	-- what you collected
	for npcID, npc in pairs(ns.db.npcs) do
		local instance = npc.instanceKey and ns.db.instances[npc.instanceKey]
		for itemID, item in pairs(npc.items) do
			local data = ns.GetItemData(itemID)
			local name = (data and data.name) or ""
			if name ~= "" and name:lower():find(query, 1, true) then
				seen[itemID] = true
				tinsert(results, {
					itemID = itemID,
					quality = item.q or 1,
					count = item.n or 1,
					name = name,
					texture = (data and data.texture) or FALLBACK_ICON,
					loots = npc.loots or 0,
					origin = string.format("%s › %s",
						instance and instance.name or "?",
						npc.name or ("NPC " .. npcID)),
				})
			end
		end
	end

	-- and what the reference knows
	for dungeon, byBoss in pairs(ns.RefIndex or {}) do
		for bossName, items in pairs(byBoss) do
			for _, ref in ipairs(items) do
				if not seen[ref.id] then
					local data = ns.GetItemData(ref.id)
					local name = (data and data.name) or ref.name
					if name:lower():find(query, 1, true) then
						seen[ref.id] = true
						tinsert(results, {
							itemID = ref.id,
							quality = data and data.quality,
							name = name,
							texture = (data and data.texture) or FALLBACK_ICON,
							loots = 0,
							origin = string.format("%s › %s", dungeon, bossName),
						})
					end
				end
			end
		end
	end

	table.sort(results, function(a, b)
		local qa, qb = a.quality or -1, b.quality or -1
		if qa ~= qb then return qa > qb end
		return a.name < b.name
	end)
	return results
end

-------------------------------------------------------------------------------
-- Render
-------------------------------------------------------------------------------

local function OnItemClick(self)
	local link = ns.ItemLink(self.tooltipItem)
	if IsShiftKeyDown() then
		ns.MarkAction("shift-click (chat link)")
		if ChatEdit_InsertLink then pcall(ChatEdit_InsertLink, link) end
	elseif IsControlKeyDown() then
		ns.MarkAction("ctrl-click (dressing room)")
		if DressUpItemLink then pcall(DressUpItemLink, link) end
	end
end

local function RenderInstances()
	local column = ui.instances
	local list = BuildInstanceList()
	local index = 0

	for _, entry in ipairs(list) do
		index = index + 1
		local row = GetRow(column, index)
		row.icon:SetTexture(nil)

		if entry.header then
			row.label:SetText("|cffffd100" .. entry.header .. "|r")
			row.right:SetText("")
			row:SetScript("OnClick", nil)
			row:EnableMouse(false)
		else
			row:EnableMouse(true)

			local label = entry.name
			if entry.levels then
				label = label .. "  |cff808080" .. entry.levels .. "|r"
			end
			row.label:SetText(label)
			local refSet = ns.RefItemSet and ns.RefItemSet[entry.name]
			local total = refSet and refSet.total or 0
			if total > 0 then
				local seen = 0
				if entry.dbKey then seen = ns.Coverage(entry.name, entry.dbKey) end
				local color = (seen > 0) and "|cff40d040" or "|cff707070"
				row.right:SetText(string.format("%s%d/%d|r", color, seen, total))
			else
				row.right:SetText(entry.dbKey and "|cff40d040*|r" or "")
			end

			local tip = entry.zone or ""
			if entry.note then
				tip = tip ~= "" and (tip .. "\n" .. entry.note) or entry.note
			end
			row.tooltipText = tip ~= "" and tip or nil

			if state.instance == entry.name then
				row.selected = true
				row.highlight:Show()
				ui.selectedDbKey = entry.dbKey
			end

			row:SetScript("OnClick", function()
				state.instance = entry.name
				state.boss = nil
				ns.RefreshUI()
			end)
		end
	end

	HideRowsFrom(column, index + 1)
	column.content:SetHeight(math.max(1, index * 18))
end

local function RenderNpcs()
	local column = ui.npcs
	local list = BuildBossList(ui.selectedDbKey, state.instance)
	ui.bossList = list
	local index = 0

	for _, entry in ipairs(list) do
		index = index + 1
		local row = GetRow(column, index)
		row.icon:SetTexture(nil)

		local refCount = entry.ref and #entry.ref or 0
		local label = entry.name
		if entry.npc then
			label = "|cff40d040" .. label .. "|r"
		end
		row.label:SetText(label)
		row.right:SetText(refCount > 0 and tostring(refCount) or "")

		local tip = {}
		if refCount > 0 then tinsert(tip, refCount .. " items in the reference") end
		if entry.npc then
			tinsert(tip, string.format("NPC ID %d, looted %d time(s)", entry.npcID, entry.npc.loots or 0))
		end
		row.tooltipText = #tip > 0 and table.concat(tip, "\n") or nil

		if state.boss == entry.name then
			row.selected = true
			row.highlight:Show()
		end

		row:SetScript("OnClick", function()
			state.boss = entry.name
			ns.RefreshUI()
		end)
	end

	if index == 0 then
		index = 1
		local row = GetRow(column, 1)
		row.icon:SetTexture(nil)
		row.label:SetText("|cff808080No known bosses in this dungeon|r")
		row.right:SetText("")
		row:SetScript("OnClick", nil)
	end

	HideRowsFrom(column, index + 1)
	column.content:SetHeight(math.max(1, index * 18))
end

local function RenderLoot()
	local column = ui.loot
	local index = 0
	local minQuality = ns.db.settings.minQuality or 0

	if state.search ~= "" and #state.search >= 2 then
		column.title:SetText("Search: \"" .. state.search .. "\"")
		for _, entry in ipairs(BuildSearchList(state.search)) do
			if (entry.quality or 99) >= minQuality then
				index = index + 1
				local row = GetRow(column, index)
				row.icon:SetTexture(entry.texture)
				row.label:SetText(ns.QualityText(entry.quality, entry.name) .. "  |cff707070" .. entry.origin .. "|r")
				row.right:SetText(entry.count and ns.Percent(entry.count, entry.loots) or "")
				row.tooltipItem = entry.itemID
				row:SetScript("OnClick", OnItemClick)
			end
		end
	else
		local entry = ui.bossList and FindEntry(ui.bossList, state.boss)
		if entry then
			local suffix = entry.npc and ("  |cff808080(" .. (entry.npc.loots or 0) .. " loots)|r") or ""
			column.title:SetText("Loot - " .. entry.name .. suffix)
		else
			column.title:SetText("Loot")
		end

		for _, row0 in ipairs(BuildItemList(entry)) do
			if (row0.quality or 99) >= minQuality then
				index = index + 1
				local row = GetRow(column, index)
				row.icon:SetTexture(row0.texture)

				local suffix = row0.guess and "  |cffb0602a(guess)|r" or ""
				if row0.isNew then suffix = suffix .. "  |cff40d040new|r" end
				row.label:SetText(ns.QualityText(row0.quality, row0.name) .. suffix)

				if row0.count then
					row.right:SetText(string.format("%d/%d  %s",
						row0.count, row0.loots, ns.Percent(row0.count, row0.loots)))
				else
					row.right:SetText("|cff606060ref|r")
				end

				row.tooltipItem = row0.itemID
				row:SetScript("OnClick", OnItemClick)
			end
		end
	end

	if index == 0 then
		index = 1
		local row = GetRow(column, 1)
		row.icon:SetTexture(nil)
		row.label:SetText("|cff808080Nothing to show yet. Run the dungeon and loot the bosses.|r")
		row.right:SetText("")
		row.tooltipItem = nil
		row:SetScript("OnClick", nil)
	end

	HideRowsFrom(column, index + 1)
	column.content:SetHeight(math.max(1, index * 18))
end

function ns.RefreshUI()
	if not ui or not ui:IsShown() then return end
	ui.selectedDbKey = nil
	RenderInstances()
	RenderNpcs()
	RenderLoot()
end

-------------------------------------------------------------------------------
-- Window construction
-------------------------------------------------------------------------------

local function CreateUI()
	local f = CreateFrame("Frame", "AtlasLootForeverFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(900, 520)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "AtlasLootForeverFrame")

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.title:SetPoint("TOP", f, "TOP", 0, -6)
	f.title:SetText("AtlasLoot|cff00ff00Forever|r  " .. ns.version)

	-- search box
	local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	search:SetSize(220, 20)
	search:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -32)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function(self)
		state.search = self:GetText() or ""
		ns.RefreshUI()
	end)
	search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
	f.search = search

	local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	searchLabel:SetPoint("LEFT", search, "RIGHT", 6, 0)
	searchLabel:SetText("search every item in the database")

	-- quality filter
	local blueOnly = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	blueOnly:SetSize(22, 22)
	blueOnly:SetPoint("TOPLEFT", f, "TOPLEFT", 420, -30)
	blueOnly.text = blueOnly:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	blueOnly.text:SetPoint("LEFT", blueOnly, "RIGHT", 2, 0)
	blueOnly.text:SetText("blue or better only")
	blueOnly:SetScript("OnClick", function(self)
		ns.db.settings.minQuality = self:GetChecked() and 3 or 0
		ns.RefreshUI()
	end)
	f.blueOnly = blueOnly

	-- buttons
	local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	exportBtn:SetSize(90, 20)
	exportBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -30)
	exportBtn:SetText("Export")
	exportBtn:SetScript("OnClick", function() ns.ShowExport("linha") end)

	local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	importBtn:SetSize(90, 20)
	importBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
	importBtn:SetText("Import")
	importBtn:SetScript("OnClick", function() ns.ShowImport() end)

	f.instances = MakeColumn(f, "Dungeons", 16, 230)
	f.npcs = MakeColumn(f, "Bosses / NPCs", 252, 200)
	f.loot = MakeColumn(f, "Loot", 458, 424)

	f:SetScript("OnShow", function()
		f.blueOnly:SetChecked((ns.db.settings.minQuality or 0) >= 3)
		ns.WarmItemCache()
		ns.RefreshUI()
	end)

	return f
end

function ns.ToggleUI()
	ns.MarkAction("toggling the window")
	if not ns.db then ns.InitDB() end
	ui = ui or CreateUI()
	if ui:IsShown() then
		ui:Hide()
	else
		ui:Show()
	end
end

-- Keybinding target (see Bindings.xml)
function AtlasLootForever_Toggle()
	ns.ToggleUI()
end

BINDING_HEADER_ATLASLOOTFOREVER = "AtlasLootForever"
BINDING_NAME_ATLASLOOTFOREVER_TOGGLE = "Toggle the loot browser"

-- AtlasLootForeverImenso :: UI.lua
-- Browser: dungeon -> boss -> loot, with global search and drop estimates.

local ADDON, ns = ...

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Two points of extra font need room to sit in.
local ROW_HEIGHT = 21

local ui
local state = { instance = nil, boss = nil, search = "" }

local OnItemClick -- definido mais abaixo; usado pelos botoes de item

-------------------------------------------------------------------------------
-- List helpers
-------------------------------------------------------------------------------

local function MakeColumn(parent, title, x, width)
	local column = CreateFrame("Frame", nil, parent)
	column:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -74)
	column:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 16)
	column:SetWidth(width)

	column.title = ns.FontString(column, "OVERLAY", "GameFontNormalSmall")
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
		row:SetHeight(height or ROW_HEIGHT)

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

		row.label = ns.FontString(row, "OVERLAY", "GameFontHighlightSmall")
		row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.label:SetJustifyH("LEFT")

		row.right = ns.FontString(row, "OVERLAY", "GameFontDisableSmall")
		row.right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.right:SetJustifyH("RIGHT")

		row.label:SetPoint("RIGHT", row.right, "LEFT", -4, 0)

		column.rows[index] = row
	end

	local offset = -((index - 1) * (height or ROW_HEIGHT))
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", column.content, "TOPLEFT", 0, offset)
	row:SetPoint("TOPRIGHT", column.content, "TOPRIGHT", 0, offset)
	row.tooltipItem, row.tooltipText, row.selected = nil, nil, false
	row.highlight:Hide()
	row:Show()
	return row
end

local ITEM_HEIGHT = 39

local function ItemTooltip(self)
	self.highlight:Show()
	if not self.itemID then return end
	ns.MarkAction("item tooltip")
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, ns.ItemLink(self.itemID))
	if not ok then GameTooltip:SetText("Item " .. tostring(self.itemID)) end

	if ns.ItemStatus then
		local status, clientName = ns.ItemStatus(self.itemID)
		local info = ns.STATUS_TAG and ns.STATUS_TAG[status]
		if info then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("|c" .. info.color .. info.text .. "|r")
			if status == "renamed" and clientName then
				GameTooltip:AddLine("your client calls it: " .. clientName, 1, 1, 1)
			end
		end
	end
	GameTooltip:AddLine("shift-click links it in chat, ctrl-click tries it on", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

-- Two-column item grid, the way AtlasLoot lays its pages out.
local function GetItemButton(column, index)
	column.items = column.items or {}
	local btn = column.items[index]

	if not btn then
		btn = CreateFrame("Button", nil, column.content)
		btn:RegisterForClicks("LeftButtonUp")

		btn.highlight = btn:CreateTexture(nil, "BACKGROUND")
		btn.highlight:SetAllPoints()
		btn.highlight:SetColorTexture(1, 1, 1, 0.07)
		btn.highlight:Hide()

		btn.icon = btn:CreateTexture(nil, "ARTWORK")
		btn.icon:SetSize(26, 26)
		btn.icon:SetPoint("LEFT", btn, "LEFT", 2, 0)

		btn.stat = ns.FontString(btn, "OVERLAY", "GameFontDisableSmall")
		btn.stat:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3)
		btn.stat:SetJustifyH("RIGHT")

		btn.name = ns.FontString(btn, "OVERLAY", "GameFontNormalSmall")
		btn.name:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 5, -2)
		btn.name:SetPoint("RIGHT", btn.stat, "LEFT", -4, 0)
		btn.name:SetJustifyH("LEFT")
		btn.name:SetWordWrap(false)

		btn.sub = ns.FontString(btn, "OVERLAY", "GameFontDisableSmall")
		btn.sub:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -2)
		btn.sub:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
		btn.sub:SetJustifyH("LEFT")
		btn.sub:SetWordWrap(false)

		btn:SetScript("OnEnter", ItemTooltip)
		btn:SetScript("OnLeave", function(self)
			self.highlight:Hide()
			GameTooltip:Hide()
		end)
		btn:SetScript("OnClick", function(self, ...) return OnItemClick(self, ...) end)

		column.items[index] = btn
	end

	local half = (column.content:GetWidth() or 240) / 2
	local col = (index - 1) % 2
	local line = math.floor((index - 1) / 2)

	btn:SetSize(half - 4, ITEM_HEIGHT)
	btn:ClearAllPoints()
	btn:SetPoint("TOPLEFT", column.content, "TOPLEFT", col * half, -line * ITEM_HEIGHT)
	btn.highlight:Hide()
	btn:Show()
	return btn
end

local function HideItemsFrom(column, index)
	if not column.items then return end
	for i = index, #column.items do
		column.items[i]:Hide()
	end
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
		row.sub = ns.ItemSlotText(data)
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

function OnItemClick(self)
	local itemID = self.itemID or self.tooltipItem
	if not itemID then return end

	if IsShiftKeyDown() then
		ns.MarkAction("shift-click (chat link)")

		local link = ns.ItemChatLink(itemID)
		if not link then
			ns.Print("item not cached yet - hover it once and try again")
			return
		end

		-- insert into the open edit box, or open chat with the link in it
		local inserted = false
		if ChatEdit_InsertLink then
			local ok, res = pcall(ChatEdit_InsertLink, link)
			inserted = ok and res
		end
		if not inserted and ChatFrame_OpenChat then
			pcall(ChatFrame_OpenChat, link)
		end

	elseif IsControlKeyDown() then
		ns.MarkAction("ctrl-click (dressing room)")
		local link = ns.ItemChatLink(itemID) or ns.ItemLink(itemID)
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
	column.content:SetHeight(math.max(1, index * ROW_HEIGHT))
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
		local wing = ns.RefWing and ns.RefWing(state.instance, entry.name)
		if wing then
			label = label .. "  |cff707070" .. wing .. "|r"
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
	column.content:SetHeight(math.max(1, index * ROW_HEIGHT))
end

local function RenderLoot()
	local column = ui.loot
	local count = 0
	local minQuality = ns.db.settings.minQuality or 0

	-- One item cell: icon, coloured name with its validation marker, the slot
	-- line underneath and the drop rate on the right.
	local function Place(row, subText)
		count = count + 1
		local btn = GetItemButton(column, count)
		btn.itemID = row.itemID
		btn.icon:SetTexture(row.texture or FALLBACK_ICON)

		local name = ns.QualityText(row.quality, row.name)
		local marker = ns.StatusMarker and (ns.StatusMarker(row.itemID)) or ""
		if marker ~= "" then name = marker .. " " .. name end
		if row.guess then name = name .. " |cffb0602a?|r" end
		btn.name:SetText(name)

		btn.sub:SetText(subText or row.sub or "")

		if row.count and row.loots and row.loots > 0 then
			btn.stat:SetText(string.format("|cffffffff%s|r  %d/%d",
				ns.Percent(row.count, row.loots), row.count, row.loots))
		elseif row.count then
			btn.stat:SetText(string.format("|cffffffffx%d|r", row.count))
		else
			btn.stat:SetText("")
		end
	end

	if state.search ~= "" and #state.search >= 2 then
		column.title:SetText("Search: \"" .. state.search .. "\"")
		for _, row in ipairs(BuildSearchList(state.search)) do
			if (row.quality or 99) >= minQuality then
				Place(row, "|cff707070" .. (row.origin or "") .. "|r")
			end
		end
	else
		local entry = ui.bossList and FindEntry(ui.bossList, state.boss)
		if entry then
			local suffix = entry.npc and ("  |cff808080" .. (entry.npc.loots or 0) .. " loots|r") or ""
			column.title:SetText("Loot - " .. entry.name .. suffix)
		else
			column.title:SetText("Loot")
		end

		for _, row in ipairs(BuildItemList(entry)) do
			if (row.quality or 99) >= minQuality then
				Place(row)
			end
		end
	end

	if count == 0 then
		HideItemsFrom(column, 1)
		local row = GetRow(column, 1)
		row.icon:SetTexture(nil)
		row.label:SetText("|cff808080Pick a boss on the left, or run the dungeon and loot it.|r")
		row.right:SetText("")
		row.tooltipItem = nil
		row:SetScript("OnClick", nil)
		HideRowsFrom(column, 2)
		column.content:SetHeight(ROW_HEIGHT)
		return
	end

	HideRowsFrom(column, 1)
	HideItemsFrom(column, count + 1)
	column.content:SetHeight(math.max(1, math.ceil(count / 2) * ITEM_HEIGHT))
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
	local f = CreateFrame("Frame", "AtlasLootForeverImensoFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(1080, 600)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "AtlasLootForeverImensoFrame")

	f.title = ns.FontString(f, "OVERLAY", "GameFontHighlight")
	f.title:SetPoint("TOP", f, "TOP", 0, -6)
	f.title:SetText("AtlasLoot|cff00ff00Forever|r|cffffd100Imenso|r  " .. ns.version)

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

	local searchLabel = ns.FontString(f, "OVERLAY", "GameFontDisableSmall")
	searchLabel:SetPoint("LEFT", search, "RIGHT", 6, 0)
	searchLabel:SetText("search every item in the database")

	-- quality filter
	local blueOnly = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	blueOnly:SetSize(22, 22)
	blueOnly:SetPoint("TOPLEFT", f, "TOPLEFT", 420, -30)
	blueOnly.text = ns.FontString(blueOnly, "OVERLAY", "GameFontNormalSmall")
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

	-- Checks the reference against this client. The dungeon selected on the
	-- left is the scope; with none selected it checks everything.
	local validateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	validateBtn:SetSize(90, 20)
	validateBtn:SetPoint("RIGHT", importBtn, "LEFT", -6, 0)
	validateBtn:SetText("Validate")
	validateBtn:SetScript("OnClick", function()
		ns.StartValidation(state.instance)
	end)
	validateBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Validate the loot table", 1, 1, 1)
		GameTooltip:AddLine("Asks your own client about every item id listed for the selected dungeon (all of them when none is selected) and marks each one:", nil, nil, nil, true)
		GameTooltip:AddLine("|cff40d040NEW|r added by Forever      |cff40d040OK|r you looted it", nil, nil, nil, true)
		GameTooltip:AddLine("|cff9d9d9d?|r Classic data, unconfirmed", nil, nil, nil, true)
		GameTooltip:AddLine("|cffffd100~|r renamed      |cffff4040!|r not in your client any more", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	validateBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.validateBtn = validateBtn

	f.instances = MakeColumn(f, "Dungeons", 16, 248)
	f.npcs = MakeColumn(f, "Bosses / NPCs", 270, 226)
	f.loot = MakeColumn(f, "Loot", 502, 562)

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
function AtlasLootForeverImenso_Toggle()
	ns.ToggleUI()
end

BINDING_HEADER_ATLASLOOTFOREVER = "AtlasLootForeverImenso"
BINDING_NAME_ATLASLOOTFOREVER_TOGGLE = "Toggle the loot browser"

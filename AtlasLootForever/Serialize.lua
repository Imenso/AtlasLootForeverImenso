-- AtlasLootForever :: Serialize.lua
-- Export and import of the collected database.
--
-- Line format (one line per item, easy to paste into Discord or a spreadsheet):
--   ALF1;map=2100;inst=Ruins of Lordaeron;npc=12345;npcname=Witherfang;loots=7;item=54321;q=3;n=2;g=0
--
-- Lua format: a table ready to become a static data file.

local ADDON, ns = ...

local function Escape(text)
	text = tostring(text or "")
	return (text:gsub(";", ","))
end

function ns.ExportLines()
	local out = {}
	tinsert(out, "# AtlasLootForever " .. ns.version .. " - exported " .. date("%Y-%m-%d %H:%M"))

	for npcID, npc in pairs(ns.db.npcs) do
		local instance = npc.instanceKey and ns.db.instances[npc.instanceKey]
		local instanceName = instance and instance.name or "Unknown"
		local mapID = instance and instance.mapID or 0

		for itemID, item in pairs(npc.items) do
			tinsert(out, string.format(
				"ALF1;map=%d;inst=%s;npc=%d;npcname=%s;loots=%d;item=%d;q=%d;n=%d;g=%d",
				mapID,
				Escape(instanceName),
				npcID,
				Escape(npc.name or "?"),
				npc.loots or 0,
				itemID,
				item.q or 1,
				item.n or 1,
				item.guess and 1 or 0
			))
		end
	end

	if #out == 1 then
		tinsert(out, "# (nothing collected yet - run a dungeon and loot the bosses)")
	end
	return table.concat(out, "\n")
end

function ns.ExportLua()
	local out = { "AtlasLootForeverData = {" }

	for npcID, npc in pairs(ns.db.npcs) do
		local instance = npc.instanceKey and ns.db.instances[npc.instanceKey]
		local instanceName = instance and instance.name or "Unknown"

		tinsert(out, string.format("\t[%d] = { -- %s", npcID, npc.name or "?"))
		tinsert(out, string.format("\t\tname = %q,", npc.name or "?"))
		tinsert(out, string.format("\t\tinstance = %q,", instanceName))
		tinsert(out, string.format("\t\tloots = %d,", npc.loots or 0))
		tinsert(out, "\t\titems = {")

		for itemID, item in pairs(npc.items) do
			local data = ns.GetItemData(itemID)
			tinsert(out, string.format(
				"\t\t\t{ id = %d, q = %d, n = %d }, -- %s",
				itemID, item.q or 1, item.n or 1, (data and data.name) or "?"
			))
		end

		tinsert(out, "\t\t},")
		tinsert(out, "\t},")
	end

	tinsert(out, "}")
	return table.concat(out, "\n")
end

function ns.ImportLines(text)
	if type(text) ~= "string" then return 0, 0 end

	local npcsTouched, itemsAdded = {}, 0

	for line in text:gmatch("[^\r\n]+") do
		if line:sub(1, 5) == "ALF1;" then
			local fields = {}
			for key, value in line:gmatch("(%w+)=([^;]*)") do
				fields[key] = value
			end

			local npcID = tonumber(fields.npc)
			local itemID = tonumber(fields.item)

			if npcID and itemID then
				local mapID = tonumber(fields.map) or 0
				local instanceEntry, instanceKey = ns.GetInstanceEntry(mapID, fields.inst or "Unknown", true)
				local npc = ns.GetNpcEntry(npcID, true)

				npc.name = npc.name or fields.npcname
				npc.instanceKey = npc.instanceKey or instanceKey
				npc.loots = math.max(npc.loots or 0, tonumber(fields.loots) or 0)
				instanceEntry.npcs[npcID] = true

				local item = npc.items[itemID]
				local count = tonumber(fields.n) or 1
				if not item then
					npc.items[itemID] = {
						q = tonumber(fields.q) or 1,
						n = count,
						guess = (fields.g == "1") or nil,
					}
					itemsAdded = itemsAdded + 1
				else
					item.n = math.max(item.n or 1, count)
				end

				npcsTouched[npcID] = true
				ns.GetItemData(itemID)
			end
		end
	end

	local npcCount = 0
	for _ in pairs(npcsTouched) do npcCount = npcCount + 1 end
	return npcCount, itemsAdded
end

-------------------------------------------------------------------------------
-- Text window (used for both export and import)
-------------------------------------------------------------------------------

local textFrame

local function CreateTextFrame()
	local f = CreateFrame("Frame", "AtlasLootForeverTextFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(620, 440)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetFrameStrata("DIALOG")
	tinsert(UISpecialFrames, "AtlasLootForeverTextFrame")

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.title:SetPoint("TOP", f, "TOP", 0, -6)

	f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -30)
	f.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -30)
	f.hint:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", "AtlasLootForeverTextScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -50)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 44)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(560)
	edit:SetAutoFocus(false)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(edit)
	f.edit = edit

	f.action = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.action:SetSize(140, 22)
	f.action:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)

	return f
end

function ns.ShowExport(format)
	if not ns.db then ns.InitDB() end
	textFrame = textFrame or CreateTextFrame()

	local text = (format == "lua") and ns.ExportLua() or ns.ExportLines()
	textFrame.title:SetText("AtlasLootForever - export (" .. (format or "lines") .. ")")
	textFrame.hint:SetText("Click the text, Ctrl+A to select all, Ctrl+C to copy.")
	textFrame.edit:SetText(text)
	textFrame.edit:HighlightText()
	textFrame.edit:SetFocus()

	textFrame.action:SetText("Close")
	textFrame.action:SetScript("OnClick", function() textFrame:Hide() end)
	textFrame:Show()
end

function ns.ShowImport()
	if not ns.db then ns.InitDB() end
	textFrame = textFrame or CreateTextFrame()

	textFrame.title:SetText("AtlasLootForever - import")
	textFrame.hint:SetText("Paste someone else's ALF1 lines here and click Import. The data is merged into yours.")
	textFrame.edit:SetText("")
	textFrame.edit:SetFocus()

	textFrame.action:SetText("Import")
	textFrame.action:SetScript("OnClick", function()
		local npcs, items = ns.ImportLines(textFrame.edit:GetText())
		ns.Print(string.format("imported: %d NPCs, %d new items.", npcs, items))
		textFrame:Hide()
		if ns.RefreshUI then ns.RefreshUI() end
	end)
	textFrame:Show()
end

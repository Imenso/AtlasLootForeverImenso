-- AtlasLootForeverImenso :: Validate.lua
-- Checks the reference loot against the client you are actually running.
--
-- Why this exists: WoW: Forever rewrote parts of the classic dungeon tables,
-- and the site the reference comes from says so itself - only the drops seen
-- in the beta carry Forever tooltips, "the others Classic's for now". So every
-- classic row in Reference.lua is a claim, not a fact.
--
-- Your own client is the one source that cannot be out of date: ask it about
-- an item id and it either answers with the item Forever currently has under
-- that id, or it never answers because the id is not in the game any more.
-- That is what this file does, and it turns each reference row into one of:
--
--   forever  the id is one Forever added (>= 200000) - new by construction
--   looted   you saw it drop yourself, so it is real on this client
--   known    the client has the item and the name matches the reference
--   renamed  the client has that id under a different name
--   missing  the client stayed silent twice - the id is probably gone
--
-- The client answers asynchronously, so this runs as a queue: it asks for a
-- batch of ids per frame, waits for the answers, then asks a second time for
-- whatever stayed silent before calling anything missing.

local ADDON, ns = ...

local GetItemInfoFn = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local RequestItem = C_Item and C_Item.RequestLoadItemDataByID

local BATCH = 25 -- ids asked per frame
local GRACE = 3.0 -- seconds of silence that end a pass
local MAX_LIST = 12 -- lines listed per problem category before summarising

local frame = CreateFrame("Frame")

local queue, cursor = {}, 1
local waiting = {} -- [itemID] = true, asked and not answered yet
local pass = 0
local running = false
local scopeName, scopeLabel
local lastAnswer = 0
local startedAt = 0

-------------------------------------------------------------------------------
-- What you have actually looted
-------------------------------------------------------------------------------

local lootedSet, lootedDirty = {}, true

function ns.InvalidateLooted()
	lootedDirty = true
end

function ns.LootedItems()
	if not lootedDirty then return lootedSet end
	wipe(lootedSet)
	local db = ns.db
	if db then
		for _, npc in pairs(db.npcs) do
			for itemID, item in pairs(npc.items) do
				-- a guessed attribution still proves the item dropped
				if item then lootedSet[itemID] = true end
			end
		end
	end
	lootedDirty = false
	return lootedSet
end

function ns.HasLooted(itemID)
	return ns.LootedItems()[itemID] == true
end

-------------------------------------------------------------------------------
-- Status of a single reference item
-------------------------------------------------------------------------------

ns.STATUS_TAG = {
	forever = { tag = "NEW", color = "ff40d040", text = "added by Forever" },
	looted = { tag = "OK", color = "ff40d040", text = "you looted it" },
	known = { tag = "?", color = "ff9d9d9d", text = "Classic data, still unconfirmed" },
	renamed = { tag = "~", color = "ffffd100", text = "renamed by Forever" },
	missing = { tag = "!", color = "ffff4040", text = "your client does not know this id" },
	unchecked = { tag = "", color = "ff6a6a6a", text = "not validated yet" },
}

-- Priority: what you saw with your own eyes beats anything else.
function ns.ItemStatus(itemID)
	if not itemID then return "unchecked" end
	if ns.HasLooted(itemID) then return "looted" end
	if ns.IsForeverItem and ns.IsForeverItem(itemID) then return "forever" end

	local db = ns.db
	local record = db and db.validation and db.validation[itemID]
	if record and record.s then return record.s, record.n end

	return "unchecked"
end

-- Short coloured marker for the browser and the tooltip
function ns.StatusMarker(itemID)
	local status, other = ns.ItemStatus(itemID)
	local info = ns.STATUS_TAG[status]
	if not info or info.tag == "" then return "", status, other end
	return string.format("|c%s%s|r", info.color, info.tag), status, other
end

-------------------------------------------------------------------------------
-- The queue
-------------------------------------------------------------------------------

local function Store(itemID, status, clientName, quality)
	local db = ns.db
	if not db then return end
	db.validation = db.validation or {}
	db.validation[itemID] = {
		s = status,
		n = (status == "renamed") and clientName or nil,
		q = quality,
		t = time(),
	}
end

-- Returns true when the client answered.
local function Ask(itemID)
	local ok, name, _, quality = pcall(GetItemInfoFn, itemID)
	if ok and name then
		waiting[itemID] = nil
		local ref = ns.RefAllItems and ns.RefAllItems[itemID]
		local expected = ref and ref.name
		if expected and name ~= expected then
			Store(itemID, "renamed", name, quality)
		else
			Store(itemID, "known", name, quality)
		end
		return true
	end

	waiting[itemID] = true
	if RequestItem then pcall(RequestItem, itemID) end
	return false
end

-- Called from Core's GET_ITEM_INFO_RECEIVED path
function ns.ValidateOnItemInfo(itemID)
	if not running or not itemID then return end
	if waiting[itemID] then
		lastAnswer = GetTime()
		Ask(itemID)
	end
end

local function BuildQueue(dungeon)
	wipe(queue)
	wipe(waiting)
	cursor = 1

	local all = ns.RefAllItems
	if not all then return 0 end

	for itemID, ref in pairs(all) do
		if not dungeon or ref.dungeon == dungeon then
			-- ids Forever added need no checking, they are new by construction
			if not (ns.IsForeverItem and ns.IsForeverItem(itemID)) then
				queue[#queue + 1] = itemID
			end
		end
	end
	table.sort(queue)
	return #queue
end

local function Finish()
	running = false
	frame:SetScript("OnUpdate", nil)

	local left = 0
	for itemID in pairs(waiting) do
		Store(itemID, "missing")
		left = left + 1
	end
	wipe(waiting)

	ns.Print(string.format("validation of %s finished in %.0fs - %d id(s) the client never answered for.",
		scopeLabel or "the reference", GetTime() - startedAt, left))
	ns.ValidationReport(scopeName)

	if ns.RefreshUI then pcall(ns.RefreshUI) end
end

local function OnUpdate()
	if not running then return end

	local asked = 0
	while cursor <= #queue and asked < BATCH do
		local itemID = queue[cursor]
		cursor = cursor + 1
		asked = asked + 1
		if Ask(itemID) then lastAnswer = GetTime() end
	end

	if cursor > #queue then
		local silent = next(waiting) ~= nil
		if not silent then
			Finish()
		elseif (GetTime() - lastAnswer) > GRACE then
			if pass < 2 then
				-- second round: ask once more for everything that stayed silent
				pass = pass + 1
				wipe(queue)
				for itemID in pairs(waiting) do queue[#queue + 1] = itemID end
				table.sort(queue)
				cursor = 1
				lastAnswer = GetTime()
				ns.Print(string.format("asking the client a second time about %d id(s)...", #queue))
			else
				Finish()
			end
		end
	end
end

function ns.StartValidation(dungeon)
	if running then
		ns.Print("a validation is already running.")
		return
	end
	if not ns.RefAllItems then
		ns.Print("the reference did not load.")
		return
	end

	ns.InvalidateLooted()

	local total = BuildQueue(dungeon)
	scopeName = dungeon
	scopeLabel = dungeon or "all dungeons"

	if total == 0 then
		if dungeon then
			ns.Print(string.format("no reference item to check in %s.", dungeon))
		else
			ns.Print("no reference item to check.")
		end
		return
	end

	local db = ns.db
	if db then db.validation = db.validation or {} end

	pass = 1
	running = true
	startedAt = GetTime()
	lastAnswer = GetTime()
	ns.MarkAction("validating the reference")
	ns.Print(string.format("checking %d id(s) of %s against your client, hold on...", total, scopeLabel))
	frame:SetScript("OnUpdate", OnUpdate)
end

ns.validateFrame = frame

function ns.IsValidating()
	return running
end

-------------------------------------------------------------------------------
-- Report
-------------------------------------------------------------------------------

local function CountDungeon(dungeon)
	local counts = { forever = 0, looted = 0, known = 0, renamed = 0, missing = 0, unchecked = 0 }
	local renamed, missing = {}, {}

	local byBoss = ns.RefIndex and ns.RefIndex[dungeon]
	if not byBoss then return counts, renamed, missing, 0 end

	local seen, total = {}, 0
	for boss, items in pairs(byBoss) do
		for _, item in ipairs(items) do
			if not seen[item.id] then
				seen[item.id] = true
				total = total + 1
				local status, clientName = ns.ItemStatus(item.id)
				counts[status] = (counts[status] or 0) + 1
				if status == "renamed" then
					renamed[#renamed + 1] = { id = item.id, was = item.name, now = clientName, boss = boss }
				elseif status == "missing" then
					missing[#missing + 1] = { id = item.id, was = item.name, boss = boss }
				end
			end
		end
	end

	table.sort(renamed, function(a, b) return a.id < b.id end)
	table.sort(missing, function(a, b) return a.id < b.id end)
	return counts, renamed, missing, total
end

ns.CountDungeonStatus = CountDungeon

local function PrintDungeon(dungeon, verbose)
	local counts, renamed, missing, total = CountDungeon(dungeon)
	if total == 0 then return false end

	ns.Print(string.format("|cffffd100%s|r - %d reference items", dungeon, total))

	if counts.forever > 0 then
		ns.Print(string.format("   |cff40d040%d|r added by Forever (new ids)", counts.forever))
	end
	if counts.looted > 0 then
		ns.Print(string.format("   |cff40d040%d|r confirmed by your own drops", counts.looted))
	end
	if counts.known > 0 then
		ns.Print(string.format("   |cff9d9d9d%d|r still in the client, Classic data, unconfirmed", counts.known))
	end
	if counts.unchecked > 0 then
		ns.Print(string.format("   |cff6a6a6a%d|r not validated yet", counts.unchecked))
	end
	if counts.renamed > 0 then
		ns.Print(string.format("   |cffffd100%d renamed by Forever|r", counts.renamed))
		if verbose then
			for i = 1, math.min(#renamed, MAX_LIST) do
				local r = renamed[i]
				ns.Print(string.format("      %d  %s |cffffd100->|r %s   (%s)", r.id, r.was, r.now, r.boss))
			end
			if #renamed > MAX_LIST then
				ns.Print(string.format("      ... and %d more", #renamed - MAX_LIST))
			end
		end
	end
	if counts.missing > 0 then
		ns.Print(string.format("   |cffff4040%d the client does not know - probably removed|r", counts.missing))
		if verbose then
			for i = 1, math.min(#missing, MAX_LIST) do
				local m = missing[i]
				ns.Print(string.format("      %d  %s   (%s)", m.id, m.was, m.boss))
			end
			if #missing > MAX_LIST then
				ns.Print(string.format("      ... and %d more", #missing - MAX_LIST))
			end
		end
	end

	return true
end

-- dungeon = nil prints every dungeon as one line block; naming one dungeon
-- also lists the renamed and missing ids.
function ns.ValidationReport(dungeon)
	ns.InvalidateLooted()

	if dungeon then
		if not PrintDungeon(dungeon, true) then
			ns.Print(string.format("no reference data for %s.", dungeon))
		end
		return
	end

	local names = {}
	for name in pairs(ns.RefIndex or {}) do names[#names + 1] = name end
	table.sort(names)

	local grand = { forever = 0, looted = 0, known = 0, renamed = 0, missing = 0, unchecked = 0 }
	local total = 0

	for _, name in ipairs(names) do
		local counts, _, _, n = CountDungeon(name)
		total = total + n
		for key, value in pairs(counts) do grand[key] = (grand[key] or 0) + value end
	end

	ns.Print(string.format("|cffffd100reference validation|r - %d items across %d dungeons (%s, %s)",
		total, #names, ns.RefSource or "?", ns.RefDate or "?"))
	ns.Print(string.format("   |cff40d040%d|r added by Forever    |cff40d040%d|r confirmed by your drops",
		grand.forever, grand.looted))
	ns.Print(string.format("   |cff9d9d9d%d|r Classic data the client still has    |cff6a6a6a%d|r not validated yet",
		grand.known, grand.unchecked))
	ns.Print(string.format("   |cffffd100%d|r renamed    |cffff4040%d|r missing from the client",
		grand.renamed, grand.missing))

	if grand.renamed > 0 or grand.missing > 0 then
		ns.Print("per dungeon:")
		for _, name in ipairs(names) do
			local counts = CountDungeon(name)
			if counts.renamed > 0 or counts.missing > 0 then
				ns.Print(string.format("   %s: |cffffd100%d|r renamed, |cffff4040%d|r missing  (/alfi validate %s for the list)",
					name, counts.renamed, counts.missing, name))
			end
		end
	end

	if grand.unchecked > 0 then
		ns.Print("run |cffffd100/alfi validate|r inside the game to check the rest against your client.")
	end
end

-- Name of the dungeon you are standing in, when it is one the reference knows
function ns.CurrentDungeon()
	local name, instanceType = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return nil end
	if ns.RefIndex and ns.RefIndex[name] then return name end
	return name
end

-- Resolves what the player typed to a dungeon name, case-insensitively and by
-- prefix, so "/alfi validate strat" finds Stratholme.
function ns.ResolveDungeon(text)
	if not text or text == "" then return nil end
	local needle = text:lower()

	for name in pairs(ns.RefIndex or {}) do
		if name:lower() == needle then return name end
	end

	local matches = {}
	for name in pairs(ns.RefIndex or {}) do
		if name:lower():find(needle, 1, true) then matches[#matches + 1] = name end
	end
	table.sort(matches)

	if #matches == 1 then return matches[1] end
	return nil, matches
end

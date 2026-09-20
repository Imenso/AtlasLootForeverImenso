-- AtlasLootForever :: Diagnostics.lua
-- Captures ADDON_ACTION_FORBIDDEN / ADDON_ACTION_BLOCKED and reports EXACTLY
-- which function was blocked and when, since the game popup never says.

local ADDON, ns = ...

ns.lastAction = "loading"

function ns.MarkAction(what)
	ns.lastAction = what
end

ns.blocked = {}

local function Record(event, addonName, funcName)
	local entry = {
		event = event,
		addon = addonName or "?",
		func = funcName or "?",
		context = ns.lastAction or "?",
		when = date("%H:%M:%S"),
	}
	tinsert(ns.blocked, entry)
	if #ns.blocked > 20 then
		table.remove(ns.blocked, 1)
	end

	if addonName == ADDON then
		ns.Print(string.format(
			"|cffff4040BLOCKED|r function |cffffd100%s|r during |cffffd100%s|r (%s). Run /alf blocked and send me this.",
			entry.func, entry.context, event
		))
	end
	return entry
end

function ns.DumpBlocked()
	ns.Print(string.format("secret values ignored this session: %d", ns.secretHits or 0))

	if #ns.blocked == 0 then
		ns.Print("no blocks recorded since login.")
		return
	end
	ns.Print("blocks recorded (most recent last):")
	for _, entry in ipairs(ns.blocked) do
		ns.Print(string.format("  %s  %s  addon=%s  func=%s  context=%s",
			entry.when, entry.event, entry.addon, entry.func, entry.context))
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:SetScript("OnEvent", function(_, event, addonName, funcName)
	Record(event, addonName, funcName)
end)

ns.diagnosticsFrame = frame
ns.RecordBlocked = Record

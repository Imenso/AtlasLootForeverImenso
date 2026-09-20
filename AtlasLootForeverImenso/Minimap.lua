-- AtlasLootForeverImenso :: Minimap.lua
-- Minimap button: left click opens the browser, right click exports,
-- dragging moves it around the edge. The position is saved.

local ADDON, ns = ...

local button

-- The default minimap is 140px wide, so a fixed radius of 80 only works there.
-- Deriving it from the real width keeps the button on the edge whatever the
-- minimap size or UI scale is.
local function Radius()
	local ok, width = pcall(function() return Minimap and Minimap:GetWidth() end)
	if not ok or not width or width <= 0 then return 80 end
	return (width / 2) + 10
end

local function SavedAngle()
	local db = ns.db
	if db and db.settings and db.settings.minimapAngle then
		return db.settings.minimapAngle
	end
	return 210
end

local function UpdatePosition()
	if not button then return end
	local angle = math.rad(SavedAngle())
	local radius = Radius()
	local x = math.cos(angle) * radius
	local y = math.sin(angle) * radius
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

ns.UpdateMinimapPosition = UpdatePosition

-- A door for ImensoTweaks.
--
-- This client hands addons an empty saved-variables table on /reload, so the
-- angle you drag the button to is gone by the next session. ImensoTweaks keeps
-- a copy and puts it back - but it loads AFTER this addon (A sorts before I),
-- so it cannot do that the way it does for the others, before they read their
-- own settings. These two functions are how it reaches in afterwards instead:
-- it reads the angle at logout and sets it again at login.
function AtlasLootForeverImenso_GetMinimapAngle()
	local db = ns.db
	if db and db.settings and type(db.settings.minimapAngle) == "number" then
		return db.settings.minimapAngle
	end
	return nil
end

function AtlasLootForeverImenso_SetMinimapAngle(angle)
	if type(angle) ~= "number" then return false end
	if not ns.db or not ns.db.settings then return false end
	ns.db.settings.minimapAngle = angle
	UpdatePosition()
	return true
end

local function OnDragUpdate()
	local cx, cy = Minimap:GetCenter()
	if not cx then return end

	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not scale or scale == 0 then return end
	px, py = px / scale, py / scale

	local angle = math.deg(math.atan2(py - cy, px - cx))
	if ns.db and ns.db.settings then
		ns.db.settings.minimapAngle = angle
	end
	UpdatePosition()
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("AtlasLoot|cff00ff00Forever|r")

	local seen, total, extra = ns.GlobalCoverage()
	GameTooltip:AddLine(string.format("|cffffffff%d|r of |cffffffff%d|r reference items seen", seen, total), 0.8, 0.8, 0.8)
	if extra > 0 then
		GameTooltip:AddLine(string.format("|cff40d040%d|r item(s) outside the reference", extra), 0.8, 0.8, 0.8)
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Click: open the browser", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Right click: export", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Drag: move around the edge", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function ns.CreateMinimapButton()
	if button then return button end
	if not Minimap then return nil end

	button = CreateFrame("Button", "AtlasLootForeverImensoMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetMovable(true)

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(19, 19)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Green")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("CENTER", button, "CENTER", -1, 1)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

	button:SetScript("OnEnter", function(self) pcall(ShowTooltip, self) end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", OnDragUpdate)
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.ShowExport("linha")
		else
			ns.ToggleUI()
		end
	end)

	button:SetScript("OnShow", UpdatePosition)

	UpdatePosition()
	return button
end

function ns.ToggleMinimapButton()
	if not ns.db then return end
	local hidden = not ns.db.settings.minimapHide
	ns.db.settings.minimapHide = hidden

	if not button then ns.CreateMinimapButton() end
	if button then
		if hidden then button:Hide() else button:Show() end
	end

	ns.Print(hidden and "minimap button hidden (/alf minimap to bring it back)"
	                or "minimap button visible")
end

function ns.SetupMinimap()
	if not ns.db then return end
	ns.CreateMinimapButton()
	if button and ns.db.settings.minimapHide then
		button:Hide()
	end
end

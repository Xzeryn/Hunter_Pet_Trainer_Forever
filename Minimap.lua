local HPT = HunterPetTrainer

-- Minimap button: left-click toggles the planner, right-click the dev window.
-- Drag to move around the minimap; /hpt minimap hides or shows it.

local DEFAULT_ANGLE = 215

local function Settings()
	local db = HPT:GetDB()
	db.minimap = db.minimap or { angle = DEFAULT_ANGLE, hide = false }
	return db.minimap
end

local function Place(btn)
	local angle = math.rad(Settings().angle or DEFAULT_ANGLE)
	local radius = (Minimap:GetWidth() / 2) + 5
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate(btn)
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	Settings().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	Place(btn)
end

function HPT:CreateMinimapButton()
	if self.minimapButton then
		return self.minimapButton
	end
	local btn = CreateFrame("Button", "HunterPetTrainerMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 7, -5)
	icon:SetTexture(self.ICON)
	if btn.CreateMaskTexture then
		local mask = btn:CreateMaskTexture()
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(icon)
		icon:AddMaskTexture(mask)
	end
	btn.icon = icon

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			HPT:ToggleDevWindow()
		else
			HPT:ToggleUI()
		end
	end)
	btn:SetScript("OnDragStart", function(b)
		b:SetScript("OnUpdate", OnDragUpdate)
	end)
	btn:SetScript("OnDragStop", function(b)
		b:SetScript("OnUpdate", nil)
	end)
	btn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:AddLine(HPT.ADDON_NAME)
		GameTooltip:AddLine("Left-click: planner", 1, 1, 1)
		GameTooltip:AddLine("Right-click: report window", 1, 1, 1)
		GameTooltip:AddLine("Drag: move", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", GameTooltip_Hide)

	self.minimapButton = btn
	Place(btn)
	btn:SetShown(not Settings().hide)
	return btn
end

function HPT:ToggleMinimapButton()
	local s = Settings()
	s.hide = not s.hide
	self:CreateMinimapButton():SetShown(not s.hide)
	self:Echo("Minimap button %s.", s.hide and "hidden" or "shown")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	HPT:CreateMinimapButton()
end)

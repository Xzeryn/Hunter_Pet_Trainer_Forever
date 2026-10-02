local HPT = HunterPetTrainer
local D = HunterPetTrainerData

local ROW_HEIGHT = 22
local SECTION_HEIGHT = 20
local FRAME_WIDTH = 580
local CONTENT_WIDTH = 560
local ICON_SIZE = 18
local BUTTON_W = 24
local BUTTON_STEP = 25
local BUTTONS_X = 240
local RANK_LABEL_W = 54
local NAME_WIDTH = BUTTONS_X - RANK_LABEL_W - ICON_SIZE - 14
local MAX_RANK_COLS = 11
local TP_HEADER_CENTER_X = BUTTONS_X + (MAX_RANK_COLS * BUTTON_STEP) / 2

local DROP_MENU = CreateFrame("Frame", "HunterPetTrainerDropMenu", UIParent, "UIDropDownMenuTemplate")

local function FlatBackdrop()
	return {
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	}
end

-- EllesmereUI skinning removes the backdrop; hover borders then do nothing.
local function SetFlatBorder(btn, shade)
	if btn.backdropInfo then
		btn:SetBackdropBorderColor(shade, shade, shade, 1)
	end
end

local function StyleFlatButton(btn, width, height)
	btn:SetSize(width, height)
	btn:SetBackdrop(FlatBackdrop())
	btn:SetBackdropColor(0.14, 0.14, 0.14, 0.98)
	btn:SetBackdropBorderColor(0.38, 0.38, 0.38, 1)
	btn:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local ht = btn:GetHighlightTexture()
	if ht then
		ht:SetVertexColor(1, 1, 1, 0.08)
	end
	btn:SetScript("OnEnter", function(self)
		SetFlatBorder(self, 0.55)
	end)
	btn:SetScript("OnLeave", function(self)
		SetFlatBorder(self, 0.38)
	end)
end

local function CreateFlatButton(parent, width, height, label)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	StyleFlatButton(btn, width, height)
	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("CENTER", 0, 0)
	fs:SetText(label or "")
	btn.label = fs
	btn:SetFontString(fs)
	return btn
end

local function CreateFlatDropdown(parent, width, height)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	StyleFlatButton(btn, width, height)
	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", 8, 0)
	fs:SetPoint("RIGHT", -20, 0)
	fs:SetJustifyH("LEFT")
	fs:SetText("")
	btn.text = fs
	-- Texture arrow (Unicode ▼ shows as missing-glyph diamond-? on many WoW fonts)
	local arrow = btn:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(10, 10)
	arrow:SetPoint("RIGHT", -5, -1)
	arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
	arrow:SetTexCoord(0.2, 0.8, 0.25, 0.75)
	arrow:SetVertexColor(0.75, 0.75, 0.75)
	btn.arrow = arrow
	function btn:SetText(value)
		self.text:SetText(value or "")
	end
	function btn:GetText()
		return self.text:GetText()
	end
	return btn
end

local function StyleModernScrollBar(scroll)
	local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
	if not bar or bar.hptStyled then
		return
	end
	bar.hptStyled = true

	local up = _G[bar:GetName() .. "ScrollUpButton"]
	local down = _G[bar:GetName() .. "ScrollDownButton"]
	local thumb = bar:GetThumbTexture()

	if up then
		up:SetSize(14, 14)
		up:ClearAllPoints()
		up:SetPoint("TOP", bar, "TOP", 0, 0)
		for _, r in ipairs({ up:GetRegions() }) do
			if r.SetVertexColor then r:SetVertexColor(0.45, 0.45, 0.45) end
		end
	end
	if down then
		down:SetSize(14, 14)
		down:ClearAllPoints()
		down:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
		for _, r in ipairs({ down:GetRegions() }) do
			if r.SetVertexColor then r:SetVertexColor(0.45, 0.45, 0.45) end
		end
	end

	bar:SetWidth(10)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, -16)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 16)

	-- Hide noisy default track art
	for _, region in ipairs({ bar:GetRegions() }) do
		if region:IsObjectType("Texture") and region ~= thumb then
			region:SetTexture(nil)
			region:SetColorTexture(0.12, 0.12, 0.12, 0.9)
		end
	end

	if not bar.hptTrack then
		local track = bar:CreateTexture(nil, "BACKGROUND")
		track:SetPoint("TOPLEFT", 1, -14)
		track:SetPoint("BOTTOMRIGHT", -1, 14)
		track:SetColorTexture(0.12, 0.12, 0.12, 0.95)
		bar.hptTrack = track
	end

	if thumb then
		thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
		thumb:SetVertexColor(0.4, 0.4, 0.4, 1)
		thumb:SetWidth(8)
	else
		bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
		local t = bar:GetThumbTexture()
		if t then
			t:SetVertexColor(0.4, 0.4, 0.4, 1)
			t:SetWidth(8)
		end
	end
end

local function OpenEasyMenu(anchor, menuList)
	DROP_MENU.displayMode = "MENU"
	DROP_MENU.HPT_menuList = menuList
	UIDropDownMenu_Initialize(DROP_MENU, function(frame, level, list)
		level = level or 1
		if level == 1 then
			list = frame.HPT_menuList
		elseif type(list) ~= "table" then
			-- Some Classic builds pass the submenu via MENU_VALUE instead of list
			local v = UIDROPDOWNMENU_MENU_VALUE
			if type(v) == "table" and v[1] and v[1].text then
				list = v
			else
				list = frame.HPT_menuList
			end
		end
		if type(list) ~= "table" then
			return
		end
		for index = 1, #list do
			local item = list[index]
			if item and item.text then
				local info = UIDropDownMenu_CreateInfo()
				info.text = item.text
				info.isTitle = item.isTitle
				info.disabled = item.disabled
				info.notCheckable = item.notCheckable
				if item.isTitle or item.hasArrow then
					info.notCheckable = true
				end
				info.isNotRadio = item.isNotRadio
				info.checked = item.checked
				info.hasArrow = item.hasArrow
				info.menuList = item.menuList
				-- Submenu payload for Classic dropdown opener
				info.value = item.menuList or item.value
				info.func = item.func
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end, "MENU", nil, menuList)
	ToggleDropDownMenu(1, nil, DROP_MENU, anchor, 0, 0, menuList)
end

local function BuildNewTemplateFamilyMenu()
	local families = {}
	for name in pairs(D.Families) do
		table.insert(families, name)
	end
	table.sort(families)
	local menu = {
		{ text = "Select family", isTitle = true, notCheckable = true },
	}
	for _, famName in ipairs(families) do
		local fam = famName
		table.insert(menu, {
			text = fam,
			notCheckable = true,
			func = function()
				CloseDropDownMenus()
				StaticPopup_Show("HPT_NEW_TEMPLATE", fam, nil, fam)
			end,
		})
	end
	return menu
end

function HPT:ToggleUI()
	if not self.frame then
		self:CreateUI()
	end
	if self:IsBeastTrainingOpen() and self.ShowTrainerOverlay then
		if self:IsTrainerOverlayShown() then
			self.dockDismissed = true
			self:HideTrainerOverlay()
		else
			self.dockDismissed = false
			self:ShowTrainerOverlay()
		end
		return
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
		self:UpdateUI()
	end
end

function HPT:CreateUI()
	if self.frame then
		return
	end

	local f = CreateFrame("Frame", "HunterPetTrainerFrame", UIParent, "BackdropTemplate")
	f:SetWidth(FRAME_WIDTH)
	f:SetHeight(580)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	f:Hide()
	tinsert(UISpecialFrames, "HunterPetTrainerFrame")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Hunter Pet Trainer")
	f.title = title
	local titleIcon = f:CreateTexture(nil, "OVERLAY")
	titleIcon:SetSize(22, 22)
	titleIcon:SetPoint("RIGHT", title, "LEFT", -6, 0)
	titleIcon:SetTexture(HPT.ICON)
	f.titleIcon = titleIcon

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	f.closeBtn = close

	local familyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	familyLabel:SetPoint("TOPLEFT", 20, -42)
	familyLabel:SetText("Family")
	f.familyLabel = familyLabel

	local familyList = {}
	for name in pairs(D.Families) do
		table.insert(familyList, name)
	end
	table.sort(familyList)

	local familyDrop = CreateFlatDropdown(f, 140, 22)
	familyDrop:SetPoint("LEFT", familyLabel, "RIGHT", 8, 0)
	familyDrop:SetText(self:GetActiveTemplate().family)
	familyDrop:SetScript("OnClick", function(self)
		if HPT:IsCurrentPetActive() then
			return
		end
		local menu = {}
		for _, name in ipairs(familyList) do
			local famName = name
			table.insert(menu, {
				text = famName,
				checked = (HPT:GetActiveTemplate().family == famName),
				func = function()
					local t = HPT:GetActiveTemplate()
					if t.family == famName then
						return
					end
					local applyFamily = function()
						HPT:SetTemplateFamily(t, famName)
						self:SetText(famName)
					end
					if HPT:TemplateHasPlannedRanks(t) then
						StaticPopup_Show("HPT_CHANGE_FAMILY", famName, nil, famName)
					else
						applyFamily()
					end
				end,
			})
		end
		OpenEasyMenu(self, menu)
	end)
	f.familyDrop = familyDrop

	local pointsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pointsText:SetPoint("TOPRIGHT", -40, -48)
	pointsText:SetJustifyH("RIGHT")
	f.pointsText = pointsText

	local petText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	petText:SetPoint("TOPLEFT", 20, -68)
	petText:SetJustifyH("LEFT")
	f.petText = petText

	local templateText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	templateText:SetPoint("TOPLEFT", 20, -84)
	f.templateText = templateText

	-- Theory-craft calculator (level / loyalty / TP budget)
	local calc = CreateFrame("Frame", nil, f, "BackdropTemplate")
	calc:SetHeight(44)
	calc:SetPoint("TOPLEFT", 16, -100)
	calc:SetPoint("TOPRIGHT", -36, -100)
	calc:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	calc:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
	calc:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	f.calcBar = calc

	local function MakeStepper(parent, label, valueWidth)
		local wrap = CreateFrame("Frame", nil, parent)
		wrap.valueWidth = valueWidth or 36
		local nameFS = wrap:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		nameFS:SetPoint("TOPLEFT", 0, 0)
		nameFS:SetText(label)
		wrap.label = nameFS
		local minus = CreateFlatButton(wrap, 18, 18, "-")
		minus:SetPoint("BOTTOMLEFT", 0, 0)
		local valueFS = wrap:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		valueFS:SetPoint("LEFT", minus, "RIGHT", 3, 0)
		valueFS:SetWidth(wrap.valueWidth)
		valueFS:SetJustifyH("CENTER")
		valueFS:SetWordWrap(false)
		wrap.value = valueFS
		local plus = CreateFlatButton(wrap, 18, 18, "+")
		plus:SetPoint("LEFT", valueFS, "RIGHT", 3, 0)
		wrap.minus = minus
		wrap.plus = plus
		wrap:SetSize(18 + 3 + wrap.valueWidth + 3 + 18, 36)
		function wrap:SetSteppersVisible(visible)
			if visible then
				self.minus:Show()
				self.plus:Show()
				self.value:ClearAllPoints()
				self.value:SetPoint("LEFT", self.minus, "RIGHT", 3, 0)
				self.value:SetWidth(self.valueWidth)
				self.value:SetJustifyH("CENTER")
				self:SetWidth(18 + 3 + self.valueWidth + 3 + 18)
			else
				self.minus:Hide()
				self.plus:Hide()
				self.value:ClearAllPoints()
				self.value:SetPoint("BOTTOMLEFT", 0, 1)
				self.value:SetWidth(self.valueWidth + 42)
				self.value:SetJustifyH("LEFT")
				self:SetWidth(self.valueWidth + 42)
			end
		end
		return wrap
	end

	local levelStep = MakeStepper(calc, "PET LEVEL", 28)
	levelStep:SetPoint("LEFT", 8, 0)
	f.levelStep = levelStep

	local loyaltyStep = MakeStepper(calc, "LOYALTY", 110)
	loyaltyStep:SetPoint("LEFT", levelStep, "RIGHT", 16, 0)
	f.loyaltyStep = loyaltyStep

	local tpLabel = calc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	tpLabel:SetPoint("TOPRIGHT", -10, -2)
	tpLabel:SetText("TRAINING POINTS")
	f.tpLabel = tpLabel

	local tpValue = calc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tpValue:SetPoint("BOTTOMRIGHT", -10, 6)
	tpValue:SetJustifyH("RIGHT")
	f.tpValue = tpValue

	local tpBar = CreateFrame("StatusBar", nil, calc)
	tpBar:SetSize(120, 10)
	tpBar:SetPoint("RIGHT", tpValue, "LEFT", -8, 0)
	tpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	tpBar:SetStatusBarColor(0.3, 0.75, 0.3, 1)
	tpBar:SetMinMaxValues(0, 1)
	tpBar:SetValue(0)
	local tpBg = tpBar:CreateTexture(nil, "BACKGROUND")
	tpBg:SetAllPoints()
	tpBg:SetColorTexture(0.15, 0.15, 0.15, 1)
	f.tpBar = tpBar

	local tpHit = CreateFrame("Frame", nil, calc)
	tpHit:SetPoint("TOPLEFT", tpBar, "TOPLEFT", 0, 4)
	tpHit:SetPoint("BOTTOMRIGHT", tpValue, "BOTTOMRIGHT", 0, -4)
	tpHit:EnableMouse(true)
	tpHit:SetScript("OnEnter", function(self)
		if not f.tpNote then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Training points")
		GameTooltip:AddLine(f.tpNote, 0.9, 0.9, 0.9, true)
		GameTooltip:Show()
	end)
	tpHit:SetScript("OnLeave", GameTooltip_Hide)

	levelStep.minus:SetScript("OnClick", function()
		local t = HPT:GetActiveTemplate()
		if t.isCurrentPet then return end
		HPT:SetTheoryLevel((t.theoryLevel or HPT.MAX_LEVEL) - 1)
	end)
	levelStep.plus:SetScript("OnClick", function()
		local t = HPT:GetActiveTemplate()
		if t.isCurrentPet then return end
		HPT:SetTheoryLevel((t.theoryLevel or HPT.MAX_LEVEL) + 1)
	end)
	loyaltyStep.minus:SetScript("OnClick", function()
		local t = HPT:GetActiveTemplate()
		if t.isCurrentPet then return end
		HPT:SetTheoryLoyalty((t.theoryLoyalty or 6) - 1)
	end)
	loyaltyStep.plus:SetScript("OnClick", function()
		local t = HPT:GetActiveTemplate()
		if t.isCurrentPet then return end
		HPT:SetTheoryLoyalty((t.theoryLoyalty or 6) + 1)
	end)

	local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:SetPoint("TOPLEFT", 20, -148)
	statusText:SetWidth(FRAME_WIDTH - 40)
	statusText:SetJustifyH("LEFT")
	f.statusText = statusText

	-- Scrollable ability list
	local scroll = CreateFrame("ScrollFrame", "HunterPetTrainerScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -168)
	scroll:SetPoint("BOTTOMRIGHT", -36, 70)
	f.scroll = scroll
	StyleModernScrollBar(scroll)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(CONTENT_WIDTH)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	f.content = content
	f.rows = {}
	f.contentWidth = CONTENT_WIDTH
	f.standaloneBackdrop = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	}

	local function MakeRankButton(parent, ability, rank, cost)
		local b = CreateFrame("Button", nil, parent)
		b:SetWidth(BUTTON_W)
		b:SetHeight(18)
		b:EnableMouse(true)
		b:RegisterForClicks("LeftButtonUp")
		b.ability = ability
		b.rank = rank
		b:SetScript("OnClick", function(self)
			local t = HPT:GetActiveTemplate()
			if HPT:IsInfoOnlyAbility(ability) or not HPT:AbilityAvailableForFamily(ability, t.family) then
				return
			end
			if t.ranks[ability] == rank then
				t.ranks[ability] = 0
			else
				t.ranks[ability] = rank
			end
			HPT:UpdateUI()
			if HPT.SyncAssistToPlan then
				HPT:SyncAssistToPlan()
			end
		end)
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
		b.bg = bg
		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("CENTER")
		fs:SetText(tostring(cost or rank))
		b.fs = fs
		return b
	end

	local function MakeSectionHeader(title)
		local h = CreateFrame("Frame", nil, content)
		h:SetWidth(CONTENT_WIDTH)
		h:SetHeight(SECTION_HEIGHT)
		local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("LEFT", 4, 0)
		fs:SetText(title)
		fs:SetTextColor(1, 1, 1)
		h.title = fs
		local costHint = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		costHint:SetPoint("CENTER", h, "LEFT", TP_HEADER_CENTER_X, 0)
		costHint:SetText("TRAINING POINTS COSTS")
		h.costHint = costHint
		h:Hide()
		return h
	end

	f.sectionHeaders = {
		active = MakeSectionHeader("Active"),
		passive = MakeSectionHeader("Passive"),
		infoOnly = MakeSectionHeader("Unconfirmed: source unknown (info only)"),
		unused = MakeSectionHeader("Not used by this pet family"),
	}
	f.sectionHeaders.infoOnly.costHint:SetText("PET LEVEL")
	f.sectionHeaders.unused.costHint:SetText("")

	f.rowByAbility = {}
	for _, ability in ipairs(D.AbilityOrder) do
		local info = D.Abilities[ability]
		if info then
			local row = CreateFrame("Frame", nil, content)
			row:SetWidth(CONTENT_WIDTH)
			row:SetHeight(ROW_HEIGHT)
			row.ability = ability

			local icon = row:CreateTexture(nil, "ARTWORK")
			icon:SetWidth(ICON_SIZE)
			icon:SetHeight(ICON_SIZE)
			icon:SetPoint("LEFT", 4, 0)
			icon:SetTexture(D.AbilityIcons[ability] or "Interface\\Icons\\INV_Misc_QuestionMark")
			row.icon = icon

			local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			nameFS:SetPoint("LEFT", icon, "RIGHT", 4, 0)
			nameFS:SetWidth(NAME_WIDTH)
			nameFS:SetJustifyH("LEFT")
			nameFS:SetText(ability)
			row.nameFS = nameFS

			-- Hover target covering icon + name for the real ability tooltip
			local tipHit = CreateFrame("Button", nil, row)
			tipHit:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
			tipHit:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -2, -2)
			tipHit:SetPoint("RIGHT", nameFS, "RIGHT", 0, 0)
			tipHit:SetFrameLevel(row:GetFrameLevel() + 5)
			tipHit:EnableMouse(true)
			tipHit:SetScript("OnEnter", function(self)
				local t = HPT:GetActiveTemplate()
				local preferred = (t.ranks[ability] and t.ranks[ability] > 0) and t.ranks[ability] or nil
				HPT:ShowAbilityTooltip(self, ability, preferred)
			end)
			tipHit:SetScript("OnLeave", GameTooltip_Hide)
			row.tipHit = tipHit

			local compareFS = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			compareFS:SetPoint("RIGHT", row, "LEFT", BUTTONS_X - 4, 0)
			compareFS:SetWidth(RANK_LABEL_W)
			compareFS:SetJustifyH("RIGHT")
			row.compareFS = compareFS

			row.buttons = {}
			local maxRank = 0
			for r in pairs(info.ranks) do
				if r > maxRank then maxRank = r end
			end
			local bx = BUTTONS_X
			local infoOnly = HPT:IsInfoOnlyAbility(ability)
			for rank = 1, maxRank do
				if info.ranks[rank] then
					local label = infoOnly and info.ranks[rank].level or info.ranks[rank].cost
					local b = MakeRankButton(row, ability, rank, label)
					b:SetPoint("LEFT", bx, 0)
					row.buttons[rank] = b
					bx = bx + BUTTON_STEP
				end
			end
			row.buttonsEndX = bx

			local clearBtn = CreateFrame("Button", nil, row)
			clearBtn:SetWidth(16)
			clearBtn:SetHeight(16)
			clearBtn:SetPoint("LEFT", bx + 2, 0)
			local clearFS = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			clearFS:SetPoint("CENTER")
			clearFS:SetText("|cffff4444x|r")
			clearBtn:SetScript("OnClick", function()
				local t = HPT:GetActiveTemplate()
				t.ranks[ability] = 0
				HPT:UpdateUI()
				if HPT.SyncAssistToPlan then
					HPT:SyncAssistToPlan()
				end
			end)
			clearBtn:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText("Clear selected ranks")
				GameTooltip:Show()
			end)
			clearBtn:SetScript("OnLeave", GameTooltip_Hide)
			clearBtn:SetShown(not infoOnly)
			row.clearBtn = clearBtn

			f.rowByAbility[ability] = row
			table.insert(f.rows, row)
		end
	end
	content:SetHeight(1)

	local applyBtn = CreateFlatButton(f, 120, 24, "Assist Train")
	applyBtn:SetPoint("BOTTOMLEFT", 20, 28)
	applyBtn:SetScript("OnClick", function()
		HPT:StartApply()
	end)
	f.applyBtn = applyBtn

	local templateLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	templateLabel:SetPoint("TOPRIGHT", -210, -42)
	templateLabel:SetText("Template")
	f.templateLabel = templateLabel

	local templateDrop = CreateFlatDropdown(f, 130, 22)
	templateDrop:SetPoint("LEFT", templateLabel, "RIGHT", 8, 0)
	templateDrop:SetText(self:GetDB().activeTemplate or "Default")
	f.templateDrop = templateDrop

	local templateMenuBtn = CreateFlatButton(f, 28, 22, "···")
	templateMenuBtn:SetPoint("LEFT", templateDrop, "RIGHT", 4, 0)
	templateMenuBtn.label:SetTextColor(0.85, 0.85, 0.85)
	f.templateMenuBtn = templateMenuBtn

	-- Keep a hidden alias so older layout code that referenced saveBtn still works
	f.saveBtn = templateMenuBtn

	local function ShowTemplateActions()
		local db = HPT:GetDB()
		local active = db.activeTemplate or HPT.CURRENT_PET_KEY
		local t = HPT:GetActiveTemplate()
		local isCurrent = HPT:IsCurrentPetActive()
		local showPet = HPT:IsShowPetTrained()
		local menu = {
			{ text = "Template actions", isTitle = true, notCheckable = true },
			{
				text = "New template...",
				hasArrow = true,
				notCheckable = true,
				menuList = BuildNewTemplateFamilyMenu(),
			},
			{
				text = "Save As...",
				notCheckable = true,
				func = function()
					StaticPopup_Show("HPT_SAVE_TEMPLATE")
				end,
			},
			{
				text = "Apply to Current Pet...",
				notCheckable = true,
				disabled = isCurrent or not UnitExists("pet"),
				func = function()
					HPT:ApplyTemplateToCurrentPet(active)
				end,
			},
			{
				text = "Reset Current Pet to trained...",
				notCheckable = true,
				disabled = not isCurrent or not UnitExists("pet"),
				func = function()
					HPT:SyncCurrentPetPlanFromPet(true)
					HPT:Echo("Current Pet plan reset to trained ranks.")
					HPT:UpdateUI()
					if HPT.SyncAssistToPlan then HPT:SyncAssistToPlan() end
				end,
			},
			{
				text = "Show pet trained",
				checked = showPet,
				isNotRadio = true,
				disabled = isCurrent,
				func = function()
					if not HPT:IsCurrentPetActive() then
						HPT:SetShowPetTrained(not HPT:IsShowPetTrained())
					end
				end,
			},
			{
				text = "Reset to empty...",
				notCheckable = true,
				disabled = isCurrent or not HPT:TemplateHasPlannedRanks(t),
				func = function()
					StaticPopup_Show("HPT_CLEAR_TEMPLATE", active, nil, active)
				end,
			},
			{
				text = ("Delete '%s'..."):format(active),
				notCheckable = true,
				disabled = isCurrent,
				func = function()
					StaticPopup_Show("HPT_DELETE_TEMPLATE", active, nil, active)
				end,
			},
		}
		if HPT.WOWHEAD_IMPORT then
			table.insert(menu, 4, {
				text = "Import Wowhead link...",
				notCheckable = true,
				func = function()
					StaticPopup_Show("HPT_IMPORT_WOWHEAD")
				end,
			})
		end
		OpenEasyMenu(templateMenuBtn, menu)
	end
	templateMenuBtn:SetScript("OnClick", ShowTemplateActions)
	templateMenuBtn:SetScript("OnEnter", function(self)
		SetFlatBorder(self, 0.55)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Template actions")
		GameTooltip:AddLine("New / Apply / Save As / …", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	templateMenuBtn:SetScript("OnLeave", function(self)
		SetFlatBorder(self, 0.38)
		GameTooltip_Hide()
	end)

	local function TemplateMenuLabel(name)
		if name == HPT.CURRENT_PET_KEY then
			return "|cff33ff99Current Pet|r"
		end
		local tmpl = HPT:GetDB().templates[name]
		if tmpl and tmpl.family then
			return ("%s |cff888888(%s)|r"):format(name, tmpl.family)
		end
		return name
	end

	local function RefreshTemplateDrop()
		local db = HPT:GetDB()
		local active = db.activeTemplate or HPT.CURRENT_PET_KEY
		if active == HPT.CURRENT_PET_KEY then
			templateDrop:SetText("Current Pet")
		else
			templateDrop:SetText(active)
		end
		templateDrop:SetScript("OnClick", function(self)
			local menu = {
				{
					text = TemplateMenuLabel(HPT.CURRENT_PET_KEY),
					checked = (db.activeTemplate == HPT.CURRENT_PET_KEY),
					func = function()
						HPT:SetActiveTemplate(HPT.CURRENT_PET_KEY)
					end,
				},
			}
			local names = {}
			for name in pairs(db.templates or {}) do
				table.insert(names, name)
			end
			table.sort(names)
			if #names > 0 then
				table.insert(menu, { text = "Saved templates", isTitle = true, notCheckable = true })
			end
			for _, name in ipairs(names) do
				local tmplName = name
				table.insert(menu, {
					text = TemplateMenuLabel(tmplName),
					checked = (db.activeTemplate == tmplName),
					func = function()
						HPT:SetActiveTemplate(tmplName)
					end,
				})
			end
			table.insert(menu, { text = " ", disabled = true, notCheckable = true })
			table.insert(menu, {
				text = "New template...",
				hasArrow = true,
				notCheckable = true,
				menuList = BuildNewTemplateFamilyMenu(),
			})
			table.insert(menu, {
				text = "Save As...",
				notCheckable = true,
				func = function()
					StaticPopup_Show("HPT_SAVE_TEMPLATE")
				end,
			})
			if HPT.WOWHEAD_IMPORT then
				table.insert(menu, {
					text = "Import Wowhead link...",
					notCheckable = true,
					func = function()
						StaticPopup_Show("HPT_IMPORT_WOWHEAD")
					end,
				})
			end
			if db.activeTemplate and db.activeTemplate ~= HPT.CURRENT_PET_KEY then
				table.insert(menu, {
					text = "Apply to Current Pet...",
					notCheckable = true,
					disabled = not UnitExists("pet"),
					func = function()
						HPT:ApplyTemplateToCurrentPet(db.activeTemplate)
					end,
				})
			end
			OpenEasyMenu(self, menu)
		end)
	end
	f.RefreshTemplateDrop = RefreshTemplateDrop
	RefreshTemplateDrop()

	StaticPopupDialogs["HPT_SAVE_TEMPLATE"] = {
		text = "Save template as:",
		button1 = SAVE,
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 40,
		OnAccept = function(dialog)
			local box = dialog.editBox or _G[dialog:GetName() .. "EditBox"]
			local name = box and box:GetText()
			if name and name ~= "" then
				HPT:SaveTemplateAs(name)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
		end,
		EditBoxOnEnterPressed = function(editBox)
			local dialog = editBox:GetParent()
			local name = editBox:GetText()
			if name and name ~= "" then
				HPT:SaveTemplateAs(name)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
			dialog:Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["HPT_IMPORT_WOWHEAD"] = {
		text = "Paste a Wowhead Hunter Pet Training link:\n(https://www.wowhead.com/tbc/hunter-pet-training/...)\nCreates a new theory template.",
		button1 = ACCEPT or "Import",
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 300,
		OnShow = function(dialog)
			local box = dialog.editBox or _G[dialog:GetName() .. "EditBox"]
			if box then
				box:SetText("")
				box:SetFocus()
			end
		end,
		OnAccept = function(dialog)
			local box = dialog.editBox or _G[dialog:GetName() .. "EditBox"]
			local link = box and box:GetText()
			if link and link ~= "" then
				HPT:ImportWowheadPetTraining(link)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
		end,
		EditBoxOnEnterPressed = function(editBox)
			local dialog = editBox:GetParent()
			local link = editBox:GetText()
			if link and link ~= "" then
				HPT:ImportWowheadPetTraining(link)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
			dialog:Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["HPT_NEW_TEMPLATE"] = {
		text = "Create blank |cffffffff%s|r template:\nEmpty plan — nothing copied from your pet.",
		button1 = ACCEPT or "Create",
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 40,
		OnShow = function(dialog)
			local box = dialog.editBox or _G[dialog:GetName() .. "EditBox"]
			if box then
				box:SetText("")
				box:SetFocus()
			end
		end,
		OnAccept = function(dialog)
			local box = dialog.editBox or _G[dialog:GetName() .. "EditBox"]
			local name = box and box:GetText()
			local family = dialog.data or HPT:SuggestNewTemplateFamily()
			if name and name ~= "" then
				HPT:CreateBlankTemplate(name, family)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
		end,
		EditBoxOnEnterPressed = function(editBox)
			local dialog = editBox:GetParent()
			local name = editBox:GetText()
			local family = dialog.data or HPT:SuggestNewTemplateFamily()
			if name and name ~= "" then
				HPT:CreateBlankTemplate(name, family)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
			dialog:Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["HPT_CHANGE_FAMILY"] = {
		text = "Change template family to |cffffffff%s|r?\nRanks not used by that family will be cleared.",
		button1 = YES,
		button2 = NO,
		OnAccept = function(dialog)
			local fam = dialog.data
			if fam then
				HPT:SetTemplateFamily(HPT:GetActiveTemplate(), fam)
				if f.familyDrop and f.familyDrop.SetText then
					f.familyDrop:SetText(fam)
				end
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["HPT_CLEAR_TEMPLATE"] = {
		text = "Clear all planned ranks on template '%s'?",
		button1 = YES,
		button2 = NO,
		OnAccept = function(dialog)
			HPT:ClearTemplateRanks(HPT:GetActiveTemplate())
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["HPT_DELETE_TEMPLATE"] = {
		text = "Delete template '%s'?\nThis cannot be undone.",
		button1 = DELETE or "Delete",
		button2 = CANCEL,
		OnAccept = function(dialog)
			local name = dialog.data
			if name then
				HPT:DeleteTemplate(name)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["HPT_APPLY_FAMILY_MISMATCH"] = {
		text = "Template is for |cffffffff%s|r but your pet is |cffffffff%s|r.\nApply only ranks usable by your pet?",
		button1 = YES,
		button2 = NO,
		OnAccept = function(dialog)
			local name = dialog.data
			if name then
				HPT:ApplyTemplateToCurrentPet(name, true)
				if f.RefreshTemplateDrop then
					f.RefreshTemplateDrop()
				end
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	f.familyDrop = familyDrop
	self.frame = f
	familyDrop:SetText(self:GetActiveTemplate().family)
	self:LayoutAbilityRows()
	if self.ApplySkin then
		self:ApplySkin()
	end
end

function HPT:LayoutAbilityRows()
	local f = self.frame
	if not f or not f.content or not f.rowByAbility then
		return
	end
	local t = self:GetActiveTemplate()
	local family = t.family
	local activeList, passiveList, infoOnlyList, unusedList = {}, {}, {}, {}

	for _, ability in ipairs(D.AbilityOrder) do
		local info = D.Abilities[ability]
		if info and f.rowByAbility[ability] then
			local avail = self:AbilityAvailableForFamily(ability, family)
			if not avail then
				table.insert(unusedList, ability)
			elseif self:IsInfoOnlyAbility(ability) then
				table.insert(infoOnlyList, ability)
			elseif info.active then
				table.insert(activeList, ability)
			else
				table.insert(passiveList, ability)
			end
		end
	end

	local y = 0
	local function placeHeader(header, show)
		if not header then
			return
		end
		if show then
			header:Show()
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", 0, -y)
			y = y + SECTION_HEIGHT
		else
			header:Hide()
		end
	end

	local function placeRows(list)
		for _, ability in ipairs(list) do
			local row = f.rowByAbility[ability]
			row:Show()
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			y = y + ROW_HEIGHT
		end
	end

	placeHeader(f.sectionHeaders.active, #activeList > 0)
	placeRows(activeList)
	placeHeader(f.sectionHeaders.passive, #passiveList > 0)
	placeRows(passiveList)
	placeHeader(f.sectionHeaders.infoOnly, #infoOnlyList > 0)
	placeRows(infoOnlyList)
	placeHeader(f.sectionHeaders.unused, #unusedList > 0)
	placeRows(unusedList)

	f.content:SetHeight(math.max(y, 1))
end

-- When true, planner is drawn inside the Beast Training dock (no second dialog chrome).
function HPT:SetPlannerEmbedded(embedded)
	local f = self.frame
	if not f then
		return
	end
	f.embedded = embedded and true or false
	if f.skinShell then
		f.skinShell:SetShown(not embedded)
	end
	if embedded then
		f:SetBackdrop(nil)
		f:SetMovable(false)
		f:RegisterForDrag()
		if f.title then
			f.title:Hide()
			f.titleIcon:Hide()
		end
		if f.closeBtn then
			f.closeBtn:Hide()
		end

		-- Row 1: Family (left) | Template dropdown + actions (right)
		if f.familyLabel then
			f.familyLabel:ClearAllPoints()
			f.familyLabel:SetPoint("TOPLEFT", 8, -6)
		end
		if f.familyDrop then
			f.familyDrop:ClearAllPoints()
			f.familyDrop:SetPoint("LEFT", f.familyLabel, "RIGHT", 6, 0)
			f.familyDrop:SetSize(130, 22)
		end
		if f.templateMenuBtn then
			f.templateMenuBtn:ClearAllPoints()
			f.templateMenuBtn:SetPoint("TOPRIGHT", -6, -4)
			f.templateMenuBtn:Show()
		end
		if f.templateDrop then
			f.templateDrop:ClearAllPoints()
			f.templateDrop:SetPoint("RIGHT", f.templateMenuBtn, "LEFT", -4, 0)
			f.templateDrop:SetSize(130, 22)
			f.templateDrop:Show()
		end
		if f.templateLabel then
			f.templateLabel:ClearAllPoints()
			f.templateLabel:SetPoint("RIGHT", f.templateDrop, "LEFT", -6, 0)
			f.templateLabel:Show()
		end
		if f.saveBtn and f.saveBtn ~= f.templateMenuBtn then
			f.saveBtn:Hide()
		end

		-- Row 2: pet strip (left), TP cost (right)
		if f.petText then
			f.petText:ClearAllPoints()
			f.petText:SetPoint("TOPLEFT", 8, -32)
			f.petText:Show()
		end
		if f.templateText then
			f.templateText:Hide()
		end
		if f.pointsText then
			f.pointsText:ClearAllPoints()
			f.pointsText:SetPoint("TOPRIGHT", -8, -32)
			f.pointsText:SetJustifyH("RIGHT")
		end
		if f.statusText then
			f.statusText:Hide()
		end

		-- Row 3: calculator
		if f.calcBar then
			f.calcBar:ClearAllPoints()
			f.calcBar:SetPoint("TOPLEFT", 4, -50)
			f.calcBar:SetPoint("TOPRIGHT", -26, -50)
			f.calcBar:Show()
		end
		if f.scroll then
			f.scroll:ClearAllPoints()
			f.scroll:SetPoint("TOPLEFT", 4, -98)
			f.scroll:SetPoint("BOTTOMRIGHT", -28, 4)
		end
		if f.applyBtn then f.applyBtn:Hide() end
		if f.RefreshTemplateDrop then
			f.RefreshTemplateDrop()
		end
	else
		if f.standaloneBackdrop and not f.skinShell then
			f:SetBackdrop(f.standaloneBackdrop)
		end
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		if f.title then
			f.title:Show()
			f.titleIcon:Show()
		end
		if f.closeBtn then
			f.closeBtn:Show()
		end
		if f.statusText then
			f.statusText:Show()
		end
		if f.familyLabel then
			f.familyLabel:ClearAllPoints()
			f.familyLabel:SetPoint("TOPLEFT", 20, -42)
		end
		if f.familyDrop then
			f.familyDrop:ClearAllPoints()
			f.familyDrop:SetPoint("LEFT", f.familyLabel, "RIGHT", 8, 0)
			f.familyDrop:SetSize(140, 22)
		end
		if f.pointsText then
			f.pointsText:ClearAllPoints()
			f.pointsText:SetPoint("TOPRIGHT", -40, -48)
			f.pointsText:SetJustifyH("RIGHT")
		end
		if f.petText then
			f.petText:ClearAllPoints()
			f.petText:SetPoint("TOPLEFT", 20, -68)
			f.petText:Show()
		end
		if f.templateText then
			f.templateText:ClearAllPoints()
			f.templateText:SetPoint("TOPLEFT", 20, -84)
			f.templateText:Show()
		end
		if f.calcBar then
			f.calcBar:ClearAllPoints()
			f.calcBar:SetPoint("TOPLEFT", 16, -100)
			f.calcBar:SetPoint("TOPRIGHT", -36, -100)
			f.calcBar:Show()
		end
		if f.statusText then
			f.statusText:ClearAllPoints()
			f.statusText:SetPoint("TOPLEFT", 20, -148)
			f.statusText:SetWidth(FRAME_WIDTH - 40)
		end
		if f.scroll then
			f.scroll:ClearAllPoints()
			f.scroll:SetPoint("TOPLEFT", 16, -168)
			f.scroll:SetPoint("BOTTOMRIGHT", -36, 70)
		end
		if f.applyBtn then f.applyBtn:Show() end
		if f.templateMenuBtn then
			f.templateMenuBtn:ClearAllPoints()
			f.templateMenuBtn:SetPoint("BOTTOMRIGHT", -20, 28)
			f.templateMenuBtn:Show()
		end
		if f.templateLabel then
			f.templateLabel:ClearAllPoints()
			f.templateLabel:SetPoint("BOTTOMLEFT", 20, 58)
			f.templateLabel:Show()
		end
		if f.templateDrop then
			f.templateDrop:ClearAllPoints()
			f.templateDrop:SetPoint("LEFT", f.templateLabel, "RIGHT", 8, 0)
			f.templateDrop:SetSize(130, 22)
			f.templateDrop:Show()
		end
		-- In standalone, put menu next to template drop
		if f.templateMenuBtn and f.templateDrop then
			f.templateMenuBtn:ClearAllPoints()
			f.templateMenuBtn:SetPoint("LEFT", f.templateDrop, "RIGHT", 4, 0)
		end
		if f.RefreshTemplateDrop then
			f.RefreshTemplateDrop()
		end
	end
end

function HPT:UpdateUI()
	if not self.frame or not self.frame:IsShown() then
		return
	end
	local t = self:GetActiveTemplate()
	self:SanitizeTemplateForFamily(t)
	local petRanks = self:GetPetKnownRanks()
	local usable, totalTP, spentTP, pointsSource = self:GetPetPoints()
	local cost = self:GetTemplateCost(t)
	local remaining = self:GetTemplateRemainingCost(t, petRanks)
	local craftOpen = self:IsBeastTrainingOpen()
	local isCurrent = self:IsCurrentPetActive()

	local planLabel = isCurrent and "Current Pet" or t.name
	self.frame.templateText:SetText(("Plan: |cffffffff%s|r  ·  Family: |cffffffff%s|r"):format(planLabel, t.family))
	if isCurrent then
		self.frame.pointsText:SetText(("TP to train: |cffffffff%d|r  ·  Available: |cffffffff%d|r"):format(remaining, usable))
	else
		self.frame.pointsText:SetText(("Build cost: |cffffffff%d|r TP"):format(cost))
	end

	if self.frame.petText then
		local petOverlay = ""
		if not isCurrent then
			petOverlay = self:IsShowPetTrained() and "" or "  ·  |cff888888pet overlay off|r"
		end
		if UnitExists("pet") then
			local petFamily = self:GetPetFamily() or "?"
			local petLevel = UnitLevel("pet") or "?"
			if petFamily ~= t.family then
				self.frame.petText:SetText(("Pet: |cffff6666%s|r Lvl %s  ·  |cffff9900plan is %s|r%s"):format(
					petFamily, tostring(petLevel), t.family, petOverlay))
			else
				self.frame.petText:SetText(("Pet: |cffffffff%s|r Lvl %s%s"):format(
					petFamily, tostring(petLevel), petOverlay))
			end
		else
			self.frame.petText:SetText("|cff888888No pet summoned|r" .. petOverlay)
		end
	end

	-- Calculator: live pet values on Current Pet (never theory); editable on saved templates
	if self.frame.calcBar then
		local level, loyalty, used, maxTP
		local steppersOn = not isCurrent
		local levelText, loyaltyText
		if isCurrent then
			if UnitExists("pet") then
				level = UnitLevel("pet") or 0
				loyalty = self:GetPetLoyaltyLevel()
				-- Live max (loyalty 1 => 0 is real). Numerator includes planned upgrades
				-- so over-budget plans show e.g. 130 / 0 in red, not 0 / 0.
				maxTP = totalTP or 0
				used = (spentTP or 0) + (remaining or 0)
				levelText = tostring(level)
				if loyalty then
					loyaltyText = ("%d %s"):format(loyalty, self:LoyaltyName(loyalty))
				else
					loyaltyText = "|cff888888open Pet tab|r"
				end
			else
				levelText = "—"
				loyaltyText = "—"
				used = 0
				maxTP = 0
			end
		else
			level = t.theoryLevel or HPT.MAX_LEVEL
			loyalty = t.theoryLoyalty or 6
			used = cost
			maxTP = self:GetTheoryMaxTP(level, loyalty)
			levelText = tostring(level)
			loyaltyText = ("%d %s"):format(loyalty, self:LoyaltyName(loyalty))
		end

		if self.frame.levelStep then
			self.frame.levelStep:SetSteppersVisible(steppersOn)
			self.frame.levelStep.value:SetText(levelText)
			if steppersOn then
				self.frame.levelStep.minus:Enable()
				self.frame.levelStep.plus:Enable()
			end
		end
		if self.frame.loyaltyStep then
			self.frame.loyaltyStep:SetSteppersVisible(steppersOn)
			-- Re-anchor loyalty after level width may change
			self.frame.loyaltyStep:ClearAllPoints()
			self.frame.loyaltyStep:SetPoint("LEFT", self.frame.levelStep, "RIGHT", 16, 0)
			self.frame.loyaltyStep.value:SetText(loyaltyText)
			if steppersOn then
				self.frame.loyaltyStep.minus:Enable()
				self.frame.loyaltyStep.plus:Enable()
			end
		end
		local overBudget = used > maxTP
		if self.frame.tpBar then
			local barMax = math.max(1, maxTP, used)
			self.frame.tpBar:SetMinMaxValues(0, barMax)
			self.frame.tpBar:SetValue(used)
			if overBudget then
				self.frame.tpBar:SetStatusBarColor(0.85, 0.25, 0.2, 1)
			elseif maxTP <= 0 then
				self.frame.tpBar:SetStatusBarColor(0.35, 0.35, 0.35, 1)
			elseif used / barMax > 0.85 then
				self.frame.tpBar:SetStatusBarColor(0.85, 0.7, 0.2, 1)
			else
				self.frame.tpBar:SetStatusBarColor(0.3, 0.75, 0.3, 1)
			end
		end
		self.frame.tpNote = nil
		if self.frame.tpValue then
			if not isCurrent or UnitExists("pet") then
				local live = not isCurrent or pointsSource == "trainer"
				local usedColor = overBudget and "ff4444" or (live and "ffffff" or "999999")
				local maxColor = live and "" or "|cff999999"
				self.frame.tpValue:SetText(("|cff%s%d|r / %s%d|r"):format(usedColor, used, maxColor, maxTP))
				if isCurrent and not loyalty then
					self.frame.tpNote = "Open the Pet tab of the Character window once so the addon can read loyalty."
				elseif pointsSource == "cached" then
					self.frame.tpNote = "Spent TP is from your last visit to the pet trainer. It updates the next time you open Beast Training."
				elseif pointsSource == "estimate" then
					self.frame.tpNote = "Spent TP is unknown until you open Beast Training at a pet trainer with this pet."
				end
			else
				self.frame.tpValue:SetText("— / —")
			end
		end
		if self.frame.tpLabel then
			self.frame.tpLabel:SetText("TRAINING POINTS")
		end
	end

	-- Status line only used in standalone /hpt window; craft overlay uses footer "Next:"
	if self.frame.embedded then
		self.frame.statusText:Hide()
	else
		self.frame.statusText:Show()
		local status = ""
		if not isCurrent then
			status = "|cff888888Theory craft — Apply to Current Pet to train.|r"
		elseif not UnitExists("pet") then
			status = "|cffff9900Summon a pet to train from Current Pet.|r"
		elseif not craftOpen then
			status = "Open |cffffff00Beast Training|r to assist Train from Current Pet."
		elseif not select(2, self:GetTrainerFilterState()) then
			status = "|cffff9900Tick every Filters option in Beast Training so all ranks are listed.|r"
		else
			status = ""
		end
		self.frame.statusText:SetText(status)
	end
	if self.frame.familyDrop and self.frame.familyDrop.SetText then
		self.frame.familyDrop:SetText(t.family)
		if isCurrent then
			self.frame.familyDrop:Disable()
			self.frame.familyDrop:SetAlpha(0.55)
			if self.frame.familyDrop.text then
				self.frame.familyDrop.text:SetTextColor(0.7, 0.7, 0.7)
			end
		else
			self.frame.familyDrop:Enable()
			self.frame.familyDrop:SetAlpha(1)
			if self.frame.familyDrop.text then
				self.frame.familyDrop.text:SetTextColor(1, 1, 1)
			end
		end
	end

	self:LayoutAbilityRows()

	-- Ranks the trainer lists; nil when closed or a filter hides rows (can't tell "not known" from "hidden")
	local filtersAllOn = select(2, self:GetTrainerFilterState())
	local hunterCraftRankSet = craftOpen and filtersAllOn and self:GetTrainerRankSet() or nil
	local showPet = self:IsShowPetTrained()
	-- Live pet ranks for compare overlay (optional for theory-crafting)
	local displayPetRanks = showPet and petRanks or {}

	for _, row in ipairs(self.frame.rows) do
		local ability = row.ability
		local available = self:AbilityAvailableForFamily(ability, t.family)
		local desired = t.ranks[ability] or 0
		local petRank = displayPetRanks[ability] or 0
		local info = D.Abilities[ability]
		local infoOnly = self:IsInfoOnlyAbility(ability)
		local hasPlannedGreen = desired > petRank
		local knownSet = hunterCraftRankSet and hunterCraftRankSet[ability] or nil

		local function IsHunterKnownRank(rank)
			-- Only annotate when Beast Training is open (we can see the craft list)
			if hunterCraftRankSet == nil then
				return true
			end
			return knownSet and knownSet[rank] or false
		end

		local function ApplyRankTooltip(btn, rank, rankInfo, extraLines)
			btn:SetScript("OnEnter", function(self)
				local liveTip = HPT:ShowAbilityTooltip(self, ability, rank)
				-- Append planner details under the real ability tip
				GameTooltip:AddLine(" ")
				if not IsHunterKnownRank(rank) then
					GameTooltip:AddLine("*Ability not known", 1, 0.15, 0.15)
				end
				if rankInfo then
					-- Live craft/spell tip may omit our planner numbers; static fallback already has req/TP
					if liveTip then
						GameTooltip:AddLine(("Req pet level: %d"):format(rankInfo.level), 1, 1, 1)
						GameTooltip:AddLine(("Training points: %d"):format(rankInfo.cost), 1, 1, 1)
					end
					local prevCost = (rank > 1 and info.ranks[rank - 1] and info.ranks[rank - 1].cost) or 0
					local upgrade = (rankInfo.cost or 0) - prevCost
					if rank > 1 then
						GameTooltip:AddLine(("Upgrade from rank %d: %d"):format(rank - 1, upgrade), 0.7, 0.9, 0.7)
					end
				end
				if extraLines then
					for _, line in ipairs(extraLines) do
						GameTooltip:AddLine(line[1], line[2], line[3], line[4])
					end
				end
				GameTooltip:Show()
			end)
			btn:SetScript("OnLeave", GameTooltip_Hide)
		end

		if not available then
			row:SetAlpha(0.35)
			-- Informational only: no selection chrome; clicks are ignored
			row.compareFS:SetText("")
			row.nameFS:SetTextColor(0.5, 0.5, 0.5)
			if row.icon.SetDesaturated then
				row.icon:SetDesaturated(true)
			end
			row.icon:SetAlpha(0.45)
			row.clearBtn:Hide()
			for rank, btn in pairs(row.buttons) do
				local rankInfo = info.ranks[rank]
				btn.bg:SetColorTexture(0.12, 0.12, 0.12, 0.85)
				btn:EnableMouse(true)
				if btn.Enable then btn:Enable() end
				if rankInfo then
					btn.fs:SetText(tostring(infoOnly and rankInfo.level or rankInfo.cost))
					if not IsHunterKnownRank(rank) then
						btn.fs:SetTextColor(1, 0.2, 0.2)
					else
						btn.fs:SetTextColor(0.45, 0.45, 0.45)
					end
					ApplyRankTooltip(btn, rank, rankInfo, {
						{ "Not used by this pet family — cannot select", 1, 0.3, 0.3 },
					})
				end
			end
		else
			row:SetAlpha(1)

			if desired > 0 or petRank > 0 then
				local labelRank = math.max(desired, petRank)
				row.compareFS:SetText("|cff888888RANK " .. labelRank .. "|r")
			else
				row.compareFS:SetText("")
			end

			-- Gold = planned selection; normal = trained only; grey = neither
			if desired > 0 then
				row.nameFS:SetTextColor(1, 0.82, 0)
				if row.icon.SetDesaturated then
					row.icon:SetDesaturated(false)
				end
				row.icon:SetAlpha(1)
			elseif petRank > 0 then
				row.nameFS:SetTextColor(0.9, 0.9, 0.9)
				if row.icon.SetDesaturated then
					row.icon:SetDesaturated(false)
				end
				row.icon:SetAlpha(1)
			else
				row.nameFS:SetTextColor(0.55, 0.55, 0.55)
				if row.icon.SetDesaturated then
					row.icon:SetDesaturated(true)
				end
				row.icon:SetAlpha(0.85)
			end

			-- Clear only when template has ranks beyond what is already trained (green cells)
			if hasPlannedGreen and not infoOnly then
				row.clearBtn:Show()
			else
				row.clearBtn:Hide()
			end

			for rank, btn in pairs(row.buttons) do
				local rankInfo = info.ranks[rank]
				btn:Enable()
				btn:EnableMouse(true)
				-- Blue = already trained (this rank or below pet's rank)
				-- Green = selected plan rank or below it (but not already blue)
				-- Grey = neither
				if petRank > 0 and rank <= petRank then
					btn.bg:SetColorTexture(0.2, 0.35, 0.55, 1) -- trained blue
				elseif desired > 0 and rank <= desired then
					btn.bg:SetColorTexture(0.2, 0.55, 0.2, 1) -- planned green
				else
					btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
				end
				if rankInfo then
					btn.fs:SetText(tostring(infoOnly and rankInfo.level or rankInfo.cost))
					if not IsHunterKnownRank(rank) then
						btn.fs:SetTextColor(1, 0.2, 0.2)
					else
						btn.fs:SetTextColor(1, 1, 1)
					end
					if infoOnly then
						ApplyRankTooltip(btn, rank, rankInfo, {
							{ "Unconfirmed: no trainer source or TP cost found yet", 1, 0.82, 0 },
							{ "Shown for reference; can't be added to a plan", 0.8, 0.8, 0.8 },
						})
					else
						ApplyRankTooltip(btn, rank, rankInfo)
					end
				end
			end
		end
	end

	if self.frame.RefreshTemplateDrop then
		self.frame.RefreshTemplateDrop()
	end
	if self.frame.templateDrop and self.frame.templateDrop.SetText then
		if isCurrent then
			self.frame.templateDrop:SetText("Current Pet")
		else
			self.frame.templateDrop:SetText(self:GetDB().activeTemplate or t.name)
		end
	end

	if self.apply.active then
		if self.frame.applyBtn then
			self.frame.applyBtn.label:SetText("Stop")
			self.frame.applyBtn:SetScript("OnClick", function()
				HPT:StopApply("Cancelled.")
			end)
		end
	else
		if self.frame.applyBtn then
			self.frame.applyBtn.label:SetText("Assist Train")
			self.frame.applyBtn:SetScript("OnClick", function()
				HPT:StartApply()
			end)
			if isCurrent then
				self.frame.applyBtn:Enable()
				self.frame.applyBtn:SetAlpha(1)
			else
				self.frame.applyBtn:Disable()
				self.frame.applyBtn:SetAlpha(0.45)
			end
		end
	end

	if self.UpdateNextLabel then
		self:UpdateNextLabel()
	end
end

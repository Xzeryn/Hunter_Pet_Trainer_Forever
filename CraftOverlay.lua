local HPT = HunterPetTrainer

-- Restyle CraftFrame IN PLACE for Beast Training (ProfessionPlus-style),
-- instead of stacking a second dialog window on top.

local SUPPRESS = {
	"CraftListScrollFrame",
	"CraftDetailScrollFrame",
	"CraftHighlightFrame",
	"CraftExpandButtonFrame",
	"CraftRankFrame",
	"CraftFrameAvailableFilterCheckButton",
	"CraftRequirements",
	"CraftCost",
	"CraftDescription",
	"CraftItemName",
	"CraftIcon",
	"CraftCancelButton",
}

local savedButton = {}
local savedCraft = {}
local skinned = false

local function IsPetCraftOpen()
	return HPT:IsBeastTrainingOpen()
end

local function SuppressFrame(f)
	if not f then
		return
	end
	f:Hide()
	if not f.hptSuppressed then
		f.hptSuppressed = true
		f:HookScript("OnShow", function(self)
			if HPT.craftSkinned then
				self:Hide()
			end
		end)
	end
end

function HPT:CreateCraftOverlay()
	if self.craftHost then
		return
	end

	-- Content host fills CraftFrame; no separate window chrome
	local host = CreateFrame("Frame", "HunterPetTrainerCraftHost", UIParent)
	host:Hide()

	-- Footer is parented to CraftFrame on show (absolute bottom), not the scroll host
	local footer = CreateFrame("Frame", "HunterPetTrainerCraftFooter", UIParent)
	footer:SetHeight(64)
	footer:Hide()
	host.footer = footer

	local footerBg = footer:CreateTexture(nil, "BACKGROUND")
	footerBg:SetAllPoints()
	footerBg:SetColorTexture(0.08, 0.08, 0.08, 1)

	local nextLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	nextLabel:SetPoint("LEFT", 10, 8)
	nextLabel:SetPoint("RIGHT", footer, "RIGHT", -118, 8)
	nextLabel:SetJustifyH("LEFT")
	nextLabel:SetText("Next: —")
	host.nextLabel = nextLabel

	local hint = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", 10, -10)
	hint:SetPoint("RIGHT", footer, "RIGHT", -118, -10)
	hint:SetJustifyH("LEFT")
	hint:SetText("Click Train to teach this skill. The next plan skill is selected automatically.")
	host.hint = hint

	local slot = CreateFrame("Frame", "HunterPetTrainerTrainSlot", footer)
	slot:SetSize(100, 28)
	slot:SetPoint("RIGHT", -4, 0)
	host.trainSlot = slot

	local slotLabel = slot:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	slotLabel:SetPoint("CENTER")
	slotLabel:SetText(TRAIN or "Train")
	slot.placeholder = slotLabel

	self.craftHost = host
end

function HPT:SaveCraftFrameState()
	if savedCraft.saved or not CraftFrame then
		return
	end
	savedCraft.saved = true
	savedCraft.width = CraftFrame:GetWidth()
	savedCraft.height = CraftFrame:GetHeight()
	savedCraft.regionAlphas = {}
	for _, region in ipairs({ CraftFrame:GetRegions() }) do
		if region.IsObjectType and region:IsObjectType("Texture") then
			savedCraft.regionAlphas[region] = region:GetAlpha()
		end
	end
	if CraftFrameTitleText then
		savedCraft.titlePoint = { CraftFrameTitleText:GetPoint(1) }
		savedCraft.titleText = CraftFrameTitleText:GetText()
	end
end

local PROFESSIONPLUS_HIDE = {
	"ProfessionPlusEnchantBackground",
	"ProfessionPlusEnchantRankBar",
	"ProfessionPlusEnchantProfSelector",
	"ProfessionPlusEnchantViewerButton",
	"ProfessionPlusEnchantOptionsButton",
	"ProfessionPlusEnchantExpandBtn",
	"ProfessionPlusEnchantSearchBox",
	"ProfessionPlusEnchantFilterCraftable",
	"ProfessionPlusEnchantFilterSkillUp",
	"ProfessionPlusEnchantFilterHideGrey",
	"ProfessionPlusEnchantSettingsDrop",
	"ProfessionPlusEnchantList",
	"ProfessionPlusEnchantDetail",
}

local function HideCraftSkillButtons()
	-- Blizzard list rows (and any extras ProfessionPlus may create)
	for i = 1, 32 do
		local btn = _G["Craft" .. i]
		if btn then
			btn:Hide()
			-- Also hide text/cost children if they somehow show independently
			local text = _G["Craft" .. i .. "Text"]
			local sub = _G["Craft" .. i .. "SubText"]
			local cost = _G["Craft" .. i .. "Cost"]
			if text then text:SetText("") end
			if sub then sub:SetText("") end
			if cost then cost:SetText("") end
		end
	end
	if CraftListScrollFrame then
		CraftListScrollFrame:Hide()
		if CraftListScrollFrame.pptEnchantSkin then
			CraftListScrollFrame.pptEnchantSkin:Hide()
		end
	end
	if CraftDetailScrollFrame then
		CraftDetailScrollFrame:Hide()
	end
end

local function HideProfessionPlusOnCraft()
	for _, name in ipairs(PROFESSIONPLUS_HIDE) do
		local f = _G[name]
		if f then
			SuppressFrame(f)
		end
	end
	-- Filter checkbox labels are separate FontStrings sometimes
	for _, name in ipairs({
		"ProfessionPlusEnchantFilterCraftableText",
		"ProfessionPlusEnchantFilterSkillUpText",
		"ProfessionPlusEnchantFilterHideGreyText",
	}) do
		local f = _G[name]
		if f and f.Hide then
			f:Hide()
		end
	end
end

function HPT:EnsureCraftCover()
	if not CraftFrame then
		return
	end
	if not self.craftCover then
		local cover = CreateFrame("Frame", "HunterPetTrainerCraftCover", CraftFrame, "BackdropTemplate")
		cover:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = nil,
			tile = false,
		})
		-- Fully opaque so ghost craft rows cannot bleed through
		cover:SetBackdropColor(0.07, 0.07, 0.07, 1)
		cover:EnableMouse(true) -- block clicks to hidden list underneath
		self.craftCover = cover
	end
	local cover = self.craftCover
	cover:ClearAllPoints()
	cover:SetPoint("TOPLEFT", CraftFrame, "TOPLEFT", 6, -34)
	if self.craftHost and self.craftHost.footer and self.craftHost.footer:IsShown() then
		cover:SetPoint("BOTTOMRIGHT", self.craftHost.footer, "TOPRIGHT", 4, 0)
	else
		cover:SetPoint("BOTTOMRIGHT", CraftFrame, "BOTTOMRIGHT", -6, 58)
	end
	cover:SetFrameLevel(CraftFrame:GetFrameLevel() + 30)
	cover:Show()
	return cover
end

function HPT:HideForeignCraftUI()
	HideCraftSkillButtons()
	HideProfessionPlusOnCraft()
	for _, name in ipairs(SUPPRESS) do
		SuppressFrame(_G[name])
	end
end

function HPT:HookCraftFrameUpdate()
	if self.craftUpdateHooked or not CraftFrame_Update then
		return
	end
	self.craftUpdateHooked = true
	hooksecurefunc("CraftFrame_Update", function()
		if HPT.craftSkinned and IsPetCraftOpen() then
			HPT:HideForeignCraftUI()
			if CraftFrameTitleText then
				CraftFrameTitleText:SetText("Hunter Pet Trainer")
			end
			-- Keep our cover/host above anything ProfessionPlus re-shows
			if HPT.craftCover then
				HPT.craftCover:SetFrameLevel(CraftFrame:GetFrameLevel() + 30)
				HPT.craftCover:Show()
			end
			if HPT.craftHost and HPT.craftHost:IsShown() then
				HPT.craftHost:SetFrameLevel(CraftFrame:GetFrameLevel() + 40)
			end
			HPT:CaptureCraftTrainButton()
		end
	end)
end

function HPT:SkinCraftFrameForPet()
	if not CraftFrame then
		return
	end
	self:SaveCraftFrameState()
	self.craftSkinned = true
	self:HookCraftFrameUpdate()

	-- Size / movement like ProfessionPlus does for CraftFrame
	CraftFrame:SetWidth(600)
	CraftFrame:SetHeight(620)
	CraftFrame:SetMovable(true)
	CraftFrame:EnableMouse(true)
	CraftFrame:SetFrameStrata("HIGH")
	CraftFrame:SetToplevel(true)
	CraftFrame:RegisterForDrag("LeftButton")
	CraftFrame:SetScript("OnDragStart", CraftFrame.StartMoving)
	CraftFrame:SetScript("OnDragStop", CraftFrame.StopMovingOrSizing)

	-- Hide default craft art (keep one window look)
	for _, region in ipairs({ CraftFrame:GetRegions() }) do
		if region.IsObjectType and region:IsObjectType("Texture") then
			region:SetAlpha(0)
		end
	end

	if not self.craftBg then
		local bg = CreateFrame("Frame", "HunterPetTrainerCraftBackground", CraftFrame, "BackdropTemplate")
		bg:SetAllPoints(CraftFrame)
		bg:SetFrameLevel(math.max(1, CraftFrame:GetFrameLevel() - 1))
		bg:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		bg:SetBackdropColor(0.05, 0.05, 0.05, 1)
		bg:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
		self.craftBg = bg
	end
	self.craftBg:Show()
	self.craftBg:SetFrameLevel(math.max(1, CraftFrame:GetFrameLevel() - 1))

	if CraftFramePortrait then
		CraftFramePortrait:SetAlpha(0)
	end
	if CraftFrameTitleText then
		CraftFrameTitleText:SetAlpha(1)
		CraftFrameTitleText:ClearAllPoints()
		CraftFrameTitleText:SetPoint("TOPLEFT", CraftFrame, "TOPLEFT", 16, -14)
		CraftFrameTitleText:SetFontObject(GameFontNormalLarge)
		CraftFrameTitleText:SetText("Hunter Pet Trainer")
	end
	if CraftFrameCloseButton then
		CraftFrameCloseButton:ClearAllPoints()
		CraftFrameCloseButton:SetPoint("TOPRIGHT", CraftFrame, "TOPRIGHT", -4, -4)
		CraftFrameCloseButton:SetFrameLevel(CraftFrame:GetFrameLevel() + 60)
		CraftFrameCloseButton:Show()
	end

	-- Hide Blizzard list + ProfessionPlus chrome, then paint opaque cover over them
	self:HideForeignCraftUI()
	self:EnsureCraftCover()
end

function HPT:UnskinCraftFrame()
	if not self.craftSkinned or not CraftFrame then
		return
	end
	self.craftSkinned = false

	if self.craftBg then
		self.craftBg:Hide()
	end
	if self.craftCover then
		self.craftCover:Hide()
	end

	if savedCraft.width then
		CraftFrame:SetWidth(savedCraft.width)
		CraftFrame:SetHeight(savedCraft.height)
	end
	for region, alpha in pairs(savedCraft.regionAlphas or {}) do
		if region.SetAlpha then
			region:SetAlpha(alpha)
		end
	end
	if CraftFrameTitleText then
		if savedCraft.titleText then
			CraftFrameTitleText:SetText(savedCraft.titleText)
		end
		if savedCraft.titlePoint then
			CraftFrameTitleText:ClearAllPoints()
			CraftFrameTitleText:SetPoint(unpack(savedCraft.titlePoint))
		end
	end
	if CraftFramePortrait then
		CraftFramePortrait:SetAlpha(1)
	end
end

local TRAIN_BTN_W = 100
local TRAIN_BTN_H = 28

function HPT:EnsureTrainProxy()
	local footer = self.craftHost and self.craftHost.footer
	if not footer then
		return nil
	end
	if self.craftHost.trainProxy then
		return self.craftHost.trainProxy
	end

	-- Our own Train control. ProfessionPlus keeps yanking CraftCreateButton around;
	-- this proxy stays put and securely /clicks the real button.
	local proxy = CreateFrame("Button", "HunterPetTrainerTrainProxy", footer, "SecureActionButtonTemplate")
	proxy:SetSize(TRAIN_BTN_W, TRAIN_BTN_H)
	proxy:RegisterForClicks("AnyUp", "AnyDown")
	proxy:SetAttribute("type", "macro")
	proxy:SetAttribute("macrotext", "/click CraftCreateButton")

	local bg = proxy:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.18, 0.06, 0.06, 1)
	proxy.bg = bg

	local edge = proxy:CreateTexture(nil, "BORDER")
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	edge:SetColorTexture(0.75, 0.15, 0.15, 1)
	proxy.edge = edge
	-- draw edge behind fill
	bg:SetDrawLayer("BACKGROUND", 1)
	edge:SetDrawLayer("BACKGROUND", 0)

	local fs = proxy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER", 0, 0)
	fs:SetText(TRAIN or "Train")
	fs:SetTextColor(1, 0.25, 0.25)
	proxy.label = fs

	proxy:SetScript("OnEnter", function(self)
		if self.hptTrainLocked then
			self.bg:SetColorTexture(0.12, 0.12, 0.12, 1)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText("Train unavailable")
			GameTooltip:AddLine("Switch to Current Pet (or Apply this template) to train.", 0.8, 0.8, 0.8, true)
			GameTooltip:Show()
			return
		end
		self.bg:SetColorTexture(0.28, 0.1, 0.1, 1)
	end)
	proxy:SetScript("OnLeave", function(self)
		GameTooltip_Hide()
		if self.hptTrainLocked then
			self.bg:SetColorTexture(0.12, 0.12, 0.12, 1)
		else
			self.bg:SetColorTexture(0.18, 0.06, 0.06, 1)
		end
	end)

	self.craftHost.trainProxy = proxy
	return proxy
end

function HPT:HookTrainButtonSetPoint()
	local btn = _G.CraftCreateButton
	if not btn or btn.hptSetPointHooked then
		return
	end
	btn.hptSetPointHooked = true
	hooksecurefunc(btn, "SetPoint", function()
		if not HPT.craftSkinned or HPT._capturingTrain or HPT._trainReentry then
			return
		end
		HPT._trainReentry = true
		HPT:PinTrainButtonNow()
		HPT._trainReentry = false
	end)
	hooksecurefunc(btn, "SetParent", function(self)
		if not HPT.craftSkinned or HPT._capturingTrain or HPT._trainReentry then
			return
		end
		local proxy = HPT.craftHost and HPT.craftHost.trainProxy
		if proxy and self:GetParent() ~= proxy then
			HPT._trainReentry = true
			HPT:PinTrainButtonNow()
			HPT._trainReentry = false
		end
	end)
end

function HPT:SyncProfessionPlusTrainOverlay(btn)
	local overlay = (btn and btn.secureOverlay) or _G["CraftCreateButton_PPTOverlay"]
	if not overlay then
		return
	end
	if self.craftSkinned then
		overlay:Hide()
		overlay:EnableMouse(false)
		overlay:SetAlpha(0)
		overlay:ClearAllPoints()
		overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -5000, -5000)
	else
		overlay:SetAlpha(1)
		overlay:EnableMouse(true)
		if btn then
			overlay:ClearAllPoints()
			overlay:SetAllPoints(btn)
		end
		overlay:Show()
	end
end

function HPT:PinTrainButtonNow()
	local btn = _G.CraftCreateButton
	local footer = self.craftHost and self.craftHost.footer
	if not btn or not CraftFrame or not footer then
		return
	end

	local proxy = self:EnsureTrainProxy()
	local slot = self.craftHost.trainSlot
	if not proxy then
		return
	end

	-- Park Cancel off-screen so ProfessionPlus "left of Cancel" anchors don't show a ghost control
	if CraftCancelButton then
		self._capturingTrain = true
		CraftCancelButton:SetParent(footer)
		CraftCancelButton:ClearAllPoints()
		CraftCancelButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -5000, -5000)
		CraftCancelButton:SetSize(1, 1)
		CraftCancelButton:SetAlpha(0)
		CraftCancelButton:EnableMouse(false)
		CraftCancelButton:Hide()
		self._capturingTrain = false
	end

	self._capturingTrain = true

	-- Visible Train proxy — vertically centered in the footer
	proxy:SetParent(footer)
	proxy:ClearAllPoints()
	proxy:SetPoint("RIGHT", footer, "RIGHT", -6, 0)
	proxy:SetSize(TRAIN_BTN_W, TRAIN_BTN_H)
	proxy:SetFrameStrata(footer:GetFrameStrata())
	proxy:SetFrameLevel(footer:GetFrameLevel() + 80)
	proxy:Show()
	proxy:EnableMouse(true)

	if slot then
		slot:Hide()
	end

	-- Real Blizzard button: invisible, under proxy, still /click-able
	btn:SetParent(proxy)
	btn:ClearAllPoints()
	btn:SetAllPoints(proxy)
	btn:SetFrameLevel(proxy:GetFrameLevel() - 1)
	btn:SetAlpha(0)
	btn:EnableMouse(false)
	btn:Show()
	if self.apply and self.apply.waiting then
		btn:Enable()
	end

	-- Mirror enabled state onto proxy label (theory templates force locked)
	self:UpdateTrainButtonState()

	self._capturingTrain = false
	self:SyncProfessionPlusTrainOverlay(btn)

	if CraftFramePortrait then
		CraftFramePortrait:SetAlpha(0)
		CraftFramePortrait:Hide()
	end
end

-- Grey out / block Train while viewing a theory template (train is Current Pet only).
function HPT:UpdateTrainButtonState()
	local proxy = self.craftHost and self.craftHost.trainProxy
	local btn = _G.CraftCreateButton
	if not proxy then
		return
	end

	local canTrain = self:IsCurrentPetActive() and UnitExists("pet")
	proxy.hptTrainLocked = not canTrain

	if not canTrain then
		-- Keep mouse for tooltip; clear macro so clicks do nothing
		proxy:SetAttribute("macrotext", "")
		if proxy.Enable then
			proxy:Enable()
		end
		proxy:EnableMouse(true)
		if proxy.label then
			proxy.label:SetTextColor(0.45, 0.45, 0.45)
		end
		if proxy.bg then
			proxy.bg:SetColorTexture(0.12, 0.12, 0.12, 1)
		end
		if proxy.edge then
			proxy.edge:SetColorTexture(0.35, 0.35, 0.35, 1)
		end
		if btn then
			btn:Disable()
			btn:EnableMouse(false)
		end
		return
	end

	-- Restore secure click-through to Blizzard Train
	proxy:SetAttribute("macrotext", "/click CraftCreateButton")
	if proxy.Enable then
		proxy:Enable()
	end
	proxy:EnableMouse(true)
	if proxy.edge then
		proxy.edge:SetColorTexture(0.75, 0.15, 0.15, 1)
	end

	if btn and btn:IsEnabled() then
		if proxy.label then
			proxy.label:SetTextColor(1, 0.25, 0.25)
		end
		if proxy.bg then
			proxy.bg:SetColorTexture(0.18, 0.06, 0.06, 1)
		end
	else
		if proxy.label then
			proxy.label:SetTextColor(0.45, 0.45, 0.45)
		end
		if proxy.bg then
			proxy.bg:SetColorTexture(0.12, 0.12, 0.12, 1)
		end
	end

	-- Re-enable Blizzard button when assist is waiting on a selection
	if btn and self.apply and self.apply.waiting then
		btn:Enable()
		if proxy.label then
			proxy.label:SetTextColor(1, 0.25, 0.25)
		end
		if proxy.bg then
			proxy.bg:SetColorTexture(0.18, 0.06, 0.06, 1)
		end
	end
end

function HPT:CaptureCraftTrainButton()
	local btn = _G.CraftCreateButton
	if not btn or not CraftFrame then
		return
	end

	self:HookTrainButtonSetPoint()

	if not savedButton.parent then
		savedButton.parent = btn:GetParent()
		savedButton.points = {}
		for i = 1, btn:GetNumPoints() do
			local point, relativeTo, relativePoint, x, y = btn:GetPoint(i)
			savedButton.points[i] = { point, relativeTo, relativePoint, x, y }
		end
		savedButton.width = btn:GetWidth()
		savedButton.height = btn:GetHeight()
		savedButton.frameLevel = btn:GetFrameLevel()
	end

	self:PinTrainButtonNow()

	local footer = self.craftHost and self.craftHost.footer
	if footer and not footer.hptPinScript then
		footer.hptPinScript = true
		footer:SetScript("OnUpdate", function(self, elapsed)
			if not HPT.craftSkinned then
				return
			end
			self.hptPinElapsed = (self.hptPinElapsed or 0) + elapsed
			if self.hptPinElapsed < 0.15 then
				return
			end
			self.hptPinElapsed = 0

			local proxy = HPT.craftHost and HPT.craftHost.trainProxy
			local b = _G.CraftCreateButton
			if not proxy or not b then
				return
			end

			-- Keep proxy parked in the footer corner
			local _, rel = proxy:GetPoint(1)
			if rel ~= self or not proxy:IsShown() then
				HPT:PinTrainButtonNow()
				return
			end

			-- Keep real button hidden under proxy; re-hide PPT overlay if it resurfaces
			if b:GetParent() ~= proxy or b:GetAlpha() > 0.05 then
				HPT:PinTrainButtonNow()
				return
			end
			local overlay = b.secureOverlay or _G["CraftCreateButton_PPTOverlay"]
			if overlay and (overlay:IsShown() or overlay:GetAlpha() > 0.05) then
				HPT:SyncProfessionPlusTrainOverlay(b)
			end

			-- Refresh enabled look
			if proxy.label then
				if b:IsEnabled() then
					proxy.label:SetTextColor(1, 0.25, 0.25)
				else
					proxy.label:SetTextColor(0.45, 0.45, 0.45)
				end
			end
		end)
	end
end

function HPT:RestoreCraftTrainButton()
	local btn = _G.CraftCreateButton
	local footer = self.craftHost and self.craftHost.footer
	if footer then
		footer:SetScript("OnUpdate", nil)
		footer.hptPinScript = nil
	end
	if CraftFrame and CraftFrame.hptPinScript then
		CraftFrame:SetScript("OnUpdate", nil)
		CraftFrame.hptPinScript = nil
	end
	if self.craftHost and self.craftHost.trainProxy then
		self.craftHost.trainProxy:Hide()
		self.craftHost.trainProxy:EnableMouse(false)
	end
	if CraftCancelButton then
		CraftCancelButton:SetAlpha(1)
		CraftCancelButton:EnableMouse(true)
	end
	if not btn or not savedButton.parent then
		local overlay = (btn and btn.secureOverlay) or _G["CraftCreateButton_PPTOverlay"]
		if overlay then
			overlay:SetAlpha(1)
			overlay:EnableMouse(true)
			overlay:Show()
		end
		return
	end
	self._capturingTrain = true
	btn:SetParent(savedButton.parent)
	btn:ClearAllPoints()
	for _, p in ipairs(savedButton.points or {}) do
		btn:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
	if savedButton.width then
		btn:SetWidth(savedButton.width)
	end
	if savedButton.height then
		btn:SetHeight(savedButton.height)
	end
	if savedButton.frameLevel then
		btn:SetFrameLevel(savedButton.frameLevel)
	end
	btn:SetAlpha(1)
	btn:EnableMouse(true)
	self._capturingTrain = false
	wipe(savedButton)
	if self.craftHost and self.craftHost.trainSlot and self.craftHost.trainSlot.placeholder then
		self.craftHost.trainSlot.placeholder:Show()
	end
	local overlay = (btn and btn.secureOverlay) or _G["CraftCreateButton_PPTOverlay"]
	if overlay then
		overlay:SetAlpha(1)
		overlay:EnableMouse(true)
		overlay:ClearAllPoints()
		overlay:SetAllPoints(btn)
		overlay:Show()
	end
end

-- Always reflect the live plan (same source as /hpt plan), not a stale apply step.
function HPT:UpdateCraftNextLabel()
	if not self.craftHost or not self.craftHost.nextLabel then
		return
	end
	local label = self.craftHost.nextLabel
	if not self:IsCurrentPetActive() then
		label:SetText("Next: |cff888888switch to Current Pet (or Apply template) to train|r")
		self:UpdateTrainButtonState()
		return
	end
	local plan = select(1, self:BuildApplyPlan())
	if plan and plan[1] then
		local n = #plan
		label:SetText(("Next: |cffffffff%s Rank %d|r  (|cffffff00%d left|r)"):format(
			plan[1].ability, plan[1].trainRank, n))
	else
		label:SetText("Next: |cff888888nothing to train for Current Pet|r")
	end
	self:UpdateTrainButtonState()
end

-- Keep assisted selection synced when the template/plan changes.
function HPT:SyncAssistToPlan()
	if not self.craftSkinned or not self:IsBeastTrainingOpen() then
		return
	end
	if not self:IsCurrentPetActive() then
		self:UpdateCraftNextLabel()
		if self.apply.active then
			self:StopApply(nil)
		end
		return
	end
	local plan = select(1, self:BuildApplyPlan())
	self:UpdateCraftNextLabel()
	if not plan or #plan == 0 then
		if self.apply.active then
			self:StopApply(nil)
		end
		return
	end
	local first = plan[1]
	local needRestart = not self.apply.active
		or self.apply.pendingAbility ~= first.ability
		or (self.apply.pendingRank or 0) ~= first.trainRank
	if needRestart then
		if self.apply.active then
			self.apply.active = false
			self.apply.waiting = false
			self.apply.queue = nil
			self.apply.step = 0
		end
		self:StartApply(true)
	end
end

function HPT:ShowCraftOverlay()
	if not IsPetCraftOpen() or not CraftFrame then
		return
	end
	self:CreateCraftOverlay()
	self:CreateUI()
	self:SkinCraftFrameForPet()

	local host = self.craftHost
	local footer = host.footer

	-- Footer pinned to absolute bottom of CraftFrame (above planner content)
	footer:SetParent(CraftFrame)
	footer:ClearAllPoints()
	footer:SetPoint("BOTTOMLEFT", CraftFrame, "BOTTOMLEFT", 8, 6)
	footer:SetPoint("BOTTOMRIGHT", CraftFrame, "BOTTOMRIGHT", -8, 6)
	footer:SetHeight(64)
	footer:SetFrameStrata(CraftFrame:GetFrameStrata())
	footer:SetFrameLevel(CraftFrame:GetFrameLevel() + 250)
	footer:Show()

	-- Planner fills everything above the footer
	host:SetParent(CraftFrame)
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", 8, -36)
	host:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 2)
	host:SetFrameLevel(CraftFrame:GetFrameLevel() + 40)
	host:Show()

	-- Embed planner content into CraftFrame host (no second window)
	local f = self.frame
	if self.SetPlannerEmbedded then
		self:SetPlannerEmbedded(true)
	end
	f:SetParent(host)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", 0, 0)
	f:SetPoint("BOTTOMRIGHT", 0, 0)
	f:SetFrameStrata(CraftFrame:GetFrameStrata())
	f:SetFrameLevel(host:GetFrameLevel() + 5)
	-- Opaque fill so nothing under the planner bleeds through gaps
	if not f.embedFill then
		local fill = f:CreateTexture(nil, "BACKGROUND")
		fill:SetAllPoints()
		fill:SetColorTexture(0.07, 0.07, 0.07, 1)
		f.embedFill = fill
	end
	f.embedFill:Show()
	f:Show()
	self:UpdateUI()

	self:CaptureCraftTrainButton()
	local function reclaim()
		if IsPetCraftOpen() and self.craftSkinned then
			self:SkinCraftFrameForPet()
			self:HideForeignCraftUI()
			self:EnsureCraftCover()
			-- Keep footer at bottom
			if footer then
				footer:SetParent(CraftFrame)
				footer:ClearAllPoints()
				footer:SetPoint("BOTTOMLEFT", CraftFrame, "BOTTOMLEFT", 8, 6)
				footer:SetPoint("BOTTOMRIGHT", CraftFrame, "BOTTOMRIGHT", -8, 6)
				footer:SetHeight(64)
				footer:SetFrameStrata(CraftFrame:GetFrameStrata())
				footer:SetFrameLevel(CraftFrame:GetFrameLevel() + 250)
				footer:Show()
			end
			self:CaptureCraftTrainButton()
			self:UpdateCraftNextLabel()
			if self.craftHost then
				self.craftHost:SetFrameLevel(CraftFrame:GetFrameLevel() + 40)
			end
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, reclaim)
		C_Timer.After(0.05, reclaim)
		C_Timer.After(0.15, reclaim)
		C_Timer.After(0.4, reclaim)
	end

	if self:IsCurrentPetActive() and not self.apply.active then
		local plan = select(1, self:BuildApplyPlan())
		if plan and #plan > 0 then
			self:StartApply(true)
		else
			self:UpdateCraftNextLabel()
		end
	else
		self:UpdateCraftNextLabel()
	end
end

function HPT:HideCraftOverlay()
	if self.apply.active then
		self:StopApply(nil)
	end
	self:RestoreCraftTrainButton()
	self:UnskinCraftFrame()

	if self.craftHost then
		self.craftHost:Hide()
		self.craftHost:SetParent(UIParent)
		if self.craftHost.footer then
			self.craftHost.footer:Hide()
			self.craftHost.footer:SetParent(UIParent)
		end
	end

	if self.frame then
		if self.frame.embedFill then
			self.frame.embedFill:Hide()
		end
		if self.SetPlannerEmbedded then
			self:SetPlannerEmbedded(false)
		end
		self.frame:SetParent(UIParent)
		self.frame:ClearAllPoints()
		self.frame:SetWidth(580)
		self.frame:SetHeight(520)
		self.frame:SetPoint("CENTER")
		self.frame:SetFrameStrata("DIALOG")
		self.frame:Hide()
	end
end

function HPT:OnCraftEvent(event)
	if event == "CRAFT_SHOW" then
		if IsPetCraftOpen() then
			self:ShowCraftOverlay()
		else
			-- Enchanting: leave CraftFrame to ProfessionPlus / Blizzard
			if self.craftSkinned then
				self:HideCraftOverlay()
			end
		end
	elseif event == "CRAFT_CLOSE" then
		self:HideCraftOverlay()
	elseif event == "CRAFT_UPDATE" then
		if IsPetCraftOpen() and self.craftSkinned then
			self:CaptureCraftTrainButton()
			self:UpdateCraftNextLabel()
			if self.UpdateUI then
				self:UpdateUI()
			end
		end
	end
end

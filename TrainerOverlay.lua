local HPT = HunterPetTrainer

-- Planner docked beside the Beast Training window. Only anchors to ClassTrainerFrame:
-- moving, reparenting or re-scripting Blizzard trainer frames risks tainting Train.

local DOCK_WIDTH = 580
local DOCK_MIN_HEIGHT = 520
local FOOTER_HEIGHT = 48

function HPT:CreateTrainerDock()
	if self.dock then
		return self.dock
	end
	local dock = CreateFrame("Frame", "HunterPetTrainerDock", UIParent, "BackdropTemplate")
	dock:SetWidth(DOCK_WIDTH)
	dock:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	dock:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
	dock:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
	dock:EnableMouse(true)
	dock:Hide()
	dock:SetScript("OnHide", function()
		HPT:OnDockHidden()
	end)

	local titleIcon = dock:CreateTexture(nil, "OVERLAY")
	titleIcon:SetSize(22, 22)
	titleIcon:SetPoint("TOPLEFT", 12, -7)
	titleIcon:SetTexture(HPT.ICON)
	dock.titleIcon = titleIcon

	local title = dock:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
	title:SetText("Hunter Pet Trainer")
	dock.title = title

	local close = CreateFrame("Button", nil, dock, "UIPanelCloseButton")
	dock.closeBtn = close
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		HPT.dockDismissed = true
		HPT:HideTrainerOverlay()
	end)

	local footer = CreateFrame("Frame", nil, dock)
	footer:SetPoint("BOTTOMLEFT", 8, 6)
	footer:SetPoint("BOTTOMRIGHT", -8, 6)
	footer:SetHeight(FOOTER_HEIGHT)
	local footerBg = footer:CreateTexture(nil, "BACKGROUND")
	footerBg:SetAllPoints()
	footerBg:SetColorTexture(0.1, 0.1, 0.1, 1)
	footer.bg = footerBg
	dock.footer = footer

	local nextLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	nextLabel:SetPoint("TOPLEFT", 10, -6)
	nextLabel:SetPoint("RIGHT", footer, "RIGHT", -200, 0)
	nextLabel:SetJustifyH("LEFT")
	dock.nextLabel = nextLabel

	local hint = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", nextLabel, "BOTTOMLEFT", 0, -4)
	hint:SetPoint("RIGHT", footer, "RIGHT", -200, 0)
	hint:SetJustifyH("LEFT")
	dock.hint = hint

	if HPT.CreateTrainNextButton then
		HPT:CreateTrainNextButton(footer)
	end

	local host = CreateFrame("Frame", nil, dock)
	host:SetPoint("TOPLEFT", 8, -34)
	host:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
	dock.host = host

	self.dock = dock
	if self.ApplySkin then
		self:ApplySkin()
	end
	return dock
end

function HPT:IsTrainerOverlayShown()
	return self.dock and self.dock:IsVisible() or false
end

-- Always reflects the live plan, not a stale apply step.
function HPT:UpdateNextLabel()
	local dock = self.dock
	if not dock or not dock:IsShown() then
		return
	end
	if not self:IsCurrentPetActive() then
		dock.nextLabel:SetText("Next: |cff888888switch to Current Pet (or apply a template) to train|r")
		dock.hint:SetText("Saved templates are for planning. Training follows the Current Pet plan.")
		return
	end
	if not UnitExists("pet") then
		dock.nextLabel:SetText("Next: |cff888888summon your pet|r")
		dock.hint:SetText("")
		return
	end
	local plan = select(1, self:BuildApplyPlan())
	if plan and plan[1] then
		dock.nextLabel:SetText(("Next: |cffffffff%s Rank %d|r  (|cffffff00%d left|r)"):format(
			plan[1].ability, plan[1].trainRank, #plan))
		local warning = self.GetTrainNextWarning and self:GetTrainNextWarning()
		if warning then
			dock.hint:SetText("|cffff4444" .. warning .. "|r")
		else
			dock.hint:SetText("Press the button twice: once to select the row, once to train it.")
		end
	else
		dock.nextLabel:SetText("Next: |cff888888nothing to train for Current Pet|r")
		dock.hint:SetText("Raise ranks in the planner to queue more training.")
	end
end

-- Keep the assist queue in step when the template or plan changes.
function HPT:SyncAssistToPlan()
	if not self:IsTrainerOverlayShown() or not self:IsBeastTrainingOpen() then
		return
	end
	if not self:IsCurrentPetActive() then
		if self.apply.active then
			self:StopApply(nil)
		end
		self:UpdateNextLabel()
		return
	end
	local plan = select(1, self:BuildApplyPlan())
	if not plan or #plan == 0 then
		if self.apply.active then
			self:StopApply(nil)
		end
		self:UpdateNextLabel()
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
	self:UpdateNextLabel()
end

function HPT:ShowTrainerOverlay()
	local trainer = _G.ClassTrainerFrame
	-- The dock holds a secure button, so it can't be shown or moved in combat.
	if not trainer or not self:IsBeastTrainingOpen() or InCombatLockdown() then
		return
	end
	local dock = self:CreateTrainerDock()
	self:CreateUI()

	-- Child of the trainer so it hides with it; TRAINER_CLOSED does not fire for the Beast Training spell.
	dock:SetParent(trainer)
	dock:ClearAllPoints()
	dock:SetPoint("TOPLEFT", trainer, "TOPRIGHT", 2, 0)
	dock:SetHeight(math.max(DOCK_MIN_HEIGHT, trainer:GetHeight() or 0))
	dock:SetFrameStrata(trainer:GetFrameStrata())
	dock:SetFrameLevel(trainer:GetFrameLevel() + 5)
	dock:Show()

	local f = self.frame
	if not f.hptDockHideHooked then
		f.hptDockHideHooked = true
		-- Escape hides the planner (UISpecialFrames); take the empty dock with it.
		f:HookScript("OnHide", function(frame)
			if frame.embedded and HPT:IsTrainerOverlayShown() then
				HPT.dockDismissed = true
				HPT:HideTrainerOverlay()
			end
		end)
	end
	if not f.embedded then
		f.hptStandaloneSize = { f:GetWidth(), f:GetHeight() }
	end
	self:SetPlannerEmbedded(true)
	f:SetParent(dock.host)
	f:ClearAllPoints()
	f:SetAllPoints(dock.host)
	f:SetFrameStrata(dock:GetFrameStrata())
	f:SetFrameLevel(dock:GetFrameLevel() + 2)
	f:Show()
	self:UpdateUI()
	self:SyncAssistToPlan()
end

function HPT:HideTrainerOverlay()
	if self.dock and not InCombatLockdown() then
		self.dock:Hide()
	end
	self:OnDockHidden()
end

-- Runs when the dock is hidden directly or because the trainer window closed.
function HPT:OnDockHidden()
	-- A parent hide leaves the dock flagged shown; clear it so the next open re-embeds the planner.
	if self.dock and self.dock:IsShown() and not InCombatLockdown() then
		self.dock:Hide()
	end
	if self.apply.active then
		self:StopApply(nil)
	end
	local trainer = _G.ClassTrainerFrame
	if not trainer or not trainer:IsShown() then
		self:InvalidateTrainerCache()
		self:RestoreTrainerFilters()
	end
	local f = self.frame
	if f and f.embedded then
		self:SetPlannerEmbedded(false)
		f:SetParent(UIParent)
		f:ClearAllPoints()
		if f.hptStandaloneSize then
			f:SetSize(f.hptStandaloneSize[1], f.hptStandaloneSize[2])
		end
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:Hide()
	end
end

-- Called from Core after the trainer events settle (the TP label is set a frame later).
function HPT:OnTrainerOverlayEvent(event)
	if event == "TRAINER_SHOW" then
		self.dockDismissed = false
	end
	if self:IsBeastTrainingOpen() then
		if not self.dockDismissed and not self:IsTrainerOverlayShown() then
			self:ShowTrainerOverlay()
		elseif self:IsTrainerOverlayShown() then
			self:SyncAssistToPlan()
		end
	elseif self:IsTrainerOverlayShown() then
		self:HideTrainerOverlay()
	end
end

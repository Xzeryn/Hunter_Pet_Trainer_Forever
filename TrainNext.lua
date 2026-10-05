local HPT = HunterPetTrainer

-- "Train next": one secure button pressed twice. Press 1 clicks the planned Beast Training
-- row, press 2 clicks Blizzard's Train. Only secure clicks keep the selection untainted;
-- never call ClassTrainer_SetSelection, SelectTrainerService or BuyTrainerService here.

local BUTTON_WIDTH = 184
local REFRESH_INTERVAL = 0.25
local VERIFY_DELAY = 0.3

-- Register only the half of the click the secure template acts on, so PostClick runs once per press.
local CLICK_HALF = GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp"

local button, glow
local mode = "select"
local target -- { ability, rank, row }
local warning
local needsScroll

local function RankNumber(text)
	return tonumber((text or ""):match("(%d+)"))
end

local function CollectTexts(frame, out, depth)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetText then
			local text = region:GetText()
			if text and text ~= "" then
				out[#out + 1] = text
			end
		end
	end
	if depth < 2 then
		for _, child in ipairs({ frame:GetChildren() }) do
			CollectTexts(child, out, depth + 1)
		end
	end
	return out
end

-- Trainer rows are unnamed, recycled ScrollBox buttons: match by visible name and rank text.
function HPT:FindTrainerRowButton(name, rank)
	local trainer = _G.ClassTrainerFrame
	if not trainer then
		return nil
	end
	local found
	local function scan(frame, depth)
		if found or depth > 12 then
			return
		end
		if frame:IsVisible() and frame:IsObjectType("Button") and frame:GetScript("OnClick") then
			local hasName, hasRank = false, false
			for _, text in ipairs(CollectTexts(frame, {}, 0)) do
				if text == name then
					hasName = true
				elseif RankNumber(text:match("[Rr]ank%s*%d+")) == rank then
					hasRank = true
				end
			end
			if hasName and hasRank then
				found = frame
				return
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			scan(child, depth + 1)
		end
	end
	scan(trainer.ScrollBox or trainer, 0)
	return found
end

local function SelectionMatchesTarget()
	local sel = GetTrainerSelectionIndex and GetTrainerSelectionIndex()
	if not sel or not target then
		return false
	end
	local name, _, _, _, rankText = GetTrainerServiceInfo(sel)
	return name == target.ability and RankNumber(rankText) == target.rank
end

local function ShowGlow(row)
	if not glow then
		return
	end
	if row then
		glow:ClearAllPoints()
		glow:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 2)
		glow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -2)
		glow:Show()
	else
		glow:Hide()
	end
end

local function SetLabel(text, enabled)
	button:SetText(text)
	if enabled then
		button:Enable()
	else
		button:Disable()
	end
end

local function ApplyMode()
	if InCombatLockdown() then
		return
	end
	if not target or not target.row then
		button:SetAttribute("clickbutton", nil)
		return
	end
	if mode == "train" then
		local train = _G.ClassTrainerTrainButton
		button:SetAttribute("clickbutton", train)
		if train and train:IsEnabled() then
			SetLabel(("Train %s %d"):format(target.ability, target.rank), true)
		else
			SetLabel("Train unavailable", false)
		end
	else
		button:SetAttribute("clickbutton", target.row)
		SetLabel(("Select %s %d"):format(target.ability, target.rank), true)
	end
end

function HPT:RefreshTrainNext(allowFilterAssist)
	if not button or not button:IsVisible() or InCombatLockdown() then
		return
	end
	local step
	if self:IsCurrentPetActive() and UnitExists("pet") and self:IsBeastTrainingOpen() then
		step = select(1, self:BuildApplyPlan())[1]
	end
	if not step then
		target = nil
		mode = "select"
		needsScroll = nil
		button:SetAttribute("clickbutton", nil)
		SetLabel("Nothing to train", false)
		ShowGlow(nil)
		return
	end

	if not target or target.ability ~= step.ability or target.rank ~= step.trainRank then
		mode = "select"
		warning = nil
	end
	-- Only on Train next press: hide used/unavailable, then find the row.
	-- The 0.25s timer must not do this — that fights anyone turning those filters back on.
	if allowFilterAssist then
		self:ShowAvailableTrainerFilters()
	end
	target = { ability = step.ability, rank = step.trainRank, row = self:FindTrainerRowButton(step.ability, step.trainRank) }
	if not target.row then
		mode = "select"
		local notify = not needsScroll
		needsScroll = true
		button:SetAttribute("clickbutton", nil)
		SetLabel(("Scroll to %s %d"):format(target.ability, target.rank), true)
		ShowGlow(nil)
		if notify and self.UpdateNextLabel then
			self:UpdateNextLabel()
		end
		return
	end
	local wasScroll = needsScroll
	needsScroll = nil
	if wasScroll and self.UpdateNextLabel then
		self:UpdateNextLabel()
	end
	if mode == "train" and not SelectionMatchesTarget() then
		mode = "select"
	end
	ShowGlow(target.row)
	ApplyMode()
end

local function OnPostClick()
	local pressedIn = mode
	local clickedRow = target and target.row
	C_Timer.After(VERIFY_DELAY, function()
		if InCombatLockdown() or not target then
			return
		end
		if pressedIn == "select" then
			if SelectionMatchesTarget() then
				mode = "train"
				warning = nil
			elseif clickedRow then
				warning = ("Selection didn't match %s %d. Press Select again."):format(target.ability, target.rank)
			end
		else
			mode = "select"
		end
		HPT:RefreshTrainNext()
		if HPT.UpdateNextLabel then
			HPT:UpdateNextLabel()
		end
	end)
end

function HPT:GetTrainNextWarning()
	return warning
end

function HPT:GetTrainNextNeedsScroll()
	return needsScroll
end

function HPT:CreateTrainNextButton(parent)
	if button then
		return button
	end
	button = CreateFrame("Button", "HunterPetTrainerTrainNext", parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	button:SetSize(BUTTON_WIDTH, 28)
	button:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
	button:RegisterForClicks(CLICK_HALF)
	button:SetAttribute("type", "click")
	button:SetScript("PreClick", function()
		if not InCombatLockdown() then
			HPT:RefreshTrainNext(true)
		end
	end)
	button:HookScript("PostClick", OnPostClick)
	button:SetMotionScriptsWhileDisabled(true)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Train next planned rank")
		GameTooltip:AddLine("This press hides already known and unavailable ranks, then selects the planned row. Press again to Train.", 1, 1, 1, true)
		GameTooltip:AddLine("If it still says Scroll to, the rank is not in the shortened list; scroll until you can see it. Filters restore when Beast Training closes.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)

	local elapsed = 0
	button:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			HPT:RefreshTrainNext()
		end
	end)
	button:SetScript("OnShow", function()
		mode = "select"
		target = nil
		warning = nil
		needsScroll = nil
		HPT:RefreshTrainNext()
	end)

	glow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	glow:SetFrameStrata("HIGH")
	glow:EnableMouse(false)
	glow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
	glow:SetBackdropBorderColor(1, 0.82, 0, 1)
	local fill = glow:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetColorTexture(1, 0.82, 0, 0.12)
	glow.fill = fill
	local pulse = glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.35)
	fade:SetDuration(0.6)
	pulse:Play()
	glow:Hide()

	HPT.trainNextButton = button
	HPT.trainNextGlow = glow
	return button
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent", function(_, _, msg)
	if not msg or not msg:find("learned") or not HPT:IsTrainerOverlayShown() then
		return
	end
	-- Beast Training may not fire TRAINER_UPDATE; rebuild from the pet once the spellbook updates.
	C_Timer.After(0.3, function()
		HPT:InvalidateTrainerCache()
		if UnitExists("pet") then
			HPT:SyncCurrentPetPlanFromPet(false)
		end
		mode = "select"
		HPT:RefreshTrainNext()
		if HPT.SyncAssistToPlan then
			HPT:SyncAssistToPlan()
		end
		if HPT.UpdateUI then
			HPT:UpdateUI()
		end
	end)
end)

local HPT = HunterPetTrainer

HPT.apply = {
	active = false,
	queue = nil,
	step = 0,
	waiting = false,
	lastIndex = nil,
	errors = {},
	beforeSpent = nil,
	beforePetRank = nil,
	pendingAbility = nil,
	pendingRank = nil,
}

local function GetSpent()
	local _, total, spent = HPT:GetPetPoints()
	return spent or 0, total or 0
end

function HPT:StopApply(reason)
	if self.apply.active then
		self.apply.active = false
		self.apply.waiting = false
		self.apply.queue = nil
		self.apply.step = 0
		self.apply.pendingAbility = nil
		self.apply.pendingRank = nil
		if reason then
			self:Print(reason)
		end
		if self.UpdateUI then
			self:UpdateUI()
		end
	end
end

-- Records the planned step only. Selecting a trainer row from addon code taints Train
-- (ADDON_ACTION_FORBIDDEN), so the player or a secure button must make the selection.
function HPT:SelectTrainTarget(entry)
	if not entry or not entry.index then
		return false
	end
	self.apply.lastIndex = entry.index
	self.apply.pendingAbility = entry.ability
	self.apply.pendingRank = entry.rank
	self.apply.beforeSpent = select(1, GetSpent())
	self.apply.beforePetRank = (self:GetPetKnownRanks()[entry.ability]) or 0
	self.apply.waiting = true
	return true
end

function HPT:StartApply(quiet)
	if self.apply.active then
		if not quiet then
			self:Print("Apply already running. /hpt stop to cancel.")
		end
		return
	end
	if not self:IsCurrentPetActive() then
		if not quiet then
			self:Print("Train only runs from |cffffffffCurrent Pet|r. Apply a template to Current Pet first, or switch to it.")
		end
		return
	end
	if not UnitExists("pet") then
		self:Print("Summon your pet first.")
		return
	end
	local plan, skipped, err = self:BuildApplyPlan()
	if err then
		self:Print(err)
		return
	end
	if #plan == 0 then
		if not quiet then
			self:Print("Nothing to train.")
		end
		return
	end

	self.apply.active = true
	self.apply.queue = plan
	self.apply.step = 0
	self.apply.waiting = false
	self.apply.errors = {}
	if not quiet then
		self:Print("Assisted apply: %d skill(s). Click Train for each selected skill.", #plan)
		if #skipped > 0 then
			self:Print("%d skill(s) skipped.", #skipped)
		end
	end
	self:ApplyNext()
end

function HPT:ApplyNext()
	if not self.apply.active then
		return
	end
	if not self:IsBeastTrainingOpen() then
		self:StopApply("Beast Training closed — apply stopped.")
		return
	end

	self.apply.step = self.apply.step + 1
	local step = self.apply.queue[self.apply.step]
	if not step then
		self:StopApply("Apply finished.")
		return
	end

	local template = self:GetActiveTemplate()
	local desired = template.ranks[step.ability] or step.desired
	local entry, reason = self:FindBestTrainerEntry(step.ability, desired)
	if not entry or reason ~= "ok" then
		self:Print("Skip %s: %s", step.ability, reason or "unavailable")
		self.apply.waiting = false
		self:ApplyNext()
		return
	end

	self:SelectTrainTarget(entry)
	local left = #self.apply.queue - self.apply.step + 1
	self:Print("Next: |cffffffff%s rank %d|r — select it in the trainer and click |cffffff00Train|r. (%d left)",
		entry.ability, entry.rank, left)
	if self.UpdateNextLabel then
		self:UpdateNextLabel()
	end
	if self.UpdateUI then
		self:UpdateUI()
	end
end

function HPT:OnApplyEvent(event)
	if not self.apply.active or not self.apply.waiting then
		return
	end
	if event == "TRAINER_CLOSED" then
		self:StopApply("Beast Training closed — apply stopped.")
		return
	end
	if event ~= "TRAINER_UPDATE" and event ~= "PET_BAR_UPDATE" and event ~= "SPELLS_CHANGED" then
		return
	end

	local spentNow = select(1, GetSpent())
	local ability = self.apply.pendingAbility
	local petRankNow = ability and (self:GetPetKnownRanks()[ability] or 0) or 0
	local changed = (self.apply.beforeSpent ~= nil and spentNow ~= self.apply.beforeSpent)
		or (self.apply.beforePetRank ~= nil and petRankNow > self.apply.beforePetRank)

	if not changed then
		return
	end

	self.apply.waiting = false
	self:Print("Trained %s (rank now %d).", tostring(ability or "?"), petRankNow)
	if self.UpdateNextLabel then
		self:UpdateNextLabel()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.2, function()
			if self.apply.active then
				-- Rebuild queue from current pet state so Next stays accurate
				local plan = select(1, self:BuildApplyPlan())
				if not plan or #plan == 0 then
					self:StopApply("Apply finished.")
					if self.UpdateNextLabel then
						self:UpdateNextLabel()
					end
					return
				end
				self.apply.queue = plan
				self.apply.step = 0
				self:ApplyNext()
			end
		end)
	else
		self:ApplyNext()
	end
end

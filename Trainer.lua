local HPT = HunterPetTrainer
local D = HunterPetTrainerData

-- Forever shows Beast Training in ClassTrainerFrame. Never call ClassTrainer_SetSelection,
-- SelectTrainerService or BuyTrainerService from here: they taint the trainer and block Train.

local FILTERS = { "used", "available", "unavailable" }
local entryCache
local hunterRankSet -- last full "hunter can teach this" snapshot; kept when filters hide rows

local function RankNumber(text)
	return tonumber((text or ""):match("(%d+)"))
end

function HPT:InvalidateTrainerCache()
	entryCache = nil
end

-- NPC trainers (class and pet) use the same frame with costs in copper and "used" meaning
-- the hunter knows it. Only the Beast Training spell window has the TP label on screen.
function HPT:IsBeastTrainingOpen()
	local f = _G.ClassTrainerFrame
	local label = _G.ClassTrainerFrameTrainingPointsLabel
	return f and f:IsShown() and label and label:IsVisible() and GetNumTrainerServices ~= nil or false
end

function HPT:GetTrainerFilterState()
	local state, allOn = {}, true
	if not GetTrainerServiceTypeFilter then
		return state, true
	end
	for _, key in ipairs(FILTERS) do
		local on = GetTrainerServiceTypeFilter(key) and true or false
		state[key] = on
		allOn = allOn and on
	end
	return state, allOn
end

-- Calling SetTrainerServiceTypeFilter from addon code does not taint Train
-- (all-on: October 1; available-only: October 4). Filters are shared with NPC
-- trainers, so the player's choice is restored on close.
function HPT:RememberTrainerFilters()
	if not self.savedFilters and GetTrainerServiceTypeFilter then
		self.savedFilters = self:GetTrainerFilterState()
	end
end

function HPT:ShowAllTrainerFilters()
	if not SetTrainerServiceTypeFilter or not self:IsBeastTrainingOpen() then
		return false
	end
	self:RememberTrainerFilters()
	local _, allOn = self:GetTrainerFilterState()
	if allOn then
		return false
	end
	for _, key in ipairs(FILTERS) do
		SetTrainerServiceTypeFilter(key, true)
	end
	self:InvalidateTrainerCache()
	return true
end

-- Hide used/unavailable so the planned available rank is on screen for Train next.
-- Do not use ScrollBox APIs: those taint selectedService and block Train (October 4).
function HPT:ShowAvailableTrainerFilters()
	if not SetTrainerServiceTypeFilter or not self:IsBeastTrainingOpen() then
		return false
	end
	self:RememberTrainerFilters()
	local state = self:GetTrainerFilterState()
	if state.available and not state.used and not state.unavailable then
		return false
	end
	SetTrainerServiceTypeFilter("used", false)
	SetTrainerServiceTypeFilter("unavailable", false)
	SetTrainerServiceTypeFilter("available", true)
	self:InvalidateTrainerCache()
	return true
end

-- Run fn with used+available+unavailable on, then put the player's filters back.
-- Does not touch savedFilters (Train next and trainer-close own that).
function HPT:WithAllTrainerFilters(fn)
	if not self:IsBeastTrainingOpen() or not SetTrainerServiceTypeFilter then
		return fn(false, nil)
	end
	local previous, allOn = self:GetTrainerFilterState()
	if not allOn then
		for _, key in ipairs(FILTERS) do
			SetTrainerServiceTypeFilter(key, true)
		end
		self:InvalidateTrainerCache()
	end
	local ok, a, b, c = pcall(fn, true, previous)
	if not allOn then
		for _, key in ipairs(FILTERS) do
			SetTrainerServiceTypeFilter(key, previous[key] and true or false)
		end
		self:InvalidateTrainerCache()
	end
	if not ok then
		error(a)
	end
	return a, b, c
end

function HPT:RestoreTrainerFilters()
	local saved = self.savedFilters
	if not saved then
		return
	end
	self.savedFilters = nil
	if not SetTrainerServiceTypeFilter then
		return
	end
	for _, key in ipairs(FILTERS) do
		pcall(SetTrainerServiceTypeFilter, key, saved[key] and true or false)
	end
end

function HPT:GetTrainerServiceSpellId(index)
	local tip = self:EnsureScanTooltip()
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok = pcall(tip.SetTrainerService, tip, index)
	local spellId
	if ok and tip.GetSpell then
		spellId = select(2, tip:GetSpell())
	end
	tip:Hide()
	return spellId
end

-- entry = { index, name, ability, sub, rank, status, cost, reqLevel, spellId }
function HPT:GetTrainerEntries()
	if not self:IsBeastTrainingOpen() then
		return {}
	end
	if entryCache then
		return entryCache
	end
	local list = {}
	for i = 1, GetNumTrainerServices() or 0 do
		local name, status, _, reqLevel, rankText = GetTrainerServiceInfo(i)
		if name and status ~= "header" then
			local spellId = self:GetTrainerServiceSpellId(i)
			local byId = spellId and self:RankForSpellId(spellId)
			table.insert(list, {
				index = i,
				name = name,
				ability = byId and byId.ability or name,
				sub = rankText or "",
				rank = RankNumber(rankText) or (byId and byId.rank) or 1,
				status = status,
				cost = GetTrainerServiceCost(i) or 0,
				reqLevel = (GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i)) or reqLevel or 0,
				spellId = spellId,
			})
		end
	end
	entryCache = list
	return list
end

-- Ranks the pet already has, per the trainer's "used" rows.
function HPT:GetKnownTrainerRanks()
	local known = {}
	for _, entry in ipairs(self:GetTrainerEntries()) do
		if entry.status == "used" and D.Abilities[entry.ability] then
			known[entry.ability] = math.max(known[entry.ability] or 0, entry.rank)
		end
	end
	return known
end

-- Every rank the trainer lists (the hunter can teach it). Hidden rows are missing when a filter is off.
function HPT:GetTrainerRankSet()
	local set = {}
	for _, entry in ipairs(self:GetTrainerEntries()) do
		if D.Abilities[entry.ability] then
			set[entry.ability] = set[entry.ability] or {}
			set[entry.ability][entry.rank] = true
		end
	end
	return set
end

function HPT:ClearHunterKnownRankSet()
	hunterRankSet = nil
end

-- White vs red rank numbers: white = the hunter can teach it. A filtered list
-- hides rows, so we keep the last complete snapshot from this Beast Training
-- session instead of treating missing rows as known.
function HPT:GetHunterKnownRankSet()
	if not self:IsBeastTrainingOpen() then
		return nil
	end
	local live = self:GetTrainerRankSet()
	local _, allOn = self:GetTrainerFilterState()
	if allOn then
		hunterRankSet = live
		return hunterRankSet
	end
	if not hunterRankSet then
		return nil
	end
	for ability, ranks in pairs(live) do
		hunterRankSet[ability] = hunterRankSet[ability] or {}
		for rank in pairs(ranks) do
			hunterRankSet[ability][rank] = true
		end
	end
	return hunterRankSet
end

-- exactOnly=true: never fall back to a different rank (used for tooltips).
function HPT:FindTrainerEntry(abilityName, preferredRank, exactOnly)
	if not abilityName then
		return nil
	end
	local best, exact
	for _, entry in ipairs(self:GetTrainerEntries()) do
		if entry.ability == abilityName then
			if preferredRank and entry.rank == preferredRank then
				exact = entry
			end
			if not best or entry.rank > best.rank then
				best = entry
			end
		end
	end
	if exact or exactOnly then
		return exact
	end
	return best
end

-- Highest listed rank <= desiredRank that the pet can learn now.
-- Returns entry or nil, plus reason string ("ok" when trainable).
function HPT:FindBestTrainerEntry(abilityName, desiredRank, petRanks)
	desiredRank = desiredRank or 0
	if desiredRank <= 0 then
		return nil, "not in template"
	end
	petRanks = petRanks or self:GetPetKnownRanks()
	local petRank = petRanks[abilityName] or 0
	if petRank >= desiredRank then
		return nil, "pet already at or above target"
	end

	local petLevel = UnitExists("pet") and UnitLevel("pet") or nil
	local best, bestTooHigh
	local listedMax = 0
	for _, entry in ipairs(self:GetTrainerEntries()) do
		if entry.ability == abilityName then
			listedMax = math.max(listedMax, entry.rank)
			if entry.status ~= "used" and entry.rank <= desiredRank and entry.rank > petRank then
				local req = entry.reqLevel or 0
				local tooLow = entry.status == "unavailable" or (petLevel and req > 0 and petLevel < req)
				if tooLow then
					if not bestTooHigh or entry.rank > bestTooHigh.rank then
						bestTooHigh = entry
					end
				elseif not best or entry.rank > best.rank then
					best = entry
				end
			end
		end
	end

	if best then
		return best, "ok"
	end
	if listedMax == 0 then
		local _, allOn = self:GetTrainerFilterState()
		if not allOn then
			return nil, "not listed (tick every Filters option)"
		end
		return nil, "you have not learned this ability yet"
	elseif bestTooHigh then
		return bestTooHigh, ("pet level too low for rank %d (need %d)"):format(bestTooHigh.rank, bestTooHigh.reqLevel or 0)
	elseif listedMax <= petRank then
		return nil, "no higher rank available than pet already has"
	end
	return nil, ("no trainable rank <= %d (trainer lists up to %d)"):format(desiredRank, listedMax)
end

function HPT:BuildApplyPlan(template)
	template = template or self:GetActiveTemplate()
	local petRanks = self:GetPetKnownRanks()
	local plan, skipped = {}, {}

	if not self:IsBeastTrainingOpen() then
		return plan, skipped, "Beast Training is not open."
	end

	for _, ability in ipairs(D.AbilityOrder) do
		local desired = template.ranks[ability] or 0
		if desired > 0 and not self:IsInfoOnlyAbility(ability) and self:AbilityAvailableForFamily(ability, template.family) then
			local entry, reason = self:FindBestTrainerEntry(ability, desired, petRanks)
			if entry and reason == "ok" then
				table.insert(plan, {
					ability = ability,
					desired = desired,
					trainRank = entry.rank,
					index = entry.index,
					cost = entry.cost,
				})
			else
				table.insert(skipped, {
					ability = ability,
					desired = desired,
					reason = reason or "unknown",
					wouldTrain = entry and entry.rank or nil,
				})
			end
		elseif desired > 0 and not self:IsInfoOnlyAbility(ability) then
			table.insert(skipped, {
				ability = ability,
				desired = desired,
				reason = "not available for family " .. tostring(template.family),
			})
		end
	end

	return plan, skipped, nil
end

local function ShowSpellIdOnTooltip(spellId)
	if not spellId or not GameTooltip.SetSpellByID then
		return false
	end
	local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellId)
	return ok and GameTooltip:NumLines() > 0
end

-- preferredRank: always that exact rank, never a different learned rank.
-- Returns true if a live trainer/spell tip was shown (vs static data fallback).
function HPT:ShowAbilityTooltip(owner, abilityName, preferredRank)
	if not owner or not abilityName then
		return false
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()

	local shown = false
	local entry = self:FindTrainerEntry(abilityName, preferredRank, true)
	if entry and GameTooltip.SetTrainerService then
		local ok = pcall(GameTooltip.SetTrainerService, GameTooltip, entry.index)
		shown = ok and GameTooltip:NumLines() > 0
	end

	if not shown and preferredRank then
		shown = ShowSpellIdOnTooltip(D.GetRankSpellId and D:GetRankSpellId(abilityName, preferredRank))
	end

	if not shown then
		local info = D.Abilities[abilityName]
		GameTooltip:SetText(abilityName, 1, 0.82, 0)
		if preferredRank and info and info.ranks[preferredRank] then
			local r = info.ranks[preferredRank]
			GameTooltip:AddLine(("Rank %d"):format(preferredRank), 0.9, 0.9, 0.9)
			GameTooltip:AddLine(("Req pet level: %d"):format(r.level), 1, 1, 1)
			GameTooltip:AddLine(("Training points: %d"):format(r.cost), 1, 1, 1)
		elseif info then
			local maxRank = 0
			for r in pairs(info.ranks) do
				if r > maxRank then maxRank = r end
			end
			GameTooltip:AddLine(("%d ranks"):format(maxRank), 0.75, 0.75, 0.75)
		end
	end

	GameTooltip:Show()
	return shown
end

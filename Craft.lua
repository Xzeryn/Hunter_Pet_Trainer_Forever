local HPT = HunterPetTrainer
local D = HunterPetTrainerData

local function ParseRank(subSpellName, craftName)
	if subSpellName and subSpellName ~= "" then
		local n = tonumber(subSpellName:match("(%d+)"))
		if n then
			return n
		end
	end
	if craftName then
		local n = tonumber(craftName:match("(%d+)%s*$"))
		if n then
			return n
		end
	end
	return 1
end

function HPT:IsBeastTrainingOpen()
	if not GetNumCrafts or not GetCraftInfo then
		return false
	end
	if CraftIsPetTraining then
		local ok, isPet = pcall(CraftIsPetTraining)
		if ok and isPet then
			return true
		end
	end
	-- Fallback: pet training points appear on craft entries
	local n = GetNumCrafts()
	if not n or n < 1 then
		return false
	end
	for i = 1, math.min(n, 20) do
		local _, _, craftType, _, _, trainingPointCost = GetCraftInfo(i)
		if craftType ~= "header" and trainingPointCost ~= nil then
			return true
		end
	end
	return false
end

function HPT:GetCraftEntries()
	local list = {}
	if not self:IsBeastTrainingOpen() then
		return list
	end
	-- Expand headers so every rank is visible
	local n = GetNumCrafts() or 0
	if ExpandCraftSkillLine then
		for i = 1, n do
			local _, _, craftType, _, isExpanded = GetCraftInfo(i)
			if craftType == "header" and not isExpanded then
				pcall(ExpandCraftSkillLine, i)
			end
		end
		n = GetNumCrafts() or 0
	end
	for i = 1, n do
		local name, sub, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(i)
		if name and craftType ~= "header" then
			local rank = ParseRank(sub, name)
			-- Prefer clean ability name without trailing rank digits if present
			local ability = name:gsub("%s*%d+%s*$", ""):gsub("%s+$", "")
			if not D.Abilities[ability] and D.Abilities[name] then
				ability = name
			end
			local cost = trainingPointCost
			local reqLevel = requiredLevel
			-- Anniversary often returns craftType "none" and may omit cost/req; fall back to static data
			local static = D.Abilities[ability] and D.Abilities[ability].ranks[rank]
			if (not cost or cost == 0) and static and static.cost and static.cost > 0 then
				cost = static.cost
			end
			if (not reqLevel or reqLevel == 0) and static and static.level then
				reqLevel = static.level
			end
			table.insert(list, {
				index = i,
				name = name,
				ability = ability,
				sub = sub or "",
				rank = rank,
				craftType = craftType,
				numAvailable = numAvailable,
				cost = cost or 0,
				reqLevel = reqLevel or 0,
				rawCost = trainingPointCost,
				rawReq = requiredLevel,
			})
		end
	end
	return list
end

function HPT:GetKnownCraftRanks()
	-- Highest rank of each ability present in the Beast Training list (hunter knows it)
	local known = {}
	for _, entry in ipairs(self:GetCraftEntries()) do
		local ability = entry.ability
		if D.Abilities[ability] then
			known[ability] = math.max(known[ability] or 0, entry.rank)
		end
	end
	return known
end

-- Exact ranks present in the Beast Training craft list (not inferred from max).
-- Hunters can know Gore 8/9 without knowing Gore 1-7.
function HPT:GetKnownCraftRankSet()
	local known = {}
	for _, entry in ipairs(self:GetCraftEntries()) do
		local ability = entry.ability
		if D.Abilities[ability] then
			known[ability] = known[ability] or {}
			known[ability][entry.rank] = true
		end
	end
	return known
end

-- Prefer an exact rank craft line; otherwise highest known rank for that ability.
-- exactOnly=true: never fall back to a different rank (used for tooltips).
function HPT:FindCraftEntryForAbility(abilityName, preferredRank, exactOnly)
	if not abilityName or not self:IsBeastTrainingOpen() then
		return nil
	end
	local best
	local exact
	for _, entry in ipairs(self:GetCraftEntries()) do
		if entry.ability == abilityName then
			if preferredRank and entry.rank == preferredRank then
				exact = entry
			end
			if not best or entry.rank > best.rank then
				best = entry
			end
		end
	end
	if exact then
		return exact
	end
	if exactOnly then
		return nil
	end
	return best
end

local function ShowSpellIdOnTooltip(spellId)
	if not spellId then
		return false
	end
	if GameTooltip.SetSpellByID then
		local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellId)
		if ok and GameTooltip:NumLines() > 0 then
			return true
		end
	end
	if GetSpellLink then
		local link = GetSpellLink(spellId)
		if link then
			local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
			if ok and GameTooltip:NumLines() > 0 then
				return true
			end
		end
	end
	local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(spellId))
	return ok and GameTooltip:NumLines() > 0
end

-- Spellbook / craft / spell-ID tooltip for ability hover.
-- preferredRank: always that exact rank — never a different learned rank.
-- Returns true if a live craft/spell tip was shown (vs static data fallback).
function HPT:ShowAbilityTooltip(owner, abilityName, preferredRank)
	if not owner or not abilityName then
		return false
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()

	local shown = false
	-- 1) Exact Beast Training craft line (hunter has learned this rank)
	local entry = self:FindCraftEntryForAbility(abilityName, preferredRank, true)
	if entry and entry.index then
		if GameTooltip.SetCraftSpell then
			local ok = pcall(GameTooltip.SetCraftSpell, GameTooltip, entry.index)
			shown = ok and GameTooltip:NumLines() > 0
		end
		if not shown and GameTooltip.SetCraftItem then
			local ok = pcall(GameTooltip.SetCraftItem, GameTooltip, entry.index)
			shown = ok and GameTooltip:NumLines() > 0
		end
	end

	-- 2) Spell ID — works for ranks not yet in Beast Training
	if not shown and preferredRank then
		local spellId = D.GetRankSpellId and D:GetRankSpellId(abilityName, preferredRank)
		local info = D.Abilities[abilityName]
		if not spellId and info and info.ranks[preferredRank] then
			spellId = info.ranks[preferredRank].spellId
		end
		shown = ShowSpellIdOnTooltip(spellId)
	end

	-- 3) Pet spellbook — matching trained rank only
	if not shown then
		local num = HasPetSpells and HasPetSpells()
		if num then
			local book = BOOKTYPE_PET or "pet"
			local fallbackIndex
			for i = 1, num do
				local name, sub = nil, nil
				if GetSpellBookItemName then
					name, sub = GetSpellBookItemName(i, book)
				elseif GetSpellName then
					name, sub = GetSpellName(i, book)
				end
				if name == abilityName then
					local slotRank = nil
					if sub and sub ~= "" then
						slotRank = tonumber(sub:match("(%d+)"))
					end
					if preferredRank then
						if slotRank and slotRank == preferredRank then
							fallbackIndex = i
							break
						end
					elseif not fallbackIndex then
						fallbackIndex = i
					end
				end
			end
			if fallbackIndex then
				if GameTooltip.SetSpellBookItem then
					local ok = pcall(GameTooltip.SetSpellBookItem, GameTooltip, fallbackIndex, book)
					shown = ok and GameTooltip:NumLines() > 0
				elseif GameTooltip.SetSpell then
					local ok = pcall(GameTooltip.SetSpell, GameTooltip, fallbackIndex, book)
					shown = ok and GameTooltip:NumLines() > 0
				end
			end
		end
	end

	-- 4) Static fallback (correct rank req/TP even without a live tip)
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
			GameTooltip:AddLine("Open Beast Training for full ability tooltips.", 0.6, 0.6, 0.6)
		end
	end

	GameTooltip:Show()
	return shown
end

-- Best craft index to teach: highest known rank <= desiredRank that the pet
-- can actually learn now (level gate applied while choosing, not after).
-- Returns entry or nil, plus reason string.
function HPT:FindBestCraftForAbility(abilityName, desiredRank, petRanks)
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
	local best
	local bestTooHigh -- highest matching rank skipped only due to level
	for _, entry in ipairs(self:GetCraftEntries()) do
		if entry.ability == abilityName and entry.rank <= desiredRank and entry.rank > petRank then
			local req = entry.reqLevel or 0
			if petLevel and req > 0 and petLevel < req then
				if not bestTooHigh or entry.rank > bestTooHigh.rank then
					bestTooHigh = entry
				end
			else
				if not best or entry.rank > best.rank then
					best = entry
				end
			end
		end
	end

	if best then
		return best, "ok"
	end

	local hunterKnows = self:GetKnownCraftRanks()[abilityName] or 0
	if hunterKnows == 0 then
		return nil, "you have not learned this ability yet"
	elseif hunterKnows <= petRank then
		return nil, "no higher rank available than pet already has"
	elseif bestTooHigh then
		return bestTooHigh, ("pet level too low for rank %d (need %d); no lower learnable rank"):format(
			bestTooHigh.rank, bestTooHigh.reqLevel or 0)
	else
		return nil, ("no usable craft rank <= %d (you know up to %d)"):format(desiredRank, hunterKnows)
	end
end

function HPT:BuildApplyPlan(template)
	template = template or self:GetActiveTemplate()
	local petRanks = self:GetPetKnownRanks()
	local plan = {}
	local skipped = {}

	if not self:IsBeastTrainingOpen() then
		return plan, skipped, "Beast Training is not open. Cast Beast Training first."
	end

	for _, ability in ipairs(D.AbilityOrder) do
		local desired = template.ranks[ability] or 0
		if desired > 0 and not self:IsInfoOnlyAbility(ability) and self:AbilityAvailableForFamily(ability, template.family) then
			local entry, reason = self:FindBestCraftForAbility(ability, desired, petRanks)
			if entry and reason == "ok" then
				table.insert(plan, {
					ability = ability,
					desired = desired,
					trainRank = entry.rank,
					index = entry.index,
					cost = entry.cost,
					craftType = entry.craftType,
				})
			elseif desired > 0 then
				table.insert(skipped, {
					ability = ability,
					desired = desired,
					reason = reason or "unknown",
					wouldTrain = entry and entry.rank or nil,
				})
			end
		elseif desired > 0 then
			table.insert(skipped, {
				ability = ability,
				desired = desired,
				reason = "not available for family " .. tostring(template.family),
			})
		end
	end

	return plan, skipped, nil
end

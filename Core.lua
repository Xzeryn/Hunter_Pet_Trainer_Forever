HunterPetTrainer = HunterPetTrainer or {}
local HPT = HunterPetTrainer
local D = HunterPetTrainerData

HPT.VERSION = "0.2.6"
HPT.ICON = "Interface\\AddOns\\Hunter_Pet_Trainer_Forever\\media\\icon"
HPT.ADDON_NAME = "Hunter Pet Trainer Forever"
HPT.MAX_LEVEL = 60
-- Wowhead has no Forever pet calculator yet; the TBC import code stays but is hidden.
HPT.WOWHEAD_IMPORT = false
HPT.CURRENT_PET_KEY = "Current Pet"
-- Set true (or /hpt debug) to restore chat diagnostics
HPT.DEBUG = false

local LOYALTY_NAMES = {
	[1] = "Rebellious",
	[2] = "Unruly",
	[3] = "Submissive",
	[4] = "Dependable",
	[5] = "Faithful",
	[6] = "Best Friend",
}

local defaults = {
	profile = {
		templates = {},
		activeTemplate = nil, -- CURRENT_PET_KEY or a saved theory template name
		selectedFamily = "Boar",
		showPetTrained = true,
		currentPetPlan = nil,
		theoryLevel = HPT.MAX_LEVEL,
		theoryLoyalty = 6,
	},
}

local function DeepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for k, v in pairs(src) do
		dst[k] = DeepCopy(v)
	end
	return dst
end

function HPT:Print(msg, ...)
	if not self.DEBUG then
		return
	end
	if select("#", ...) > 0 then
		msg = msg:format(...)
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HPT|r: " .. tostring(msg))
end

-- Always-visible chat for slash-command replies the user asked for.
function HPT:Echo(msg, ...)
	if select("#", ...) > 0 then
		msg = msg:format(...)
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HPT|r: " .. tostring(msg))
end

function HPT:LoyaltyName(level)
	return LOYALTY_NAMES[level] or ("Loyalty " .. tostring(level))
end

-- Parse loyalty 1–6 from classic flavor strings, e.g. "(Loyalty Level 4) Content".
function HPT:ParseLoyaltyValue(v)
	if v == nil then
		return nil
	end
	if type(v) == "number" then
		if v >= 1 and v <= 6 then
			return v
		end
		return nil
	end
	if type(v) ~= "string" or v == "" then
		return nil
	end
	local n = tonumber(v:match("[Ll]oyalty%s*[Ll]evel%s*(%d+)"))
		or tonumber(v:match("(%d+)%s*/%s*6"))
	if not n then
		-- Avoid treating UnitLoyalty XP progress strings as a level
		local only = v:match("^%s*(%d+)%s*$")
		n = only and tonumber(only) or nil
	end
	if n and n >= 1 and n <= 6 then
		return n
	end
	local lower = v:lower()
	for level, name in pairs(LOYALTY_NAMES) do
		if lower:find(name:lower(), 1, true) then
			return level
		end
	end
	return nil
end

-- Per-pet values, keyed by GetLivePetIdentity(). Survives /reload and pet swaps.
function HPT:GetPetStats(identity)
	identity = identity or self:GetLivePetIdentity()
	if not identity then
		return nil
	end
	local db = self:GetDB()
	db.petStats = db.petStats or {}
	db.petStats[identity] = db.petStats[identity] or {}
	return db.petStats[identity]
end

function HPT:CallPetInfo(method, ...)
	local fn = C_PetInfo and C_PetInfo[method]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		return nil
	end
	if issecretvalue then
		if a ~= nil and issecretvalue(a) then a = nil end
		if b ~= nil and issecretvalue(b) then b = nil end
		if c ~= nil and issecretvalue(c) then c = nil end
	end
	return a, b, c
end

local function AsNumber(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v)
	end
end

function HPT:RecordLoyaltyLevel(level)
	local stats = level and UnitExists("pet") and self:GetPetStats()
	if stats and stats.loyalty ~= level then
		stats.loyalty = level
		if self.UpdateUI then
			self:UpdateUI()
		end
	end
	return level
end

-- Fallback: the Pet tab's PetLoyaltyText is only fresh while that tab is shown.
function HPT:RecordPetLoyaltyText(text)
	self:RecordLoyaltyLevel(self:ParseLoyaltyValue(text))
end

-- Live pet loyalty only. Never falls back to theory / Best Friend.
function HPT:GetPetLoyaltyLevel()
	if not UnitExists("pet") then
		return nil
	end
	-- Forever: C_PetInfo.GetPetLoyalty works with the Pet tab closed (confirmed 2026-10-05).
	local fromApi = self:ParseLoyaltyValue(self:CallPetInfo("GetPetLoyalty"))
	if fromApi then
		return self:RecordLoyaltyLevel(fromApi)
	end
	local stats = self:GetPetStats()
	if stats and stats.loyalty then
		return stats.loyalty
	end
	if GetPetLoyalty then
		local n = self:ParseLoyaltyValue(GetPetLoyalty())
		if n then
			return n
		end
	end
	-- Slot 0 = current pet on some classic clients (even while dismissed)
	if GetStablePetInfo then
		local _, _, _, _, loyalty = GetStablePetInfo(0)
		local n = self:ParseLoyaltyValue(loyalty)
		if n then
			return n
		end
	end
	if UnitLoyalty then
		-- Often returns loyalty XP progress (numbers), not the 1–6 level
		local a, b = UnitLoyalty("pet")
		local n = self:ParseLoyaltyValue(a) or self:ParseLoyaltyValue(b)
		if n then
			return n
		end
	end
	return nil
end

function HPT:CollectCPetInfoLines()
	local lines = {}
	local function add(fmt, ...)
		lines[#lines + 1] = fmt:format(...)
	end
	local function describe(v)
		if v == nil then
			return "nil"
		end
		if issecretvalue and issecretvalue(v) then
			return "secret (" .. type(v) .. ")"
		end
		return tostring(v) .. " (" .. type(v) .. ")"
	end
	local function call(fn, ...)
		if type(fn) ~= "function" then
			return "missing"
		end
		local ok, a, b, c = pcall(fn, ...)
		if not ok then
			return "error: " .. tostring(a)
		end
		return describe(a) .. ", " .. describe(b) .. ", " .. describe(c)
	end
	local loyaltyFS = _G.PetLoyaltyText
	local parent = loyaltyFS and loyaltyFS:GetParent()
	add("PetLoyaltyText shown: %s visible: %s | parent: %s shown: %s",
		tostring(loyaltyFS and loyaltyFS:IsShown()),
		tostring(loyaltyFS and loyaltyFS:IsVisible()),
		tostring(parent and parent:GetName()),
		tostring(parent and parent:IsShown()))
	if not C_PetInfo then
		add("C_PetInfo: missing")
	else
		local keys = {}
		for k, v in pairs(C_PetInfo) do
			keys[#keys + 1] = tostring(k) .. "=" .. type(v)
		end
		table.sort(keys)
		add("C_PetInfo keys: %s", #keys > 0 and table.concat(keys, ", ") or "(empty)")
		add("  GetPetLoyalty: %s", call(C_PetInfo.GetPetLoyalty))
		add("  GetPetHappiness (happiness, damage, rate): %s", call(C_PetInfo.GetPetHappiness))
		add("  GetPetTrainingPoints (total, spent): %s", call(C_PetInfo.GetPetTrainingPoints))
	end
	add("GetPetLoyalty(): %s", call(GetPetLoyalty))
	add("GetPetTrainingPoints(): %s", call(GetPetTrainingPoints))
	add("UnitLoyalty(pet): %s", call(UnitLoyalty, "pet"))
	add("GetStablePetInfo(0): %s", call(GetStablePetInfo, 0))
	return lines
end

-- Max TP = level * (loyalty - 1); confirmed in the Forever beta (level 10 Dependable = 30).
function HPT:GetTheoryMaxTP(level, loyalty)
	level = tonumber(level) or HPT.MAX_LEVEL
	loyalty = tonumber(loyalty) or 6
	if level < 1 then level = 1 end
	if level > HPT.MAX_LEVEL then level = HPT.MAX_LEVEL end
	if loyalty < 1 then loyalty = 1 end
	if loyalty > 6 then loyalty = 6 end
	return level * math.max(0, loyalty - 1)
end

function HPT:GetDB()
	if not HunterPetTrainerForeverDB then
		HunterPetTrainerForeverDB = DeepCopy(defaults)
	end
	if not HunterPetTrainerForeverDB.profile then
		HunterPetTrainerForeverDB.profile = DeepCopy(defaults.profile)
	end
	local db = HunterPetTrainerForeverDB.profile
	if not db.templates then
		db.templates = {}
	end
	if db.showPetTrained == nil then
		db.showPetTrained = true
	end
	if not db.theoryLevel then
		db.theoryLevel = HPT.MAX_LEVEL
	end
	if not db.theoryLoyalty then
		db.theoryLoyalty = 6
	end
	-- Migrate old Default scratch → Current Pet
	if db.activeTemplate == "Default" then
		db.activeTemplate = HPT.CURRENT_PET_KEY
	end
	if db.templates["Default"] then
		db.templates["Default"] = nil
	end
	self:EnsureCurrentPetPlan()
	if not db.activeTemplate then
		db.activeTemplate = HPT.CURRENT_PET_KEY
	end
	return db
end

function HPT:NewTemplate(name, family)
	local ranks = {}
	for _, ability in ipairs(D.AbilityOrder) do
		ranks[ability] = 0
	end
	return {
		name = name or "New Template",
		family = family or self:GetDB().selectedFamily or "Boar",
		ranks = ranks,
		theoryLevel = self:GetDB().theoryLevel or HPT.MAX_LEVEL,
		theoryLoyalty = self:GetDB().theoryLoyalty or 6,
	}
end

function HPT:EnsureCurrentPetPlan()
	if not HunterPetTrainerForeverDB or not HunterPetTrainerForeverDB.profile then
		return nil
	end
	local db = HunterPetTrainerForeverDB.profile
	local created = false
	if not db.currentPetPlan then
		local family = (UnitExists("pet") and UnitCreatureFamily("pet")) or db.selectedFamily or "Boar"
		local ranks = {}
		for _, ability in ipairs(D.AbilityOrder) do
			ranks[ability] = 0
		end
		db.currentPetPlan = {
			name = HPT.CURRENT_PET_KEY,
			family = family,
			ranks = ranks,
			isCurrentPet = true,
		}
		created = true
	end
	db.currentPetPlan.name = HPT.CURRENT_PET_KEY
	db.currentPetPlan.isCurrentPet = true
	-- Current Pet is live-only; never keep theory calculator fields
	db.currentPetPlan.theoryLevel = nil
	db.currentPetPlan.theoryLoyalty = nil
	if not db.currentPetPlan.ranks then
		db.currentPetPlan.ranks = {}
	end
	-- First-time seed from live pet so Current Pet isn't an empty plan
	if created and UnitExists("pet") then
		self:SyncCurrentPetPlanFromPet(true)
	end
	return db.currentPetPlan
end

function HPT:IsCurrentPetActive()
	local db = self:GetDB()
	return (db.activeTemplate == HPT.CURRENT_PET_KEY) or (db.activeTemplate == nil)
end

function HPT:CanAssistTrain()
	return self:IsCurrentPetActive() and UnitExists("pet") and self:IsBeastTrainingOpen()
end

function HPT:GetPetFamily()
	if not UnitExists("pet") then
		return nil
	end
	return UnitCreatureFamily("pet")
end

-- Best stable fingerprint on TBC Anniversary (no public unique pet id).
-- Format: "Name|Family". Dismiss / flying keeps the last identity on the plan.
function HPT:GetLivePetIdentity()
	if not UnitExists("pet") then
		return nil
	end
	local name = UnitName("pet")
	local family = UnitCreatureFamily("pet")
	if not name or name == "" or not family or family == "" then
		return nil
	end
	return name .. "|" .. family
end

-- Family for a new blank template: prefer the Family dropdown / active template,
-- NOT the summoned pet (that was causing Owl New → Ravager).
function HPT:SuggestNewTemplateFamily()
	local db = self:GetDB()
	if self.frame and self.frame.familyDrop and self.frame.familyDrop.GetText then
		local fromDrop = self.frame.familyDrop:GetText()
		if fromDrop and D.Families[fromDrop] then
			return fromDrop
		end
	end
	local active = self:GetActiveTemplate()
	if active and active.family and D.Families[active.family] then
		return active.family
	end
	if db.selectedFamily and D.Families[db.selectedFamily] then
		return db.selectedFamily
	end
	return self:GetPetFamily() or "Boar"
end

function HPT:IsShowPetTrained()
	-- Current Pet always compares against the live pet
	if self:IsCurrentPetActive() then
		return true
	end
	return self:GetDB().showPetTrained ~= false
end

function HPT:SetShowPetTrained(enabled)
	self:GetDB().showPetTrained = enabled and true or false
	if self.UpdateUI then
		self:UpdateUI()
	end
end

-- Create a blank template (no ranks copied from pet or current template) and activate it.
function HPT:CreateBlankTemplate(name, family)
	if not name or name == "" then
		self:Echo("Template name required.")
		return false
	end
	if name == HPT.CURRENT_PET_KEY or name == "Default" then
		self:Echo("That name is reserved. Choose another.")
		return false
	end
	local db = self:GetDB()
	if db.templates[name] then
		self:Echo("Template '%s' already exists. Choose another name or delete it first.", name)
		return false
	end
	family = family or self:SuggestNewTemplateFamily()
	if not D.Families[family] then
		self:Echo("Unknown family '%s'.", tostring(family))
		return false
	end
	local tmpl = self:NewTemplate(name, family)
	for _, ability in ipairs(D.AbilityOrder) do
		tmpl.ranks[ability] = 0
	end
	db.templates[name] = tmpl
	db.activeTemplate = name
	db.selectedFamily = family
	db.showPetTrained = false
	self:Echo("Created blank template '%s' (%s).", name, family)
	if self.UpdateUI then
		self:UpdateUI()
	end
	if self.SyncAssistToPlan then
		self:SyncAssistToPlan()
	end
	return true
end

function HPT:TemplateHasPlannedRanks(template)
	template = template or self:GetActiveTemplate()
	if not template or not template.ranks then
		return false
	end
	for _, rank in pairs(template.ranks) do
		if rank and rank > 0 then
			return true
		end
	end
	return false
end

function HPT:SetTemplateFamily(template, family, force)
	template = template or self:GetActiveTemplate()
	if not template or not family or not D.Families[family] then
		return false
	end
	if template.isCurrentPet then
		self:Echo("Current Pet family follows your summoned pet.")
		return false
	end
	if template.family == family then
		return true
	end
	template.family = family
	self:GetDB().selectedFamily = family
	self:SanitizeTemplateForFamily(template)
	if self.UpdateUI then
		self:UpdateUI()
	end
	if self.SyncAssistToPlan then
		self:SyncAssistToPlan()
	end
	return true
end

function HPT:ClearTemplateRanks(template)
	template = template or self:GetActiveTemplate()
	if not template then
		return false
	end
	for _, ability in ipairs(D.AbilityOrder) do
		template.ranks[ability] = 0
	end
	self:Print("Cleared planned ranks on '%s'.", template.name)
	if self.UpdateUI then
		self:UpdateUI()
	end
	if self.SyncAssistToPlan then
		self:SyncAssistToPlan()
	end
	return true
end

function HPT:GetActiveTemplate()
	local db = self:GetDB()
	if db.activeTemplate == HPT.CURRENT_PET_KEY or not db.activeTemplate then
		db.activeTemplate = HPT.CURRENT_PET_KEY
		return self:EnsureCurrentPetPlan()
	end
	if db.templates[db.activeTemplate] then
		local t = db.templates[db.activeTemplate]
		if not t.theoryLevel then t.theoryLevel = db.theoryLevel or HPT.MAX_LEVEL end
		if not t.theoryLoyalty then t.theoryLoyalty = db.theoryLoyalty or 6 end
		return t
	end
	db.activeTemplate = HPT.CURRENT_PET_KEY
	return self:EnsureCurrentPetPlan()
end

function HPT:SetActiveTemplate(name)
	local db = self:GetDB()
	if name == HPT.CURRENT_PET_KEY then
		db.activeTemplate = HPT.CURRENT_PET_KEY
		db.showPetTrained = true
		self:SyncCurrentPetPlanFromPet(false)
		if self.UpdateUI then self:UpdateUI() end
		if self.SyncAssistToPlan then self:SyncAssistToPlan() end
		return true
	end
	if db.templates[name] then
		db.activeTemplate = name
		db.selectedFamily = db.templates[name].family
		if self.UpdateUI then self:UpdateUI() end
		if self.SyncAssistToPlan then self:SyncAssistToPlan() end
		return true
	end
	return false
end

-- Mirror live pet into Current Pet plan.
-- resetTargets=true: planned ranks become exactly what the pet has trained.
-- resetTargets=false: keep planned targets, only update family + sanitize.
-- Swapping animals (even same family) is detected via name|family identity.
function HPT:SyncCurrentPetPlanFromPet(resetTargets)
	local plan = self:EnsureCurrentPetPlan()
	if not plan then
		return false
	end
	if not UnitExists("pet") then
		-- Keep plan.petIdentity so dismiss / flying does not clear the plan
		return false
	end
	local family = self:GetPetFamily()
	local identity = self:GetLivePetIdentity()
	if not family or not identity then
		return false
	end

	local identityChanged = plan.petIdentity ~= nil and plan.petIdentity ~= identity
	local familyChanged = plan.family ~= family
	local doReset = resetTargets or identityChanged or familyChanged

	plan.family = family
	plan.petIdentity = identity
	plan.petName = UnitName("pet")
	self:GetDB().selectedFamily = family

	if doReset then
		local petRanks = self:GetPetKnownRanks()
		for _, ability in ipairs(D.AbilityOrder) do
			if self:AbilityAvailableForFamily(ability, family) then
				plan.ranks[ability] = petRanks[ability] or 0
			else
				plan.ranks[ability] = 0
			end
		end
		if identityChanged then
			if self.apply and self.apply.active then
				self:StopApply(nil)
			end
			self:Print("Pet changed (%s) — Current Pet plan reset to trained ranks.", UnitName("pet") or "?")
			if self.SyncAssistToPlan then
				self:SyncAssistToPlan()
			end
		end
	else
		self:SanitizeTemplateForFamily(plan)
		-- Can't untrain: never let Current Pet plan sit below live ranks
		local petRanks = self:GetPetKnownRanks()
		for _, ability in ipairs(D.AbilityOrder) do
			if self:AbilityAvailableForFamily(ability, family) then
				local have = petRanks[ability] or 0
				if (plan.ranks[ability] or 0) < have then
					plan.ranks[ability] = have
				end
			end
		end
	end
	return true
end

-- Copy a theory template's planned ranks onto Current Pet (Train uses this plan only).
function HPT:ApplyTemplateToCurrentPet(sourceName, force)
	local db = self:GetDB()
	sourceName = sourceName or db.activeTemplate
	if not sourceName or sourceName == HPT.CURRENT_PET_KEY then
		self:Echo("Select a saved template to apply.")
		return false
	end
	local src = db.templates[sourceName]
	if not src then
		self:Echo("No template named '%s'.", tostring(sourceName))
		return false
	end
	if not UnitExists("pet") then
		self:Echo("Summon a pet before applying a template to Current Pet.")
		return false
	end
	local petFamily = self:GetPetFamily()
	if not petFamily then
		self:Echo("Could not read pet family.")
		return false
	end
	if src.family ~= petFamily and not force then
		StaticPopup_Show("HPT_APPLY_FAMILY_MISMATCH", src.family, petFamily, sourceName)
		return false
	end

	local plan = self:EnsureCurrentPetPlan()
	plan.family = petFamily
	db.selectedFamily = petFamily
	-- Start from what the pet already knows, then raise to template targets
	local petRanks = self:GetPetKnownRanks()
	for _, ability in ipairs(D.AbilityOrder) do
		if self:AbilityAvailableForFamily(ability, petFamily) then
			local desired = src.ranks[ability] or 0
			local have = petRanks[ability] or 0
			plan.ranks[ability] = math.max(desired, have)
		else
			plan.ranks[ability] = 0
		end
	end
	db.activeTemplate = HPT.CURRENT_PET_KEY
	db.showPetTrained = true
	self:Echo("Applied |cffffffff%s|r to Current Pet (%s).", sourceName, petFamily)
	if self.UpdateUI then self:UpdateUI() end
	if self.SyncAssistToPlan then self:SyncAssistToPlan() end
	return true
end

function HPT:SaveTemplateAs(name)
	if not name or name == "" or name == HPT.CURRENT_PET_KEY then
		self:Echo("Choose a different template name.")
		return false
	end
	local current = self:GetActiveTemplate()
	local db = self:GetDB()
	local copy = DeepCopy(current)
	copy.name = name
	copy.isCurrentPet = nil
	copy.theoryLevel = copy.theoryLevel or db.theoryLevel or HPT.MAX_LEVEL
	copy.theoryLoyalty = copy.theoryLoyalty or db.theoryLoyalty or 6
	db.templates[name] = copy
	db.activeTemplate = name
	self:Echo("Saved template '%s'.", name)
	if self.UpdateUI then self:UpdateUI() end
	return true
end

function HPT:DeleteTemplate(name)
	local db = self:GetDB()
	if name == HPT.CURRENT_PET_KEY or name == "Default" then
		self:Echo("Cannot delete Current Pet.")
		return
	end
	if not db.templates[name] then
		self:Echo("No template named '%s'.", tostring(name))
		return
	end
	db.templates[name] = nil
	if db.activeTemplate == name then
		db.activeTemplate = HPT.CURRENT_PET_KEY
	end
	self:Echo("Deleted template '%s'.", name)
	if self.UpdateUI then self:UpdateUI() end
	if self.SyncAssistToPlan then self:SyncAssistToPlan() end
end

function HPT:AbilityAvailableForFamily(abilityName, family)
	local info = D.Abilities[abilityName]
	if not info then
		return false
	end
	for _, fam in ipairs(info.families) do
		if fam == "ALL" or fam == family then
			return true
		end
	end
	return false
end

-- Family abilities with no trainer and 0 TP; pets appear to learn them with level.
function HPT:IsInfoOnlyAbility(abilityName)
	local info = D.Abilities[abilityName]
	return info ~= nil and info.source == "innate"
end

-- Rank cost in Data.lua is the total TP invested to have that rank (not per-rank fee).
-- Upgrade from have→desired costs cost(desired) - cost(have).
function HPT:GetRankTotalCost(ability, rank)
	if not rank or rank <= 0 then
		return 0
	end
	local info = D.Abilities[ability]
	if not info or not info.ranks[rank] then
		return 0
	end
	return info.ranks[rank].cost or 0
end

function HPT:GetRankUpgradeCost(ability, fromRank, toRank)
	fromRank = fromRank or 0
	toRank = toRank or 0
	if toRank <= fromRank then
		return 0
	end
	return self:GetRankTotalCost(ability, toRank) - self:GetRankTotalCost(ability, fromRank)
end

-- Full build cost: sum of selected ranks' total costs (highest rank only per ability).
function HPT:GetTemplateCost(template)
	local cost = 0
	local family = template.family
	for ability, rank in pairs(template.ranks) do
		if rank and rank > 0 and self:AbilityAvailableForFamily(ability, family) then
			cost = cost + self:GetRankTotalCost(ability, rank)
		end
	end
	return cost
end

-- Remaining cost to train from petRanks up to template targets (difference of totals).
function HPT:GetTemplateRemainingCost(template, petRanks)
	petRanks = petRanks or {}
	local cost = 0
	local family = template.family
	for ability, rank in pairs(template.ranks) do
		local have = petRanks[ability] or 0
		if rank and rank > have and self:AbilityAvailableForFamily(ability, family) then
			cost = cost + self:GetRankUpgradeCost(ability, have, rank)
		end
	end
	return cost
end

function HPT:SetTheoryLevel(level)
	local t = self:GetActiveTemplate()
	if t.isCurrentPet then
		return
	end
	level = math.max(1, math.min(HPT.MAX_LEVEL, tonumber(level) or HPT.MAX_LEVEL))
	t.theoryLevel = level
	self:GetDB().theoryLevel = level
	if self.UpdateUI then self:UpdateUI() end
end

function HPT:SetTheoryLoyalty(loyalty)
	local t = self:GetActiveTemplate()
	if t.isCurrentPet then
		return
	end
	loyalty = math.max(1, math.min(6, tonumber(loyalty) or 6))
	t.theoryLoyalty = loyalty
	self:GetDB().theoryLoyalty = loyalty
	if self.UpdateUI then self:UpdateUI() end
end

-- Clear planned ranks that the selected family cannot learn (informational-only rows).
function HPT:SanitizeTemplateForFamily(template)
	if not template or not template.ranks then
		return false
	end
	local changed = false
	for ability, rank in pairs(template.ranks) do
		if rank and rank > 0 and not self:AbilityAvailableForFamily(ability, template.family) then
			template.ranks[ability] = 0
			changed = true
		end
	end
	return changed
end

-- Forever: remaining TP is only shown in the pet trainer's label ("Training Points: 14").
function HPT:GetTrainerPointsRemaining()
	local label = _G.ClassTrainerFrameTrainingPointsLabel
	if not label or not label:IsVisible() then
		return nil
	end
	local text = label:GetText()
	return text and tonumber(text:match("(%d+)%s*$"))
end

function HPT:RecordTrainerPoints()
	local remaining = self:GetTrainerPointsRemaining()
	local stats = remaining and UnitExists("pet") and self:GetPetStats()
	if not stats then
		return
	end
	local loyalty = self:GetPetLoyaltyLevel()
	stats.remaining = remaining
	stats.level = UnitLevel("pet")
	if loyalty then
		stats.spent = math.max(0, self:GetTheoryMaxTP(stats.level, loyalty) - remaining)
	end
end

-- Returns remaining, total, spent, source.
-- source: "api" (C_PetInfo), "trainer" (Beast Training label), "cached", "estimate".
function HPT:GetPetPoints()
	if not UnitExists("pet") then
		return 0, 0, 0, "estimate"
	end
	local loyalty = self:GetPetLoyaltyLevel()
	local formulaTotal = loyalty and self:GetTheoryMaxTP(UnitLevel("pet"), loyalty) or 0
	-- Forever C_PetInfo.GetPetTrainingPoints is (total, spent), same as classic.
	-- Remaining is max(0, total - spent). Assign the two returns first: tonumber(total, spent)
	-- treats spent as a numeric base (17, 17 became 24).
	-- L17 Rebellious: (0, 10) remaining 0. L17 Unruly after Bite 3: (17, 17) remaining 0.
	local totalPoints, spentPoints = self:CallPetInfo("GetPetTrainingPoints")
	totalPoints = AsNumber(totalPoints)
	spentPoints = AsNumber(spentPoints)
	if totalPoints then
		spentPoints = spentPoints or 0
		local remaining = math.max(0, totalPoints - spentPoints)
		local stats = self:GetPetStats()
		if stats then
			stats.remaining = remaining
			stats.level = UnitLevel("pet")
			stats.spent = spentPoints
		end
		return remaining, totalPoints, spentPoints, "api"
	end
	if GetPetTrainingPoints then
		local points, spent = GetPetTrainingPoints()
		points = points or 0
		spent = spent or 0
		return points - spent, points, spent, "trainer"
	end
	local live = self:GetTrainerPointsRemaining()
	if live then
		local liveTotal = loyalty and formulaTotal or live
		return live, liveTotal, math.max(0, liveTotal - live), "trainer"
	end
	local stats = self:GetPetStats()
	if stats and stats.spent then
		return math.max(0, formulaTotal - stats.spent), formulaTotal, stats.spent, "cached"
	end
	return formulaTotal, formulaTotal, 0, "estimate"
end

-- Hook Blizzard text updates so values are captured the moment Blizzard sets them.
-- hooksecurefunc never taints the hooked frame.
function HPT:EnsureBlizzardHooks()
	if not self.hookedLoyaltyText and _G.PetLoyaltyText then
		hooksecurefunc(_G.PetLoyaltyText, "SetText", function(_, text)
			HPT:RecordPetLoyaltyText(text)
		end)
		hooksecurefunc(_G.PetLoyaltyText, "SetFormattedText", function(fs)
			HPT:RecordPetLoyaltyText(fs:GetText())
		end)
		self.hookedLoyaltyText = true
		if _G.PetLoyaltyText:IsVisible() then
			self:RecordPetLoyaltyText(_G.PetLoyaltyText:GetText())
		end
	end
	if not self.hookedTrainerPoints and _G.ClassTrainerFrame_UpdateTrainingPoints then
		hooksecurefunc("ClassTrainerFrame_UpdateTrainingPoints", function()
			HPT:RecordTrainerPoints()
			if HPT.UpdateUI then
				HPT:UpdateUI()
			end
		end)
		self.hookedTrainerPoints = true
	end
end

local function ParseRankFromSubText(sub)
	if not sub or sub == "" then
		return nil
	end
	-- "Rank 2", "Rank 2 Passive", etc. — not bare "Passive"
	local n = tonumber(sub:match("(%d+)"))
	return n
end

function HPT:EnsureScanTooltip()
	if self.scanTip then
		return self.scanTip
	end
	local tip = CreateFrame("GameTooltip", "HunterPetTrainerScanTooltip", nil, "GameTooltipTemplate")
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	self.scanTip = tip
	return tip
end

local function TooltipLines(tip)
	local lines = {}
	local n = tip:NumLines() or 0
	for i = 1, n do
		local fs = _G[tip:GetName() .. "TextLeft" .. i]
		local text = fs and fs:GetText()
		if text and text ~= "" then
			table.insert(lines, text)
		end
	end
	return lines
end

local function RankFromTooltipLines(abilityName, lines)
	local joined = table.concat(lines, "\n")
	-- Explicit "Rank N" anywhere in the tip
	local rank = tonumber(joined:match("[Rr]ank%s*(%d+)"))
	if rank then
		return rank
	end
	-- Data-driven signatures (e.g. Avoidance 25% vs 50%)
	local info = D.Abilities[abilityName]
	if not info then
		return nil
	end
	local best
	for r, rankInfo in pairs(info.ranks) do
		local pat = rankInfo.tipMatch
		if pat and joined:find(pat) then
			if not best or r > best then
				best = r
			end
		end
	end
	return best
end

local function RankFromPetBookSlot(index, book, abilityName, sub)
	local fromSub = ParseRankFromSubText(sub)
	if fromSub then
		return fromSub
	end

	local tip = HPT:EnsureScanTooltip()
	tip:ClearLines()
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok = false
	if tip.SetSpellBookItem then
		ok = pcall(tip.SetSpellBookItem, tip, index, book)
	elseif tip.SetSpell then
		ok = pcall(tip.SetSpell, tip, index, book)
	end
	if ok then
		local rank = RankFromTooltipLines(abilityName, TooltipLines(tip))
		tip:Hide()
		if rank then
			return rank
		end
	else
		tip:Hide()
	end

	-- Spell ID map (optional per-rank spellId in data)
	if GetSpellBookItemInfo then
		local spellType, spellId = GetSpellBookItemInfo(index, book)
		if type(spellId) == "number" then
			local info = D.Abilities[abilityName]
			if info then
				for r, rankInfo in pairs(info.ranks) do
					if rankInfo.spellId == spellId then
						return r
					end
				end
			end
		end
	end

	-- Single-rank abilities (e.g. Cobra Reflexes) safely default to 1
	local info = D.Abilities[abilityName]
	if info then
		local count = 0
		local only
		for r in pairs(info.ranks) do
			count = count + 1
			only = r
		end
		if count == 1 then
			return only
		end
	end

	-- Unknown multi-rank passive — don't guess rank 1
	return nil
end

-- spellId -> { ability, rank } from generated data
local rankBySpellId
function HPT:RankForSpellId(spellId)
	if not rankBySpellId then
		rankBySpellId = {}
		for ability, info in pairs(D.Abilities) do
			for rank, rankInfo in pairs(info.ranks) do
				if rankInfo.spellId then
					rankBySpellId[rankInfo.spellId] = { ability = ability, rank = rank }
				end
			end
		end
	end
	return rankBySpellId[spellId]
end

-- Pet spellbook access on both the classic globals and the newer C_SpellBook API.
local function PetBookCount()
	if HasPetSpells then
		return HasPetSpells()
	end
	if C_SpellBook and C_SpellBook.HasPetSpells then
		return C_SpellBook.HasPetSpells()
	end
end

local function PetBookSlot(index)
	if GetSpellBookItemName then
		local book = BOOKTYPE_PET or "pet"
		local name, sub = GetSpellBookItemName(index, book)
		local spellId
		if GetSpellBookItemInfo then
			local _, id = GetSpellBookItemInfo(index, book)
			spellId = id
		end
		return name, sub, spellId, book
	end
	if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
		local bank = Enum.SpellBookSpellBank.Pet
		local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
		if item then
			return item.name, item.subName, item.spellID or item.actionID, bank
		end
	end
end

function HPT:GetPetKnownRanks()
	local known = {}
	local num = PetBookCount()
	if not num then
		return known
	end
	for i = 1, num do
		local name, sub, spellId, book = PetBookSlot(i)
		local byId = type(spellId) == "number" and self:RankForSpellId(spellId)
		if byId then
			known[byId.ability] = math.max(known[byId.ability] or 0, byId.rank)
		elseif name and D.Abilities[name] then
			local rank = RankFromPetBookSlot(i, book, name, sub)
			if rank and rank > 0 then
				known[name] = math.max(known[name] or 0, rank)
			end
		end
	end
	if self.GetKnownTrainerRanks then
		for ability, rank in pairs(self:GetKnownTrainerRanks()) do
			known[ability] = math.max(known[ability] or 0, rank)
		end
	end
	return known
end

local eventFrame = CreateFrame("Frame")

-- Forever removed some TBC events (CRAFT_*); registering an unknown event errors and aborts the file.
function HPT:RegisterEventIfValid(frame, event)
	if C_EventUtils and C_EventUtils.IsEventValid then
		if C_EventUtils.IsEventValid(event) then
			frame:RegisterEvent(event)
			return true
		end
		return false
	end
	return pcall(frame.RegisterEvent, frame, event)
end

for _, event in ipairs({
	"ADDON_LOADED",
	"PLAYER_LOGIN",
	"UNIT_PET",
	"UNIT_PET_TRAINING_POINTS",
	"PET_UI_UPDATE",
	"PET_BAR_UPDATE",
	"SPELLS_CHANGED",
	"TRAINER_SHOW",
	"TRAINER_UPDATE",
	"TRAINER_CLOSED",
}) do
	HPT:RegisterEventIfValid(eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Hunter_Pet_Trainer_Forever" then
		HPT:GetDB()
		HPT:Print("Loaded v%s. Open Beast Training to use the hybrid trainer UI.", HPT.VERSION)
	elseif event == "ADDON_LOADED" then
		HPT:EnsureBlizzardHooks()
	elseif event == "PLAYER_LOGIN" then
		HPT:EnsureBlizzardHooks()
		if HPT.CreateUI then
			HPT:CreateUI()
		end
		-- Preserve planned ranks; only sync family / sanitize
		HPT:SyncCurrentPetPlanFromPet(false)
	elseif event == "UNIT_PET" then
		if arg1 == "player" then
			-- Identity check inside Sync resets plan when the animal changes
			HPT:SyncCurrentPetPlanFromPet(false)
		end
		if HPT.OnApplyEvent then HPT:OnApplyEvent(event) end
		if HPT.UpdateUI then HPT:UpdateUI() end
	elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" or event == "TRAINER_CLOSED" then
		HPT:EnsureBlizzardHooks()
		HPT:InvalidateTrainerCache()
		if event == "TRAINER_CLOSED" then
			HPT:RestoreTrainerFilters()
			HPT:ClearHunterKnownRankSet()
			if HPT.HideTrainerOverlay then
				HPT:HideTrainerOverlay()
			end
		end
		-- The TP label is filled in after the event; read it on the next frame.
		C_Timer.After(0.1, function()
			if event == "TRAINER_SHOW" then
				HPT:ShowAllTrainerFilters()
			end
			HPT:InvalidateTrainerCache()
			HPT:RecordTrainerPoints()
			if event ~= "TRAINER_CLOSED" and UnitExists("pet") then
				HPT:SyncCurrentPetPlanFromPet(false)
			end
			if HPT.OnApplyEvent then
				HPT:OnApplyEvent(event)
			end
			if HPT.OnTrainerOverlayEvent then
				HPT:OnTrainerOverlayEvent(event)
			end
			if HPT.UpdateUI then
				HPT:UpdateUI()
			end
		end)
	elseif event == "UNIT_PET_TRAINING_POINTS" or event == "PET_UI_UPDATE"
		or event == "PET_BAR_UPDATE" or event == "SPELLS_CHANGED" then
		-- Pet book often populates after UNIT_PET; re-clamp trained floors
		if (event == "PET_BAR_UPDATE" or event == "SPELLS_CHANGED") and UnitExists("pet") then
			HPT:SyncCurrentPetPlanFromPet(false)
		end
		if HPT.OnApplyEvent then
			HPT:OnApplyEvent(event)
		end
		if HPT.UpdateUI then
			HPT:UpdateUI()
		end
	end
end)

SLASH_HUNTERPETTRAINER1 = "/hpt"
SLASH_HUNTERPETTRAINER2 = "/pettrainer"
SlashCmdList.HUNTERPETTRAINER = function(msg)
	local raw = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	msg = raw:lower()
	if msg == "" or msg == "show" or msg == "toggle" then
		HPT:ToggleUI()
	elseif msg == "help" then
		HPT:Echo("Commands:")
		HPT:Echo("  /hpt - toggle planner")
		HPT:Echo("  /hpt apply - assisted train from Current Pet (you click Train)")
		HPT:Echo("  /hpt stop - cancel apply")
		HPT:Echo("  /hpt save <name> - duplicate active plan as a saved template")
		HPT:Echo("  /hpt new <name> [family] - create blank theory template")
		HPT:Echo("  /hpt load <name> - load Current Pet or a saved template")
		HPT:Echo("  /hpt delete <name> - delete a saved template")
		HPT:Echo("  /hpt templates - list saved templates")
		HPT:Echo("  /hpt apply <name> - copy a saved template onto Current Pet")
		HPT:Echo("  /hpt debug - toggle diagnostic chat messages")
		HPT:Echo("  /hpt dev - developer window with copyable reports")
		HPT:Echo("  /hpt report - pet + Beast Training snapshot and a GitHub issue link")
		HPT:Echo("  /hpt minimap - hide or show the minimap button")
	elseif msg == "dev" then
		HPT:ToggleDevWindow()
	elseif msg == "report" then
		HPT:ShowDataReport()
	elseif msg == "report test" or msg == "report all" then
		HPT:ShowDataReport(msg:match("^report (%a+)$"))
	elseif msg == "report clear" then
		HPT:ClearObservations()
	elseif msg == "minimap" then
		HPT:ToggleMinimapButton()
	elseif msg == "debug" then
		HPT.DEBUG = not HPT.DEBUG
		HPT:Echo("Debug chat %s.", HPT.DEBUG and "ON" or "OFF")
		if HPT.LayoutDevButtons then
			HPT:LayoutDevButtons()
		end
	elseif msg == "apply" then
		HPT:StartApply()
	elseif msg:match("^apply%s+") then
		local name = msg:match("^apply%s+(.+)$")
		HPT:ApplyTemplateToCurrentPet(name)
	elseif msg == "stop" then
		HPT:StopApply("Cancelled.")
	elseif msg == "templates" then
		local db = HPT:GetDB()
		HPT:Echo("Active: |cffffffff%s|r", db.activeTemplate or HPT.CURRENT_PET_KEY)
		HPT:Echo("Saved templates:")
		for name, tmpl in pairs(db.templates or {}) do
			local mark = (db.activeTemplate == name) and " |cff00ff00(active)|r" or ""
			local fam = tmpl.family and (" |cff888888[" .. tmpl.family .. "]|r") or ""
			HPT:Echo("  %s%s%s", name, fam, mark)
		end
	elseif msg:match("^new%s+") then
		local name, family = msg:match("^new%s+(%S+)%s*(.*)$")
		family = family and family:match("%S+") or nil
		HPT:CreateBlankTemplate(name, family)
	elseif msg:match("^delete%s+") then
		local name = msg:match("^delete%s+(.+)$")
		HPT:DeleteTemplate(name)
	elseif msg:match("^load%s+") then
		local name = msg:match("^load%s+(.+)$")
		if name == "current" or name == "pet" or name == "current pet" then
			name = HPT.CURRENT_PET_KEY
		end
		if HPT:SetActiveTemplate(name) then
			HPT:Echo("Loaded '%s'.", name)
			if HPT.SyncAssistToPlan then
				HPT:SyncAssistToPlan()
			end
		else
			HPT:Echo("No template named '%s'.", name)
		end
	elseif msg:match("^save%s+") then
		local name = msg:match("^save%s+(.+)$")
		HPT:SaveTemplateAs(name)
	else
		HPT:Echo("Unknown command. Try /hpt help")
	end
end

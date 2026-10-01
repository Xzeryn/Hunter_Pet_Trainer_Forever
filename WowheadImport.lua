-- Import builds from Wowhead TBC Hunter Pet Training calculator share links:
--   https://www.wowhead.com/tbc/hunter-pet-training/<token>
local HPT = HunterPetTrainer
local D = HunterPetTrainerData

-- Creature family IDs used by Wowhead's hunter-pet-training page
local WOWHEAD_PET_ID = {
	[1] = "Wolf",
	[2] = "Cat",
	[3] = "Spider",
	[4] = "Bear",
	[5] = "Boar",
	[6] = "Crocolisk",
	[7] = "Carrion Bird",
	[8] = "Crab",
	[9] = "Gorilla",
	[11] = "Raptor",
	[12] = "Tallstrider",
	[20] = "Scorpid",
	[21] = "Turtle",
	[24] = "Bat",
	[25] = "Hyena",
	[26] = "Owl",
	[27] = "Wind Serpent",
	[30] = "Dragonhawk",
	[31] = "Ravager",
	[32] = "Warp Stalker",
	[33] = "Sporebat",
	[34] = "Nether Ray",
	[35] = "Serpent",
}

-- Spell ID keys Wowhead stores in the share payload (rank-1 / ability key)
local WOWHEAD_SPELL_ID = {
	[2649] = "Growl",
	[1742] = "Cower",
	[17253] = "Bite",
	[16827] = "Claw",
	[35290] = "Gore",
	[7371] = "Charge",
	[23099] = "Dash",
	[23145] = "Dive",
	[24450] = "Prowl",
	[24604] = "Furious Howl",
	[24423] = "Screech",
	[24640] = "Scorpid Poison",
	[35387] = "Poison Spit",
	[24844] = "Lightning Breath",
	[34889] = "Fire Breath",
	[26090] = "Thunderstomp",
	[26064] = "Shell Shield",
	[35346] = "Warp",
	[4187] = "Great Stamina",
	[24545] = "Natural Armor",
	[35694] = "Avoidance",
	[25076] = "Cobra Reflexes",
	[24493] = "Arcane Resistance",
	[23992] = "Fire Resistance",
	[24446] = "Frost Resistance",
	[24492] = "Nature Resistance",
	[24488] = "Shadow Resistance",
}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Decode(data)
	data = data:gsub("[^" .. B64 .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then
			return ""
		end
		local r, f = "", (B64:find(x, 1, true) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
		end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then
			return ""
		end
		local c = 0
		for i = 1, 8 do
			c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
		end
		return string.char(c)
	end))
end

local function ExtractToken(text)
	if not text or text == "" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	-- Full or partial Wowhead URL
	local token = text:match("[Hh]unter%-[Pp]et%-[Tt]raining/([%w%-%_]+)")
	if token then
		return token
	end
	-- Bare token (base64url chars only)
	if text:match("^[%w%-%_]+$") and #text >= 4 then
		return text
	end
	return nil
end

-- Decode Wowhead share payload into { family, level, loyalty, ranks }.
function HPT:ParseWowheadPetTrainingLink(text)
	local token = ExtractToken(text)
	if not token then
		return nil, "Paste a Wowhead hunter-pet-training link (or its share token)."
	end

	local b64 = token:gsub("%-", "+"):gsub("_", "/")
	local pad = #b64 % 4
	if pad > 0 then
		b64 = b64 .. string.rep("=", 4 - pad)
	end

	local ok, decoded = pcall(Base64Decode, b64)
	if not ok or not decoded or #decoded < 4 then
		return nil, "Could not decode Wowhead link."
	end

	local bytes = { decoded:byte(1, #decoded) }
	local version = table.remove(bytes, 1)
	if version ~= 1 then
		return nil, ("Unsupported Wowhead link version (%s)."):format(tostring(version))
	end

	local petId = table.remove(bytes, 1)
	local level = table.remove(bytes, 1)
	local loyalty = table.remove(bytes, 1)
	local family = WOWHEAD_PET_ID[petId]
	if not family then
		return nil, ("Unknown pet family id %s in Wowhead link."):format(tostring(petId))
	end

	local ranks = {}
	for _, ability in ipairs(D.AbilityOrder) do
		ranks[ability] = 0
	end

	local mapped, skipped = 0, 0
	while #bytes >= 3 do
		local hi = table.remove(bytes, 1)
		local lo = table.remove(bytes, 1)
		local rank = table.remove(bytes, 1)
		local spellId = hi * 256 + lo
		local ability = WOWHEAD_SPELL_ID[spellId]
		if ability and D.Abilities[ability] and rank and rank > 0 then
			local maxRank = 0
			for r in pairs(D.Abilities[ability].ranks) do
				if r > maxRank then maxRank = r end
			end
			if rank > maxRank then
				rank = maxRank
			end
			ranks[ability] = rank
			mapped = mapped + 1
		else
			skipped = skipped + 1
		end
	end

	return {
		family = family,
		theoryLevel = math.max(1, math.min(HPT.MAX_LEVEL, tonumber(level) or HPT.MAX_LEVEL)),
		theoryLoyalty = math.max(1, math.min(6, tonumber(loyalty) or 6)),
		ranks = ranks,
		mapped = mapped,
		skipped = skipped,
	}
end

-- Apply a parsed Wowhead build onto a theory template (never Current Pet).
function HPT:ImportWowheadPetTraining(text, templateName)
	local parsed, err = self:ParseWowheadPetTrainingLink(text)
	if not parsed then
		self:Echo(err or "Wowhead import failed.")
		return false
	end

	local db = self:GetDB()
	local name = templateName
	if not name or name == "" then
		-- Default name from family + short stamp
		local n = 1
		repeat
			name = ("%s Wowhead %d"):format(parsed.family, n)
			n = n + 1
		until not db.templates[name] and name ~= HPT.CURRENT_PET_KEY
	end
	if name == HPT.CURRENT_PET_KEY or name == "Default" then
		self:Echo("That name is reserved. Choose another.")
		return false
	end

	local tmpl = self:NewTemplate(name, parsed.family)
	tmpl.theoryLevel = parsed.theoryLevel
	tmpl.theoryLoyalty = parsed.theoryLoyalty
	for ability, rank in pairs(parsed.ranks) do
		tmpl.ranks[ability] = rank
	end
	self:SanitizeTemplateForFamily(tmpl)
	db.templates[name] = tmpl
	db.activeTemplate = name
	db.selectedFamily = parsed.family
	db.showPetTrained = false
	db.theoryLevel = parsed.theoryLevel
	db.theoryLoyalty = parsed.theoryLoyalty

	self:Echo("Imported Wowhead build as |cffffffff%s|r (%s, lvl %d, loyalty %d) — %d abilities.",
		name, parsed.family, parsed.theoryLevel, parsed.theoryLoyalty, parsed.mapped)
	if parsed.skipped > 0 then
		self:Echo("%d Wowhead ability id(s) were skipped (unknown to HPT).", parsed.skipped)
	end
	if self.UpdateUI then
		self:UpdateUI()
	end
	if self.SyncAssistToPlan then
		self:SyncAssistToPlan()
	end
	return true
end

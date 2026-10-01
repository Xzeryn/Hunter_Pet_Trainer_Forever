local HPT = HunterPetTrainer
local D = HunterPetTrainerData

-- Data collection: whenever Beast Training is open, rows (and pet spellbook entries)
-- that disagree with Data.lua are saved. The Report builds a prefilled GitHub issue
-- from whatever still disagrees, so entries drop out once Data.lua is updated.

HPT.ISSUE_URL = "https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/issues/new"
-- GitHub rejects issue links much past 8 KB.
local MAX_URL = 7000

local function Str(v)
	if v == nil then
		return "nil"
	end
	return tostring(v)
end

local function Observed()
	local db = HPT:GetDB()
	db.observed = db.observed or {}
	local o = db.observed
	o.rows = o.rows or {}
	o.book = o.book or {}
	o.tp = o.tp or {}
	o.missing = o.missing or {}
	return o
end

-- Test reports record everything into a throwaway table and never touch saved data.
local function Scratch()
	return { rows = {}, book = {}, tp = {}, missing = {}, test = true }
end

-- Faster / Slower Attack I-III are per-species traits, not trainable ranks.
local function IsSpeciesTrait(name)
	return name ~= nil and (name:find("^Faster Attack") or name:find("^Slower Attack")) ~= nil
end

local function SpellIcon(spellId)
	if GetSpellTexture then
		return GetSpellTexture(spellId)
	end
	return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId)
end

function HPT:GetPetSpellbook()
	local list = {}
	local num = HasPetSpells and HasPetSpells()
		or (C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells())
	for i = 1, num or 0 do
		local name, sub, spellId
		if GetSpellBookItemName then
			name, sub = GetSpellBookItemName(i, BOOKTYPE_PET or "pet")
			spellId = GetSpellBookItemInfo and select(2, GetSpellBookItemInfo(i, BOOKTYPE_PET or "pet"))
		elseif C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
			local item = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Pet)
			if item then
				name, sub, spellId = item.name, item.subName, item.spellID or item.actionID
			end
		end
		-- Pet commands and stances (Attack, Follow, Passive, ...) come back as packed
		-- action IDs above 2^24, not spell IDs.
		if type(spellId) ~= "number" or spellId >= 0x1000000 then
			spellId = nil
		end
		list[#list + 1] = { name = name, sub = sub, spellId = spellId, icon = spellId and SpellIcon(spellId) }
	end
	return list
end

local function TooltipText(fill)
	local tip = HPT:EnsureScanTooltip()
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	local lines = {}
	if pcall(fill, tip) then
		local name = tip:GetName()
		for n = 1, tip:NumLines() or 0 do
			local left = _G[name .. "TextLeft" .. n]
			local right = _G[name .. "TextRight" .. n]
			local l = left and left:GetText()
			local r = right and right:IsShown() and right:GetText()
			if l and l ~= "" then
				lines[#lines + 1] = (r and r ~= "") and (l .. " [" .. r .. "]") or l
			end
		end
	end
	tip:Hide()
	return table.concat(lines, " / ")
end

-- Differences between one observed Beast Training row and Data.lua. Empty = matches.
function HPT:CheckObservedRow(r)
	local issues = {}
	local info = D.Abilities[r.ability]
	if not D.Families[r.family] then
		issues[#issues + 1] = "NEW FAMILY"
	end
	if not info then
		issues[#issues + 1] = "NEW ABILITY"
		return issues
	end
	if D.Families[r.family] and not self:AbilityAvailableForFamily(r.ability, r.family) then
		issues[#issues + 1] = "FAMILY (data doesn't list " .. r.family .. ")"
	end
	if info.source == "innate" then
		issues[#issues + 1] = "SOURCE (data says innate)"
	end
	local data = r.rank and info.ranks[r.rank]
	if not data then
		issues[#issues + 1] = "NEW RANK"
		return issues
	end
	if r.level and data.level ~= r.level then
		issues[#issues + 1] = "LEVEL (data " .. Str(data.level) .. ")"
	end
	if r.spellId and data.spellId ~= r.spellId then
		issues[#issues + 1] = "SPELLID (data " .. Str(data.spellId) .. ")"
	end
	if r.status ~= "used" and r.cost and (r.known or 0) < r.rank then
		local expected = self:GetRankUpgradeCost(r.ability, r.known or 0, r.rank)
		if r.cost ~= expected then
			issues[#issues + 1] = "COST (data " .. expected .. ")"
		end
	end
	if r.icon and not D.AbilityIcons[r.ability] then
		issues[#issues + 1] = "ICON"
	end
	return issues
end

local function KnownRanksText(ranks)
	local list = {}
	for ability, rank in pairs(ranks) do
		list[#list + 1] = ability .. " " .. rank
	end
	table.sort(list)
	return table.concat(list, ", ")
end

function HPT:RecordObservations(o)
	if not self:IsBeastTrainingOpen() or not UnitExists("pet") then
		return
	end
	local family = UnitCreatureFamily("pet") or "?"
	local petLevel = UnitLevel("pet")
	o = o or Observed()
	local petRanks = self:GetPetKnownRanks()
	local listed = {}

	for i = 1, GetNumTrainerServices() or 0 do
		local name, status, icon, reqLevel, rankText = GetTrainerServiceInfo(i)
		if name and status ~= "header" then
			listed[name] = true
			local rank = tonumber((rankText or ""):match("(%d+)"))
			local r = {
				family = family,
				ability = name,
				rank = rank,
				rankText = rankText,
				status = status,
				cost = GetTrainerServiceCost(i),
				level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or reqLevel,
				spellId = self:GetTrainerServiceSpellId(i),
				icon = icon,
				known = petRanks[name] or 0,
				petLevel = petLevel,
			}
			local key = family .. "|" .. name .. "|" .. Str(rank)
			if o.test or #self:CheckObservedRow(r) > 0 then
				local index = i
				r.tip = TooltipText(function(tip) tip:SetTrainerService(index) end)
				o.rows[key] = r
			else
				o.rows[key] = nil
			end
		end
	end

	for _, s in ipairs(self:GetPetSpellbook()) do
		if s.spellId and not IsSpeciesTrait(s.name) and (o.test or not self:RankForSpellId(s.spellId)) then
			local key = family .. "|" .. s.spellId
			local seen = o.book[key]
			if not seen or (petLevel and seen.petLevel and petLevel < seen.petLevel) then
				local id = s.spellId
				o.book[key] = {
					family = family, name = s.name, sub = s.sub, spellId = id, icon = s.icon, petLevel = petLevel,
					tip = TooltipText(function(tip) tip:SetSpellByID(id) end),
				}
			end
		end
	end

	local loyalty = self:GetPetLoyaltyLevel()

	-- Beast Training only lists what the hunter has learned, so remember everything it has
	-- listed for this character, for any pet.
	local db = self:GetDB()
	db.hunterKnows = db.hunterKnows or {}
	local charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
	db.hunterKnows[charKey] = db.hunterKnows[charKey] or {}
	local hunterKnows = db.hunterKnows[charKey]
	for ability in pairs(listed) do
		hunterKnows[ability] = true
	end

	-- Abilities the hunter knows and the data says this family can learn, but Beast
	-- Training doesn't list for this pet (only meaningful with every filter ticked).
	local _, allOn = self:GetTrainerFilterState()
	if allOn and D.Families[family] then
		local trainer, wild = {}, {}
		for _, ability in ipairs(D.AbilityOrder) do
			local info = D.Abilities[ability]
			if info and hunterKnows[ability] and not listed[ability] and info.source ~= "innate"
				and self:AbilityAvailableForFamily(ability, family) then
				table.insert(info.source == "wild" and wild or trainer, ability)
			end
		end
		local key = family .. "|" .. Str(loyalty)
		if #trainer + #wild > 0 then
			o.missing[key] = {
				family = family, loyalty = loyalty, petLevel = petLevel,
				trainer = table.concat(trainer, ", "), wild = table.concat(wild, ", "),
			}
		else
			o.missing[key] = nil
		end
	end

	local remaining = self:GetTrainerPointsRemaining()
	if loyalty and remaining and petLevel then
		local spent = 0
		for ability, rank in pairs(petRanks) do
			spent = spent + self:GetRankTotalCost(ability, rank)
		end
		o.tp[petLevel .. "|" .. loyalty] = {
			level = petLevel, loyalty = loyalty, remaining = remaining, spent = spent,
			family = family, ranks = KnownRanksText(petRanks),
		}
	end
end

local function SortedValues(t, less)
	local list = {}
	for _, v in pairs(t) do
		list[#list + 1] = v
	end
	table.sort(list, less)
	return list
end

-- Report entries for everything that still disagrees with Data.lua.
-- Each entry is { text, sig }; sig identifies the reported values so a sent entry
-- is only reported again when the game shows something different. Section headers have no sig.
-- Returns entries and the number of entries skipped because they were already sent.
function HPT:BuildDataReportLines(o, includeSent)
	o = o or Observed()
	local saved = Observed()
	saved.sent = saved.sent or {}
	local sent = saved.sent
	local lines, present, skipped = {}, {}, 0
	local section
	local function Add(header, text, sig)
		present[sig] = true
		if sent[sig] and not includeSent and not o.test then
			skipped = skipped + 1
			return
		end
		if header ~= section then
			lines[#lines + 1] = { text = header }
			section = header
		end
		lines[#lines + 1] = { text = text, sig = sig }
	end
	local function WithTip(text, tip)
		if tip and tip ~= "" then
			return text .. "\n  tip: " .. tip
		end
		return text
	end
	for key, s in pairs(o.book) do
		if s.spellId >= 0x1000000 or IsSpeciesTrait(s.name) then
			o.book[key] = nil
		end
	end

	local rows = SortedValues(o.rows, function(a, b)
		if a.family ~= b.family then return a.family < b.family end
		if a.ability ~= b.ability then return a.ability < b.ability end
		return (a.rank or 0) < (b.rank or 0)
	end)
	for _, r in ipairs(rows) do
		local issues = self:CheckObservedRow(r)
		if #issues == 0 and o.test then
			issues = { "TEST" }
		end
		if #issues == 0 then
			o.rows[r.family .. "|" .. r.ability .. "|" .. Str(r.rank)] = nil
		else
			local found = table.concat(issues, ", ")
			local sig = table.concat({ "row", r.family, r.ability, Str(r.rank), Str(r.level), Str(r.cost),
				Str(r.known), Str(r.spellId), Str(r.icon), found }, "|")
			Add("## Beast Training: " .. r.family, WithTip(
				("- %s %s | lvl %s | cost %s (pet knows %s) | %s | spell %s | icon %s | pet L%s -> %s"):format(
					r.ability, Str(r.rank or r.rankText), Str(r.level), Str(r.cost), Str(r.known), Str(r.status),
					Str(r.spellId), Str(r.icon), Str(r.petLevel), found), r.tip), sig)
		end
	end

	local book = {}
	for key, s in pairs(o.book) do
		if self:RankForSpellId(s.spellId) and not o.test then
			o.book[key] = nil
		else
			book[#book + 1] = s
		end
	end
	table.sort(book, function(a, b)
		if a.family ~= b.family then return a.family < b.family end
		return (a.name or "") < (b.name or "")
	end)
	local bookHeader = o.test and "## Pet spellbook" or "## Pet spells not in data"
	for _, s in ipairs(book) do
		Add(bookHeader, WithTip(("- %s | %s %s | spell %s | icon %s | first seen pet L%s"):format(
			s.family, Str(s.name), Str(s.sub), Str(s.spellId), Str(s.icon), Str(s.petLevel)), s.tip),
			"book|" .. s.family .. "|" .. s.spellId)
	end

	local tpLines = {}
	local missing = SortedValues(o.missing or {}, function(a, b)
		if a.family ~= b.family then return a.family < b.family end
		return (a.loyalty or 0) < (b.loyalty or 0)
	end)
	for _, m in ipairs(missing) do
		Add("## Known to the hunter but not listed for this pet (all filters on)",
			("- %s pet L%s loyalty %s | trainer abilities: %s | wild abilities: %s"):format(
				m.family, Str(m.petLevel), Str(m.loyalty),
				m.trainer ~= "" and m.trainer or "none", m.wild ~= "" and m.wild or "none"),
			table.concat({ "missing", m.family, Str(m.loyalty), m.trainer, m.wild }, "|"))
	end

	-- Readings that match the formula stay saved as evidence; "all" lists them.
	-- The trainer label never goes below 0, so a pet tamed with more TP of abilities
	-- than it has (loyalty 1 = 0 TP) shows 0, not a negative number.
	local function ExpectedRemaining(t)
		return math.max(0, self:GetTheoryMaxTP(t.level, t.loyalty) - t.spent)
	end
	for _, t in pairs(o.tp) do
		if t.remaining ~= ExpectedRemaining(t) or o.test or includeSent then
			tpLines[#tpLines + 1] = t
		end
	end
	table.sort(tpLines, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.loyalty < b.loyalty
	end)
	for _, t in ipairs(tpLines) do
		local theory = self:GetTheoryMaxTP(t.level, t.loyalty)
		local expected = ExpectedRemaining(t)
		local verdict = " (matches)"
		if t.remaining > expected then
			verdict = " MISMATCH (loyalty may be out of date: open the Pet tab, then Beast Training)"
		elseif t.remaining < expected then
			verdict = " MISMATCH"
		end
		Add("## Training points vs formula", ("- pet L%d loyalty %d (%s): remaining %d, spent %d, formula total %d, expected remaining %d%s | ranks: %s"):format(
			t.level, t.loyalty, Str(t.family), t.remaining, t.spent, theory, expected, verdict,
			t.ranks ~= "" and t.ranks or "none"),
			("tp|%d|%d|%d|%d"):format(t.level, t.loyalty, t.remaining, t.spent))
	end

	if not o.test then
		for sig in pairs(sent) do
			if not present[sig] then
				sent[sig] = nil
			end
		end
	end
	return lines, skipped
end

function HPT:ClearObservations()
	self:GetDB().observed = nil
	self:ShowDevText("Saved report data cleared. New data is recorded the next time Beast Training opens.")
end

function HPT:MarkReportSent(sigs)
	local saved = Observed()
	saved.sent = saved.sent or {}
	for sig in pairs(sigs) do
		saved.sent[sig] = date("%Y-%m-%d")
	end
end

local function UrlEncode(s)
	return (s:gsub("[^%w%-%._~]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

-- URL-safe base64 without padding (- and _ instead of + and /).
local function Base64(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = 4 - (b and 0 or 1) - (c and 0 or 1)
		for k = 1, chars do
			local v = math.floor(n / 64 ^ (4 - k)) % 64
			out[#out + 1] = B64:sub(v + 1, v + 1)
		end
	end
	return table.concat(out)
end

-- "HPTZ1:" = zlib + base64, "HPTB1:" = base64 only (client without C_EncodingUtil).
-- tools\Read-Reports.ps1 decodes both.
local function EncodeReport(text)
	local prefix, data = "HPTB1:", text
	local E = C_EncodingUtil
	if E and E.CompressString and Enum.CompressionMethod and Enum.CompressionMethod.Zlib then
		local ok, packed = pcall(E.CompressString, text, Enum.CompressionMethod.Zlib)
		if ok and packed then
			prefix, data = "HPTZ1:", packed
		end
	end
	local encoded = Base64(data)
	local wrapped = {}
	for i = 1, #encoded, 76 do
		wrapped[#wrapped + 1] = encoded:sub(i, i + 75)
	end
	return prefix .. "\n" .. table.concat(wrapped, "\n")
end

local function IssueUrl(title, header, body, compress)
	local report = header .. "\n" .. body
	if compress then
		report = header .. "\n" .. EncodeReport(report)
	end
	return HPT.ISSUE_URL .. "?template=data-report.yml&title=" .. UrlEncode(title) .. "&report=" .. UrlEncode(report)
end

-- Groups entries into parts whose links fit MAX_URL; a part that starts mid-section repeats its header.
local function SplitParts(entries, title, header, compress)
	local parts, current, section = {}, {}, nil
	local function Body(list)
		local text = {}
		for i, e in ipairs(list) do
			text[i] = e.text
		end
		return table.concat(text, "\n")
	end
	for _, e in ipairs(entries) do
		if not e.sig then
			section = e
		end
		current[#current + 1] = e
		if #current > 1 and #IssueUrl(title .. " part 99/99", header, Body(current), compress) > MAX_URL then
			current[#current] = nil
			if current[#current] == section and #current > 1 then
				current[#current] = nil
			end
			parts[#parts + 1] = current
			current = (e.sig and section) and { section, e } or { e }
		end
	end
	parts[#parts + 1] = current
	for n, part in ipairs(parts) do
		local sigs = {}
		for _, e in ipairs(part) do
			if e.sig then
				sigs[e.sig] = true
			end
		end
		parts[n] = { body = Body(part), sigs = sigs }
	end
	return parts
end

-- mode: nil = new entries, "all" = include entries already sent,
-- "test" = every Beast Training row and pet spell, without reading or changing saved data.
function HPT:ShowDataReport(mode)
	local test = mode == "test"
	local o = test and Scratch() or nil
	self:RecordObservations(o)
	local lines, skipped = self:BuildDataReportLines(o, mode == "all")
	local _, build, _, toc = GetBuildInfo()
	local header = ("HPT %s | build %s | interface %s | %s%s"):format(
		self.VERSION, Str(build), Str(toc), date("%Y-%m-%d"), test and " | TEST" or "")

	if test and not self:IsBeastTrainingOpen() then
		self:ShowDevText("Test report: open Beast Training with your pet out first.")
		return
	end
	if UnitExists("pet") and not self:GetPetLoyaltyLevel() then
		header = header .. "\n(loyalty unknown: open the Pet tab of the Character window, then Beast Training, for training point readings)"
	end
	if #lines == 0 then
		local text = header .. "\n\nNothing new to report. Everything seen at Beast Training matches the addon's data."
		if skipped > 0 then
			text = text .. ("\n\n%d already-sent entries are hidden; /hpt report all shows them again."):format(skipped)
		end
		self:ShowDevText(text .. "\n\nNew data is recorded whenever Beast Training is open with your pet out.")
		return
	end

	local families = {}
	for _, e in ipairs(lines) do
		local fam = e.text:match("^## Beast Training: (.+)$")
		if fam then
			families[#families + 1] = fam
		end
	end
	local title = (test and "TEST " or "") .. "Data report: "
		.. (#families > 0 and table.concat(families, ", ") or "pet data") .. " (HPT " .. self.VERSION .. ")"

	-- Readable unless that needs more than one link; then compressed.
	local compress = false
	local parts = SplitParts(lines, title, header, false)
	if #parts > 1 then
		compress = true
		parts = SplitParts(lines, title, header, true)
	end

	local urls, bodies, linkSize = {}, {}, 0
	for n, part in ipairs(parts) do
		local partTitle = #parts > 1 and ("%s part %d/%d"):format(title, n, #parts) or title
		urls[n] = IssueUrl(partTitle, header, part.body, compress)
		linkSize = linkSize + #urls[n]
		bodies[n] = (#parts > 1 and ("-- Part %d/%d --\n"):format(n, #parts) or "") .. header .. "\n" .. part.body
	end

	local intro = "Click Copy link, paste it into your browser and submit the issue."
	if #urls > 1 then
		intro = intro .. "\nThe report is in " .. #urls .. " parts; use the Part button to switch links and submit each one."
	end
	intro = intro .. ("\nThe issue holds this text %s (%d characters of link)."):format(
		compress and "compressed, because it is too long for one readable link" or "as is", linkSize)
	if test then
		intro = intro .. "\nTest report: nothing is marked as sent."
	elseif skipped > 0 then
		intro = intro .. ("\n%d already-sent entries are hidden; /hpt report all shows them."):format(skipped)
	end
	local onCopy = not test and function(part)
		HPT:MarkReportSent(parts[part].sigs)
	end or nil
	self:ShowDevText(intro .. "\n\nThis is the text the issue will contain:\n\n" .. table.concat(bodies, "\n\n"), urls, onCopy)
end

local recorder = CreateFrame("Frame")
recorder:RegisterEvent("TRAINER_SHOW")
recorder:RegisterEvent("TRAINER_UPDATE")
local pending
recorder:SetScript("OnEvent", function()
	if pending then
		return
	end
	pending = true
	-- After Core has ticked the filters and refreshed the trainer list.
	C_Timer.After(0.5, function()
		pending = false
		HPT:RecordObservations()
	end)
end)

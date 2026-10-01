local HPT = HunterPetTrainer
local D = HunterPetTrainerData

-- Developer window: reports go into a copyable text box and survive /reload.

local MAX_LINES = 800
local memoryLog = {}

local function LogLines()
	if HunterPetTrainerForeverDB then
		HunterPetTrainerForeverDB.devLog = HunterPetTrainerForeverDB.devLog or {}
		if #memoryLog > 0 then
			for _, line in ipairs(memoryLog) do
				table.insert(HunterPetTrainerForeverDB.devLog, line)
			end
			wipe(memoryLog)
		end
		return HunterPetTrainerForeverDB.devLog
	end
	return memoryLog
end

local function Str(v)
	if v == nil then
		return "nil"
	end
	return tostring(v)
end

local function Join(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = Str((select(i, ...)))
	end
	return table.concat(parts, " | ")
end

function HPT:DevLog(msg, ...)
	if select("#", ...) > 0 then
		msg = msg:format(...)
	end
	local lines = LogLines()
	table.insert(lines, date("%H:%M:%S") .. "  " .. msg)
	while #lines > MAX_LINES do
		table.remove(lines, 1)
	end
	if self.devFrame and self.devFrame:IsShown() then
		self:RefreshDevWindow()
	end
end

local function Header(title)
	local _, build, _, toc = GetBuildInfo()
	HPT:DevLog("== %s ==  HPT %s, build %s, interface %s", title, HPT.VERSION, Str(build), Str(toc))
end

function HPT:DevTrainerReport()
	Header("Trainer report")
	local f = _G.ClassTrainerFrame
	local label = _G.ClassTrainerFrameTrainingPointsLabel
	self:DevLog("ClassTrainerFrame shown: %s  |  TP label shown: %s  visible: %s  parent: %s  |  TP label text: %s",
		Str(f and f:IsShown()), Str(label and label:IsShown()), Str(label and label:IsVisible()),
		Str(label and label:GetParent() and label:GetParent():GetDebugName()), Str(label and label:GetText()))
	local title = f and ((f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText or _G.ClassTrainerFrameTitleText)
	self:DevLog("Window title: %s  |  npc: %s  |  hunter level: %s",
		Str(title and title:GetText()), Str(UnitName("npc")), Str(UnitLevel("player")))
	self:DevLog("IsBeastTrainingOpen: %s  |  TP remaining read: %s", Str(self:IsBeastTrainingOpen()), Str(self:GetTrainerPointsRemaining()))
	if not f or not f:IsShown() or not GetNumTrainerServices then
		self:DevLog("Trainer window is not open.")
		return
	end
	local filters, allOn = self:GetTrainerFilterState()
	self:DevLog("Filters: used=%s available=%s unavailable=%s (all on: %s)",
		Str(filters.used), Str(filters.available), Str(filters.unavailable), Str(allOn))
	self:DevLog("Services: %s  |  selection: %s", Str(GetNumTrainerServices()), Str(GetTrainerSelectionIndex and GetTrainerSelectionIndex()))
	local beast = self:IsBeastTrainingOpen()
	local petRanks = beast and self:GetPetKnownRanks() or {}
	self:DevLog("idx | name | rankText | status | cost (%s) | req | spellId | data (level/cost/spellId) | all cost returns",
		beast and "TP" or "copper")
	for i = 1, GetNumTrainerServices() or 0 do
		local name, status, _, reqLevel, rankText = GetTrainerServiceInfo(i)
		local cost = GetTrainerServiceCost(i)
		local costReturns = Join(GetTrainerServiceCost(i))
		local req = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or reqLevel
		local spellId = self:GetTrainerServiceSpellId(i)
		local rank = tonumber((rankText or ""):match("(%d+)"))
		local info = name and D.Abilities[name]
		local data = info and rank and info.ranks[rank]
		local check
		if not info then
			check = "not in data"
		elseif not data then
			check = "rank not in data"
		else
			local flags = {}
			if req and data.level ~= req then flags[#flags + 1] = "LEVEL" end
			if spellId and data.spellId and data.spellId ~= spellId then flags[#flags + 1] = "SPELLID" end
			-- Beast Training charges the upgrade from the pet's current rank; known ranks show 0.
			local expected = self:GetRankUpgradeCost(name, petRanks[name] or 0, rank)
			if beast and cost and cost ~= expected then flags[#flags + 1] = "COST (expected " .. expected .. ")" end
			check = ("%d/%d/%s"):format(data.level or 0, data.cost or 0, Str(data.spellId))
			if #flags > 0 then
				check = check .. "  MISMATCH " .. table.concat(flags, ",")
			end
		end
		self:DevLog("%d | %s | %s | %s | %s | %s | %s | %s | %s", i, Str(name), Str(rankText), Str(status), Str(cost), Str(req), Str(spellId), check, costReturns)
	end
	local known = {}
	for ability, rank in pairs(self:GetKnownTrainerRanks()) do
		known[#known + 1] = ability .. " " .. rank
	end
	table.sort(known)
	self:DevLog("Known per trainer (used rows): %s", #known > 0 and table.concat(known, ", ") or "none")
end

function HPT:DevPetReport()
	Header("Pet report")
	if not UnitExists("pet") then
		self:DevLog("No pet summoned.")
	else
		local xp, xpMax = GetPetExperience()
		self:DevLog("Name: %s  |  family: %s  |  level: %s  |  xp: %s/%s",
			Str(UnitName("pet")), Str(UnitCreatureFamily("pet")), Str(UnitLevel("pet")), Str(xp), Str(xpMax))
	end
	self:DevLog("PetLoyaltyText: %s  |  PetStableLoyaltyText: %s  |  stable badge: %s",
		Str(_G.PetLoyaltyText and _G.PetLoyaltyText:GetText()),
		Str(_G.PetStableLoyaltyText and _G.PetStableLoyaltyText:GetText()),
		Str(PetStableFrame and PetStableFrame.loyaltyLevel and PetStableFrame.loyaltyLevel.levelText
			and PetStableFrame.loyaltyLevel.levelText:GetText()))
	local stats = UnitExists("pet") and self:GetPetStats()
	if stats then
		self:DevLog("Saved stats: loyalty=%s remaining=%s level=%s spent=%s",
			Str(stats.loyalty), Str(stats.remaining), Str(stats.level), Str(stats.spent))
	end
	self:DevLog("GetPetPoints: remaining | total | spent | source = %s", Join(self:GetPetPoints()))

	local num = HasPetSpells and HasPetSpells()
		or (C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells())
	self:DevLog("Pet spellbook slots: %s", Str(num))
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
		local mapped = type(spellId) == "number" and self:RankForSpellId(spellId)
		self:DevLog("  %d | %s | %s | %s | %s", i, Str(name), Str(sub), Str(spellId),
			mapped and (mapped.ability .. " " .. mapped.rank) or "-")
	end

	local known = {}
	for ability, rank in pairs(self:GetPetKnownRanks()) do
		known[#known + 1] = ability .. " " .. rank
	end
	table.sort(known)
	self:DevLog("Known ranks used by planner: %s", #known > 0 and table.concat(known, ", ") or "none")
	local plan = self:EnsureCurrentPetPlan()
	if plan then
		self:DevLog("Current Pet plan: family=%s identity=%s", Str(plan.family), Str(plan.petIdentity))
	end
end

function HPT:DevTaintReport()
	Header("Taint check")
	local f = _G.ClassTrainerFrame
	if not f then
		self:DevLog("ClassTrainerFrame not loaded (open a trainer first).")
		return
	end
	local count = 0
	for key in pairs(f) do
		if type(key) == "string" and not issecurevariable(f, key) then
			self:DevLog("addon-marked field: %s", key)
			count = count + 1
		end
	end
	self:DevLog("%d addon-marked fields on ClassTrainerFrame  |  selection: %s  |  Train enabled: %s",
		count, Str(GetTrainerSelectionIndex and GetTrainerSelectionIndex()),
		Str(_G.ClassTrainerTrainButton and _G.ClassTrainerTrainButton:IsEnabled()))
end

-- Phase 0.1c: does SetTrainerServiceTypeFilter from addon code taint the trainer?
function HPT:DevFilterTest()
	Header("Filter test")
	if not self:IsBeastTrainingOpen() or not SetTrainerServiceTypeFilter then
		self:DevLog("Open Beast Training first.")
		return
	end
	local before = self:GetTrainerFilterState()
	self:DevLog("Before: used=%s available=%s unavailable=%s", Str(before.used), Str(before.available), Str(before.unavailable))
	local changed = false
	for _, key in ipairs({ "used", "available", "unavailable" }) do
		if not before[key] then
			SetTrainerServiceTypeFilter(key, true)
			changed = true
		end
	end
	if not changed then
		SetTrainerServiceTypeFilter("unavailable", false)
		SetTrainerServiceTypeFilter("unavailable", true)
	end
	local after = self:GetTrainerFilterState()
	self:DevLog("Addon called SetTrainerServiceTypeFilter. After: used=%s available=%s unavailable=%s",
		Str(after.used), Str(after.available), Str(after.unavailable))
	C_Timer.After(0.3, function()
		HPT:DevTaintReport()
		HPT:DevLog("Now click a row and Train by hand. A TRAINED or BLOCKED line will appear here.")
	end)
end

local watchEvents = {
	"TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "UNIT_PET", "PET_BAR_UPDATE",
	"SPELLS_CHANGED", "UNIT_PET_TRAINING_POINTS", "PET_STABLE_SHOW", "PET_STABLE_UPDATE",
}

local always = CreateFrame("Frame")
always:RegisterEvent("ADDON_ACTION_FORBIDDEN")
always:RegisterEvent("ADDON_ACTION_BLOCKED")
always:RegisterEvent("CHAT_MSG_SYSTEM")
always:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_SYSTEM" then
		local msg = ...
		if msg and msg:find("learned") then
			HPT:DevLog("TRAINED: %s", msg)
		end
	else
		HPT:DevLog("BLOCKED (%s): %s", event, Join(...))
	end
end)

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, ...)
	HPT:DevLog("EV %s  %s", event, Join(...))
end)

function HPT:SetDevEventWatch(on)
	self.devWatching = on
	if on then
		for _, e in ipairs(watchEvents) do
			self:RegisterEventIfValid(watcher, e)
		end
		self:DevLog("Event log ON")
	else
		watcher:UnregisterAllEvents()
		self:DevLog("Event log OFF")
	end
	if self.devFrame then
		self.devFrame.eventsBtn:SetText(on and "Events: on" or "Events: off")
	end
end

function HPT:RefreshDevWindow()
	local f = self.devFrame
	if not f then
		return
	end
	f.edit:SetText(table.concat(LogLines(), "\n"))
	C_Timer.After(0, function()
		f.scroll:SetVerticalScroll(f.scroll:GetVerticalScrollRange())
	end)
end

local function MakeButton(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

function HPT:CreateDevWindow()
	if self.devFrame then
		return self.devFrame
	end
	local f = CreateFrame("Frame", "HunterPetTrainerDevFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(720, 460)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	tinsert(UISpecialFrames, "HunterPetTrainerDevFrame")
	if f.TitleText then
		f.TitleText:SetText("HPT Dev — select all, Ctrl+C, paste into chat")
	end

	local buttons = {
		{ "Trainer", 70, function() HPT:DevTrainerReport() end },
		{ "Pet", 50, function() HPT:DevPetReport() end },
		{ "Taint", 56, function() HPT:DevTaintReport() end },
		{ "Filter test", 84, function() HPT:DevFilterTest() end },
		{ "Events: off", 90, function() HPT:SetDevEventWatch(not HPT.devWatching) end },
		{ "Select all", 80, function() f.edit:SetFocus() f.edit:HighlightText() end },
		{ "Clear", 56, function()
			wipe(LogLines())
			HPT:RefreshDevWindow()
		end },
	}
	local prev
	f.buttons = {}
	for _, def in ipairs(buttons) do
		local b = MakeButton(f, def[1], def[2], def[3])
		table.insert(f.buttons, b)
		if prev then
			b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
		else
			b:SetPoint("TOPLEFT", 12, -30)
		end
		if def[1] == "Events: off" then
			f.eventsBtn = b
		end
		prev = b
	end

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -58)
	scroll:SetPoint("BOTTOMRIGHT", -32, 10)
	f.scroll = scroll

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetMaxLetters(0)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(660)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			HPT:RefreshDevWindow()
		end
	end)
	scroll:SetScrollChild(edit)
	f.edit = edit

	self.devFrame = f
	if self.ApplySkin then
		self:ApplySkin()
	end
	f:Hide()
	f:SetScript("OnShow", function()
		HPT:RefreshDevWindow()
	end)
	return f
end

function HPT:ToggleDevWindow()
	local f = self:CreateDevWindow()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end

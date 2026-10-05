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
	if self.devFrame and self.devFrame:IsShown() and not self.devFrame.reportText then
		self:RefreshDevWindow()
	end
end

-- Replaces the log view with fixed text (the data report) until another button is used.
-- urls: optional list of links shown one at a time in a single-line copy box.
-- onCopy(part): called when Copy link is clicked for that part.
function HPT:ShowDevText(text, urls, onCopy)
	local f = self:CreateDevWindow()
	f.reportText = text
	f.reportUrls = urls
	f.reportOnCopy = onCopy
	f.reportPart = 1
	f:Show()
	self:RefreshDevWindow()
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
	self:DevLog("idx | name | rankText | status | cost (%s) | req | spellId | data (level/cost/spellId) | all cost returns | icon",
		beast and "TP" or "copper")
	for i = 1, GetNumTrainerServices() or 0 do
		local name, status, icon, reqLevel, rankText = GetTrainerServiceInfo(i)
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
		self:DevLog("%d | %s | %s | %s | %s | %s | %s | %s | %s | %s", i, Str(name), Str(rankText), Str(status), Str(cost), Str(req), Str(spellId), check, costReturns, Str(icon))
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

	local book = self:GetPetSpellbook()
	self:DevLog("Pet spellbook slots: %d", #book)
	for i, s in ipairs(book) do
		local mapped = s.spellId and self:RankForSpellId(s.spellId)
		self:DevLog("  %d | %s | %s | %s | %s | icon %s", i, Str(s.name), Str(s.sub), Str(s.spellId),
			mapped and (mapped.ability .. " " .. mapped.rank) or "-", Str(s.icon))
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

local function TooltipText(tip)
	local lines = {}
	local name = tip:GetName()
	for n = 1, tip:NumLines() or 0 do
		local left = _G[name .. "TextLeft" .. n]
		local right = _G[name .. "TextRight" .. n]
		local l = left and left:GetText()
		local r = right and right:IsShown() and right:GetText()
		if l and l ~= "" then
			lines[#lines + 1] = (r and r ~= "") and (l .. "  [" .. r .. "]") or l
		end
	end
	return lines
end

function HPT:DevTooltipReport()
	Header("Tooltips")
	if not _G.ClassTrainerFrame or not _G.ClassTrainerFrame:IsShown() then
		self:DevLog("Open Beast Training first.")
		return
	end
	local tip = self:EnsureScanTooltip()
	for i = 1, GetNumTrainerServices() or 0 do
		local name, status, _, _, rankText = GetTrainerServiceInfo(i)
		if name and status ~= "header" then
			tip:SetOwner(UIParent, "ANCHOR_NONE")
			if pcall(tip.SetTrainerService, tip, i) then
				self:DevLog("-- %d %s %s", i, name, Str(rankText))
				for _, line in ipairs(TooltipText(tip)) do
					self:DevLog("     %s", line)
				end
			end
			tip:Hide()
		end
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

local function Describe(v)
	if v == nil then
		return "nil"
	end
	local t = type(v)
	if t ~= "table" then
		return t .. " " .. tostring(v)
	end
	local keys = {}
	for k in pairs(v) do
		keys[#keys + 1] = tostring(k)
	end
	table.sort(keys)
	return "table{" .. table.concat(keys, ",") .. "}"
end

-- Does scrolling ClassTrainerFrame.ScrollBox from addon code taint Train?
-- Only scrolls; does not select a row or call BuyTrainerService.
function HPT:DevScrollTest()
	Header("Scroll test")
	if not self:IsBeastTrainingOpen() then
		self:DevLog("Open Beast Training first.")
		return
	end
	local box = _G.ClassTrainerFrame and _G.ClassTrainerFrame.ScrollBox
	if not box then
		self:DevLog("ClassTrainerFrame.ScrollBox is missing.")
		return
	end
	self:DevLog("ScrollBox APIs: ScrollToElementData=%s  ScrollToElementDataIndex=%s  SetScrollPercentage=%s  GetDataProvider=%s  EnumerateFrames=%s",
		Str(box.ScrollToElementData ~= nil), Str(box.ScrollToElementDataIndex ~= nil),
		Str(box.SetScrollPercentage ~= nil), Str(box.GetDataProvider ~= nil), Str(box.EnumerateFrames ~= nil))

	local name, rank, index
	local step = self:IsCurrentPetActive() and UnitExists("pet") and select(1, self:BuildApplyPlan())[1]
	if step then
		name, rank = step.ability, step.trainRank
		for i = 1, GetNumTrainerServices() or 0 do
			local n, status, _, _, rankText = GetTrainerServiceInfo(i)
			if n == name and status ~= "header" and tonumber((rankText or ""):match("(%d+)")) == rank then
				index = i
				break
			end
		end
		self:DevLog("Target from plan: %s %s (service %s)", name, Str(rank), Str(index))
	else
		for i = GetNumTrainerServices() or 0, 1, -1 do
			local n, status, _, _, rankText = GetTrainerServiceInfo(i)
			if n and status ~= "header" then
				name, rank, index = n, tonumber((rankText or ""):match("(%d+)")), i
				break
			end
		end
		self:DevLog("No planned rank; using last list row: %s %s (service %s)", Str(name), Str(rank), Str(index))
	end
	if not index then
		self:DevLog("No trainer row to scroll to.")
		return
	end

	local visibleBefore = self:FindTrainerRowButton(name, rank)
	self:DevLog("Row visible before scroll: %s", visibleBefore and "yes" or "no")

	if box.EnumerateFrames then
		local ok, frame = pcall(function()
			for _, f in box:EnumerateFrames() do
				return f
			end
		end)
		local data = ok and frame and frame.GetElementData and frame:GetElementData()
		self:DevLog("First visible element data: %s", Describe(data))
	end

	local function Try(label, fn)
		local ok, err = pcall(fn)
		self:DevLog("  %s: %s", label, ok and "ok" or tostring(err))
		return ok
	end

	local provider = box.GetDataProvider and box:GetDataProvider()
	local element
	if provider then
		self:DevLog("DataProvider: GetSize=%s FindElementDataByPredicate=%s",
			Str(provider.GetSize ~= nil), Str(provider.FindElementDataByPredicate ~= nil))
		if provider.FindElementDataByPredicate then
			local ok, found = pcall(function()
				return provider:FindElementDataByPredicate(function(el)
					if type(el) == "number" then
						return el == index
					end
					if type(el) ~= "table" then
						return false
					end
					return el.skillIndex == index or el.index == index or el.serviceIndex == index
				end)
			end)
			if ok then
				element = found
			end
			self:DevLog("FindElementDataByPredicate: %s", Describe(element))
		end
	end

	if box.ScrollToElementDataIndex then
		Try("ScrollToElementDataIndex(" .. index .. ")", function()
			box:ScrollToElementDataIndex(index)
		end)
	end
	if element and box.ScrollToElementData then
		Try("ScrollToElementData", function()
			box:ScrollToElementData(element)
		end)
	end
	if box.SetScrollPercentage then
		local total = math.max(1, (GetNumTrainerServices() or 1) - 1)
		Try(("SetScrollPercentage(%.2f)"):format((index - 1) / total), function()
			box:SetScrollPercentage((index - 1) / total)
		end)
	end

	C_Timer.After(0.3, function()
		local visibleAfter = HPT:FindTrainerRowButton(name, rank)
		HPT:DevLog("Row visible after scroll: %s", visibleAfter and "yes" or "no")
		HPT:DevTaintReport()
		HPT:DevLog("Now use Train next, or click the row and Train by hand. A TRAINED or BLOCKED line will appear here.")
	end)
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

local function PlannedTrainerRow()
	local step = HPT:IsCurrentPetActive() and UnitExists("pet") and select(1, HPT:BuildApplyPlan())[1]
	if not step then
		return nil
	end
	local name, rank = step.ability, step.trainRank
	for i = 1, GetNumTrainerServices() or 0 do
		local n, status, _, _, rankText = GetTrainerServiceInfo(i)
		if n == name and status ~= "header" and tonumber((rankText or ""):match("(%d+)")) == rank then
			return name, rank, i, status
		end
	end
	return name, rank, nil, nil
end

-- Show only "available" rows so the planned rank may appear without scrolling.
-- SetTrainerServiceTypeFilter did not taint Train on October 1; this checks whether
-- narrowing the list is enough for Train next, without touching ScrollBox.
function HPT:DevAvailableFilterTest()
	Header("Available-only filter")
	if not self:IsBeastTrainingOpen() or not SetTrainerServiceTypeFilter then
		self:DevLog("Open Beast Training first.")
		return
	end
	local before = self:GetTrainerFilterState()
	local name, rank, index, status = PlannedTrainerRow()
	self:DevLog("Before: used=%s available=%s unavailable=%s  |  services=%s",
		Str(before.used), Str(before.available), Str(before.unavailable), Str(GetNumTrainerServices()))
	if name then
		self:DevLog("Plan: %s %s  service=%s  status=%s  visible=%s",
			name, Str(rank), Str(index), Str(status),
			self:FindTrainerRowButton(name, rank) and "yes" or "no")
	else
		self:DevLog("No planned rank. The list will still be narrowed so you can look.")
	end
	SetTrainerServiceTypeFilter("used", false)
	SetTrainerServiceTypeFilter("unavailable", false)
	SetTrainerServiceTypeFilter("available", true)
	C_Timer.After(0.3, function()
		local after = HPT:GetTrainerFilterState()
		HPT:DevLog("After: used=%s available=%s unavailable=%s  |  services=%s",
			Str(after.used), Str(after.available), Str(after.unavailable), Str(GetNumTrainerServices()))
		local n2, r2, i2, s2 = PlannedTrainerRow()
		if n2 then
			HPT:DevLog("Plan after filter: %s %s  service=%s  status=%s  visible=%s",
				n2, Str(r2), Str(i2), Str(s2),
				HPT:FindTrainerRowButton(n2, r2) and "yes" or "no")
		end
		HPT:DevTaintReport()
		HPT:DevLog("Filters stay like this until Beast Training closes (then they restore). Use Train next, or Train by hand.")
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
	local urls = f.reportText and f.reportUrls
	f.scroll:SetPoint("TOPLEFT", 12, (urls and #urls > 0) and -86 or -58)
	if urls and #urls > 0 then
		f.urlBox:Show()
		f.urlBox:SetText(urls[f.reportPart] or "")
		f.urlBox:SetCursorPosition(0)
		f.urlBox:SetFocus()
		f.partBtn:SetShown(#urls > 1)
		f.partBtn:SetText(("Part %d/%d"):format(f.reportPart, #urls))
		f.copyBtn:Show()
		f.copyBtn:ClearAllPoints()
		if #urls > 1 then
			f.copyBtn:SetPoint("RIGHT", f.partBtn, "LEFT", -4, 0)
		else
			f.copyBtn:SetPoint("TOPRIGHT", -12, -58)
		end
	else
		f.urlBox:Hide()
		f.partBtn:Hide()
		f.copyBtn:Hide()
	end
	if f.reportText then
		f.edit:SetText(f.reportText)
		C_Timer.After(0, function()
			f.scroll:SetVerticalScroll(0)
		end)
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
	b:SetScript("OnClick", function(self, ...)
		if parent.reportText and not self.keepsReport then
			parent.reportText = nil
			HPT:RefreshDevWindow()
		end
		onClick(self, ...)
	end)
	return b
end

-- Extra dump buttons and taint/filter/event tests are only shown with /hpt debug on.
function HPT:LayoutDevButtons()
	local f = self.devFrame
	if not f then
		return
	end
	local prev
	for _, b in ipairs(f.buttons) do
		b:ClearAllPoints()
		if b.debugOnly and not self.DEBUG then
			b:Hide()
		else
			b:Show()
			if prev then
				b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
			else
				b:SetPoint("TOPLEFT", 12, -30)
			end
			prev = b
		end
	end
end

function HPT:CreateDevWindow()
	if self.devFrame then
		return self.devFrame
	end
	local f = CreateFrame("Frame", "HunterPetTrainerDevFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(1080, 460)
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
		{ "Report", 64, function() HPT:ShowDataReport() end },
		{ "Trainer", 70, function() HPT:DevTrainerReport() end, debugOnly = true },
		{ "Tooltips", 70, function() HPT:DevTooltipReport() end, debugOnly = true },
		{ "Pet", 50, function() HPT:DevPetReport() end, debugOnly = true },
		{ "Test report", 84, function() HPT:ShowDataReport("test") end, debugOnly = true },
		{ "Taint", 56, function() HPT:DevTaintReport() end, debugOnly = true },
		{ "Filter test", 84, function() HPT:DevFilterTest() end, debugOnly = true },
		{ "Avail. only", 80, function() HPT:DevAvailableFilterTest() end, debugOnly = true },
		{ "Scroll test", 84, function() HPT:DevScrollTest() end, debugOnly = true },
		{ "Events: off", 90, function() HPT:SetDevEventWatch(not HPT.devWatching) end, debugOnly = true },
		{ "Select all", 80, function() f.edit:SetFocus() f.edit:HighlightText() end, keepsReport = true },
		{ "Clear", 56, function()
			wipe(LogLines())
			HPT:RefreshDevWindow()
		end },
	}
	f.buttons = {}
	for _, def in ipairs(buttons) do
		local b = MakeButton(f, def[1], def[2], def[3])
		b.debugOnly = def.debugOnly
		b.keepsReport = def.keepsReport
		table.insert(f.buttons, b)
		if def[1] == "Events: off" then
			f.eventsBtn = b
		end
	end
	self.devFrame = f
	self:LayoutDevButtons()

	local partBtn = MakeButton(f, "Part 1/1", 80, function()
		f.reportPart = f.reportPart % #f.reportUrls + 1
		HPT:RefreshDevWindow()
	end)
	partBtn.keepsReport = true
	partBtn:SetPoint("TOPRIGHT", -12, -58)
	partBtn:Hide()
	f.partBtn = partBtn

	local copyBtn = MakeButton(f, "Copy link", 80, function(btn)
		local url = f.reportUrls and f.reportUrls[f.reportPart]
		if url and f.reportOnCopy then
			f.reportOnCopy(f.reportPart)
		end
		f.urlBox:SetFocus()
		f.urlBox:HighlightText(0, #f.urlBox:GetText())
		if url and _G.CopyToClipboard and pcall(_G.CopyToClipboard, url) then
			btn:SetText("Copied!")
		else
			btn:SetText("Ctrl+C now")
		end
		C_Timer.After(2, function()
			btn:SetText("Copy link")
		end)
	end)
	copyBtn.keepsReport = true
	copyBtn:Hide()
	f.copyBtn = copyBtn

	local urlBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	urlBox:SetHeight(20)
	urlBox:SetPoint("TOPLEFT", 18, -59)
	urlBox:SetPoint("RIGHT", copyBtn, "LEFT", -8, 0)
	urlBox:SetAutoFocus(false)
	urlBox:SetMaxLetters(0)
	urlBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText(0, #(self:GetText() or ""))
	end)
	urlBox:SetScript("OnEscapePressed", urlBox.ClearFocus)
	urlBox:SetScript("OnTextChanged", function(_, userInput)
		if userInput then
			HPT:RefreshDevWindow()
		end
	end)
	urlBox:Hide()
	f.urlBox = urlBox

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -58)
	scroll:SetPoint("BOTTOMRIGHT", -32, 10)
	f.scroll = scroll

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetMaxLetters(0)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(1020)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(_, userInput)
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

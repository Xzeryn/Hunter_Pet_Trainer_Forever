local HPT = HunterPetTrainer

-- EllesmereUI third-party skinning (EllesmereUI/SKINNING_API.md). The callback only runs
-- when EllesmereUI is installed and its skinning is on for this addon; otherwise the
-- addon keeps its own look. Every S primitive is idempotent, so ApplySkin can run again
-- whenever another of our windows is created.

local S

local function Font(fs)
	if fs and fs.GetFont then
		S.Font(fs)
	end
end

-- Our flat buttons draw a BackdropTemplate box; drop it so EUI's button art is the only one.
local function FlatButton(btn, keepKeys)
	if not btn or btn.hptSkinned then
		return
	end
	btn.hptSkinned = true
	if btn.SetBackdrop then
		btn:SetBackdrop(nil)
	end
	local ht = btn:GetHighlightTexture()
	if ht then
		ht:SetAlpha(0)
	end
	S.Button(btn, keepKeys)
	Font(btn.label)
	Font(btn.text)
end

local function FlatDropdown(btn)
	if not btn or btn.hptSkinned then
		return
	end
	btn.hptSkinned = true
	btn:SetBackdrop(nil)
	local ht = btn:GetHighlightTexture()
	if ht then
		ht:SetAlpha(0)
	end
	S.Dropdown(btn)
	Font(btn.text)
end

-- S.ScrollBar only handles the modern MinimalScrollBar; match its look (no arrows or
-- track, slim translucent white thumb) on the legacy UIPanelScrollFrameTemplate bar.
local function LegacyScrollBar(scroll)
	local bar = scroll and (scroll.ScrollBar or (scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"]))
	if not bar or bar.hptSkinned then
		return
	end
	bar.hptSkinned = true
	local barName = bar:GetName()
	for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
		local b = bar[key] or (barName and _G[barName .. key])
		if b then
			b:SetAlpha(0)
		end
	end
	local thumb = bar:GetThumbTexture()
	for _, region in ipairs({ bar:GetRegions() }) do
		if region ~= thumb and region.SetAlpha then
			region:SetAlpha(0)
		end
	end
	if thumb then
		thumb:SetVertexColor(1, 1, 1, 1)
		thumb:SetColorTexture(1, 1, 1, 0.3)
		thumb:SetWidth(4)
	end
end

local function SkinPlanner(f)
	if f.hptSkinned then
		return
	end
	f.hptSkinned = true

	-- The planner also lives inside the dock, so its shell sits on a holder that hides when docked.
	local holder = CreateFrame("Frame", nil, f)
	holder:SetAllPoints()
	holder:SetFrameLevel(f:GetFrameLevel())
	S.Shell(holder)
	f.skinShell = holder
	f:SetBackdrop(nil)
	holder:SetShown(not f.embedded)

	S.CloseButton(f.closeBtn)
	FlatDropdown(f.familyDrop)
	FlatDropdown(f.templateDrop)
	LegacyScrollBar(f.scroll)
	FlatButton(f.templateMenuBtn)
	FlatButton(f.applyBtn)
	for _, step in ipairs({ f.levelStep, f.loyaltyStep }) do
		FlatButton(step.minus)
		FlatButton(step.plus)
		Font(step.label)
		Font(step.value)
	end

	if f.calcBar then
		f.calcBar:SetBackdrop(nil)
		S.Panel(f.calcBar, { inset = true })
	end

	for _, fs in ipairs({ f.title, f.familyLabel, f.templateLabel, f.pointsText, f.petText,
		f.templateText, f.statusText, f.tpLabel, f.tpValue }) do
		Font(fs)
	end
	for _, header in pairs(f.sectionHeaders or {}) do
		Font(header.title)
		Font(header.costHint)
	end
	for _, row in ipairs(f.rows or {}) do
		Font(row.nameFS)
		Font(row.compareFS)
		for _, b in pairs(row.buttons or {}) do
			Font(b.fs)
		end
	end
end

local function ColorGlow()
	local glow = HPT.trainNextGlow
	if glow and S then
		local r, g, b = S.GetAccentColor()
		glow:SetBackdropBorderColor(r, g, b, 1)
		if glow.fill then
			glow.fill:SetColorTexture(r, g, b, 0.12)
		end
	end
end

local function SkinDock(dock)
	if dock.hptSkinned then
		return
	end
	dock.hptSkinned = true
	dock:SetBackdrop(nil)
	S.Shell(dock)
	S.CloseButton(dock.closeBtn)
	if dock.footer then
		dock.footer.bg:SetAlpha(0)
		S.Panel(dock.footer, { inset = true })
	end
	Font(dock.title)
	Font(dock.nextLabel)
	Font(dock.hint)
	local button = HPT.trainNextButton
	if button then
		S.Button(button)
		S.StateButtonLabel(button)
		Font(button:GetFontString())
	end
	ColorGlow()
end

local function SkinDev(f)
	if f.hptSkinned then
		return
	end
	f.hptSkinned = true
	S.Shell(f)
	S.CloseButton(f.CloseButton)
	for _, b in ipairs(f.buttons or {}) do
		S.Button(b)
		Font(b:GetFontString())
	end
	LegacyScrollBar(f.scroll)
	Font(f.TitleText)
end

function HPT:ApplySkin()
	if not S or not S.IsEnabled() then
		return
	end
	if self.frame then
		SkinPlanner(self.frame)
	end
	if self.dock then
		SkinDock(self.dock)
	end
	if self.devFrame then
		SkinDev(self.devFrame)
	end
end

if EllesmereUI and EllesmereUI.RegisterSkin then
	EllesmereUI.RegisterSkin("Hunter_Pet_Trainer_Forever", function(skin)
		S = skin
		S.OnLooksChanged(ColorGlow)
		HPT:ApplySkin()
	end)
end

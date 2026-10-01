# Hunter Pet Trainer Forever — Port Plan

**Goal:** A separate addon, *Hunter Pet Trainer Forever*, that plans hunter pet training for WoW Forever (Classic Era based, level cap 60), built from the TBC Anniversary addon v0.5.9.

**Approach:** Copy v0.5.9, keep the parts that don't touch the game (planner, templates, cost math, UI layout), and replace the parts that do. Forever moved Beast Training from the craft window to the class trainer window and removed the pet loyalty and training point functions, so the game-facing layer is new code. Ability data is regenerated for Forever.

**Tech:** Lua 5.1 addon, Interface 16001, Blizzard trainer API. No Lua interpreter on this machine, so all verification is in game (beta client, with BugSack/BugGrabber installed for error capture).

**Source addon:** `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\Hunter_Pet_Trainer` (commit `6236866`, v0.5.9).
**Target:** `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\Hunter_Pet_Trainer_Forever`

**Deadline:** the beta ends **October 21, 2026**. Forever launches November 4, 2026. Every in-game check below must happen before October 21, or wait for launch.

---

## Decisions already made

| Topic | Decision |
|---|---|
| Name | Folder `Hunter_Pet_Trainer_Forever`, title "Hunter Pet Trainer Forever" |
| Repo | New **private** GitHub repo `Xzeryn/Hunter_Pet_Trainer_Forever` (the TBC repo is private) |
| Wowhead import | Keep the code, hide the button and slash command until Wowhead has a Forever pet calculator |
| New family abilities with 0 TP and no trainer (Dismember, Web, Pinch, Swipe, Savage Rend, Tendon Rip, Dust Cloud, Mine!, Lava Breath, Trickster's Dance) | Shown as info-only rows (level and rank shown, not plannable, no TP cost) until the game shows otherwise |
| Faster Attack I–VII, Slower Attack II–III | Not shown. They are separate per-species spells, not trainable ranks |
| TBC addon | Frozen. No further fixes (including the loyalty-name bug) |

## What we confirmed in the Forever beta (October 1)

| Need | Forever API | Evidence |
|---|---|---|
| Interface number | `16001` | `GetBuildInfo()` |
| Pet exists / name | `UnitExists("pet")`, `UnitName("pet")` | `true`, `"Loxley"` |
| Pet XP | `GetPetExperience()` | `745, 1900` |
| Loyalty | `PetLoyaltyText:GetText()` (pet tab font string) | `"Dependable"` — text only, no number |
| Loyalty / TP functions | `GetPetLoyalty`, `GetPetTrainingPoints`, `UnitLoyalty`, `GetStablePetInfo` | **All removed (nil)** |
| Beast Training window | `ClassTrainerFrame` (craft window is gone: `CraftFrame`, `GetNumCrafts` are nil) | Shown, `GetNumTrainerServices() = 4` |
| Ability rows | `GetTrainerServiceInfo(i)` returns `name, status, icon, reqLevel, rankText, ""` | `"Natural Armor", "available", 136094, 1, "Rank 1", ""` |
| Status values | `"used"` (pet knows it), `"available"`, `"unavailable"` (level too low) | Full filtered list of 9 rows |
| TP cost | `GetTrainerServiceCost(i)` | `1` for Natural Armor 1 |
| Required level | `GetTrainerServiceLevelReq(i)` | `12` for Natural Armor 2 |
| Spell ID | `GameTooltip:SetTrainerService(i)` then `GameTooltip:GetSpell()` | `24545` for Natural Armor 1 |
| TP remaining | `ClassTrainerFrameTrainingPointsLabel:GetText()` | `"Training Points: 14"` |
| Select a row in the UI | `ClassTrainer_SetSelection(i)` enables Train; `SelectTrainerService(i)` alone does **not** | `enabled: false` vs `true` |
| Train button | `ClassTrainerTrainButton`, which calls `BuyTrainerService(index)` | Hook printed `BuyTrainerService called with 7` |
| Training by hand | Click the row, click Train (clean UI, EllesmereUI on) | "Your pet has learned a new spell: Natural Armor (Rank 1)", TP 14 → 13 |
| **Training after addon selection** | **Blocked.** `BuyTrainerService` is protected. If addon code calls `ClassTrainer_SetSelection`, the selection is tainted and Train fails with `ADDON_ACTION_FORBIDDEN`, whether Train is pressed with `/click` or with the mouse (both tested after a clean `/reload`) | BugGrabber: `ForceTaint_Strong tried to call the protected function 'BuyTrainerService()'` |
| Known abilities | Rows the pet knows show "Already known" in the window; the API reported them as `"used"` once and as `"available"` with cost 0 another time | Two dumps on October 1 |
| Stable loyalty | `PetStableLoyaltyText:GetText()` = `"Dependable"`; the number badge is `PetStableFrame.loyaltyLevel.levelText:GetText()` = `"4"` (only while the stable is open). Use it to check the name-to-level map | Stable screenshot, frame search |
| Stable slots | Current pet plus 2 stable slots (second costs 5 gold) | Stable screenshot |

**Three windows share `ClassTrainerFrame` (October 1, `/hpt dev` reports):**
- *Beast Training spell* — the pet learns; cost is TP, level is pet level, `"used"` = the pet knows it. Only here is `ClassTrainerFrameTrainingPointsLabel` actually on screen (`IsVisible()`).
- *Pet trainer NPC* — the hunter learns Great Stamina, Natural Armor, Growl and the resistances for gold. Cost is copper, level is hunter level, `"used"` = the hunter knows it. 45 rows; levels and spell IDs match `Data.lua` except Shadow Resistance 4 (trainer 50, data 40; recheck in Beast Training before changing).
- *Hunter class trainer* — hunter spells, none in `Data.lua`.
At both NPCs the TP label reports `IsShown() = true` with stale text but `IsVisible()` is false. `SetTrainerServiceTypeFilter` needs a boolean (`1` errors "Missing on/off parameter").

Confirmed trainer costs (use as data checks): Great Stamina 1 = 5 TP (level 1), Great Stamina 2 = 10 TP (level 12), Natural Armor 1 = 1 TP (level 1), Natural Armor 2 = 5 TP (level 12).

**Max TP formula confirmed:** after a pet talent reset, Loxley (level 10, Dependable = 4) shows 30 TP = level × (loyalty − 1). Known rows display cost 0; unlearned rows show real costs: Cower 1 = 8 TP (level 5), Bite 2 = 4 (level 8), Claw 2 = 4 (level 8), Growl 1 and 2 = 0 (Growl 2 level 10). Before the reset he had 14 left, and 8 + 4 + 4 + 0 = 16 spent, which matches.

**Pet talent reset** exists in Forever (costs gold) and returns all TP; the addon should treat it like a pet swap: re-read known ranks, keep the plan.

---

## Phase 0 — Blockers to resolve before building the trainer features

These don't block Tasks 1–3, but they decide how Tasks 4–6 are built. Each is an in-game check.

- [x] **0.1 Why training failed.** Resolved October 1: training works by hand. Earlier failures came from test commands tainting the trainer selection. Addon-made selections can't be trained (see the findings table), which reshapes Task 6.
- [x] **0.1b Secure row click.** Works (October 1, `HPT_ClickTest`). A `SecureActionButtonTemplate` button with `type = "click"` and `clickbutton = <row frame>` selects the row with 0 addon-marked fields; a mouse click on Train then trained Growl 1. Rows are found by scanning `ClassTrainerFrame.ScrollBox.ScrollTarget` children for the ability name and rank text.
  - The one-press macro (`/click <row alias>` then `/click ClassTrainerTrainButton`) is **unsafe**: it trained Natural Armor 1 instead of Growl 2. The row click did nothing, and Train bought whatever Blizzard had auto-selected. Never ship it. It does show that a secure-macro `/click ClassTrainerTrainButton` is not blocked.
- [x] **0.1c Filters and taint.** Resolved October 1: the addon set the `used` filter, the taint check found 0 marked fields, and a hand Train of Bite 2 worked. Task 4 now ticks all filters on Beast Training open and restores them on close. Original check: calling `SetTrainerServiceTypeFilter` from addon code also taints the trainer (train by hand afterwards and watch BugSack). If it does, Task 4 must not change filters and should ask you to tick them instead.
- [ ] **0.2 Max TP formula.** Only one pet so far. At each level-up or loyalty change, record level, loyalty, the trainer's "Training Points" value and anything trained since the last record.
- [x] **0.3 Pet trainer vs class trainer.** Resolved October 1: the TP label is `IsVisible()` only in the Beast Training spell window (see "Three windows" above). Beast Training also lists known ranks as `"available"` with cost 0, and charges the upgrade cost (`cost(target) - cost(known)`), e.g. Great Stamina 2 = 5 with rank 1 known. Original check: Hunters also use `ClassTrainerFrame` at their class trainer. Open the hunter class trainer and run
  `/dump ClassTrainerFrameTrainingPointsLabel:IsShown(), GetTrainerServiceInfo(1)`
  If the TP label is hidden there and shown at the pet trainer, that is how the addon tells them apart.
- [ ] **0.4 Stable master.** With the stable open: `/dump PetStableLoyaltyText and PetStableLoyaltyText:GetText()` and screenshot the stable. Tells us whether loyalty is shown as a number there and whether the stable lists all three slots' level and loyalty.
- [ ] **0.5 Trainer events.** With a chat-frame event trace, confirm which events fire on open, train and close:
  `/run local f=CreateFrame("Frame") for _,e in ipairs({"TRAINER_SHOW","TRAINER_UPDATE","TRAINER_CLOSED","UNIT_PET","PET_BAR_UPDATE","SPELLS_CHANGED"}) do f:RegisterEvent(e) end f:SetScript("OnEvent",function(_,e,...) print("EV",e,...) end)`
- [ ] **0.6 Does the pet tab need to be opened once?** After `/reload`, without opening the Character pet tab, run `/dump PetLoyaltyText:GetText()`. If it's empty, the addon must read loyalty after the pet tab has been shown, or from another place.

---

## Task 1 — Create the Forever addon and repo

**Files**
- Copy every `.lua`, `.toc`, `README.md` from the TBC folder into the beta folder `Hunter_Pet_Trainer`, then rename that folder to `Hunter_Pet_Trainer_Forever` (this plan file moves with it).
- Rename `Hunter_Pet_Trainer.toc` → `Hunter_Pet_Trainer_Forever.toc`.

**Steps**
- [ ] Copy files, rename folder and `.toc`.
- [ ] Edit the `.toc`:

```
## Interface: 16001
## Title: Hunter Pet Trainer Forever
## Notes: Plan pet training for WoW Forever and assist training at the pet trainer
## Author: Xzeryn
## Version: 0.1.0
## SavedVariables: HunterPetTrainerForeverDB
```

- [ ] In `Core.lua`: set `HPT.VERSION = "0.1.0"`, change the `ADDON_LOADED` check from `"Hunter_Pet_Trainer"` to `"Hunter_Pet_Trainer_Forever"`, and change every `HunterPetTrainerDB` reference to `HunterPetTrainerForeverDB`. (Global table names `HunterPetTrainer` / `HunterPetTrainerData` and the `/hpt` command stay; the two addons never load in the same client.)
- [ ] Set `theoryLevel = 60` in the defaults, and clamp the theory level control in `UI.lua` to 1–60.
- [ ] Hide Wowhead import: remove the Import button from `UI.lua` layout (keep the file and functions), and drop `wowhead` from the `/hpt` help and dispatcher.
- [ ] `git init`, add a `.gitignore` matching the TBC repo, create the GitHub repo with `gh repo create Xzeryn/Hunter_Pet_Trainer_Forever --private`, first commit, push with `-u`.

**Check in game:** addon shows as "Hunter Pet Trainer Forever" in the AddOn list without "out of date"; `/hpt` opens the window; BugSack shows errors from the craft code (expected until Task 4), and nothing else.

---

## Task 2 — Forever ability data

**Status (October 1):** generator written and run: 31 abilities (8 trainer, 13 wild, 10 info-only), 19 families, all trainer checks pass. Petopia is a single page (`abilities.php`) with one `<h3 id=…>` section per ability, so no per-ability pages are needed. Icons fall back to Wowhead's embedded spell data (Mine!). Info-only abilities get their own "Learned with level (info only)" section with pet levels instead of costs, and are skipped by the apply plan.

**Still to confirm in game:** the family name the client reports for owls (`UnitCreatureFamily("pet")`): Petopia says "Birds of Prey", TBC used "Owl". Same check for Core Hound and Fox.

**Files**
- Create: `tools/Build-ForeverData.ps1` — downloads Wowhead and Petopia, writes `Data.lua` and `SpellIds.lua`.
- Replace: `Data.lua`, `SpellIds.lua`.

**Data shape** (unchanged from TBC so the planner keeps working, plus two new fields):

```lua
D.Abilities["Natural Armor"] = {
  active = false,
  families = { "ALL" },
  source = "trainer",        -- NEW: "trainer" | "wild" | "innate" (innate = info-only)
  ranks = {
    [1] = { level = 1,  cost = 1, spellId = 24545 },  -- NEW: spellId per rank
    [2] = { level = 12, cost = 5, spellId = 24549 },
  },
}
```

**Steps**
- [ ] **Wowhead (spell IDs, ranks, levels).** In the script, download `https://www.wowhead.com/forever/spells/pet-abilities/hunter` and parse with this regex, which already returned 147 rows on October 1:
  `"id":(\d+),"level":(\d+),"name":"([^"]+)"[^}]*?"rank":"Rank (\d+)"`
  Skip `Tamed Pet Passive (DND)`, `Hunter Pet Scaling`, `Summoning`, `Faster Attack *`, `Slower Attack *`.
- [ ] **Petopia (TP cost, families, source).** Download `https://www.wow-petopia.com/forever/abilities.php` and each ability page it links to. First save one page to disk and write the parser against its actual HTML. Rows with 0 TP and "No known training source" get `source = "innate"`.
- [ ] Merge: Wowhead decides which ranks exist and their level and spell ID; Petopia adds cost and families. Print a warning list for any rank only one source has (expected: Lava Breath and Trickster's Dance are Petopia-only).
- [ ] Rebuild `D.Families` for Forever, including Core Hound, Fox and Bird of Prey, and drop TBC-only families (Dragonhawk, Nether Ray, Ravager, Serpent, Sporebat, Warp Stalker) unless Petopia lists them for Forever.
- [ ] Drop TBC-only abilities (Gore, Warp, Poison Spit, Fire Breath, Avoidance, Cobra Reflexes) unless Forever has them. Replace Screech with Demoralizing Screech.
- [ ] Update `D.AbilityOrder` and `D.AbilityIcons` for new abilities (icon IDs can be numbers, e.g. `136094`, from the trainer or Wowhead).
- [ ] Assert in the script: Natural Armor 1 = level 1 / 1 TP / 24545; Natural Armor 2 = level 12 / 5 TP; Great Stamina 1 = 5 TP; Great Stamina 2 = level 12 / 10 TP. Fail loudly if Petopia disagrees with the trainer; the trainer wins.

**Check:** the script runs clean; `/hpt` lists Forever families and abilities; Loxley's known ranks add up to 16 TP (Phase 0.2 confirms the formula).

---

## Task 3 — Live pet stats without the removed functions

**Status (October 1):** built. Loyalty is captured by hooking `PetLoyaltyText:SetText` (the Pet tab text is only fresh when Blizzard sets it) and stored per pet in `db.petStats[Name|Family]`. Remaining TP is read from `ClassTrainerFrameTrainingPointsLabel` via a hook on `ClassTrainerFrame_UpdateTrainingPoints` plus `TRAINER_SHOW/UPDATE`; spent TP is stored per pet. `GetPetPoints` returns a 4th value, `source` = `"trainer"`, `"cached"` or `"estimate"`; the bar greys out and explains itself when not live. Known ranks match pet spellbook entries by spell ID first (classic globals or `C_SpellBook`).

**Files**
- Modify: `Core.lua` — `LOYALTY_NAMES`, `GetPetLoyaltyLevel`, `GetPetPoints`, `GetPetKnownRanks`.

**Interfaces produced**
- `HPT:GetPetLoyaltyLevel() -> number|nil` (1–6)
- `HPT:GetPetPoints() -> remaining, total, spent, isCached` (numbers; `isCached = true` when the value came from the last trainer visit)
- `HPT:RecordTrainerPoints(remaining)` (called by Task 4)

**Steps**
- [ ] Fix loyalty names and map text to level:

```lua
local LOYALTY_NAMES = {
	[1] = "Rebellious",
	[2] = "Unruly",
	[3] = "Submissive",
	[4] = "Dependable",
	[5] = "Faithful",
	[6] = "Best Friend",
}
local LOYALTY_BY_NAME = {}
for level, name in pairs(LOYALTY_NAMES) do
	LOYALTY_BY_NAME[name:lower()] = level
end

function HPT:GetPetLoyaltyLevel()
	if not UnitExists("pet") then
		return nil
	end
	local fs = _G.PetLoyaltyText
	local text = fs and fs.GetText and fs:GetText()
	if not text or text == "" then
		return nil
	end
	return LOYALTY_BY_NAME[strtrim(text):lower()]
end
```

- [ ] Training points: cache per pet identity (`Name|Family`, already used by `GetLivePetIdentity`) in the saved data whenever the trainer is open, and compute the live max from the formula:

```lua
function HPT:RecordTrainerPoints(remaining)
	local id = self:GetLivePetIdentity()
	if not id or not remaining then
		return
	end
	local db = self:GetDB()
	db.petPoints = db.petPoints or {}
	db.petPoints[id] = { remaining = remaining, level = UnitLevel("pet"), loyalty = self:GetPetLoyaltyLevel() }
end

function HPT:GetPetPoints()
	if not UnitExists("pet") then
		return 0, 0, 0, false
	end
	local total = self:GetTheoryMaxTP(UnitLevel("pet"), self:GetPetLoyaltyLevel() or 1)
	local open = self:GetTrainerPointsRemaining()
	if open then
		return open, total, total - open, false
	end
	local cached = (self:GetDB().petPoints or {})[self:GetLivePetIdentity() or ""]
	if cached then
		local spent = self:GetTheoryMaxTP(cached.level, cached.loyalty or 1) - cached.remaining
		return total - spent, total, spent, true
	end
	return total, total, 0, true
end
```

- [ ] `GetPetKnownRanks`: when the trainer is open, use its `"used"` rows (Task 4's `GetKnownTrainerRanks`); otherwise keep the pet-spellbook scan, and add matching on `rankInfo.spellId` which now exists for every rank.
- [ ] UI: when `isCached` is true, show the TP number in grey with a tooltip "Last seen at the pet trainer".

**Check in game:** with the pet tab opened once, the bar shows Dependable and level 10; after visiting the trainer and leaving, TP still reads 14 (greyed); dismiss and summon a different pet, the bar changes.

---

## Task 4 — Read the pet trainer (replaces `Craft.lua`)

**Status (October 1):** built, awaiting in-game test. `Trainer.lua` reads entries (cached until the next `TRAINER_*` event), merges `"used"` rows into known ranks, and shows `SetTrainerService` tooltips. Filters are **not** changed automatically until 0.1c is answered; the window asks you to tick them instead, and "not known" marks are skipped while any filter is off. Added `Dev.lua` (`/hpt dev`): Trainer, Pet, Taint and Filter-test reports plus an event log, written to a copyable text box that survives `/reload`. `ADDON_ACTION_FORBIDDEN/BLOCKED` and "learned" system messages are always logged there. It covers Phase 0.1c, 0.3, 0.5 and 0.6 and the owl family check.

**Files**
- Create: `Trainer.lua` (replaces `Craft.lua` in the `.toc`).
- Delete: `Craft.lua`.
- Modify: `Core.lua` events (`CRAFT_*` → `TRAINER_SHOW`, `TRAINER_UPDATE`, `TRAINER_CLOSED`, adjusted by Phase 0.5), `Apply.lua`, `UI.lua` callers listed below.

**Interfaces produced** (same entry shape as TBC `GetCraftEntries`, so `Apply.lua` and `UI.lua` need only renames):

```lua
-- entry = { index, name, ability, sub, rank, status, cost, reqLevel, spellId }
HPT:IsBeastTrainingOpen()            -> boolean
HPT:GetTrainerEntries()              -> { entry, ... }
HPT:GetKnownTrainerRanks()           -> { [ability] = highestUsedRank }
HPT:FindTrainerEntry(ability, rank, exactOnly) -> entry|nil
HPT:FindBestTrainerEntry(ability, desiredRank, petRanks) -> entry|nil, reason
HPT:GetTrainerPointsRemaining()      -> number|nil
```

**Steps**
- [ ] Core readers:

```lua
function HPT:IsBeastTrainingOpen()
	local f = _G.ClassTrainerFrame
	local label = _G.ClassTrainerFrameTrainingPointsLabel
	return f and f:IsShown() and label and label:IsShown() or false
end

function HPT:GetTrainerPointsRemaining()
	if not self:IsBeastTrainingOpen() then
		return nil
	end
	local text = ClassTrainerFrameTrainingPointsLabel:GetText()
	return text and tonumber(text:match("(%d+)%s*$"))
end

local function SpellIdForService(i)
	local tip = HPT:EnsureScanTooltip()
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:SetTrainerService(i)
	local _, spellId = tip:GetSpell()
	tip:Hide()
	return spellId
end

function HPT:GetTrainerEntries()
	local list = {}
	if not self:IsBeastTrainingOpen() then
		return list
	end
	for i = 1, GetNumTrainerServices() do
		local name, status, _, reqLevel, rankText = GetTrainerServiceInfo(i)
		if name and status ~= "header" then
			table.insert(list, {
				index = i,
				name = name,
				ability = name,
				sub = rankText or "",
				rank = tonumber((rankText or ""):match("(%d+)")) or 1,
				status = status,
				cost = GetTrainerServiceCost(i) or 0,
				reqLevel = GetTrainerServiceLevelReq(i) or reqLevel or 0,
				spellId = SpellIdForService(i),
			})
		end
	end
	return list
end
```

  (Make `EnsureScanTooltip` in `Core.lua` a method `HPT:EnsureScanTooltip()` so both files share it.)
- [ ] The trainer's filters hide rows. On `TRAINER_SHOW`, save the current `GetTrainerServiceTypeFilter("used"/"available"/"unavailable")`, set all three to on with `SetTrainerServiceTypeFilter`, and restore them on `TRAINER_CLOSED`.
- [ ] Port `FindCraftEntryForAbility` → `FindTrainerEntry` and `FindBestCraftForAbility` → `FindBestTrainerEntry`. In Forever "already known" comes from `status == "used"`, so the TBC "hunter knows rank X" logic (`GetKnownCraftRankSet`) is replaced by `status`.
- [ ] On each `TRAINER_SHOW` / `TRAINER_UPDATE`, call `HPT:RecordTrainerPoints(self:GetTrainerPointsRemaining())`.
- [ ] Rename callers: `UI.lua:1222, 1374`, `Core.lua:228`, `Apply.lua:120, 134` and anything else `rg "Craft"` finds outside `CraftOverlay.lua`.
- [ ] Tooltips: `ShowAbilityTooltip` uses `GameTooltip:SetTrainerService(entry.index)` when the trainer is open, else `GameTooltip:SetSpellByID(D:GetRankSpellId(ability, rank))`, else the static text.

**Check in game:** at the pet trainer, `/run for _,e in ipairs(HunterPetTrainer:GetTrainerEntries()) do print(e.index,e.ability,e.rank,e.status,e.cost,e.reqLevel,e.spellId) end` matches the trainer window row for row; Loxley's planner shows Bite 2, Claw 2, Cower 1, Growl 2 as trained; hovering an untrained rank shows the right tooltip.

---

## Task 5 — Trainer overlay (replaces the craft-window parts of `CraftOverlay.lua`)

**Status (October 1):** built, awaiting in-game test. `CraftOverlay.lua` is replaced by `TrainerOverlay.lua`: a separate dock frame anchored to the right of `ClassTrainerFrame` (anchor only; no Blizzard frame is moved, reparented, resized or re-scripted). It hosts the embedded planner and a footer with "Next: …" and a hint. It shows on Beast Training only, hides on close or at NPC trainers, and its close button, Escape or `/hpt` dismiss it until the next open. The Train proxy and every craft skinning helper are gone. First test: closing Beast Training left the dock up, so `TRAINER_CLOSED` apparently doesn't fire for the spell window. The dock is now a child of `ClassTrainerFrame` and cleans up in its own `OnHide` (stop apply, restore planner, restore filters).

**Files**
- Rename: `CraftOverlay.lua` → `TrainerOverlay.lua`.

**Steps**
- [ ] Re-anchor the embedded planner next to `ClassTrainerFrame` instead of `CraftFrame`. Remove the ProfessionPlus and craft-skinning code (`SkinCraftFrameForPet`, `HideCraftSkillButtons`, `HideProfessionPlusOnCraft`, `EnsureCraftCover`), which targeted TBC craft frames.
- [ ] Remove the Train proxy (`EnsureTrainProxy`, `CaptureCraftTrainButton`, `RestoreCraftTrainButton`, `PinTrainButtonNow`). Blizzard's `ClassTrainerTrainButton` stays as is; the addon must not move, disable or re-script it, since that risks taint.
- [ ] Keep the `UpdateTrainButtonState` rules (only Current Pet, only with a pet out) for the addon's guidance glow, not for Blizzard's button.
- [ ] Check the overlay against the EllesmereUI skin as well as plain Blizzard UI, since the user plays with EllesmereUI.

**Check in game:** opening the pet trainer shows the planner beside it; closing hides it; hunter class trainer does not show it (Phase 0.3).

---

## Task 6 — Assisted training (depends on Phase 0.1b)

The addon must **never** call `ClassTrainer_SetSelection`, `SelectTrainerService` or `BuyTrainerService`; any of them taints the trainer and blocks training.

**Status (October 1):** built, awaiting in-game test. `TrainNext.lua` adds the two-press secure button to the dock footer and a pulsing gold box over the planned row. Every 0.25 s it takes the first `BuildApplyPlan` step and re-finds the row by name and rank text. If the row is off screen, the button reads "Scroll to …" and stays disabled; the addon doesn't scroll the list, since writing to Blizzard's ScrollBox could taint the selection. After a Select press it checks `GetTrainerSelectionIndex()` 0.3 s later before switching to Train. If Train is disabled the button shows "Train unavailable". A "learned" system message resets the queue to the next step. Dock show/hide is skipped in combat (protected child).

**Files**
- Modify: `Apply.lua` — `SelectTrainTarget`, `GetSpent`, `OnApplyEvent`.

**Steps**
- [ ] `SelectTrainTarget(entry)` scrolls the trainer list to the next planned row and draws a glow over it, without touching Blizzard's selection.
- [ ] **"Train next" button, pressed twice** (proven October 1 with `HPT_ClickTest` button 3, trained Growl 2). One `SecureActionButtonTemplate` button with `type = "click"`:
  - Select mode: `clickbutton` = the planned row (found by scanning `ClassTrainerFrame.ScrollBox.ScrollTarget`), label "Select <ability> <rank>".
  - After a press in Select mode, `PostClick` waits 0.3 s, then checks `GetTrainerSelectionIndex()` and that row's name and rank against the plan. Only if they match does it switch `clickbutton` to `ClassTrainerTrainButton`, label "Train <ability> <rank>". Otherwise it shows a red warning and stays on Select.
  - After a press in Train mode, it switches back to Select and moves to the next planned step on `TRAINER_UPDATE`.
  - Register only one click half: `RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")`. Registering both runs the action and `PostClick` twice per press.
  - Every attribute change happens out of combat (`InCombatLockdown()` check), and on `TRAINER_UPDATE` and hover the target is re-found, because ScrollBox row frames are recycled.
- [ ] Glow the planned row as well, so you can see what the button will select.
- [ ] `GetSpent`: use `self:GetPetPoints()` instead of `GetPetTrainingPoints()`.
- [ ] Detect success from the chat message "Your pet has learned a new spell: X (Rank N)" or the row changing to "Already known" on `TRAINER_UPDATE`, then move the glow to the next planned step.

**Check in game:** plan Natural Armor 1 → Great Stamina 1 on Loxley; Assist Train selects Natural Armor 1; one Train click trains it (TP 14 → 13) and the addon moves on to Great Stamina 1.

---

## Task 7 — Docs, version and launch prep

- [ ] Rewrite `README.md` for Forever: supported client, what's different from the TBC version, which abilities are info-only, and that TP shown away from the trainer is the last-seen value.
- [ ] Bump to `0.2.0`, commit, push.
- [ ] Before November 4: confirm the live client's folder name (likely not `_classic_beta_`) and copy `Hunter_Pet_Trainer_Forever` there. Re-run `Build-ForeverData.ps1` against launch data and re-check Interface number.

---

## Risks to watch

1. **Loyalty reads empty until the pet tab has been opened** (Phase 0.6). Fallback: show "—" and a hint to open the pet tab once.
2. **Pet trainer vs hunter class trainer confusion** — the planner must not appear, or train, at the class trainer.
3. **Trainer filters hiding rows** — planner thinks an ability isn't available because a filter is off.
4. **Data drift during the beta** — Wowhead and Petopia change; the trainer's live values always override static data.
5. **EllesmereUI reskinning the trainer** — button names or layout differ; test both with and without it.

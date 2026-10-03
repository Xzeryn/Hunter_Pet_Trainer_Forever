<#
.SYNOPSIS
  Regenerates Data.lua and SpellIds.lua for Hunter Pet Trainer Forever.

.DESCRIPTION
  Wowhead (forever) supplies ranks, required pet levels and spell IDs.
  Petopia (forever) supplies TP costs, families, icons and training source.
  Values confirmed at the in-game pet trainer are asserted at the end; the
  script fails instead of writing data that contradicts the trainer.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Build-ForeverData.ps1
#>
[CmdletBinding()]
param(
	[string]$OutDir
)

$ErrorActionPreference = "Stop"
if (-not $OutDir) { $OutDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ((Split-Path -Leaf $OutDir) -eq "tools") { $OutDir = Split-Path -Parent $OutDir }

$WowheadUrl = "https://www.wowhead.com/forever/spells/pet-abilities/hunter"
$PetopiaUrl = "https://www.wow-petopia.com/forever/abilities.php"

# Not trainable: per-species attack speed effects and internal spells.
$SkipAbilities = @(
	"Faster Attack", "Slower Attack", "Tamed Pet Passive (DND)", "Hunter Pet Scaling", "Summoning"
)

$PassiveAbilities = @(
	"Great Stamina", "Natural Armor",
	"Arcane Resistance", "Fire Resistance", "Frost Resistance", "Nature Resistance", "Shadow Resistance"
)

# Abilities Petopia doesn't list yet.
$FamilyOverrides = @{
	"Mine!" = @("Bird of Prey")
	"Sonic Blast" = @("Bat")  # Wowhead-only; Forever notes and beastmaster.io say Bat
}

$FamilyNames = @{
	"All Families"  = "ALL"
	"Bats"          = "Bat"
	"Bears"         = "Bear"
	"Birds of Prey" = "Bird of Prey"
	"Boars"         = "Boar"
	"Carrion Birds" = "Carrion Bird"
	"Cats"          = "Cat"
	"Core Hounds"   = "Core Hound"
	"Crabs"         = "Crab"
	"Crocolisks"    = "Crocolisk"
	"Foxes"         = "Fox"
	"Gorillas"      = "Gorilla"
	"Hyenas"        = "Hyena"
	"Raptors"       = "Raptor"
	"Scorpids"      = "Scorpid"
	"Spiders"       = "Spider"
	"Tallstriders"  = "Tallstrider"
	"Turtles"       = "Turtle"
	"Wind Serpents" = "Wind Serpent"
	"Wolves"        = "Wolf"
}

$PreferredOrder = @(
	"Growl", "Cower", "Bite", "Claw", "Charge", "Dash", "Dive", "Prowl",
	"Furious Howl", "Demoralizing Screech", "Scorpid Poison", "Lightning Breath",
	"Thunderstomp", "Shell Shield",
	"Dismember", "Dust Cloud", "Lava Breath", "Mine!", "Pinch", "Savage Rend",
	"Sonic Blast", "Swipe", "Tendon Rip", "Trickster's Dance", "Web",
	"Great Stamina", "Natural Armor",
	"Arcane Resistance", "Fire Resistance", "Frost Resistance", "Nature Resistance", "Shadow Resistance"
)

# Confirmed at the Forever beta pet trainer on 2026-10-01: ability, rank, level, cost, spellId (0 = not checked).
$TrainerChecks = @(
	@("Natural Armor", 1, 1, 1, 24545),
	@("Natural Armor", 2, 12, 5, 0),
	@("Great Stamina", 1, 1, 5, 0),
	@("Great Stamina", 2, 12, 10, 0),
	@("Cower", 1, 5, 8, 0),
	@("Bite", 2, 8, 4, 0),
	@("Claw", 2, 8, 4, 0),
	@("Growl", 1, 1, 0, 0),
	@("Growl", 2, 10, 0, 0)
)

$Warnings = New-Object System.Collections.Generic.List[string]
function Warn([string]$msg) { $Warnings.Add($msg); Write-Warning $msg }

function Get-Page([string]$url) {
	Write-Host "Downloading $url"
	return (Invoke-WebRequest -UseBasicParsing -Uri $url -UserAgent "Mozilla/5.0").Content
}

function Get-Ability($table, [string]$name) {
	if (-not $table.ContainsKey($name)) {
		$table[$name] = @{ name = $name; ranks = @{}; families = $null; icon = $null; sources = @{} }
	}
	return $table[$name]
}

function Get-Rank($ability, [int]$rank) {
	if (-not $ability.ranks.ContainsKey($rank)) {
		$ability.ranks[$rank] = @{ level = $null; cost = $null; spellId = $null; wowheadLevel = $null; petopiaLevel = $null }
	}
	return $ability.ranks[$rank]
}

$abilities = @{}

# --- Wowhead: ranks, levels, spell IDs ---------------------------------------
$wowhead = Get-Page $WowheadUrl
$whMatches = [regex]::Matches($wowhead, '"id":(\d+),"level":(\d+),"name":"([^"]+)"[^}]*?"rank":"Rank (\d+)"')
if ($whMatches.Count -lt 100) {
	throw "Wowhead returned only $($whMatches.Count) ranked spells; the page format may have changed."
}
foreach ($m in $whMatches) {
	$name = $m.Groups[3].Value
	if ($SkipAbilities -contains $name) { continue }
	$a = Get-Ability $abilities $name
	$r = Get-Rank $a ([int]$m.Groups[4].Value)
	$r.spellId = [int]$m.Groups[1].Value
	$r.wowheadLevel = [int]$m.Groups[2].Value
	$a.sources["wowhead"] = $true
}
Write-Host ("Wowhead: {0} ranked spells" -f $whMatches.Count)

$wowheadIcons = @{}
foreach ($m in [regex]::Matches($wowhead, '"(\d+)":\{"name_enus":"[^"]*","icon":"([^"]+)"')) {
	$wowheadIcons[[int]$m.Groups[1].Value] = $m.Groups[2].Value
}

# --- Petopia: costs, families, icons, source ---------------------------------
$petopia = Get-Page $PetopiaUrl
$sections = [regex]::Matches($petopia, "<h3 class='guide_heading classic forever' id='[a-z]+'>(?:<img[^>]*src='([^']*)'[^>]*>)?([^<]+)</h3>([\s\S]*?)(?=<h3 class='guide_heading|$)")
if ($sections.Count -lt 25) {
	throw "Petopia returned only $($sections.Count) ability sections; the page format may have changed."
}
foreach ($s in $sections) {
	$name = [System.Net.WebUtility]::HtmlDecode($s.Groups[2].Value.Trim())
	if ($SkipAbilities -contains $name) { continue }
	$a = Get-Ability $abilities $name
	$a.sources["petopia"] = $true
	$iconPath = $s.Groups[1].Value
	if ($iconPath) {
		$a.icon = [System.IO.Path]::GetFileNameWithoutExtension($iconPath)
	}
	$body = $s.Groups[3].Value
	$famText = [regex]::Match($body, "ability_family_list classic forever'>([\s\S]*?)</span></p>").Groups[1].Value -replace '<[^>]+>', ''
	$fams = @()
	foreach ($f in ($famText -split ',')) {
		$f = $f.Trim()
		if (-not $f) { continue }
		if ($FamilyNames.ContainsKey($f)) { $fams += $FamilyNames[$f] } else { Warn "Unknown Petopia family '$f' on $name"; $fams += $f }
	}
	$a.families = $fams
	$rankMatches = [regex]::Matches($body, "abilityrankname classic forever'>[^<]*?(\d+)</span>: Pet Level (\d+), Cost (\d+) TP\.[\s\S]*?abilitysourceheading classic forever'>([^<]*)")
	$a.petopiaSources = @()
	foreach ($rm in $rankMatches) {
		$r = Get-Rank $a ([int]$rm.Groups[1].Value)
		$r.petopiaLevel = [int]$rm.Groups[2].Value
		$r.cost = [int]$rm.Groups[3].Value
		$a.petopiaSources += $rm.Groups[4].Value.Trim()
	}
}
Write-Host ("Petopia: {0} ability sections" -f $sections.Count)

# --- Merge --------------------------------------------------------------------
foreach ($a in $abilities.Values) {
	$name = $a.name
	if (-not $a.sources["petopia"]) { Warn "$name is on Wowhead only (no TP cost; treated as info-only)" }
	if (-not $a.sources["wowhead"]) { Warn "$name is on Petopia only (no spell IDs)" }
	if ($FamilyOverrides.ContainsKey($name)) { $a.families = $FamilyOverrides[$name] }
	if (-not $a.families) { Warn "$name has no family list; defaulting to ALL"; $a.families = @("ALL") }
	if (-not $a.icon) {
		foreach ($r in $a.ranks.Values) {
			if ($r.spellId -and $wowheadIcons.ContainsKey($r.spellId)) { $a.icon = $wowheadIcons[$r.spellId]; break }
		}
	}

	foreach ($rank in @($a.ranks.Keys)) {
		$r = $a.ranks[$rank]
		if ($null -ne $r.wowheadLevel) { $r.level = $r.wowheadLevel } else { $r.level = $r.petopiaLevel }
		if ($null -ne $r.wowheadLevel -and $null -ne $r.petopiaLevel -and $r.wowheadLevel -ne $r.petopiaLevel) {
			Warn ("{0} {1}: Wowhead level {2}, Petopia level {3}; using Wowhead" -f $name, $rank, $r.wowheadLevel, $r.petopiaLevel)
		}
		if ($null -eq $r.cost) {
			if ($a.sources["petopia"]) { Warn "$name $rank has no Petopia cost; using 0" }
			$r.cost = 0
		}
	}

	$srcText = ($a.petopiaSources | Sort-Object -Unique) -join ' | '
	$allFree = -not ($a.ranks.Values | Where-Object { $_.cost -gt 0 })
	if ($srcText -match 'trainers') {
		$a.source = "trainer"
	} elseif ($srcText -match 'taming') {
		$a.source = "wild"
	} elseif ($allFree) {
		$a.source = "innate"
	} else {
		$a.source = "wild"
	}
	$a.active = -not ($PassiveAbilities -contains $name)
}

# --- Assert trainer-confirmed values -----------------------------------------
$failures = @()
foreach ($c in $TrainerChecks) {
	$name, $rank, $level, $cost, $spellId = $c
	if (-not $abilities.ContainsKey($name) -or -not $abilities[$name].ranks.ContainsKey($rank)) {
		$failures += "$name $rank missing"
		continue
	}
	$r = $abilities[$name].ranks[$rank]
	if ($r.level -ne $level) { $failures += "$name $rank level $($r.level), trainer says $level" }
	if ($r.cost -ne $cost) { $failures += "$name $rank cost $($r.cost), trainer says $cost" }
	if ($spellId -and $r.spellId -ne $spellId) { $failures += "$name $rank spellId $($r.spellId), trainer says $spellId" }
}
if ($failures.Count -gt 0) {
	throw ("Data contradicts the in-game trainer:`n  " + ($failures -join "`n  "))
}

# --- Order --------------------------------------------------------------------
$order = New-Object System.Collections.Generic.List[string]
foreach ($n in $PreferredOrder) { if ($abilities.ContainsKey($n)) { $order.Add($n) } }
foreach ($n in ($abilities.Keys | Sort-Object)) {
	if (-not $order.Contains($n)) { Warn "$n is not in the preferred order; appended"; $order.Add($n) }
}

# --- Families -----------------------------------------------------------------
$families = @{}
foreach ($n in $order) {
	foreach ($f in $abilities[$n].families) {
		if ($f -eq "ALL") { continue }
		if (-not $families.ContainsKey($f)) { $families[$f] = New-Object System.Collections.Generic.List[string] }
		$families[$f].Add($n)
	}
}

# --- Write Lua ----------------------------------------------------------------
function LuaStr([string]$s) { return '"' + $s.Replace('\', '\\').Replace('"', '\"') + '"' }

$stamp = (Get-Date).ToString("yyyy-MM-dd")
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- Generated by tools/Build-ForeverData.ps1 on $stamp. Do not edit by hand.")
[void]$sb.AppendLine("-- Ranks, levels and spell IDs: Wowhead (forever). TP costs, families, icons: Petopia (forever).")
[void]$sb.AppendLine("HunterPetTrainerData = HunterPetTrainerData or {}")
[void]$sb.AppendLine("local D = HunterPetTrainerData")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("D.MAX_ACTIVE = 4")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("-- source: ""trainer"" | ""wild"" (learned by taming, then trained) | ""innate"" (learned with level; info only)")
[void]$sb.AppendLine("D.Abilities = {")
foreach ($n in ($order | Sort-Object)) {
	$a = $abilities[$n]
	$fams = ($a.families | ForEach-Object { LuaStr $_ }) -join ", "
	[void]$sb.AppendLine("  [$(LuaStr $n)] = {")
	[void]$sb.AppendLine("    active = $($a.active.ToString().ToLower()),")
	[void]$sb.AppendLine("    source = $(LuaStr $a.source),")
	[void]$sb.AppendLine("    families = { $fams },")
	[void]$sb.AppendLine("    ranks = {")
	foreach ($rank in ($a.ranks.Keys | Sort-Object)) {
		$r = $a.ranks[$rank]
		$sid = ""
		if ($r.spellId) { $sid = ", spellId = $($r.spellId)" }
		[void]$sb.AppendLine("      [$rank] = { level = $($r.level), cost = $($r.cost)$sid },")
	}
	[void]$sb.AppendLine("    },")
	[void]$sb.AppendLine("  },")
}
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("D.Families = {")
foreach ($f in ($families.Keys | Sort-Object)) {
	$list = ($families[$f] | ForEach-Object { LuaStr $_ }) -join ", "
	[void]$sb.AppendLine("  [$(LuaStr $f)] = { $list },")
}
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("D.CommonAbilities = {")
foreach ($n in $order) { if ($abilities[$n].families -contains "ALL") { [void]$sb.AppendLine("  $(LuaStr $n),") } }
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("D.AbilityOrder = {")
foreach ($n in $order) { [void]$sb.AppendLine("  $(LuaStr $n),") }
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("D.AbilityIcons = {")
foreach ($n in $order) {
	$icon = $abilities[$n].icon
	if ($icon) { [void]$sb.AppendLine("  [$(LuaStr $n)] = $(LuaStr ("Interface\Icons\" + $icon)),") }
	else { Warn "$n has no icon" }
}
[void]$sb.AppendLine("}")

$ids = New-Object System.Text.StringBuilder
[void]$ids.AppendLine("-- Generated by tools/Build-ForeverData.ps1 on $stamp. Do not edit by hand.")
[void]$ids.AppendLine("-- Forever pet ability rank -> spell ID (for tooltips of unlearned ranks). Source: Wowhead (forever).")
[void]$ids.AppendLine("HunterPetTrainerData = HunterPetTrainerData or {}")
[void]$ids.AppendLine("local D = HunterPetTrainerData")
[void]$ids.AppendLine("")
[void]$ids.AppendLine("D.RankSpellIds = {")
foreach ($n in $order) {
	$a = $abilities[$n]
	$pairs = @()
	foreach ($rank in ($a.ranks.Keys | Sort-Object)) {
		if ($a.ranks[$rank].spellId) { $pairs += "[$rank] = $($a.ranks[$rank].spellId)" }
	}
	if ($pairs.Count -gt 0) { [void]$ids.AppendLine("  [$(LuaStr $n)] = { $($pairs -join ', ') },") }
}
[void]$ids.AppendLine("}")
[void]$ids.AppendLine("")
[void]$ids.AppendLine("function D:GetRankSpellId(abilityName, rank)")
[void]$ids.AppendLine("  local byAbility = self.RankSpellIds and self.RankSpellIds[abilityName]")
[void]$ids.AppendLine("  if not byAbility then")
[void]$ids.AppendLine("    return nil")
[void]$ids.AppendLine("  end")
[void]$ids.AppendLine("  return byAbility[rank]")
[void]$ids.AppendLine("end")

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $OutDir "Data.lua"), $sb.ToString(), $utf8)
[System.IO.File]::WriteAllText((Join-Path $OutDir "SpellIds.lua"), $ids.ToString(), $utf8)

Write-Host ""
Write-Host ("Wrote {0} abilities, {1} families to {2}" -f $order.Count, $families.Count, $OutDir)
$bySource = $abilities.Values | Group-Object { $_.source } | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ("Sources: " + ($bySource -join ", "))
if ($Warnings.Count -gt 0) {
	Write-Host ""
	Write-Host "$($Warnings.Count) warning(s):"
	$Warnings | ForEach-Object { Write-Host "  - $_" }
}

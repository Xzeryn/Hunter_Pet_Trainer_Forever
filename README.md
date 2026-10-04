<img src="media/logo.png" alt="Hunter Pet Trainer Forever" width="128" align="right">

# Hunter Pet Trainer Forever

Plan hunter pet training and train it step by step in **World of Warcraft: Forever** (Classic Era based, level cap 60, interface `16001`).

Ported from Hunter Pet Trainer v0.5.9 for TBC Anniversary. The planner and templates are the same; everything that talks to the game is new, because Forever moved Beast Training into the trainer window and removed the pet loyalty and training point functions.

## Features

- **Current Pet plan**: tied to your summoned pet. Known ranks come from the pet spellbook and the Beast Training list.
- **Saved templates**: plan builds per family with level, loyalty and a TP budget.
- **Ability grid**: Active, Passive, info-only and not-for-this-family rows with TP costs; trained and planned ranks are colored.
- **Docked planner**: opens beside the Beast Training window and closes with it.
- **Train next button**: two presses per rank. The first selects the planned row in Blizzard's list, the second clicks Train. The planned row is highlighted.
- **Live training points and loyalty**, read from the Beast Training window and the Pet tab, remembered per pet.
- **Minimap button**: left-click for the planner, right-click for data reports, drag to move.
- **EllesmereUI theme** when EllesmereUI is installed (toggle under Blizz UI Enhanced > Blizzard Window Skins > Third-Party Addons).

## Install

1. Copy the `Hunter_Pet_Trainer_Forever` folder into your Forever client's `Interface\AddOns` folder.
2. Restart the game.
3. Open the Pet tab of the Character window once, so the addon can read your pet's loyalty.
4. Cast **Beast Training**, or type `/hpt`.

## How to use

### Train your current pet

1. Summon your pet and cast Beast Training. The planner docks on the right.
2. Pick **Current Pet** in the Template dropdown.
3. Click ranks to plan them (green = planned, blue = already trained).
4. Press **Train next** twice per rank: once to select it, once to train it. The footer shows what's next.

If a planned rank is off screen, Train next hides used and unavailable rows so it can reach it. If the button still reads "Scroll to …", scroll the Beast Training list to that rank. Your filter choices come back when Beast Training closes.

### Plan with templates

1. **··· → New template…**, pick a family and name it.
2. Set level, loyalty and ranks.
3. **··· → Apply to Current Pet…**, then train from Current Pet.

### Colors

| Color | Meaning |
|-------|---------|
| Blue cell | Pet already has this rank |
| Green cell | Planned |
| Red TP text | The trainer doesn't list this rank (`*Ability not known`); checked only while Beast Training is open |
| Grey row | Not used by this pet family |

## Differences from the TBC version

- **Training needs your clicks.** Forever blocks addons from choosing a trainer row or pressing Train. The Train next button works because it is a secure click of Blizzard's own row and Train button.
- **Beast Training stays visible.** The planner docks beside it instead of replacing it, since the button has to click Blizzard's rows.
- **Training points away from the trainer are the last value seen there.** The number turns grey; hover it for details. Max TP = pet level × (loyalty level − 1).
- **Beast Training charges the upgrade cost.** With rank 1 known, rank 2 costs the difference (Great Stamina 2 = 10 − 5 = 5 TP).
- **No Wowhead import yet.** Wowhead has no Forever pet calculator.

## Info-only abilities

These family abilities have no trainer and no TP cost on Petopia, and seem to be learned with pet level. They're listed under "Unconfirmed: source unknown (info only)" with the pet level for each rank and can't be planned until the game shows how they're learned:

Dismember, Web, Pinch, Swipe, Savage Rend, Tendon Rip, Dust Cloud, Mine!, Lava Breath, Sonic Blast, Trickster's Dance.

Faster Attack and Slower Attack are per-species traits, not trainable ranks, and aren't shown.

## Slash commands

| Command | Action |
|---------|--------|
| `/hpt` | Toggle the planner (or the dock while Beast Training is open) |
| `/hpt apply` | Start the assist queue for Current Pet |
| `/hpt stop` | Cancel it |
| `/hpt new <name> [family]` | New blank template |
| `/hpt save <name>` | Save the active plan as a template |
| `/hpt load <name>` | Load Current Pet or a template |
| `/hpt delete <name>` | Delete a template |
| `/hpt apply <name>` | Copy a template onto Current Pet |
| `/hpt templates` | List templates |
| `/hpt report` | Build a GitHub issue link with new game data |
| `/hpt report all` | Same, including entries already sent |
| `/hpt report test` | Report every Beast Training row (for testing; nothing is saved) |
| `/hpt report clear` | Forget all saved report data and sent marks |
| `/hpt minimap` | Hide or show the minimap button |
| `/hpt dev` | Developer window with copyable reports |
| `/hpt debug` | Toggle diagnostic chat messages |
| `/hpt help` | Full command list |

## Reporting game data

Whenever Beast Training is open with your pet out, the addon quietly saves anything that differs from its data:

- trainer rows with a different level, cost or spell ID;
- abilities, ranks or families the data doesn't have;
- pet spells that aren't in the data;
- training point totals that don't match the formula.

Tooltip text and icon IDs are saved with each entry.

To send it: type `/hpt report` (or **Report** in `/hpt dev`), click **Copy link**, paste it into your browser and submit the GitHub issue it opens. The text below the link is exactly what the issue will contain. Reports are sent as readable text; one too long for a single link is compressed instead (`tools\Read-Reports.ps1` decodes it), and only if it still doesn't fit is it split into parts (the **Part** button switches links).

Copy link marks those entries as sent, so later reports leave them out unless the game shows different values. `/hpt report all` includes sent entries again. Once the addon's data is updated, entries that now match drop out on their own.

`/hpt dev` also has manual reports you can select and copy (the log survives `/reload`):

- **Trainer**: every Beast Training row with rank, status, cost, level, spell ID and icon, checked against the addon's data.
- **Tooltips**: the full tooltip text of every Beast Training row.
- **Pet**: family name, level, loyalty, training points and the pet spellbook with spell IDs and icons.

With `/hpt debug` on, the window also shows **Taint**, **Filter test** and **Events** for diagnosing blocked actions. Blocked actions and "your pet has learned" messages are always logged.

## Rebuilding ability data

`tools\Build-ForeverData.ps1` downloads Wowhead and Petopia Forever data and writes `Data.lua` and `SpellIds.lua`:

```
powershell -ExecutionPolicy Bypass -File tools\Build-ForeverData.ps1
```

The trainer's live values always override this data in game.

## Version

See `Hunter_Pet_Trainer_Forever.toc` (`## Version`).

## License

MIT; see [LICENSE](LICENSE). Ability data is compiled from [Wowhead](https://www.wowhead.com/) and [Petopia](https://www.wow-petopia.com/), and corrected from in-game reports.

## Releasing

Two ways to ship a CurseForge zip that contains only the files the game needs (see `.pkgmeta`):

**Manual.** `powershell -ExecutionPolicy Bypass -File tools\Build-Release.ps1` writes `dist\Hunter_Pet_Trainer_Forever-<version>.zip`. Upload that file on the CurseForge project.

**From GitHub.** After the project exists and `## X-Curse-Project-ID` is in the `.toc`, a `v*` tag (for example `v0.2.0`) runs `.github/workflows/release.yml`. That uses [BigWigs packager](https://github.com/BigWigsMods/packager) to build from `.pkgmeta` and upload to CurseForge plus a GitHub release. The repository secret `CF_API_KEY` is a [CurseForge API token](https://wow.curseforge.com/account/api-tokens). Tags with `beta` or `alpha` in the name go to those CurseForge channels.

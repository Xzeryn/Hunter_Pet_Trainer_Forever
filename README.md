# Hunter Pet Trainer Forever

> **Work in progress.** Port of Hunter Pet Trainer v0.5.9 (TBC Anniversary) to **WoW Forever** (interface `16001`). The text below still describes the TBC addon until the port is finished; see [`docs/plans/2026-10-01-forever-port.md`](docs/plans/2026-10-01-forever-port.md).

Plan pet ability training and assist Beast Training on **World of Warcraft TBC Anniversary** (interface `20506` / patch 2.5.6).

Because `DoCraft()` is protected on this client (`ADDON_ACTION_FORBIDDEN`), the addon cannot auto-train. Instead it selects the next planned skill in the Blizzard Beast Training UI; you click **Train**.

## Features

- **Current Pet** — live training plan tied to your summoned pet (only place Assist Train runs)
- **Saved templates** — theory-craft builds per family (level / loyalty / TP budget)
- **Ability grid** — Active / Passive / unused-for-family rows with TP costs, trained vs planned colors
- **Beast Training overlay** — restyles CraftFrame for pet training; leaves Enchanting alone
- **Wowhead import** — paste a [Hunter Pet Training](https://www.wowhead.com/tbc/hunter-pet-training) share link into a new template
- Family-accurate ability lists (synced to Wowhead TBC data)

## Install

1. Copy this folder to:
   `World of Warcraft\_anniversary_\Interface\AddOns\Hunter_Pet_Trainer`
2. Restart the client or `/reload`
3. Open **Beast Training** from your spellbook, or use `/hpt`

## How to use

### Current Pet (train)

1. Summon your pet and open Beast Training
2. Select **Current Pet** in the template dropdown
3. Click ranks to plan upgrades (green = planned, blue = already trained)
4. Click Blizzard **Train** for each selected skill; HPT advances to the next

### Theory templates

1. **··· → New template…** → pick a family → name it  
   or **Import Wowhead link…**
2. Adjust level / loyalty steppers and ability ranks
3. When ready: **Apply to Current Pet…**, then train from Current Pet

### Color legend

| Color | Meaning |
|-------|---------|
| Blue cell | Pet already has this rank |
| Green cell | Planned on the template |
| Red TP text | Hunter has not learned that craft rank yet (`*Ability not known`) |
| Grey row | Not used by this pet family |

## Slash commands

| Command | Action |
|---------|--------|
| `/hpt` | Toggle standalone planner |
| `/hpt apply` | Start assisted train (Current Pet) |
| `/hpt stop` | Cancel assist |
| `/hpt new <name> [family]` | Blank theory template |
| `/hpt save <name>` | Save As |
| `/hpt load <name>` | Load Current Pet or a template |
| `/hpt delete <name>` | Delete a saved template |
| `/hpt apply <name>` | Copy a saved template onto Current Pet |
| `/hpt wowhead <link>` | Import Wowhead share link |
| `/hpt templates` | List saved templates |
| `/hpt debug` | Toggle diagnostic chat messages |
| `/hpt help` | Full command list |

## Notes

- Assist Train **only** runs on **Current Pet** with a pet summoned and Beast Training open
- Swapping pets (stable or abandon/tame) resets Current Pet to that animal’s trained ranks, even within the same family (tracked as `Name|Family`; dismiss / flying does not reset)
- Cumulative TP costs use each rank’s listed total; upgrades cost the difference between ranks
- ProfessionPlus / other craft UI addons: HPT hides conflicting enchant chrome while Beast Training is open
- Optional: use [Tamed](https://www.curseforge.com/wow/addons/tamed) separately for tame sources — HPT does not modify or depend on it

## Version

See `Hunter_Pet_Trainer.toc` (`## Version`).

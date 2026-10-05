# Changelog

All notable changes to Hunter Pet Trainer Forever are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Add user-facing notes under **[Unreleased]** in the same change as the code.
When tagging a version, move those notes into a dated `## [x.y.z]` section first.
The CurseForge and GitHub release changelog is that section only.

## [Unreleased]

### Changed

- Train next always hides already known and unavailable Beast Training ranks before it looks for the planned row

### Fixed

- Remaining training points no longer jump above the pet's max after a loyalty gain

## [0.2.5] - 2026-10-05

### Changed

- Loyalty and remaining training points are read while the pet is summoned; opening the Character Pet tab is no longer required

## [0.2.4] - 2026-10-05

### Changed

- Web is learned by taming a Spider that knows it, then trained at Beast Training
- `/hpt report` includes family coverage (data vs spellbook vs Beast Training) and recent learned messages from tames and training

### Fixed

- The report log only records blocked actions from this addon, not other addons such as action-bar skins
- Used and unavailable Beast Training filters stay as you set them until you press Train next
- Minimap right-click opens the data snapshot, not the empty developer window

## [0.2.3] - 2026-10-05

### Changed

- Swipe is learned by taming a Bear that knows it, then trained at Beast Training (Rank 1 is 0 TP)
- `/hpt report` is one snapshot (pet + Beast Training) with a GitHub issue link; separate Pet/Trainer buttons stay under `/hpt debug`

## [0.2.2] - 2026-10-04

### Fixed

- Train next can reach off-screen ranks by showing only available Beast Training rows (scrolling the list still blocks Train)
- Planned ranks stay marked unknown (red) after Beast Training filters change
- The button and footer still say to scroll if the rank is not on screen

## [0.2.1] - 2026-10-03

### Added

- Sonic Blast for Bats as an info-only ability (ranks listed; not plannable until a trainer source and cost are known)

## [0.2.0] - 2026-10-02

### Added

- First CurseForge release for WoW Forever
- Planner docked beside Beast Training, with a two-press Train next button
- Forever pet ability data from Wowhead and Petopia, including info-only abilities
- Loyalty and training point tracking from the Pet tab and Beast Training
- In-game data reports (`/hpt report`) for crowdsourced corrections
- EllesmereUI theme support when that addon is installed
- Custom icon for the AddOns list, title bars, and minimap

[Unreleased]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.5...HEAD
[0.2.5]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.4...v0.2.5
[0.2.4]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/releases/tag/v0.2.0

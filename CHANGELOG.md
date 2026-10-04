# Changelog

All notable changes to Hunter Pet Trainer Forever are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Add user-facing notes under **[Unreleased]** in the same change as the code.
When tagging a version, move those notes into a dated `## [x.y.z]` section first.
The CurseForge and GitHub release changelog is that section only.

## [Unreleased]

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

[Unreleased]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/Xzeryn/Hunter_Pet_Trainer_Forever/releases/tag/v0.2.0

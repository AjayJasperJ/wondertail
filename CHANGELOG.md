# Changelog

User-visible changes for each application version belong here. The app version
in `pubspec.yaml` is the source of truth. Older dates are omitted where they were
not recorded in the release history.

## [0.5.0] - 2026-10-19

### Added

- Global Starlight wallet and reward receipts; collecting all twelve island coins
  awards one core, once per island. Previously collected coins import on revisit.
- Loom & Workshop with permanent Starweave Cape, Comet Trail, Companion Crown,
  Glider Cape, and an earned Trailblazer Cape. Equipment works across local islands.
- Breeze, mist, and overgrowth mutators from island 4, with visible wind lanes,
  limited visibility, shears, vine clearing, and alternate walking routes.
- Two- or three-chamber generated caves with directional mirror/rune gates,
  saved puzzle state, varying room dimensions, and chamber-specific crystals.
- Permanent archive perks: pickup-radius upgrades (capped at 52 world units)
  and optional cache detection. Caches supply Starlight and skyseeds.
- Companion bond ranks 1–3, one skyseed favor per island, rain gifts from Pip,
  mist/cache help from Luma, and cache finding from Moss.
- Optional seven-minute active-play Trailblazer runs over three compact seeded
  islands after three main restorations; normal saves and run rewards are isolated.
- Release documentation rules and an automated version/changelog consistency check.

### Changed

- Later lantern/garden tasks vary their object order; some rain islands require
  explicit ordered sunseed gathering.
- Wallet receipts and active island progress commit in a single authoritative
  checkpoint; older saves remain readable. Receipt history grows with exploration.
- README now describes the current game and setup; release history lives here.

### Known limits

- The room modules, task families and mirror puzzle rules remain finite.
- Equipment is device-wide, not cloud/account-wide. Trailblazer attempts are
  session-only; quitting abandons an unfinished run without changing normal progress.
- Web audio remains unavailable. Engagement targets have not been measured.

### Fixed

- Nearest-target interaction selection prevents overlapping creature/landmark
  ranges from hiding archive restoration or required collection actions.
- Glider landings search safe bank angles near coastal ponds and reject launches
  from invalid ground; crossings still have to pass through the water area.
- Later lantern instructions show their generated order instead of the tutorial's.

## [0.4.0] - 2026-10-19

### Added

- Landscape lobby with Rowan, Sky and Fern appearances, persistent settings,
  and a paginated unlocked-island atlas.
- Five island size profiles and irregular coastlines shared by drawing/collision.
- Mountain cave entrances, walkable cave/lodge interiors, Scout Wren, cave
  crystals and persistent Sky Archive restoration.
- Save-and-return-to-lobby control and discovery checklist.

## [0.3.0] - 2026-10-18

### Added

- Android landscape/immersive presentation and compact side panels.
- Collision-aware walking paths, richer biome foliage, cliffs, distant islets,
  waterfalls, and glowing objective guidance.
- Twelve persistent island coins, an island-specific scarf, and next-island previews.
- Original Android music and proximity, pickup, task and completion cues.

## [0.2.0]

### Added

- Ongoing seeded island trail, three biomes, three main adventure families,
  saved revisits, and separate island memories.
- Analog joystick movement, collision substeps/sliding, themed cards and ribbons.
- Cached scenery, bounded effects, event-driven HUD updates and calm motion.
- Save migration, recovery tests, web CI builds and an Android app/APK workflow.

## [0.1.0]

### Added

- First playable Flutter/Flame prototype with player movement, the lost-cloud
  adventure, world interactions, and local persistence.

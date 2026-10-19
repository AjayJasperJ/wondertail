# Changelog

User-visible changes for each application version belong here. The app version
in `pubspec.yaml` is the source of truth. Older dates are omitted where they were
not recorded in the release history.

## [0.7.0] - 2026-10-19

### Added

- Bottom health/booster bars and touch backpack, jump, attack and sprint controls.
- Gravity-driven Z jumps and double jumps with stamina costs; airborne pond
  crossings, landing hazards and campsite recovery without inventory loss.
- Seeded lava patches, side-cave lava, bounded hostile chasers, close-range
  attacks, damage immunity windows and a craftable damage-reducing guard charm.
- Persistent expedition backpack, once-per-island crystal/herb gathering, and
  scout-lodge recipes for health tonics, stamina boosters and defensive gear.
- Seeded rope-untangling, perfect-maze and four-color graph puzzle gateways.
  Normal progression requires restoration plus puzzle clearance; existing
  unlocked islands remain accessible. The maze timer is optional and pauses
  while the app is backgrounded.
- Distinct explorer body proportions, foot boxes, movement/jump speeds and
  attack strength. Nearby foreground trees can occlude the explorer.

### Changed

- Mountains, lodges and tree trunks share solid foot geometry with route
  generation and movement. Circular rocks and shore sliding remain supported.
- Space now jumps; E interacts, F attacks and B opens the backpack.
- Saves include backpack, gathered-item bits, puzzle clearance and vitals;
  older checkpoints receive default health and an empty bag. Trial backpacks
  and vitals stay separate from normal exploration and reward merges.
- Campsite artwork follows each generated island's arrival point.
- Generator 4 places mountain footprints clear of quest targets and reserves
  landmark space when planting solid trees; older generation saves still load.

### Known limits

- Stylized top-down 2D with simulated jump height; no side-scrolling engine,
  climbable mountain mesh, Minecraft voxel world, or realistic character assets.
- Layouts and puzzles are seeded combinations of finite rules. Enemies reset
  after travel/relaunch; unfinished puzzle boards are session-only. Puzzle
  clearance persists. Timed maze expiry restarts only that maze attempt.
- No measured retention, excitement, boredom or cognitive-development results.
  Real-device frame pacing and touch feel still require playtesting.

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
- Old positions inside a newly introduced vine gate relocate safely; movement
  can also back out of a gate without getting trapped.
- Archive bonuses are counted on load/restoration rather than scanning the full
  reward history for every nearby coin during each frame.

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

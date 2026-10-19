# Technical architecture

## Version 0.7

The current action, inventory, puzzle and persistence rules are detailed in
[SUPER_ADVENTURE_V0.7.md](SUPER_ADVENTURE_V0.7.md). `adventure_system.dart` adds
pure Dart vitals/combat/backpack/puzzle models. Movement also checks shared
mountain, lodge and trunk foot boxes. The bottom vitals notifier is throttled
separately from quest HUD updates. The table below describes the retained base.

| Boundary | Implementation |
| --- | --- |
| Domain | Pure Dart world/island rules, `PlayerProfile`, reward receipts, mutators, and `TrailRun` |
| Generation | Save schema 2, generator 3; stable PRNG; seed/index; compact challenge maps |
| Movement | Analog input, substeps, circular blockers, irregular shore projection, vine gates, wind and checked glide landings |
| Real-time drawing | Flame 1.30.1; original Canvas art; one cached `ui.Picture` for static terrain |
| UI | Flutter; scoped value notifiers for contact, compass, progress and save status; themed in-game cards |
| Storage | SharedPreferencesAsync 2.5.3; authoritative profile/active-progress snapshot plus historical island caches and backups |

The v0.5 progression, challenge isolation and migration protocol are detailed in
[ENGAGEMENT_UPDATE.md](ENGAGEMENT_UPDATE.md). Reward receipts grow with exploration;
the profile checkpoint is no longer strictly constant in size. Run maps are
session-only; first-win rewards merge into the normal profile without replacing
its position or island memories.

## Generated trail and authored mechanics

Island zero remains the cloud/rain adventure so old saves have a meaningful migration. Later islands combine biome selection, a repeating adventure rotation and seeded map variations. Landmark arrangements, obstacles, decoration and names are deterministic. The three authored mechanics are cloud rescue/rain/exploration, a numbered light sequence, and filling a can then planting three beds. The player can keep generating a next island; this does not mean unlimited unique authored mechanics.

The world holds the active map, island progress, and shared player profile.
Restoring a wonder and solving its puzzle gate unlock the next index (optional
Trailblazer runs use restoration alone). A lobby atlas or journal loads earlier
island memory before replacing the map. Generated scenery is reconstructed from
the seed/index; progress bits, equipment, bond points and reward receipts persist.

## Movement and rendering costs

Movement subdivides an elapsed frame into steps no longer than 1/90 second,
consuming up to 150ms after a stall. Contact projection preserves tangential
movement along circular blockers and the irregular shore. Vine gates add a
clearable collision area. Wind modifies movement in its lane; gliding searches
for a safe landing whose segment crosses a pond. Tests do not replace device
playtesting.

The renderer retains one static `ui.Picture` until the island, quest stage or planted-bed state changes. Terrain, path, tree, obstacle and label work is recorded once. Character, companion, pickups and at most 42 effect particles remain dynamic. Camera translation follows the player; compass updates are throttled. Contact/progress changes notify their HUD listeners. The game loop does not call screen-wide `setState` as the player walks. The analog knob rebuilds only its own widget during drag. Calm motion reduces animation, particles and camera easing.

One active island, one terrain picture and a bounded particle list keep active rendering resources bounded. Retained save keys still grow with exploration. Device frame times, battery use and browser behavior require profiling; no universal FPS guarantee is made.

## Save protocol and recovery

The repository snapshots the wallet/receipts and active progress together before
queueing a write. Historical island cache writes precede the authoritative
checkpoint. Loading prefers embedded active progress over a possibly newer cache;
the reward ledger reconciles previously unclaimed caches without duplicate coins.
Movement-only saves do not rewrite historical island caches. Writes are serialized
and retain recovery copies; SharedPreferences is not a transactional database.

Version 1 data is explicitly mapped to the redesigned first island. Rescued cloud, learned story, awakened grove, collected seed and completed bridge progress are retained. The arrival position resets because the map changed. The old v1 keys are left in place. Unsupported schema/generator versions are rejected rather than interpreted as current terrain.

Shared preferences is **not a transactional database**. Independent key writes cannot promise atomic commits across power loss, and a lifecycle save can be interrupted. Browser quotas and data clearing can remove saves. Production durability, storage budgets and archival/migration policy remain future work.

## Validation boundary

Unit tests cover repeatable generation, multiple adventure completions, reachable landmarks, anti-snag collision behavior, timing, prerequisite/idempotency rules, migration and snapshot recovery. Widget tests cover small screens, landscape, raw pointer release/cancel, themed cards and travel/revisit. A structural rendering test checks terrain caching and bounded HUD notifications. Physical mobile profiling, real browser reload/offline checks and engagement playtests remain open.

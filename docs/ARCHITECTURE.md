# Technical architecture

## Version 0.2

| Boundary | Implementation |
| --- | --- |
| Domain | Pure Dart `WorldState`, `IslandProgress`, `IslandMap`, `WorldRules` |
| Generation | Schema/generator version 2; stable integer PRNG; seed plus island index |
| Movement | Analog vector; normalized keyboard diagonals; bounded simulation substeps; circular obstacle contact normals/tangents; ellipse shore projection |
| Real-time drawing | Flame 1.30.1; original Canvas art; one cached `ui.Picture` for static terrain |
| UI | Flutter; scoped value notifiers for contact, compass, progress and save status; themed in-game cards |
| Storage | SharedPreferencesAsync 2.5.3; header checkpoint plus separate island-memory keys and recovery copies |

## Generated trail and authored mechanics

Island zero remains the cloud/rain adventure so old saves have a meaningful migration. Later islands combine biome selection, a repeating adventure rotation and seeded map variations. Landmark arrangements, obstacles, decoration and names are deterministic. The three authored mechanics are cloud rescue/rain/exploration, a numbered light sequence, and filling a can then planting three beds. The player can keep generating a next island; this does not mean unlimited unique authored mechanics.

The world holds only the active map and its `IslandProgress`. A header records seed, current index, highest unlocked/visited indices and position. Restoring a wonder unlocks the next index. Returning through the paged trail book loads that island’s memory before replacing the active map. Generated scenery is reconstructed; progress bits, choices and timer state persist separately.

## Movement and rendering costs

Movement subdivides an elapsed frame into steps no longer than 1/90 second, consuming up to 150ms after a stall. Obstacle penetration is projected along the contact normal, and tangential input is retained. A small deterministic assist moves the player around a nearly head-on obstacle. Shoreline projection permits sliding along the ellipse. Landmark spacing avoids unavoidable blockers. Tests verify traversability and collision regressions; they are not a substitute for tactile device playtesting.

The renderer retains one static `ui.Picture` until the island, quest stage or planted-bed state changes. Terrain, path, tree, obstacle and label work is recorded once. Character, companion, pickups and at most 42 effect particles remain dynamic. Camera translation follows the player; compass updates are throttled. Contact/progress changes notify their HUD listeners. The game loop does not call screen-wide `setState` as the player walks. The analog knob rebuilds only its own widget during drag. Calm motion reduces animation, particles and camera easing.

One active island, one terrain picture and a bounded particle list keep active rendering resources bounded. Retained save keys still grow with exploration. Device frame times, battery use and browser behavior require profiling; no universal FPS guarantee is made.

## Save protocol and recovery

The save repository snapshots the small header and active island memory before queuing a write. It writes island progress only when the active island or its memory changed, then writes the header. Movement-only checkpoints rewrite no prior island memories. Writes are serialized so delayed older requests cannot win over newer snapshots. Each key has a previous-good recovery copy; corrupt primary island data is not copied over a valid backup.

Version 1 data is explicitly mapped to the redesigned first island. Rescued cloud, learned story, awakened grove, collected seed and completed bridge progress are retained. The arrival position resets because the map changed. The old v1 keys are left in place. Unsupported schema/generator versions are rejected rather than interpreted as current terrain.

Shared preferences is **not a transactional database**. Independent key writes cannot promise atomic commits across power loss, and a lifecycle save can be interrupted. Browser quotas and data clearing can remove saves. Production durability, storage budgets and archival/migration policy remain future work.

## Validation boundary

Unit tests cover repeatable generation, multiple adventure completions, reachable landmarks, anti-snag collision behavior, timing, prerequisite/idempotency rules, migration and snapshot recovery. Widget tests cover small screens, landscape, raw pointer release/cancel, themed cards and travel/revisit. A structural rendering test checks terrain caching and bounded HUD notifications. Physical mobile profiling, real browser reload/offline checks and engagement playtests remain open.

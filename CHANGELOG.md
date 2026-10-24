# Changelog

User-visible changes for each application version belong here. Flutter versions
come from `pubspec.yaml`; separate 3D versions come from `three_d/project.godot`.
Older dates are omitted where they were not recorded in the release history.

## [3D 0.18.0] - 2026-10-20

- Added an isolated Custom Explorer lobby preview using the supplied SWAT GLB.
  It previews the model's available idle, walk, run, shooting, roll, sword and
  interaction clips without changing the active gameplay hero or save data.
  Missing jump/crouch/prone/sitting/scope/bow-draw clips are labelled honestly
  as planned source clips until a compatible animation pack is provided.
- Kept the custom preview GLB hand-packed while making the normal asset-prep
  pipeline deterministic, so CI can verify the runtime files without rewriting
  the lobby-only character.
- Added bright Colour Archive mural panels at the ruins and colour-coded beacon
  pennants as visual anchors for the upcoming persistent painting activity.
- Added trail cairns, biome colour pockets, river-bank stones and deterministic
  vegetation groves to reduce empty stretches without adding heavy per-frame work.
- Grounded bridge fix: the ridge crossing now follows the generated river centreline, with terrain-snapped stone abutments; added shallow foundations to camp, cavern, ruins and beacon so constructions blend into uneven land instead of floating above it.

- Crafting hotfix: explicit recipe selection with deferred UI refresh, output
  item artwork and carried/required material counts. Previews work without
  ingredients; crafting stays locked until materials and camp access are ready.
  Added real mouse/touch input regression checks for all five recipe buttons.
- Added a marked 12 m peaceful spawn camp where hostile mobs stop pursuing and
  cannot damage the player. Added height-based landing damage after falls above
  5.5 m, with normal jumps and protected camp landings remaining safe.
- Fixed mobile web two-finger controls by tracking each touch position
  independently; joystick movement and camera orbit no longer steal or corrupt
  each other's pointer data.
- Mobile performance pass: throttled solar lighting, landmark label visibility,
  ground-object visibility and HUD status refreshes to reduce battery and GPU/CPU
  work while keeping movement, camera input and visual effects full-rate.
- Applied the expedition theme across the HUD: deep navy surfaces, warm gold
  framing, purple pressed/selected states, beveled buttons, soft shadows and
  consistent disabled styling across lobby, brief, camp, backpack and pause.
- Replaced pack and crafting ingredient text tiles with original item artwork
  and separate counts, selected outlines, equipped highlights and tooltips.
- Rebuilt the lobby as a winding eight-node island journey with locked previews,
  mechanic labels, difficulty colors, paging and a plum/blue/gold menu theme.
- Stopped rendering the hidden 3D world behind the opaque lobby.
- Generator 3 adds separated landmark sectors, alternate route graphs, return
  loops, six landform profiles and winding river alignment on unvisited islands.
- Difficulty tiers scale enemy stats with a cap; fixed respawn and health-bar
  maxima. Added deterministic generation, route and UI regression checks.

## [3D 0.17.0] - 2026-10-20

- Optional repeatable material deliveries, marked hunts and explorer rescue
  contracts; transactional coin/diamond rewards and an open exploration option.
- Coin supply shop and five diamond-funded visible camp improvements with
  discounts, herb rewards, cache rumours, melee bonus and additional pack boxes.
- Day/night lighting paused by menus, flanking hunters and frontal warden defense.
- Selectable Off/2x/4x edge smoothing, default 2x for Android silhouette aliasing.
- Added living-world save/rollback/reward tests and approved roadmap with explicit
  shipped-versus-planned status for all requested feature families.

## [3D 0.16.0] - 2026-10-20

- Capped imported external textures at 256px with mipmaps (source assets retained),
  reduced grass budgets and brought vegetation culling nearer to the player.

- Removed surrounding sea and suspended coastal sailing; island rivers remain.
- Expanded the game viewport to the available screen aspect ratio, preserving
  HUD proportions. Android immersive mode remains enabled.
- Added preset-based distance fog and shorter camera rendering horizons.

- Performance hotfix: preset-based vegetation draw distance and grass counts,
  no grass shadows, reduced tree shadows on Low/Medium, primitive rock colliders,
  and proximity checks before inventory copying during automatic collection.

- Runner publishes successful main builds as GitHub Early Access prereleases,
  with a directly downloadable, versioned Android APK and SHA-256 checksum.
  Pull requests cannot publish; reruns preserve existing release assets.

- Fixed missing ocean construction; ocean shading now scales to the sea mesh.
- Boardable, steerable coastal boat with dock return and unlocked-island travel.
- Carved river on expanded layouts; hollow camp cabin with usable doorway.
- Axe/hammer selection and persistent tree/rock harvest receipts.
- Replaced weight with 27 boxes and 50-item stacks; upgrades add nine boxes.
- Navy/teal menus, stack grid, graphics/color/FPS presets and custom controls.
- Added slot-limit, failed-harvest rollback and boat-state regression checks.
- See docs/FRONTIER_V0.16.md for controls and current limits.

## [3D 0.14.0] - 2026-10-20

### Adventure loop

- Replaced the active repeated cloud-rescue loop with three persistent contracts:
  defended relay calibration, survey/underground archive recovery, and sentinel
  outpost clearance. Contract rotation varies independently of the six biomes.
- New expeditions open a themed briefing with three tasks and an extraction
  payment. Players can prioritize available tasks and follow a cyan trail over
  the walkable path graph; the HUD names the action and remaining distance.
- Relay channels take 1.8 seconds and break on damage or leaving range. Vaults
  require both survey fragments and decoded terminals. Outpost targets remain
  defeated after their objectives commit. Menus pause all contract timers.
- Optional field caches award 15 Starlight and ammunition when capacity allows.
  Camp backpack upgrades cost 50 Starlight for +10 capacity, up to three upgrades.

### World and presentation

- Four coastline formations, seeded landmark relocation, mountain placement and
  increased scale variation for newly generated islands. Existing layouts and
  saved dropped-item positions are retained.
- Bright pickup colors, cyan/violet/gold shafts, claim bursts, warmer daylight,
  cooler ambient fill and fine continuous ground shading.
- Updated archive terminology and instructions; the active loop no longer asks
  players to rescue a cloud on each island. Existing cloud/seeds data remain saved.

### Reliability and limits

- Contract flags, extraction payments, cache claims and upgrades use atomic save
  transactions with failed-write rollback. JSON numeric progress flags are
  normalized on load, including older seed flags.
- Added tests for terrain variants, physical guided traversal, all three contract
  paths, pause/interruption, save/reload, extraction and upgrade limits.
- This remains a stylized adventure with a finite set of contract/landmark types;
  it is not a photorealistic or endlessly unique content generator. Device frame
  rates, retention and excitement are not measured by the automated checks.

## [3D 0.13.0] - 2026-10-20

### Added

- Stack-grid backpack, equipment selection, drop-one/drop-stack actions and a
  nearby loot panel. Dropped stacks persist per island and cave/surface realm,
  with transactional saves, reclaim receipts and a starter-sword fallback.
- Camp crafting table with a 3×3 shapeless ingredient grid, recipe autofill and
  output preview. Existing bow, arrow and tonic recipes remain; a pistol and
  crystal ammunition are now craftable. Weapons and ammo can be dropped/reclaimed.
- Uploaded Quaternius sword and pistol meshes, first-person equipped models,
  bow string draw/release, nocked arrows, gun recoil and separate pistol rounds.
- Selected textured oak/pine variants and rocks from the uploaded nature archive,
  normalized in world units with trunk/rock collision. Original uploads retained.
- Reproducible asset extraction with archive/node provenance and runtime hashes.

### Fixed

- Full-bag resources no longer stop the auto-collection loop before quest seeds.
  Failed pickups retry individually; unavailable resources do not mask interactions.
- Crafting and mob ammunition rewards respect carrying capacity. Dropping an
  equipped weapon safely selects the starter sword.
- Inventory checks cover save failure rollback, reloads, repeated reclaim,
  full-bag quest collection, cave isolation and control bounds/overlap.

### Compatibility and limits

- Existing schema-1 saves migrate the optional gun/ammo/ground-loot fields.
  Quest discoveries and Starlight stay protected and do not occupy bag space.
- This is a weight-based stack inventory inspired by Minecraft/PUBG; it does not
  implement their full drag/drop, armor or shaped-recipe systems. The starter
  sword is protected. Dropped stacks are reclaimed whole, with 128 per island.
- Art stays stylized. Bow draw and gun recoil are procedural; character combat
  uses the available shared clips rather than bespoke motion capture or hand IK.
- New environment/equipment models are generated from the preserved archives by
  the preparation script before local runs and CI exports.

## [3D 0.12.1] - 2026-10-20

### Changed

- Softer daylight and terrain colors, small instanced grass tufts instead of tall
  cone flowers, fuller wind-swaying crowns and mixed forest conifers.
- Timber camp cabin with pitched roof, windows and chimney; stone-ring hearth,
  rounded cave entrance rocks, clustered crystals and a curved wooden bow.
- Recessed pond basin with shoreline stones and a clear scenery exclusion zone.
- Compact quest card, translucent touch controls, quieter landmark labels and a
  lobby reading panel that leaves the landscape visible.
- Closer trailing camera, horizon-facing first-person entry and camera-relative
  shoulder offsets. Returning to the lobby restores the explorer's visibility.

### Fixed

- Enemies no longer share the player's collision space. Aimed arrows now account
  for the offset between the shoulder camera and the bow.
- Removed explorer invulnerability flashing and touch-button style seams.
- Added camera reset and touch-control layout regression checks. Existing save
  formats, equipment, quest receipts and progress remain compatible.

### Limits

- Art remains stylized and procedural. Water uses ripple/foam effects rather
  than physical refraction. Phone frame rates have not been measured.

## [3D 0.12.0] - 2026-10-20

### Added

- Modular trailing, eye-level, left/right shoulder and tactical overhead cameras,
  aim zoom/crosshair and a skippable three-second beacon restoration reveal.
- North-up radar with nearby loot, enemies and motion vectors, objective markers
  and cave rune/exit markers. The existing world beacon remains the 3D waypoint.
- Translucent rounded touch actions for aiming, camera/shoulder switching and
  physical crouching, plus a three-heart display above the health/stamina HUD.
- Automatic coin, material, unlocked skyseed and mob-drop collection with suction,
  solid-terrain line-of-sight checks, storage retry backoff and durable receipts.
- New-game bow and 24 arrows. Defeated mobs drop arrows, Starlight and a crystal
  when inventory capacity allows; each mob reward is limited to once per island.
- Fading proximity health indicators, volcanic burning, winter slowing and
  telegraphed, wall-blocked elite stun projectiles. All timers pause in menus.
- Physical crouch capsule with ceiling clearance checks and smooth visual height
  transitions. Death clears negative effects; existing double-jump physics remain.
- Animated pool ripple/foam shader, denser layered broadleaf crowns with branches
  and shader-driven wind, and directional melee sparks replacing swing rings.
- Regression checks for cameras, crouch/ceilings, default equipment, quest locks,
  pickup occlusion, storage recovery, mob receipt reload and paused timers.

### Compatibility and limits

- Existing save schema, island progress and owned equipment are retained. The
  starter bow applies to new games; older bags keep their existing loadout.
- Three hearts summarize the existing continuous HP pool, preserving explorer
  health differences; this is not a rule that every hit costs one whole heart.
- Tactical overhead is the specification's "6th person" view, not a distinct
  standard camera projection. Reveal pans play on restoration and can be skipped.
- Trees remain stylized procedural 3D geometry. Pool shading uses procedural
  ripple/foam and radial depth tint, not physically accurate depth/refraction.
- Guns/armory caches, diamonds, throwables, inventory tabs, rope/map-coloring games
  and larger new level layouts are not implemented by this polish release.

### Deployment

- Added automatic GitHub Pages publishing of the 3D browser game after successful
  main-branch builds, with deployment permissions isolated from the build job.
- Web assets use commit-specific filenames to avoid mixing cached builds.
  Export validation checks the required files and non-threaded configuration.
- Documented one-time Pages activation, stable browser testing, local browser
  saves, mobile requirements and private-repository hosting limitations.

## [3D 0.11.0] - 2026-10-20

### Added

- Organized all uploaded GLBs and source packs under `source_assets/` with stable
  names, provider/license references and a reproducible runtime asset manifest.
- Rigged Adventurer, Hooded Adventurer and Farmer replace the three placeholder
  explorers. Imported idle, walking, running, attack/recoil and hit animations;
  bone-attached equipment preserves existing movement, stats and collision.
- Animated Mushnub, Cactoro and Yeti hunters plus a Goleling Evolved guardian.
- Runtime preparation keeps only used clips and compacts their buffers. Original
  uploads retain all clips; unused SWAT and gun models remain outside exports.
- Denser smoothly shaded island terrain, blended path/rock colors, softened cliff
  bands, rounded-edge prop meshes, round forest crowns and smoother rock shapes.
- Camera-only foliage collision and Standard-detail 2x MSAA, disabled on Low.
- Tests for imported rigs/clips, looping movement, equipment socket, terrain
  normals and paused animations, alongside existing route/combat/save checks.

### Compatibility and limits

- Save slots, landmarks, player stats, equipment and reward receipts are preserved.
  Cosmetic scenery placement is revised. Smooth visual edges retain solid gameplay
  colliders. The source models do not include dedicated jump/bow clips.
- These remain stylized low-poly assets. No measured Android frame-rate claim.

## [3D 0.10.0] - 2026-10-20

### Added

- Persistent backpack for wood, crystals, herbs, bottled tonics and arrows;
  once-only resource gathering along trails and character carrying capacities.
- Camp workbench recipes for a bow, eight-arrow bundles and health tonics.
  Inventory pauses gameplay; tonics can be consumed away from camp.
- Bow/sword equipment selection with visible held models, touch SWAP and SHOOT
  controls, arrow count, B backpack and Tab weapon shortcuts.
- Ranged projectiles with swept scenery/enemy collision, facing-cone aim assist,
  finite saved ammunition, lifetime and a 24-arrow cap. Menus freeze arrows.
- Legacy 3D save migration adds an empty bag without resetting discoveries;
  failed gathering, crafting and firing writes roll back before gameplay effects.
- Tests for migration, crafting/refunds, capacity, equipment persistence, tonic
  consumption, paused inventory, ranged hits and walls intercepting arrows.

### Limits

- The 3D edition now has a sword and bow. Guns, throwables, additional powers,
  remaining puzzle families and challenge runs are still unported.
- Arrow supplies persist, but arrows already in flight do not survive reload or
  island travel. The existing Flutter game and its saves remain separate.

## [3D 0.9.0] - 2026-10-20

### Added

- Playable Godot 4.4.1 third-person 3D edition in `three_d/`, with original
  procedural low-poly meshes, lit sky, floating cliffs, variable coastlines
  and island sizes, mountain slopes, landmark trails, ridge bridge and waterfall.
- Physical capsule movement with slope limits, sliding, jump buffering, coyote
  time, double jumps, sprinting, collision-resolved dashes and a retracting camera.
- Landscape lobby, Rowan/Sky/Fern body and stat differences, unlocked island
  atlas, sound/detail/sensitivity settings, pause, touch joystick/camera/actions.
- A complete rescue-to-beacon loop: cloud companion, ruins skyseed, physical
  Echo Cavern with songstone puzzle, ridge guardian and next-island travel.
- Six biome identities with woodland, cacti, frost pines, mushroom groves,
  basalt spires and celestial columns; a modular seeded island sequence.
- Sword combat, telegraphed attacks, health/stamina, volcanic hot-spring damage,
  free camp recovery and a Starlight-funded instant health-tonic recipe.
- Once-only coins/skyseeds/restoration rewards, atomic offline checkpoints,
  backup recovery, failed-write rollback and an independent Android/save namespace.
- Synthesized music and movement/jump/combat/discovery cues, objective marker,
  bottom-center vitals and in-theme inline feedback.
- Headless terrain, physics, camera, progression and save tests; rendered desktop
  and small-phone screenshots; Android/Windows/Linux/web export workflow.
- Physical route traversal checks cover both landmark trails; the cave approach
  bypasses solid arch walls, and the restored beacon opens a visible portal.

### Migration and limits

- Flutter v0.8 remains intact. The 3D edition starts its own expedition and cannot
  import old Flutter saves. It installs alongside the existing Android package.
- This is a playable 3D foundation, not a feature-complete v0.8 port. The full
  arsenal, backpack, three brain-puzzle families, challenge runs and workshop
  unlock economy remain in the 2D edition. No real-device performance claim.
- Six visual biomes reuse one quest structure and finite procedural models;
  this is not a seamless voxel world. Health, enemy state and exact position
  reset on reload; committed discoveries and Starlight persist.

## [0.8.0] - 2026-10-20

### Added

- Compact bottom-center vitals and equipment tray; right-side jump, attack,
  throwable, power, sprint, bag and nearby-exploration controls. Notifications
  use a single-line bottom ribbon. Tap the world to aim independently of movement.
- Swords, daggers and hammers with directional combo strikes; guns, bows and
  slingshots with swept projectile collision, finite ammunition where applicable,
  lodge forging and restocking. Sword and slingshot are starter equipment.
- Grenades, lingering gas and timer charges, with fuses, bounded area effects,
  saved supplies and vault-wall breaching. Dash, shield and Starlight burst powers
  use combat energy and cooldowns.
- Passive forage creatures and distinct hunter, dive-bomber, burrower and ranged
  elite behaviors. Seasonal spawn variation, pursuit routes and at most nine mobs.
- Desert, winter, underground, volcanic Devils and celestial Heaven realms,
  alongside the three retained biomes; biome scenery and progress-driven seasons.
- New frontier islands have 3x width and height, more scenery, larger collision
  grids and cached navigation. Introductory and Trailblazer islands retain their size.
- Animated lava channels, edge gradients, bubbles and heat-wave lines; permanent
  crystal bridges, snowflakes, ice momentum and cold exposure with campsite/lodge warmth.
- Seeded lore/switch locations and guarded vault interiors with once-only hammer
  schematics, ammunition and booster rewards. Explore interacts with nearby secrets.

### Changed

- Explorer maximum health, carrying capacity and knockback resistance now vary
  by body archetype; gathering respects capacity without deleting older inventory.
- Generator 5 saves include the expansion boundary and validated combat loadout.
  Older visited islands retain their layout; new expansion begins beyond the
  saved frontier. Challenge gear, bag and vitals do not replace normal progress.
- Split combat, AI and world-generation rules into dedicated domain modules.
- Closed vault walls block traversal and shots; melee checks line of sight.
  Forage gifts account for consumable weight, and guardian spawns use valid ground.
- Optional vault placement reserves clearance from required walking routes so
  an unopened vault cannot block the main adventure.

### Known limits

- This remains stylized top-down 2D. Heat distortion is drawn wave animation,
  not a full-screen post-processing shader. Seasons change along progression,
  not through a real-time weather simulation. Realm names do not imply separate 3D worlds.
- Enemies, projectiles, active fuses and unfinished challenges are session-only;
  supplies, equipment, secrets and rewards persist. No real-device frame-rate guarantee.

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
- Mountain placement checks route connectivity and uses a wider fallback search
  on crowded compact islands, preserving continuous cave and quest paths.

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




## [3D 0.14.1] - 2026-10-20

### Changed

- Ridge bridge now crosses a visible animated water channel with irregular stone banks; the crossing no longer floats over dry ground.
- Sky clouds use layered translucent wisps instead of solid oval blobs, and daylight now moves through a gentle solar cycle.
- Hostile creatures are larger, faster and more readable with emissive warning eyes, stronger pursuit, shorter wind-ups and heavier contact damage.

### Fixed

- Flipped the held bow root on imported character sockets so the bow, string and nocked arrow face the firing direction instead of appearing on the explorer's back.

### Design direction

- Coins remain spendable expedition currency for backpack upgrades and caches; the world loop stays open-ended through optional routes, cave entry and persistent island travel rather than a single forced cloud hand-off.


## [3D 0.14.2] - 2026-10-20

### Fixed

- Multitouch movement now latches the movement thumb's heading while the second thumb orbits the camera, preventing the player from spinning or refusing to advance.
- Touch ownership is explicitly released when the joystick returns to neutral.
- Crouching no longer scales the imported GLB vertically. The collision capsule and camera lower smoothly while the full character rig moves down as one piece, avoiding stretched-body deformation on rigs without a crouch animation.


## [3D 0.15.0] - 2026-10-20

### Added

- Islands now sit inside a visible animated ocean with a softer horizon ring and water shader.
- Added a dock-like expedition boat at the gate so travel reads as a journey between destinations.
- Increased seeded vegetation density from sparse landmark dressing to a fuller island ecosystem.
- Increased instanced grass and understory coverage while preserving clear walkable routes and landmark space.

### Design direction

- The island remains open-ended: the boat is a visual travel anchor, while cave entrances, optional caches and expedition objectives remain available before departure.
- Supplied GLB characters continue to provide the playable explorers and creatures; scenery density is procedural so new island seeds remain varied.

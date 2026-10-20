# Wondertail 3D — 0.18.0

[Journey UI and generator 3](JOURNEY_V0.18.md) describes the new island path,
inventory artwork, difficulty scaling and save-compatible terrain changes.

See [living-world contracts, economy and roadmap](LIVING_WORLD_ROADMAP.md) for
optional progression, camp upgrades and current Android edge-smoothing controls.

Current coastal sailing, harvesting, backpack and display rules supersede older
weight-based descriptions below: [Coastal frontier](FRONTIER_V0.16.md).

The 3D action-adventure edition uses Godot **4.4.1**, GDScript and
procedural environments and bundled Quaternius character/creature models. Flutter
v0.8 remains in the same repository.
This document describes implemented behavior, not the entire v0.14.0 blueprint.

## The expedition

1. Choose Rowan, Sky or Fern in the landscape lobby. Continue or select an
   already unlocked island in the atlas.
2. Follow sandy trails and the floating objective marker to the ruins. Free Pip,
   the cloud creature. Pip follows you and awakens the ruins skyseed.
3. Enter Echo Cavern through the mountain arch. Read its three-symbol song, then
   interact with the Sun, Moon and Star songstones in the indicated order. A wrong
   note resets the attempt. Completion permanently awakens the cavern skyseed.
4. Cross the ridge approach and face the warden. Its visible windup gives time
   to step away or dash. Defeat it to gather the third seed.
5. Bring three seeds and the rescued friendship to the sky beacon. Restoration
   awards 30 Starlight once and unlocks the next island. Interact again to travel.
   Revisit old islands from the atlas.

Coins, materials, mob drops and unlocked seeds use proximity collection with
wall checks. Landmarks still use the context action.
Each seed awards five Starlight once. Mob loot is claimable once per mob per
island. Ordinary mobs recover after 30 active seconds when the player is far away.
The warden stays defeated for the current visit; collecting its seed removes it
from future visits. Progression is untimed and fully offline.

New islands vary scale, coastline, terrain noise and visual biome. Six identities
cycle: Mosswake Highlands, Amber Dunes, Frostbell Reach, Moonveil Wilds, Emberfall
Crags and Cloudgarden. Shared landmarks, trails and quest order make this a
finite modular system, not infinitely novel adventures. One island and one small
cave are loaded at a time; there is no seamless streaming or voxel excavation.

## Movement and survival

| Explorer | Health | Walk speed | Jump velocity | Sword damage |
| --- | ---: | ---: | ---: | ---: |
| Rowan | 100 | 7.0 m/s | 9.0 m/s | 28 |
| Sky | 80 | 8.2 m/s | 10.0 m/s | 23 |
| Fern | 135 | 6.2 m/s | 8.7 m/s | 39 |

Distinct silhouettes have different capsule radii/heights. Terrain uses a
clockwise-wound collision mesh; trunks, rocks, buildings, cave walls, arches and
bridge planks have solid colliders. A 46-degree slope limit blocks steep faces;
trail corridors suppress sharp height changes. Sliding, six solver slides and
a small safe margin reduce corner catches. No free-climbing system is included.

Jump buffering is 0.16 seconds and coyote time is 0.12 seconds. A second airborne
jump is available; each costs 12 stamina. Sprint is 1.55× walking speed and drains
22 stamina/s. Otherwise stamina regenerates at 16/s. Strikes cost nine stamina
and check range, direction and terrain line of sight. Dashes cost 30 stamina,
have a 2.5-second cooldown and resolve physics velocity rather than teleporting.
They grant 0.45 seconds of protection.

Attackers deal 13 damage, or 23 for the warden, after a 0.65-second windup with a
two-second cooldown. Damage grants 1.2 seconds of immunity. Emberfall's marked
hot spring deals 27 damage while grounded in it; this is an initial hazard, not
the full animated lava-channel system of the 2D game. Falls or zero health return
you to camp with full vitals and all discoveries intact. Camp recovery is free.
The pause menu can spend five Starlight on an immediate 55-health tonic; it
does not charge an already healthy player.

A sphere-swept SpringArm3D retracts the orbit camera against scenery and excludes
the player. Pitch is limited. Simultaneous joystick, camera and action touches
are supported. Hostiles use local steering and physics, not global navmeshes;
extended playtesting may expose catches despite reserved landmark paths.

## Controls and interface

The backpack (B or BAG) pauses play. Gather each trail resource once per island
for two wood, crystals or herbs. Capacity is 40 for Rowan, 30 for Sky and 60 for
Fern. Materials and tonics weigh one unit each, arrows and rounds 0.1. Changing to a smaller
explorer preserves existing items; gathering resumes after freeing space.

At camp, craft a bow for three wood/two crystals, eight arrows for one wood,
or a bottled tonic for two herbs/one crystal. A tonic heals 55 health anywhere
and is not consumed at full health. Camp recovery remains free. Weapon selection,
materials, ammunition and tonics persist; v0.9 saves receive an empty backpack.
Crafting and shot consumption commit to disk before effects are applied.

New games start with a bow and 24 arrows; existing bags retain their loadout.
Tab or SWAP cycles owned sword/bow/pistol. F or SHOOT fires the bow
for six stamina with a 0.65-second cooldown. Each arrow deals 38 damage and
travels at 30 m/s for up to 2.5 seconds. Up to 24 arrows can exist; swept rays
test both scenery and enemies. Aim assist selects an unobstructed target within
23 metres and a forward-facing cone. In-flight arrows pause with menus and are
cleared on reload/travel; ammunition already spent is not refunded.

| Action | Touch | Keyboard / mouse |
| --- | --- | --- |
| Move | Left stick | WASD / arrows |
| Look | Drag the world | Drag mouse over world |
| Double jump | JUMP twice | Space twice |
| Strike | STRIKE | F |
| Dash | DASH | Q |
| Sprint | RUN toggles | Hold Shift |
| Interact | Context action | E |
| Pause | CAMP | Escape |
| Camera / shoulder side | VIEW / L-R | C / R |
| Aim / crouch | AIM / CROUCH | V / X |

Bottom-center vitals and right-side actions leave the center free for play.
Objective/distance appear at the top, feedback in a themed bottom ribbon. No
native dialogs, scaffold snackbars or task timers are used. A 1280×720 design
canvas scales to landscape phone sizes. Menus/backgrounding release touch input
and stop gameplay simulation.

The lobby contains explorer selection, unlocked-island atlas and settings.
Low detail disables shadows and distant scenery. New mobile expeditions default
to Low. Volume and camera sensitivity persist. Eight pooled cue voices and an
original eight-second pentatonic music loop provide sound. More music variety
and animation variety remain needed. Players and enemies now use skinned models
with imported animation clips; environment and equipment remain procedural.

## Saves and compatibility

Android uses `com.ajayjasper.wondertail3d`, separate from Flutter. The slot is
Godot's `user://expedition_3d_v1.json`. No Flutter files are read or changed;
there is no cross-engine save importer, login or cloud synchronization.

Saved: seed, selected/unlocked island, hero, Starlight, settings, backpack/equipment and per-island
coin receipts, seeds, rescue, cavern solution and restoration. Session-only:
exact position, vitals, enemies, effects and unfinished song attempts. Reload
resumes at the selected island's camp with full vitals. Storage grows with
visited-island changes rather than saved meshes.

Reward transactions snapshot state, write/flush a temporary file, back up the
previous checkpoint and rename the new file into place. Failed writes restore
the prior in-memory state. The loader validates structure and falls back to the
backup if the primary is corrupt. Temporary files are not committed checkpoints.
An OS crash can still lose the latest operation; hardware storage testing remains
needed. Uninstalling an edition removes its own local data.

## Source map

| File under `three_d/scripts/` | Responsibility |
| --- | --- |
| `main.gd` | Expedition, landmarks, interactions and combat orchestration |
| `terrain.gd` | Seeded mesh, collision, trails and scenery |
| `art.gd` | Shared materials and original models |
| `player.gd` | Capsule physics, animation, crouch and vitals |
| `camera_manager.gd` | Camera modes, aiming and reveal pans |
| `minimap.gd` | North-up radar and nearby markers |
| `creature.gd` | Roaming/chasing/telegraphed attackers |
| `hud.gd` | Responsive lobby, menus, HUD and multitouch |
| `save_store.gd` | Validated transactional local storage |
| `sound.gd` | Synthesized score and bounded cue voices |

## Build and verification

Open `three_d/project.godot` in Godot 4.4.1 and press F5. Compatibility rendering
targets OpenGL ES 3.0/WebGL 2.0. Matching export templates are required. Presets
support Linux/Windows x86-64, single-threaded web and Android ARMv7/ARM64.

```sh
godot --headless --path three_d --editor --quit
godot --headless --path three_d --script tests/smoke.gd
python3 three_d/tests/check_packaging.py
godot --headless --path three_d --export-release Linux
godot --headless --path three_d --export-release Windows
godot --headless --path three_d --export-release Web
```

Android requires Java 17 and SDK platform/build-tools 34, configured in Godot
Editor Settings. CI validates the pinned engine/templates with official SHA-512
checksums, checks scripts, runs headless tests, renders screenshots and exports
all targets. APKs are release-mode test builds with ephemeral debug signing;
they are not store-signed. `check_packaging.py` verifies version/docs consistency
and the separate Android namespace.

Artifacts: `wondertail-3d-android`, `wondertail-3d-desktop`, `wondertail-3d-web`,
`wondertail-3d-screenshots`. Serve web files over HTTP(S); the first visit downloads
the runtime. Browser audio requires a user gesture. Native gameplay works offline;
offline browser reload is not guaranteed.

`tests/smoke.gd` exercises the actual engine: 24 seeded islands, required-route
slopes/landmarks, scale variety, physical spawn/movement/jump, walls, dash collision,
camera retraction, pause input release, cavern solution, once-only rewards/travel,
failed-write rollback and backup recovery. `tests/screenshots.gd` renders the real
scene and menus, including a 640×360 phone view. These are not frame-rate benchmarks.

## Remaining conversion work

The full v0.8 arsenal, throwables, additional powers, armor,
workshop and Trailblazer runs are not ported. The 3D pistol and grid inventory
are described in the linked v0.13 inventory guide. The song is the only 3D puzzle;
rope, maze and map coloring remain in Flutter. No brain-development benefits
are claimed. More quest/encounter layouts, NPCs, interiors, animation and music
are needed beyond this first complete loop.

No Android hardware frame-pacing, thermal, notch or long-session testing has
been completed. No retention, boredom or excitement percentages are measured.
Prioritize device playtests before adding more systems.


## v0.11 visual assets and smooth surfaces

Original uploads live under `source_assets/characters/` and `source_assets/packs/`.
The SWAT model is retained but not shipped. The pistol is now selected from the gun archive. Runtime
models are a reproducible subset under `three_d/assets/models/`: Adventurer for
Rowan, Hooded Adventurer for Sky, Farmer for Fern; Mushnub, Cactoro, Yeti and
Goleling Evolved for hunters/guardian. See the asset credits and SHA-256 manifest
under `three_d/assets/`. `python3 tool/prepare_3d_assets.py` recreates the subset.

The source character models each contain 24 clips. Only used locomotion, idle,
attack/recoil and hit clips are retained in runtime copies; unused animation
buffers are removed without editing original sources. Dedicated jump and bow
clips are not supplied: airborne characters use a neutral pose, and bow attacks
reuse a recoil clip. Weapon meshes follow the right wrist through a bone socket.
Root movement and collision stay in the original gameplay capsule; animations
do not change combat reach or move the player through scenery. Animation pauses
with gameplay menus.

Terrain retains its seeded height function, landmarks and reward positions. Its
visual mesh is denser, uses continuous height-derived normals, and blends ground,
rock and path colors per vertex rather than shading each triangle independently.
Cliff undersides use smoother bands. Cosmetic scenery placement is revised.
Props use cached rounded-edge meshes while retaining their solid collision boxes;
rounded appearance is not a promise of rounded collision at every structure.
Forest and winter scenery now use individually selected textured oak/pine models
with solid trunk colliders. Other biomes retain their procedural identities.
Leaf surfaces are visual and do not block arrows; trunks and rocks do. Standard detail enables 2x MSAA;
Low disables it along with shadows/distant scenery. Real-phone thermal and
frame-pacing measurements remain outstanding.


## Camera, navigation and collection polish

See [v0.12 camera controls, shipped changes and explicit limits](3D_POLISH_V0.12.md).



See [inventory, crafting and equipment in 0.14.0](INVENTORY_V0.13.md) for current backpack rules.


See [0.14 expedition contracts and migration](EXPEDITIONS_V0.14.md) for the active adventure loop.

# Wondertail v0.8 — Tactical survival and biome expansion

Version **0.8.0+8**. This document describes implemented behavior, including its
limits. The Flutter/Flame game remains offline and top-down 2D.

## Controls and HUD

Joystick: bottom left. Compact health, booster and three equipment slots: bottom
center. Context action, sprint, bag, Explore, jump, attack, throwable and power:
bottom right. The footer shows short notifications, without modal alerts or
scaffold snackbars. Quest details remain available in themed cards and the journal.

Tap a world position to aim for two seconds independently of movement. Otherwise
movement determines facing. Tap equipment slots to cycle available weapons,
throwable type and power. Keyboard: WASD/arrows move, Shift sprint, Space double
jump, F attack, Q cycle weapon, G throw, R power, I Explore, E context action,
B bag, J journal. Select throwable and power through their quick slots.

## Arsenal

| Weapon | Base damage | Reach / range | Cooldown | Stamina | Ammo |
| --- | --- | --- | --- | --- | --- |
| Sword | 35 | 90 | 0.45s | 8 | None |
| Dagger | 22 | 65 | 0.22s | 5 | None |
| Hammer | 65 | 120 | 0.90s | 16 | None |
| Gun | 30 | 650 | 0.28s | 2 | Shared ammo |
| Bow | 42 | 560 | 0.65s | 8 | Shared ammo |
| Slingshot | 18 | 400 | 0.40s | 6 | None |

Melee uses facing, reach, clear line of sight and explorer strength. A three-hit chain has damage
multipliers 1.0, 1.2 and 1.4, with a 1.4-second combo window. Ranged shots have
travel time and substepped collision against scenery and mobs. Ammunition is a
shared abstract resource for gun and bow, not a realistic cartridge simulation.
No PvP, gore, friendly fire or real-world weapon instructions are included.

Sword and slingshot start unlocked. A scout lodge can forge a dagger/bow for two
crystals, hammer for three, or gun for four, plus one herb each. Known equipment
cannot be charged twice. A crystal plus herb crafts ten ammo or one selected
throwable. Ammo caps at 500; each throwable type caps at 20. The equipment tray
selects the throwable being restocked. Existing tonic/booster/guard recipes remain.

| Tactical item | Fuse | Effect |
| --- | --- | --- |
| Grenade | 1.1s | 100 damage within 125 units; opens a nearby cracked vault wall |
| Boom gas | 0.65s | Four-second cloud, 18 damage/second within 125 units |
| Timer charge | 2.3s | 100 damage within 125 units; wall breaching |

Throws arc visually, slow over time and stop at solid scenery. Each new normal
save starts with three grenades, one gas and one charge; traveling does not
refill them. Maximum eight active throwables and 48 live projectiles, including
enemy shots. This is a bounded combat simulation, not a general physics engine.

Each power costs 40 energy and shares a six-second cooldown. Dash traverses up
to 180 units through collision-checked steps and gives brief immunity. Shield
grants three seconds of protection. Starlight burst deals 75 damage to nearby
mobs within 190 units. Energy regenerates at 1.5/second and gains 15% of damage
dealt to living enemies, capped at 100. Menus/backgrounding pause these clocks.

## Explorers and survival

| Explorer | Maximum health | Pack capacity | Movement / jumps | Knockback multiplier |
| --- | --- | --- | --- | --- |
| Rowan — balanced | 100 | 45 | Baseline | 1.0 |
| Sky — agile scout | 80 | 30 | Faster and higher | 1.25 |
| Fern — heavy brawler | 125 | 70 | Slower, stronger melee | 0.4 |

Capacity counts raw materials and consumables; already-saved inventory is never
deleted when over capacity. Gathering pauses until space is available. Weapons
and ammunition are separate equipment counts. Changing archetype clamps current
health to its maximum rather than granting a free heal.

Lava is a narrow, animated channel across a path, with gradient edges, bubbles
and drawn heat-wave lines. Expanded channels deal 40 damage; introductory ones
retain 25. Jump height avoids contact. Near the first channel, Explore can spend
two crystals and two herbs to build a saved bridge. Only its central crossing
is safe; the remaining lava continues to damage. The channel stays visually lava.

Winter terrain has low-friction movement. Cold realms and winter seasons cool
the player at 0.8 warmth/second; warmth restores at camp or a lodge at 8/second.
At zero warmth, exposure can deal six damage through the normal immunity window.
Volcanic/underground realms are exempt from seasonal cold. Warmth is session
state, not a persistent hunger or permadeath mechanic. Campsite recovery retains
equipment, coins, bag and quest progress.

## Biomes, scale and seasons

The first three introductory islands and optional compact Trailblazer runs keep
their previous scale. New frontier islands use **three times the width and
height**, roughly nine times the area before shape variation. Landmarks spread
with the terrain. More rocks and border scenery fill the space. Cached grid
navigation supports negative world coordinates; blocked route edges are sampled
to prevent paths crossing thin obstacles.

Eight identities cycle across expanded islands: meadow/plains, twilight, coral,
desert, winter, underground, Devils and Heaven. Desert cacti, snow pines, cavern
crystal/spike scenery, volcanic spires and celestial cloud arches distinguish
the new realms. The retained meadow supports seasonal leaf colors. Snow has
bounded screen-space flakes; calm motion reduces animated effects.

Spring, summer, autumn and winter derive from the world seed and each three-island
progression block. Summer permits an extra spawn and winter one fewer, within
the cap. This is deterministic seasonal variation across exploration, not a
calendar or continuously simulated weather system.

## Mob ecosystem and secrets

- Hunters pursue nearby players with collision and route assistance.
- Flying mobs hover, visibly telegraph a dive, then accelerate; the bite is
  active during the dive window. They can cross scenery while remaining on land.
- Desert/cave burrowers show a dust ring, telegraph emergence, and bite only
  during their surface phase. Their movement still respects solid ground geometry.
- Elite vault guardians have higher health and telegraphed ranged elemental
  shots. They guard optional loot; main restoration does not require killing them.
- Three passive forage creatures wander locally. Explore peacefully receives a
  two-herb gift once per creature per island, subject to pack space. Existing Pip,
  Luma and Moss companion stories/bonds remain available.

There are at most eight ordinary attackers plus one elite on an expanded island,
and three passives. Enemies leash to their home area. Mob logic updates only
during active play. Enemies reset after leaving/reloading; they drop no farmable
currency. Seasonal spawn counts and biome-selected behaviors vary encounters.

Each expanded island has a seeded cracked vault and a lore/switch location. A
grenade/charge near the vault or its switch opens the entrance. Defeat the elite,
then Explore at the vault to descend into a hidden interior. Explore at the chest
unlocks the hammer schematic, 20 ammo and a booster once. Return through the
exit. The open/claimed state and rewards save atomically with the normal world.
The vault is an additional room module, not a fully destructible underground world.

## Persistence and implementation

Schema 2 now writes generator 5. Saves from generators 2–4 remain readable. An
`expansionStart` boundary preserves visited legacy layouts and introduces larger
islands beyond their saved frontier, with at least three introductory islands.
Missing combat loadouts receive starter gear. Selection, ownership, ammo,
throwable supplies, energy, secrets and bridge state are validated and saved.

Transient state includes projectiles, fuses, power cooldowns, warmth, enemy AI
and unfinished puzzles. Restarting discards active throwables without refunding
already-checkpointed supplies. Trailblazer gear/bag/vitals are isolated; only the
existing profile reward path merges into the normal save.

| Module | Responsibility |
| --- | --- |
| `combat_system.dart` | Loadout, recipes, directional combos, swept shots, throwables and powers |
| `mob_ai.dart` | Passive movement, hunter routes, dives, burrowing, elite fire and spawn caps |
| `world_generator.dart` | Expanded navigation, population, channel/bridge rules, secrets and climate |
| `world_state.dart` | Validated checkpoints, expansion boundary, movement and island persistence |
| `tactical_hud.dart` | Compact vitals, equipment slots and ergonomic action cluster |

## Limits and validation

The game uses stylized Canvas art, not realistic animated characters. It has
finite authored tasks and room modules with procedural combinations. Combat has
no weapon-specific animation rigs, reload simulation or destructible terrain
beyond the vault state. Heat waves are drawn effects, not a post-processing
distortion shader. NPC trade markets and a full ecological simulation are not
implemented. Frame pacing, difficulty, fun and retention require real-player and
device playtests; automated tests cannot establish those outcomes.

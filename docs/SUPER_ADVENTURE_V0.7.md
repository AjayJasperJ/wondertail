# Wondertail v0.7 — Super-Adventure implementation

Version: **0.7.0+7**. This describes the implemented first playable overhaul.
It supersedes peaceful-only descriptions in older concept documents. It does
not claim that every ambition in the supplied v0.7 proposal is production-ready.

## What the player does

Choose an explorer in the landscape lobby, select an unlocked island, then
follow the compass to help a companion restore its wonder. Gather coins,
crystals and herbs, explore the lodge and multi-chamber crystal cave, restore
archives, avoid lava and chasers, and jump across hazards. A restored wonder
reveals a puzzle gate. Solve it to unlock the next generated island. Earlier
islands keep their discoveries and gathered-item flags. There is no authored
last island; the task and scenery vocabulary remains finite.

| System | Rules |
| --- | --- |
| Health | 100 maximum; surface/side-cave lava deals 25; enemies deal 12 + difficulty × 2. Damage grants 1.2 seconds of immunity. |
| Recovery | Zero health returns to the current island's arrival campsite, with full health/stamina. A missed pond jump also returns to camp. No bag, coin or quest loss. |
| Booster | 100 stamina; sprint drains 28/second, walking restores 12/second, resting restores 24/second. Sprint requires stamina above 1. |
| Jump | First jump costs 12, second costs 22; maximum two impulses before landing. Gravity is 780 units/second². High jumps clear lava and ponds, not mountains or buildings. |
| Attack | Omnidirectional reach 90, cost 8 stamina, cooldown 0.45 seconds; base damage 35 × explorer strength; modest collision-checked knockback. |
| Guard charm | Permanent backpack gear; reduces incoming damage by 40%. No durability or armor tiers. |
| Difficulty | min(8, 1 + island index / 3 rounded down); at most three chasers per island, with local pursuit/leash bounds. |
| Pause | Gameplay, health hazards, stamina and Trailblazer clocks pause in cards/puzzles and while backgrounded. |

Enemy art is a stylized hostile creature, with no gore. Combat is optional where
the player can evade; it is not a level-completion requirement. Enemies have no
currency drop, preventing repeated reset farming. They reset on travel/relaunch.

## Explorers

| Explorer slot | Speed multiplier | Foot box | Jump impulse | Strength | Appearance |
| --- | --- | --- | --- | --- | --- |
| Rowan | 1.00 | 22 × 16 | 330 | 1.0 | Balanced proportions |
| Sky | 1.12 | 18 × 14 | 365 | 0.8 | Tall and narrow |
| Fern | 0.92 | 28 × 20 | 310 | 1.4 | Broad and compact |

These are stylized Canvas characters, not realistic animated human models.
Base walking speed is 205 world units/second; sprint speed is 260 before the
explorer multiplier. Existing wind/equipment systems still apply.

## Inventory and collection huts

Six seeded material positions follow generated walking routes: three crystals
and three herb bundles (two herbs each). Walking within 30 units gathers each
position once per island; jumping does not gather. Progress bits and bag counts
are checkpointed together. Gathering stops crediting at the storage cap.

Open the backpack anywhere to use supplies. Enter a scout lodge to craft:

| Recipe | Cost | Result |
| --- | --- | --- |
| Health tonic | 1 crystal + 2 herbs | Restore 50 health, capped at 100 |
| Booster | 1 crystal + 1 herb | Refill stamina |
| Guard charm | 3 crystals + 1 herb | Equip permanent damage reduction |

Invalid purchases consume nothing. Full-health/full-stamina uses consume
nothing. Consumables cap at 99 each; raw material counts cap at 999,999.
The bag is a count-based collection, not a drag-and-drop equipment grid.

## Puzzle gateways

The zero-based island index selects the puzzle family modulo three. Seeds vary
the board. Completion is validated from board state, then saved on that island.

- **Untie the Rope:** six movable knots form a closed loop. Drag knots until
  nonadjacent edges do not cross or touch; knots must remain separated. A convex
  loop gives a constructive solution. This is graph untangling, not rope physics.
- **Maze:** a seeded DFS carves a connected 5 × 5 perfect maze. Tap a neighboring
  tile through an open wall to reach the bottom-right exit. By default untimed;
  optional 90-second mode resets the attempt on expiry and pauses in background.
  There is no consumable maze-resource mechanic yet.
- **Four-color map:** color nine regions so bordering regions use distinct
  colors. Dark diagonal links mark extra adjacency constraints. The tiled graph
  is planar and has a constructive four-color solution; this is a graph puzzle,
  not an arbitrary geographical polygon generator.

Back exits safely without awarding completion. Unfinished boards are not saved.
Previously unlocked islands are grandfathered; the update does not relock them.
New restoration rewards still pay once, but new island access waits for the gate.
Optional Trailblazer runs retain their existing three-island restoration rules
and do not require these new gates.

## Terrain, generation and performance

The game remains top-down Flame/Canvas. Island seeds produce irregular shores,
five size/shape profiles, three biomes, walking routes, caves, lodges, ruins,
coins, resources and danger placements. Difficulty adds chasers and a second
surface lava patch after the introductory islands. Lava appears in cave side
chambers. There is no voxel/chunk terrain simulation or continuous vertical
platform stack. Z height supports jumps and pond crossings; mountains remain
solid scenery with explorable cave entrances.

Feet collide with shared mountain/building/trunk boxes; circular rocks and
shore boundaries retain substepped sliding. Route search includes solid foot
geometry. Jumping does not disable solid scenery collision. Trees may cover a
player walking behind their canopy. Collision is a hybrid box/circle model,
not a pixel-perfect silhouette or a full tile-physics engine.

Static terrain remains picture-cached. Chasers are capped at three, particles
at 42, and vitals HUD updates at roughly 10 Hz through a separate notifier.
These bounds do not establish a frame-rate guarantee on low-end phones.

## Files and persistence

- `lib/domain/adventure_system.dart`: vitals, explorer stats, backpack recipes,
  solids, hazards, hostiles, attack rules and seeded puzzle models.
- `lib/domain/world_state.dart`: checkpoint integration, gathering/puzzle flags,
  shared terrain geometry, movement and unlock rules.
- `lib/game/wondertail_game.dart`: action updates, jump rendering, resource/lava/
  enemy art, foreground occlusion and vitals notifier.
- `lib/ui/game_screen.dart`: bottom controls, puzzle travel and side-panel bag.
- `lib/ui/inventory_screen.dart`: inventory and lodge crafting panel.
- `lib/ui/puzzles/puzzle_screen.dart`: interactive boards and optional maze clock.

Schema 2 now records generator 4; generators 2 and 3 remain readable. Mountain
placement avoids quest endpoints and trees reserve space around landmarks.
Added fields have validated defaults.
Old bag/vitals omissions become an empty bag and 100 health/stamina. Save recovery
continues using authoritative checkpoint plus backups. Jump velocities, live
enemy state and unfinished puzzle boards are transient. Trial attempts get a
separate bag/vitals; only existing profile rewards merge into the normal world.

## Pros, limits and evaluation

The overhaul gives resources a use, hazards a readable consequence, explorers
different movement tradeoffs, and each restoration a second kind of challenge.
Its weaknesses remain a small art/content library, modest enemy AI, fixed maze
size, simple omnidirectional combat, and finite task families. It still needs
real-device touch, accessibility, pacing, and difficulty playtests.

Addictiveness %, boredom %, excitement at completion %, retention and cognitive
benefits are **unmeasured**. No defensible percentages can be assigned from code
inspection. Use consented playtests to measure completion rate, time stuck,
voluntary next-island starts, reported enjoyment and device frame times.

Future work includes richer enemy telegraphs, varied cave geometry, climbable
ledges and moving platforms, a larger authored quest pool, accessibility options,
art/animation upgrades and device profiling. These are not shipped features.

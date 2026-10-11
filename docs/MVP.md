# MVP

## Planned scope

- [ ] One playable character
- [ ] Three island biomes
- [ ] Five creature types
- [ ] Ten reusable, authored adventure events
- [ ] Three world-changing mechanics
- [ ] Offline save/load
- [ ] Procedural island expansion

Biome names, creature roster and the final ten events remain design decisions.

## First vertical slice

One hand-designed island, one cloud creature and one complete consequence chain: rescue → rain → growth → new route. Use placeholder assets initially.

## Acceptance criteria

- Movement, camera and collisions work on the target test device.
- A child can discover and complete the cloud encounter with minimal explanation.
- A choice produces an observable change and a new reachable opportunity.
- Closing and reopening restores player position, choices and changed entities.
- Revisiting an island preserves changes and does not duplicate rewards.
- The same seed and generator version reconstruct the same base island.
- Expansion keeps active maps bounded; distant islands can be unloaded.
- A fresh install and a resumed game work without a network connection.

## Out of scope

3D, multiplayer, accounts, cloud synchronization, unrestricted chat, runtime generative AI, monetization systems and a large companion evolution tree.

## Quality gate

Playtest the first 15 minutes before expanding content. Record where players become confused, whether they understand consequences and whether they voluntarily explore the next opportunity. Do not claim replayability until observed.

## Implementation checkpoint — Little Drift

The first authored consequence chain is now implemented in Flutter/Flame: one player, cloud rescue, timed rain, grove growth, one seed, bridge planting, and a reachable lookout. It includes local snapshots and a journal. The broader checkboxes above remain planned; this is not three biomes, procedural expansion, or a validated 15-minute session. Automated checks cover rules, save behavior, map reachability and UI basics. Target-device movement, offline reinstall/reload behavior and child playtesting still require hands-on acceptance.

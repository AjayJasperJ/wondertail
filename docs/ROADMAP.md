# Four-week development plan

Planning estimate, not a delivery guarantee. Artwork, device coverage and playtesting may extend the schedule.

## Week 1 — Core gameplay

- [x] Bootstrap Flutter and Flame (web target)
- [x] Add character movement and player-following view
- [x] Add collision handling
- [x] Build one hand-designed island
- [ ] Verify movement on a physical device

## Week 2 — World generation and persistence

- [ ] Implement deterministic island generation
- [ ] Add biome definitions and portals
- [ ] Bound active island/chunk memory
- [x] Implement local save/load and save versions (prototype snapshots)
- [ ] Verify revisits and restart recovery

## Week 3 — Adventure engine

- [x] Add NPC dialogue and choices for the cloud encounter
- [ ] Implement event prerequisites and repetition rules
- [x] Add persistent, idempotent consequences for the first adventure
- [x] Complete the cloud → rain → grove → bridge chain

## Week 4 — Playable prototype

- [ ] Expand toward ten events, five creatures and three biomes
- [ ] Add licensed/original audio and clear UI
- [ ] Add onboarding and settings
- [ ] Playtest with appropriate parental involvement
- [ ] Fix confusion, save failures and performance issues

## Deferred decisions

Checked items mean implemented in the first slice, not accepted on physical devices. General event authoring, procedural expansion, and production-grade persistence remain future work.

Target age range; primary platform and minimum device; visual style; final state-management/persistence packages; distribution license; accessibility and parental settings appropriate to release scope.

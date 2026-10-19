# v0.5 — Progression and replay

This describes implemented version 0.5.0 behavior. It translates the supplied
engagement proposal into deterministic offline systems. Proposed engagement
percentages remain unmeasured design targets.

## Currency and equipment

Each outdoor coin banks one Starlight, once per island. All twelve award one
Starlight Core. Older coin flags import when their island is loaded/revisited;
startup does not scan all historic islands. The profile is device-local, with
no online account or cloud sync.

| Item | Starlight | Cores | Effect |
| --- | --- | --- | --- |
| Starweave Cape | 12 | 0 | Golden explorer cape |
| Comet Trail | 24 | 1 | Walking sparkles, disabled in calm mode |
| Companion Crown | 18 | 1 | Crown on the current following creature |
| Glider Cape | 36 | 2 | Context action to hop a pond to a checked safe bank |
| Trailblazer Cape | Earned | Earned | First successful three-island run |

Owned equipment can be freely equipped/toggled. Only one cape is worn at a time.
The crown and trail are independent. Gliding is a short bank-to-bank hop, not
unrestricted flight. No real-money purchasing is implemented.

## Mutators and main tasks

The first three islands retain clear learning conditions. From island 4, seeded
conditions are displayed at arrival and in the atlas:

- Breeze: a visible lane boosts moving input by 35% and adds an eastward push.
- Mist: reduced visibility; Luma rank 2 expands twilight visibility, rank 3
  extends that help to other biomes.
- Overgrowth: a vine gate blocks part of a route. Find shears near camp and clear
  it permanently, or take a detour. It is not a paid equipment gate.

Later lights and garden beds have seeded collection/planting orders. Some rain
islands require explicit ordered sunseed gathering rather than automatic pickup.
The three main families remain authored; every island does not invent a new mechanic.

## Modular caves and archive perks

Caves contain a hub and one or two side chambers. Generated room insets, crystal
positions and gate runes vary by seed/index. Rotate the hub mirror through
north/east/south/west; match a gate's rune to enter its branch. Branch exits return
to the hub; the hub exit returns outdoors. Mirror state and crystal flags persist.

The puzzle is directional rune alignment with beam feedback, not a physical optics
simulation. Modules remain finite. Lodges vary their inset and scout placement.
Restarts resume safely outdoors rather than storing an interior standing position.

Three crystals restore the archive. The first archive reveals seed caches and
raises coin radius from 28 to 36 world units. Further archives raise it to 44,
then 52 (the cap). After the main task, the upgraded compass targets an unopened
cache before the skyway. Each cache grants 3 Starlight and one skyseed; Moss rank 3
increases the seed reward to two. Every cache has a once-only reward receipt.

## Bonds

Main-wonder completion grants one kindness to its creature type. A skyseed gift
after completion grants one more, once per island, including older-island revisits.
Rank 1 is the starting relationship, rank 2 requires two kindness, rank 3 requires four.

| Creature | Rank 2 | Rank 3 |
| --- | --- | --- |
| Pip | One bonus Starlight on a qualifying rain island | Three bonus Starlight |
| Luma | Twilight mist/cache help | Help across biomes |
| Moss | Detects/unearths nearby seed caches | Two skyseeds per cache |

These are shared passive unlocks, not machine learning or free-form NPC behavior.
Pip gifts and caches cannot be farmed by waiting or repeated revisits.

## Trailblazer Runs

Unlock after three main restorations. Each attempt uses a new seed and three
compact islands. Complete all three main wonders within seven minutes of active
play. Cards, journals, and backgrounded play pause the clock.

- The normal world and its island memories are isolated from the attempt.
- Run pickups/archives do not bank normal currency or companion kindness.
- First victory grants the permanent cape, 24 Starlight and two cores.
- Later wins improve best time; first-win currency is not repeatedly farmable.
- Failed runs remove no normal progress. Free exploration stays untimed.
- Runs are session-only. Leaving/restarting abandons an unfinished attempt.

## Saves and migration

The authoritative checkpoint contains active island progress, wallet, equipment,
bonds and reward receipts together. Historical island caches remain separate.
If an island cache writes but the wallet checkpoint fails, loading the authoritative
snapshot retains the prior committed state. Later cache reconciliation pays only
unclaimed rewards. A challenge result commits profile rewards without replacing
the normal world's position, memories or unlocks.

Receipt history grows with rewarded islands, so profile checkpoint size is no
longer strictly constant with exploration. Movement still avoids rewriting all
historic island caches. Older v1/v2 progress remains readable; invalid or newly
blocked positions reset to safe arrival. Uninstalling removes local saves.

## Validation

Tests cover receipts, ownership, migration, interrupted commits, mutators,
mirror-gate solvability, upgrades, bonds, safe gliding and challenge isolation.
Landscape UI checks cover purchasing/equipping and challenge-menu gating.
Builds do not prove the proposal's engagement scores, real-device smoothness,
or child usability; those require measured playtests.

# Wondertail 3D 0.14 — The lost network

The active adventure is an expedition to recover an abandoned network of islands.
Each island has three contract objectives and an extraction payment. A full-screen
briefing opens on a new contract. Tap an available task to prioritize it; completed
steps remain marked. BRIEF reopens the plan and pauses play.

## Contract families

| Contract | Actions | Extraction |
| --- | --- | --- |
| The Silent Network | Calibrate three relays; clear the ridge warden before its relay. Stay within 3.5 metres and avoid damage during the 1.8-second channel. | 40 Starlight |
| The Sealed Archive | Open two surface survey caches. Enter the cavern, tune the displayed three-terminal sequence, then open the archive chest. | 55 Starlight |
| The Occupied Ridge | Defeat three marked sentinels. Regular ambient enemies do not count toward this contract. | 65 Starlight |

Each secured objective also pays eight Starlight once. Return to the extraction
gate after all three steps, claim payment, then interact again to travel onward.
The HUD displays the next action and distance. The cyan trail follows the path
graph and projects onto nearby trail segments rather than pointing straight
through mountains. In the archive it points to the next required terminal.

Surface objectives can be completed in another order. The archive chest remains
locked until both fragments and the decoder sequence are complete. Relay channels
pause in menus; taking damage or moving away cancels the channel without consuming
materials. Outpost deaths retry their objective save if storage is unavailable.
Saved completed target objectives do not respawn their sentinels.

## Rewards and permanent upgrades

Three optional gold field caches are placed beside trails. Opening one awards
15 Starlight and up to eight rounds/arrows, limited by weight and the 200-ammo
stack cap. Currency rewards still work with a full backpack. Caches are not
required for extraction. All cache and contract rewards have once-only receipts.

At camp, open PACK → CRAFTING → PACK +10. Each upgrade costs 50 Starlight and
adds ten capacity across explorers. There are three permanent upgrade levels.
Failed saves refund the currency and capacity change together. Inventory dropping,
reclaiming and crafting retain the [0.13 rules](INVENTORY_V0.13.md).

## World generation and presentation

New islands choose among Shattered Coast, Windward Spine, Three-Cape Basin and
Twin Summit formations. Coastline, scale, landmark positions and two mountain
centres vary by seed. Routes are rebuilt between the actual landmarks. Biomes
still control environmental identity, while contract type follows a separate
rotation. These are four procedural formations, not four entirely separate
hand-authored worlds or an unlimited narrative generator.

Unclaimed resources, field caches and contract targets have colored light shafts.
Rare objects use cyan, violet or gold accents. Pickups create short claim bursts.
Ground uses continuous procedural color detail; no large downloaded terrain
textures or online generation service are required. Lighting is warmer with a
cool ambient fill. Effects are stylized and compatible with the existing renderer;
they do not depend on ray tracing or expensive real volumetric lighting.

## Existing saves and limits

Existing island records, cloud/seed flags, collected receipts, equipment, currency
and ground stacks are retained. Prior seed completion is credited as equivalent
contract steps; restored islands stay restored. Previously visited layouts stay
unchanged so saved dropped-item positions and resource receipts remain valid.
Only newly generated islands use layout version 2. The previous cloud loop is
retained internally for regression tests and compatibility, not active play.

There are three contract families, a shared landmark library, one archive decoder
family and the existing combat system. More authored encounters, NPCs, interiors,
custom animations and art direction would be needed for a much larger production.
Automated completion tests do not measure whether human players find the game fun.
Physical-phone frame pacing, thermal behaviour and touch ergonomics remain unmeasured.

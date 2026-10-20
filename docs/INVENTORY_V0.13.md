# Wondertail 3D 0.13.0 — Inventory and equipment

Open PACK or press B. Select an item stack on the left, then equip/use it,
drop one, or drop the entire stack. Dropped stacks appear at your feet, do not
magnet back into your bag, and remain saved on that island. Use NEARBY LOOT
within four metres to reclaim a stack. Surface and cave loot stay separate.
A whole stack must fit; reclaim a stack to reveal additional nearby entries.
The starter sword and quest discoveries cannot be dropped. They guarantee a
fallback weapon and preserve progress. Bows and pistols can be dropped.

Skyseeds and Starlight never use backpack weight. Full resource pickups are
skipped, so they cannot prevent quest collection. Save failures roll back both
the bag change and the ground stack. Reloading never awards a reclaimed stack
again. There are at most 128 dropped stacks per island.

## Camp table

Craft within six metres of camp. Select wood, crystal or herbs in the backpack
and tap an empty crafting cell to add a preview ingredient. Tap a filled cell
to clear it. The recipe book fills the grid automatically, including recipes
whose ingredients you have not yet collected. Preview cells do not reserve or
remove items. The output button consumes materials only after a successful save.
Recipes are shapeless; arrangements with the same counts produce the same item.

| Output | Materials |
| --- | --- |
| Bow | 3 wood + 2 crystals |
| 8 arrows | 1 wood |
| Tonic (+55 health when used) | 2 herbs + 1 crystal |
| Pistol | 4 wood + 5 crystals |
| 12 rounds | 1 crystal |

Tab cycles owned weapons. The bow draws briefly before releasing an arrow.
The pistol fires faster, uses rounds, and shows recoil. Both use the camera aim
ray and swept projectile collision. First-person view includes the held weapon.
The sword uses the existing animated slash. These are stylized game weapons,
not physically simulated real weapons or bespoke motion-captured animations.

## Selected uploads

The runtime preparation script extracts two NormalTree variants, two PineTree
variants and two rock variants from Ultimate Stylized Nature Pack; a pistol
from Ultimate Guns; and the sword mesh from Hooded Adventurer. Grouped scenes
are split so an entire collection is never spawned as one tree. Transforms
are normalized to metres, and the source archives are unchanged. The manifest
records selected nodes, source hashes and generated runtime hashes. Embedded
textures are shared by content hash to avoid duplicate copies across variants.

Run `python3 tool/prepare_3d_assets.py` before opening the Godot project.
Generated nature/equipment GLBs are excluded from source control; CI reproduces
them from the committed uploads. New saves remain offline. Actual mobile frame
rates and touch ergonomics still need testing on physical devices.

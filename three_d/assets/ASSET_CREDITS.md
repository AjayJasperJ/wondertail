# Art credits and provenance

Characters and creatures: **Quaternius** (https://quaternius.com/).
The user supplied the original GLB files and source ZIPs; these are retained in
`source_assets/`. Runtime copies preserve the original materials, skeletons and
used animation clips. `manifest.json` records source/archive paths, hashes and
runtime sizes. `tool/prepare_3d_assets.py` reproduces the selected subset.

## Used models

- Rowan: Adventurer. Sky: Hooded Adventurer. Fern: Farmer from Modular Men.
- Forest/moon/volcanic/cloud hunters: Mushnub. Desert: Cactoro. Winter: Yeti.
- Ridge guardian: Goleling Evolved, a hovering stone creature.

The producer lists the following relevant collections under **CC0**:

- Ultimate Animated Character Pack: https://quaternius.com/packs/ultimatedanimatedcharacter
- Ultimate Modular Men: https://quaternius.com/packs/ultimatemodularcharacters.html
- Cute Animated Monsters: https://quaternius.com/packs/cutemonsters
- Ultimate Monsters: https://quaternius.com/packs/ultimatemonsters.html
- Ultimate Stylized Nature (two oak variants, two pines, two rocks): https://quaternius.com/packs/ultimatestylizednature.html
- Guns (Pistol selected): https://quaternius.com/packs/ultimategun.html

CC0 1.0 legal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode
Provider pages checked 2026-10-20. The downloaded archives did not contain a
separate license file; these official provider pages document the license.
This attribution is retained for provenance even though CC0 does not require it.

The sword mesh is extracted from Hooded Adventurer. Nature collection scenes are
split into individual named meshes before normalization; source archives remain
unchanged. Additional loose GLBs and the Survival/armor/saved archives remain
unshipped pending individual provenance and runtime suitability checks.

Terrain, structures, cloud companion, bow/arrow geometry and synthesized audio
remain Wondertail procedural assets. The runtime excludes the unused SWAT model,
whole source ZIPs and unused gun models. Equipment/nature subsets are generated
by `tool/prepare_3d_assets.py` before import, with hashes in the manifest.


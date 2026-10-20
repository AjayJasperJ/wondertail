# Uploaded art sources

Original user uploads are preserved here, outside the Godot runtime project.
Names are normalized for stable paths. No source model or archive was discarded.

| Folder / file | Origin | Status |
| --- | --- | --- |
| `characters/adventurer.glb` | Adventurer by Quaternius | Rowan source |
| `characters/hooded_adventurer.glb` | Hooded Adventurer by Quaternius | Sky source |
| `characters/swat.glb` | SWAT by Quaternius | Reserved; not shipped in game |
| `packs/ultimate_modular_men_glb.zip` | Uploaded Modular Men pack | Farmer selected for Fern |
| `packs/ultimate_monsters_glb.zip` | Uploaded Monsters bundle | Four creatures selected |
| `packs/ultimate_guns_glb.zip` | Uploaded Guns pack | Reserved; no new gun gameplay |

Run `python3 tool/prepare_3d_assets.py` from the repository root to reproduce the
runtime subset in `three_d/assets/models/` and its SHA-256 manifest. The script
retains mesh/material/skin data and the animation clips used in gameplay, then
compacts unused animation buffers. Original files retain all their animation clips.

See [asset credits and license sources](../three_d/assets/ASSET_CREDITS.md).

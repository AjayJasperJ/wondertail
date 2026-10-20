# Coastal frontier — 3D 0.16.0

## Current performance revision

External texture imports are capped at 256 pixels with mipmaps. Original source
images are preserved. Low draws 400 grass tufts and culls vegetation at 26 metres;
Medium uses 800 and 36 metres. High/Ultra retain larger scenery budgets.

Surrounding ocean and coastal sailing are suspended following performance
feedback. Rivers and pools remain. The game viewport expands with the display
aspect ratio and Android uses immersive mode. HUD proportions remain intact.
Distance fog accompanies shorter tree and camera draw distances; fog alone does
not reduce geometry rendering. The sailing description below records the earlier
0.16 implementation and does not describe currently enabled travel.

The ocean is built on every world load. Board the expedition boat from the dock
interaction beside the gate. Movement steers on the sea; interact returns to the
dock. Sailing beyond 135 metres travels to the next unlocked island. This is
coastal sailing with a transition, not seamless streaming between landmasses.

Expanded layouts have a shallow carved river and ridge bridge. Old layouts retain
their terrain. The cabin now has an open doorway and usable interior.

TOOLS cycles weapon, axe and hammer. Attack near a tree or rock to harvest two
wood or crystal. Harvest receipts persist; failed saves leave resources unchanged.
Tools currently share a simple procedural model without bespoke chopping clips.

Backpack: 27 boxes, 50 identical items per box; upgrades add nine boxes. Stacks
auto-arrange. Drop one or up to 50. Manual slot dragging is not implemented.
Old oversized bags retain contents. Quest discoveries and currency use no slots.

Graphics: Low, Medium, High, Ultra, Custom. Presets adjust resolution, MSAA,
shadow distance and scenery. Custom exposes shadow and resolution controls.
Color: Normal, Balanced, Realistic, Colorful, Pro. These are color adjustments.
FPS caps: 30, 45, 60, 90, 120; actual performance depends on device and browser.

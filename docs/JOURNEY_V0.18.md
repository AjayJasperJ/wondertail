# Journey presentation and generation — 3D 0.18.0

The lobby opens on an eight-island winding path with numbered nodes, locked
previews, the current island highlighted, and paging in either direction. Green
is Relaxed (islands 1–4), blue Adventure (5–8), amber Tough (9–12), and violet
Extreme (13 onward). Labels preview optional relay, archive or sentinel content.
These remain freely paced destinations rather than a requirement to complete
every bonus expedition. Open additional destinations through the camp menu.

Enemy health increases by 12% per difficulty tier, contact damage by two and
movement speed by 0.15. Scaling stops at tier three; enemy counts do not increase.
Respawns and health indicators now use the correctly scaled maximum health.

The new plum, midnight-blue and gold interface uses a flat illustrated lobby
background. The hidden 3D world is not rendered behind the opaque lobby. Starting
or resuming restores it. Item slots and crafting ingredients use original vector
drawings for logs, crystals, herbs, arrows, tonic, rounds, sword, bow and pistol.
Stack counts remain separate; selected item details and tooltips retain names.

Generator 3 applies only to newly visited islands. Visited layouts and resource
receipts are preserved. It samples five separated landmark sectors inside a safe
coastline envelope, alternates route topology, adds a return loop, varies mountain
amplitude and landform waves, and aligns water with a winding riverbed. Six
formations, scale and rotation vary deterministically with world seed and island
index. Trail carving keeps routes accessible. Mesh density, texture cap, fog and
vegetation budgets remain unchanged.

This is a finite procedural template library with seeded variation, not limitless
unique handmade content. Candy Crush inspired the readable winding level path;
the artwork and UI are original and no third-party game assets were copied.

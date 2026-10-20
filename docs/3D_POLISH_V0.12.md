# Wondertail 3D 0.12.0 — implementation and playtest guide

This release implements the camera, navigation, collection and control polish
from the supplied v0.12.0 blueprint. It does not claim the entire long-term
arsenal and brain-training roadmap is complete.

## Controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Move / look | WASD or arrows / drag world | Left stick / drag world |
| Jump / dash / sprint | Space / Q / Shift | JUMP / DASH / RUN |
| Shoot or strike / interact | F / E | SHOOT or STRIKE / contextual action |
| Camera mode | C | VIEW |
| Shoulder side | R | L / R |
| Aim zoom | V | AIM |
| Crouch toggle | X | CROUCH |
| Weapon / backpack / pause | Tab / B / Escape | SWAP / BAG / CAMP |

VIEW cycles Trail → First person → Shoulder → Tactical. "6th person" in the
blueprint maps to the distant tactical camera, not a new projection type.
First person hides the local explorer mesh without removing its collision.
Shoulder mode retains collision on the camera spring arm. Aiming narrows the
field of view; eye/shoulder shots follow camera direction. When explicit aim is
off, the existing narrow-cone, line-of-sight bow assist remains active.

Restoring the beacon starts a three-second camera sweep toward the gate. VIEW
skips it. Traversal attacks/jumps/dashes are disabled during the sweep; world
simulation continues, and pause freezes the sweep as well as status timers.

## Navigation and collection

Radar is north-up with a 39-metre radius. Gold dots mark nearby loot, red dots
and short vectors mark live threats, and the larger gold marker points toward
the current objective. Cave radar marks runes and the exit. The glowing 3D marker
and objective distance remain in the main view. Radar refreshes at 10 Hz and
uses existing entity lists rather than drawing a second 3D viewport.

Coins, wood, herbs, crystals, unlocked skyseeds and mob drops pull toward the
explorer inside a 3.2-metre radius. A solid-world ray prevents collection through
walls. Quest conditions still apply: free Pip, solve the song, defeat the warden.
Collection requires a successful save before the object disappears. A failed
write or full material bag leaves the resource available and backs off retries.
The magnet never auto-activates runes, cave transitions or the sky beacon.

Mob drops contain 3 arrows (8 for elites), 2 Starlight (10 for elites), and one
crystal if carrying capacity allows. Ammo caps at 200. Each mob's island receipt
survives reload; ordinary mob respawns cannot farm the same reward indefinitely.
Unclaimed drops themselves are session objects and disappear when the island is
rebuilt; defeating the same mob again can recreate an unclaimed drop.

## Survival and visuals

The three hearts represent three portions of the explorer's existing HP pool;
HP and stamina bars remain visible. At zero HP the player returns to the camp
without losing discoveries. Health differences between explorers remain intact.
Crouching slows travel and shortens the actual capsule. Standing is refused if
a ceiling overlaps the standing capsule. Crouching is not an invisibility or
stealth-detection system. Volcanic mobs cause brief burning, winter mobs slow,
and elites fire visible stun bolts that solid scenery can intercept.

Trees have branches, multiple layered 3D crowns and small wind movement; trunks
retain solid collision and foliage retains camera collision. These are stylized
assets, not scanned realistic trees. Pool water has animated procedural ripples,
foam and radial colour variation. No real depth-buffer refraction is claimed.
Existing terrain already has varying heights, cliffs, bridges and a cave. Abyss
falls trigger the existing camp recovery; no new invisible island wall is added.

## Deferred blueprint items

- Guns, crossbows, advanced ammo and armory-cache progression.
- Diamonds, power shards, throwable gear and categorized inventory tabs.
- Expanded island generation, new vertical realms and new passive NPC behaviours.
- Rope untangling, procedural mazes and map-colouring puzzle gateways. The existing
  cavern song puzzle remains the shipped puzzle, with its persistent completion.
- Dedicated source crouch/bow animation clips. Current rigs blend existing clips;
  crouching interpolates model height and bow recoil uses the available clip.

## Validation and device limits

Engine checks exercise existing routes/combat/saves plus camera validity and
first-person visibility, shoulder side, crouch clearance, pickup line of sight,
quest locks, failed-write recovery, drop idempotence and paused status/reveal
clocks. Rendered desktop screenshots cover all four camera modes and crouch in
addition to lobby, cave, inventory and the 640×360 layout. These are not measured
Android/iOS frame-rate or touch-device results; test on actual target phones.
